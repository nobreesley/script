#!/bin/bash

# Atualizar DATA E HORA Automaticamente com NTP
sudo dnf install chrony -y

#  Ative e inicie o serviço:
sudo systemctl enable chronyd --now

set -e

echo "==== 1️⃣ Removendo Docker antigo ===="
sudo systemctl stop docker || true
sudo systemctl disable docker || true

# Limpa containers, imagens e volumes
sudo docker system prune -a --volumes -f || true

# Remove pacotes Docker e similares
sudo yum remove -y docker \
                 docker-client \
                 docker-client-latest \
                 docker-common \
                 docker-latest \
                 docker-latest-logrotate \
                 docker-logrotate \
                 docker-engine \
                 docker-ce \
                 docker-ce-cli \
                 containerd.io \
                 docker-compose-plugin \
                 podman \
                 runc || true

# Remove diretórios residuais
sudo rm -rf /var/lib/docker /var/lib/containerd /etc/docker /run/docker /var/run/docker.sock

echo "==== 2️⃣ Instalando Docker no Oracle Linux ===="
sudo yum install -y yum-utils
sudo dnf config-manager --add-repo=https://download.docker.com/linux/centos/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io

# Inicia e habilita Docker
sudo systemctl daemon-reexec
sudo systemctl enable --now docker

# Adiciona usuário ao grupo docker
sudo usermod -aG docker $USER
echo "⚠️ Reinicie a sessão ou use: newgrp docker"

echo "==== 3️⃣ Instalando Docker Compose (plugin) ===="
sudo dnf install -y docker-compose-plugin

echo "==== 4️⃣ Baixando e preparando Veeam Backup API ===="
sudo yum install -y wget unzip
mkdir -p /var/docker/veeambackup-api-dtu/
cd /var/docker/veeambackup-api-dtu/

# Baixa o pacote
wget -O veeam_backup_api.zip http://dataunique.ddns.com.br:8048/monitoramento/veeam_backup_api.zip
unzip -o veeam_backup_api.zip && rm -f veeam_backup_api.zip

echo "==== 5️⃣ Ajustando Dockerfile para Oracle Linux ===="
cat > Dockerfile <<'EOF'
FROM oraclelinux:8

WORKDIR /tmp

# Instala pacotes necessários no Oracle Linux
RUN yum install -y \
    make \
    perl \
    gcc \
    tar \
    wget \
    && yum clean all

# Copia o OpenSSL e instala
COPY openssl-1.0.2l.tar.gz /tmp
RUN tar -xzf openssl-1.0.2l.tar.gz && \
    cd openssl-1.0.2l && \
    ./config && make && make install

# Define diretório da aplicação
WORKDIR /app
COPY requirements.txt /app/

# Instala Python 3 e dependências
RUN yum install -y python3 python3-pip && pip3 install --no-cache-dir -r requirements.txt

# Copia código da aplicação
COPY veeam_backup_api.py /app/

CMD ["python3", "veeam_backup_api.py"]
EOF

echo "==== 6️⃣ Subindo container ===="
docker compose up -d --build

echo "✅ Instalação concluída com sucesso!"
