#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Запуск всех chaos-сценариев последовательно
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CHAOS ENGINEERING DEMO — все сценарии                  ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Сценарии:"
echo "  1. HTTP Latency — задержка backend (стандартный)"
echo "  2. HTTP 500 — Harbor core ошибки (стандартный)"
echo "  3. DB Latency — задержка БД (стандартный)"
echo "  4. Network Partition — обрыв backend↔DB (кастомный)"
echo ""
echo "Каждый сценарий:"
echo "  1. Демонстрация работы приложения"
echo "  2. Пауза для ручной проверки"
echo "  3. Внедрение ошибки"
echo "  4. Демонстрация деградации"
echo "  5. Пауза"
echo "  6. Откат изменений"
echo ""

# Проверка зависимостей
if ! command -v kubectl &>/dev/null; then
    echo "✗ kubectl не найден. Установите k3s/kubectl сначала."
    exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "✗ Kubernetes кластер недоступен. Запустите site.yml сначала."
    exit 1
fi

# Запуск сценариев
for script in \
    "${SCRIPT_DIR}/01-http-latency.sh" \
    "${SCRIPT_DIR}/02-http-500.sh" \
    "${SCRIPT_DIR}/03-db-latency.sh" \
    "${SCRIPT_DIR}/04-network-partition.sh"; do
    
    if [ -f "${script}" ]; then
        echo ""
        echo "──────────────────────────────────────────────────────────"
        bash "${script}"
        echo "──────────────────────────────────────────────────────────"
        
        if [ "${script}" != "${SCRIPT_DIR}/04-network-partition.sh" ]; then
            echo ""
            echo "Нажмите Enter для следующего сценария..."
            read -r
        fi
    else
        echo "⚠ Скрипт не найден: ${script}"
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ВСЕ СЦЕНАРИИ ЗАВЕРШЕНЫ                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Все fault injection откачены. Кластер в нормальном состоянии."
