# Chaos Engineering Research — анализ сценариев отказа

## Цель

Документ описывает 4 сценария отказа для приложения, работающего в Kubernetes
кластере с Istio service mesh. Для каждого сценария приведены: реальные причины,
влияние на систему, архитектурные рекомендации для защиты.

## Архитектура стенда

```
                    ┌─────────────┐
     User ──────────│  Istio      │
                    │  Ingress GW │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Frontend   │ (nginx)
                    │  :80        │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  Backend    │ (python)
                    │  :5000      │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │  PostgreSQL │ (db)
                    │  :5432      │
                    └─────────────┘

     Harbor Registry (separate namespace):
     harbor-core:80 ←→ harbor-portal:80
                    ←→ harbor-registry:5000
```

## Сценарии

---

### 1. HTTP Latency — задержка ответа backend (стандартный)

**Описание:** backend получает переменную окружения DB_DELAY_MS=3000 и искусственно задерживает каждый HTTP-ответ на 3 секунды. Инъекция выполняется через rollout (обновление env-var) без участия Istio fault injection.

#### Реальные причины

| Причина | Как происходит |
|---------|---------------|
| GC pause | JVM/Go приложение останавливается на сборку мусора (Stop-the-World) |
| CPU throttling | Container упирается в CPU limit, обработка замедляется |
| Cold start | Новый pod ещё не готов (JIT, connection pool init) |
| Network congestion | Перегруженный сетевой канал между nodes |
| Зависимый сервис | Backend ждёт ответа от внешнего API (payment, SMS) |
| Disk I/O | Медленный диск при записи логов/файлов |

#### Влияние

- Frontend ждёт ответа → пользователь видит "loading" → timeout
- Если нет timeout на frontend → поток блокируется → thread pool exhaustion
- При накоплении очереди → cascading failure всего frontend

#### Защита

| Решение | Как |
|---------|-----|
| **Timeout** | Установить HTTP timeout на frontend (например, 3s) |
| **Circuit Breaker** | Istio DestinationRule outlierDetection — после N ошибок исключить backend из пула |
| **Bulkhead** | Ограничить количество одновременных соединений к backend |
| **Retry с backoff** | Повторить запрос с экспоненциальной задержкой (Istio retries) |
| **Graceful degradation** | Frontend отдаёт кэшированные данные при недоступности backend |

**Istio конфигурация:**
```yaml
# DestinationRule с Circuit Breaker
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: backend-cb
spec:
  host: backend
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 3
      interval: 10s
      baseEjectionTime: 30s
    connectionPool:
      http:
        http1MaxPendingRequests: 10
        maxRequestsPerConnection: 5
```

---

### 2. HTTP 500 — ошибки Harbor core (стандартный)

**Описание:** deployment harbor-core масштабируется до 0 реплик (kubectl scale harbor-core --replicas=0). В результате Harbor API недоступен и возвращает HTTP 503 (Service Unavailable) вместо отдельных HTTP 500.

#### Реальные причины

| Причина | Как происходит |
|---------|---------------|
| OOM Kill | Harbor core контейнер убит из-за нехватки памяти |
| DB connection pool exhausted | Harbor core не может подключиться к своей БД |
| Config error | Неверный secret/config после обновления |
| Disk full | Переполнен disk для registry storage |
| Certificate expired | Истёк TLS сертификат между core и registry |
| Version mismatch | Несовместимость версий core и portal после upgrade |

#### Влияние

- Docker push/pull операции падают — CI/CD pipeline заблокирован
- Аутентификация не работает — пользователи не могут залогиниться
- API возвращает 500 — автоматизация (helm pull, skopeo) ломается
- При 1 реплике — нет failover, весь registry недоступен

#### Защита

| Решение | Как |
|---------|-----|
| **Multi-replica** | Запустить ≥2 реплики core (требует больше ресурсов) |
| **Health checks** | Liveness/Readiness probes — K8s перезапускает упавший pod |
| **Resource limits** | Адекватные CPU/memory requests+limits |
| **Monitoring** | Alert на 5xx rate, latency, pod restarts |
| **Registry mirroring** | Второй registry как fallback |
| **Caching** | imagePullSecrets + локальный кэш на нодах |

---

### 3. DB Latency — задержка между приложением и PostgreSQL (стандартный)

**Описание:** backend получает переменную окружения DB_DELAY_MS=2000, каждый DB-запрос к PostgreSQL задерживается на 2 секунды. Инъекция выполняется через rollout (обновление env-var), без Istio fault injection.

#### Реальные причины

