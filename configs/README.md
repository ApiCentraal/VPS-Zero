# VPS-Zero Configuraties
## Enterprise-Grade Cybersecure Database & Application Omgeving

Deze directory bevat alle configuraties voor een volledig beveiligde, productie-ready omgeving met zero-attack surface benadering.

## 📁 Directory Structuur

```
configs/
├── database/           # Database configuraties
│   ├── postgresql/    # PostgreSQL met TLS, SCRAM-SHA-256
│   ├── mysql/        # MySQL met SSL, caching_sha2
│   ├── mongodb/      # MongoDB met TLS, auth enabled
│   └── redis/        # Redis met TLS, ACL, password
├── docker/           # Docker security configuraties
│   ├── daemon.json          # Docker daemon hardening
│   └── seccomp-default.json # Seccomp security profile
├── security/         # Security tools
│   ├── backup-databases.sh  # Encrypted backup script
│   └── security-scan.sh     # Security scanning tool
├── ssl/             # SSL/TLS certificaten
│   └── generate-certificates.sh
├── .env.production.template   # Production environment vars
└── .env.development.template  # Development environment vars
```

## 🚀 Quick Start

### 1. Genereer SSL/TLS Certificaten

#### Development (Self-Signed)
```bash
cd configs/ssl
sudo ./generate-certificates.sh all
```

#### Production (Let's Encrypt)
```bash
# Installeer certbot
sudo apt-get install -y certbot

# Genereer certificaten
sudo certbot certonly --standalone \
  -d db.yourdomain.com \
  --agree-tos \
  --email admin@yourdomain.com
```

### 2. Configureer Secrets

```bash
cd configs
cp .env.production.template .env.production

# Genereer sterke passwords
openssl rand -base64 32  # Voor database passwords
openssl rand -base64 64  # Voor JWT secrets
openssl rand -hex 32     # Voor encryption keys

# Edit .env.production en vervang alle CHANGEME waarden
nano .env.production
```

### 3. Setup Docker Secrets (Productie)

```bash
# Initialiseer Docker Swarm
docker swarm init

# Maak secrets aan
echo "strong_password" | docker secret create postgres_password -
echo "app_user" | docker secret create postgres_user -
# ... etc voor andere secrets
```

Zie [SECRETS-MANAGEMENT.md](../SECRETS-MANAGEMENT.md) voor complete guide.

### 4. Deploy Database

```bash
# Kies database type
cd configs/database/postgresql

# Kopieer certificaten naar volume locatie
sudo cp /etc/ssl/database-certs/postgresql/* /var/lib/postgresql/data/

# Start database
docker-compose -f docker-compose.prod.yml up -d

# Verifieer
docker-compose ps
docker-compose logs
```

## 🗄️ Database Configuraties

### PostgreSQL
**Features:**
- ✅ SCRAM-SHA-256 authenticatie (meest veilig)
- ✅ TLS 1.2+ verplicht voor alle connecties
- ✅ Read-only root filesystem
- ✅ No new privileges
- ✅ Resource limits
- ✅ Connection logging
- ✅ WAL archiving voor PITR

**Ports:**
- PostgreSQL: 5432 (alleen binnen Docker netwerk)

**Volumes:**
- Data: `/var/lib/postgresql/data`
- Logs: `/var/log/postgresql`

**Health Check:**
```bash
docker exec postgres_prod pg_isready -U $POSTGRES_USER
```

### MySQL
**Features:**
- ✅ caching_sha2_password authenticatie
- ✅ SSL/TLS verplicht
- ✅ TLS 1.2/1.3 only
- ✅ LOCAL INFILE disabled
- ✅ Binary logging voor replicatie
- ✅ Slow query logging

**Ports:**
- MySQL: 3306 (alleen binnen Docker netwerk)

### MongoDB
**Features:**
- ✅ SCRAM-SHA-256 authenticatie
- ✅ TLS verplicht
- ✅ JavaScript execution disabled
- ✅ WiredTiger encryption-at-rest (enterprise)
- ✅ Authorization enabled
- ✅ Replica set ready

**Ports:**
- MongoDB: 27017 (alleen binnen Docker netwerk)

### Redis
**Features:**
- ✅ TLS only (port 6379 disabled)
- ✅ Password authenticatie
- ✅ Gevaarlijke commands disabled/renamed
- ✅ ACL support (Redis 6+)
- ✅ AOF + RDB persistence
- ✅ Protected mode

**Ports:**
- Redis: 6380 TLS (alleen binnen Docker netwerk)

## 🔒 Security Features

### Container Security
- **No Root**: Alle containers draaien als non-root user
- **Read-Only FS**: Root filesystem is read-only waar mogelijk
- **No New Privileges**: Privilege escalatie geblokkeerd
- **Dropped Capabilities**: Alleen essentiële Linux capabilities
- **Seccomp Profile**: Syscall filtering actief
- **Resource Limits**: CPU en memory limits geconfigureerd

### Network Security
- **Isolated Networks**: Elke database in eigen netwerk
- **No ICC**: Inter-container communicatie uitgeschakeld
- **User Namespaces**: Docker user namespace remapping
- **TLS Only**: Alle database connecties via TLS
- **No Plaintext**: Geen onversleutelde communicatie

### Data Security
- **Encryption at Rest**: Database volume encryptie
- **Encryption in Transit**: TLS 1.2+ voor alle connecties
- **Encrypted Backups**: Alle backups met AES-256
- **Secrets Management**: Docker secrets of Vault
- **Key Rotation**: Procedures voor key rotatie

