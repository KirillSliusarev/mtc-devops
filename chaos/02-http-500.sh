#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 2: HTTP 500 — Harbor core возвращает ошибки
# Тип: Стандартный
# =============================================================================
# 50% запросов к Harbor core возвращают HTTP 500.
# Демонстрирует: как ошибки одного компонента Harbor ломают весь registry.
# =============================================================================

HARBOR_NS="harbor"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 2: HTTP 500 (Harbor core)                     ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Конфигурация:"
echo "  - HTTP 500 на ${PERCENT}% запросов к harbor-core"
echo "  - Влияет: docker push/pull, API, аутентификация"
echo ""

# --- ДО ---
echo "▶ ФАЗА 1: Проверка ДО внедрения ошибки"
echo "  Проверяем Harbor core..."
if kubectl get svc -n "${HARBOR_NS}" harbor-core >/dev/null 2>&1; then
    echo "  ✓ Harbor core Service существует"
    CORE_IP=$(kubectl get svc -n "${HARBOR_NS}" harbor-core -o jsonpath='{.spec.clusterIP}' 2>/dev/null || echo "")
    if [ -n "${CORE_IP}" ]; then
        kubectl exec -n "${HARBOR_NS}" deployment/harbor-core -- \
            curl -s -o /dev/null -w "  Harbor core: HTTP %{http_code}, время: %{time_total}s\n" \
            "http://localhost:80/api/v2.0/health" || true
    fi
else
    echo "  ⚠ Harbor не найден. Убедитесь что role harbor выполнена."
fi
echo ""
echo "  >>> Проверьте Harbor UI (docker login, docker pull) <<<"
echo "  >>> Нажмите Enter чтобы продолжить <<<"
read -r

# --- Применение ---
echo "▶ ФАЗА 2: Внедрение HTTP 500 через Istio..."
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
echo "  ✓ Istio VirtualService 'harbor-core-500' применён"
echo ""

# --- ПОСЛЕ ---
echo "▶ ФАЗА 3: Проверка ПОСЛЕ внедрения ошибки"
for i in 1 2 3 4 5; do
    kubectl exec -n "${HARBOR_NS}" deployment/harbor-core -- \
        curl -s -o /dev/null -w "  Запрос ${i}: HTTP %{http_code}\n" \
        "http://localhost:80/api/v2.0/health" 2>/dev/null || \
        echo "  Запрос ${i}: соединение разорвано (ISTIO 500 injected)"
done
echo ""
echo "  >>> Попробуйте docker login/pull — половина операций упадёт <<<"
echo "  >>> Нажмите Enter чтобы откатить <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Откат изменений"
kubectl delete virtualservice harbor-core-500 -n "${HARBOR_NS}" --ignore-not-found
echo "  ✓ VirtualService удалён"
echo ""
echo "✓ Сценарий 2 завершён"
