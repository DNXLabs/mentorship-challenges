# 3-Tier Application Infrastructure
# This Terraform configuration creates the AWS infrastructure for the 3-tier application
# Based on the EC2 self-hosted deployment guide

terraform {
  required_version = ">= 1.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Configure the AWS Provider
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.default_tags
  }
}

# Data source to get VPC (either default or specified)
data "aws_vpc" "selected" {
  count   = var.vpc_id != "" ? 1 : 0
  id      = var.vpc_id
}

data "aws_vpc" "default" {
  count   = var.vpc_id == "" ? 1 : 0
  default = true
}

locals {
  vpc_id = var.vpc_id != "" ? data.aws_vpc.selected[0].id : data.aws_vpc.default[0].id
}

# Data source to get subnets from the selected VPC
data "aws_subnets" "available" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
}

# Data source to get the latest Ubuntu AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = [var.ami_name_filter]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "architecture"
    values = [var.architecture]
  }
}

# Security Group for the 3-tier application
resource "aws_security_group" "app_sg" {
  name_prefix = "${var.project_name}-sg-"
  description = "Security group for ${var.project_name}"
  vpc_id      = local.vpc_id

  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      description = ingress.value.description
      from_port   = ingress.value.from_port
      to_port     = ingress.value.to_port
      protocol    = ingress.value.protocol
      cidr_blocks = ingress.value.cidr_blocks
    }
  }

  dynamic "egress" {
    for_each = var.egress_rules
    content {
      description = egress.value.description
      from_port   = egress.value.from_port
      to_port     = egress.value.to_port
      protocol    = egress.value.protocol
      cidr_blocks = egress.value.cidr_blocks
    }
  }

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-security-group"
  })
}

# Key Pair for EC2 access (conditional creation)
resource "aws_key_pair" "app_key" {
  count      = var.create_key_pair ? 1 : 0
  key_name   = var.key_pair_name
  public_key = var.public_key_content

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-key-pair"
  })
}

# EC2 Instance for the 3-tier application
resource "aws_instance" "app_server" {
  ami                    = var.ami_id != "" ? var.ami_id : data.aws_ami.ubuntu.id
  instance_type          = var.instance_type
  key_name               = var.create_key_pair ? aws_key_pair.app_key[0].key_name : var.existing_key_pair_name
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  subnet_id              = var.subnet_id != "" ? var.subnet_id : data.aws_subnets.available.ids[0]

  # Root volume configuration
  root_block_device {
    volume_type           = var.root_volume_type
    volume_size           = var.root_volume_size
    encrypted             = var.encrypt_root_volume
    delete_on_termination = var.delete_volume_on_termination
    iops                  = var.root_volume_type == "gp3" ? var.root_volume_iops : null
    throughput            = var.root_volume_type == "gp3" ? var.root_volume_throughput : null

    tags = merge(var.default_tags, {
      Name = "${var.project_name}-root-volume"
    })
  }

  # Enable detailed monitoring
  monitoring = var.enable_detailed_monitoring

  # User data script for initial setup
  user_data = var.user_data_script != "" ? base64encode(templatefile(var.user_data_script, var.user_data_vars)) : null

  # Instance metadata options
  metadata_options {
    http_endpoint = var.metadata_http_endpoint
    http_tokens   = var.metadata_http_tokens
  }

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-server"
  })

  # Ensure the instance is created after the security group
  depends_on = [aws_security_group.app_sg]
}

# Elastic IP for the instance (optional)
resource "aws_eip" "app_eip" {
  count    = var.create_elastic_ip ? 1 : 0
  instance = aws_instance.app_server.id
  domain   = "vpc"

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-eip"
  })

  depends_on = [aws_instance.app_server]
}

# Route53 DNS record (optional)
resource "aws_route53_record" "app_dns" {
  count   = var.create_dns_record ? 1 : 0
  zone_id = var.route53_zone_id
  name    = var.dns_record_name
  type    = "A"
  ttl     = var.dns_record_ttl
  records = [var.create_elastic_ip ? aws_eip.app_eip[0].public_ip : aws_instance.app_server.public_ip]
}
