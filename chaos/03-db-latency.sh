#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# Сценарий 3: DB Latency — задержка между backend и PostgreSQL
# Стандартный. Backend РЕАЛЬНО подключается к БД, так что задержка видна.
# =============================================================================

NAMESPACE="demo-app"
DELAY="3s"

echo "╔══════════════════════════════════════════════════════════╗"
echo "║  СЦЕНАРИЙ 3: DB Latency (backend → PostgreSQL)          ║"
echo "╚══════════════════════════════════════════════════════════╝"
echo ""

# --- ДО ---
echo "▶ ФАЗА 1: Проверка ДО — DB запрос работает"
for i in 1 2 3; do
    kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
        curl -s http://backend:5000/api/status 2>/dev/null | \
        grep -o '"db_response_ms": [0-9]*' || echo "  Попытка $i: ошибка"
done
echo ""

echo "  >>> Нажмите Enter чтобы внедрить задержку <<<"
read -r

# --- Istio fault injection: задержка на HTTP-запросы к backend ---
# (источник задержки — DB, ноIstio инъецирует на HTTP-уровне)
echo "▶ ФАЗА 2: Внедрение задержки ${DELAY} через Istio..."
cat <<EOF | kubectl apply -f -
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: db-latency
  namespace: ${NAMESPACE}
spec:
  hosts:
  - backend
  http:
  - fault:
      delay:
        percentage:
          value: 100
        fixedDelay: ${DELAY}
    route:
    - destination:
        host: backend
        port:
          number: 5000
EOF
echo "  ✓ Задержка ${DELAY} применена"
echo ""

# --- ПОСЛЕ ---
echo "▶ ФАЗА 3: Проверка ПОСЛЕ — ожидаем задержку в ответе"
for i in 1 2 3; do
    kubectl exec -n "${NAMESPACE}" deployment/frontend -- \
        curl -s -o /dev/null -w "  Запрос $i: %{time_total}s (HTTP %{http_code})\n" \
        http://backend:5000/api/status 2>/dev/null
done
echo ""
echo "  >>> Приложение отвечает медленно. Проверьте в браузере <<<"
echo "  >>> Нажмите Enter для отката <<<"
read -r

# --- Откат ---
echo "▶ ФАЗА 4: Откат"
kubectl delete virtualservice db-latency -n "${NAMESPACE}" --ignore-not-found
echo "  ✓ Задержка снята"
echo ""
echo "✓ Сценарий 3 завершён"
