# Variables for 3-Tier Application Infrastructure

# AWS Configuration
variable "aws_region" {
  description = "AWS region for resources"
  type        = string
  default     = "us-east-1"
}

variable "availability_zones" {
  description = "List of availability zones to use"
  type        = list(string)
  default     = []
}

# Project Configuration
variable "project_name" {
  description = "Name of the project (used for resource naming)"
  type        = string
  default     = "3-tier-app"
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9-]+$", var.project_name))
    error_message = "Project name must contain only alphanumeric characters and hyphens."
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "dev"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: dev, staging, prod."
  }
}

variable "default_tags" {
  description = "Default tags to apply to all resources"
  type        = map(string)
  default = {
    Project     = "3-tier-app"
    Environment = "dev"
    ManagedBy   = "Terraform"
  }
}

# Network Configuration
variable "vpc_id" {
  description = "VPC ID to use (leave empty to use default VPC)"
  type        = string
  default     = ""
}

variable "subnet_id" {
  description = "Subnet ID to use (leave empty to use first available subnet)"
  type        = string
  default     = ""
}

# EC2 Configuration
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
  
  validation {
    condition = contains([
      "t2.micro", "t2.small", "t2.medium", "t2.large",
      "t3.micro", "t3.small", "t3.medium", "t3.large",
      "t3a.micro", "t3a.small", "t3a.medium", "t3a.large",
      "m5.large", "m5.xlarge", "c5.large", "c5.xlarge"
    ], var.instance_type)
    error_message = "Instance type must be a valid EC2 instance type."
  }
}

variable "ami_id" {
  description = "AMI ID to use (leave empty to use latest Ubuntu)"
  type        = string
  default     = ""
}

variable "ami_name_filter" {
  description = "AMI name filter for Ubuntu images"
  type        = string
  default     = "ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"
}

variable "architecture" {
  description = "Instance architecture"
  type        = string
  default     = "x86_64"
  
  validation {
    condition     = contains(["x86_64", "arm64"], var.architecture)
    error_message = "Architecture must be either x86_64 or arm64."
  }
}

# Storage Configuration
variable "root_volume_type" {
  description = "Type of root EBS volume"
  type        = string
  default     = "gp3"
  
  validation {
    condition     = contains(["gp2", "gp3", "io1", "io2"], var.root_volume_type)
    error_message = "Root volume type must be one of: gp2, gp3, io1, io2."
  }
}

variable "root_volume_size" {
  description = "Size of the root EBS volume in GB"
  type        = number
  default     = 20
  
  validation {
    condition     = var.root_volume_size >= 8 && var.root_volume_size <= 1000
    error_message = "Root volume size must be between 8 and 1000 GB."
  }
}

variable "root_volume_iops" {
  description = "IOPS for gp3 volumes"
  type        = number
  default     = 3000
}

variable "root_volume_throughput" {
  description = "Throughput for gp3 volumes (MB/s)"
  type        = number
  default     = 125
}

variable "encrypt_root_volume" {
  description = "Whether to encrypt the root volume"
  type        = bool
  default     = true
}

variable "delete_volume_on_termination" {
  description = "Whether to delete the volume when the instance is terminated"
  type        = bool
  default     = true
}

# SSH Key Configuration
variable "create_key_pair" {
  description = "Whether to create a new key pair"
  type        = bool
  default     = true
}

variable "key_pair_name" {
  description = "Name of the key pair to create or use"
  type        = string
  default     = "3-tier-app-key"
}

variable "existing_key_pair_name" {
  description = "Name of existing key pair to use (when create_key_pair is false)"
  type        = string
  default     = ""
}

variable "public_key_content" {
  description = "Content of the public key for EC2 access"
  type        = string
  default     = ""
  sensitive   = true
}

# Security Configuration
variable "ingress_rules" {
  description = "List of ingress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "SSH"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
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
}

variable "egress_rules" {
  description = "List of egress rules for the security group"
  type = list(object({
    description = string
    from_port   = number
    to_port     = number
    protocol    = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      description = "All outbound traffic"
      from_port   = 0
      to_port     = 0
      protocol    = "-1"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

variable "allowed_ssh_cidr_blocks" {
  description = "CIDR blocks allowed for SSH access"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# Elastic IP Configuration
variable "create_elastic_ip" {
  description = "Whether to create and associate an Elastic IP"
  type        = bool
  default     = false
}

# DNS Configuration
variable "create_dns_record" {
  description = "Whether to create a DNS record"
  type        = bool
  default     = false
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID"
  type        = string
  default     = ""
}

variable "dns_record_name" {
  description = "DNS record name"
  type        = string
  default     = ""
}

variable "dns_record_ttl" {
  description = "DNS record TTL"
  type        = number
  default     = 300
}

# Monitoring Configuration
variable "enable_detailed_monitoring" {
  description = "Enable detailed monitoring for the EC2 instance"
  type        = bool
  default     = false
}

# Instance Metadata Configuration
variable "metadata_http_endpoint" {
  description = "Whether the metadata service is available"
  type        = string
  default     = "enabled"
  
  validation {
    condition     = contains(["enabled", "disabled"], var.metadata_http_endpoint)
    error_message = "Metadata HTTP endpoint must be either enabled or disabled."
  }
}

variable "metadata_http_tokens" {
  description = "Whether metadata service requires session tokens"
  type        = string
  default     = "required"
  
  validation {
    condition     = contains(["optional", "required"], var.metadata_http_tokens)
    error_message = "Metadata HTTP tokens must be either optional or required."
  }
}

# User Data Configuration
variable "user_data_script" {
  description = "Path to user data script template"
  type        = string
  default     = ""
}

variable "user_data_vars" {
  description = "Variables to pass to user data script template"
  type        = map(string)
  default     = {}
}
