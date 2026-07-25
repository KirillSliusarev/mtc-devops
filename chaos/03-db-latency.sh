#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 3: DB Latency — задержка между backend и PostgreSQL
# Mesh-level fault injection на backend (влияет на /api/ через gateway)
# =============================================================================

NAMESPACE="demo-app"
DELAY="3s"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Сценарий 3: DB Latency (backend → PostgreSQL)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Istio Service Dashboard"
echo ""
echo "Что видно сейчас:"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10-20ms"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

echo "Внедрение задержки ${DELAY} на ВСЕ запросы к backend..."
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
          value: 100
        fixedDelay: ${DELAY}
    route:
    - destination:
        host: backend
        port:
          number: 5000
EOF
echo "Готово!"
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB response вырастет до ~3000ms+"
echo "  📈 Grafana → Istio Service: spike latency"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice backend-latency -n "${NAMESPACE}" --ignore-not-found
echo "Задержка снята."
echo ""
echo "✓ Сценарий 3 завершён"
