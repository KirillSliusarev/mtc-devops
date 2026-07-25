# Docker-wrapped Ansible playbook (бонус)
# Позволяет запустить весь стенд из Docker контейнера без установки Ansible локально
#
# Build:  docker build -t mtc-chaos-runner .
# Run:    docker run --rm -e TARGET_HOST=192.168.1.100 -e TARGET_USER=ubuntu mtc-chaos-runner
#
# Требуется SSH ключ для доступа к ВМ. Передайте через volume mount:
#   docker run --rm -v ~/.ssh:/root/.ssh:ro -e TARGET_HOST=... -e TARGET_USER=... mtc-chaos-runner

FROM ubuntu:22.04

ARG ANSIBLE_VERSION=8.5.0
ARG KUBECTL_VERSION=v1.29.3

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
    ansible==${ANSIBLE_VERSION} \
    kubernetes \
    PyYAML \
    && curl -fsSL "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl" \
       -o /usr/local/bin/kubectl \
    && chmod +x /usr/local/bin/kubectl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /ansible

COPY . /ansible/

RUN echo "[defaults]\n\
host_key_checking = False\n\
retry_files_enabled = False\n\
stdout_callback = yaml\n" > /etc/ansible/ansible.cfg

ENTRYPOINT ["ansible-playbook", "-i", "inventory.yml", "site.yml", "-e"]
CMD ["target_host=192.168.1.100", "target_user=ubuntu"]
