#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 4: Network Partition — полный обрыв backend ↔ DB
# Тип: Кастомный (свой сценарий)
# =============================================================================
# Полный разрыв сетевого соединения между backend и PostgreSQL.
# Демонстрирует: поведение приложения при потере БД (timeout, retry, fallback).
# В отличие от latency (частичная деградация), partition — полная недоступность.
#
# Реализация: Istio AuthorizationPolicy DENY-all от backend к db:5432
# =============================================================================

NAMESPACE="demo-app"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 4: Network Partition (backend ↔ DB)            ║"
echo "║  [КАСТОМНЫЙ СЦЕНАРИЙ]                                    ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Описание:"
echo "  Полный обрыв связи между backend и PostgreSQL через Istio"
echo "  AuthorizationPolicy (DENY all traffic от backend к db)."
echo ""
echo "Реальные сценарии:"
echo "  - Сетевой сбой между availability zones"
echo "  - Ошибка firewall/security group"
echo "  - Отказ сетевого оборудования (switch, router)"
echo "  - BGP route flap — временная потеря маршрутизации"
echo ""

# --- ДО ---
echo "▶ ФАЗА 1: Проверка ДО внедрения ошибки"
echo "  Проверяем доступность DB из backend..."
kubectl exec -n "${NAMESPACE}" deployment/backend -- \
    python3 -c "import socket; s=socket.create_connection(('db',5432),timeout=2); print('  ✓ DB доступна: TCP соединение успешно'); s.close()" 2>/dev/null || \
    echo "  (проверка пропущена)"
echo ""
echo "  >>> Проверьте приложение — всё работает <<<"
echo "  >>> Нажмите Enter для обрыва связи <<<"
read -r

# --- Применение: AuthorizationPolicy DENY ---
echo "▶ ФАЗА 2: Обрыв связи (AuthorizationPolicy DENY backend→db)..."
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-backend-to-db
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      app: db
  action: DENY
  rules:
  - from:
    - source:
        principals: ["cluster.local/ns/${NAMESPACE}/sa/default"]
    to:
    - operation:
        ports: ["5432"]
EOF
echo "  ✓ AuthorizationPolicy 'deny-backend-to-db' применён"
echo "  Весь трафик от backend к DB:5432 теперь DENIED"
echo ""

# Дополнительно: deny через VirtualService abort для HTTP-трафика
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: db-partition
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
EOF
echo "  ✓ VirtualService 'db-partition' применён"
echo ""

# --- ПОСЛЕ ---
echo "▶ ФАЗА 3: Проверка ПОСЛЕ обрыва связи"
echo "  Пытаемся подключиться к DB из backend..."
for i in 1 2 3; do
    kubectl exec -n "${NAMESPACE}" deployment/backend -- \
        python3 -c "
import socket, sys
try:
    s = socket.create_connection(('db', 5432), timeout=5)
    print('  Попытка ${i}: соединение УСПЕШНО (partition не сработал?)')
    s.close()
except Exception as e:
    print(f'  Попытка ${i}: СОЕДИНЕНИЕ РАЗОРВАНО — {type(e).__name__}')
" 2>/dev/null || echo "  Попытка ${i}: СОЕДИНЕНИЕ РАЗОРВАНО (timeout/refused)"
done
echo ""
echo "  >>> Приложение не сможет работать с БД <<<"
echo "  >>> Будут видны ошибки 500, таймауты, retry <<<"
echo "  >>> Нажмите Enter для восстановления <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Восстановление связи"
kubectl delete authorizationpolicy deny-backend-to-db -n "${NAMESPACE}" --ignore-not-found
kubectl delete virtualservice db-partition -n "${NAMESPACE}" --ignore-not-found
echo "  ✓ AuthorizationPolicy и VirtualService удалены"
echo ""

# --- Проверка восстановления ---
echo "▶ Проверка после восстановления:"
kubectl exec -n "${NAMESPACE}" deployment/backend -- \
    python3 -c "import socket; s=socket.create_connection(('db',5432),timeout=2); print('  ✓ DB снова доступна'); s.close()" 2>/dev/null || \
    echo "  (может потребоваться несколько секунд для восстановления)"
echo ""
echo "✓ Сценарий 4 завершён"
echo ""
echo "Выводы (см. CHAOS_RESEARCH.md):"
echo "  - Network partition — самая разрушительная failure mode"
echo "  - Без retry/timeout в приложении → полная нереспонсивность"
echo "  - Рекомендация: circuit breaker (Istio DestinationRule outlierDetection)"
