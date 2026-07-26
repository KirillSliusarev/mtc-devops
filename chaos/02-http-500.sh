#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 2: HTTP 500 — Harbor core недоступен
# Scale down harbour-core deployment до 0 реплик.
# Harbour-nginx вернёт 502/504 Bad Gateway — это реальный сценарий отказа.
# Registry API полностью недоступен, UI показывает ошибки.
# =============================================================================

HARBOR_NS="harbor"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 2: Harbor core недоступен (502)                ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  🐳 Harbor UI:   http://<VM-IP>:30002  (admin / Harbor12345)"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Chaos Engineering Demo"
echo ""
echo "Что видно сейчас: Harbor открывается, логин работает."
echo ""
echo ">>> Нажми Enter чтобы отключить harbour-core <<<"
read -r

echo "Scale down harbour-core до 0 реплик..."
kubectl scale deployment harbor-core -n "${HARBOR_NS}" --replicas=0
echo "Ждём 5 секунд..."
sleep 5

echo "Готово! Harbor core отключён."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  🐳 Harbor UI: обнови страницу — 502 Bad Gateway"
echo "     Попробуй залогиниться — не получится"
echo "  📈 Grafana → Chaos Engineering Demo: Error Rate для harbour-core"
echo ""
echo ">>> Нажми Enter чтобы восстановить <<<"
read -r

kubectl scale deployment harbor-core -n "${HARBOR_NS}" --replicas=1
echo "Ждём восстановления..."
kubectl rollout status deployment/harbor-core -n "${HARBOR_NS}" --timeout=120s 2>/dev/null
echo "Harbor core восстановлен."
echo ""
echo "✓ Сценарий 2 завершён"
