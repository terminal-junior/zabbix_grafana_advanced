# Arquitetura distribuída entre vários servidores

Arquiterura: \
Sistema operacional: [Rocky Linux 9](https://rockylinux.org/pt-BR/download) \
Servidor 1 → IP: 192.168.1.201 → Banco PostgreSQL \
Servidor 2 → IP: 192.168.1.202 → Zabbix Server + Frontend \
Servidor 3 → IP: 192.168.1.203 → Zabbix Proxy Local \
Servidor 4 → IP: 192.168.1.204 → Grafana \
Servidor 5 → IP: 192.168.1.206 → Zabbix Proxy Externo 

### Abaixo segue o guia de instalação e configuração distribuída

---

## 1. Preparar o Servidor do Banco de Dados (Servidor 1 – PostgreSQL)

Fazer update do sistema

```bash
sudo dnf update -y

```

### 1.1 Instalar PostgreSQL

```bash
sudo dnf install -y postgresql-server postgresql-contrib

```
```bash
sudo postgresql-setup --initdb
sudo systemctl enable --now postgresql

```

### 1.2 Configurar o PostgreSQL para aceitar conexões remotas

Editar 
```
postgresql.conf
```
Arquivo normalmente em:

```bash
sudo dnf install -y nano

```

```bash
sudo nano /var/lib/pgsql/data/postgresql.conf

```

Editar a linha:

```bash
listen_addresses = 'localhost,127.0.0.1,192.168.1.201'
```

Editar **pg_hba.conf**

Arquivo:

```bash
sudo nano /var/lib/pgsql/data/pg_hba.conf

```

Adicionar liberação para o IP do servidor do Zabbix:

```bash
host    zabbix          zabbix          192.168.1.202/32        md5
host    all             all             192.168.1.201/32        md5
```

Se quiser liberar uma subnet inteira:

```bash
host    all             all             192.168.1.0/24        md5
```

### 1.3 Criar banco e usuário para o Zabbix

```bash
sudo -u postgres createuser --pwprompt zabbix

```

```bash
sudo -u postgres createdb -O zabbix zabbix

```

### 1.4 Reiniciar PostgreSQL

```bash
sudo systemctl restart postgresql

```

### 1.5 Configuração de Firewall

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="5432" protocol="tcp" accept'
sudo firewall-cmd --reload

```

---

## 2. Preparar o Servidor do Zabbix (Servidor 2 – Zabbix Server + Frontend)

### 2.1 Instalar o Zabbix Server + Frontend + Agent2

```bash
sudo dnf update -y

```

```bash
sudo rpm -Uvh https://repo.zabbix.com/zabbix/7.4/release/rocky/9/noarch/zabbix-release-latest-7.4.el9.noarch.rpm

```

```bash
sudo dnf clean all

```

```bash
sudo dnf install -y nano zabbix-server-pgsql zabbix-web-pgsql zabbix-nginx-conf zabbix-sql-scripts zabbix-selinux-policy zabbix-agent2 zabbix-agent2-plugin-postgresql

```

### 2.2 Configurar o Zabbix Server para usar o banco no Servidor 1

```bash
sudo nano /etc/zabbix/zabbix_server.conf

```

**Modifique:**

DBHost=192.168.1.201 \
DBName=zabbix \
DBUser=zabbix \
DBPassword=sua_senha


### 2.3 Importar o schema no banco remoto


```bash
sudo zcat /usr/share/zabbix-sql-scripts/postgresql/server.sql.gz | PGPASSWORD="sua_senha" psql -h 192.168.1.201 -U zabbix -d zabbix

```

### 2.4 Iniciar serviços

```bash
sudo systemctl enable --now zabbix-server zabbix-agent2 nginx php-fpm
sudo systemctl restart zabbix-server zabbix-agent2 nginx php-fpm

```

### 2.5 Configuração de Firewall

```bash
sudo systemctl enable firewalld

````
 
```bash
sudo systemctl start firewalld

```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="80" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.203" port port="10050" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.203" port port="10051" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="80" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="443" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="10050" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="10051" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.206" port port="10050" protocol="tcp" accept'
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.206" port port="10051" protocol="tcp" accept'
sudo firewall-cmd --reload

```

---

## 3. Preparar o Servidor do Zabbix Proxy Local (Servidor 3 – Proxy Local)

Este guia descreve passo a passo como instalar, configurar e inicializar um Zabbix Proxy utilizando o banco de dados PostgreSQL, com firewall configurado e comunicação com o Zabbix Server.

### 🧩 3.1 Atualizar sistema e instalar dependências básicas

```bash
dnf update -y

```
```bash
dnf install -y nano openssh-server firewalld

```

### 🔥 3.2 Configuração inicial do Firewall

Permitir acesso SSH apenas da rede 192.168.1.0/24:

```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'

```

Permitir comunicação do Zabbix Server (192.168.1.202) com o Proxy:

```bash
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="10050" protocol="tcp" accept'
firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="10051" protocol="tcp" accept'

```

Aplicar regras:

```bash
firewall-cmd --reload

```

### 📦 3.3 Instalar repositório oficial do Zabbix

```bash
rpm -Uvh https://repo.zabbix.com/zabbix/7.4/release/rocky/9/noarch/zabbix-release-latest-7.4.el9.noarch.rpm

```
```bash
dnf clean all

```

### 🏗 3.4 Instalar Zabbix Proxy + PostgreSQL

```bash
dnf install -y zabbix-proxy-pgsql zabbix-sql-scripts zabbix-selinux-policy postgresql-server postgresql-contrib

```

### 🗄 3.5 Inicializar e ativar PostgreSQL

```bash
postgresql-setup --initdb
systemctl enable --now postgresql

```

### 👤 3.6 Criar usuário e banco do Zabbix Proxy

Criar usuário no PostgreSQL:

```bash
sudo -u postgres createuser --pwprompt zabbix

```

Criar banco:

```bash
sudo -u postgres createdb -O zabbix zabbix_proxy

```

### 📥 3.7 Importar estrutura do banco

```bash
cat /usr/share/zabbix/sql-scripts/postgresql/proxy.sql | sudo -u zabbix psql zabbix_proxy

```

### ⚙️ 3.8 Configurar o Zabbix Proxy

Editar o arquivo:

```bash
nano /etc/zabbix/zabbix_proxy.conf

```


Inserir:

Server=192.168.1.202 \
ServerPort=10051 \
Hostname=Zabbix-Proxy \
DBName=zabbix_proxy \
DBUser=zabbix \
DBPassword=sua_senha

### 🛡 3.9 Configurar acesso do PostgreSQL (pg_hba.conf)

```bash
nano /var/lib/pgsql/data/pg_hba.conf

```


Adicionar/ajustar:

```bash
Conexão local via socket
local   all             all                                     md5

Conexões IPv4 localhost
host    all             all             127.0.0.1/32            md5

Conexões IPv6 localhost
host    all             all             ::1/128                 md5

Conexões da rede local (opcional)
host    all             all             192.168.1.0/24          md5
```


Reiniciar PostgreSQL se alterar:

```bash
systemctl restart postgresql

```

### 🚀 3.10 Habilitar e iniciar Zabbix Proxy

```bash
systemctl enable zabbix-proxy
systemctl restart zabbix-proxy

```

---

## 4. Preparar o Servidor Grafana (Servidor 4 - Grafana)

### 🛠️ 4.1 Atualizando o sistema

```bash
sudo dnf update -y

```

### 🧩 4.2 Instalando pacotes básicos
```bash
sudo dnf install -y nano openssh-server firewalld

```

### 🔧 4.3 Habilitando e iniciando serviços essenciais
```bash
sudo systemctl enable sshd firewalld
sudo systemctl start sshd firewalld


```

### 📦 4.4 Instalando o Grafana Enterprise 12.3.0

Baixe e instale o pacote .rpm:

```bash
sudo yum install -y https://dl.grafana.com/grafana-enterprise/release/12.3.0/grafana-enterprise_12.3.0_19497075765_linux_amd64.rpm

```

Atualize os serviços:

```bash
sudo systemctl daemon-reload

```

Inicie e habilite o serviço do Grafana:

```bash
sudo systemctl start grafana-server
sudo systemctl enable grafana-server

```

### 🔥 4.5 Configurando Firewall (firewalld)

Libere o acesso à porta 3000 (Grafana) apenas para a rede interna:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="3000" protocol="tcp" accept'

```

Libere acesso SSH para a rede:

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" service name="ssh" accept'

```

Recarregue o firewall:

```bash
sudo firewall-cmd --reload

```

### 🚀 4.6 Acessando o Grafana

Abra o navegador e acesse:

```bash
http://192.168.1.204:3000
```

Credenciais padrão:

Usuário: admin

Senha: admin (será solicitado para alterar no primeiro login)



---

## 5. Preparar o Servidor do Zabbix Proxy Externo (Servidor 5 – Proxy Externo)


Repita o **passo 3** e no final instale o [ZeroTier](https://www.zerotier.com/) para usar sua VPN privada. \
Com isso poderá monitorar hosts e dispositivos remotos.

```bash
curl -s https://install.zerotier.com | sudo bash
```




