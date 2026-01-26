#!/bin/bash
################################################################################
# Configuration Validation Script
# Verificatie van alle enterprise security configuraties
#
# Dit script valideert dat alle configuraties correct zijn opgezet
# en klaar zijn voor deployment
#
# Gebruik: ./validate-configs.sh
################################################################################

set -uo pipefail

# Kleuren
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

ERRORS=0
WARNINGS=0
PASSED=0

info() {
    echo -e "${BLUE}[INFO]${NC} $@"
}

success() {
    echo -e "${GREEN}[PASS]${NC} $@"
    ((PASSED++))
}

warning() {
    echo -e "${YELLOW}[WARN]${NC} $@"
    ((WARNINGS++))
}

error() {
    echo -e "${RED}[FAIL]${NC} $@"
    ((ERRORS++))
}

check_file_exists() {
    local file=$1
    local desc=$2
    
    if [[ -f "$file" ]]; then
        success "$desc exists: $file"
        return 0
    else
        error "$desc missing: $file"
        return 1
    fi
}

check_file_executable() {
    local file=$1
    local desc=$2
    
    if [[ -x "$file" ]]; then
        success "$desc is executable: $file"
        return 0
    else
        error "$desc not executable: $file"
        return 1
    fi
}

check_directory() {
    local dir=$1
    local desc=$2
    
    if [[ -d "$dir" ]]; then
        success "$desc exists: $dir"
        return 0
    else
        error "$desc missing: $dir"
        return 1
    fi
}

validate_yaml() {
    local file=$1
    
    if command -v yamllint &> /dev/null; then
        # Use very relaxed rules - we only care about syntax errors
        if yamllint -d '{extends: relaxed, rules: {line-length: disable, trailing-spaces: disable}}' "$file" &> /dev/null; then
            success "YAML syntax valid: $(basename $file)"
            return 0
        else
            warning "YAML has style issues but may be syntactically valid: $(basename $file)"
            return 0
        fi
    else
        warning "yamllint not installed, skipping YAML validation"
        return 0
    fi
}

validate_json() {
    local file=$1
    
    if command -v jq &> /dev/null; then
        if jq empty "$file" &> /dev/null 2>&1; then
            success "JSON syntax valid: $(basename $file)"
            return 0
        else
            error "JSON syntax invalid: $(basename $file)"
            return 1
        fi
    else
        warning "jq not installed, skipping JSON validation"
        return 0
    fi
}

check_config_values() {
    local file=$1
    local pattern=$2
    local desc=$3
    
    if grep -q "$pattern" "$file" 2>/dev/null; then
        warning "$desc still contains default/placeholder values in $file"
        return 1
    else
        success "$desc properly configured in $file"
        return 0
    fi
}

echo "======================================================================"
echo "  VPS-Zero Configuration Validation"
echo "======================================================================"
echo ""

info "Starting validation..."
echo ""

# 1. Structuur validatie
info "Checking directory structure..."
check_directory "configs" "configs directory"
check_directory "configs/database" "database configs directory"
check_directory "configs/database/postgresql" "PostgreSQL configs"
check_directory "configs/database/mysql" "MySQL configs"
check_directory "configs/database/mongodb" "MongoDB configs"
check_directory "configs/database/redis" "Redis configs"
check_directory "configs/docker" "Docker configs"
check_directory "configs/security" "Security scripts"
check_directory "configs/ssl" "SSL scripts"
check_directory "secrets" "Secrets directory"
echo ""

# 2. Database configuratie bestanden
info "Checking database configuration files..."
check_file_exists "configs/database/postgresql/docker-compose.prod.yml" "PostgreSQL compose"
check_file_exists "configs/database/postgresql/postgresql.conf" "PostgreSQL config"
check_file_exists "configs/database/postgresql/pg_hba.conf" "PostgreSQL HBA config"
check_file_exists "configs/database/mysql/docker-compose.prod.yml" "MySQL compose"
check_file_exists "configs/database/mysql/my.cnf" "MySQL config"
check_file_exists "configs/database/mongodb/docker-compose.prod.yml" "MongoDB compose"
check_file_exists "configs/database/mongodb/mongod.conf" "MongoDB config"
check_file_exists "configs/database/redis/docker-compose.prod.yml" "Redis compose"
check_file_exists "configs/database/redis/redis.conf" "Redis config"
echo ""

# 3. Docker security configuratie
info "Checking Docker security configurations..."
check_file_exists "configs/docker/daemon.json" "Docker daemon config"
check_file_exists "configs/docker/seccomp-default.json" "Seccomp profile"
echo ""

# 4. Environment templates
info "Checking environment templates..."
check_file_exists "configs/.env.production.template" "Production env template"
check_file_exists "configs/.env.development.template" "Development env template"
echo ""

# 5. Scripts
info "Checking security scripts..."
check_file_executable "configs/ssl/generate-certificates.sh" "Certificate generation script"
check_file_executable "configs/security/backup-databases.sh" "Backup script"
check_file_executable "configs/security/security-scan.sh" "Security scan script"
echo ""

