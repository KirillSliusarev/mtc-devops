# MTC True Tech — DevOps Test Task

Chaos Engineering стенд: k3s + Istio + Harbor + многокомпонентное приложение
с автоматизированной инъекцией отказов через Istio fault injection.

## Быстрый старт

```bash
# Требования: Ubuntu 22.04 amd64, 8+ GB RAM, SSH-доступ с sudo

# 1. Клонировать репозиторий
git clone <repo-url> && cd mtc-devops

# 2. Запустить полный setup одной командой
ansible-playbook -i inventory.yml site.yml

# 3. Запустить chaos-демонстрацию
./chaos/run-all.sh
```

## Что входит

| Компонент | Описание |
|---|---|
| **k3s** | Однонодовый Kubernetes |
| **Istio** | Service mesh для fault injection |
| **Harbor** | Приватный registry (core, portal, registry — по 1 реплике) |
| **Sample app** | Frontend (nginx) + Backend (python/flask) + DB (postgres) |
| **Ansible** | Автоматизация установки всех компонентов |
| **Chaos-скрипты** | 4 сценария отказа с автоматическим откатом |

## Сценарии Chaos Engineering

| # | Сценарий | Тип | Описание |
|---|---|---|---|
| 1 | HTTP Latency | Стандартный | Задержка 5s на 50% запросов backend↔frontend |
| 2 | HTTP 500 | Стандартный | 50% запросов к Harbor core возвращают 500 |
| 3 | DB Latency | Стандартный | Задержка 3s между приложением и PostgreSQL |
| 4 | Network Partition | Кастомный | Полный обрыв связи между backend и DB |

Каждый сценарий: демонстрация до → внедрение ошибки → демонстрация после → откат.

## Структура

```
mtc-devops/
├── site.yml                  # Главный playbook (одна команда — весь стенд)
├── inventory.yml             # Инвентарь (localhost по умолчанию)
├── roles/
│   ├── docker/               # Установка Docker
│   ├── k3s/                  # Установка k3s
│   ├── istio/                # Установка Istio + включение injection
│   ├── harbor/               # Установка Harbor (1 реплика)
│   └── app/                  # Деплой sample app
├── manifests/
│   ├── app/                  # K8s манифесты приложения
│   ├── harbor/               # Harbor Helm values
│   └── istio-base/           # Базовые Istio ресурсы (Gateway, DestinationRule)
├── chaos/                    # Bash-скрипты chaos-сценариев
│   ├── 01-http-latency.sh
│   ├── 02-http-500.sh
│   ├── 03-db-latency.sh
│   ├── 04-network-partition.sh
│   └── run-all.sh
├── docs/
│   ├── CHAOS_RESEARCH.md     # Анализ сценариев отказа
│   └── architecture.md       # Описание архитектуры
└── README.md
```

## Демонстрация

После `site.yml` откройте:

- **Harbor UI:** `http://<VM-IP>:30002` (admin/Harbor12345)
- **Приложение:** `http://<VM-IP>:30080`

Chaos-скрипты запускаются интерактивно с паузами для проверки:

```bash
./chaos/01-http-latency.sh
```

## Требования к ВМ

- Ubuntu 22.04 amd64
- 8+ GB RAM (рекомендуется 8-16 GB)
- 4+ vCPU
- 40 GB свободного места
- SSH-доступ с пользователем в группе sudoers
