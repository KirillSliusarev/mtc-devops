# MTC True Tech — DevOps Test Task

Chaos Engineering стенд: разворачивает k3s + Istio + Harbor + demo-приложение
+ мониторинг через Ansible в Docker-контейнере. Включает 4 chaos-сценария.

## Архитектура

| Компонент | Описание |
|---|---|
| Docker | Контейнерная среда на ВМ |
| k3s | Однонодовый Kubernetes (`v1.29.3+k3s1`), без Traefik |
| Istio | Service mesh (`1.21.0`, профиль `default`), strict mTLS в namespace `demo-app` |
| Harbor | Приватный registry, 1 реплика на компонент (namespace `harbor`) |
| demo-app | Frontend (nginx) → Backend (python + psycopg2) → DB (postgres), namespace `demo-app`, istio-injection enabled |
| Monitoring | kube-prometheus-stack: Prometheus + Grafana, namespace `monitoring` |

Istio Ingress Gateway маршрутизирует трафик: `/api/` и `/health` → backend, остальное → frontend.

## Запуск

Единственный путь запуска — через Docker. Контейнер содержит Ansible,
подключается к ВМ по SSH и разворачивает весь стенд.

```bash
docker build -t mtc-chaos .

docker run --rm \
  -e TARGET_HOST=<IP> \
  -e TARGET_PORT=<port> \
  -e TARGET_USER=<user> \
  -e TARGET_PASSWORD=<pass> \
  mtc-chaos
```

`TARGET_PORT` по умолчанию `22`, `TARGET_USER` — `ubuntu`.
`TARGET_PASSWORD` опционален — если не задан, используется SSH-ключ из
`~/.ssh` (примонтируйте `-v ~/.ssh:/root/.ssh:ro`).

После завершения Ansible копирует chaos-скрипты на ВМ в `/tmp/mtc-devops/`.

## Запуск chaos-сценариев

Сценарии запускаются на ВМ (через SSH), не из Docker-контейнера.

```bash
ssh <user>@<IP> -p <port>
cd /tmp/mtc-devops
./chaos/run-all.sh
```

`run-all.sh` последовательно выполняет сценарии 01–04, каждый с паузой для
демонстрации нормальной работы, внедрения ошибки и отката.

Для автоматического (неинтерактивного) прогона с генерацией фонового трафика:
`./chaos/auto-test.sh` (3 минуты на сценарий + baseline/recovery).

## URL после развёртывания

| Сервис | URL | Доступ |
|---|---|---|
| Приложение | `http://VM-IP:30133` | — |
| Grafana | `http://VM-IP:30000` | `admin` / `admin` |
| Harbor UI | `http://VM-IP:30002` | `admin` / `Harbor12345` |

В Grafana: дашборд «Chaos Engineering Demo» (раскладка через ConfigMap).

## Chaos-сценарии

| # | Сценарий | Инъекция | Эффект |
|---|---|---|---|
| 1 | HTTP Latency | `RESPONSE_DELAY_MS=3000` на deployment `backend` | Backend задерживает HTTP-ответ на 3 с, P95 latency растёт |
| 2 | Harbor HTTP 500 | `EnvoyFilter` (HTTP fault abort 500, inbound на `harbour-nginx`) | 50% запросов к Harbor UI и API возвращают 500 |
| 3 | DB Latency | `DB_DELAY_MS=2000` на deployment `backend` | Задержка DB-запросов 2 с, P95 latency растёт |
| 4 | Network Partition | `AuthorizationPolicy DENY` (TCP порт 5432, от backend к db) | Backend не может записать в БД, DB status → error |

Сценарии 1 и 3 используют разные env-переменные backend: S1 задерживает
HTTP-обработчик (`RESPONSE_DELAY_MS`), S3 задерживает DB-запрос (`DB_DELAY_MS`).
Сценарий 4 — кастомный, использует Istio AuthorizationPolicy.

Каждый сценарий: демонстрация до → внедрение ошибки → демонстрация после → откат.

## Требования к ВМ

- Ubuntu 22.04 (amd64)
- 8+ ГБ RAM
- 4+ vCPU
- 20 ГБ свободного места
- SSH-доступ с пользователем в группе sudo (passwordless sudo или пароль для `TARGET_PASSWORD`)

## Структура репозитория

```
mtc-devops/
├── .dockerignore
├── CHAOS_RESEARCH.md
├── Dockerfile
├── README.md
├── entrypoint.sh
├── inventory.yml
├── site.yml
├── chaos/
│   ├── 01-http-latency.sh
│   ├── 02-http-500.sh
│   ├── 03-db-latency.sh
│   ├── 04-network-partition.sh
│   ├── auto-test.sh
│   └── run-all.sh
├── manifests/
│   ├── app/
│   │   ├── app.yml
│   │   └── gateway.yml
│   └── monitoring/
│       ├── chaos-dashboard.yml
│       └── istio-monitors.yml
└── roles/
    ├── docker/
    ├── k3s/
    ├── istio/
    ├── harbor/
    ├── app/
    └── monitoring/
```

`site.yml` — главный playbook, вызывает роли в порядке: docker → k3s → istio → harbor → app → monitoring.
