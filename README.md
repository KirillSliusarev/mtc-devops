# MTC True Tech — DevOps Test Task

Chaos Engineering стенд: k3s + Istio + Harbor + многокомпонентное приложение
с автоматизированной инъекцией отказов через Istio fault injection.

## Запуск

```bash
# 1. Клонировать
git clone git@github.com:KirillSliusarev/mtc-devops.git
cd mtc-devops

# 2. Собрать runner
docker build -t mtc-chaos .

# 3. Запустить (указать IP, порт и пользователя ВМ)
docker run --rm \
  -v ~/.ssh:/root/.ssh:ro \
  -e TARGET_HOST=192.168.0.40 \
  -e TARGET_PORT=2222 \
  -e TARGET_USER=kirill \
  -e TARGET_PASSWORD=somepassword \
  mtc-chaos

# 4. Запустить chaos-демонстрацию (на ВМ или через SSH)
ssh kirill@192.168.0.40 -p 2222
cd /tmp/mtc-devops
./chaos/run-all.sh
```

## Что происходит при запуске

Docker-контейнер с Ansible подключается к ВМ по SSH и за ~5 минут разворачивает:

| Компонент | Назначение |
|---|---|
| Docker | Контейнерная среда |
| k3s | Однонодовый Kubernetes (без Traefik) |
| Istio | Service mesh для fault injection |
| Harbor | Приватный registry (1 реплика на компонент) |
| Frontend + Backend + DB | Трёхзвенное приложение для демонстрации отказов |

## Chaos-сценарии

| # | Сценарий | Тип | Что делает |
|---|---|---|---|
| 1 | HTTP Latency | Стандартный | Задержка 5s на 50% запросов frontend→backend |
| 2 | HTTP 500 | Стандартный | 50% запросов к Harbor core возвращают 500 |
| 3 | DB Latency | Стандартный | Задержка 3s между backend и PostgreSQL |
| 4 | Network Partition | Кастомный | Полный обрыв связи backend↔DB |

Каждый сценарий: демонстрация до → внедрение ошибки → демонстрация после → откат.

## Доступы после развёртывания

- **Harbor UI:** `http://<VM-IP>:30002` (admin / Harbor12345)
- **Istio Ingress Gateway:** `http://<VM-IP>:30133`

## Требования к ВМ

- Ubuntu 22.04 amd64
- 8+ GB RAM
- 4+ vCPU
- 20 GB свободного места
- SSH-доступ с пользователем в группе sudoers

## Структура

```
mtc-devops/
├── Dockerfile                # Docker runner с Ansible внутри
├── site.yml                  # Главный playbook
├── inventory.yml             # Инвентарь (переменные окружения)
├── roles/
│   ├── docker/               # Установка Docker CE
│   ├── k3s/                  # k3s + kubectl + Helm 3
│   ├── istio/                # Istio + sidecar injection
│   ├── harbor/               # Harbor (минимальные ресурсы)
│   └── app/                  # Деплой frontend+backend+DB+gateway
├── manifests/app/            # K8s манифесты приложения
├── chaos/                    # Bash-скрипты (4 сценария + run-all)
└── docs/
    ├── CHAOS_RESEARCH.md     # Анализ сценариев отказа (271 строка)
    └── architecture.md       # Описание архитектуры
```
