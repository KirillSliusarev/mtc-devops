#!/usr/bin/env bash
# (no set -e: read returns non-zero on EOF)

# =============================================================================
# Сценарий 1: HTTP Latency — задержка ответа frontend→backend
# Модифицирует gateway VirtualService (demo-vs) для fault injection
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
cat <<EOF | kubectl apply -f -
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
echo "Готово!"
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 ~50% запросов к /api/ будут идти 5+ секунд"
echo "  📈 Grafana → Istio Service: spike p95 latency"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

# Откат
cat <<EOF | kubectl apply -f -
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
echo "Задержка снята."
echo ""
echo "✓ Сценарий 1 завершён"
