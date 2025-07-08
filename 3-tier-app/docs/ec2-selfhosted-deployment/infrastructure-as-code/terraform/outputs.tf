# Outputs for 3-Tier Application Infrastructure

# Instance Information
output "instance_id" {
  description = "ID of the EC2 instance"
  value       = aws_instance.app_server.id
}

output "instance_arn" {
  description = "ARN of the EC2 instance"
  value       = aws_instance.app_server.arn
}

output "instance_public_ip" {
  description = "Public IP address of the EC2 instance"
  value       = var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip
}

output "instance_private_ip" {
  description = "Private IP address of the EC2 instance"
  value       = aws_instance.app_server.private_ip
}

output "instance_public_dns" {
  description = "Public DNS name of the EC2 instance"
  value       = aws_instance.app_server.public_dns
}

output "instance_private_dns" {
  description = "Private DNS name of the EC2 instance"
  value       = aws_instance.app_server.private_dns
}

output "availability_zone" {
  description = "Availability zone of the instance"
  value       = aws_instance.app_server.availability_zone
}

# Network Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "subnet_id" {
  description = "ID of the subnet"
  value       = aws_instance.app_server.subnet_id
}

output "security_group_id" {
  description = "ID of the security group"
  value       = aws_security_group.app_sg.id
}

output "security_group_arn" {
  description = "ARN of the security group"
  value       = aws_security_group.app_sg.arn
}

# Key Pair Information
output "key_pair_name" {
  description = "Name of the key pair"
  value       = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name
}

output "key_pair_fingerprint" {
  description = "Fingerprint of the key pair"
  value       = var.create_key_pair ? aws_key_pair.app_key[0].fingerprint : null
}

# AMI Information
output "ami_id" {
  description = "AMI ID used for the instance"
  value       = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
}

output "ami_name" {
  description = "Name of the AMI used"
  value       = var.ami_id != "" ? null : data.aws_ami.ubuntu.name
}

# Elastic IP Information
output "elastic_ip" {
  description = "Elastic IP address (if created)"
  value       = var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : null
}

output "elastic_ip_allocation_id" {
  description = "Allocation ID of the Elastic IP (if created)"
  value       = var.create_elastic_ip ? aws_eip.app_eip[0].allocation_id : null
}

# DNS Information
output "dns_record_fqdn" {
  description = "FQDN of the DNS record (if created)"
  value       = var.create_dns_record ? aws_route53_record.app_dns[0].fqdn : null
}

# Connection Information
output "ssh_connection_command" {
  description = "SSH command to connect to the instance"
  value       = "ssh -i ~/.ssh/${var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name}.pem ubuntu@${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}"
}

output "ssh_config_entry" {
  description = "SSH config entry for the instance"
  value = <<-EOF
Host ${var.project_name}-server
    HostName ${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}
    User ubuntu
    IdentityFile ~/.ssh/${var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name}.pem
    StrictHostKeyChecking no
EOF
}

# Application URLs
output "application_urls" {
  description = "URLs to access the application"
  value = {
    base_url      = "http://${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}"
    main_app      = "http://${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}/"
    admin_panel   = "http://${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}/admin.html"
    api_endpoint  = "http://${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}/api/submissions"
    health_check  = "http://${var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip}/health"
  }
}

# Ansible Inventory Information
output "ansible_inventory" {
  description = "Ansible inventory information"
  value = {
    host                = var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip
    private_ip          = aws_instance.app_server.private_ip
    user                = "ubuntu"
    key_file            = "~/.ssh/${var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name}.pem"
    instance_id         = aws_instance.app_server.id
    availability_zone   = aws_instance.app_server.availability_zone
    instance_type       = aws_instance.app_server.instance_type
    security_group_id   = aws_security_group.app_sg.id
    subnet_id          = aws_instance.app_server.subnet_id
    vpc_id             = local.vpc_id
    groups             = ["three_tier_app", "web_servers", "api_servers", "database_servers"]
  }
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    project_name      = var.project_name
    environment       = var.environment
    region           = var.aws_region
    instance_type    = var.instance_type
    instance_id      = aws_instance.app_server.id
    public_ip        = var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip
    private_ip       = aws_instance.app_server.private_ip
    key_pair_name    = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name
    security_group   = aws_security_group.app_sg.id
    created_at       = timestamp()
  }
}
