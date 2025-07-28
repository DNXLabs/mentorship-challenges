#!/bin/bash

# Script to extract Terraform outputs and generate Ansible host_vars
# Usage: ./get-terraform-outputs.sh

set -e

TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"
HOST_VARS_FILE="$ANSIBLE_DIR/host_vars/app-server-1.yml"

echo "=== Terraform Outputs to Ansible Configuration ==="
echo

# Check if terraform directory exists
if [ ! -d "$TERRAFORM_DIR" ]; then
    echo "❌ Terraform directory not found: $TERRAFORM_DIR"
    exit 1
fi

# Check if terraform state exists
if [ ! -f "$TERRAFORM_DIR/terraform.tfstate" ]; then
    echo "❌ Terraform state not found. Please run 'terraform apply' first."
    exit 1
fi

cd $TERRAFORM_DIR

echo "📋 Extracting Terraform outputs..."

# Get outputs
RDS_ENDPOINT=$(terraform output -raw rds_endpoint 2>/dev/null || echo "")
RDS_DATABASE_NAME=$(terraform output -raw rds_database_name 2>/dev/null || echo "")
RDS_MASTER_USERNAME=$(terraform output -raw rds_master_username 2>/dev/null || echo "")
RDS_APP_USERNAME=$(terraform output -raw rds_app_username 2>/dev/null || echo "")
ALB_DNS_NAME=$(terraform output -raw alb_dns_name 2>/dev/null || echo "")
ALB_ZONE_ID=$(terraform output -raw alb_zone_id 2>/dev/null || echo "")
TARGET_GROUP_ARN=$(terraform output -raw target_group_arn 2>/dev/null || echo "")
EC2_INSTANCE_ID=$(terraform output -raw ec2_instance_id 2>/dev/null || echo "")
EC2_PUBLIC_IP=$(terraform output -raw ec2_public_ip 2>/dev/null || echo "")

cd ..

echo "✅ Terraform outputs extracted:"
echo "   RDS Endpoint: $RDS_ENDPOINT"
echo "   ALB DNS: $ALB_DNS_NAME"
echo "   EC2 Instance: $EC2_INSTANCE_ID"
echo "   EC2 Public IP: $EC2_PUBLIC_IP"
echo

# Check if host_vars example exists
if [ ! -f "$ANSIBLE_DIR/host_vars/app-server-1.yml.example" ]; then
    echo "❌ Ansible host_vars example not found: $ANSIBLE_DIR/host_vars/app-server-1.yml.example"
    exit 1
fi

echo "📝 Generating Ansible host_vars configuration..."

# Create host_vars directory if it doesn't exist
mkdir -p "$ANSIBLE_DIR/host_vars"

# Generate the host_vars file
cat > "$HOST_VARS_FILE" << EOF
---
# Host Variables for app-server-1
# Generated automatically from Terraform outputs on $(date)

# Connection Configuration
ansible_host: "$EC2_PUBLIC_IP"
ansible_user: ubuntu
ansible_ssh_private_key_file: "/path/to/your/private-key.pem"  # UPDATE THIS PATH

# Instance Information
instance_id: "$EC2_INSTANCE_ID"

# RDS Configuration (from Terraform outputs)
terraform_rds_endpoint: "$RDS_ENDPOINT"
terraform_rds_database_name: "$RDS_DATABASE_NAME"
terraform_rds_master_username: "$RDS_MASTER_USERNAME"
terraform_rds_master_password: "CHANGE_ME"  # UPDATE WITH YOUR RDS MASTER PASSWORD
terraform_rds_app_username: "$RDS_APP_USERNAME"
terraform_rds_app_password: "CHANGE_ME"  # UPDATE WITH YOUR RDS APP PASSWORD

# ALB Configuration (from Terraform outputs)
terraform_alb_dns_name: "$ALB_DNS_NAME"
terraform_alb_zone_id: "$ALB_ZONE_ID"
terraform_target_group_arn: "$TARGET_GROUP_ARN"

# Local Database Configuration (for migration from Week 2)
local_db_password: "password"  # UPDATE IF YOUR LOCAL DB PASSWORD IS DIFFERENT

# Security Configuration
vault_jwt_secret: "your-super-secret-jwt-key-change-in-production"  # UPDATE THIS
vault_session_secret: "your-session-secret-change-in-production"  # UPDATE THIS

# Environment Specific Settings
deployment_environment: "dev"
node_environment: "production"

# SSH Configuration
ssh_private_key_path: "/path/to/your/private-key.pem"  # UPDATE THIS PATH

# Feature Flags for this host
stop_local_mysql: false  # Keep local MySQL running during migration
enable_sticky_sessions: false
EOF

echo "✅ Generated: $HOST_VARS_FILE"
echo
echo "⚠️  IMPORTANT: Please update the following values in $HOST_VARS_FILE:"
echo "   - ansible_ssh_private_key_file: Path to your SSH private key"
echo "   - terraform_rds_master_password: Your RDS master password"
echo "   - terraform_rds_app_password: Your RDS application password"
echo "   - vault_jwt_secret: A secure JWT secret"
echo "   - vault_session_secret: A secure session secret"
echo "   - ssh_private_key_path: Path to your SSH private key"
echo

# Test connectivity
echo "🔍 Testing Ansible connectivity..."
if [ -f "$ANSIBLE_DIR/inventory/hosts.yml" ]; then
    echo "To test connectivity, run:"
    echo "cd $ANSIBLE_DIR && ansible -i inventory/hosts.yml app-server-1 -m ping --private-key=/path/to/your/key.pem"
else
    echo "⚠️  Please copy inventory/hosts.yml.example to inventory/hosts.yml first"
fi

echo
echo "🚀 Ready to run Ansible deployment:"
echo "cd $ANSIBLE_DIR && ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --private-key=/path/to/your/key.pem"
echo
echo "=== Configuration Complete ==="
