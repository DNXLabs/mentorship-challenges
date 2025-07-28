# Week 3: Infrastructure as Code Deployment

This directory contains Terraform and Ansible configurations to deploy the Week 3 architecture with RDS and ALB.

## 🚀 Quick Start

**📖 For detailed instructions, see: [SETUP_GUIDE.md](../SETUP_GUIDE.md)**

### 1. Configure Terraform
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
terraform init
terraform apply
```

### 2. Configure Ansible
```bash
cd ../ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp host_vars/app-server-1.yml.example host_vars/app-server-1.yml
# Edit the files with your values, or use the helper script:
../get-terraform-outputs.sh
```

### 3. Deploy Application
```bash
ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --private-key=/path/to/your/key.pem
```

## 🛠️ Helper Scripts

- `get-terraform-outputs.sh`: Automatically extracts Terraform outputs and generates Ansible configuration

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (>= 1.0)
- Ansible installed (>= 2.9)
- SSH key pair created in AWS (update key name in configurations)

## Step 1: Deploy Infrastructure with Terraform

```bash
cd terraform

# 1. Copy and customize variables
cp terraform.tfvars.example terraform.tfvars

# 2. Edit terraform.tfvars with your values:
#    - aws_region
#    - availability_zones
#    - ssh_key_name
#    - database passwords
#    - etc.

# 3. Deploy infrastructure
terraform init
terraform plan
terraform apply
```

**Important Terraform Outputs:**
After `terraform apply`, note these outputs for Ansible:
- `rds_endpoint`
- `alb_dns_name`
- `ec2_instance_public_ip` (if creating new instances)

## Step 2: Deploy Application with Ansible

```bash
cd ../ansible

# 1. Update inventory with your EC2 instance details
# Edit inventory/hosts.yml:
#   - Replace REPLACE_WITH_EC2_IP_1 with your EC2 public IP
#   - Update SSH key path if needed

# 2. Create host variables with Terraform outputs
# Edit host_vars/app-server-1.yml:
#   - Set terraform_rds_endpoint (from Terraform output)
#   - Set terraform_rds_master_password
#   - Set terraform_rds_app_password
#   - Set terraform_alb_dns_name (from Terraform output)

# 3. Test connectivity
ansible three_tier_app -m ping

# 4. Deploy application
ansible-playbook playbooks/deploy-week3.yml
```

## What the Deployment Does

### Terraform Creates:
- Amazon RDS MySQL instance in private subnets
- Application Load Balancer with target groups
- Security groups with proper access rules
- CloudWatch monitoring and alarms
- All necessary networking components

### Ansible Configures:
- **Database Migration**: Migrates data from local MySQL to RDS
- **Application Update**: Updates API to use RDS connection
- **ALB Preparation**: Configures Nginx and health checks for ALB
- **Monitoring**: Sets up CloudWatch agent and custom metrics
- **Testing**: Validates all components are working

## Testing Your Deployment

After deployment, test these endpoints:
- `http://YOUR_ALB_DNS_NAME/` - Frontend application
- `http://YOUR_ALB_DNS_NAME/api/health` - Health check
- `http://YOUR_ALB_DNS_NAME/api/ready` - Readiness check

## Troubleshooting

### Common Issues:
1. **Terraform fails**: Check AWS credentials and permissions
2. **Ansible connection fails**: Verify EC2 IP and SSH key path
3. **Database connection fails**: Check RDS endpoint and security groups
4. **ALB health checks fail**: Verify application is running on port 3000

### Useful Commands:
```bash
# Check Terraform outputs
terraform output

# Test Ansible connectivity
ansible three_tier_app -m ping

# Run specific Ansible tags
ansible-playbook playbooks/deploy-week3.yml --tags database
ansible-playbook playbooks/deploy-week3.yml --tags testing

# Check application logs
ansible three_tier_app -a "pm2 logs formapp-api --lines 20"
```

## Cleanup

To destroy resources:
```bash
# Destroy Terraform infrastructure
cd terraform
terraform destroy

# Note: Ansible doesn't need cleanup as it only configures existing resources
```

## File Structure

```
infrastructure-as-code/
├── terraform/
│   ├── main.tf                 # Main infrastructure definition
│   ├── variables.tf            # Input variables
│   ├── outputs.tf              # Output values
│   └── terraform.tfvars.example # Configuration template
└── ansible/
    ├── ansible.cfg             # Ansible configuration
    ├── inventory/hosts.yml     # Target servers
    ├── group_vars/             # Group variables
    ├── host_vars/              # Host-specific variables
    ├── playbooks/
    │   └── deploy-week3.yml    # Main deployment playbook
    └── roles/                  # Ansible roles
        ├── database_migration/
        ├── application_update/
        ├── alb_preparation/
        ├── monitoring_update/
        └── testing/
```

This approach gives you hands-on experience with both Terraform and Ansible while following the deployment guide requirements!
