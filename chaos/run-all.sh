#!/usr/bin/env bash
# Chaos Engineering Demo — последовательный запуск всех сценариев.
# Запускать на ВМ после развертывания стендa.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Определение IP ВМ для подсказок
VM_IP=$(hostname -I | awk '{print $1}')
if [ -z "${VM_IP}" ]; then
    VM_IP="<VM-IP>"
fi

export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

if ! command -v kubectl >/dev/null 2>&1; then
    echo "kubectl не найден. Сначала разверните стенд (см. README.md)."
    exit 1
fi

if ! kubectl get nodes >/dev/null 2>&1; then
    echo "Kubernetes недоступен. Сначала разверните стенд (см. README.md)."
    exit 1
fi

echo "=== Chaos Engineering Demo ==="
echo ""
echo "Откройте в браузере перед стартом:"
echo "  Приложение:  http://${VM_IP}:30133"
echo "  Harbor UI:   http://${VM_IP}:30002  (admin / Harbor12345)"
echo "  Grafana:     http://${VM_IP}:30000  (admin / admin)"
echo "    Dashboard: Chaos Engineering Demo"
echo ""
echo "Сценарии:"
echo "  1. HTTP Latency — задержка ответа backend (3с на запрос)"
echo "  2. Harbor core down — отключение Harbor API (503)"
echo "  3. DB Latency — задержка DB-запросов (2с)"
echo "  4. Network Partition — обрыв связи backend с DB (кастомный)"
echo ""
echo "Каждый сценарий:"
echo "  1) Демонстрация нормальной работы приложения"
echo "  2) Внедрение ошибки (пауза)"
echo "  3) Откат и проверка восстановления"
echo ""

for script in \
    "${SCRIPT_DIR}/01-http-latency.sh" \
    "${SCRIPT_DIR}/02-http-500.sh" \
    "${SCRIPT_DIR}/03-db-latency.sh" \
    "${SCRIPT_DIR}/04-network-partition.sh"; do

    if [ -f "${script}" ]; then
        echo ""
        echo "------------------------------------------------------------"
        bash "${script}"
        echo "------------------------------------------------------------"

        if [ "${script}" != "${SCRIPT_DIR}/04-network-partition.sh" ]; then
            echo ""
            echo "Нажмите Enter для следующего сценария..."
            read -r
        fi
    fi
done

echo ""
echo "=== Все сценарии завершены ==="
echo "Все ресурсы откачены. Проверьте приложение в браузере."
