/**
 * VPS-Zero Dashboard Server
 * Enterprise Ubuntu Server Configuration GUI
 */

const express = require('express');
const session = require('express-session');
const helmet = require('helmet');
const rateLimit = require('express-rate-limit');
const bcrypt = require('bcryptjs');
const path = require('path');
const { exec, spawn } = require('child_process');
const fs = require('fs');
const os = require('os');
const crypto = require('crypto');

const app = express();
const PORT = process.env.DASHBOARD_PORT || 8080;
const HOST = process.env.DASHBOARD_HOST || '0.0.0.0';

// Configuration
const CONFIG_FILE = path.join(__dirname, '../config.json');
const HARDENING_SCRIPT = path.resolve(__dirname, '../../server-hardening.sh');
const CONFIGS_DIR = path.resolve(__dirname, '../../configs');

// Default admin credentials (should be changed on first login)
const DEFAULT_USERNAME = 'admin';
const DEFAULT_PASSWORD_HASH = bcrypt.hashSync('changeme', 10);

// Load or create config
function loadConfig() {
    try {
        if (fs.existsSync(CONFIG_FILE)) {
            return JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8'));
        }
    } catch (err) {
        console.error('Error loading config:', err);
    }
    return {
        username: DEFAULT_USERNAME,
        passwordHash: DEFAULT_PASSWORD_HASH,
        sessionSecret: crypto.randomBytes(64).toString('hex'),
        firstRun: true
    };
}

function saveConfig(config) {
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(config, null, 2));
}

const config = loadConfig();
if (!fs.existsSync(CONFIG_FILE)) {
    saveConfig(config);
}

// Security middleware
app.use(helmet({
    contentSecurityPolicy: {
        directives: {
            defaultSrc: ["'self'"],
            styleSrc: ["'self'", "'unsafe-inline'", "https://fonts.googleapis.com", "https://cdnjs.cloudflare.com"],
            fontSrc: ["'self'", "https://fonts.gstatic.com", "https://cdnjs.cloudflare.com"],
            scriptSrc: ["'self'", "'unsafe-inline'"],
            imgSrc: ["'self'", "data:"],
        },
    },
}));

// Rate limiting
const limiter = rateLimit({
    windowMs: 15 * 60 * 1000,
    max: 100,
    message: 'Too many requests, please try again later.'
});
app.use(limiter);

// Session configuration
app.use(session({
    secret: config.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: {
        secure: process.env.NODE_ENV === 'production',
        httpOnly: true,
        maxAge: 3600000, // 1 hour
        sameSite: 'strict' // CSRF protection via SameSite cookie
    }
}));

// Body parsing
app.use(express.json());

// CSRF protection middleware for state-changing requests
function csrfProtection(req, res, next) {
    // Skip CSRF for login (no session yet)
    if (req.path === '/api/login') {
        return next();
    }
    
    // For authenticated routes, verify origin/referer header
    const origin = req.get('origin') || req.get('referer');
    if (origin) {
        const allowedOrigins = [
            `http://localhost:${PORT}`,
            `http://127.0.0.1:${PORT}`,
            `http://${HOST}:${PORT}`
        ];
        const originUrl = new URL(origin);
        const originBase = `${originUrl.protocol}//${originUrl.host}`;
        
        if (!allowedOrigins.some(allowed => originBase.startsWith(allowed.split(':').slice(0, 2).join(':')))) {
            return res.status(403).json({ error: 'CSRF validation failed' });
        }
    }
    
    next();
}

// Apply CSRF protection to all POST/PUT/DELETE requests
app.use((req, res, next) => {
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(req.method)) {
        return csrfProtection(req, res, next);
    }
    next();
});
app.use(express.urlencoded({ extended: true }));

// Static files
app.use(express.static(path.join(__dirname, '../public')));

// Auth middleware
function requireAuth(req, res, next) {
    if (req.session && req.session.authenticated) {
        return next();
    }
    if (req.xhr || req.headers.accept?.includes('application/json')) {
        return res.status(401).json({ error: 'Unauthorized' });
    }
    res.redirect('/login');
}

// Routes

// Login page
app.get('/login', (req, res) => {
    if (req.session?.authenticated) {
        return res.redirect('/');
    }
    res.sendFile(path.join(__dirname, '../views/login.html'));
});

// Login handler
app.post('/api/login', async (req, res) => {
    const { username, password } = req.body;
    const currentConfig = loadConfig();
    
    if (username === currentConfig.username && 
        bcrypt.compareSync(password, currentConfig.passwordHash)) {
        req.session.authenticated = true;
        req.session.username = username;
        res.json({ success: true, firstRun: currentConfig.firstRun });
    } else {
        res.status(401).json({ error: 'Invalid credentials' });
    }
});

