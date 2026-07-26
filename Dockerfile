# MTC DevOps — Docker Runner
# Собирает контейнер с Ansible, подключается к ВМ по SSH и разворачивает стенд.
#
# Build:
#   docker build -t mtc-chaos .
#
# Run:
#   docker run --rm \
#     -e TARGET_HOST=<VM-IP> \
#     -e TARGET_PORT=22 \
#     -e TARGET_USER=ubuntu \
#     -e TARGET_PASSWORD=my_password \
#     mtc-chaos
#
# Если используется SSH ключ вместо пароля:
#   docker run --rm \
#     -v ~/.ssh:/root/.ssh:ro \
#     -e TARGET_HOST=<VM-IP> \
#     -e TARGET_USER=ubuntu \
#     mtc-chaos

FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ENV ANSIBLE_HOST_KEY_CHECKING=False

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3 \
    python3-pip \
    python3-venv \
    openssh-client \
    sshpass \
    curl \
    && pip3 install --no-cache-dir \
    "ansible-core>=2.15" \
    PyYAML \
    && ansible-galaxy collection install community.general ansible.posix \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /ansible

COPY . /ansible/

RUN mkdir -p /etc/ansible && \
    printf '[defaults]\nhost_key_checking = False\nretry_files_enabled = False\n' \
    > /etc/ansible/ansible.cfg

# Entrypoint: генерируем inventory из env vars, запускаем playbook
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
