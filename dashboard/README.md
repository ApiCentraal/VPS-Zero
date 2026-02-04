# VPS-Zero Dashboard

A modern, web-based GUI for configuring and managing Ubuntu servers using VPS-Zero hardening scripts.

## 🚀 Features

- **System Overview Dashboard**: Real-time system status, CPU, memory, disk usage, and uptime
- **Server Hardening**: One-click access to all 16 hardening modules
- **Docker Management**: View and manage containers and images
- **Firewall Configuration**: Add/view UFW firewall rules
- **SSH Settings**: Configure SSH security parameters
- **Database Deployment**: Quick-deploy PostgreSQL, MySQL, MongoDB, Redis
- **SSL Certificate Generation**: Generate self-signed certificates
- **Security Tools**: Run security scans and create encrypted backups
- **Log Viewer**: View system logs from a single interface
- **Secure Authentication**: Password-protected with session management

## 📋 Requirements

- Ubuntu 24.04 LTS (or compatible version)
- Node.js 18+ (automatically installed if missing)
- Root/sudo access
- VPS-Zero repository cloned

## 🔧 Installation

### Quick Install

```bash
cd /path/to/VPS-Zero/dashboard
sudo ./install-dashboard.sh
```

### Manual Install

```bash
# Install Node.js (if not present)
curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install dependencies
cd /path/to/VPS-Zero/dashboard
npm install --production

# Start the server
sudo node src/server.js
```

### Development Mode

```bash
cd /path/to/VPS-Zero/dashboard
npm install
npm run dev
```

## 🌐 Access

After installation, access the dashboard at:

```
http://YOUR_SERVER_IP:8080
```

### Default Credentials

| Field | Value |
|-------|-------|
| Username | `admin` |
| Password | `changeme` |

⚠️ **Important**: Change the default password immediately after first login!

## 🔒 Security

### Authentication

- Session-based authentication with secure cookies
- Password hashing using bcrypt
- Rate limiting to prevent brute-force attacks
- Helmet.js for HTTP security headers

### Network Security

- Runs on localhost by default (configure bind address as needed)
- Use a reverse proxy (nginx) for HTTPS in production
- Configure firewall to restrict dashboard access

### Production Recommendations

1. **Use HTTPS**: Set up nginx as a reverse proxy with Let's Encrypt SSL
2. **Restrict Access**: Limit dashboard access to trusted IPs
3. **Change Port**: Use a non-standard port
4. **VPN**: Consider placing dashboard behind a VPN

Example nginx configuration:

```nginx
server {
    listen 443 ssl http2;
    server_name dashboard.example.com;

    ssl_certificate /etc/letsencrypt/live/dashboard.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/dashboard.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
    }
}
```

## ⚙️ Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DASHBOARD_PORT` | `8080` | Port to run dashboard on |
| `DASHBOARD_HOST` | `0.0.0.0` | Host to bind to |
| `NODE_ENV` | `development` | Set to `production` for secure cookies |

### Config File

The dashboard stores configuration in `dashboard/config.json`:

```json
{
  "username": "admin",
  "passwordHash": "...",
  "sessionSecret": "...",
  "firstRun": false
}
```

## 📁 Directory Structure

```
dashboard/
├── package.json          # Node.js dependencies
├── install-dashboard.sh  # Installation script
├── README.md            # This file
├── src/
│   └── server.js        # Express server
├── views/
│   ├── login.html       # Login page
│   └── dashboard.html   # Main dashboard
└── public/
    ├── css/
    │   └── dashboard.css
    └── js/
        └── dashboard.js
```

## 🔌 API Endpoints

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/login` | Login |
| POST | `/api/logout` | Logout |
| POST | `/api/change-password` | Change password |

### System

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/status` | System status |
| GET | `/api/services` | Service status |
| GET | `/api/validate` | Validate configs |

### Hardening

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/hardening/:module` | Run hardening module |

Available modules: `updates`, `docker`, `firewall`, `ssh`, `fail2ban`, `kernel`, `auditd`, `autoupdates`, `swap`, `filesystem`, `logging`, `users`, `time`, `sectools`, `dockersec`, `full`

### Docker

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/docker/containers` | List containers |
| GET | `/api/docker/images` | List images |

### Firewall

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/firewall/rules` | Get firewall rules |
| POST | `/api/firewall/rule` | Add firewall rule |

### SSH

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/ssh/config` | Get SSH config |
| POST | `/api/ssh/config` | Update SSH config |

### SSL

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/ssl/generate` | Generate certificates |

### Security

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/security/scan` | Run security scan |
| POST | `/api/backup/create` | Create backup |

### Logs

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/api/logs/:type` | Get logs |

Log types: `hardening`, `docker`, `auth`, `ufw`, `syslog`

## 🛠️ Service Management

```bash
# Check status
sudo systemctl status vps-zero-dashboard

# Restart
sudo systemctl restart vps-zero-dashboard

# Stop
sudo systemctl stop vps-zero-dashboard

# View logs
sudo journalctl -u vps-zero-dashboard -f
```

## 🐛 Troubleshooting

### Dashboard won't start

1. Check if port is in use: `sudo lsof -i :8080`
2. Check logs: `sudo journalctl -u vps-zero-dashboard -n 50`
3. Verify Node.js: `node --version`
4. Check permissions: files should be readable

### Can't access dashboard

1. Check firewall: `sudo ufw status`
2. Verify service is running: `sudo systemctl status vps-zero-dashboard`
3. Check if listening: `sudo netstat -tlnp | grep 8080`

### Authentication issues

1. Delete `config.json` to reset to defaults
2. Restart service: `sudo systemctl restart vps-zero-dashboard`
3. Use default credentials: `admin` / `changeme`

## 📄 License

MIT License - See [LICENSE](../LICENSE) for details.

## 🤝 Contributing

Contributions welcome! Please submit issues and pull requests on GitHub.
