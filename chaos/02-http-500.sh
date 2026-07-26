#!/usr/bin/env bash
# NO set -e: interactive scripts with read must not abort on non-zero

# =============================================================================
# Сценарий 2: HTTP 500 — Harbor core возвращает ошибки
# Fault injection через mesh-level VirtualService на harbor-core
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
kubectl apply -f - <<EOF
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

sleep 5

echo "Готово!"
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  🐳 Harbor UI: обнови страницу (F5) несколько раз — будут ошибки"
echo "  📈 Grafana → Istio Service: рост error rate"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice harbor-core-500 -n "${HARBOR_NS}" --ignore-not-found 2>/dev/null
echo "HTTP 500 снят."
echo ""
echo "✓ Сценарий 2 завершён"
