#!/usr/bin/env bash
# Сценарий 1: HTTP Latency — задержка ответа backend.
# Backend получает env DB_DELAY_MS=3000 и задерживает каждый запрос на 3с.
# Симулирует медленный upstream (например, тяжёлые вычисления или I/O).
# На Grafana (Chaos Engineering Demo, Panel "Backend P95 Response Time")
# виден spike P95 до ~3000ms.

NAMESPACE="demo-app"
DELAY_MS="3000"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 1: HTTP Latency (backend, ${DELAY_MS}ms) ==="
echo ""
echo "Откройте в браузере:"
echo "  Приложение: http://$(hostname -I | awk '{print $1}'):30133"
echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):30000  (Panel: Backend P95 Response Time)"
echo ""
echo "Текущее состояние:"
echo "  Backend отвечает за ~15ms (см. db_response_ms на странице приложения)"
echo ""
echo "Нажмите Enter для внедрения задержки..."
read -r

echo "Установка DB_DELAY_MS=${DELAY_MS} на backend..."
kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="${DELAY_MS}"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3

echo ""
echo "Задержка активна. db_response_ms должен вырасти до ~${DELAY_MS}ms."
echo ""
echo "Нажмите Enter для отката..."
read -r

kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="0"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3
echo "Задержка снята. db_response_ms должен вернуться к ~15ms."
echo ""
echo "Сценарий 1 завершён."
