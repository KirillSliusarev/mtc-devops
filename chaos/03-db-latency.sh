#!/usr/bin/env bash
# Сценарий 3: DB Latency — задержка DB-запросов.
# Backend получает env DB_DELAY_MS=2000 и спит 2с перед каждым DB-запросом.
# Симулирует медленную БД (disk I/O bottleneck, lock contention).
# На Grafana (Panel "Backend P95 Response Time") виден spike P95 до ~2000ms.
# Отличается от сценария 1 амплитудой задержки (2с vs 3с).

NAMESPACE="demo-app"
DELAY_MS="2000"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 3: DB Latency (backend -> PostgreSQL, ${DELAY_MS}ms) ==="
echo ""
echo "Откройте в браузере:"
echo "  Приложение: http://$(hostname -I | awk '{print $1}'):30133"
echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):30000  (Panel: Backend P95 Response Time)"
echo ""
echo "Текущее состояние:"
echo "  DB-запрос выполняется за ~15ms (см. db_response_ms на странице приложения)"
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
echo "Сценарий 3 завершён."
