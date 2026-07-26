#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 3: DB Latency — задержка TCP-соединений backend→PostgreSQL
# Использует tc netem (traffic control) внутри backend контейнера.
# Backend имеет capability NET_ADMIN для управления qdisc.
# Это РЕАЛЬНАЯ сетевая задержка на TCP-уровне, влияет только на DB-запросы.
# =============================================================================

NAMESPACE="demo-app"
DELAY_MS="3000"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  Сценарий 3: DB Latency (backend → PostgreSQL)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Chaos Engineering Demo"
echo ""
echo "Что видно сейчас:"
echo "  - DB: connected (зелёный)"
echo "  - DB response: ~10-20ms"
echo ""
echo ">>> Нажми Enter чтобы внедрить задержку <<<"
read -r

BACKEND_POD=$(kubectl get pods -n "${NAMESPACE}" -l app=backend -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

echo "Внедрение задержки ${DELAY_MS}ms на TCP-трафик в backend pod..."
echo "  Backend pod: ${BACKEND_POD}"

# Install tc and apply netem delay
kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -c backend -- sh -c '
    which tc >/dev/null 2>&1 || (apt-get update -qq >/dev/null 2>&1 && apt-get install -y -qq iproute2 >/dev/null 2>&1)
    tc qdisc add dev eth0 root netem delay '"${DELAY_MS}"'ms 2>/dev/null || \
    tc qdisc change dev eth0 root netem delay '"${DELAY_MS}"'ms
'

sleep 3
echo "Готово! Задержка ${DELAY_MS}ms активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB response вырастет до ~${DELAY_MS}ms (значение в JSON)"
echo "  📈 Grafana → Chaos Engineering Demo: P95 Response Time spike"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

# Rollback
kubectl exec -n "${NAMESPACE}" "${BACKEND_POD}" -c backend -- sh -c 'tc qdisc del dev eth0 root 2>/dev/null || true'

sleep 3
echo "Задержка снята."
echo ""
echo "✓ Сценарий 3 завершён"
