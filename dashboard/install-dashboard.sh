#!/bin/bash
################################################################################
# VPS-Zero Dashboard Installation Script
# Installs and configures the web-based dashboard
#
# Usage: sudo ./install-dashboard.sh
################################################################################

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Check root
if [[ $EUID -ne 0 ]]; then
    error "This script must be run as root (sudo ./install-dashboard.sh)"
    exit 1
fi

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   VPS-Zero Dashboard Installer                               ║"
echo "║   Enterprise Ubuntu Server Configuration GUI                 ║"
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="$SCRIPT_DIR"

# Configuration
DASHBOARD_PORT="${DASHBOARD_PORT:-8080}"
DASHBOARD_USER="${DASHBOARD_USER:-vps-zero}"
SERVICE_NAME="vps-zero-dashboard"
NODE_MIN_VERSION="18"

# Check for Node.js
info "Checking for Node.js..."

if command -v node &> /dev/null; then
    NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
    if [[ "$NODE_VERSION" -ge "$NODE_MIN_VERSION" ]]; then
        success "Node.js v$(node -v | cut -d'v' -f2) is installed"
    else
        warning "Node.js version is too old. Need v${NODE_MIN_VERSION}+. Installing..."
        INSTALL_NODE=true
    fi
else
    info "Node.js not found. Installing..."
    INSTALL_NODE=true
fi

# Install Node.js if needed
if [[ "${INSTALL_NODE:-false}" == "true" ]]; then
    info "Installing Node.js LTS..."
    
    # Install NodeSource repository
    curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
    apt-get install -y nodejs
    
    success "Node.js $(node -v) installed"
fi

# Create system user if doesn't exist
info "Setting up system user..."
if ! id "$DASHBOARD_USER" &> /dev/null; then
    useradd --system --no-create-home --shell /usr/sbin/nologin "$DASHBOARD_USER"
    success "Created system user: $DASHBOARD_USER"
else
    info "User $DASHBOARD_USER already exists"
fi

# Install npm dependencies
info "Installing npm dependencies..."
cd "$DASHBOARD_DIR"
npm install --production

# Set permissions
info "Setting permissions..."
chown -R "$DASHBOARD_USER:$DASHBOARD_USER" "$DASHBOARD_DIR"
chmod 750 "$DASHBOARD_DIR"

# Create systemd service
info "Creating systemd service..."

cat > "/etc/systemd/system/${SERVICE_NAME}.service" << EOF
[Unit]
Description=VPS-Zero Dashboard
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=$DASHBOARD_DIR
ExecStart=/usr/bin/node $DASHBOARD_DIR/src/server.js
Restart=on-failure
RestartSec=10
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=${SERVICE_NAME}
Environment=NODE_ENV=production
Environment=DASHBOARD_PORT=$DASHBOARD_PORT

# Security
NoNewPrivileges=false

[Install]
WantedBy=multi-user.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable and start service
info "Enabling and starting dashboard service..."
systemctl enable "$SERVICE_NAME"
systemctl restart "$SERVICE_NAME"

# Wait for service to start
sleep 2

# Check if service is running
if systemctl is-active --quiet "$SERVICE_NAME"; then
    success "Dashboard service is running"
else
    error "Dashboard service failed to start"
    journalctl -u "$SERVICE_NAME" --no-pager -n 20
    exit 1
fi

# Configure firewall if UFW is active
if command -v ufw &> /dev/null && ufw status | grep -q "Status: active"; then
    info "Configuring firewall..."
    ufw allow "$DASHBOARD_PORT/tcp" comment "VPS-Zero Dashboard"
    success "Firewall rule added for port $DASHBOARD_PORT"
fi

# Create symlink for vps-zero-dashboard command
info "Creating vps-zero-dashboard command..."
if [[ -f "${DASHBOARD_DIR}/vps-zero-dashboard" ]]; then
    chmod +x "${DASHBOARD_DIR}/vps-zero-dashboard"
    ln -sf "${DASHBOARD_DIR}/vps-zero-dashboard" /usr/local/bin/vps-zero-dashboard
    success "Command 'vps-zero-dashboard' is now available system-wide"
fi

# Get server IP
SERVER_IP=$(hostname -I | awk '{print $1}')

echo ""
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║                                                              ║"
echo "║   ✅ Installation Complete!                                  ║"
echo "║                                                              ║"
echo "║   Dashboard URL: http://${SERVER_IP}:${DASHBOARD_PORT}       "
echo "║                                                              ║"
echo "║   Default Credentials:                                       ║"
echo "║   Username: admin                                            ║"
echo "║   Password: changeme                                         ║"
echo "║                                                              ║"
echo "║   ⚠️  IMPORTANT: Change the default password immediately!    ║"
echo "║                                                              ║"
echo "║   Dashboard Commands:                                        ║"
echo "║   vps-zero-dashboard --start   Start dashboard               ║"
echo "║   vps-zero-dashboard --stop    Stop dashboard                ║"
echo "║   vps-zero-dashboard --status  Show status                   ║"
echo "║                                                              ║"
echo "║   Service Management:                                        ║"
echo "║   sudo systemctl status ${SERVICE_NAME}                      "
echo "║   sudo systemctl restart ${SERVICE_NAME}                     "
echo "║   sudo journalctl -u ${SERVICE_NAME} -f                      "
echo "║                                                              ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

success "VPS-Zero Dashboard installed successfully!"
