/**
 * VPS-Zero Dashboard JavaScript
 */

// State
let currentSection = 'overview';

// Initialize
document.addEventListener('DOMContentLoaded', () => {
    // Check for password change requirement
    const urlParams = new URLSearchParams(window.location.search);
    if (urlParams.get('change_password') === '1') {
        showSection('settings');
        showToast('Please change your default password for security', 'warning');
    }
    
    // Navigation
    document.querySelectorAll('.nav-item[data-section]').forEach(item => {
        item.addEventListener('click', (e) => {
            e.preventDefault();
            const section = item.dataset.section;
            showSection(section);
        });
    });
    
    // Sidebar toggle
    document.getElementById('sidebarToggle').addEventListener('click', () => {
        document.getElementById('sidebar').classList.toggle('open');
    });
    
    // Logout
    document.getElementById('logoutBtn').addEventListener('click', async (e) => {
        e.preventDefault();
        await fetch('/api/logout', { method: 'POST' });
        window.location.href = '/login';
    });
    
    // Forms
    document.getElementById('firewallForm').addEventListener('submit', handleFirewallSubmit);
    document.getElementById('sshForm').addEventListener('submit', handleSSHSubmit);
    document.getElementById('passwordForm').addEventListener('submit', handlePasswordSubmit);
    
    // Load initial data
    loadSystemStatus();
    loadServices();
    
    // Auto-refresh
    setInterval(loadSystemStatus, 30000);
});

// Show section
function showSection(section) {
    currentSection = section;
    
    // Update navigation
    document.querySelectorAll('.nav-item').forEach(item => {
        item.classList.remove('active');
        if (item.dataset.section === section) {
            item.classList.add('active');
        }
    });
    
    // Update sections
    document.querySelectorAll('.section').forEach(sec => {
        sec.classList.remove('active');
    });
    document.getElementById(`section-${section}`).classList.add('active');
    
    // Update page title
    const titles = {
        'overview': 'System Overview',
        'hardening': 'Server Hardening',
        'docker': 'Docker Management',
        'firewall': 'Firewall Configuration',
        'ssh': 'SSH Settings',
        'databases': 'Database Deployment',
        'ssl': 'SSL Certificates',
        'security': 'Security Tools',
        'logs': 'System Logs',
        'settings': 'Settings'
    };
    document.getElementById('pageTitle').textContent = titles[section] || 'Dashboard';
    
    // Load section-specific data
    switch (section) {
        case 'docker':
            loadContainers();
            loadImages();
            break;
        case 'firewall':
            loadFirewallRules();
            break;
        case 'ssh':
            loadSSHConfig();
            break;
    }
    
    // Close sidebar on mobile
    document.getElementById('sidebar').classList.remove('open');
}

// Load system status
async function loadSystemStatus() {
    try {
        const response = await fetch('/api/status');
        const data = await response.json();
        
        // Update stats
        const load = data.loadAverage[0].toFixed(2);
        document.getElementById('cpuLoad').textContent = load;
        
        const memUsed = ((data.totalMemory - data.freeMemory) / data.totalMemory * 100).toFixed(1);
        document.getElementById('memUsage').textContent = `${memUsed}%`;
        
        if (data.disk) {
            document.getElementById('diskUsage').textContent = data.disk.percent;
        }
        
        const uptime = formatUptime(data.uptime);
        document.getElementById('uptime').textContent = uptime;
        
        // Update system info
        document.getElementById('hostname').textContent = data.hostname;
        document.getElementById('osVersion').textContent = data.osVersion;
        document.getElementById('kernelVersion').textContent = data.release;
        document.getElementById('cpuCores').textContent = data.cpus;
        document.getElementById('totalMemory').textContent = formatBytes(data.totalMemory);
        if (data.disk) {
            document.getElementById('diskTotal').textContent = data.disk.total;
        }
        
        // Update status indicator
        const statusEl = document.getElementById('serverStatus');
        statusEl.innerHTML = '<i class="fas fa-circle"></i> Online';
        statusEl.classList.add('online');
        statusEl.classList.remove('offline');
        
    } catch (err) {
        console.error('Failed to load status:', err);
        const statusEl = document.getElementById('serverStatus');
        statusEl.innerHTML = '<i class="fas fa-circle"></i> Error';
        statusEl.classList.add('offline');
        statusEl.classList.remove('online');
    }
}

// Load services
async function loadServices() {
    const container = document.getElementById('servicesList');
    
    try {
        const response = await fetch('/api/services');
        const services = await response.json();
        
        container.innerHTML = Object.entries(services).map(([name, info]) => `
            <div class="service-item">
                <span class="service-name">${name}</span>
                <span class="service-status ${info.active ? 'active' : (info.status === 'unknown' ? 'unknown' : 'inactive')}">
                    <i class="fas fa-${info.active ? 'check-circle' : 'times-circle'}"></i>
                    ${info.status}
                </span>
            </div>
        `).join('');
        
    } catch (err) {
        container.innerHTML = '<div class="text-error">Failed to load services</div>';
    }
}

