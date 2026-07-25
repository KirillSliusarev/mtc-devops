#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 3: DB Latency — задержка между backend и PostgreSQL
# =============================================================================

NAMESPACE="demo-app"
DELAY="3s"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 3: DB Latency (backend → PostgreSQL)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30080"
echo "  📈 Grafana:     http://<VM-IP>:30000  → Istio Workload Dashboard"
echo ""
echo "Что должно быть видно сейчас:"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10ms"
echo "  - Insert ID растёт"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

echo "Внедрение задержки: ${DELAY} на все запросы к backend..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: db-latency
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
echo "Готово! Задержка активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB response вырастет до ~3000ms"
echo "  📈 Grafana → Istio Workload: красный spike latency"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice db-latency -n "${NAMESPACE}" --ignore-not-found
echo "Задержка снята."
echo ""
echo "Проверь: DB response снова ~10ms."
echo ""
echo "✓ Сценарий 3 завершён"
