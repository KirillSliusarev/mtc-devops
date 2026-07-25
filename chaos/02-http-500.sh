#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 2: HTTP 500 — Harbor core возвращает ошибки
# Fault injection через mesh-level VirtualService на harbor-core
# Тестируется через kubectl exec (portal → core = mesh traffic)
# =============================================================================

HARBOR_NS="harbor"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 2: HTTP 500 (Harbor core)                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  🐳 Harbor UI:   http://<VM-IP>:30002  (admin / Harbor12345)"
echo "  📈 Grafana:     http://<VM-IP>:30000 → Istio Service Dashboard"
echo ""
echo "Что видно сейчас: Harbor открывается, логин работает."
echo ""
echo ">>> Нажми Enter чтобы внедрить HTTP 500 <<<"
read -r

echo "Внедрение HTTP 500 на ${PERCENT}% запросов к harbor-core..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: harbor-core-500
  namespace: ${HARBOR_NS}
spec:
  hosts: [harbor-core]
  http:
  - fault:
      abort:
        percentage: {value: ${PERCENT}}
        httpStatus: 500
    route:
    - destination: {host: harbor-core, port: {number: 80}}
EOF
echo "Готово!"
echo ""

echo "Проверка (frontend → harbor-core = mesh traffic):"
for i in 1 2 3 4 5 6; do
    CODE=$(kubectl exec -n demo-app deployment/frontend -c frontend -- \
        wget -S -q -O /dev/null http://harbor-core.harbor.svc.cluster.local:80/ 2>&1 | \
        grep 'HTTP/' | tail -1 | awk '{print $2}')
    echo "  Запрос ${i}: HTTP ${CODE}"
done
echo ""

echo "СМОТРИ В БРАУЗЕР:"
echo "  🐳 Harbor UI: обнови страницу (F5) несколько раз — будут ошибки"
echo "  📈 Grafana → Istio Service: рост error rate"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice harbor-core-500 -n "${HARBOR_NS}" --ignore-not-found
echo "HTTP 500 снят."
echo ""
echo "✓ Сценарий 2 завершён"
