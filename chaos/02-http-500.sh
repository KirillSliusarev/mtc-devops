#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 2: HTTP 500 — Harbor core возвращает ошибки
# =============================================================================

HARBOR_NS="harbor"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 2: HTTP 500 (Harbor core)                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "ОТКРОЙ В БРАУЗЕРЕ:"
echo "  🐳 Harbor UI:   http://<VM-IP>:30002  (admin / Harbor12345)"
echo "  📈 Grafana:     http://<VM-IP>:30000  → Istio Service Dashboard"
echo ""
echo "Что должно быть видно сейчас:"
echo "  - Harbor UI открывается нормально"
echo "  - Можешь залогиниться (admin / Harbor12345)"
echo ""
echo ">>> Нажми Enter чтобы внедрить HTTP 500 <<<"
read -r

echo "Внедрение HTTP 500: ${PERCENT}% запросов к harbor-core..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: harbor-core-500
  namespace: ${HARBOR_NS}
spec:
  hosts:
  - harbor-core
  http:
  - fault:
      abort:
        percentage:
          value: ${PERCENT}
        httpStatus: 500
    route:
    - destination:
        host: harbor-core
        port:
          number: 80
EOF
echo "Готово! HTTP 500 активен."
echo ""
echo "СМОТРИ В БРАУЗЕР:"
echo "  🐳 Harbor UI: обнови страницу (F5) несколько раз — половина запросов упадёт с 500"
echo "  📈 Grafana → Istio Service: рост error rate"
echo ""
echo ">>> Нажми Enter чтобы откатить <<<"
read -r

kubectl delete virtualservice harbor-core-500 -n "${HARBOR_NS}" --ignore-not-found
echo "HTTP 500 снят."
echo ""
echo "Проверь: Harbor снова работает."
echo ""
echo "✓ Сценарий 2 завершён"