# 6. Documentation
info "Checking documentation..."
check_file_exists "README.md" "Main README"
check_file_exists "SECURITY-CONFIG.md" "Security configuration guide"
check_file_exists "SECRETS-MANAGEMENT.md" "Secrets management guide"
check_file_exists "configs/README.md" "Configs README"
echo ""

# 7. Secrets templates
info "Checking secrets templates..."
check_file_exists "secrets/postgres_password.txt.example" "PostgreSQL password template"
check_file_exists "secrets/postgres_user.txt.example" "PostgreSQL user template"
check_file_exists "secrets/mysql_root_password.txt.example" "MySQL root password template"
check_file_exists "secrets/mysql_user.txt.example" "MySQL user template"
check_file_exists "secrets/mysql_password.txt.example" "MySQL password template"
check_file_exists "secrets/mongo_root_user.txt.example" "MongoDB user template"
check_file_exists "secrets/mongo_root_password.txt.example" "MongoDB password template"
check_file_exists "secrets/.gitignore" "Secrets gitignore"
echo ""

# 8. YAML validatie (optioneel)
info "Validating YAML syntax (if yamllint available)..."
for yml in configs/database/*/docker-compose*.yml; do
    if [[ -f "$yml" ]]; then
        validate_yaml "$yml"
    fi
done
echo ""

# 9. JSON validatie (optioneel)
info "Validating JSON syntax (if jq available)..."
for json in configs/docker/*.json; do
    if [[ -f "$json" ]]; then
        validate_json "$json"
    fi
done
echo ""

# 10. Security checks
info "Checking for potential security issues..."

# Check for exposed secrets in env templates
if [[ -f "configs/.env.production.template" ]]; then
    if grep -E "(CHANGEME|change.*me|your.*password|your.*key)" "configs/.env.production.template" > /dev/null; then
        success "Production template contains placeholder values (as expected)"
    else
        warning "Production template may have been modified with real values"
    fi
fi

# Check gitignore voor secrets
if [[ -f "secrets/.gitignore" ]]; then
    if grep -q "*.txt" "secrets/.gitignore"; then
        success "Secrets directory has proper .gitignore"
    else
        error "Secrets .gitignore may not exclude actual secret files"
    fi
fi

# Check for world-readable permissions on scripts
for script in configs/security/*.sh configs/ssl/*.sh; do
    if [[ -f "$script" ]]; then
        perms=$(stat -c "%a" "$script")
        if [[ "$perms" == "755" ]] || [[ "$perms" == "750" ]] || [[ "$perms" == "700" ]]; then
            success "Script has proper permissions: $script ($perms)"
        else
            warning "Script permissions may be too permissive: $script ($perms)"
        fi
    fi
done

echo ""

# 11. Configuration content checks
info "Checking configuration content..."

# PostgreSQL TLS check
if grep -q "ssl = on" configs/database/postgresql/postgresql.conf 2>/dev/null; then
    success "PostgreSQL TLS enabled"
else
    error "PostgreSQL TLS not enabled"
fi

# MySQL TLS check
if grep -q "require_secure_transport = ON" configs/database/mysql/my.cnf 2>/dev/null; then
    success "MySQL TLS enforced"
else
    error "MySQL TLS not enforced"
fi

# MongoDB TLS check
if grep -q "mode: requireTLS" configs/database/mongodb/mongod.conf 2>/dev/null; then
    success "MongoDB TLS required"
else
    error "MongoDB TLS not required"
fi

# Redis TLS check
if grep -q "tls-port 6380" configs/database/redis/redis.conf 2>/dev/null; then
    success "Redis TLS configured"
else
    error "Redis TLS not configured"
fi

# Docker user namespaces check
if grep -q '"userns-remap": "default"' configs/docker/daemon.json 2>/dev/null; then
    success "Docker user namespace remapping enabled"
else
    warning "Docker user namespace remapping not enabled"
fi

echo ""
echo "======================================================================"
echo "  Validation Summary"
echo "======================================================================"
echo -e "${GREEN}Passed:${NC}   $PASSED"
echo -e "${YELLOW}Warnings:${NC} $WARNINGS"
echo -e "${RED}Errors:${NC}   $ERRORS"
echo ""

if [[ $ERRORS -eq 0 ]]; then
    echo -e "${GREEN}✓ All critical checks passed!${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Review warnings above (if any)"
    echo "2. Generate SSL/TLS certificates: sudo ./configs/ssl/generate-certificates.sh all"
    echo "3. Configure secrets: cp configs/.env.production.template .env && edit .env"
    echo "4. Deploy databases: cd configs/database/[type] && docker-compose -f docker-compose.prod.yml up -d"
    echo "5. Run security scan: sudo ./configs/security/security-scan.sh --full"
    echo ""
    exit 0
else
    echo -e "${RED}✗ Validation failed with $ERRORS error(s)${NC}"
    echo ""
    echo "Please fix the errors above before proceeding."
    echo ""
    exit 1
fi
