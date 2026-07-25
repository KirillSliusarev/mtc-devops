#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 4: Network Partition — полный обрыв backend ↔ DB
# Кастомный. AuthorizationPolicy DENY всех подключений к DB.
# =============================================================================

NAMESPACE="demo-app"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 4: Network Partition (backend ↔ DB)           ║"
echo "║  [КАСТОМНЫЙ]                                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# --- ДО ---
echo "▶ ФАЗА 1: DB работает — backend пишет в БД"
kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
    curl -s http://backend:5000/api/status 2>&1
echo ""

echo "  >>> Нажмите Enter для обрыва связи <<<"
read -r

# --- DENY ALL трафика к DB ---
echo "▶ ФАЗА 2: Обрыв связи (DENY all → DB)"
cat <<EOF | kubectl apply -f -
apiVersion: security.istio.io/v1beta1
kind: AuthorizationPolicy
metadata:
  name: deny-all-to-db
  namespace: ${NAMESPACE}
spec:
  selector:
    matchLabels:
      app: db
  action: DENY
  rules:
  - {}
EOF
sleep 3
echo "  ✓ AuthorizationPolicy DENY ALL применён"
echo ""

# --- ПОСЛЕ ---
echo "▶ ФАЗА 3: Backend не может подключиться к DB"
for i in 1 2 3; do
    echo "  Попытка $i:"
    kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
        curl -s http://backend:5000/api/status 2>&1 | head -3
    sleep 1
done
echo ""
echo "  >>> Backend отдаёт 503 — DB недоступна <<<"
echo "  >>> Нажмите Enter для восстановления <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Восстановление"
kubectl delete authorizationpolicy deny-all-to-db -n "${NAMESPACE}" --ignore-not-found
sleep 5
echo "  ✓ Связь восстановлена"
echo ""

# Проверка
kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
    curl -s http://backend:5000/api/status 2>&1
echo ""
echo "✓ Сценарий 4 завершён"
