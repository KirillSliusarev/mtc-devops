#!/usr/bin/env bash
# NO set -e

# =============================================================================
# Сценарий 1: HTTP Latency — задержка HTTP-ответа backend
# Mesh-level VirtualService delay на host=backend (sidecar перехватывает)
# Это добавляет задержку к HTTP-ответу ОТ backend.
# P95 Response Time на Grafana чётко покажет spike.
# =============================================================================

NAMESPACE="demo-app"
DELAY="5s"
PERCENT="100"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 1: HTTP Latency (frontend → backend)          ║"
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

echo "Внедрение задержки ${DELAY} на все запросы к backend..."
# Mesh-level VirtualService: Istio sidecar applies delay on inbound traffic to backend
kubectl apply -f - <<EOF
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
sleep 5

echo "Готово! Задержка ${DELAY} активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: загрузка займёт ~${DELAY}"
echo "  📈 Grafana → Chaos Engineering Demo → Backend P95 Response Time:"
echo "     spike до ~${DELAY}"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice backend-latency -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
sleep 3
echo "Задержка снята."
echo ""
echo "✓ Сценарий 1 завершён"
