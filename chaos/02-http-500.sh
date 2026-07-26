#!/usr/bin/env bash
# Сценарий 2: Harbor core down — отключение Harbor registry API.
# harbor-core масштабируется до 0 реплик. Harbor-nginx возвращает 503
# на API-запросы (/api/v2.0/). Главная страница (portal) продолжает работать.
# На Grafana (Panel "Harbor Core Health") видно падение replicas до 0.
# Симулирует отказ центрального компонента registry.

HARBOR_NS="harbor"

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "=== Сценарий 2: Harbor core down (503) ==="
echo ""
echo "Откройте в браузере:"
echo "  Harbor UI: http://$(hostname -I | awk '{print $1}'):30002  (admin / Harbor12345)"
echo "  Grafana:   http://$(hostname -I | awk '{print $1}'):30000  (Panel: Harbor Core Health)"
echo ""
echo "Текущее состояние:"
echo "  Harbor UI доступен, логин работает"
echo ""
echo "Нажмите Enter для отключения harbor-core..."
read -r

echo "Масштабирование harbor-core до 0 реплик..."
kubectl scale deployment harbor-core -n "${HARBOR_NS}" --replicas=0
sleep 5

echo ""
echo "harbor-core отключён. API возвращает 503, логин не работает."
echo "Попробуйте обновить страницу Harbor и залогиниться."
echo ""
echo "Нажмите Enter для восстановления..."
read -r

kubectl scale deployment harbor-core -n "${HARBOR_NS}" --replicas=1
kubectl rollout status deployment/harbor-core -n "${HARBOR_NS}" --timeout=120s 2>/dev/null
echo "harbor-core восстановлен. API снова доступен."
echo ""
echo "Сценарий 2 завершён."
