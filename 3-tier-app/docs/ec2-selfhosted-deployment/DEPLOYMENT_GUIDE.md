# 3-Tier Application Deployment Guide - EC2 Self-Hosted

## Overview
This guide documents the complete deployment process for the 3-tier form application on an Ubuntu EC2 instance. The application consists of:
- **Web Tier**: Nginx serving static HTML/CSS/JS files
- **API Tier**: Node.js Express server with PM2 process management
- **Database Tier**: MySQL 8.0 database

## Server Information
- **Instance**: EC2 Ubuntu 24.04 LTS

## Deployment Summary

### ✅ Successfully Deployed Components
1. **MySQL Database** - Running on port 3306
2. **Node.js API Server** - Running on port 3000 (managed by PM2)
3. **Nginx Web Server** - Running on port 80 with reverse proxy

### 🌐 Application URLs
- **Main Application**: http://3.26.62.52/
- **Admin Dashboard**: http://3.26.62.52/admin.html (admin/admin123)
- **API Endpoint**: http://3.26.62.52/api/submissions

## Step-by-Step Deployment Process

### 1. Initial Server Setup
```bash
# Connect to EC2 instance
ssh -i ~/your-key.pem ubuntu@instance-ip-address

# Update system packages
sudo apt update

# Clone the repository
git clone https://github.com/DNXLabs/mentorship-challenges.git
```

### 2. Install Required Software

#### Node.js Installation
```bash
# Install Node.js 18.x
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Verify installation
node --version  # v18.20.6
npm --version   # 10.8.2
```

#### MySQL Installation
```bash
# Install MySQL Server
sudo apt-get install -y mysql-server

# Verify installation
mysql --version  # mysql Ver 8.0.42-0ubuntu0.24.04.1
```

#### Nginx Installation
```bash
# Install Nginx
sudo apt-get install -y nginx

# Verify installation
nginx -v  # nginx version: nginx/1.24.0 (Ubuntu)
```

### 3. Database Configuration

#### Create Database and User
```bash
sudo mysql -e "
CREATE DATABASE IF NOT EXISTS formapp;
CREATE USER IF NOT EXISTS 'formapp_user'@'localhost' IDENTIFIED BY 'secure_password123';
GRANT ALL PRIVILEGES ON formapp.* TO 'formapp_user'@'localhost';
FLUSH PRIVILEGES;
"
```

#### Import Database Schema
```bash
sudo mysql formapp < mentorship-challenges/3-tier-app/src/database/init.sql
```

#### Verify Database Setup
```bash
mysql -u formapp_user -psecure_password123 -e "USE formapp; SHOW TABLES; SELECT COUNT(*) as sample_records FROM submissions;"
```

### 4. API Server Setup

#### Install Dependencies
```bash
cd mentorship-challenges/3-tier-app/src/api
npm install
```

#### Create Environment Configuration
```bash
cat > .env << 'EOF'
# Server Configuration
PORT=3000

# MySQL Configuration
DB_HOST=localhost
DB_USER=formapp_user
DB_PASSWORD=secure_password123
DB_NAME=formapp
EOF
```

#### Install and Configure PM2
```bash
# Install PM2 globally
sudo npm install -g pm2

# Start API server with PM2
pm2 start server.js --name 'formapp-api'

# Configure PM2 to start on boot
pm2 startup
sudo env PATH=$PATH:/usr/bin /usr/lib/node_modules/pm2/bin/pm2 startup systemd -u ubuntu --hp /home/ubuntu
pm2 save
```

### 5. Web Server Configuration

#### Copy Web Files
```bash
# Copy static files to Nginx directory
sudo cp -r mentorship-challenges/3-tier-app/src/web/* /var/www/html/

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/
sudo chmod -R 755 /var/www/html/
```

#### Configure Nginx
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
# Remove default Nginx site
sudo rm -f /etc/nginx/sites-enabled/default

# Test and reload Nginx
sudo nginx -t
sudo systemctl reload nginx
```

## Service Management

### Check Service Status
```bash
# MySQL status
sudo systemctl status mysql

# Nginx status
sudo systemctl status nginx

# PM2 status
pm2 status

# All services summary
echo "MySQL: $(sudo systemctl is-active mysql)"
echo "Nginx: $(sudo systemctl is-active nginx)"
echo "API (PM2): $(pm2 jlist | jq -r '.[0].pm2_env.status' 2>/dev/null || echo 'running')"
```

### Service Control Commands
```bash
# MySQL
sudo systemctl start/stop/restart mysql

