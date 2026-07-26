#!/usr/bin/env bash
set -euo pipefail

# ============================================================
# Entrypoint: генерирует inventory.yml из env vars,
# запускает ansible-playbook, копирует репозиторий на ВМ.
# ============================================================

TARGET_HOST="${TARGET_HOST:-}"
TARGET_PORT="${TARGET_PORT:-22}"
TARGET_USER="${TARGET_USER:-ubuntu}"
TARGET_PASSWORD="${TARGET_PASSWORD:-}"

if [ -z "${TARGET_HOST}" ]; then
    echo "ERROR: TARGET_HOST is required"
    echo "Usage: docker run --rm -e TARGET_HOST=<VM-IP> -e TARGET_USER=<user> [-e TARGET_PASSWORD=<pass>] mtc-chaos"
    exit 1
fi

# Генерируем inventory.yml
echo "Generating inventory for ${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}"

cat > /ansible/inventory.yml <<EOF
all:
  hosts:
    target:
      ansible_host: ${TARGET_HOST}
      ansible_port: ${TARGET_PORT}
      ansible_user: ${TARGET_USER}
EOF

# Пароль (если задан)
if [ -n "${TARGET_PASSWORD}" ]; then
    cat >> /ansible/inventory.yml <<EOF
      ansible_password: ${TARGET_PASSWORD}
      ansible_become_password: ${TARGET_PASSWORD}
      ansible_ssh_common_args: "-o StrictHostKeyChecking=no -o PreferredAuthentications=password"
EOF
else
    cat >> /ansible/inventory.yml <<EOF
      ansible_ssh_common_args: "-o StrictHostKeyChecking=no"
EOF
fi

cat >> /ansible/inventory.yml <<EOF
      ansible_become: true
  vars:
    k3s_version: "v1.29.3+k3s1"
    harbor_admin_password: "Harbor12345"
    istio_version: "1.21.0"
    istio_profile: "default"
EOF

echo "--- Generated inventory ---"
cat /ansible/inventory.yml
echo "---------------------------"

# Запуск Ansible
echo ""
echo ">>> Starting deployment..."
ansible-playbook -i /ansible/inventory.yml /ansible/site.yml -vv

# Копируем репозиторий на ВМ для chaos-скриптов
echo ""
echo ">>> Copying chaos scripts to target VM..."
if [ -n "${TARGET_PASSWORD}" ]; then
    sshpass -p "${TARGET_PASSWORD}" ssh -o StrictHostKeyChecking=no -p "${TARGET_PORT}" \
        "${TARGET_USER}@${TARGET_HOST}" "mkdir -p /tmp/mtc-devops"
    sshpass -p "${TARGET_PASSWORD}" scp -o StrictHostKeyChecking=no -P "${TARGET_PORT}" \
        -r /ansible/chaos /ansible/README.md /ansible/CHAOS_RESEARCH.md \
        "${TARGET_USER}@${TARGET_HOST}:/tmp/mtc-devops/"
else
    ssh -o StrictHostKeyChecking=no -p "${TARGET_PORT}" \
        "${TARGET_USER}@${TARGET_HOST}" "mkdir -p /tmp/mtc-devops"
    scp -P "${TARGET_PORT}" \
        -r /ansible/chaos /ansible/README.md /ansible/CHAOS_RESEARCH.md \
        "${TARGET_USER}@${TARGET_HOST}:/tmp/mtc-devops/"
fi

echo ""
echo "============================================================"
echo "  DEPLOYMENT COMPLETE"
echo "============================================================"
echo ""
echo "  VM: ${TARGET_USER}@${TARGET_HOST}:${TARGET_PORT}"
echo ""
echo "  Harbor UI:  http://${TARGET_HOST}:30002  (admin / Harbor12345)"
echo "  Ingress:    http://${TARGET_HOST}:30133"
echo ""
echo "  Chaos demo:"
echo "    ssh ${TARGET_USER}@${TARGET_HOST} -p ${TARGET_PORT}"
echo "    cd /tmp/mtc-devops && ./chaos/run-all.sh"
echo ""
echo "============================================================"
