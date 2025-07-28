# Week 3: Quick Start Guide

This guide will help you quickly set up and deploy the Week 3 3-tier application with RDS and ALB using the provided example files.

## 🚀 Quick Setup (5 minutes)

### Step 1: Copy Example Files
```bash
# Navigate to the infrastructure directory
cd /workspaces/mentorship-challenges/3-tier-app/docs/week3-ec2-decoupling-and-alb/infrastructure-as-code

# Copy Terraform example
cd terraform
cp terraform.tfvars.example terraform.tfvars

# Copy Ansible examples
cd ../ansible
cp inventory/hosts.yml.example inventory/hosts.yml
cp host_vars/app-server-1.yml.example host_vars/app-server-1.yml
```

### Step 2: Configure Terraform
Edit `terraform/terraform.tfvars` and update these key values:

```hcl
# REQUIRED CHANGES:
aws_region = "your-preferred-region"           # e.g., "us-west-2"
availability_zones = ["your-region-az"]       # e.g., ["us-west-2a"]
admin_cidr_blocks = ["YOUR.IP.ADDRESS/32"]    # Your actual IP address
db_password = "YourSecurePassword123!"        # Strong password
default_tags = {
  Owner = "your-name"                          # Your name
  # ... other tags
}
```

### Step 3: Deploy Infrastructure
```bash
cd terraform
terraform init
terraform plan
terraform apply
```

### Step 4: Configure Ansible
Use the helper script to automatically populate Ansible configuration:

```bash
cd ..
./get-terraform-outputs.sh
```

Or manually edit `ansible/host_vars/app-server-1.yml`:
```yaml
# REQUIRED CHANGES:
ansible_host: "YOUR.EC2.PUBLIC.IP"
ansible_ssh_private_key_file: "/path/to/your/key.pem"
instance_id: "i-xxxxxxxxxxxxxxxxx"
terraform_rds_endpoint: "your-rds-endpoint"
# ... other values from Terraform outputs
```

### Step 5: Deploy Application
```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/deploy.yml
```

### Step 6: Test Your Deployment
```bash
# Get ALB DNS name
cd ../terraform
terraform output alb_dns_name

# Test the application
curl http://your-alb-dns-name
```

## 📋 Configuration Checklist

### Before Terraform Apply:
- [ ] Updated `aws_region` to your preferred region
- [ ] Updated `availability_zones` to match your region
- [ ] Changed `admin_cidr_blocks` to your IP address
- [ ] Set a strong `db_password`
- [ ] Updated `Owner` tag with your name
- [ ] Reviewed all "CHANGE THIS" comments

### Before Ansible Deploy:
- [ ] Updated `ansible_host` with EC2 public IP
- [ ] Updated `ansible_ssh_private_key_file` with correct path
- [ ] Updated `instance_id` with actual EC2 instance ID
- [ ] Updated all `terraform_*` values with Terraform outputs
- [ ] Changed `vault_jwt_secret` and `vault_session_secret`
- [ ] Set correct `cloudwatch_region`

## 🛠️ Helper Scripts

### Validation Script
```bash
./validate-config.sh
```
Checks for:
- Required files exist
- Placeholder values that need updating
- AWS CLI configuration
- Required tools installed

### Terraform Outputs Script
```bash
./get-terraform-outputs.sh
```
Automatically:
- Extracts Terraform outputs
- Updates Ansible configuration files
- Validates the configuration

## 🔧 Common Issues and Solutions

### Issue: "Key pair not found"
**Solution:** Create an EC2 key pair in your AWS region first
```bash
aws ec2 create-key-pair --key-name my-key --query 'KeyMaterial' --output text > my-key.pem
chmod 400 my-key.pem
```

### Issue: "VPC not found" 
**Solution:** Either:
1. Set `use_existing_vpc = false` to create a new VPC
2. Provide correct `existing_vpc_id` if using existing VPC

### Issue: "Permission denied (publickey)"
**Solution:** Check:
- SSH key path is correct
- Key permissions are 400: `chmod 400 your-key.pem`
- Security group allows SSH from your IP

### Issue: "Database connection failed"
**Solution:** Verify:
- RDS instance is available
- Security group allows MySQL (3306) from EC2
- Database credentials match terraform.tfvars

## 🌍 Region-Specific Examples

### US East (N. Virginia)
```hcl
aws_region = "us-east-1"
availability_zones = ["us-east-1a", "us-east-1b"]
```

### US West (Oregon)
```hcl
aws_region = "us-west-2"
availability_zones = ["us-west-2a", "us-west-2b"]
```

### Europe (Ireland)
```hcl
aws_region = "eu-west-1"
availability_zones = ["eu-west-1a", "eu-west-1b"]
```

### Asia Pacific (Sydney)
```hcl
aws_region = "ap-southeast-2"
availability_zones = ["ap-southeast-2a", "ap-southeast-2b"]
```

## 🔒 Security Best Practices

### For Learning/Development:
- Use your actual IP in `admin_cidr_blocks`
- Use strong passwords for database
- Keep `db_deletion_protection = false` for easy cleanup

### For Production:
- Enable `db_deletion_protection = true`
- Set `db_skip_final_snapshot = false`
- Enable `db_multi_az = true`
- Use HTTPS with SSL certificates
- Implement proper backup strategies
- Use AWS Secrets Manager for passwords

## 📞 Getting Help

1. **Check the validation script output**: `./validate-config.sh`
2. **Review the comprehensive guides**:
   - `SETUP_GUIDE.md` - Detailed setup instructions
   - `EXAMPLES_SUMMARY.md` - Overview of all example files
3. **Check Terraform/Ansible logs** for specific error messages
4. **Verify AWS CLI configuration**: `aws configure list`

## 🎯 Success Indicators

Your deployment is successful when:
- ✅ Terraform apply completes without errors
- ✅ RDS instance shows "available" status
- ✅ ALB shows "active" status
- ✅ Target group shows "healthy" targets
- ✅ Application responds at ALB DNS name
- ✅ Database connection works from application

## 🧹 Cleanup

When you're done with the lab:
```bash
cd terraform
terraform destroy
```

This will remove all AWS resources and stop billing.

---

**Ready to start?** Follow the Quick Setup steps above and you'll have a running 3-tier application in about 10-15 minutes!