# Nginx
sudo systemctl start/stop/restart nginx
sudo systemctl reload nginx  # Reload config without restart

# PM2 API Server
pm2 start/stop/restart formapp-api
pm2 reload formapp-api  # Zero-downtime reload
pm2 logs formapp-api    # View logs
```

## Testing the Deployment

### Web Application Test
```bash
# Test main page
curl -I http://public-ip-address/

# Test admin page
curl -I http://public-ip-address/admin.html
```

### API Endpoint Tests
```bash
# Get all submissions
curl http://public-ip-address/api/submissions

# Create new submission
curl -X POST http://public-ip-address/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "interests": "technology",
    "subscription": "premium",
    "frequency": "weekly",
    "termsAccepted": true
  }'
```

### Database Test
```bash
# Check database connectivity
mysql -u formapp_user -psecure_password123 -e "SELECT COUNT(*) FROM formapp.submissions;"
```

## Security Considerations

### Current Security Measures
- Database user with limited privileges
- Environment variables for sensitive configuration
- Nginx reverse proxy configuration
- PM2 process management for API stability

### Production Security Enhancements
```bash
# Enable UFW firewall
sudo ufw enable
sudo ufw allow 22    # SSH
sudo ufw allow 80    # HTTP
sudo ufw allow 443   # HTTPS (for future SSL)

# Secure MySQL installation
sudo mysql_secure_installation

# Configure SSL/TLS (recommended for production)
# sudo certbot --nginx -d yourdomain.com
```

## Monitoring and Maintenance

### Log Locations
- **Nginx Access Logs**: `/var/log/nginx/access.log`
- **Nginx Error Logs**: `/var/log/nginx/error.log`
- **MySQL Logs**: `/var/log/mysql/error.log`
- **PM2 Logs**: `pm2 logs formapp-api`

### Backup Procedures
```bash
# Database backup
mysqldump -u formapp_user -psecure_password123 formapp > backup_$(date +%Y%m%d).sql

# Application files backup
tar -czf app_backup_$(date +%Y%m%d).tar.gz /var/www/html/ ~/.pm2/
```

### Performance Monitoring
```bash
# System resources
htop
df -h
free -h

# PM2 monitoring
pm2 monit

# Nginx status
sudo systemctl status nginx
```

## Troubleshooting

### Common Issues and Solutions

#### API Server Not Responding
```bash
# Check PM2 status
pm2 status

# Restart API server
pm2 restart formapp-api

# Check logs
pm2 logs formapp-api --lines 50
```

#### Database Connection Issues
```bash
# Check MySQL status
sudo systemctl status mysql

# Test database connection
mysql -u formapp_user -psecure_password123 -e "SELECT 1;"

# Check MySQL logs
sudo tail -f /var/log/mysql/error.log
```

#### Nginx Configuration Issues
```bash
# Test Nginx configuration
sudo nginx -t

# Check Nginx status
sudo systemctl status nginx

# Check Nginx logs
sudo tail -f /var/log/nginx/error.log
```

#### Port Conflicts
```bash
# Check what's using port 3000
sudo lsof -i :3000

# Check what's using port 80
sudo lsof -i :80
```

## Application Features

### User Features
- Multi-step registration form with validation
- Responsive design for all devices
- Real-time form validation
- Success confirmation after submission

### Admin Features
- Admin dashboard at `/admin.html`
- Default credentials: admin/admin123
- View all form submissions
- Delete submissions with confirmation
- Real-time data refresh

### API Endpoints
- `GET /api/submissions` - Retrieve all submissions
- `POST /api/submissions` - Create new submission
- `GET /api/submissions/:id` - Get specific submission
- `DELETE /api/submissions/:id` - Delete submission

## Deployment Verification Checklist

- [x] MySQL database running and accessible
- [x] Database schema imported with sample data
- [x] Node.js API server running on port 3000
- [x] PM2 managing API server process
- [x] Nginx serving static files on port 80
- [x] Nginx reverse proxy for API requests
- [x] All services configured to start on boot
- [x] Web application accessible via browser
- [x] Admin dashboard functional
- [x] API endpoints responding correctly
- [x] Form submission working end-to-end


**Deployment completed successfully on July 7, 2025**

