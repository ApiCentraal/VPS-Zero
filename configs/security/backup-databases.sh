#!/bin/bash
################################################################################
# Database Backup Script
# Enterprise-grade encrypted backup solution
#
# Features:
# - Encrypted backups voor alle databases
# - Automatische rotatie
# - Cloud upload (optioneel)
# - Backup verificatie
#
# Gebruik: ./backup-databases.sh [database-type]
################################################################################

set -euo pipefail

# Kleuren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuratie
BACKUP_ROOT="/var/backups/databases"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
RETENTION_DAYS=30
ENCRYPTION_ENABLED=true
COMPRESSION_LEVEL=9

# Logging
LOG_DIR="/var/log/database-backups"
LOG_FILE="${LOG_DIR}/backup-${TIMESTAMP}.log"

# Database configuratie - gebruik secrets in productie
POSTGRES_HOST="${POSTGRES_HOST:-localhost}"
POSTGRES_PORT="${POSTGRES_PORT:-5432}"
POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-postgres}"

MYSQL_HOST="${MYSQL_HOST:-localhost}"
MYSQL_PORT="${MYSQL_PORT:-3306}"
MYSQL_USER="${MYSQL_USER:-root}"

MONGO_HOST="${MONGO_HOST:-localhost}"
MONGO_PORT="${MONGO_PORT:-27017}"

REDIS_HOST="${REDIS_HOST:-localhost}"
REDIS_PORT="${REDIS_PORT:-6379}"

info() {
    local msg="$@"
    echo -e "${BLUE}[INFO]${NC} $msg" | tee -a "$LOG_FILE"
}

success() {
    local msg="$@"
    echo -e "${GREEN}[SUCCESS]${NC} $msg" | tee -a "$LOG_FILE"
}

warning() {
    local msg="$@"
    echo -e "${YELLOW}[WARNING]${NC} $msg" | tee -a "$LOG_FILE"
}

error() {
    local msg="$@"
    echo -e "${RED}[ERROR]${NC} $msg" | tee -a "$LOG_FILE"
    exit 1
}

setup_logging() {
    mkdir -p "$LOG_DIR"
    info "Backup gestart op $(date)"
}

encrypt_backup() {
    local file=$1
    local encrypted_file="${file}.gpg"
    
    if [[ "$ENCRYPTION_ENABLED" == "true" ]]; then
        info "Versleutelen backup: $(basename $file)"
        
        # Gebruik GPG met symmetrische encryptie
        # In productie: gebruik GPG key of secrets management
        gpg --batch --yes --passphrase "${BACKUP_ENCRYPTION_KEY:-default_key_change_me}" \
            --symmetric --cipher-algo AES256 \
            --output "$encrypted_file" "$file"
        
        # Verwijder onversleutelde backup
        rm -f "$file"
        
        success "Backup versleuteld: $(basename $encrypted_file)"
        echo "$encrypted_file"
    else
        echo "$file"
    fi
}

backup_postgresql() {
    info "Starten PostgreSQL backup..."
    
    local backup_dir="${BACKUP_ROOT}/postgresql/${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # Full database dump
    local dump_file="${backup_dir}/postgresql-${TIMESTAMP}.sql.gz"
    
    PGPASSWORD="${POSTGRES_PASSWORD}" pg_dump \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        -d "$POSTGRES_DB" \
        --clean --if-exists \
        --verbose \
        | gzip -${COMPRESSION_LEVEL} > "$dump_file"
    
    # Versleutel backup
    local final_file=$(encrypt_backup "$dump_file")
    
    # Backup globals (users, roles)
    local globals_file="${backup_dir}/postgresql-globals-${TIMESTAMP}.sql.gz"
    PGPASSWORD="${POSTGRES_PASSWORD}" pg_dumpall \
        -h "$POSTGRES_HOST" \
        -p "$POSTGRES_PORT" \
        -U "$POSTGRES_USER" \
        --globals-only \
        | gzip -${COMPRESSION_LEVEL} > "$globals_file"
    
    encrypt_backup "$globals_file"
    
    success "PostgreSQL backup voltooid: $(basename $backup_dir)"
}

backup_mysql() {
    info "Starten MySQL backup..."
    
    local backup_dir="${BACKUP_ROOT}/mysql/${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # Full database dump
    local dump_file="${backup_dir}/mysql-${TIMESTAMP}.sql.gz"
    
    mysqldump \
        -h "$MYSQL_HOST" \
        -P "$MYSQL_PORT" \
        -u "$MYSQL_USER" \
        -p"${MYSQL_PASSWORD}" \
        --all-databases \
        --single-transaction \
        --quick \
        --lock-tables=false \
        --routines \
        --triggers \
        --events \
        | gzip -${COMPRESSION_LEVEL} > "$dump_file"
    
    # Versleutel backup
    encrypt_backup "$dump_file"
    
    success "MySQL backup voltooid: $(basename $backup_dir)"
}

