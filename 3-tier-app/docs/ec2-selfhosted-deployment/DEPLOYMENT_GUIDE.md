# AWS EC2 Self-Hosted Deployment Guide

## Overview
This guide provides step-by-step instructions for deploying the 3-tier form application on an AWS EC2 instance using traditional server deployment methods. You'll learn infrastructure fundamentals, server management, and DevOps practices while building a production-ready deployment.

## What You'll Build

By following this guide, you'll deploy:
- **Web Tier**: Nginx serving static HTML/CSS/JS files
- **API Tier**: Node.js Express server with PM2 process management  
- **Database Tier**: MySQL 8.0 database with proper security configuration

## Architecture Overview

```
Internet → EC2 Instance (Ubuntu 24.04)
├── Nginx (Port 80) → Static Files + Reverse Proxy
├── Node.js API (Port 3000) → Managed by PM2
└── MySQL (Port 3306) → Local Database
```

## Prerequisites

### AWS Requirements
- AWS Account with EC2 access
- Basic understanding of AWS Console
- SSH key pair for EC2 access

### Local Requirements
- Terminal/Command Line access
- SSH client
- Git (for cloning repository)
- Basic Linux command knowledge

### Estimated Costs
- **EC2 t3.micro**: ~$8.50/month (Free Tier eligible)
- **EBS Storage**: ~$1/month for 8GB
- **Data Transfer**: Minimal for development use

## Step 1: Launch EC2 Instance

### 1.1 Create EC2 Instance
1. **Login to AWS Console** and navigate to EC2
2. **Click "Launch Instance"**
3. **Configure Instance:**
   - **Name**: `3-tier-app-server`
   - **AMI**: Ubuntu Server 24.04 LTS
   - **Instance Type**: t3.micro (Free Tier eligible)
   - **Key Pair**: Create new or select existing
   - **Security Group**: Create new with following rules:

### 1.2 Security Group Configuration
Create security group named `3-tier-app-sg`:

| Type | Protocol | Port | Source | Description |
|------|----------|------|---------|-------------|
| SSH | TCP | 22 | Your IP | SSH access |
| HTTP | TCP | 80 | 0.0.0.0/0 | Web traffic |
| HTTPS | TCP | 443 | 0.0.0.0/0 | Secure web traffic |
| Custom TCP | TCP | 3000 | Your IP | API development access |

### 1.3 Storage Configuration
- **Root Volume**: 8 GB gp3 (sufficient for this application)
- **Encryption**: Enable for security best practices

### 1.4 Launch and Connect
1. **Launch the instance**
2. **Wait for instance to reach "running" state**
3. **Note the Public IP address**
4. **Test SSH connection:**
   ```bash
   ssh -i your-key.pem ubuntu@YOUR-PUBLIC-IP
   ```

## Step 2: Initial Server Setup

### 2.1 Update System Packages
```bash
# Update package lists
sudo apt update

# Upgrade installed packages
sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl wget git htop unzip
```

### 2.2 Configure Firewall (Optional but Recommended)
```bash
# Enable UFW firewall
sudo ufw enable

# Allow SSH
sudo ufw allow 22

# Allow HTTP/HTTPS
sudo ufw allow 80
sudo ufw allow 443

# Check status
sudo ufw status
```

### 2.3 Clone Application Repository
```bash
# Clone the repository
git clone https://github.com/DNXLabs/mentorship-challenges.git

# Navigate to application directory
cd mentorship-challenges/3-tier-app

# Explore the structure
ls -la src/
```

## Step 3: Install Required Software

### 3.1 Install Node.js 18.x
```bash
# Add NodeSource repository
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -

# Install Node.js
sudo apt-get install -y nodejs

# Verify installation
node --version  # Should show v18.x.x
npm --version   # Should show 10.x.x
```

### 3.2 Install MySQL Server
```bash
# Install MySQL
sudo apt-get install -y mysql-server

# Start MySQL service
sudo systemctl start mysql
sudo systemctl enable mysql

# Verify MySQL is running
sudo systemctl status mysql
```

