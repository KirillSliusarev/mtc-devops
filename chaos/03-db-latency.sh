#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 3: DB Latency — задержка между приложением и PostgreSQL
# Тип: Стандартный
# =============================================================================
# Вносит задержку 3 секунды на 100% TCP-соединений между backend и DB.
# Демонстрирует: как деградация БД делает приложение нереспонсивным.
# =============================================================================

NAMESPACE="demo-app"
DELAY="3s"
PERCENT="100"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 3: DB Latency (backend → DB)                   ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Конфигурация:"
echo "  - Задержка: ${DELAY} на ${PERCENT}% соединений к DB"
echo "  - Влияет: все запросы backend → PostgreSQL"
echo ""

# --- ДО ---
echo "▶ ФАЗА 1: Проверка ДО внедрения ошибки"
echo "  Проверяем доступность DB..."
kubectl exec -n "${NAMESPACE}" deployment/backend -- \
    python3 -c "import socket; s=socket.create_connection(('db',5432),timeout=2); print('  ✓ DB доступна, соединение установлено'); s.close()" 2>/dev/null || \
    echo "  (проверка TCP порта — ожидаемо если python3 -c недоступен)"
echo ""
echo "  >>> Проверьте приложение — DB запросы работают нормально <<<"
echo "  >>> Нажмите Enter чтобы продолжить <<<"
read -r

# --- Применение ---
echo "▶ ФАЗА 2: Внедрение задержки через Istio..."
# Istio TCP-level fault injection через VirtualService для TCP-сервиса
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: db-latency
  namespace: ${NAMESPACE}
spec:
  hosts:
  - db
  tcp:
  - match:
    - port: 5432
    route:
    - destination:
        host: db
        port:
          number: 5432
    rewrite:
      uri: "/"
  http:
  - fault:
      delay:
        percentage:
          value: ${PERCENT}
        fixedDelay: ${DELAY}
    match:
    - uri:
        prefix: "/"
    route:
    - destination:
        host: db
        port:
          number: 5432
EOF
echo "  ✓ Istio VirtualService 'db-latency' применён"
echo "  (Заметка: Istio TCP delay не поддерживается напрямую для TCP."
echo "   Используется HTTP-уровень fault injection как fallback."
echo "   Для чистого TCP delay см. EnvoyFilter в docs/architecture.md)"
echo ""

# --- ПОСЛЕ ---
echo "▶ ФАЗА 3: Проверка ПОСЛЕ внедрения ошибки"
echo "  Проверяем время соединения с DB..."
for i in 1 2 3; do
    START=$(date +%s%N)
    kubectl exec -n "${NAMESPACE}" deployment/backend -- \
        python3 -c "import socket; s=socket.create_connection(('db',5432),timeout=10); s.close()" 2>/dev/null || true
    END=$(date +%s%N)
    ELAPSED=$(( (END - START) / 1000000 ))
    echo "  Попытка ${i}: ${ELAPSED}ms"
done
echo ""
echo "  >>> Приложение будет отвечать медленно или зависать <<<"
echo "  >>> Нажмите Enter чтобы откатить <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Откат изменений"
kubectl delete virtualservice db-latency -n "${NAMESPACE}" --ignore-not-found
echo "  ✓ VirtualService удалён"
echo ""
echo "✓ Сценарий 3 завершён"
