#!/bin/bash

# -----------------------------------------------
# Script de Instalação e Configuração do Zabbix Proxy
# Rocky Linux 9 + PostgreSQL
# -----------------------------------------------

hostnamectl set-hostname Zabbix-Proxy-Externo

echo "=== Atualizando o sistema e instalando pacotes básicos ==="
dnf update -y &>/dev/null
dnf install -y nano openssh-server firewalld &>/dev/null

echo "=== Inicializando serviços SSH e Firewall ==="
systemctl enable sshd firewalld &>/dev/null
systemctl start sshd firewalld &>/dev/null

echo "=== Configurando Firewall ==="
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept' &>/dev/null
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="10050" protocol="tcp" accept' &>/dev/null
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="10051" protocol="tcp" accept' &>/dev/null
firewall-cmd --reload &>/dev/null

echo "=== Instalando Repositório Zabbix ==="
rpm -Uvh https://repo.zabbix.com/zabbix/7.4/release/rocky/9/noarch/zabbix-release-latest-7.4.el9.noarch.rpm &>/dev/null
dnf clean all &>/dev/null

echo "=== Instalando Zabbix Proxy e PostgreSQL ==="
dnf install -y zabbix-proxy-pgsql zabbix-sql-scripts zabbix-selinux-policy postgresql-server postgresql-contrib &>/dev/null

echo "=== Inicializando Banco PostgreSQL ==="
postgresql-setup --initdb &>/dev/null
systemctl enable --now postgresql &>/dev/null

echo "=== Criando usuário e banco do Zabbix Proxy ==="
sudo -u postgres psql -c "DO \$\$ BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'zabbix') THEN
        CREATE USER zabbix WITH PASSWORD 'zabbix';
    END IF;
END \$\$;" &>/dev/null

sudo -u postgres createdb -O zabbix zabbix_proxy &>/dev/null

echo "=== Importando estrutura do banco ==="
cat /usr/share/zabbix/sql-scripts/postgresql/proxy.sql | sudo -u zabbix psql zabbix_proxy &>/dev/null

echo "=== Configurando Zabbix Proxy ==="
ZBX_CONF="/etc/zabbix/zabbix_proxy.conf"

echo "Criando backup do arquivo original..."
cp $ZBX_CONF ${ZBX_CONF}.bak &>/dev/null

echo "Verificando e adicionando parâmetros necessários..."

add_or_update() {
    local key="$1"
    local value="$2"

    if grep -q "^${key}=" "$ZBX_CONF"; then
        sed -i "s|^${key}=.*|${key}=${value}|g" "$ZBX_CONF"
        return
    fi

    if grep -q "^#${key}=" "$ZBX_CONF"; then
        sed -i "s|^#${key}=.*|${key}=${value}|g" "$ZBX_CONF"
        return
    fi

    echo "${key}=${value}" >> "$ZBX_CONF"
}

add_or_update "Server" "192.168.1.202"
add_or_update "ServerPort" "10051"
add_or_update "Hostname" "Zabbix-Proxy-Externo"
add_or_update "DBName" "zabbix_proxy"
add_or_update "DBUser" "zabbix"
add_or_update "DBPassword" "zabbix"

echo "Configurações aplicadas ao zabbix_proxy.conf!"

echo "=== Ajustando pg_hba.conf ==="

PG_HBA="/var/lib/pgsql/data/pg_hba.conf"

echo "Criando backup do pg_hba.conf..."
cp $PG_HBA ${PG_HBA}.bak &>/dev/null

echo "Gerando novo pg_hba.conf..."
cat <<EOF > $PG_HBA
# Conexão local via socket
local   all             all                                     md5

# Conexões IPv4 localhost
host    all             all             127.0.0.1/32            md5

# Conexões IPv6 localhost
host    all             all             ::1/128                 md5

# Conexões da rede local
host    all             all             192.168.1.0/24          md5
EOF

systemctl restart postgresql &>/dev/null

echo "=== Habilitando e iniciando Zabbix Proxy Externo==="
systemctl enable zabbix-proxy &>/dev/null
systemctl restart zabbix-proxy &>/dev/null

echo "=== Instalação da VPN ZeroTier ==="

curl -s https://install.zerotier.com | sudo bash
echo "Copie o ZeroTier address e adicione a sua rede"

echo "=== Instalação concluída com sucesso! ==="
echo "Verifique o status com: systemctl status zabbix-proxy"

