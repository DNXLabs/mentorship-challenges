# Outputs for Week 3: 3-Tier Application with RDS and ALB

# Network Information
output "vpc_id" {
  description = "ID of the VPC"
  value       = local.vpc_id
}

output "vpc_cidr" {
  description = "CIDR block of the VPC"
  value       = local.vpc_cidr
}

output "public_subnet_ids" {
  description = "IDs of the public subnets"
  value       = local.public_subnet_ids
}

output "private_subnet_ids" {
  description = "IDs of the private subnets"
  value       = aws_subnet.private[*].id
}

# Security Group Information
output "alb_security_group_id" {
  description = "ID of the ALB security group"
  value       = aws_security_group.alb.id
}

output "ec2_security_group_id" {
  description = "ID of the EC2 security group"
  value       = aws_security_group.ec2.id
}

output "rds_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}

# Database Information
output "rds_endpoint" {
  description = "RDS instance endpoint"
  value       = aws_db_instance.main.endpoint
  sensitive   = true
}

output "rds_port" {
  description = "RDS instance port"
  value       = aws_db_instance.main.port
}

output "rds_instance_id" {
  description = "RDS instance identifier"
  value       = aws_db_instance.main.id
}

output "rds_instance_arn" {
  description = "RDS instance ARN"
  value       = aws_db_instance.main.arn
}

output "db_subnet_group_name" {
  description = "Name of the DB subnet group"
  value       = aws_db_subnet_group.main.name
}

# Load Balancer Information
output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = aws_lb.main.dns_name
}

output "alb_zone_id" {
  description = "Zone ID of the Application Load Balancer"
  value       = aws_lb.main.zone_id
}

output "alb_arn" {
  description = "ARN of the Application Load Balancer"
  value       = aws_lb.main.arn
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_lb_target_group.main.arn
}

# Application URLs
output "application_urls" {
  description = "URLs to access the application"
  value = {
    main_app     = "http://${aws_lb.main.dns_name}/"
    admin_panel  = "http://${aws_lb.main.dns_name}/admin.html"
    api_endpoint = "http://${aws_lb.main.dns_name}/api/submissions"
    health_check = "http://${aws_lb.main.dns_name}${var.target_group_health_check_path}"
  }
}

# Monitoring Information
output "cloudwatch_log_group" {
  description = "CloudWatch log group name"
  value       = aws_cloudwatch_log_group.app_logs.name
}

output "cloudwatch_dashboard_url" {
  description = "URL to the CloudWatch dashboard"
  value       = "https://${var.aws_region}.console.aws.amazon.com/cloudwatch/home?region=${var.aws_region}#dashboards:name=${aws_cloudwatch_dashboard.main.dashboard_name}"
}

# Database Connection Information for Ansible
output "database_config" {
  description = "Database configuration for application"
  value = {
    host     = aws_db_instance.main.endpoint
    port     = aws_db_instance.main.port
    name     = aws_db_instance.main.db_name
    username = aws_db_instance.main.username
  }
  sensitive = true
}

# Ansible Inventory Information
output "ansible_inventory" {
  description = "Information for Ansible inventory"
  value = {
    alb_dns_name          = aws_lb.main.dns_name
    rds_endpoint          = aws_db_instance.main.endpoint
    target_group_arn      = aws_lb_target_group.main.arn
    ec2_security_group_id = aws_security_group.ec2.id
    rds_security_group_id = aws_security_group.rds.id
    vpc_id                = local.vpc_id
    private_subnet_ids    = aws_subnet.private[*].id
    public_subnet_ids     = local.public_subnet_ids
  }
  sensitive = true
}

# Resource Summary
output "resource_summary" {
  description = "Summary of created resources"
  value = {
    project_name         = var.project_name
    environment          = var.environment
    region               = var.aws_region
    vpc_id               = local.vpc_id
    alb_dns_name         = aws_lb.main.dns_name
    rds_endpoint         = aws_db_instance.main.endpoint
    private_subnets      = length(aws_subnet.private)
    created_at           = timestamp()
    estimated_monthly_cost = "~$35-45 (ALB: ~$16, RDS: ~$12, monitoring: ~$5-10)"
  }
}

# Cleanup Information
output "cleanup_info" {
  description = "Information for resource cleanup"
  value = {
    alb_arn              = aws_lb.main.arn
    target_group_arn     = aws_lb_target_group.main.arn
    rds_instance_id      = aws_db_instance.main.id
    db_subnet_group_name = aws_db_subnet_group.main.name
    security_group_ids   = [
      aws_security_group.alb.id,
      aws_security_group.ec2.id,
      aws_security_group.rds.id
    ]
    private_subnet_ids   = aws_subnet.private[*].id
    cloudwatch_alarms    = [
      aws_cloudwatch_metric_alarm.alb_response_time.alarm_name,
      aws_cloudwatch_metric_alarm.rds_cpu.alarm_name
    ]
    cloudwatch_dashboard = aws_cloudwatch_dashboard.main.dashboard_name
    log_group_name       = aws_cloudwatch_log_group.app_logs.name
  }
}
