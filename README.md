# Arquitetura distribuída entre vários servidores

Arquiterura: \
Sistema operacional: [Rocky Linux 9](https://rockylinux.org/pt-BR/download) \
Servidor 1 → IP: 192.168.1.201 → Banco PostgreSQL \
Servidor 2 → IP: 192.168.1.202 → Zabbix Server + Frontend \
Servidor 3 → IP: 192.168.1.203 → Zabbix Proxy Local \
Servidor 4 → IP: 192.168.1.204 → Grafana \
Servidor 5 → IP: 192.168.1.206 → Zabbix Proxy Externo\ 

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

listen_addresses = '*'
