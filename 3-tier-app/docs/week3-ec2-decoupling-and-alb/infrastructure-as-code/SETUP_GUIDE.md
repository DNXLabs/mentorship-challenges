# Week 3 Setup Guide: RDS Migration and ALB Configuration

This guide will help you deploy the Week 3 infrastructure and migrate your application from local MySQL to Amazon RDS with Application Load Balancer.

## Prerequisites

- AWS CLI configured with appropriate permissions
- Terraform installed (version 1.0+)
- Ansible installed (version 2.10+)
- An existing Week 2 deployment (3-tier application on EC2)
- SSH access to your EC2 instance

## Step 1: Configure Terraform Variables

1. **Copy the example terraform variables:**
   ```bash
   cd infrastructure-as-code/terraform
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit `terraform.tfvars` with your values:**
   ```bash
   nano terraform.tfvars
   ```

3. **Update the following key values:**
   - `aws_region`: Your preferred AWS region
   - `availability_zones`: AZs in your region
   - `key_pair_name`: Your EC2 key pair name
   - `rds_master_password`: A secure password for RDS master user
   - `rds_app_password`: A secure password for application user
   - `allowed_cidr_blocks`: Restrict access (don't use 0.0.0.0/0 in production)

## Step 2: Deploy Infrastructure with Terraform

1. **Initialize Terraform:**
   ```bash
   terraform init
   ```

2. **Plan the deployment:**
   ```bash
   terraform plan
   ```

3. **Apply the infrastructure:**
   ```bash
   terraform apply
   ```

4. **Note the outputs:**
   Save the following outputs for Ansible configuration:
   - `rds_endpoint`
   - `alb_dns_name`
   - `target_group_arn`
   - `ec2_instance_id` (if creating new instance)

## Step 3: Configure Ansible

1. **Copy the example inventory:**
   ```bash
   cd ../ansible
   cp inventory/hosts.yml.example inventory/hosts.yml
   ```

2. **Copy the example host variables:**
   ```bash
   cp host_vars/app-server-1.yml.example host_vars/app-server-1.yml
   ```

3. **Update `host_vars/app-server-1.yml` with your values:**
   - `ansible_host`: Your EC2 instance public IP
   - `ansible_ssh_private_key_file`: Path to your SSH private key
   - `instance_id`: Your EC2 instance ID
   - `terraform_rds_endpoint`: From Terraform output
   - `terraform_alb_dns_name`: From Terraform output
   - `terraform_target_group_arn`: From Terraform output
   - Update all password fields with secure values

## Step 4: Test Ansible Connectivity

```bash
ansible -i inventory/hosts.yml app-server-1 -m ping --private-key=/path/to/your/key.pem
```

## Step 5: Run Database Migration and Application Update

1. **Run the complete deployment:**
   ```bash
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --private-key=/path/to/your/key.pem
   ```

2. **Or run specific components:**
   ```bash
   # Database migration only
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --tags database --private-key=/path/to/your/key.pem
   
   # Application update only
   ansible-playbook -i inventory/hosts.yml playbooks/deploy-week3.yml --tags application --private-key=/path/to/your/key.pem
   ```

## Step 6: Verify Deployment

1. **Check ALB health:**
   ```bash
   aws elbv2 describe-target-health --target-group-arn YOUR_TARGET_GROUP_ARN
   ```

2. **Test application endpoints:**
   ```bash
   # Main application
   curl http://YOUR_ALB_DNS_NAME/
   
   # API endpoint
   curl http://YOUR_ALB_DNS_NAME/api/submissions
   
   # Admin panel
   curl http://YOUR_ALB_DNS_NAME/admin.html
   ```

3. **Verify data migration:**
   ```bash
   curl http://YOUR_ALB_DNS_NAME/api/submissions | jq length
   ```

## Security Considerations

### For Production Deployments:

1. **Network Security:**
   - Use private subnets for RDS
   - Restrict `allowed_cidr_blocks` to your organization's IP ranges
   - Enable VPC Flow Logs

2. **Database Security:**
   - Use strong, unique passwords
   - Enable encryption at rest
   - Enable automated backups
   - Consider using AWS Secrets Manager

3. **Application Security:**
   - Use HTTPS with SSL certificates
   - Implement proper authentication
   - Enable CloudTrail logging
   - Use IAM roles instead of access keys

4. **Monitoring:**
   - Enable CloudWatch monitoring
   - Set up alerts for critical metrics
   - Implement log aggregation

## Troubleshooting

### Common Issues:

1. **Terraform fails with permission errors:**
   - Ensure your AWS credentials have sufficient permissions
   - Check IAM policies for EC2, RDS, and ELB services

2. **Ansible cannot connect to EC2:**
   - Verify security group allows SSH (port 22)
   - Check SSH key path and permissions
   - Ensure EC2 instance is running

3. **Database migration fails:**
   - Verify RDS security group allows access from EC2
   - Check RDS endpoint and credentials
   - Ensure local MySQL has data to migrate

4. **ALB health checks fail:**
   - Verify application is running on correct port
   - Check security group allows HTTP traffic
   - Ensure health check path returns 200 OK

### Useful Commands:

```bash
# Check Terraform state
terraform show

# Validate Ansible playbook
ansible-playbook --syntax-check playbooks/deploy-week3.yml

# Check EC2 instance status
aws ec2 describe-instances --instance-ids YOUR_INSTANCE_ID

# Check RDS status
aws rds describe-db-instances --db-instance-identifier YOUR_DB_IDENTIFIER

# Check ALB status
aws elbv2 describe-load-balancers --names YOUR_ALB_NAME
```

## Cleanup

To destroy the infrastructure:

```bash
cd infrastructure-as-code/terraform
terraform destroy
```

**Warning:** This will delete all resources including the RDS database. Ensure you have backups if needed.

## Next Steps

After successful deployment:
1. Configure monitoring and alerting
2. Set up automated backups
3. Implement CI/CD pipeline
4. Add SSL/TLS certificates
5. Configure auto-scaling policies

## Support

If you encounter issues:
1. Check the troubleshooting section above
2. Review AWS CloudWatch logs
3. Verify all configuration values
4. Ensure prerequisites are met
