#!/bin/bash

# Configuration Validation Script
# Checks if all required configuration files are properly set up

set -e

echo "=== Week 3 Configuration Validation ==="
echo

ERRORS=0
WARNINGS=0

# Function to check if file exists
check_file() {
    local file=$1
    local description=$2
    
    if [ -f "$file" ]; then
        echo "✅ $description: $file"
    else
        echo "❌ $description: $file (missing)"
        ((ERRORS++))
    fi
}

# Function to check for placeholder values
check_placeholder() {
    local file=$1
    local pattern=$2
    local description=$3
    
    if [ -f "$file" ]; then
        if grep -q "$pattern" "$file"; then
            echo "⚠️  $description contains placeholder values in: $file"
            ((WARNINGS++))
        fi
    fi
}

echo "📋 Checking Terraform configuration..."

# Check Terraform files
check_file "terraform/terraform.tfvars" "Terraform variables"
check_file "terraform/main.tf" "Terraform main configuration"
check_file "terraform/variables.tf" "Terraform variable definitions"
check_file "terraform/outputs.tf" "Terraform outputs"

# Check for placeholder values in Terraform
check_placeholder "terraform/terraform.tfvars" "your-key-pair-name" "Key pair name"
check_placeholder "terraform/terraform.tfvars" "YourSecurePassword123!" "RDS passwords"
check_placeholder "terraform/terraform.tfvars" "your-name-or-team" "Owner field"

echo
echo "📋 Checking Ansible configuration..."

# Check Ansible files
check_file "ansible/inventory/hosts.yml" "Ansible inventory"
check_file "ansible/host_vars/app-server-1.yml" "Ansible host variables"
check_file "ansible/playbooks/deploy-week3.yml" "Ansible playbook"
check_file "ansible/ansible.cfg" "Ansible configuration"

# Check for placeholder values in Ansible
check_placeholder "ansible/host_vars/app-server-1.yml" "YOUR_EC2_PUBLIC_IP" "EC2 public IP"
check_placeholder "ansible/host_vars/app-server-1.yml" "/path/to/your/private-key.pem" "SSH private key path"
check_placeholder "ansible/host_vars/app-server-1.yml" "CHANGE_ME" "Database passwords"
check_placeholder "ansible/host_vars/app-server-1.yml" "your-super-secret" "Security secrets"

echo
echo "📋 Checking AWS CLI configuration..."

# Check AWS CLI
if command -v aws &> /dev/null; then
    echo "✅ AWS CLI installed"
    
    if aws sts get-caller-identity &> /dev/null; then
        echo "✅ AWS credentials configured"
        ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
        REGION=$(aws configure get region)
        echo "   Account: $ACCOUNT_ID"
        echo "   Region: $REGION"
    else
        echo "❌ AWS credentials not configured"
        ((ERRORS++))
    fi
else
    echo "❌ AWS CLI not installed"
    ((ERRORS++))
fi

echo
echo "📋 Checking required tools..."

# Check Terraform
if command -v terraform &> /dev/null; then
    TERRAFORM_VERSION=$(terraform version -json | jq -r '.terraform_version')
    echo "✅ Terraform installed (version: $TERRAFORM_VERSION)"
else
    echo "❌ Terraform not installed"
    ((ERRORS++))
fi

# Check Ansible
if command -v ansible &> /dev/null; then
    ANSIBLE_VERSION=$(ansible --version | head -n1 | cut -d' ' -f2)
    echo "✅ Ansible installed (version: $ANSIBLE_VERSION)"
else
    echo "❌ Ansible not installed"
    ((ERRORS++))
fi

# Check jq (used by helper scripts)
if command -v jq &> /dev/null; then
    echo "✅ jq installed"
else
    echo "⚠️  jq not installed (recommended for JSON processing)"
    ((WARNINGS++))
fi

echo
echo "📋 Summary:"
echo "   Errors: $ERRORS"
echo "   Warnings: $WARNINGS"

if [ $ERRORS -eq 0 ]; then
    echo
    echo "🎉 Configuration validation passed!"
    
    if [ $WARNINGS -gt 0 ]; then
        echo "⚠️  Please address the warnings above before deployment."
        echo
        echo "💡 Common fixes:"
        echo "   - Update terraform.tfvars with your actual values"
        echo "   - Update ansible host_vars with your instance details"
        echo "   - Use the get-terraform-outputs.sh script to auto-generate Ansible config"
    fi
    
    echo
    echo "🚀 Next steps:"
    echo "   1. cd terraform && terraform init && terraform plan"
    echo "   2. terraform apply"
    echo "   3. cd ../ansible && ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --private-key=/path/to/your/key.pem"
    
    exit 0
else
    echo
    echo "❌ Configuration validation failed!"
    echo "Please fix the errors above before proceeding."
    exit 1
fi
