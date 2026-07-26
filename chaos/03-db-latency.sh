#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 3: DB Latency — задержка DB-запросов
# Применяется через env DB_DELAY_MS на backend deployment.
# Backend искусственно задерживает каждый DB-запрос на DB_DELAY_MS миллисекунд.
# В реальном мире это симулирует медленную БД (disk I/O, lock contention).
# =============================================================================

NAMESPACE="demo-app"
DELAY_MS="2000"

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

echo "Внедрение задержки ${DELAY_MS}ms на каждый DB-запрос..."
kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="${DELAY_MS}"
echo "Ждём рестарта backend..."
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s

echo "Готово! Задержка ${DELAY_MS}ms активна."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB response вырастет до ~${DELAY_MS}ms"
echo "  📈 Grafana → Chaos Engineering Demo: P95 Response Time spike"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl set env deployment/backend -n "${NAMESPACE}" DB_DELAY_MS="0"
kubectl rollout status deployment/backend -n "${NAMESPACE}" --timeout=60s
sleep 3
echo "Задержка снята."
echo ""
echo "✓ Сценарий 3 завершён"
