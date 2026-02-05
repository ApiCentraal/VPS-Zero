# VPS-Zero

Enterprise Production Server Hardening Script voor Ubuntu 24.04 LTS. Dit script biedt een complete oplossing voor het beveiligen van VPS servers voor het draaien van gecontaineriseerde applicaties.

**🆕 NIEUW:** Enterprise-grade database configuraties, secrets management, en cybersecurity tools toegevoegd! Zie [configs/](configs/) directory voor complete database security setup.

**🖥️ WEB DASHBOARD:** Nu met een moderne web-based GUI voor server configuratie! Zie [dashboard/](dashboard/) voor installatie.

![Dashboard Preview](dashboard/docs/dashboard-preview.png)

## 🚀 Snelle Start

```bash
# Download en maak uitvoerbaar
chmod +x server-hardening.sh

# Start interactief menu
sudo ./server-hardening.sh

# Of volledige automatische installatie
sudo ./server-hardening.sh --full

# Start de web dashboard (GUI)
sudo ./server-hardening.sh --gui

# Help weergeven
sudo ./server-hardening.sh --help
```

### 🖥️ Web Dashboard Installatie

```bash
# Installeer de web dashboard
cd dashboard
sudo ./install-dashboard.sh

# Dashboard is beschikbaar op http://SERVER_IP:8080
# Standaard login: admin / changeme

# Na installatie kan je de dashboard starten met:
vps-zero-dashboard --start
# of
vps-zero-dashboard --yes
```

### Dashboard Commando's

```bash
# Start dashboard service
sudo vps-zero-dashboard --start
sudo vps-zero-dashboard --yes

# Stop dashboard
sudo vps-zero-dashboard --stop

# Herstart dashboard
sudo vps-zero-dashboard --restart

# Toon status
vps-zero-dashboard --status

# Start in foreground (voor debugging)
sudo vps-zero-dashboard --foreground
```

## ✨ Features

### Interactief Menu Systeem
- **Optie 1**: Volledige Automatische Installatie (aanbevolen)
- **Opties 2-16**: Individuele configuratie modules
- **Optie 20**: Systeem Status Dashboard
- **Optie 21**: Security Audit met Lynis
- **Optie 22**: Backup Configuratie

### Menu Opties Overzicht

| Optie | Functie | Beschrijving |
|-------|---------|--------------|
| 1 | Volledige Installatie | Voert alle hardening stappen automatisch uit |
| 2 | Systeem Updates | APT update, upgrade en cleanup |
| 3 | Docker Engine | Installeert Docker met security configuratie |
| 4 | UFW Firewall | Configureert firewall met rate limiting |
| 5 | SSH Hardening | Custom poort, key-only authenticatie |
| 6 | Fail2Ban | Brute-force bescherming |
| 7 | Kernel Security | Sysctl parameters voor beveiliging |
| 8 | Auditd | Linux Audit Framework |
| 9 | Auto Updates | Automatische security updates |
| 10 | Swap | Swap space configuratie |
| 11 | Filesystem | Hardening van /tmp, /var/tmp, /dev/shm |
| 12 | Logging | Logrotate en journald configuratie |
| 13 | User Management | PAM wachtwoord policy |
| 14 | Time Sync | NTP synchronisatie |
| 15 | Security Tools | AIDE, rkhunter, lynis, tripwire |
| 16 | Docker Security | User namespaces, seccomp profiles |
| 20 | Status | Systeem status dashboard |
| 21 | Security Audit | Lynis security scan |
| 22 | Backup | Configuratie backup maken |

### 🖥️ Web Dashboard

Het VPS-Zero dashboard biedt een moderne, browser-based interface voor:

- **Systeem Overzicht** - Real-time CPU, geheugen, schijf en uptime monitoring
- **Server Hardening** - Eén-klik toegang tot alle 16 hardening modules
- **Docker Management** - Bekijk en beheer containers en images
- **Firewall Configuratie** - Voeg UFW regels toe via GUI
- **SSH Instellingen** - Configureer SSH security parameters
- **Database Deployment** - Quick-deploy PostgreSQL, MySQL, MongoDB, Redis
- **SSL Certificaten** - Genereer self-signed certificaten
- **Security Tools** - Security scans en encrypted backups
- **Log Viewer** - Bekijk systeem logs in één interface

Zie [dashboard/README.md](dashboard/README.md) voor volledige documentatie.

## 🔧 Geïmplementeerde Hardening

- **Docker Engine** met security best practices
- **UFW Firewall** met rate limiting
- **SSH Hardening** (custom poort, key-only auth)
- **Fail2Ban** met Docker protection
- **Kernel Security Parameters** (sysctl)
- **Auditd** met uitgebreide rules
- **Automatische Security Updates** (unattended-upgrades)
- **Swap Configuratie** (2GB standaard)
- **Filesystem Hardening** (noexec, nosuid, nodev)
- **Logging & Logrotate** configuratie
- **User Management & PAM** hardening
- **NTP Synchronisatie** via systemd-timesyncd
- **Security Tools** (AIDE, Lynis, rkhunter, tripwire)
- **Docker Security** (user namespaces, seccomp)

