# Infrastructure as Code for 3-Tier Application

This directory contains Infrastructure as Code (IaC) configurations for deploying the 3-tier application on AWS EC2 using Terraform and Ansible.

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    AWS Cloud Infrastructure                 │
├─────────────────────────────────────────────────────────────┤
│  ┌─────────────────┐    ┌──────────────────────────────────┐ │
│  │   Terraform     │    │           Ansible                │ │
│  │                 │    │                                  │ │
│  │ • EC2 Instance  │───▶│ • Application Deployment         │ │
│  │ • Security Group│    │ • Configuration Management       │ │
│  │ • Key Pair      │    │ • Service Management             │ │
│  │ • Elastic IP    │    │ • Security Hardening             │ │
│  │ • DNS Records   │    │ • Monitoring Setup               │ │
│  └─────────────────┘    └──────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

## 📁 Directory Structure

```
infrastructure-as-code/
├── terraform/                 # Infrastructure provisioning
│   ├── main.tf               # Main Terraform configuration
│   ├── variables.tf          # Variable definitions
│   ├── outputs.tf            # Output definitions
│   ├── user_data.sh          # Server initialization script
│   ├── terraform.tfvars.example  # Example variables file
│   └── environments/         # Environment-specific configurations
│       ├── development.tfvars
│       └── production.tfvars
└── ansible/                  # Configuration management
    ├── ansible.cfg           # Ansible configuration
    ├── deploy.sh            # Deployment script
    ├── inventory/           # Server inventory
    │   └── hosts.yml.template
    ├── group_vars/          # Group variables
    │   ├── all.yml
    │   ├── development.yml
    │   └── production.yml
    ├── playbooks/           # Ansible playbooks
    │   └── deploy.yml
    └── roles/               # Ansible roles
        ├── common/
        ├── database/
        ├── application/
        ├── webserver/
        ├── monitoring/
        └── security/
```

## 🚀 Quick Start (Learning-First Approach)

### Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (>= 1.0)
3. **Ansible** installed (>= 2.9)
4. **AWS CLI** configured
5. **SSH key pair** for EC2 access

### Step 1: Infrastructure Provisioning with Terraform

```bash
# Navigate to terraform directory
cd terraform/

# Copy and customize variables
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars  # Edit with your values

# Learn terraform commands
terraform init
terraform validate
terraform plan
terraform apply

# Get server details
terraform output
terraform output instance_public_ip
```

### Step 2: Application Deployment with Ansible

```bash
# Navigate to ansible directory
cd ../ansible/

# Create host variables manually (learn ansible structure)
vim host_vars/3-tier-app-server.yml
# Add your server IP and configuration

# Test connection (learn ansible basics)
ansible all -i inventory/hosts.yml -m ping

# Deploy application (learn ansible-playbook)
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

**📚 For detailed step-by-step instructions, see [SIMPLE_DEPLOYMENT.md](SIMPLE_DEPLOYMENT.md)**

## 🔧 Configuration Options

### Terraform Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `aws_region` | AWS region | `us-east-1` | No |
| `project_name` | Project name | `3-tier-app` | No |
| `environment` | Environment | `dev` | No |
| `instance_type` | EC2 instance type | `t3.micro` | No |
| `public_key_content` | SSH public key | - | Yes |
| `create_elastic_ip` | Create Elastic IP | `false` | No |
| `enable_detailed_monitoring` | Enable detailed monitoring | `false` | No |

### Ansible Variables

| Variable | Description | Default | Environment Override |
|----------|-------------|---------|---------------------|
| `app_port` | Application port | `3000` | Yes |
| `db_name` | Database name | `formapp` | Yes |
| `nginx_server_name` | Nginx server name | `_` | Yes |
| `pm2_instances` | PM2 instances | `1` | Yes |
| `backup_enabled` | Enable backups | `true` | Yes |

## 🌍 Environment Management

### Development Environment

```bash
# Terraform
terraform apply -var-file="environments/development.tfvars"

# Ansible
./deploy.sh -e dev
```

**Development Features:**
- Cost-optimized instance types
- Relaxed security settings
- Development tools installed
- File watching enabled
- Basic monitoring

### Production Environment

```bash
# Terraform
terraform apply -var-file="environments/production.tfvars"

