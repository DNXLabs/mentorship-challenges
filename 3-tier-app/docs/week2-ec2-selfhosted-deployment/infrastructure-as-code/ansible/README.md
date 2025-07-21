# Ansible Configuration for 3-Tier Application

This Ansible configuration automates the deployment and management of the 3-tier application on AWS EC2 instances.

## 🎯 What Gets Deployed

### Application Stack
- **Web Tier**: Nginx reverse proxy serving static files
- **API Tier**: Node.js Express server managed by PM2
- **Database Tier**: MySQL 8.0 with application schema

### Additional Components
- **Monitoring**: Health checks, log rotation, performance monitoring
- **Security**: UFW firewall, fail2ban, secure configurations
- **Backup**: Automated database backups
- **Logging**: Centralized log management

## 📁 Role Structure

```
roles/
├── common/          # Basic system setup and configuration
├── database/        # MySQL installation and configuration
├── application/     # Node.js API deployment and PM2 setup
├── webserver/       # Nginx configuration and static files
├── monitoring/      # Health checks and log management
└── security/        # Firewall, fail2ban, and hardening
```

## 🚀 Quick Start (Learning-First Approach)

### Prerequisites

1. **Ansible** installed (>= 2.9)
2. **Target server** provisioned (via Terraform or manually)
3. **SSH access** to the target server
4. **Server details** from Terraform outputs

### 1. Create Host Variables

```bash
# Create host-specific configuration
vim host_vars/3-tier-app-server.yml
```

**Add your server details:**
```yaml
---
# Connection details (from terraform output)
ansible_host: "YOUR_SERVER_PUBLIC_IP"  # From terraform output
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/3-tier-app
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

# Database configuration (change these passwords!)
db_password: "YourSecurePassword123!"
db_root_password: "YourSecureRootPassword123!"

# Application configuration
app_port: 3000
nginx_server_name: "_"  # or your domain
```

### 2. Test Connection

```bash
# Test if Ansible can connect to your server
ansible all -i inventory/hosts.yml -m ping
```

### 3. Deploy Application

```bash
# Deploy the full application
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml

# Deploy with verbose output (to learn what's happening)
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -v

# Deploy specific components only
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --tags database
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --tags application
```

## 🔧 Configuration Management

### Environment Variables

Variables are managed hierarchically:

1. **Global defaults**: `group_vars/all.yml`
2. **Environment-specific**: `group_vars/{environment}.yml`
3. **Host-specific**: `host_vars/{hostname}.yml`
4. **Command-line**: `--extra-vars`

### Development Environment

```bash
./deploy.sh -e dev
```

**Development Features:**
- Relaxed security settings
- Development tools installed
- File watching enabled
- Basic monitoring
- Smaller resource allocation

### Production Environment

```bash
./deploy.sh -e prod --vault-password-file .vault_pass
```

**Production Features:**
- Strict security settings
- SSL/TLS configuration
- Comprehensive monitoring
- Multiple PM2 instances
- Automated backups
- Performance optimization

## 📊 Variable Configuration

### Application Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `app_name` | `3-tier-form-app` | Application name |
| `app_port` | `3000` | Application port |
| `app_version` | `1.0.0` | Application version |
| `app_directory` | `/opt/3-tier-app` | Application directory |

### Database Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `db_name` | `formapp` | Database name |
| `db_user` | `formapp_user` | Database user |
| `db_password` | `SecurePassword123!` | Database password |
| `db_host` | `localhost` | Database host |

### Web Server Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `nginx_server_name` | `_` | Nginx server name |
| `nginx_document_root` | `/var/www/html` | Document root |
| `nginx_client_max_body_size` | `10M` | Max upload size |

### PM2 Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `pm2_app_name` | `formapp-api` | PM2 application name |
| `pm2_instances` | `1` | Number of instances |
| `pm2_exec_mode` | `fork` | Execution mode |
| `pm2_max_memory_restart` | `200M` | Memory restart limit |

## 🏷️ Deployment Tags

Deploy specific components using tags:

```bash
# System setup only
./deploy.sh -t common

# Database only
./deploy.sh -t database

# Application only
./deploy.sh -t application

# Web server only
./deploy.sh -t webserver

# Monitoring setup
./deploy.sh -t monitoring

# Security hardening
./deploy.sh -t security

# Multiple components
./deploy.sh -t "database,application"
```

## 🔐 Security Features

### Firewall Configuration
- UFW firewall with minimal required ports
- SSH access can be restricted to specific IPs
- Fail2ban for intrusion prevention

### Application Security
- Non-root application user
- Secure file permissions
- Environment variable protection
- Database access restrictions

### System Security
- Automatic security updates
- SSH hardening
- Log monitoring
- Security audit scripts

## 📈 Monitoring and Logging

### Built-in Monitoring Scripts

