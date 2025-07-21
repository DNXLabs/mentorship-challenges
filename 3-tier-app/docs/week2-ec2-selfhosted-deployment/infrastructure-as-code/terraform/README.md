# Terraform Configuration for 3-Tier Application

This Terraform configuration provisions AWS infrastructure for the 3-tier application deployment.

## 🏗️ Resources Created

- **EC2 Instance**: Ubuntu server for hosting the application
- **Security Group**: Firewall rules for web traffic and SSH access
- **Key Pair**: SSH key for secure server access (optional)
- **Elastic IP**: Static IP address (optional)
- **Route53 Record**: DNS record for the application (optional)

## 📋 Prerequisites

1. **AWS Account** with appropriate permissions
2. **Terraform** installed (>= 1.0)
3. **AWS CLI** configured with credentials
4. **SSH key pair** generated

## 🚀 Quick Start

### 1. Generate SSH Key Pair

```bash
# Generate a new SSH key pair
ssh-keygen -t ed25519 -f ~/.ssh/3-tier-app-key -C "your-email@example.com"

# Get the public key content
cat ~/.ssh/3-tier-app-key.pub
```

### 2. Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the variables file
vim terraform.tfvars
```

**Required Variables:**
```hcl
# AWS Configuration
aws_region = "us-east-1"

# SSH Key Configuration
public_key_content = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI... your-email@example.com"

# Security Configuration (recommended)
allowed_ssh_cidr_blocks = ["YOUR_IP/32"]  # Replace with your IP
```

### 3. Deploy Infrastructure

```bash
# Initialize Terraform
terraform init

# Plan the deployment
terraform plan

# Apply the configuration
terraform apply
```

### 4. Get Connection Information

```bash
# Get the server IP
terraform output instance_public_ip

# Get the SSH command
terraform output ssh_connection_command

# Get all application URLs
terraform output application_urls
```

## 🔧 Configuration Options

### Core Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `aws_region` | string | `us-east-1` | AWS region for resources |
| `project_name` | string | `3-tier-app` | Project name (used for naming) |
| `environment` | string | `dev` | Environment (dev/staging/prod) |
| `instance_type` | string | `t3.micro` | EC2 instance type |

### Network Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `vpc_id` | string | `""` | VPC ID (empty = use default VPC) |
| `subnet_id` | string | `""` | Subnet ID (empty = use first available) |
| `availability_zones` | list(string) | `[]` | Preferred availability zones |

### Security Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_key_pair` | bool | `true` | Whether to create a new key pair |
| `public_key_content` | string | `""` | SSH public key content |
| `allowed_ssh_cidr_blocks` | list(string) | `["0.0.0.0/0"]` | CIDR blocks for SSH access |

### Storage Variables

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `root_volume_type` | string | `gp3` | EBS volume type |
| `root_volume_size` | number | `20` | Root volume size (GB) |
| `encrypt_root_volume` | bool | `true` | Encrypt root volume |

### Optional Features

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `create_elastic_ip` | bool | `false` | Create and attach Elastic IP |
| `create_dns_record` | bool | `false` | Create Route53 DNS record |
| `enable_detailed_monitoring` | bool | `false` | Enable detailed CloudWatch monitoring |

## 🌍 Environment-Specific Deployments

### Development Environment

```bash
terraform apply -var-file="environments/development.tfvars"
```

**Development Features:**
- `t3.micro` instance (Free Tier eligible)
- No Elastic IP (cost optimization)
- Basic monitoring
- Permissive security groups for development

### Production Environment

```bash
terraform apply -var-file="environments/production.tfvars"
```

**Production Features:**
- `t3.small` or larger instance
- Elastic IP for static addressing
- Enhanced monitoring
- Restricted security groups
- DNS record creation
- IMDSv2 enforcement

## 📤 Outputs

| Output | Description |
|--------|-------------|
| `instance_id` | EC2 instance ID |
| `instance_public_ip` | Public IP address |
| `instance_private_ip` | Private IP address |
| `ssh_connection_command` | SSH command to connect |
| `application_urls` | URLs to access the application |
| `ansible_inventory` | Ansible inventory information |

## 🔐 Security Features

### Network Security
- Security groups with minimal required access
- SSH access can be restricted to specific IP addresses
- HTTPS traffic allowed for SSL termination

### Instance Security
- IMDSv2 required for instance metadata access
- Encrypted EBS volumes by default
- No hardcoded credentials in configuration

### Access Control
- SSH key-based authentication only
- Optional Elastic IP for consistent access
- Security group rules follow least privilege principle

## 🛠️ Customization Examples

### Custom Security Groups

```hcl
# terraform.tfvars
ingress_rules = [
  {
    description = "SSH from office"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["203.0.113.0/24"]  # Office IP range
  },
  {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  },
  {
    description = "HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
]
```

### Custom Tags

```hcl
# terraform.tfvars
default_tags = {
  Project     = "my-3-tier-app"
  Environment = "production"
  Owner       = "devops-team@company.com"
  CostCenter  = "engineering"
  Backup      = "required"
}
```

### DNS Configuration

```hcl
# terraform.tfvars
create_dns_record = true
route53_zone_id   = "Z1234567890ABC"
dns_record_name   = "app.mycompany.com"
```

## 🔄 State Management

### Local State (Development)
```bash
# Default - state stored locally
terraform init
terraform apply
```

### Remote State (Production)
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket = "my-terraform-state"
    key    = "3-tier-app/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## 🧪 Testing

### Validate Configuration
```bash
terraform validate
```

### Plan Changes
```bash
terraform plan -var-file="environments/production.tfvars"
```

### Dry Run
```bash
terraform plan -out=tfplan
terraform show tfplan
```

## 🔍 Troubleshooting

### Common Issues

**Issue**: `No default VPC found`
```bash
# Solution: Create VPC or specify existing one
vpc_id = "vpc-xxxxxxxxx"
```

**Issue**: `InvalidKeyPair.NotFound`
```bash
# Solution: Ensure key pair exists or create new one
create_key_pair = true
public_key_content = "ssh-ed25519 AAAAC3..."
```

**Issue**: `UnauthorizedOperation`
```bash
# Solution: Check AWS credentials and permissions
aws sts get-caller-identity
```

### Debug Commands

```bash
# Enable debug logging
export TF_LOG=DEBUG
terraform apply

# Validate AWS credentials
aws sts get-caller-identity

# Check available VPCs
aws ec2 describe-vpcs

# Check available subnets
aws ec2 describe-subnets
```

## 🧹 Cleanup

```bash
# Destroy all resources
terraform destroy

# Destroy specific resources
terraform destroy -target=aws_instance.app_server
```

## 📚 Additional Resources

- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [AWS EC2 Instance Types](https://aws.amazon.com/ec2/instance-types/)
- [Terraform Best Practices](https://www.terraform.io/docs/cloud/guides/recommended-practices/index.html)

---

**Next Step**: After infrastructure is provisioned, use [Ansible](../ansible/README.md) to deploy the application! 🚀