backup_mongodb() {
    info "Starten MongoDB backup..."
    
    local backup_dir="${BACKUP_ROOT}/mongodb/${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # MongoDB dump
    mongodump \
        --host "$MONGO_HOST" \
        --port "$MONGO_PORT" \
        --username "${MONGO_USER}" \
        --password "${MONGO_PASSWORD}" \
        --authenticationDatabase admin \
        --gzip \
        --out "$backup_dir/dump"
    
    # Tar en versleutel
    local tar_file="${backup_dir}/mongodb-${TIMESTAMP}.tar.gz"
    tar -czf "$tar_file" -C "$backup_dir" dump
    rm -rf "${backup_dir}/dump"
    
    encrypt_backup "$tar_file"
    
    success "MongoDB backup voltooid: $(basename $backup_dir)"
}

backup_redis() {
    info "Starten Redis backup..."
    
    local backup_dir="${BACKUP_ROOT}/redis/${TIMESTAMP}"
    mkdir -p "$backup_dir"
    
    # Trigger Redis BGSAVE
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "${REDIS_PASSWORD}" BGSAVE
    
    # Wacht tot save compleet is
    sleep 5
    
    # Kopieer RDB file
    local rdb_file="${backup_dir}/redis-${TIMESTAMP}.rdb.gz"
    
    # Gebruik redis-cli om data te exporteren
    redis-cli -h "$REDIS_HOST" -p "$REDIS_PORT" -a "${REDIS_PASSWORD}" \
        --rdb /tmp/dump.rdb
    
    gzip -${COMPRESSION_LEVEL} -c /tmp/dump.rdb > "$rdb_file"
    rm -f /tmp/dump.rdb
    
    encrypt_backup "$rdb_file"
    
    success "Redis backup voltooid: $(basename $backup_dir)"
}

cleanup_old_backups() {
    info "Opruimen oude backups (ouder dan ${RETENTION_DAYS} dagen)..."
    
    find "$BACKUP_ROOT" -type f -mtime +${RETENTION_DAYS} -delete
    find "$BACKUP_ROOT" -type d -empty -delete
    
    success "Oude backups opgeruimd"
}

verify_backup() {
    local backup_file=$1
    
    if [[ -f "$backup_file" ]]; then
        local size=$(du -h "$backup_file" | cut -f1)
        info "Backup bestand grootte: $size"
        
        # Test GPG decryptie zonder data te schrijven
        if [[ "$backup_file" == *.gpg ]]; then
            gpg --batch --yes --passphrase "${BACKUP_ENCRYPTION_KEY:-default_key_change_me}" \
                --decrypt "$backup_file" > /dev/null 2>&1
            
            if [[ $? -eq 0 ]]; then
                success "Backup encryptie geverifieerd"
            else
                error "Backup encryptie verificatie gefaald!"
            fi
        fi
    fi
}

upload_to_cloud() {
    local backup_dir=$1
    
    # Placeholder voor cloud upload
    # Implementeer AWS S3, Azure Blob, GCS, etc.
    
    if [[ -n "${AWS_S3_BUCKET:-}" ]]; then
        info "Uploaden naar S3: $AWS_S3_BUCKET"
        # aws s3 sync "$backup_dir" "s3://${AWS_S3_BUCKET}/backups/"
    fi
}

show_usage() {
    cat << EOF
Gebruik: $0 [database-type]

Opties:
    postgresql   Backup PostgreSQL database
    mysql        Backup MySQL database
    mongodb      Backup MongoDB database
    redis        Backup Redis database
    all          Backup alle databases

Omgevingsvariabelen:
    POSTGRES_PASSWORD    PostgreSQL wachtwoord
    MYSQL_PASSWORD       MySQL wachtwoord
    MONGO_PASSWORD       MongoDB wachtwoord
    REDIS_PASSWORD       Redis wachtwoord
    BACKUP_ENCRYPTION_KEY Encryptie key voor backups

Voorbeelden:
    $0 postgresql
    $0 all
    
    # Met encryptie key:
    BACKUP_ENCRYPTION_KEY=your_key $0 all
EOF
}

main() {
    setup_logging
    
    local db_type="${1:-all}"
    
    case $db_type in
        postgresql)
            backup_postgresql
            ;;
        mysql)
            backup_mysql
            ;;
        mongodb)
            backup_mongodb
            ;;
        redis)
            backup_redis
            ;;
        all)
            backup_postgresql
            backup_mysql
            backup_mongodb
            backup_redis
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Onbekende optie: $db_type. Gebruik -h voor help."
            ;;
    esac
    
    cleanup_old_backups
    
    success "Backup proces voltooid!"
    info "Backup locatie: $BACKUP_ROOT"
    info "Log bestand: $LOG_FILE"
}

main "$@"
