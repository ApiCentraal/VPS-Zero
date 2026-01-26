#!/bin/bash
################################################################################
# SSL/TLS Certificate Generation Script
# Voor Enterprise-grade Database Security
#
# Dit script genereert zelf-ondertekende certificaten voor development
# of integreert met Let's Encrypt voor productie
#
# Gebruik: sudo ./generate-certificates.sh [database-type]
# Opties: postgresql, mysql, mongodb, redis, all
################################################################################

set -euo pipefail

# Kleuren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuratie
CERT_DIR="/etc/ssl/database-certs"
DAYS_VALID=3650  # 10 jaar voor self-signed
COUNTRY="NL"
STATE="Noord-Holland"
CITY="Amsterdam"
ORG="VPS-Zero"
OU="Database"

info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@"
}

error() {
    echo -e "${RED}[ERROR]${NC} $@"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Dit script moet als root uitgevoerd worden"
    fi
}

create_ca() {
    local db_type=$1
    local cert_path="${CERT_DIR}/${db_type}"
    
    info "Genereren CA certificaat voor ${db_type}..."
    
    mkdir -p "$cert_path"
    cd "$cert_path"
    
    # Genereer CA private key
    openssl genrsa -out ca.key 4096
    chmod 400 ca.key
    
    # Genereer CA certificaat
    openssl req -new -x509 -days ${DAYS_VALID} -key ca.key -out ca.crt \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${db_type}-ca"
    
    success "CA certificaat gegenereerd voor ${db_type}"
}

generate_server_cert() {
    local db_type=$1
    local cert_path="${CERT_DIR}/${db_type}"
    
    info "Genereren server certificaat voor ${db_type}..."
    
    cd "$cert_path"
    
    # Genereer server private key
    openssl genrsa -out server.key 4096
    chmod 400 server.key
    
    # Genereer server CSR
    openssl req -new -key server.key -out server.csr \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${db_type}-server"
    
    # Creëer extensie bestand voor SAN
    cat > server.ext << EOF
subjectAltName = @alt_names
extendedKeyUsage = serverAuth

[alt_names]
DNS.1 = ${db_type}
DNS.2 = localhost
DNS.3 = *.${db_type}
IP.1 = 127.0.0.1
IP.2 = ::1
EOF
    
    # Onderteken server certificaat met CA
    openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out server.crt -days ${DAYS_VALID} \
        -extfile server.ext
    
    # Cleanup
    rm server.csr server.ext
    
    success "Server certificaat gegenereerd voor ${db_type}"
}

generate_client_cert() {
    local db_type=$1
    local cert_path="${CERT_DIR}/${db_type}"
    
    info "Genereren client certificaat voor ${db_type}..."
    
    cd "$cert_path"
    
    # Genereer client private key
    openssl genrsa -out client.key 4096
    chmod 400 client.key
    
    # Genereer client CSR
    openssl req -new -key client.key -out client.csr \
        -subj "/C=${COUNTRY}/ST=${STATE}/L=${CITY}/O=${ORG}/OU=${OU}/CN=${db_type}-client"
    
    # Onderteken client certificaat met CA
    openssl x509 -req -in client.csr -CA ca.crt -CAkey ca.key \
        -CAcreateserial -out client.crt -days ${DAYS_VALID}
    
    # Cleanup
    rm client.csr
    
    success "Client certificaat gegenereerd voor ${db_type}"
}

generate_postgresql_certs() {
    info "Genereren PostgreSQL certificaten..."
    create_ca "postgresql"
    generate_server_cert "postgresql"
    generate_client_cert "postgresql"
    
    # PostgreSQL specifieke setup
    local pg_cert_path="${CERT_DIR}/postgresql"
    cp "$pg_cert_path/server.crt" "$pg_cert_path/server.crt"
    cp "$pg_cert_path/server.key" "$pg_cert_path/server.key"
    
    success "PostgreSQL certificaten gereed in ${CERT_DIR}/postgresql"
}

generate_mysql_certs() {
    info "Genereren MySQL certificaten..."
    create_ca "mysql"
    generate_server_cert "mysql"
    generate_client_cert "mysql"
    
    # MySQL specifieke setup
    local mysql_cert_path="${CERT_DIR}/mysql"
    cp "$mysql_cert_path/ca.crt" "$mysql_cert_path/ca.pem"
    cp "$mysql_cert_path/server.crt" "$mysql_cert_path/server-cert.pem"
    cp "$mysql_cert_path/server.key" "$mysql_cert_path/server-key.pem"
    cp "$mysql_cert_path/client.crt" "$mysql_cert_path/client-cert.pem"
    cp "$mysql_cert_path/client.key" "$mysql_cert_path/client-key.pem"
    
    success "MySQL certificaten gereed in ${CERT_DIR}/mysql"
}

generate_mongodb_certs() {
    info "Genereren MongoDB certificaten..."
    create_ca "mongodb"
    generate_server_cert "mongodb"
    generate_client_cert "mongodb"
    
    # MongoDB specifieke setup - PEM formaat
    local mongo_cert_path="${CERT_DIR}/mongodb"
    cat "$mongo_cert_path/server.crt" "$mongo_cert_path/server.key" > "$mongo_cert_path/mongodb.pem"
    cat "$mongo_cert_path/client.crt" "$mongo_cert_path/client.key" > "$mongo_cert_path/client.pem"
    chmod 400 "$mongo_cert_path/mongodb.pem" "$mongo_cert_path/client.pem"
    
    success "MongoDB certificaten gereed in ${CERT_DIR}/mongodb"
}

generate_redis_certs() {
    info "Genereren Redis certificaten..."
    create_ca "redis"
    generate_server_cert "redis"
    generate_client_cert "redis"
    
    # Redis specifieke setup
    local redis_cert_path="${CERT_DIR}/redis"
    cp "$redis_cert_path/server.crt" "$redis_cert_path/redis.crt"
    cp "$redis_cert_path/server.key" "$redis_cert_path/redis.key"
    
    success "Redis certificaten gereed in ${CERT_DIR}/redis"
}

show_usage() {
    cat << EOF
Gebruik: $0 [database-type]

Opties:
    postgresql   Genereer PostgreSQL certificaten
    mysql        Genereer MySQL certificaten
    mongodb      Genereer MongoDB certificaten
    redis        Genereer Redis certificaten
    all          Genereer alle database certificaten

Voorbeelden:
    $0 postgresql
    $0 all
EOF
}

main() {
    check_root
    
    local db_type="${1:-all}"
    
    case $db_type in
        postgresql)
            generate_postgresql_certs
            ;;
        mysql)
            generate_mysql_certs
            ;;
        mongodb)
            generate_mongodb_certs
            ;;
        redis)
            generate_redis_certs
            ;;
        all)
            generate_postgresql_certs
            generate_mysql_certs
            generate_mongodb_certs
            generate_redis_certs
            success "Alle database certificaten gegenereerd in ${CERT_DIR}"
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            error "Onbekende optie: $db_type. Gebruik -h voor help."
            ;;
    esac
    
    info ""
    info "BELANGRIJK: Kopieer de certificaten naar de juiste Docker volume locaties:"
    info "  - PostgreSQL: /var/lib/postgresql/data/"
    info "  - MySQL: /var/lib/mysql/"
    info "  - MongoDB: /data/configdb/"
    info "  - Redis: /data/"
    info ""
    info "Voor productie gebruik Let's Encrypt met certbot!"
}

main "$@"
