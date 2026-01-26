#!/bin/bash
################################################################################
# Security Scanning & Hardening Script
# Voor Container en Host Security
#
# Features:
# - Container vulnerability scanning met Trivy
# - CIS Docker Benchmark met docker-bench-security
# - System hardening checks
# - Secrets scanning
#
# Gebruik: sudo ./security-scan.sh
################################################################################

set -euo pipefail

# Kleuren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuratie
REPORT_DIR="/var/log/security-scans"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

success() {
    echo -e "${GREEN}[SUCCESS]${NC} $@"
}

warning() {
    echo -e "${YELLOW}[WARNING]${NC} $@"
}

error() {
    echo -e "${RED}[ERROR]${NC} $@"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "Dit script moet als root uitgevoerd worden"
        exit 1
    fi
}

setup_report_dir() {
    mkdir -p "$REPORT_DIR"
    info "Security scan reports: $REPORT_DIR"
}

install_trivy() {
    if ! command -v trivy &> /dev/null; then
        info "Installeren Trivy..."
        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | apt-key add -
        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | tee /etc/apt/sources.list.d/trivy.list
        apt-get update
        apt-get install -y trivy
        success "Trivy geïnstalleerd"
    fi
}

install_docker_bench() {
    if [[ ! -d "/opt/docker-bench-security" ]]; then
        info "Installeren Docker Bench Security..."
        git clone https://github.com/docker/docker-bench-security.git /opt/docker-bench-security
        success "Docker Bench Security geïnstalleerd"
    fi
}

