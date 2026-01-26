# Deployment Guide
## Enterprise-Grade Cybersecure VPS Setup

Deze gids leidt je door de complete setup van een enterprise-grade, cybersecure VPS omgeving met zero-attack surface benadering.

## 📋 Prerequisites

- Ubuntu 24.04 LTS server
- Root/sudo toegang
- Minimaal 4GB RAM
- 20GB vrije schijfruimte
- Werkende internetverbinding
- SSH toegang

## 🚀 Complete Deployment Process

### Fase 1: Server Hardening (30-45 minuten)

#### 1.1 Download en voer server hardening script uit

```bash
# Clone repository
git clone https://github.com/ApiCentraal/VPS-Zero.git
cd VPS-Zero

# Maak hardening script uitvoerbaar
chmod +x server-hardening.sh

# Voer volledige hardening uit
sudo ./server-hardening.sh --full
```

Dit installeert en configureert:
- ✅ Docker Engine met security configuratie
- ✅ UFW Firewall met rate limiting
- ✅ SSH Hardening (custom poort 2222, key-only)
- ✅ Fail2Ban voor brute-force bescherming
- ✅ Kernel security parameters (sysctl)
- ✅ Auditd logging
- ✅ Automatische security updates
- ✅ Swap configuratie
- ✅ Filesystem hardening
- ✅ Security tools (AIDE, Lynis, rkhunter)

⚠️ **BELANGRIJK**: Na installatie:
1. Noteer de nieuwe SSH poort (standaard: 2222)
2. Test SSH verbinding VOORDAT je huidige sessie sluit
3. Herstart de server: `sudo reboot`

#### 1.2 Herverbind via nieuwe SSH poort

```bash
ssh -p 2222 user@your-server-ip
```

### Fase 2: SSL/TLS Certificaten (10-15 minuten)

#### 2.1 Genereer certificaten voor databases

**Optie A: Development (Self-Signed)**
```bash
cd configs/ssl
sudo ./generate-certificates.sh all
```

Certificaten worden gegenereerd in `/etc/ssl/database-certs/`