// Validate configs
async function validateConfigs() {
    const output = document.getElementById('validationOutput');
    output.textContent = 'Running validation...';
    
    try {
        const response = await fetch('/api/validate');
        const data = await response.json();
        output.textContent = data.output || 'Validation complete';
        
        if (data.success) {
            showToast('Configuration validation passed!', 'success');
        } else {
            showToast('Validation found some issues', 'warning');
        }
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
        showToast('Validation failed', 'error');
    }
}

// Run hardening module
async function runHardening(module) {
    const output = document.getElementById('hardeningOutput');
    output.textContent = `Running ${module} module... This may take several minutes.`;
    
    const btn = event.target;
    btn.disabled = true;
    const originalText = btn.innerHTML;
    btn.innerHTML = '<i class="fas fa-spinner fa-spin"></i> Running...';
    
    try {
        const response = await fetch(`/api/hardening/${module}`, {
            method: 'POST'
        });
        const data = await response.json();
        
        if (response.ok) {
            output.textContent = data.output || 'Completed successfully';
            showToast(`${module} module completed successfully`, 'success');
        } else {
            output.textContent = `Error: ${data.error}\n\nOutput:\n${data.output || ''}`;
            showToast(`${module} module failed`, 'error');
        }
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
        showToast('Operation failed', 'error');
    } finally {
        btn.disabled = false;
        btn.innerHTML = originalText;
    }
}

// Docker containers
async function loadContainers() {
    const container = document.getElementById('containersList');
    
    try {
        const response = await fetch('/api/docker/containers');
        
        if (!response.ok) {
            container.innerHTML = '<div class="text-warning">Docker not available or not running</div>';
            return;
        }
        
        const containers = await response.json();
        
        if (containers.length === 0) {
            container.innerHTML = '<div class="text-muted">No containers found</div>';
            return;
        }
        
        container.innerHTML = `
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Name</th>
                        <th>Image</th>
                        <th>Status</th>
                        <th>Ports</th>
                    </tr>
                </thead>
                <tbody>
                    ${containers.map(c => `
                        <tr>
                            <td>${c.Names}</td>
                            <td>${c.Image}</td>
                            <td><span class="service-status ${c.State === 'running' ? 'active' : 'inactive'}">${c.Status}</span></td>
                            <td>${c.Ports || '-'}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
    } catch (err) {
        container.innerHTML = '<div class="text-error">Failed to load containers</div>';
    }
}

// Docker images
async function loadImages() {
    const container = document.getElementById('imagesList');
    
    try {
        const response = await fetch('/api/docker/images');
        
        if (!response.ok) {
            container.innerHTML = '<div class="text-warning">Docker not available</div>';
            return;
        }
        
        const images = await response.json();
        
        if (images.length === 0) {
            container.innerHTML = '<div class="text-muted">No images found</div>';
            return;
        }
        
        container.innerHTML = `
            <table class="data-table">
                <thead>
                    <tr>
                        <th>Repository</th>
                        <th>Tag</th>
                        <th>Size</th>
                        <th>Created</th>
                    </tr>
                </thead>
                <tbody>
                    ${images.map(i => `
                        <tr>
                            <td>${i.Repository}</td>
                            <td>${i.Tag}</td>
                            <td>${i.Size}</td>
                            <td>${i.CreatedSince}</td>
                        </tr>
                    `).join('')}
                </tbody>
            </table>
        `;
    } catch (err) {
        container.innerHTML = '<div class="text-error">Failed to load images</div>';
    }
}

// Firewall rules
async function loadFirewallRules() {
    const output = document.getElementById('firewallRules');
    
    try {
        const response = await fetch('/api/firewall/rules');
        const data = await response.json();
        output.textContent = data.output || 'No firewall rules found';
    } catch (err) {
        output.textContent = 'Error loading firewall rules: ' + err.message;
    }
}

async function handleFirewallSubmit(e) {
    e.preventDefault();
    
    const action = document.getElementById('fwAction').value;
    const port = document.getElementById('fwPort').value;
    const protocol = document.getElementById('fwProtocol').value;
    const from = document.getElementById('fwFrom').value || 'any';
    
    try {
        const response = await fetch('/api/firewall/rule', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action, port, protocol, from })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showToast('Firewall rule added', 'success');
            loadFirewallRules();
            e.target.reset();
        } else {
            showToast(data.error || 'Failed to add rule', 'error');
        }
    } catch (err) {
        showToast('Error: ' + err.message, 'error');
    }
}

// SSH config
async function loadSSHConfig() {
    try {
        const response = await fetch('/api/ssh/config');
        const config = await response.json();
        
        document.getElementById('sshPort').value = config.port || '';
        document.getElementById('maxAuthTries').value = config.maxauthtries || '';
        document.getElementById('permitRootLogin').checked = config.permitrootlogin === 'yes';
        document.getElementById('passwordAuth').checked = config.passwordauthentication === 'yes';
    } catch (err) {
        showToast('Failed to load SSH config', 'error');
    }
}

