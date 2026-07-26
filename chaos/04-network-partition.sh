#!/usr/bin/env bash
# Сценарий 4: Network Partition — обрыв связи backend с DB.
# Кастомный сценарий. AuthorizationPolicy DENY блокирует TCP-трафик
# от backend к DB на порт 5432. Backend не может выполнять запросы к PostgreSQL.
# На Grafana (Panel "Backend Success vs Error Rate") error rate растёт до 100%.
# Симулирует сетевой раздел между уровнями приложения.

NAMESPACE="demo-app"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 4: Network Partition (backend <-> DB) [КАСТОМНЫЙ] ==="
echo ""
echo "Откройте в браузере:"
echo "  Приложение: http://$(hostname -I | awk '{print $1}'):30133"
echo "  Grafana:    http://$(hostname -I | awk '{print $1}'):30000  (Panel: Backend Success vs Error Rate)"
echo ""
echo "Текущее состояние:"
echo "  DB: connected (зелёный), Insert ID растёт"
echo ""
echo "Нажмите Enter для обрыва связи с DB..."
read -r

echo "Применение AuthorizationPolicy DENY для backend -> DB:5432..."
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
echo ""
echo "Связь с DB разорвана. На странице приложения: DB: error (красный)."
echo ""
echo "Нажмите Enter для восстановления связи..."
read -r

kubectl delete authorizationpolicy deny-backend-to-db -n "${NAMESPACE}" --ignore-not-found 2>/dev/null
sleep 5
echo "Связь восстановлена. DB снова connected (зелёный)."
echo ""
echo "Сценарий 4 завершён."