# Ansible
./deploy.sh -e prod --vault-password-file .vault_pass
```

**Production Features:**
- High-performance instance types
- Strict security settings
- SSL/TLS enabled
- Comprehensive monitoring
- Automated backups
- Multiple PM2 instances

## 🔐 Security Best Practices

### Terraform Security

- ✅ Encrypted EBS volumes by default
- ✅ IMDSv2 required for instance metadata
- ✅ Security groups with minimal required access
- ✅ No hardcoded credentials
- ✅ Resource tagging for compliance

### Ansible Security

- ✅ UFW firewall configuration
- ✅ Fail2ban intrusion prevention
- ✅ Secure file permissions
- ✅ Ansible Vault for sensitive data
- ✅ Non-root application user
- ✅ Automatic security updates

## 📊 Monitoring and Logging

### Built-in Monitoring

- **Health Checks**: Automated every 5 minutes
- **Log Rotation**: Automatic cleanup of old logs
- **Performance Monitoring**: CPU, memory, disk usage
- **Service Monitoring**: All services monitored for availability
- **Security Auditing**: Regular security scans

### Monitoring Scripts

```bash
# Full monitoring dashboard
/opt/3-tier-app/scripts/monitor_all.sh

# Quick health check
/opt/3-tier-app/scripts/health_check.sh

# Log analysis
/opt/3-tier-app/scripts/analyze_logs.sh
```

## 🔄 Deployment Workflows

### Development Workflow

```bash
# 1. Provision infrastructure
cd terraform/
terraform apply -var-file="environments/development.tfvars"

# 2. Deploy application
cd ../ansible/
./deploy.sh -e dev

# 3. Test deployment
curl http://$(terraform output -raw instance_public_ip)/api/submissions
```

### Production Workflow

```bash
# 1. Plan infrastructure changes
cd terraform/
terraform plan -var-file="environments/production.tfvars"

# 2. Apply infrastructure (with approval)
terraform apply -var-file="environments/production.tfvars"

# 3. Deploy application (with vault)
cd ../ansible/
./deploy.sh -e prod --vault-password-file .vault_pass

# 4. Verify deployment
./deploy.sh -e prod --check  # Dry run to verify state
```

## 🛠️ Customization Guide

### Adding New Environments

1. **Create Terraform variables file:**
   ```bash
   cp environments/development.tfvars environments/staging.tfvars
   # Edit staging.tfvars
   ```

2. **Create Ansible variables file:**
   ```bash
   cp group_vars/development.yml group_vars/staging.yml
   # Edit staging.yml
   ```

3. **Deploy to new environment:**
   ```bash
   terraform apply -var-file="environments/staging.tfvars"
   ./deploy.sh -e staging
   ```

### Adding Custom Ansible Roles

1. **Create role structure:**
   ```bash
   mkdir -p roles/custom_role/{tasks,handlers,templates,files,vars,defaults}
   ```

2. **Add role to playbook:**
   ```yaml
   # playbooks/deploy.yml
   roles:
     - role: custom_role
       tags: ['custom']
   ```

3. **Deploy with custom role:**
   ```bash
   ./deploy.sh -t custom
   ```

## 🔍 Troubleshooting

### Common Terraform Issues

**Issue**: `No default VPC found`
```bash
# Solution: Specify VPC ID in terraform.tfvars
vpc_id = "vpc-xxxxxxxxx"
```

**Issue**: `Key pair already exists`
```bash
# Solution: Use existing key pair
create_key_pair = false
existing_key_pair_name = "my-existing-key"
```

### Common Ansible Issues

**Issue**: `Connection refused`
```bash
# Check SSH connectivity
ansible all -i inventory/hosts.yml -m ping -vvv
```

**Issue**: `Permission denied`
```bash
# Check SSH key permissions
chmod 600 ~/.ssh/your-key.pem
```

**Issue**: `Variable undefined`
```bash
# Check variable definitions in group_vars/
ansible-playbook playbooks/deploy.yml --list-vars
```

## 📚 Additional Resources

- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Ansible Documentation](https://docs.ansible.com/)
- [AWS EC2 Best Practices](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/ec2-best-practices.html)
- [3-Tier Application Deployment Guide](../DEPLOYMENT_GUIDE.md)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](../../../LICENSE) file for details.

---

**Ready to deploy?** Start with the [Quick Start](#-quick-start) section above! 🚀
