#!/usr/bin/env bash
# Сценарий 1: HTTP Latency — замедление ответа backend.
# Backend получает env RESPONSE_DELAY_MS=3000 и задерживает HTTP-ответ на 3с
# перед обработкой запроса. Симулирует медленный upstream (GC pause, CPU throttle).
# На Grafana (Panel "Backend P95 Response Time") виден spike P95 до ~3000ms.
# Отличается от S3: задержка на уровне HTTP-обработчика, а не DB-запроса.

NAMESPACE="demo-app"
DELAY_MS="3000"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 1: HTTP Latency (backend response, ${DELAY_MS}ms) ==="
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

echo "Установка RESPONSE_DELAY_MS=${DELAY_MS} на backend..."
kubectl set env deployment/backend -n "${NAMESPACE}" RESPONSE_DELAY_MS="${DELAY_MS}"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3

echo ""
echo "Задержка активна. HTTP-ответ занимает ~${DELAY_MS}ms."
echo "На странице db_response_ms остаётся ~15ms (DB не затронута)."
echo ""
echo "Нажмите Enter для отката..."
read -r

kubectl set env deployment/backend -n "${NAMESPACE}" RESPONSE_DELAY_MS="0"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s 2>/dev/null
sleep 3
echo "Задержка снята. Ответ снова ~15ms."
echo ""
echo "Сценарий 1 завершён."
