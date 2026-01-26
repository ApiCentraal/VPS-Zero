# Docker Secrets Setup Guide
## Veilig beheren van gevoelige data

### Overzicht
Docker Secrets biedt een veilige manier om gevoelige data (passwords, API keys, certificates) te beheren in productie omgevingen.

## Quick Start

### 1. Initialiseer Docker Swarm (vereist voor secrets)
```bash
docker swarm init
```

### 2. Aanmaken van Secrets

#### Via Bestand
```bash
# PostgreSQL
echo "your_strong_password" | docker secret create postgres_password -
echo "app_user" | docker secret create postgres_user -

# MySQL
echo "mysql_root_password" | docker secret create mysql_root_password -
echo "app_user" | docker secret create mysql_user -
echo "mysql_app_password" | docker secret create mysql_password -

# MongoDB
echo "mongodb_admin" | docker secret create mongo_root_user -
echo "mongo_strong_password" | docker secret create mongo_root_password -

# Redis
echo "redis_strong_password" | docker secret create redis_password -

# Application secrets
openssl rand -base64 64 | docker secret create jwt_secret -
openssl rand -hex 32 | docker secret create encryption_key -
```

#### Via File (aanbevolen voor productie)
```bash
# Maak secrets directory aan
mkdir -p /run/secrets-source
chmod 700 /run/secrets-source

# Genereer secrets
openssl rand -base64 32 > /run/secrets-source/postgres_password
openssl rand -base64 32 > /run/secrets-source/mysql_password
openssl rand -base64 32 > /run/secrets-source/mongo_password
openssl rand -base64 32 > /run/secrets-source/redis_password

# Importeer in Docker
docker secret create postgres_password /run/secrets-source/postgres_password
docker secret create mysql_password /run/secrets-source/mysql_password
docker secret create mongo_password /run/secrets-source/mongo_password
docker secret create redis_password /run/secrets-source/redis_password

# Verwijder source bestanden (ze zijn nu veilig in Docker)
shred -u /run/secrets-source/*
```

### 3. Secrets Gebruiken in Docker Compose

```yaml
version: '3.9'

services:
  database:
    image: postgres:16
    secrets:
      - postgres_password
      - postgres_user
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/postgres_password
      POSTGRES_USER_FILE: /run/secrets/postgres_user

secrets:
  postgres_password:
    external: true
  postgres_user:
    external: true
```

### 4. Secrets Lezen in Applicatie

#### Bash
```bash
#!/bin/bash
DB_PASSWORD=$(cat /run/secrets/postgres_password)
```

#### Python
```python
def read_secret(secret_name):
    try:
        with open(f'/run/secrets/{secret_name}', 'r') as f:
            return f.read().strip()
    except FileNotFoundError:
        return os.getenv(secret_name.upper())

db_password = read_secret('postgres_password')
```

#### Node.js
```javascript
const fs = require('fs');

function readSecret(secretName) {
  try {
    return fs.readFileSync(`/run/secrets/${secretName}`, 'utf8').trim();
  } catch (err) {
    return process.env[secretName.toUpperCase()];
  }
}

const dbPassword = readSecret('postgres_password');
```

#### Go
```go
package main

import (
    "io/ioutil"
    "os"
    "strings"
)

func ReadSecret(secretName string) (string, error) {
    data, err := ioutil.ReadFile("/run/secrets/" + secretName)
    if err != nil {
        // Fallback to environment variable
        return os.Getenv(strings.ToUpper(secretName)), nil
    }
    return strings.TrimSpace(string(data)), nil
}

func main() {
    dbPassword, _ := ReadSecret("postgres_password")
}
```

## Beheer van Secrets

### Lijst van Secrets
```bash
docker secret ls
```

### Inspecteer Secret (metadata only)
```bash
docker secret inspect postgres_password
```

### Verwijder Secret
```bash
docker secret rm postgres_password
```

### Update Secret (rotate)
```bash
# 1. Maak nieuwe secret met andere naam
echo "new_password" | docker secret create postgres_password_v2 -

# 2. Update docker-compose.yml om nieuwe secret te gebruiken
# 3. Deploy update
docker stack deploy -c docker-compose.yml myapp

# 4. Verwijder oude secret
docker secret rm postgres_password

# 5. Hernoem nieuwe secret (optioneel)
```

## Best Practices

### ✅ DO
- Gebruik unieke, sterke passwords voor elke service
- Roteer secrets regelmatig (elke 90 dagen)
- Gebruik Docker Secrets in productie
- Beperk toegang tot secrets (least privilege)
- Audit secret toegang
- Gebruik secret versioning (_v1, _v2)
- Test secret rotatie procedures

### ❌ DON'T
- Commit secrets naar git
- Hard-code secrets in code
- Log secret waarden
- Email/slack secrets in plaintext
- Hergebruik secrets tussen omgevingen
- Deel secrets via onveilige kanalen

## Alternative: HashiCorp Vault

Voor enterprise deployments overweeg HashiCorp Vault:

### Installatie
```bash
# Download Vault
wget https://releases.hashicorp.com/vault/1.15.0/vault_1.15.0_linux_amd64.zip
unzip vault_1.15.0_linux_amd64.zip
sudo mv vault /usr/local/bin/

# Start Vault (dev mode voor testing)
vault server -dev

# Export Vault address
export VAULT_ADDR='http://127.0.0.1:8200'
```

### Gebruik
```bash
# Login
vault login

# Store secret
vault kv put secret/database password="strongpassword"

# Read secret
vault kv get secret/database

# In applicatie (met Vault agent)
DATABASE_PASSWORD=$(vault kv get -field=password secret/database)
```

### Vault in Docker Compose
```yaml
version: '3.9'

services:
  vault:
    image: vault:latest
    cap_add:
      - IPC_LOCK
    environment:
      VAULT_DEV_ROOT_TOKEN_ID: 'root'
    ports:
      - "8200:8200"
  
  app:
    image: myapp
    environment:
      VAULT_ADDR: http://vault:8200
      VAULT_TOKEN: ${VAULT_TOKEN}
```

## Troubleshooting

### Secret niet gevonden
```bash
# Verify secret exists
docker secret ls | grep postgres_password

# Check service logs
docker service logs myapp
```

### Permission denied
```bash
# Check service configuration
docker service inspect myapp

# Verify secret is attached to service
docker service inspect myapp | grep -A 10 Secrets
```

### Secret niet updated na rotatie
```bash
# Force service update
docker service update --force myapp

# Of gebruik rolling update
docker service update --secret-rm postgres_password \
  --secret-add postgres_password_v2 myapp
```

## Security Checklist

- [ ] Docker Swarm mode geactiveerd
- [ ] Secrets bestanden niet in git
- [ ] Strong passwords gebruikt (32+ chars)
- [ ] Secrets geroteerd na initiële setup
- [ ] Applicatie leest secrets correct
- [ ] Logging bevat geen secret waarden
- [ ] Backup van secrets (encrypted!)
- [ ] Recovery procedure gedocumenteerd
- [ ] Team getraind in secrets management
- [ ] Audit logging ingeschakeld

## Resources
- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [HashiCorp Vault](https://www.vaultproject.io/)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)