scan_docker_images() {
    info "Scannen Docker images op vulnerabilities..."
    
    local report_file="${REPORT_DIR}/trivy-scan-${TIMESTAMP}.txt"
    
    # Scan all local images
    for image in $(docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>"); do
        info "Scanning: $image"
        trivy image --severity HIGH,CRITICAL "$image" >> "$report_file" 2>&1 || true
    done
    
    success "Trivy scan voltooid: $report_file"
}

run_docker_bench() {
    info "Uitvoeren CIS Docker Benchmark..."
    
    cd /opt/docker-bench-security
    local report_file="${REPORT_DIR}/docker-bench-${TIMESTAMP}.log"
    
    ./docker-bench-security.sh | tee "$report_file"
    
    success "Docker Bench voltooid: $report_file"
}

scan_secrets() {
    info "Scannen op secrets in Docker containers..."
    
    local report_file="${REPORT_DIR}/secrets-scan-${TIMESTAMP}.txt"
    
    echo "=== Secrets Scan Report ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check for exposed secrets in environment variables
    for container in $(docker ps --format "{{.Names}}"); do
        echo "=== Container: $container ===" >> "$report_file"
        
        # Check environment variables for potential secrets
        docker inspect "$container" | jq -r '.[].Config.Env[]' | \
            grep -iE '(password|secret|key|token|api)' | \
            grep -v '_FILE' | \
            sed 's/=.*/=***REDACTED***/g' >> "$report_file" 2>/dev/null || true
        
        echo "" >> "$report_file"
    done
    
    warning "Controleer secrets scan: $report_file"
}

check_host_security() {
    info "Controleren host security instellingen..."
    
    local report_file="${REPORT_DIR}/host-security-${TIMESTAMP}.txt"
    
    echo "=== Host Security Check ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check firewall status
    echo "=== Firewall Status ===" >> "$report_file"
    ufw status verbose >> "$report_file" 2>&1 || echo "UFW not installed" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check fail2ban status
    echo "=== Fail2Ban Status ===" >> "$report_file"
    systemctl status fail2ban --no-pager >> "$report_file" 2>&1 || echo "Fail2Ban not running" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check SSH configuration
    echo "=== SSH Configuration ===" >> "$report_file"
    grep -E "PermitRootLogin|PasswordAuthentication|Port" /etc/ssh/sshd_config >> "$report_file" 2>&1
    echo "" >> "$report_file"
    
    # Check Docker daemon configuration
    echo "=== Docker Daemon Configuration ===" >> "$report_file"
    if [[ -f "/etc/docker/daemon.json" ]]; then
        cat /etc/docker/daemon.json >> "$report_file"
    else
        echo "No daemon.json found" >> "$report_file"
    fi
    echo "" >> "$report_file"
    
    # Check for updates
    echo "=== System Updates ===" >> "$report_file"
    apt list --upgradable 2>/dev/null | head -20 >> "$report_file"
    
    success "Host security check voltooid: $report_file"
}

check_database_security() {
    info "Controleren database security..."
    
    local report_file="${REPORT_DIR}/database-security-${TIMESTAMP}.txt"
    
    echo "=== Database Security Check ===" > "$report_file"
    echo "Timestamp: $(date)" >> "$report_file"
    echo "" >> "$report_file"
    
    # Check PostgreSQL if running
    if docker ps | grep -q postgres; then
        echo "=== PostgreSQL Security ===" >> "$report_file"
        docker exec $(docker ps | grep postgres | awk '{print $1}') \
            psql -U postgres -c "SHOW ssl;" >> "$report_file" 2>&1 || true
        docker exec $(docker ps | grep postgres | awk '{print $1}') \
            psql -U postgres -c "SELECT name, setting FROM pg_settings WHERE name LIKE '%password_encryption%';" >> "$report_file" 2>&1 || true
        echo "" >> "$report_file"
    fi
    
    # Check MySQL if running
    if docker ps | grep -q mysql; then
        echo "=== MySQL Security ===" >> "$report_file"
        docker exec $(docker ps | grep mysql | awk '{print $1}') \
            mysql -u root -e "SHOW VARIABLES LIKE '%ssl%';" >> "$report_file" 2>&1 || true
        echo "" >> "$report_file"
    fi
    
    # Check MongoDB if running
    if docker ps | grep -q mongo; then
        echo "=== MongoDB Security ===" >> "$report_file"
        docker exec $(docker ps | grep mongo | awk '{print $1}') \
            mongosh --eval "db.adminCommand({getCmdLineOpts: 1})" >> "$report_file" 2>&1 || true
        echo "" >> "$report_file"
    fi
    
    success "Database security check voltooid: $report_file"
}

generate_summary() {
    info "Genereren security summary..."
    
    local summary_file="${REPORT_DIR}/summary-${TIMESTAMP}.txt"
    
    cat > "$summary_file" << EOF
=== VPS-Zero Security Scan Summary ===
Scan uitgevoerd: $(date)

Rapporten gegenereerd:
- Trivy Vulnerability Scan: ${REPORT_DIR}/trivy-scan-${TIMESTAMP}.txt
- Docker Bench Security: ${REPORT_DIR}/docker-bench-${TIMESTAMP}.log
- Secrets Scan: ${REPORT_DIR}/secrets-scan-${TIMESTAMP}.txt
- Host Security Check: ${REPORT_DIR}/host-security-${TIMESTAMP}.txt
- Database Security: ${REPORT_DIR}/database-security-${TIMESTAMP}.txt

Aanbevolen acties:
1. Bekijk alle rapporten voor HIGH en CRITICAL issues
2. Update vulnerable Docker images
3. Implement Docker Bench aanbevelingen
4. Verwijder exposed secrets uit environment variables
5. Update systeem packages
6. Roteer database credentials indien nodig

Next scan: Voer elke 7 dagen uit of na elke deployment

Voor ondersteuning: https://github.com/ApiCentraal/VPS-Zero/issues
EOF
    
    cat "$summary_file"
    success "Summary gegenereerd: $summary_file"
}

show_usage() {
    cat << EOF
Gebruik: $0 [optie]

Opties:
    --full          Volledige security scan (all checks)
    --images        Scan alleen Docker images
    --bench         Alleen Docker Bench Security
    --secrets       Alleen secrets scanning
    --host          Alleen host security check
    --database      Alleen database security check
    -h, --help      Deze help tekst

Voorbeelden:
    $0 --full
    $0 --images
    $0 --host --database
EOF
}

main() {
    check_root
    setup_report_dir
    
    local scan_type="${1:-full}"
    
    case $scan_type in
        --full)
            install_trivy
            install_docker_bench
            scan_docker_images
            run_docker_bench
            scan_secrets
            check_host_security
            check_database_security
            generate_summary
            ;;
        --images)
            install_trivy
            scan_docker_images
            ;;
        --bench)
            install_docker_bench
            run_docker_bench
            ;;
        --secrets)
            scan_secrets
            ;;
        --host)
            check_host_security
            ;;
        --database)
            check_database_security
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            install_trivy
            install_docker_bench
            scan_docker_images
            run_docker_bench
            scan_secrets
            check_host_security
            check_database_security
            generate_summary
            ;;
    esac
    
    success "Security scan voltooid!"
}

main "$@"
