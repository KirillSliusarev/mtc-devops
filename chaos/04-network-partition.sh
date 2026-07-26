#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 4: Network Partition — обрыв backend ↔ DB
# AuthorizationPolicy DENY для TCP-трафика от backend к DB.
# DENY только от источника backend, не блокирует istio health checks.
# =============================================================================

NAMESPACE="demo-app"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 4: Network Partition (backend ↔ DB)           ║"
echo "║  [КАСТОМНЫЙ]                                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Chaos Engineering Demo"
echo ""
echo "Что должно быть видно сейчас:"
echo "  - DB: connected (зелёный)"
echo "  - Backend пишет в БД (Insert ID растёт)"
echo ""
echo ">>> Нажми Enter чтобы ОБОРВАТЬ связь с DB <<<"
read -r

echo "Обрыв связи: DENY TCP-трафика от backend к DB на порт 5432..."
kubectl apply -f - <<EOF
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

sleep 5
echo "Готово! Трафик backend→DB заблокирован."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB: error (красный) — backend не может записать в БД"
echo "  📈 Grafana → Chaos Engineering Demo: Error Rate spike"
echo ""
echo ">>> Нажми Enter чтобы восстановить связь <<<"
read -r

kubectl delete authorizationpolicy deny-backend-to-db -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
sleep 5
echo "Связь восстановлена."
echo ""
echo "Проверь: DB снова connected (зелёный)."
echo ""
echo "✓ Сценарий 4 завершён"
