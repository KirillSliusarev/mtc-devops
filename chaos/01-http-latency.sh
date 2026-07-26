#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 1: HTTP Latency — задержка ответа frontend→backend
# Fault injection через gateway VirtualService (demo-vs)
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

echo "Внедрение задержки ${DELAY} на ${PERCENT}% запросов..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-vs
  namespace: ${NAMESPACE}
spec:
  hosts: ['*']
  gateways: ['istio-system/demo-gateway']
  http:
  - match: [{uri: {prefix: /api/}}]
    fault:
      delay:
        percentage: {value: ${PERCENT}}
        fixedDelay: ${DELAY}
    route:
    - destination: {host: backend, port: {number: 5000}}
  - match: [{uri: {prefix: /health}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - route:
    - destination: {host: frontend, port: {number: 80}}
EOF

# Wait for envoy config to propagate
sleep 5

echo "Готово! Задержка активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 ~50% запросов к /api/ будут идти 5+ секунд"
echo "  📈 Grafana → Istio Service: spike p95 latency"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

# Откат
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: demo-vs
  namespace: ${NAMESPACE}
spec:
  hosts: ['*']
  gateways: ['istio-system/demo-gateway']
  http:
  - match: [{uri: {prefix: /api/}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - match: [{uri: {prefix: /health}}]
    route:
    - destination: {host: backend, port: {number: 5000}}
  - route:
    - destination: {host: frontend, port: {number: 80}}
EOF

sleep 3
echo "Задержка снята."
echo ""
echo "✓ Сценарий 1 завершён"