async function handleSSHSubmit(e) {
    e.preventDefault();
    
    const config = {
        port: document.getElementById('sshPort').value,
        maxAuthTries: document.getElementById('maxAuthTries').value,
        permitRootLogin: document.getElementById('permitRootLogin').checked,
        passwordAuth: document.getElementById('passwordAuth').checked
    };
    
    try {
        const response = await fetch('/api/ssh/config', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(config)
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showToast('SSH configuration saved', 'success');
        } else {
            showToast(data.error || 'Failed to save config', 'error');
        }
    } catch (err) {
        showToast('Error: ' + err.message, 'error');
    }
}

// SSL generation
async function generateSSL(type) {
    const output = document.getElementById('sslOutput');
    output.textContent = `Generating ${type} certificates...`;
    
    try {
        const response = await fetch('/api/ssl/generate', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            output.textContent = data.output || 'Certificates generated successfully';
            showToast('Certificates generated', 'success');
        } else {
            output.textContent = `Error: ${data.error}`;
            showToast('Certificate generation failed', 'error');
        }
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
        showToast('Operation failed', 'error');
    }
}

// Security scan
async function runSecurityScan() {
    const output = document.getElementById('securityOutput');
    output.textContent = 'Running security scan... This may take several minutes.';
    
    try {
        const response = await fetch('/api/security/scan', {
            method: 'POST'
        });
        
        const data = await response.json();
        
        if (response.ok) {
            output.textContent = data.output || 'Scan completed';
            showToast('Security scan completed', 'success');
        } else {
            output.textContent = `Error: ${data.error}\n\nOutput:\n${data.output || ''}`;
            showToast('Security scan failed', 'error');
        }
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
        showToast('Operation failed', 'error');
    }
}

// Backup
async function createBackup(type) {
    const output = document.getElementById('securityOutput');
    output.textContent = `Creating ${type} backup...`;
    
    try {
        const response = await fetch('/api/backup/create', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ type })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            output.textContent = data.output || 'Backup created successfully';
            showToast('Backup created', 'success');
        } else {
            output.textContent = `Error: ${data.error}`;
            showToast('Backup failed', 'error');
        }
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
        showToast('Operation failed', 'error');
    }
}

// Logs
async function loadLogs() {
    const type = document.getElementById('logType').value;
    const lines = document.getElementById('logLines').value;
    const output = document.getElementById('logsOutput');
    
    output.textContent = 'Loading logs...';
    
    try {
        const response = await fetch(`/api/logs/${type}?lines=${lines}`);
        const data = await response.json();
        output.textContent = data.logs || 'No logs found';
    } catch (err) {
        output.textContent = 'Error: ' + err.message;
    }
}

// Password change
async function handlePasswordSubmit(e) {
    e.preventDefault();
    
    const currentPassword = document.getElementById('currentPassword').value;
    const newPassword = document.getElementById('newPassword').value;
    const confirmPassword = document.getElementById('confirmPassword').value;
    
    if (newPassword !== confirmPassword) {
        showToast('Passwords do not match', 'error');
        return;
    }
    
    try {
        const response = await fetch('/api/change-password', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ currentPassword, newPassword })
        });
        
        const data = await response.json();
        
        if (response.ok) {
            showToast('Password changed successfully', 'success');
            e.target.reset();
        } else {
            showToast(data.error || 'Failed to change password', 'error');
        }
    } catch (err) {
        showToast('Error: ' + err.message, 'error');
    }
}

// Clear output
function clearOutput(elementId) {
    document.getElementById(elementId).textContent = '';
}

// Modal functions
function showModal(title, content) {
    document.getElementById('modalTitle').textContent = title;
    document.getElementById('modalBody').innerHTML = content;
    document.getElementById('modal').classList.add('show');
}

function closeModal() {
    document.getElementById('modal').classList.remove('show');
}

// Toast notifications
function showToast(message, type = 'info') {
    const container = document.getElementById('toastContainer');
    const toast = document.createElement('div');
    toast.className = `toast ${type}`;
    
    const icons = {
        success: 'check-circle',
        error: 'times-circle',
        warning: 'exclamation-triangle',
        info: 'info-circle'
    };
    
    toast.innerHTML = `
        <i class="fas fa-${icons[type]}"></i>
        <span>${message}</span>
    `;
    
    container.appendChild(toast);
    
    setTimeout(() => {
        toast.style.animation = 'slideIn 0.3s ease reverse';
        setTimeout(() => toast.remove(), 300);
    }, 5000);
}

// Utility functions
function formatUptime(seconds) {
    const days = Math.floor(seconds / 86400);
    const hours = Math.floor((seconds % 86400) / 3600);
    const mins = Math.floor((seconds % 3600) / 60);
    
    if (days > 0) return `${days}d ${hours}h`;
    if (hours > 0) return `${hours}h ${mins}m`;
    return `${mins}m`;
}

function formatBytes(bytes) {
    const sizes = ['B', 'KB', 'MB', 'GB', 'TB'];
    if (bytes === 0) return '0 B';
    const i = Math.floor(Math.log(bytes) / Math.log(1024));
    return (bytes / Math.pow(1024, i)).toFixed(2) + ' ' + sizes[i];
}
