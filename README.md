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
sudo dnf install postgresql-server postgresql-contrib
```
```bash
sudo postgresql-setup --initdb
```
```bash
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
```

```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.202" port port="5432" protocol="tcp" accept'
```

```bash
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
```

```bash
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
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="443" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.0/24" port port="80" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.203" port port="10050" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.203" port port="10051" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="80" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="443" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="10050" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.204" port port="10051" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.206" port port="10050" protocol="tcp" accept'
```
 
```bash
sudo firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="192.168.1.206" port port="10051" protocol="tcp" accept'
```` 

---

## 3. Preparar o Servidor do Zabbix Proxy Local (Servidor 3 – Proxy Local)




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







