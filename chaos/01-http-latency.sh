#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 1: HTTP Latency — задержка ответа backend
# Тип: Стандартный
# =============================================================================
# Вносит задержку 5 секунд на 50% запросов между frontend и backend.
# Демонстрирует: как задержка одного компонента деградирует весь UX.
# =============================================================================

NAMESPACE="demo-app"
DELAY="5s"
PERCENT="50"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 1: HTTP Latency (backend)                      ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""
echo "Конфигурация:"
echo "  - Задержка: ${DELAY}"
echo "  - Процент затронутых запросов: ${PERCENT}%"
echo ""

# --- ДО внедрения ошибки ---
echo "▶ ФАЗА 1: Проверка ДО внедрения ошибки"
echo "  Проверяем доступность backend..."
if kubectl get svc -n "${NAMESPACE}" backend >/dev/null 2>&1; then
    echo "  ✓ Backend Service существует"
    kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
        curl -s -o /dev/null -w "  Время ответа: %{time_total}s\nHTTP код: %{http_code}\n" \
        http://backend:5000/ || echo "  (ожидаемо — python http.server)"
fi
echo ""
echo "  >>> Откройте приложение и проверьте что оно работает <<<"
echo "  >>> Нажмите Enter чтобы продолжить <<<"
read -r

# --- Применение Istio fault injection ---
echo "▶ ФАЗА 2: Внедрение задержки через Istio VirtualService..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: backend-latency
  namespace: ${NAMESPACE}
spec:
  hosts:
  - backend
  http:
  - fault:
      delay:
        percentage:
          value: ${PERCENT}
        fixedDelay: ${DELAY}
    route:
    - destination:
        host: backend
        port:
          number: 5000
EOF
echo "  ✓ Istio VirtualService 'backend-latency' применён"
echo ""

# --- ПОСЛЕ внедрения ошибки ---
echo "▶ ФАЗА 3: Проверка ПОСЛЕ внедрения ошибки"
echo "  Проверяем задержку..."
for i in 1 2 3 4 5; do
    kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
        curl -s -o /dev/null -w "  Запрос ${i}: %{time_total}s (HTTP %{http_code})\n" \
        http://backend:5000/ || true
done
echo ""
echo "  >>> Откройте приложение — страница будет грузиться медленно <<<"
echo "  >>> Нажмите Enter чтобы откатить <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Откат изменений"
kubectl delete virtualservice backend-latency -n "${NAMESPACE}" --ignore-not-found
echo "  ✓ VirtualService удалён, задержка снята"
echo ""

# --- Проверка после отката ---
echo "▶ Проверка после отката:"
kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
    curl -s -o /dev/null -w "  Время ответа: %{time_total}s\n" \
    http://backend:5000/ || true
echo ""
echo "✓ Сценарий 1 завершён"
