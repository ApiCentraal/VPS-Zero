# Enterprise Security Configuratie Gids
## VPS-Zero Cybersecure Database Omgeving

### 📋 Inhoudsopgave
1. [Overzicht](#overzicht)
2. [Security Architectuur](#security-architectuur)
3. [Database Configuraties](#database-configuraties)
4. [Secrets Management](#secrets-management)
5. [SSL/TLS Certificaten](#ssltls-certificaten)
6. [Backup & Recovery](#backup--recovery)
7. [Monitoring & Auditing](#monitoring--auditing)
8. [Best Practices](#best-practices)

---

## Overzicht

Deze configuratie biedt een enterprise-grade, cybersecure oplossing voor het draaien van databases in een gecontaineriseerde omgeving met **zero-attack surface** benadering.

### Kernprincipes
- ✅ **Defense in Depth** - Meerdere beveiligingslagen
- ✅ **Least Privilege** - Minimale rechten voor alle componenten
- ✅ **Zero Trust** - Alles moet geverifieerd worden
- ✅ **Encryption Everywhere** - Data-at-rest en data-in-transit
- ✅ **Immutable Infrastructure** - Read-only containers waar mogelijk
- ✅ **Security by Default** - Veilige standaard configuraties

---

## Security Architectuur

### Netwerk Segmentatie
Elke database draait in een geïsoleerd Docker netwerk:
- **PostgreSQL**: `172.20.0.0/24` (br-postgres)
- **MySQL**: `172.21.0.0/24` (br-mysql)
- **MongoDB**: `172.22.0.0/24` (br-mongo)
- **Redis**: `172.23.0.0/24` (br-redis)

### Container Security
- **No root**: Alle containers draaien als non-root user
- **Read-only filesystem**: Root filesystem is read-only
- **No new privileges**: Privilege escalatie geblokkeerd
- **Dropped capabilities**: Alleen essentiële Linux capabilities
- **Seccomp profiles**: Syscall filtering actief
- **Resource limits**: CPU en memory limits ingesteld

### Network Security
- **ICC disabled**: Inter-container communicatie uitgeschakeld
- **User namespaces**: Docker user namespace remapping
- **TLS only**: Alle database connecties via TLS/SSL
- **No plaintext**: Geen onversleutelde communicatie

---

## Database Configuraties

### PostgreSQL
**Locatie**: `configs/database/postgresql/`

#### Security Features
- ✅ SCRAM-SHA-256 authenticatie (sterkste optie)
- ✅ SSL/TLS verplicht voor alle connecties
- ✅ TLS 1.2 minimum versie
- ✅ Logging van alle connecties en DDL statements
- ✅ Statement en lock timeouts geconfigureerd
- ✅ Idle transaction timeout
- ✅ WAL archiving voor point-in-time recovery

#### Deployment
```bash
cd configs/database/postgresql
docker-compose -f docker-compose.prod.yml up -d
```

#### Health Check
```bash
docker exec postgres_prod pg_isready -U $POSTGRES_USER
```

### MySQL
**Locatie**: `configs/database/mysql/`

#### Security Features
- ✅ caching_sha2_password authenticatie
- ✅ SSL/TLS verplicht
- ✅ TLS 1.2/1.3 only
- ✅ LOCAL INFILE uitgeschakeld
- ✅ Symbolic links uitgeschakeld
- ✅ Slow query logging
- ✅ Binary logging voor replicatie

#### Deployment
```bash
cd configs/database/mysql
docker-compose -f docker-compose.prod.yml up -d
```

### MongoDB
**Locatie**: `configs/database/mongodb/`

#### Security Features
- ✅ Authorization ingeschakeld
- ✅ TLS verplicht voor alle connecties
- ✅ JavaScript execution uitgeschakeld
- ✅ WiredTiger encryption-at-rest (enterprise)
- ✅ SCRAM-SHA-256 authenticatie
- ✅ Audit logging (enterprise)

#### Deployment
```bash
cd configs/database/mongodb
docker-compose -f docker-compose.prod.yml up -d
```

### Redis
**Locatie**: `configs/database/redis/`

#### Security Features
- ✅ TLS only (port 6379 disabled)
- ✅ Password authenticatie verplicht
- ✅ Gevaarlijke commands gerenamed/disabled
- ✅ ACL (Access Control Lists) support
- ✅ Protected mode enabled
- ✅ Persistence met AOF en RDB

#### Deployment
```bash
cd configs/database/redis
docker-compose -f docker-compose.prod.yml up -d
```

---

## Secrets Management

### Docker Secrets
Voor productie gebruik Docker Secrets voor gevoelige data:

```bash
# Aanmaken secrets
echo "your_strong_password" | docker secret create postgres_password -
echo "app_user" | docker secret create postgres_user -

# Secrets worden gemount als bestanden in /run/secrets/
```

### Environment Variabelen
Gebruik de template bestanden:
- **Development**: `configs/.env.development.template`
- **Production**: `configs/.env.production.template`

⚠️ **NOOIT** productie secrets committen naar git!

### Wachtwoord Requirements (Productie)
- Minimum 32 karakters
- Mix van hoofdletters, kleine letters, cijfers, speciale tekens
- Geen dictionary woorden
- Uniek per service
- Roteren elke 90 dagen

### Genereren van sterke secrets
```bash
# JWT Secret (64 bytes)
openssl rand -base64 64

# Encryption Key (32 bytes hex)
openssl rand -hex 32

# Database Password (32 karakters)
openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
```

---

## SSL/TLS Certificaten

### Genereren van Certificaten

#### Development (Self-Signed)
```bash
cd configs/ssl
sudo ./generate-certificates.sh all
```

Dit genereert certificaten voor alle databases in `/etc/ssl/database-certs/`

#### Production (Let's Encrypt)
```bash
# Installeer certbot
apt-get install -y certbot

# Genereer certificaat
certbot certonly --standalone \
  -d db.yourdomain.com \
  --agree-tos \
  --email admin@yourdomain.com

# Certificaten zijn beschikbaar in:
# /etc/letsencrypt/live/db.yourdomain.com/
```

### Certificaat Rotatie
Let's Encrypt certificaten zijn 90 dagen geldig. Configureer automatische vernieuwing:

```bash
# Cron job voor automatische vernieuwing
echo "0 3 * * * certbot renew --quiet --post-hook 'docker-compose restart'" | crontab -
```

### Certificaat Verificatie
```bash
# Controleer certificaat expiratie
openssl x509 -in /etc/ssl/database-certs/postgresql/server.crt -noout -enddate

# Test TLS connectie
openssl s_client -connect localhost:5432 -starttls postgres
```

---

## Backup & Recovery

### Backup Script
**Locatie**: `configs/security/backup-databases.sh`

#### Features
- ✅ Gecomprimeerde backups (gzip level 9)
- ✅ Encryptie met AES-256 (GPG)
- ✅ Automatische backup rotatie (30 dagen default)
- ✅ Support voor alle database types
- ✅ Backup verificatie
- ✅ Cloud upload support (S3/Azure/GCS)

#### Gebruik
```bash
# Single database
./configs/security/backup-databases.sh postgresql

# Alle databases
BACKUP_ENCRYPTION_KEY="your_key" ./configs/security/backup-databases.sh all

# Met cloud upload
AWS_S3_BUCKET="my-backups" ./configs/security/backup-databases.sh all
```

#### Automatische Backups (Cron)
```bash
# Dagelijkse backup om 2:00
0 2 * * * BACKUP_ENCRYPTION_KEY="$(cat /run/secrets/backup_key)" /path/to/backup-databases.sh all >> /var/log/backups.log 2>&1
```

### Recovery Procedures

#### PostgreSQL
```bash
# Decrypt backup
gpg --decrypt backup.sql.gz.gpg | gunzip | psql -U postgres -d database_name
```

#### MySQL
```bash
# Decrypt and restore
gpg --decrypt backup.sql.gz.gpg | gunzip | mysql -u root -p database_name
```

#### MongoDB
```bash
# Extract and restore
gpg --decrypt backup.tar.gz.gpg | tar -xz
mongorestore --gzip dump/
```

#### Redis
```bash
# Decrypt RDB file
gpg --decrypt backup.rdb.gz.gpg | gunzip > /var/lib/redis/dump.rdb
docker-compose restart redis
```

---

## Monitoring & Auditing

### Database Monitoring

#### PostgreSQL
```bash
# Actieve connecties
docker exec postgres_prod psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Database grootte
docker exec postgres_prod psql -U postgres -c "SELECT pg_size_pretty(pg_database_size('production'));"

# Slow queries
docker exec postgres_prod psql -U postgres -c "SELECT * FROM pg_stat_statements ORDER BY total_exec_time DESC LIMIT 10;"
```

#### MySQL
```bash
# Processlist
docker exec mysql_prod mysql -u root -p -e "SHOW FULL PROCESSLIST;"

# Slow queries
docker exec mysql_prod mysql -u root -p -e "SELECT * FROM mysql.slow_log;"
```

#### MongoDB
```bash
# Database stats
docker exec mongodb_prod mongosh --eval "db.stats()"

# Current operations
docker exec mongodb_prod mongosh --eval "db.currentOp()"
```

#### Redis
```bash
# Info
docker exec redis_prod redis-cli INFO

# Connected clients
docker exec redis_prod redis-cli CLIENT LIST
```

### Log Aggregatie
Alle containers loggen naar JSON format met:
- Max 10MB per log file
- Maximaal 3 rotaties
- Labels voor filtering

```bash
# View logs
docker logs postgres_prod
docker logs --tail 100 -f mysql_prod
```

### Security Auditing
```bash
# Run Lynis security audit
sudo lynis audit system

# Docker security audit
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy image postgres:16-alpine
```

---

## Best Practices

### Development vs Production

#### Development
- ✅ Gebruik `.env.development.template`
- ✅ Zwakkere passwords OK
- ✅ TLS optioneel
- ✅ Verbose logging
- ✅ Langere timeouts

#### Production
- ✅ Gebruik `.env.production.template`
- ✅ Sterke passwords (32+ chars)
- ✅ TLS verplicht
- ✅ Minimal logging
- ✅ Strikte timeouts
- ✅ Resource limits
- ✅ Health checks
- ✅ Automatische backups
- ✅ Monitoring & alerting

### Security Checklist

#### Pre-Deployment
- [ ] Alle passwords zijn strong en uniek
- [ ] SSL/TLS certificaten zijn gegenereerd
- [ ] Docker secrets zijn geconfigureerd
- [ ] Firewall rules zijn ingesteld
- [ ] Backup strategie is getest
- [ ] Monitoring is geconfigureerd
- [ ] Recovery procedures zijn gedocumenteerd

#### Post-Deployment
- [ ] Verifieer TLS connecties
- [ ] Test database connectivity
- [ ] Controleer logs op errors
- [ ] Test backup en restore
- [ ] Run security audit
- [ ] Configureer alerting
- [ ] Documenteer access credentials (in vault!)

### Incident Response
1. **Detectie**: Monitoring alerts
2. **Isolatie**: Stop gecompromitteerde containers
3. **Analyse**: Bekijk logs en audit trails
4. **Eradicate**: Verwijder malware/backdoors
5. **Recovery**: Restore van clean backup
6. **Lessons Learned**: Update procedures

### Compliance

#### GDPR
- ✅ Data encryption at-rest en in-transit
- ✅ Access logging
- ✅ Right to erasure support
- ✅ Data minimization
- ✅ Regular backups

#### PCI-DSS
- ✅ Strong access controls
- ✅ Encrypted storage
- ✅ Regular security testing
- ✅ Audit trails
- ✅ Secure key management

---

## Support & Troubleshooting

### Common Issues

#### Connection Refused
```bash
# Check if container is running
docker ps | grep database_name

# Check logs
docker logs database_name

# Verify network
docker network inspect database_network
```

#### TLS Errors
```bash
# Verify certificate
openssl verify -CAfile ca.crt server.crt

# Check certificate dates
openssl x509 -in server.crt -noout -dates
```

#### Performance Issues
```bash
# Check resource usage
docker stats

# Increase resources in docker-compose.yml
```

### Getting Help
- GitHub Issues: https://github.com/ApiCentraal/VPS-Zero/issues
- Security Issues: security@vps-zero.nl (gebruik PGP)

---

## Licentie
MIT License - Zie [LICENSE](../../LICENSE)

## Bijdragen
Pull requests zijn welkom! Zie [CONTRIBUTING.md](CONTRIBUTING.md)

---

**⚠️ DISCLAIMER**: Deze configuratie is een starting point. Pas altijd aan op basis van uw specifieke security requirements en compliance vereisten. Laat security audits uitvoeren door professionals.
