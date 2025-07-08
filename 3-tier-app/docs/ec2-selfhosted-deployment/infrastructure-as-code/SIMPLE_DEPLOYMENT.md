# Simple Step-by-Step Deployment Guide

This guide teaches you to deploy the 3-tier application using **IaC with Terraform and Ansible commands** 

## 🎯 Prerequisites

- AWS CLI configured
- Terraform installed
- Ansible installed
- SSH key pair ready

## 📋 Step 1: Deploy Infrastructure with Terraform

### 1.1 Configure Variables

```bash
cd terraform/

# Copy the example and customize
cp terraform.tfvars.example terraform.tfvars
vim terraform.tfvars
```

**Update these key values:**
```hcl
# Your AWS region
aws_region = "us-east-1"

# Use your existing key (not create new one)
create_key_pair = false
existing_key_pair_name = "3-tier-app"  # Your existing key name

# Your project details
default_tags = {
  Project     = "3-tier-app"
  Environment = "dev"
  Owner       = "your-email@example.com"
}
```

### 1.2 Deploy Infrastructure

```bash
# Initialize Terraform (downloads AWS provider)
terraform init

# Validate configuration
terraform validate

# See what will be created
terraform plan

# Create the infrastructure
terraform apply
# Type 'yes' when prompted
```

### 1.3 Get Server Details

```bash
# Get all outputs
terraform output

# Get specific values you'll need
terraform output instance_public_ip
terraform output ssh_connection_command

# Test SSH connection
ssh -i ~/.ssh/3-tier-app ubuntu@$(terraform output -raw instance_public_ip)
```

## 📋 Step 2: Configure Ansible

### 2.1 Create Host Variables

```bash
cd ../ansible/

# Create host-specific configuration
vim host_vars/3-tier-app-server.yml
```

**Copy this template and update with YOUR values:**
```yaml
---
# Connection details (from terraform output)
ansible_host: "PASTE_YOUR_SERVER_IP_HERE"  # From terraform output
ansible_user: ubuntu
ansible_ssh_private_key_file: ~/.ssh/3-tier-app  # Your SSH key path
ansible_ssh_common_args: '-o StrictHostKeyChecking=no'

# Server details (optional, from terraform output)
instance_id: "PASTE_INSTANCE_ID_HERE"
private_ip: "PASTE_PRIVATE_IP_HERE"

# Application configuration
app_name: "3-tier-form-app"
project_name: "3-tier-app"
environment: "dev"

# Database configuration (CHANGE THESE PASSWORDS!)
db_name: "formapp"
db_user: "formapp_user"
db_password: "MySecurePassword123!"      # Change this!
db_root_password: "MySecureRootPassword123!"  # Change this!

# Application settings
app_port: 3000
nginx_server_name: "_"  # Use "_" for any hostname
pm2_app_name: "formapp-api"
```

### 2.2 Test Ansible Connection

```bash
# Test if Ansible can connect to your server
ansible all -i inventory/hosts.yml -m ping

# If successful, you'll see:
# 3-tier-app-server | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }
```

## 📋 Step 3: Deploy Application with Ansible

### 3.1 Run the Deployment

```bash
# Deploy the full application
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml

# Or with verbose output to see what's happening
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -v

# Or with extra verbose for debugging
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -vv
```

### 3.2 Deploy Specific Components (Optional)

```bash
# Deploy only database
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --tags database

# Deploy only application
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --tags application

# Deploy only web server
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml --tags webserver
```

## 📋 Step 4: Verify Deployment

### 4.1 Check Application

```bash
# Get your server IP
SERVER_IP=$(cd ../terraform && terraform output -raw instance_public_ip)

# Test the application
curl http://$SERVER_IP/
curl http://$SERVER_IP/api/submissions
```

### 4.2 Check Services on Server

```bash
# SSH to your server
ssh -i ~/.ssh/3-tier-app ubuntu@$SERVER_IP

# Check services
sudo systemctl status nginx
sudo systemctl status mysql
pm2 status

# Check logs
pm2 logs
sudo tail -f /var/log/nginx/access.log
```

## 🧹 Step 5: Cleanup (When Done)

```bash
# Destroy infrastructure
cd terraform/
terraform destroy
# Type 'yes' when prompted
```

## 🎓 What You Learn

### Terraform Skills:
- ✅ Writing `.tfvars` files
- ✅ Using `terraform init`, `plan`, `apply`
- ✅ Reading terraform outputs
- ✅ Understanding infrastructure as code

### Ansible Skills:
- ✅ Creating inventory files
- ✅ Writing host variables
- ✅ Using `ansible` and `ansible-playbook` commands
- ✅ Understanding playbooks and roles
- ✅ Using tags for partial deployments

### AWS Skills:
- ✅ EC2 instances and security groups
- ✅ SSH key management
- ✅ Understanding AWS networking

## 🔧 Troubleshooting

### Can't connect to server?
```bash
# Check if server is running
aws ec2 describe-instances --instance-ids $(cd terraform && terraform output -raw instance_id)

# Check SSH key permissions
chmod 600 ~/.ssh/3-tier-app

# Test SSH manually
ssh -i ~/.ssh/3-tier-app ubuntu@YOUR_SERVER_IP
```

### Ansible fails?
```bash
# Test connection first
ansible all -i inventory/hosts.yml -m ping -vvv

# Check your host_vars file
cat host_vars/3-tier-app-server.yml

# Run with maximum verbosity
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml -vvv
```

---

You'll understand exactly what each command does and how Terraform and Ansible work together.