```bash
# Full monitoring dashboard
/opt/3-tier-app/scripts/monitor_all.sh

# Quick health check
/opt/3-tier-app/scripts/health_check.sh

# Log analysis
/opt/3-tier-app/scripts/analyze_logs.sh

# Security audit
/opt/3-tier-app/scripts/security_audit.sh
```

### Automated Tasks

- **Health checks**: Every 5 minutes
- **Log rotation**: Daily
- **Database backups**: Daily at 2 AM
- **Security audits**: Weekly
- **Log cleanup**: Daily at 1 AM

## 🛠️ Customization

### Adding Custom Variables

```bash
# Command line
./deploy.sh --extra-vars "app_port=8080,db_name=myapp"

# Environment file
# group_vars/custom.yml
app_port: 8080
db_name: myapp

./deploy.sh -e custom
```

### Custom Nginx Configuration

```yaml
# group_vars/production.yml
nginx:
  server_name: "app.mycompany.com"
  client_max_body_size: "50M"
  enable_gzip: true
  ssl_enabled: true
```

### Custom PM2 Configuration

```yaml
# group_vars/production.yml
pm2:
  app_name: "my-api"
  instances: 4
  exec_mode: "cluster"
  max_memory_restart: "1G"
```

## 🔄 Deployment Workflows

### Development Workflow

```bash
# 1. Deploy to development
./deploy.sh -e dev

# 2. Test changes
curl http://server-ip/api/submissions

# 3. Update application only
./deploy.sh -e dev -t application

# 4. Check logs
ssh ubuntu@server-ip "pm2 logs"
```

### Production Workflow

```bash
# 1. Dry run first
./deploy.sh -e prod --check

# 2. Deploy with vault
./deploy.sh -e prod --vault-password-file .vault_pass

# 3. Verify deployment
./deploy.sh -e prod --check  # Should show no changes

# 4. Monitor application
ssh ubuntu@server-ip "/opt/3-tier-app/scripts/monitor_all.sh"
```

## 🔍 Troubleshooting

### Connection Issues

```bash
# Test connectivity
ansible all -i inventory/hosts.yml -m ping

# Debug SSH connection
ansible all -i inventory/hosts.yml -m ping -vvv

# Check SSH key permissions
chmod 600 ~/.ssh/your-key.pem
```

### Deployment Issues

```bash
# Run with verbose output
./deploy.sh -vvv

# Check specific role
./deploy.sh -t database -vv

# Verify variables
ansible-playbook playbooks/deploy.yml --list-vars
```

### Service Issues

```bash
# Check service status
ansible all -i inventory/hosts.yml -m shell -a "systemctl status nginx mysql"

# Check PM2 status
ansible all -i inventory/hosts.yml -m shell -a "pm2 status" -b -u ubuntu

# Check application logs
ansible all -i inventory/hosts.yml -m shell -a "tail -50 /opt/3-tier-app/logs/*.log"
```

## 🧪 Testing

### Syntax Check

```bash
ansible-playbook playbooks/deploy.yml --syntax-check
```

### Dry Run

```bash
./deploy.sh --check
```

### Specific Host Testing

```bash
./deploy.sh -l 3-tier-app-server -t application
```

## 🔒 Secrets Management

### Using Ansible Vault

```bash
# Create vault file
ansible-vault create group_vars/vault.yml

# Edit vault file
ansible-vault edit group_vars/vault.yml

# Deploy with vault
./deploy.sh --vault-password-file .vault_pass
```

**Example vault content:**
```yaml
# group_vars/vault.yml
vault_db_password: "SuperSecurePassword123!"
vault_db_root_password: "SuperSecureRootPassword123!"
```

**Reference in variables:**
```yaml
# group_vars/production.yml
database:
  password: "{{ vault_db_password }}"
  root_password: "{{ vault_db_root_password }}"
```

## 📚 Role Documentation

### Common Role
- System package updates
- Essential tool installation
- Directory structure creation
- User configuration

### Database Role
- MySQL installation and configuration
- Database and user creation
- Schema import
- Backup script setup

### Application Role
- Node.js application deployment
- PM2 configuration and startup
- Environment file creation
- Health check setup

### Webserver Role
- Nginx installation and configuration
- Static file deployment
- Reverse proxy setup
- SSL configuration (if enabled)

### Monitoring Role
- Health check scripts
- Log rotation configuration
- Performance monitoring setup
- Automated cleanup tasks

### Security Role
- UFW firewall configuration
- Fail2ban setup
- File permission hardening
- Security audit scripts

## 📋 Best Practices

1. **Use environment-specific variables**
2. **Encrypt sensitive data with Ansible Vault**
3. **Test deployments with `--check` mode first**
4. **Use tags for partial deployments**
5. **Monitor deployment logs**
6. **Keep inventory files secure**
7. **Use version control for configurations**
8. **Document custom variables**

---

**Ready to deploy?** Start with the [Quick Start](#-quick-start) section! 🚀
