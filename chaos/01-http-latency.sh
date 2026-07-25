#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 1: HTTP Latency — задержка ответа backend
# =============================================================================

NAMESPACE="demo-app"
DELAY="5s"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 1: HTTP Latency (frontend → backend)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30080"
echo "  📈 Grafana:     http://<VM-IP>:30000  → Chaos Engineering → Istio Service Dashboard"
echo ""
echo "Что должно быть видно сейчас:"
echo "  - Страница обновляется каждые 2с"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10ms"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

echo "Внедрение задержки: ${DELAY} на ${PERCENT}% запросов..."
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
echo "  📊 Приложение: страница обновляется РАЗ В 5+ СЕКУНД (вместо 2с)"
echo "  📈 Grafana → Istio Service: красный spike p95 latency до 5s"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice backend-latency -n "${NAMESPACE}" --ignore-not-found
echo "Задержка снята."
echo ""
echo "Проверь: приложение снова быстрое, latency в норме."
echo ""
echo "✓ Сценарий 1 завершён"
