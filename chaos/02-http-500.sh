#!/usr/bin/env bash
# Сценарий 2: HTTP 500 — Harbor недоступен.
# EnvoyFilter добавляет HTTP fault abort (500) на inbound-трафик harbour-nginx.
# Все запросы к Harbor UI и API возвращают 500.
# Симулирует полный отказ точки входа в registry.

HARBOR_NS="harbor"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 2: Harbor HTTP 500 (inbound fault abort) ==="
echo ""
echo "Откройте в браузере:"
echo "  Harbor UI: http://$(hostname -I | awk '{print $1}'):30002  (admin / Harbor12345)"
echo "  Grafana:   http://$(hostname -I | awk '{print $1}'):30000  (Panel: Harbor Core Health)"
echo ""
echo "Текущее состояние:"
echo "  Harbor UI доступен, API отвечает 200"
echo ""
echo "Нажмите Enter для внедрения HTTP 500..."
read -r

echo "Применение EnvoyFilter: HTTP 500 на все запросы к harbour-nginx..."
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: EnvoyFilter
metadata:
  name: harbor-nginx-abort
  namespace: ${HARBOR_NS}
spec:
  workloadSelector:
    labels:
      component: nginx
  configPatches:
  - applyTo: HTTP_FILTER
    match:
      context: SIDECAR_INBOUND
      listener:
        filterChain:
          filter:
            name: envoy.filters.network.http_connection_manager
    patch:
      operation: INSERT_BEFORE
      value:
        name: envoy.filters.http.fault
        typed_config:
          "@type": type.googleapis.com/envoy.extensions.filters.http.fault.v3.HTTPFault
          abort:
            http_status: 500
            percentage:
              numerator: 50
              denominator: HUNDRED
EOF

sleep 5

echo ""
echo "HTTP 500 активен на 50% запросов к Harbor."
echo "Обновите страницу Harbor несколько раз — часть запросов вернёт 500."
echo ""
echo "Нажмите Enter для отката..."
read -r

kubectl delete envoyfilter harbor-nginx-abort -n "${HARBOR_NS}" --ignore-not-found 2>/dev/null
sleep 3
echo "HTTP 500 снят. Harbor снова доступен."
echo ""
echo "Сценарий 2 завершён."
