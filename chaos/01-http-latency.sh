#!/usr/bin/env bash
# NO set -e

# =============================================================================
# Сценарий 1: HTTP Latency — замедление backend (5s)
# Применяется через env BACKEND_DELAY_MS: backend спит перед HTTP-ответом.
# P95 Response Time на Grafana покажет чёткий spike до ~5000ms.
# Отличается от сценария 3 (DB Latency, 2000ms) по амплитуде.
# =============================================================================

NAMESPACE="demo-app"
DELAY_MS="3000"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 1: HTTP Latency (5s на запрос)                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Chaos Engineering Demo"
echo "  📊 Панель: Backend P95 Response Time"
echo ""
echo "Что видно сейчас:"
echo "  - Страница обновляется каждые 2с"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10-20ms"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

echo "Внедрение задержки ${DELAY_MS}ms на все запросы backend..."
kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="${DELAY_MS}"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3

echo "Готово!"
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: загрузка займёт ~${DELAY_MS}ms"
echo "  📈 Grafana → Chaos Engineering Demo → P95 Response Time:"
echo "     spike до ~${DELAY_MS}ms"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="0"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3
echo "Задержка снята."
echo ""
echo "✓ Сценарий 1 завершён"
