# Variables for Week 3: 3-Tier Application with RDS and ALB

# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "ap-southeast-2"
}

variable "availability_zones" {
  description = "List of availability zones"
  type        = list(string)
  default     = ["ap-southeast-2a"]
}

# Project Configuration
variable "project_name" {
  description = "Name of the project"
  type        = string
  default     = "3tier-app"
}

variable "environment" {
  description = "Environment name"
  type        = string
  default     = "dev"
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "3tier-app"
    Environment = "dev"
    ManagedBy   = "Terraform"
    Week        = "3"
  }
}

# Network Configuration
variable "use_existing_vpc" {
  description = "Whether to use an existing VPC"
  type        = bool
  default     = true
}

variable "existing_vpc_id" {
  description = "ID of existing VPC to use"
  type        = string
  default     = ""
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  type        = list(string)
  default     = ["10.100.20.0/24"]
}

variable "admin_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]  # Should be restricted to your IP in production
}

# Database Configuration
variable "db_instance_identifier" {
  description = "Identifier for the RDS instance"
  type        = string
  default     = "formapp-database"
}

variable "db_name" {
  description = "Name of the database"
  type        = string
  default     = "formapp"
}

variable "db_username" {
  description = "Username for the database"
  type        = string
  default     = "admin"
}

variable "db_password" {
  description = "Password for the database"
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.db_password) >= 8
    error_message = "Database password must be at least 8 characters long."
  }
}

variable "db_engine_version" {
  description = "MySQL engine version"
  type        = string
  default     = "8.0.35"
}

variable "db_instance_class" {
  description = "RDS instance class"
  type        = string
  default     = "db.t3.micro"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS instance (GB)"
  type        = number
  default     = 20
}

variable "db_max_allocated_storage" {
  description = "Maximum allocated storage for RDS instance (GB)"
  type        = number
  default     = 100
}

variable "db_storage_type" {
  description = "Storage type for RDS instance"
  type        = string
  default     = "gp2"
}

variable "db_storage_encrypted" {
  description = "Whether to encrypt the RDS instance storage"
  type        = bool
  default     = true
}

variable "db_multi_az" {
  description = "Whether to enable Multi-AZ deployment"
  type        = bool
  default     = false  # Set to true for production
}

variable "db_backup_retention_period" {
  description = "Backup retention period in days"
  type        = number
  default     = 7
}

variable "db_backup_window" {
  description = "Backup window"
  type        = string
  default     = "03:00-04:00"
}

variable "db_maintenance_window" {
  description = "Maintenance window"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "db_monitoring_interval" {
  description = "Enhanced monitoring interval (0 to disable)"
  type        = number
  default     = 60
}

variable "db_performance_insights_enabled" {
  description = "Whether to enable Performance Insights"
  type        = bool
  default     = true
}

variable "db_performance_insights_retention" {
  description = "Performance Insights retention period in days"
  type        = number
  default     = 7
}

variable "db_deletion_protection" {
  description = "Whether to enable deletion protection"
  type        = bool
  default     = false  # Set to true for production
}

variable "db_skip_final_snapshot" {
  description = "Whether to skip final snapshot on deletion"
  type        = bool
  default     = true  # Set to false for production
}

# Application Load Balancer Configuration
variable "alb_name" {
  description = "Name of the Application Load Balancer"
  type        = string
  default     = "3tier-app-alb"
}

variable "alb_deletion_protection" {
  description = "Whether to enable deletion protection for ALB"
  type        = bool
  default     = false  # Set to true for production
}

# Target Group Configuration
variable "target_group_name" {
  description = "Name of the target group"
  type        = string
  default     = "3tier-app-tg"
}

variable "target_group_healthy_threshold" {
  description = "Number of consecutive health checks before considering target healthy"
  type        = number
  default     = 2
}

variable "target_group_unhealthy_threshold" {
  description = "Number of consecutive health checks before considering target unhealthy"
  type        = number
  default     = 2
}

variable "target_group_timeout" {
  description = "Health check timeout in seconds"
  type        = number
  default     = 5
}

variable "target_group_interval" {
  description = "Health check interval in seconds"
  type        = number
  default     = 30
}

variable "target_group_health_check_path" {
  description = "Health check path"
  type        = string
  default     = "/"
}

# Monitoring Configuration
variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "sns_topic_arn" {
  description = "SNS topic ARN for alarms (optional)"
  type        = string
  default     = ""
}

# SSL Configuration (for future use)
variable "ssl_certificate_arn" {
  description = "ARN of SSL certificate for HTTPS listener"
  type        = string
  default     = ""
}

variable "enable_https_listener" {
  description = "Whether to create HTTPS listener"
  type        = bool
  default     = false
}