## 🛡️ Veiligheidsfeatures

- ✅ Automatische backups van alle configuraties
- ✅ Gedetailleerde logging (`/var/log/server-hardening/`)
- ✅ Color-coded output (info/success/warning/error)
- ✅ Bevestigingen voor kritieke acties
- ✅ Error handling met `set -euo pipefail`
- ✅ Rollback mogelijkheid via backups

## 📋 Vereisten

- Ubuntu 24.04 LTS (of compatibele versie)
- Root toegang (sudo)
- Werkende internetverbinding
- SSH toegang (voor remote servers)

## ⚠️ Belangrijke Waarschuwingen

Na installatie:
1. SSH draait op een **custom poort** (standaard: 2222)
2. Alleen **SSH key authenticatie** is toegestaan
3. **UFW firewall** is actief
4. **Herstart** de server voor alle wijzigingen: `sudo reboot`

## 📁 Bestanden Locaties

| Type | Locatie |
|------|---------|
| Logs | `/var/log/server-hardening/` |
| Backups | `/root/config-backups-{timestamp}/` |
| Docker config | `/etc/docker/daemon.json` |
| SSH config | `/etc/ssh/sshd_config.d/99-hardening.conf` |
| Firewall | `/etc/ufw/` |
| Audit rules | `/etc/audit/rules.d/hardening.rules` |

## 🔄 Omgevingsvariabelen

```bash
# SSH configuratie (optioneel)
export SSH_PORT=22           # Huidige SSH poort
export CUSTOM_SSH_PORT=2222  # Nieuwe SSH poort

# Admin email voor notificaties
export ADMIN_EMAIL=admin@example.com
```

## 🗄️ Database & Application Security

VPS-Zero bevat nu **enterprise-grade configuraties** voor een volledig beveiligde database en application omgeving:

### Database Support
- **PostgreSQL** - TLS, SCRAM-SHA-256, WAL archiving
- **MySQL** - SSL/TLS, caching_sha2_password, replicatie
- **MongoDB** - TLS, authorization, WiredTiger
- **Redis** - TLS only, ACL, password auth

### Security Features
- ✅ **Zero-Attack Surface** - Minimale attack oppervlak
- ✅ **Defense in Depth** - Meerdere beveiligingslagen  
- ✅ **Encryption Everywhere** - Data-at-rest en in-transit
- ✅ **Secrets Management** - Docker Secrets + Vault support
- ✅ **Container Hardening** - Read-only FS, no-root, seccomp
- ✅ **Network Isolation** - Geïsoleerde Docker networks
- ✅ **Automated Backups** - Encrypted, rotatie, cloud upload
- ✅ **Security Scanning** - Trivy, CIS Benchmark, secrets scan

### Configuratie Directories

| Directory | Beschrijving |
|-----------|--------------|
| `configs/database/` | Database configuraties (PostgreSQL, MySQL, MongoDB, Redis) |
| `configs/docker/` | Docker security hardening (daemon.json, seccomp) |
| `configs/security/` | Security scripts (backup, scanning) |
| `configs/ssl/` | SSL/TLS certificate generation |
| `configs/.env.*` | Environment templates (dev/prod) |
| `secrets/` | Secret management templates |

### Quick Start Database

```bash
# 1. Genereer SSL/TLS certificaten
cd configs/ssl
sudo ./generate-certificates.sh all

# 2. Setup secrets
cd ../
cp .env.production.template .env.production
# Edit en vervang alle CHANGEME waarden

# 3. Deploy database (bijvoorbeeld PostgreSQL)
cd database/postgresql
docker-compose -f docker-compose.prod.yml up -d

# 4. Verifieer
docker-compose ps
docker-compose logs
```

### Documentatie

Zie de volgende guides voor meer details:

- 🚀 [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - **Complete deployment walkthrough**
- 📘 [SECURITY-CONFIG.md](SECURITY-CONFIG.md) - Complete security configuratie gids
- 🔐 [SECRETS-MANAGEMENT.md](SECRETS-MANAGEMENT.md) - Secrets management guide
- 📁 [configs/README.md](configs/README.md) - Configuratie directory overview

### Security Tools

```bash
# Encrypted database backups
./configs/security/backup-databases.sh all

# Security scanning (Trivy, CIS Docker Benchmark)
sudo ./configs/security/security-scan.sh --full

# Certificate generation
sudo ./configs/ssl/generate-certificates.sh all
```

## 📄 Licentie

MIT License - Zie [LICENSE](LICENSE) voor details.

## 🤝 Bijdragen

Bijdragen zijn welkom! Open een issue of pull request voor verbeteringen.
