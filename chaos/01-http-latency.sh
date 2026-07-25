#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 1: HTTP Latency — задержка ответа frontend→backend
# Mesh-level fault injection: применяет VS на host=backend
# Это влияет на ВЕСЬ трафик к backend (из gateway, из frontend, отовсюду)
# =============================================================================

NAMESPACE="demo-app"
DELAY="5s"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 1: HTTP Latency (frontend → backend)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Istio Service Dashboard"
echo ""
echo "Что видно сейчас:"
echo "  - Страница обновляется каждые 2с"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10-20ms"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

echo "Внедрение задержки ${DELAY} на ${PERCENT}% запросов к backend..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-latency
  namespace: ${NAMESPACE}
spec:
  hosts:
  - backend
  http:
  - fault:
      delay:
        percentage:
          value: ${PERCENT}
        fixedDelay: ${DELAY}
    route:
    - destination:
        host: backend
        port:
          number: 5000
EOF
echo "Готово! Задержка активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: ~50% запросов к /api/ будут идти 5+ секунд"
echo "  📈 Grafana → Istio Service: spike p95 latency до 5s"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice backend-latency -n "${NAMESPACE}" --ignore-not-found
echo "Задержка снята."
echo ""
echo "✓ Сценарий 1 завершён"
