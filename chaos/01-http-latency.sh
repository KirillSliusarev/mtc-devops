#!/usr/bin/env bash
# Сценарий 1: HTTP Latency — задержка HTTP-ответа от backend.
# Istio VirtualService с fault.delay на gateway VirtualService (demo-vs).
# Envoy ingress-gateway задерживает все запросы к /api/ на 3с.
# На Grafana (Panel "Backend P95 Response Time") виден spike P95.

NAMESPACE="demo-app"
DELAY="3s"
PERCENT="100"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 1: HTTP Latency (Istio fault injection, ${DELAY}) ==="
echo ""
echo "Откройте в браузере:"
echo "  Приложение: http://$(hostname -I | awk '{print $1}'):30133"
echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):30000  (Panel: Backend P95 Response Time)"
echo ""
echo "Текущее состояние:"
echo "  Backend отвечает за ~15ms"
echo ""
echo "Нажмите Enter для внедрения задержки..."
read -r

echo "Применение Istio VirtualService fault.delay (${DELAY}, ${PERCENT}%)..."
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
sleep 5

echo ""
echo "Задержка активна. Запросы к /api/ идут ~${DELAY}."
echo ""
echo "Нажмите Enter для отката..."
read -r

# Откат к стандартному demo-vs
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
echo "Задержка снята. Запросы снова ~15ms."
echo ""
echo "Сценарий 1 завершён."
