#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 4: Network Partition — полный обрыв backend ↔ DB
# Кастомный.
# =============================================================================

NAMESPACE="demo-app"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 4: Network Partition (backend ↔ DB)           ║"
echo "║  [КАСТОМНЫЙ]                                            ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  📊 Приложение:  http://<VM-IP>:30133"
echo "  📈 Grafana:     http://<VM-IP>:30000  → Istio Workload Dashboard"
echo ""
echo "Что должно быть видно сейчас:"
echo "  - DB: connected (зелёный)"
echo "  - Backend пишет в БД (Insert ID растёт)"
echo ""
echo ">>> Нажми Enter чтобы ОБОРВАТЬ связь с DB <<<"
read -r

echo "Обрыв связи: DENY ALL трафика к DB..."
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
echo "Готово! Связь с DB полностью разорвана."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  📊 Приложение: DB: error (красный) — backend не может записать в БД"
echo "  📈 Grafana → Istio Workload: трафик к db = 0, ошибки 100%"
echo ""
echo ">>> Нажми Enter чтобы восстановить связь <<<"
read -r

kubectl delete authorizationpolicy deny-all-to-db -n "${NAMESPACE}" --ignore-not-found
sleep 5
echo "Связь восстановлена."
echo ""
echo "Проверь: DB снова connected (зелёный)."
echo ""
echo "✓ Сценарий 4 завершён"