### 3.3 Install Nginx
```bash
# Install Nginx
sudo apt-get install -y nginx

# Start Nginx service
sudo systemctl start nginx
sudo systemctl enable nginx

# Verify Nginx is running
sudo systemctl status nginx

# Test default page
curl http://localhost
```

## Step 4: Database Configuration

### 4.1 Secure MySQL Installation
```bash
# Run security script (optional for development)
sudo mysql_secure_installation

# Follow prompts:
# - Set root password: Yes (choose strong password)
# - Remove anonymous users: Yes
# - Disallow root login remotely: Yes
# - Remove test database: Yes
# - Reload privilege tables: Yes
```

### 4.2 Create Application Database and User
```bash
# Connect to MySQL as root
sudo mysql

# Run these SQL commands:
```

```sql
-- Create database
CREATE DATABASE IF NOT EXISTS formapp;

-- Create application user
CREATE USER IF NOT EXISTS 'formapp_user'@'localhost' IDENTIFIED BY 'your_secure_password_here';

-- Grant privileges
GRANT ALL PRIVILEGES ON formapp.* TO 'formapp_user'@'localhost';

-- Apply changes
FLUSH PRIVILEGES;

-- Exit MySQL
EXIT;
```

### 4.3 Import Database Schema
```bash
# Import the schema
sudo mysql formapp < src/database/init.sql

# Verify tables were created
mysql -u formapp_user -p formapp -e "SHOW TABLES;"

# Check sample data
mysql -u formapp_user -p formapp -e "SELECT COUNT(*) as records FROM submissions;"
```

## Step 5: API Server Setup

### 5.1 Install API Dependencies
```bash
# Navigate to API directory
cd src/api

# Install Node.js dependencies
npm install

# Verify package installation
ls node_modules/ | head -10
```

### 5.2 Configure Environment Variables
```bash
# Create environment file
cat > .env << 'EOF'
# Server Configuration
PORT=3000

# MySQL Configuration
DB_HOST=localhost
DB_USER=formapp_user
DB_PASSWORD=your_secure_password_here
DB_NAME=formapp
EOF

# Secure the environment file
chmod 600 .env

# Verify configuration
cat .env
```

### 5.3 Test API Server
```bash
# Test server startup
npm start

# In another terminal, test API endpoint
curl http://localhost:3000/api/submissions

# Stop server with Ctrl+C
```

### 5.4 Install and Configure PM2
```bash
# Install PM2 globally
sudo npm install -g pm2

# Start API server with PM2
pm2 start server.js --name 'formapp-api'

# Check PM2 status
pm2 status

# View logs
pm2 logs formapp-api --lines 10

# Configure PM2 to start on boot
pm2 startup
# Follow the command output instructions

# Save PM2 configuration
pm2 save
```

## Step 6: Web Server Configuration

### 6.1 Copy Web Files
```bash
# Navigate back to project root
cd ../../

# Copy static files to Nginx directory
sudo cp -r src/web/* /var/www/html/

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Verify files are copied
ls -la /var/www/html/
```

### 6.2 Configure Nginx
```bash
# Create Nginx site configuration
sudo tee /etc/nginx/sites-available/formapp > /dev/null << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Serve static files
    location / {
        root /var/www/html;
        index index.html;
        try_files $uri $uri/ =404;
    }
    
    # Proxy API requests to Node.js server
    location /api/ {
        proxy_pass http://localhost:3000;
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
EOF

# Enable the site
sudo ln -sf /etc/nginx/sites-available/formapp /etc/nginx/sites-enabled/

# Remove default site
sudo rm -f /etc/nginx/sites-enabled/default

# Test Nginx configuration
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx
```

## Step 7: Testing and Verification

### 7.1 Test Web Application
```bash
# Test main page
curl -I http://YOUR-PUBLIC-IP/

# Test admin page
curl -I http://YOUR-PUBLIC-IP/admin.html

# Test API endpoint
curl http://YOUR-PUBLIC-IP/api/submissions
```

