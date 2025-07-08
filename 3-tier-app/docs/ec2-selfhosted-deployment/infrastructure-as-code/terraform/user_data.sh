#!/bin/bash
# User Data Script for 3-Tier Application Server
# This script performs initial setup and prepares the server for application deployment

set -e

# Variables from Terraform
PROJECT_NAME="${project_name}"
ENVIRONMENT="${environment}"
INSTALL_DEV_TOOLS="${install_dev_tools:-false}"

# Log all output
exec > >(tee /var/log/user-data.log)
exec 2>&1

echo "=== Starting User Data Script ==="
echo "Project: $PROJECT_NAME"
echo "Environment: $ENVIRONMENT"
echo "Timestamp: $(date)"
echo "Instance ID: $(curl -s http://169.254.169.254/latest/meta-data/instance-id)"
echo "Region: $(curl -s http://169.254.169.254/latest/meta-data/placement/region)"

# Update system packages
echo "=== Updating system packages ==="
apt-get update -y
apt-get upgrade -y

# Install essential tools
echo "=== Installing essential tools ==="
apt-get install -y \
    curl \
    wget \
    git \
    htop \
    unzip \
    tree \
    vim \
    jq \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release

# Configure timezone (can be made variable)
echo "=== Configuring timezone ==="
timedatectl set-timezone UTC

# Install Node.js (version can be made variable)
echo "=== Installing Node.js 18.x ==="
curl -fsSL https://deb.nodesource.com/setup_18.x | bash -
apt-get install -y nodejs

# Verify Node.js installation
echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Install MySQL Server
echo "=== Installing MySQL Server ==="
apt-get install -y mysql-server

# Start and enable MySQL
systemctl start mysql
systemctl enable mysql

# Install Nginx
echo "=== Installing Nginx ==="
apt-get install -y nginx

# Start and enable Nginx
systemctl start nginx
systemctl enable nginx

# Install PM2 globally
echo "=== Installing PM2 ==="
npm install -g pm2

# Install development tools if requested
if [ "$INSTALL_DEV_TOOLS" = "true" ]; then
    echo "=== Installing development tools ==="
    apt-get install -y \
        build-essential \
        python3-pip \
        docker.io \
        docker-compose
    
    # Add ubuntu user to docker group
    usermod -aG docker ubuntu
fi

# Configure UFW firewall
echo "=== Configuring UFW firewall ==="
ufw --force enable
ufw allow 22    # SSH
ufw allow 80    # HTTP
ufw allow 443   # HTTPS

# Create application directory structure
echo "=== Creating application directories ==="
mkdir -p /opt/$PROJECT_NAME/{logs,backups,scripts}
chown -R ubuntu:ubuntu /opt/$PROJECT_NAME

# Install additional monitoring tools
echo "=== Installing monitoring tools ==="
apt-get install -y \
    iotop \
    nethogs \
    ncdu \
    fail2ban

# Configure fail2ban for SSH protection
systemctl enable fail2ban
systemctl start fail2ban

# Install AWS CLI v2
echo "=== Installing AWS CLI v2 ==="
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
./aws/install
rm -rf aws awscliv2.zip

# Install CloudWatch agent (for monitoring)
echo "=== Installing CloudWatch agent ==="
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb
rm amazon-cloudwatch-agent.deb

# Create a welcome message
echo "=== Creating welcome message ==="
cat > /etc/motd << EOF

╔══════════════════════════════════════════════════════════════╗
║                    3-Tier Application Server                 ║
║                                                              ║
║  Project: $PROJECT_NAME                                      ║
║  Environment: $ENVIRONMENT                                   ║
║  Setup completed: $(date)                          ║
║                                                              ║
║  Services installed:                                         ║
║  • Node.js $(node --version)                                 ║
║  • MySQL $(mysql --version | cut -d' ' -f3)                 ║
║  • Nginx $(nginx -v 2>&1 | cut -d' ' -f3)                   ║
║  • PM2 $(pm2 --version)                                      ║
║                                                              ║
║  Next steps:                                                 ║
║  1. Clone the application repository                         ║
║  2. Configure the database                                   ║
║  3. Deploy the application                                   ║
║  4. Configure Nginx                                          ║
║                                                              ║
║  Logs: /var/log/user-data.log                               ║
║  App directory: /opt/$PROJECT_NAME                          ║
╚══════════════════════════════════════════════════════════════╝

EOF

# Create a marker file to indicate user data completion
echo "=== Creating completion marker ==="
touch /var/log/user-data-complete
echo "User data script completed at $(date)" > /var/log/user-data-complete

# Set up log rotation for application logs
echo "=== Setting up log rotation ==="
cat > /etc/logrotate.d/$PROJECT_NAME << EOF
/opt/$PROJECT_NAME/logs/*.log {
    daily
    missingok
    rotate 7
    compress
    delaycompress
    notifempty
    create 644 ubuntu ubuntu
}
EOF

# Final system cleanup
echo "=== Final cleanup ==="
apt-get autoremove -y
apt-get autoclean

echo "=== User Data Script Completed Successfully ==="
echo "Completion time: $(date)"
