#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Chaos Engineering Demo — запуск всех сценариев
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  CHAOS ENGINEERING DEMO                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОБЯЗАТЕЛЬНО ОТКРОЙ В БРАУЗЕРЕ перед стартом:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  🐳 Harbor UI:   http://<VM-IP>:30002  (admin / Harbor12345)"
echo "  📈 Grafana:     http://<VM-IP>:30000  (admin / admin)"
echo "      → Chaos Engineering → Istio Service / Workload Dashboard"
echo ""
echo "Сценарии:"
echo "  1. HTTP Latency — 5s задержка frontend→backend"
echo "  2. HTTP 500 — Harbor core ошибки 50%"
echo "  3. DB Latency — 3s задержка backend→DB"
echo "  4. Network Partition — обрыв backend↔DB (кастомный)"
echo ""
echo "Каждый сценарий:"
echo "  1) Демонстрация работы приложения (смотри браузер)"
echo "  2) Пауза → внедрение ошибки → пауза (смотри деградацию)"
echo "  3) Откат → проверка восстановления"
echo ""

if ! command -v kubectl &>/dev/null; then
    echo "✗ kubectl не найден. Запусти site.yml сначала."
    exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "✗ Kubernetes недоступен. Запусти site.yml сначала."
    exit 1
fi

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
            echo "Нажми Enter для следующего сценария..."
            read -r
        fi
    fi
done

echo ""
echo "╔══════════════════════════════════════════════════════════╗"
echo "║  ВСЕ СЦЕНАРИИ ЗАВЕРШЕНЫ                                 ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Все ошибки откачены. Проверь в браузере — всё работает."