| Причина | Как происходит |
|---------|---------------|
| Slow query | Неоптимизированный запрос без индекса (seq scan на большой таблице) |
| Lock contention | Долгая транзакция держит lock, остальные ждут |
| Checkpoint storm | PostgreSQL выполняет mass checkpoint → I/O saturation |
| Network latency | Cross-AZ/cross-region DB, высокая сетевая задержка |
| Connection pool exhaustion | Слишком много соединений, DB тратит время на управление |
| Disk I/O bottleneck | Медленный EBS/volume, высокая IOPS latency |
| Vacuum | Autovacuum блокирует таблицу при большом количестве dead tuples |

#### Влияние

- Backend блокируется на DB-операциях → request timeout
- Connection pool истощается → новые запросы ждут connection
- cascading failure → все dependent сервисы деградируют
- При retry → thundering herd (все ретраят одновременно → DB ещё медленнее)

#### Защита

| Решение | Как |
|---------|-----|
| **Connection pool** | PgBouncer между приложением и PostgreSQL |
| **Query timeout** | Установить statement_timeout в PostgreSQL |
| **Read replicas** | Направить read-запросы на replica |
| **Caching** | Redis/memcached для часто запрашиваемых данных |
| **Circuit Breaker** | Прекратить запросы к DB при деградации, отдать fallback |
| **Async processing** | Очереди (RabbitMQ, Kafka) для неблокирующих операций |

---

### 4. Network Partition — обрыв backend ↔ DB (кастомный)

**Описание:** Istio AuthorizationPolicy с действием DENY запрещает трафик от backend principal к PostgreSQL на порт 5432, из-за чего backend не может установить соединение с БД. Эмулирует обрыв сети между backend и DB через сетевую политику service mesh.

#### Реальные причины

| Причина | Как происходит |
|---------|---------------|
| Network policy | K8s NetworkPolicy случайно блокирует трафик |
| Firewall rule | Изменение в security group / iptables |
| DNS failure | CoreDNS не резолвит db service → соединение невозможно |
| Node failure | Нода с DB pod вышла из строя |
| Cloud provider issue | Проблема с VPC routing, ENI, load balancer |
| Cable/switch failure | Физический обрыв сети в on-prem |
| BGP route flap | Временная потеря маршрутизации между AZ |

#### Влияние

- Все DB-операции немедленно падают → 500 errors
- Без retry/fallback → полное отсутствие функциональности
- Если приложение не обрабатывает DB ошибку → зависание
- Восстановление может потребовать пересоздания connection pool
- Data inconsistency если partition произошёл во время транзакции

#### Защита

| Решение | Как |
|---------|-----|
| **Circuit Breaker** | Открыть circuit при N failed connections → fast fail вместо timeout |
| **Retry с jitter** | Повторить с случайной задержкой (avoid thundering herd) |
| **Connection pool recovery** | Автоматическое пересоздание соединений |
| **Health endpoint** | Отдельный /health/db endpoint для K8s probes |
| **Multi-AZ DB** | PostgreSQL с репликацией в другой AZ |
| **Graceful degradation** | Read-only mode, отдача кэшированных данных |
| **Timeout на соединение** | connect_timeout=2s в PostgreSQL connection string |

---

## Общие рекомендации по архитектуре

### Istio层面的保护

```yaml
# Глобальный outlierDetection
apiVersion: networking.istio.io/v1beta1
kind: DestinationRule
metadata:
  name: default-circuit-breaker
  namespace: demo-app
spec:
  host: "*.demo-app.svc.cluster.local"
  trafficPolicy:
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
      maxEjectionPercent: 50
    connectionPool:
      tcp:
        maxConnections: 50
      http:
        http2MaxRequests: 100
        maxRequestsPerConnection: 10
        maxRetries: 3
```

### K8s层面的保护

```yaml
# Proper resource limits
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 512Mi

# Liveness/Readiness probes
livenessProbe:
  httpGet:
    path: /health/live
    port: 5000
  periodSeconds: 10
  failureThreshold: 3
readinessProbe:
  httpGet:
    path: /health/ready
    port: 5000
  periodSeconds: 5
  failureThreshold: 2
```

### Мониторинг

- **Prometheus**: Istio metrics (request rate, error rate, latency p50/p95/p99)
- **Grafana**: Дашборд с circuit breaker status, outlier detection events
- **Alerting**: Alert на 5xx rate > 5%, p95 latency > 2s, circuit open events

---

## Источники

- [Istio Fault Injection](https://istio.io/latest/docs/tasks/traffic-management/fault-injection/)
- [Istio Circuit Breaking](https://istio.io/latest/docs/tasks/traffic-management/circuit-breaking/)
- [Chaos Engineering Principles](https://principlesofchaos.org/)
- [PostgreSQL Troubleshooting](https://wiki.postgresql.org/wiki/Slow_Query_Questions)