// Logout
app.post('/api/logout', (req, res) => {
    req.session.destroy();
    res.json({ success: true });
});

// Change password
app.post('/api/change-password', requireAuth, (req, res) => {
    const { currentPassword, newPassword } = req.body;
    const currentConfig = loadConfig();
    
    if (!bcrypt.compareSync(currentPassword, currentConfig.passwordHash)) {
        return res.status(400).json({ error: 'Current password is incorrect' });
    }
    
    if (newPassword.length < 8) {
        return res.status(400).json({ error: 'Password must be at least 8 characters' });
    }
    
    currentConfig.passwordHash = bcrypt.hashSync(newPassword, 10);
    currentConfig.firstRun = false;
    saveConfig(currentConfig);
    
    res.json({ success: true });
});

// Dashboard
app.get('/', requireAuth, (req, res) => {
    res.sendFile(path.join(__dirname, '../views/dashboard.html'));
});

// System status API
app.get('/api/status', requireAuth, async (req, res) => {
    try {
        const status = await getSystemStatus();
        res.json(status);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Service status
app.get('/api/services', requireAuth, async (req, res) => {
    try {
        const services = await getServicesStatus();
        res.json(services);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Execute hardening module
app.post('/api/hardening/:module', requireAuth, async (req, res) => {
    const { module } = req.params;
    const validModules = [
        'updates', 'docker', 'firewall', 'ssh', 'fail2ban',
        'kernel', 'auditd', 'autoupdates', 'swap', 'filesystem',
        'logging', 'users', 'time', 'sectools', 'dockersec', 'full'
    ];
    
    if (!validModules.includes(module)) {
        return res.status(400).json({ error: 'Invalid module' });
    }
    
    try {
        const result = await executeHardeningModule(module);
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message, output: err.output });
    }
});

// UFW rules
app.get('/api/firewall/rules', requireAuth, async (req, res) => {
    try {
        const rules = await getFirewallRules();
        res.json(rules);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/firewall/rule', requireAuth, async (req, res) => {
    const { action, port, protocol, from } = req.body;
    
    if (!['allow', 'deny'].includes(action)) {
        return res.status(400).json({ error: 'Invalid action' });
    }
    
    try {
        const result = await addFirewallRule(action, port, protocol, from);
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Docker containers
app.get('/api/docker/containers', requireAuth, async (req, res) => {
    try {
        const containers = await getDockerContainers();
        res.json(containers);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.get('/api/docker/images', requireAuth, async (req, res) => {
    try {
        const images = await getDockerImages();
        res.json(images);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// SSL certificate generation
app.post('/api/ssl/generate', requireAuth, async (req, res) => {
    const { type } = req.body;
    const validTypes = ['all', 'postgresql', 'mysql', 'mongodb', 'redis'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid certificate type' });
    }
    
    try {
        const result = await generateCertificates(type);
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Security scan
app.post('/api/security/scan', requireAuth, async (req, res) => {
    try {
        const result = await runSecurityScan();
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message, output: err.output });
    }
});

// Backup
app.post('/api/backup/create', requireAuth, async (req, res) => {
    const { type } = req.body;
    const validTypes = ['all', 'postgresql', 'mysql', 'mongodb', 'redis', 'configs'];
    
    if (!validTypes.includes(type)) {
        return res.status(400).json({ error: 'Invalid backup type' });
    }
    
    try {
        const result = await createBackup(type);
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Logs
app.get('/api/logs/:type', requireAuth, async (req, res) => {
    const { type } = req.params;
    const lines = parseInt(req.query.lines) || 100;
    
    try {
        const logs = await getLogs(type, lines);
        res.json({ logs });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Config validation
app.get('/api/validate', requireAuth, async (req, res) => {
    try {
        const result = await validateConfigs();
        res.json(result);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// SSH configuration
app.get('/api/ssh/config', requireAuth, async (req, res) => {
    try {
        const sshConfig = await getSSHConfig();
        res.json(sshConfig);
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

app.post('/api/ssh/config', requireAuth, async (req, res) => {
    const { port, permitRootLogin, passwordAuth, maxAuthTries } = req.body;
    
    try {
        const result = await updateSSHConfig({ port, permitRootLogin, passwordAuth, maxAuthTries });
        res.json({ success: true, output: result });
    } catch (err) {
        res.status(500).json({ error: err.message });
    }
});

// Helper functions

async function getSystemStatus() {
    return new Promise((resolve, reject) => {
        const status = {
            hostname: os.hostname(),
            platform: os.platform(),
            release: os.release(),
            uptime: os.uptime(),
            loadAverage: os.loadavg(),
            totalMemory: os.totalmem(),
            freeMemory: os.freemem(),
            cpus: os.cpus().length,
            networkInterfaces: os.networkInterfaces()
        };
        
        exec('lsb_release -ds 2>/dev/null || cat /etc/os-release | grep PRETTY_NAME | cut -d\'"\'  -f2', (err, stdout) => {
            status.osVersion = stdout?.trim() || 'Unknown';
            
            exec('df -h / | awk \'NR==2 {print $2","$3","$4","$5}\'', (err, stdout) => {
                if (stdout) {
                    const [total, used, available, percent] = stdout.trim().split(',');
                    status.disk = { total, used, available, percent };
                }
                resolve(status);
            });
        });
    });
}

async function getServicesStatus() {
    const services = ['docker', 'ufw', 'fail2ban', 'sshd', 'auditd'];
    const results = {};
    
    for (const service of services) {
        results[service] = await checkServiceStatus(service);
    }
    
    return results;
}

function checkServiceStatus(service) {
    return new Promise((resolve) => {
        exec(`systemctl is-active ${service} 2>/dev/null`, (err, stdout) => {
            resolve({
                active: stdout?.trim() === 'active',
                status: stdout?.trim() || 'unknown'
            });
        });
    });
}

function executeHardeningModule(module) {
    return new Promise((resolve, reject) => {
        const moduleMap = {
            'updates': '2',
            'docker': '3',
            'firewall': '4',
            'ssh': '5',
            'fail2ban': '6',
            'kernel': '7',
            'auditd': '8',
            'autoupdates': '9',
            'swap': '10',
            'filesystem': '11',
            'logging': '12',
            'users': '13',
            'time': '14',
            'sectools': '15',
            'dockersec': '16',
            'full': '1'
        };
        
        const option = moduleMap[module];
        if (!option) {
            return reject(new Error('Invalid module'));
        }
        
        // For the full installation, use --full flag
        const args = module === 'full' ? ['--full'] : [];
        const cmd = `echo "${option}" | sudo ${HARDENING_SCRIPT} ${args.join(' ')}`;
        
        exec(cmd, { timeout: 600000, maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
            if (err) {
                const error = new Error(err.message);
                error.output = stdout + '\n' + stderr;
                return reject(error);
            }
            resolve(stdout);
        });
    });
}

function getFirewallRules() {
    return new Promise((resolve, reject) => {
        exec('sudo ufw status numbered 2>/dev/null', (err, stdout) => {
            if (err) return reject(err);
            resolve({ output: stdout, active: stdout.includes('Status: active') });
        });
    });
}

function addFirewallRule(action, port, protocol = 'tcp', from = 'any') {
    return new Promise((resolve, reject) => {
        const portNum = parseInt(port);
        if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
            return reject(new Error('Invalid port number'));
        }
        
        const cmd = from === 'any' 
            ? `sudo ufw ${action} ${port}/${protocol}`
            : `sudo ufw ${action} from ${from} to any port ${port} proto ${protocol}`;
        
        exec(cmd, (err, stdout, stderr) => {
            if (err) return reject(err);
            resolve(stdout || stderr);
        });
    });
}

function getDockerContainers() {
    return new Promise((resolve, reject) => {
        exec('docker ps -a --format "{{json .}}" 2>/dev/null', (err, stdout) => {
            if (err) return reject(err);
            const containers = stdout.trim().split('\n')
                .filter(line => line)
                .map(line => JSON.parse(line));
            resolve(containers);
        });
    });
}

function getDockerImages() {
    return new Promise((resolve, reject) => {
        exec('docker images --format "{{json .}}" 2>/dev/null', (err, stdout) => {
            if (err) return reject(err);
            const images = stdout.trim().split('\n')
                .filter(line => line)
                .map(line => JSON.parse(line));
            resolve(images);
        });
    });
}

function generateCertificates(type) {
    return new Promise((resolve, reject) => {
        const script = path.join(CONFIGS_DIR, 'ssl/generate-certificates.sh');
        exec(`sudo ${script} ${type}`, { timeout: 120000 }, (err, stdout, stderr) => {
            if (err) return reject(err);
            resolve(stdout);
        });
    });
}

function runSecurityScan() {
    return new Promise((resolve, reject) => {
        const script = path.join(CONFIGS_DIR, 'security/security-scan.sh');
        exec(`sudo ${script} --full`, { timeout: 600000, maxBuffer: 10 * 1024 * 1024 }, (err, stdout, stderr) => {
            if (err) {
                const error = new Error(err.message);
                error.output = stdout + '\n' + stderr;
                return reject(error);
            }
            resolve(stdout);
        });
    });
}

function createBackup(type) {
    return new Promise((resolve, reject) => {
        if (type === 'configs') {
            const backupDir = `/root/config-backups-${Date.now()}`;
            exec(`mkdir -p ${backupDir} && cp -r ${CONFIGS_DIR} ${backupDir}/`, (err, stdout) => {
                if (err) return reject(err);
                resolve(`Configs backed up to ${backupDir}`);
            });
        } else {
            const script = path.join(CONFIGS_DIR, 'security/backup-databases.sh');
            exec(`sudo ${script} ${type}`, { timeout: 300000 }, (err, stdout, stderr) => {
                if (err) return reject(err);
                resolve(stdout);
            });
        }
    });
}

function getLogs(type, lines) {
    return new Promise((resolve, reject) => {
        const logPaths = {
            'hardening': '/var/log/server-hardening/',
            'docker': 'journalctl -u docker --no-pager',
            'ufw': '/var/log/ufw.log',
            'auth': '/var/log/auth.log',
            'syslog': '/var/log/syslog'
        };
        
        let cmd;
        if (type === 'docker') {
            cmd = `${logPaths[type]} -n ${lines}`;
        } else if (type === 'hardening') {
            cmd = `ls -t ${logPaths[type]}*.log 2>/dev/null | head -1 | xargs tail -n ${lines} 2>/dev/null || echo "No hardening logs found"`;
        } else {
            const logPath = logPaths[type];
            if (!logPath) return reject(new Error('Invalid log type'));
            cmd = `sudo tail -n ${lines} ${logPath} 2>/dev/null || echo "Log file not found"`;
        }
        
        exec(cmd, { maxBuffer: 5 * 1024 * 1024 }, (err, stdout) => {
            if (err) return reject(err);
            resolve(stdout);
        });
    });
}

function validateConfigs() {
    return new Promise((resolve, reject) => {
        const script = path.resolve(__dirname, '../../validate-configs.sh');
        exec(`cd ${path.dirname(script)} && bash ${script}`, { timeout: 60000 }, (err, stdout, stderr) => {
            resolve({
                output: stdout,
                success: !err,
                errors: stderr
            });
        });
    });
}

function getSSHConfig() {
    return new Promise((resolve, reject) => {
        exec('sudo sshd -T 2>/dev/null | grep -E "^(port|permitrootlogin|passwordauthentication|maxauthtries)" ', (err, stdout) => {
            if (err) return reject(err);
            
            const config = {};
            stdout.trim().split('\n').forEach(line => {
                const [key, value] = line.split(' ');
                config[key] = value;
            });
            resolve(config);
        });
    });
}

function updateSSHConfig(settings) {
    return new Promise((resolve, reject) => {
        const configPath = '/etc/ssh/sshd_config.d/99-dashboard.conf';
        let configContent = '# VPS-Zero Dashboard SSH Configuration\n';
        
        if (settings.port) {
            const portNum = parseInt(settings.port);
            if (isNaN(portNum) || portNum < 1 || portNum > 65535) {
                return reject(new Error('Invalid port number'));
            }
            configContent += `Port ${portNum}\n`;
        }
        if (settings.permitRootLogin !== undefined) {
            configContent += `PermitRootLogin ${settings.permitRootLogin ? 'yes' : 'no'}\n`;
        }
        if (settings.passwordAuth !== undefined) {
            configContent += `PasswordAuthentication ${settings.passwordAuth ? 'yes' : 'no'}\n`;
        }
        if (settings.maxAuthTries) {
            const tries = parseInt(settings.maxAuthTries);
            if (tries > 0 && tries <= 10) {
                configContent += `MaxAuthTries ${tries}\n`;
            }
        }
        
        exec(`echo '${configContent}' | sudo tee ${configPath} && sudo systemctl reload sshd`, (err, stdout, stderr) => {
            if (err) return reject(err);
            resolve('SSH configuration updated successfully');
        });
    });
}

// Start server
app.listen(PORT, HOST, () => {
    console.log(`
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║   VPS-Zero Dashboard                                         ║
║   Enterprise Ubuntu Server Configuration GUI                 ║
║                                                              ║
║   Server running at: http://${HOST}:${PORT}                      ║
║                                                              ║
║   Default credentials:                                       ║
║   Username: admin                                            ║
║   Password: changeme                                         ║
║                                                              ║
║   ⚠️  Please change the default password on first login!     ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
    `);
});