## 🛠️ Security Tools

### Backup Script
```bash
# Backup alle databases
BACKUP_ENCRYPTION_KEY="your_key" \
  ./configs/security/backup-databases.sh all

# Backup specifieke database
./configs/security/backup-databases.sh postgresql
```

**Features:**
- Compressed backups (gzip -9)
- AES-256 encryptie
- Automatische rotatie (30 dagen)
- Cloud upload support
- Backup verificatie

### Security Scan
```bash
# Volledige security scan
sudo ./configs/security/security-scan.sh --full

# Scan Docker images
sudo ./configs/security/security-scan.sh --images

# Scan host security
sudo ./configs/security/security-scan.sh --host
```

**Scans:**
- Container vulnerability scanning (Trivy)
- CIS Docker Benchmark
- Secrets exposure check
- Host security configuration
- Database security settings

## 📊 Monitoring

### Docker Stats
```bash
# Resource usage
docker stats

# Logs
docker-compose logs -f
docker logs --tail 100 postgres_prod
```

### Database Specific

#### PostgreSQL
```bash
# Active connections
docker exec postgres_prod psql -U postgres -c \
  "SELECT * FROM pg_stat_activity;"

# Database size
docker exec postgres_prod psql -U postgres -c \
  "SELECT pg_size_pretty(pg_database_size('production'));"
```

#### MySQL
```bash
# Processlist
docker exec mysql_prod mysql -u root -p -e \
  "SHOW FULL PROCESSLIST;"
```

#### MongoDB
```bash
# Stats
docker exec mongodb_prod mongosh --eval "db.stats()"
```

#### Redis
```bash
# Info
docker exec redis_prod redis-cli --tls \
  --cert /data/redis.crt \
  --key /data/redis.key \
  --cacert /data/ca.crt \
  -p 6380 INFO
```

## 🔄 Maintenance

### Certificate Renewal
```bash
# Let's Encrypt auto-renewal
sudo certbot renew --quiet \
  --post-hook "docker-compose restart"

# Cron job
0 3 * * * certbot renew --quiet --post-hook 'cd /path/to/configs && docker-compose restart'
```

### Backup Automation
```bash
# Cron job voor dagelijkse backups
0 2 * * * BACKUP_ENCRYPTION_KEY="$(cat /run/secrets/backup_key)" \
  /path/to/configs/security/backup-databases.sh all \
  >> /var/log/backups.log 2>&1
```

### Security Scanning
```bash
# Wekelijkse security scan
0 4 * * 0 /path/to/configs/security/security-scan.sh --full \
  >> /var/log/security-scans/weekly.log 2>&1
```

### Updates
```bash
# Update Docker images
docker-compose pull
docker-compose up -d

# Update systeem
sudo apt-get update && sudo apt-get upgrade -y
```

## ⚙️ Environment Variables

### Productie
Gebruik `configs/.env.production.template`:
- Sterke passwords (32+ chars)
- Unieke secrets per omgeving
- TLS verplicht
- Strikte timeouts
- Minimal logging

### Development
Gebruik `configs/.env.development.template`:
- Eenvoudige passwords OK
- TLS optioneel
- Verbose logging
- Langere timeouts

⚠️ **NOOIT** productie secrets committen naar git!

## 📖 Documentatie

- [SECURITY-CONFIG.md](../SECURITY-CONFIG.md) - Complete security guide
- [SECRETS-MANAGEMENT.md](../SECRETS-MANAGEMENT.md) - Secrets management
- [README.md](../README.md) - Hoofd documentatie

## 🆘 Troubleshooting

### Container start niet
```bash
# Check logs
docker-compose logs database_name

# Check configuratie
docker-compose config

# Verify volumes
docker volume ls
docker volume inspect volume_name
```

### TLS connectie faalt
```bash
# Verify certificaat
openssl x509 -in server.crt -noout -text

# Test TLS connectie
openssl s_client -connect localhost:5432 -starttls postgres

# Check certificaat permissies
ls -la /path/to/certs/
```

### Performance problemen
```bash
# Resource usage
docker stats

# Verhoog resources in docker-compose.yml:
resources:
  limits:
    cpus: '4'
    memory: 4G
```

## 🔐 Security Checklist

Voordat je naar productie gaat:

- [ ] Alle passwords zijn strong en uniek
- [ ] SSL/TLS certificaten zijn gegenereerd en getest
- [ ] Docker secrets zijn geconfigureerd
- [ ] Firewall rules zijn ingesteld (UFW)
- [ ] Backup strategie is getest
- [ ] Monitoring is geconfigureerd
- [ ] Recovery procedures zijn gedocumenteerd
- [ ] Security scan is uitgevoerd zonder kritieke issues
- [ ] Team is getraind
- [ ] Incident response plan is ready

## 📜 Licentie

MIT License - Zie [LICENSE](../LICENSE) voor details.

## 🤝 Support

- GitHub Issues: https://github.com/ApiCentraal/VPS-Zero/issues
- Security Issues: Gebruik private security advisory
- Documentation: Zie [SECURITY-CONFIG.md](../SECURITY-CONFIG.md)

---

**⚠️ BELANGRIJK**: Deze configuraties zijn een starting point. Pas aan op basis van uw specifieke requirements en voer altijd security audits uit door professionals.