**Optie B: Production (Let's Encrypt)**
```bash
# Installeer certbot
sudo apt-get install -y certbot

# Voor PostgreSQL
sudo certbot certonly --standalone \
  -d postgres.yourdomain.com \
  --agree-tos \
  --email admin@yourdomain.com

# Voor MySQL
sudo certbot certonly --standalone \
  -d mysql.yourdomain.com \
  --agree-tos \
  --email admin@yourdomain.com

# Certificaten zijn in: /etc/letsencrypt/live/
```

#### 2.2 Configureer auto-renewal voor Let's Encrypt

```bash
# Voeg cron job toe
echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl restart docker'" | sudo crontab -
```

### Fase 3: Secrets Configuration (15-20 minuten)

#### 3.1 Genereer sterke passwords

```bash
# PostgreSQL password (32 chars)
POSTGRES_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "PostgreSQL Password: $POSTGRES_PASS"

# MySQL password
MYSQL_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "MySQL Password: $MYSQL_PASS"

# MongoDB password
MONGO_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "MongoDB Password: $MONGO_PASS"

# Redis password
REDIS_PASS=$(openssl rand -base64 32 | tr -d "=+/" | cut -c1-32)
echo "Redis Password: $REDIS_PASS"

# JWT Secret (64 bytes)
JWT_SECRET=$(openssl rand -base64 64)
echo "JWT Secret: $JWT_SECRET"

# Encryption key (32 bytes hex)
ENC_KEY=$(openssl rand -hex 32)
echo "Encryption Key: $ENC_KEY"
```

⚠️ **Bewaar deze waarden veilig!** Gebruik een password manager.

#### 3.2 Setup Docker Secrets (Productie)

```bash
# Initialiseer Docker Swarm
sudo docker swarm init

# Maak secrets aan (gebruik gegenereerde passwords)
echo "$POSTGRES_PASS" | sudo docker secret create postgres_password -
echo "app_user" | sudo docker secret create postgres_user -

echo "$MYSQL_PASS" | sudo docker secret create mysql_root_password -
echo "app_user" | sudo docker secret create mysql_user -
echo "$MYSQL_PASS" | sudo docker secret create mysql_password -

echo "admin" | sudo docker secret create mongo_root_user -
echo "$MONGO_PASS" | sudo docker secret create mongo_root_password -

# Verifieer
sudo docker secret ls
```

#### 3.3 Configure Environment Variables

```bash
cd configs

# Kopieer template
cp .env.production.template .env.production

# Edit met gegenereerde waarden
nano .env.production
```

Vervang alle `CHANGEME` waarden met je gegenereerde secrets.

### Fase 4: Database Deployment (20-30 minuten)

#### 4.1 Kies en deploy database(s)

**PostgreSQL:**
```bash
cd configs/database/postgresql

# Kopieer certificaten naar volume
sudo mkdir -p /var/lib/postgresql/data
sudo cp /etc/ssl/database-certs/postgresql/* /var/lib/postgresql/data/
sudo chown -R 70:70 /var/lib/postgresql/data

# Start PostgreSQL
sudo docker-compose -f docker-compose.prod.yml up -d

# Verifieer
sudo docker-compose ps
sudo docker-compose logs
sudo docker exec postgres_prod pg_isready -U postgres
```

**MySQL:**
```bash
cd configs/database/mysql

# Kopieer certificaten
sudo mkdir -p /var/lib/mysql
sudo cp /etc/ssl/database-certs/mysql/* /var/lib/mysql/
sudo chown -R 999:999 /var/lib/mysql

# Start MySQL
sudo docker-compose -f docker-compose.prod.yml up -d

# Verifieer
sudo docker-compose ps
sudo docker-compose logs
sudo docker exec mysql_prod mysqladmin ping -h localhost
```

**MongoDB:**
```bash
cd configs/database/mongodb

# Kopieer certificaten
sudo mkdir -p /data/configdb
sudo cp /etc/ssl/database-certs/mongodb/* /data/configdb/
sudo chown -R 999:999 /data/configdb

# Start MongoDB
sudo docker-compose -f docker-compose.prod.yml up -d

# Verifieer
sudo docker-compose ps
sudo docker-compose logs
```

**Redis:**
```bash
cd configs/database/redis

# Kopieer certificaten
sudo mkdir -p /var/lib/redis/data
sudo cp /etc/ssl/database-certs/redis/* /var/lib/redis/data/
sudo chown -R 999:999 /var/lib/redis/data

# Start Redis
REDIS_PASSWORD="$REDIS_PASS" sudo -E docker-compose -f docker-compose.prod.yml up -d

# Verifieer
sudo docker-compose ps
sudo docker-compose logs
```

#### 4.2 Test database connecties

**PostgreSQL:**
```bash
PGPASSWORD="$POSTGRES_PASS" psql -h localhost -p 5432 -U app_user -d production -c "SELECT version();"
```

**MySQL:**
```bash
mysql -h localhost -P 3306 -u app_user -p"$MYSQL_PASS" -e "SELECT VERSION();"
```

**MongoDB:**
```bash
mongosh --host localhost --port 27017 -u admin -p "$MONGO_PASS" --authenticationDatabase admin
```

**Redis:**
```bash
redis-cli -h localhost -p 6380 --tls \
  --cert /var/lib/redis/data/redis.crt \
  --key /var/lib/redis/data/redis.key \
  --cacert /var/lib/redis/data/ca.crt \
  -a "$REDIS_PASS" PING
```

### Fase 5: Backup Configuration (10 minuten)

#### 5.1 Setup automated backups

```bash
# Test backup script
BACKUP_ENCRYPTION_KEY="$ENC_KEY" \
  sudo -E ./configs/security/backup-databases.sh postgresql

# Verifieer backup
ls -lh /var/backups/databases/postgresql/

# Setup cron voor dagelijkse backups (2 AM)
(sudo crontab -l 2>/dev/null; echo "0 2 * * * BACKUP_ENCRYPTION_KEY='$ENC_KEY' /home/ubuntu/VPS-Zero/configs/security/backup-databases.sh all >> /var/log/database-backups/cron.log 2>&1") | sudo crontab -
```

#### 5.2 Test backup recovery

```bash
# Test decrypt
gpg --batch --passphrase "$ENC_KEY" \
  --decrypt /var/backups/databases/postgresql/*/postgresql-*.sql.gz.gpg | gunzip | head -20
```

### Fase 6: Security Scanning (15 minuten)

#### 6.1 Run initial security scan

```bash
cd /home/ubuntu/VPS-Zero
sudo ./configs/security/security-scan.sh --full
```

#### 6.2 Review security reports

```bash
# View reports
ls -lh /var/log/security-scans/

# Check summary
cat /var/log/security-scans/summary-*.txt

# Review critical issues
grep -i "critical\|high" /var/log/security-scans/trivy-scan-*.txt
```

#### 6.3 Setup weekly security scans

```bash
# Add cron for weekly scans (Sunday 4 AM)
(sudo crontab -l 2>/dev/null; echo "0 4 * * 0 /home/ubuntu/VPS-Zero/configs/security/security-scan.sh --full >> /var/log/security-scans/weekly.log 2>&1") | sudo crontab -
```

### Fase 7: Monitoring Setup (10 minuten)

#### 7.1 Setup log monitoring

```bash
# Check logs
sudo tail -f /var/log/docker/daemon.log
sudo docker-compose -f configs/database/postgresql/docker-compose.prod.yml logs -f

# Setup log rotation (already configured in hardening script)
sudo cat /etc/logrotate.d/docker
```

#### 7.2 Setup alerts (optioneel)

Voor productie, configureer monitoring met:
- Prometheus + Grafana voor metrics
- ELK Stack voor log aggregatie
- Sentry voor error tracking
- Uptime Robot voor uptime monitoring

### Fase 8: Final Validation (10 minuten)

#### 8.1 Run validation script

```bash
cd /home/ubuntu/VPS-Zero
./validate-configs.sh
```

Verwacht output:
```
Passed:   54
Warnings: 0
Errors:   0
✓ All critical checks passed!
```

#### 8.2 Security checklist

Verifieer:
- [ ] Server hardening voltooid (Lynis score > 75)
- [ ] SSH draait op custom poort (2222)
- [ ] Firewall actief (UFW enabled)
- [ ] Fail2Ban actief
- [ ] SSL/TLS certificaten gegenereerd
- [ ] Docker secrets geconfigureerd
- [ ] Database(s) draaien met TLS
- [ ] Backups werkend en getест
- [ ] Security scan uitgevoerd
- [ ] Monitoring geconfigureerd
- [ ] Alle passwords veilig opgeslagen
- [ ] Documentatie up-to-date

## 📊 Post-Deployment

### Dagelijkse taken
- Check logs voor errors: `sudo docker-compose logs --tail 100`
- Monitor disk usage: `df -h`
- Check backup status: `ls -lh /var/backups/databases/`

### Wekelijkse taken
- Review security scan reports
- Check for system updates: `sudo apt update && sudo apt list --upgradable`
- Verify backup recovery
- Review access logs

### Maandelijkse taken
- Rotate database passwords
- Review and update firewall rules
- Security audit met Lynis: `sudo lynis audit system`
- Update Docker images: `docker-compose pull && docker-compose up -d`
- Test disaster recovery procedures

## 🆘 Troubleshooting

### Database niet bereikbaar
```bash
# Check container status
sudo docker ps -a

# Check logs
sudo docker-compose logs database_name

# Check network
sudo docker network ls
sudo docker network inspect database_network

# Verify TLS certificates
openssl x509 -in /path/to/cert -noout -dates
```

### Backup fails
```bash
# Check disk space
df -h

# Check permissions
ls -la /var/backups/databases/

# Test encryption key
echo "test" | gpg --batch --passphrase "$ENC_KEY" --symmetric
```

### Performance issues
```bash
# Check resource usage
sudo docker stats

# Check database stats
sudo docker exec postgres_prod psql -U postgres -c "SELECT * FROM pg_stat_activity;"

# Increase resources in docker-compose.yml
```

## 📚 Resources

- [SECURITY-CONFIG.md](SECURITY-CONFIG.md) - Uitgebreide security configuratie
- [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md) - Secrets beheer
- [configs/README.md](configs/README.md) - Configuratie overzicht
- [Docker Security Best Practices](https://docs.docker.com/engine/security/)
- [CIS Docker Benchmark](https://www.cisecurity.org/benchmark/docker)

## 🔒 Security Contacts

- GitHub Issues: https://github.com/ApiCentraal/VPS-Zero/issues
- Security advisories: Gebruik GitHub Security tab
- Emergency: Documenteer in je incident response plan

## ✅ Deployment Voltooid!

Je hebt nu een volledig beveiligde, enterprise-grade VPS omgeving met:
- 🛡️ Server hardening met 16 beveiligingslagen
- 🔒 Encrypted databases met TLS/SSL
- 🔐 Secrets management met Docker Secrets
- 💾 Automated encrypted backups
- 🔍 Security scanning & monitoring
- 📊 Comprehensive logging & auditing

**Volgende stappen:**
1. Deploy je applicatie
2. Configure application-level security
3. Setup CI/CD pipeline
4. Implement disaster recovery plan
5. Train team op security procedures

---

**⚠️ REMINDER**: Security is een continu proces, geen eenmalige setup. Blijf systemen updaten, monitoren en testen!