### 7.2 Browser Testing
1. **Open browser** and navigate to `http://YOUR-PUBLIC-IP/`
2. **Test form submission** - Fill out and submit the registration form
3. **Access admin dashboard** at `http://YOUR-PUBLIC-IP/admin.html`
   - Username: `admin`
   - Password: `admin123`
4. **Verify submission** appears in admin dashboard

### 7.3 Service Status Check
```bash
# Check all services
echo "MySQL: $(sudo systemctl is-active mysql)"
echo "Nginx: $(sudo systemctl is-active nginx)"
echo "PM2 API: $(pm2 jlist | jq -r '.[0].pm2_env.status' 2>/dev/null || echo 'running')"
```

## Step 8: Security Hardening (Production)

### 8.1 SSL/TLS Certificate (Optional)
```bash
# Install Certbot
sudo apt install -y certbot python3-certbot-nginx

# Obtain certificate (replace with your domain)
sudo certbot --nginx -d yourdomain.com

# Test automatic renewal
sudo certbot renew --dry-run
```

### 8.2 Additional Security Measures
```bash
# Update security group to remove port 3000 access
# (Only allow from localhost after testing)

# Configure fail2ban for SSH protection
sudo apt install -y fail2ban

# Enable automatic security updates
sudo apt install -y unattended-upgrades
sudo dpkg-reconfigure -plow unattended-upgrades
```

## Service Management

### Starting/Stopping Services
```bash
# MySQL
sudo systemctl start/stop/restart mysql

# Nginx
sudo systemctl start/stop/restart nginx
sudo systemctl reload nginx  # Reload config without restart

# PM2 API Server
pm2 start/stop/restart formapp-api
pm2 reload formapp-api  # Zero-downtime reload
```

### Viewing Logs
```bash
# Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log

# MySQL logs
sudo tail -f /var/log/mysql/error.log

# PM2 logs
pm2 logs formapp-api
pm2 logs formapp-api --lines 50
```

## Backup and Maintenance

### Database Backup
```bash
# Create backup
mysqldump -u formapp_user -p formapp > backup_$(date +%Y%m%d).sql

# Restore from backup
mysql -u formapp_user -p formapp < backup_20250707.sql
```

### Application Files Backup
```bash
# Backup application and configuration
tar -czf app_backup_$(date +%Y%m%d).tar.gz \
  /var/www/html/ \
  ~/.pm2/ \
  /etc/nginx/sites-available/formapp
```

### System Updates
```bash
# Regular system updates
sudo apt update && sudo apt upgrade -y

# Update Node.js packages
cd mentorship-challenges/3-tier-app/src/api
npm update

# Restart services after updates
pm2 restart formapp-api
sudo systemctl reload nginx
```

## Troubleshooting

### Common Issues

#### API Server Not Responding
```bash
# Check PM2 status
pm2 status

# View PM2 logs
pm2 logs formapp-api --lines 50

# Restart API server
pm2 restart formapp-api

# Check if port 3000 is in use
sudo lsof -i :3000
```

#### Database Connection Issues
```bash
# Check MySQL status
sudo systemctl status mysql

# Test database connection
mysql -u formapp_user -p formapp -e "SELECT 1;"

# Check MySQL logs
sudo tail -f /var/log/mysql/error.log
```

#### Nginx Configuration Issues
```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# View Nginx logs
sudo tail -f /var/log/nginx/error.log
```

#### Permission Issues
```bash
# Fix web files permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/

# Fix environment file permissions
chmod 600 src/api/.env
```

**Congratulations!** You've successfully deployed a 3-tier application on AWS EC2. Your application should now be accessible via your EC2 instance's public IP address.

**Application URLs:**
- **Main Application**: `http://YOUR-PUBLIC-IP/`
- **Admin Dashboard**: `http://YOUR-PUBLIC-IP/admin.html` (admin/admin123)
- **API Endpoint**: `http://YOUR-PUBLIC-IP/api/submissions`
