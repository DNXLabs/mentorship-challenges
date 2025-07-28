# Week 3: 3-Tier Application with RDS and ALB
# This Terraform configuration creates the infrastructure for decoupling the database
# and adding load balancing capabilities

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

# Data source to get existing VPC (from Week 2)
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  id    = var.existing_vpc_id
}

# Data source to get default VPC if no existing VPC specified
data "aws_vpc" "default" {
  count   = var.use_existing_vpc ? 0 : 1
  default = true
}

locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : data.aws_vpc.default[0].id
  vpc_cidr = var.use_existing_vpc ? data.aws_vpc.existing[0].cidr_block : data.aws_vpc.default[0].cidr_block
}

# Data source to get existing subnets
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  filter {
    name   = "availability-zone"
    values = var.availability_zones
  }
  
  # Try to get public subnets first
  filter {
    name   = "tag:Type"
    values = ["Public", "public"]
  }
}

# Fallback to any subnets if no public subnets found
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

locals {
  # Use public subnets if available, otherwise use any available subnets
  public_subnet_ids = length(data.aws_subnets.public.ids) > 0 ? data.aws_subnets.public.ids : slice(data.aws_subnets.available.ids, 0, min(2, length(data.aws_subnets.available.ids)))
}

# Create private subnets for RDS if they don't exist
resource "aws_subnet" "private" {
  count = length(var.private_subnet_cidrs)
  
  vpc_id            = local.vpc_id
  cidr_block        = var.private_subnet_cidrs[count.index]
  availability_zone = var.availability_zones[count.index]
  
  tags = merge(var.default_tags, {
    Name = "${var.project_name}-private-subnet-${count.index + 1}"
    Type = "Private"
  })
}

# Create additional public subnet in ap-southeast-2b for ALB (if needed)
resource "aws_subnet" "public_additional" {
  count = length(data.aws_subnets.public.ids) < 2 ? 1 : 0
  
  vpc_id                  = local.vpc_id
  cidr_block              = "10.100.16.0/24"  # Non-conflicting CIDR
  availability_zone       = "ap-southeast-2b"
  map_public_ip_on_launch = true
  
  tags = merge(var.default_tags, {
    Name = "${var.project_name}-public-subnet-2"
    Type = "Public"
  })
}

# Get internet gateway for the additional public subnet
data "aws_internet_gateway" "existing" {
  filter {
    name   = "attachment.vpc-id"
    values = [local.vpc_id]
  }
}

# Get existing public route table
data "aws_route_tables" "public" {
  vpc_id = local.vpc_id
  
  filter {
    name   = "route.destination-cidr-block"
    values = ["0.0.0.0/0"]
  }
}

# Associate additional public subnet with existing public route table
resource "aws_route_table_association" "public_additional" {
  count = length(aws_subnet.public_additional)
  
  subnet_id      = aws_subnet.public_additional[count.index].id
  route_table_id = data.aws_route_tables.public.ids[0]
}

# Update locals to include the new public subnet
locals {
  # Combine existing public subnets with any new ones we created
  all_public_subnet_ids = concat(
    data.aws_subnets.public.ids,
    aws_subnet.public_additional[*].id
  )
  # Use the combined list for ALB
  alb_subnet_ids = length(local.all_public_subnet_ids) >= 2 ? slice(local.all_public_subnet_ids, 0, 2) : local.all_public_subnet_ids
}

# Create route table for private subnets
resource "aws_route_table" "private" {
  vpc_id = local.vpc_id

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-private-rt"
    Type = "Private"
  })
}

# Associate private subnets with private route table
resource "aws_route_table_association" "private" {
  count = length(aws_subnet.private)
  
  subnet_id      = aws_subnet.private[count.index].id
  route_table_id = aws_route_table.private.id
}

# Security Group for Application Load Balancer
resource "aws_security_group" "alb" {
  name_prefix = "${var.project_name}-alb-sg-"
  description = "Security group for Application Load Balancer"
  vpc_id      = local.vpc_id

  ingress {
    description = "HTTP from internet"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTPS from internet"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name    = "${var.project_name}-alb-sg"
    Purpose = "Load Balancer"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2" {
  name_prefix = "${var.project_name}-ec2-sg-"
  description = "Security group for EC2 instances - allows traffic from ALB and SSH"
  vpc_id      = local.vpc_id

  ingress {
    description     = "HTTP from ALB"
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description     = "API from ALB"
    from_port       = 3000
    to_port         = 3000
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    description = "SSH from admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = var.admin_cidr_blocks
  }

  egress {
    description = "All outbound traffic"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.default_tags, {
    Name    = "${var.project_name}-ec2-sg"
    Purpose = "Web Servers"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group for RDS
resource "aws_security_group" "rds" {
  name_prefix = "${var.project_name}-rds-sg-"
  description = "Security group for RDS database - allows MySQL from EC2 instances only"
  vpc_id      = local.vpc_id

  ingress {
    description     = "MySQL from EC2"
    from_port       = 3306
    to_port         = 3306
    protocol        = "tcp"
    security_groups = [aws_security_group.ec2.id]
  }

  # No egress rules needed for RDS

  tags = merge(var.default_tags, {
    Name    = "${var.project_name}-rds-sg"
    Purpose = "Database"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# DB Subnet Group for RDS
resource "aws_db_subnet_group" "main" {
  name       = "threetierappdbsubnetgroup"  # RDS names must be alphanumeric only
  # Use our new private subnet (ap-southeast-2a) + our new public subnet (ap-southeast-2b) for different AZs
  subnet_ids = [aws_subnet.private[0].id, aws_subnet.public_additional[0].id]

  tags = merge(var.default_tags, {
    Name = "${var.project_name}-db-subnet-group"
  })
}

# RDS MySQL Instance
resource "aws_db_instance" "main" {
  identifier = var.db_instance_identifier

  # Engine configuration
  engine         = "mysql"
  engine_version = var.db_engine_version
  instance_class = var.db_instance_class

  # Database configuration
  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  # Storage configuration
  allocated_storage     = var.db_allocated_storage
  max_allocated_storage = var.db_max_allocated_storage
  storage_type          = var.db_storage_type
  storage_encrypted     = var.db_storage_encrypted

  # Network configuration
  db_subnet_group_name   = aws_db_subnet_group.main.name
  vpc_security_group_ids = [aws_security_group.rds.id]
  publicly_accessible    = false

  # Availability and backup configuration
  availability_zone    = var.availability_zones[0]
  multi_az            = var.db_multi_az
  backup_retention_period = var.db_backup_retention_period
  backup_window       = var.db_backup_window
  maintenance_window  = var.db_maintenance_window

  # Monitoring configuration
  monitoring_interval = var.db_monitoring_interval
  monitoring_role_arn = var.db_monitoring_interval > 0 ? aws_iam_role.rds_monitoring[0].arn : null
  
  performance_insights_enabled          = var.db_performance_insights_enabled
  performance_insights_retention_period = var.db_performance_insights_enabled ? var.db_performance_insights_retention : null

  # Deletion protection
  deletion_protection = var.db_deletion_protection
  skip_final_snapshot = var.db_skip_final_snapshot

  tags = merge(var.default_tags, {
    Name = var.db_instance_identifier
  })

  depends_on = [aws_db_subnet_group.main]
}

# IAM role for RDS monitoring (if monitoring is enabled)
resource "aws_iam_role" "rds_monitoring" {
  count = var.db_monitoring_interval > 0 ? 1 : 0
  
  name = "${var.project_name}-rds-monitoring-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "monitoring.rds.amazonaws.com"
        }
      }
    ]
  })

  tags = var.default_tags
}

resource "aws_iam_role_policy_attachment" "rds_monitoring" {
  count = var.db_monitoring_interval > 0 ? 1 : 0
  
  role       = aws_iam_role.rds_monitoring[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonRDSEnhancedMonitoringRole"
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = var.alb_name
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  # Use existing subnets + our additional public subnet
  subnets            = [data.aws_subnets.available.ids[0], aws_subnet.public_additional[0].id]

  enable_deletion_protection = var.alb_deletion_protection

  tags = merge(var.default_tags, {
    Name = var.alb_name
  })
}

# Target Group for ALB
resource "aws_lb_target_group" "main" {
  name     = var.target_group_name
  port     = 80
  protocol = "HTTP"
  vpc_id   = local.vpc_id

  health_check {
    enabled             = true
    healthy_threshold   = var.target_group_healthy_threshold
    unhealthy_threshold = var.target_group_unhealthy_threshold
    timeout             = var.target_group_timeout
    interval            = var.target_group_interval
    path                = var.target_group_health_check_path
    matcher             = "200"
    port                = "traffic-port"
    protocol            = "HTTP"
  }

  tags = merge(var.default_tags, {
    Name = var.target_group_name
  })
}

# ALB Listener
resource "aws_lb_listener" "main" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }

  tags = var.default_tags
}

# Data source to get existing EC2 instance (from Week 2)
data "aws_instances" "existing" {
  filter {
    name   = "instance-state-name"
    values = ["running"]
  }

  filter {
    name   = "tag:Project"
    values = ["3-tier-app-sydney"]  # Match the actual tag value
  }
}

# Register existing EC2 instance with target group
resource "aws_lb_target_group_attachment" "existing_instance" {
  count = length(data.aws_instances.existing.ids) > 0 ? 1 : 0
  
  target_group_arn = aws_lb_target_group.main.arn
  target_id        = data.aws_instances.existing.ids[0]
  port             = 80
}

# CloudWatch Log Group for application logs
resource "aws_cloudwatch_log_group" "app_logs" {
  name              = "/aws/application/${var.project_name}"
  retention_in_days = var.log_retention_days

  tags = var.default_tags
}

# CloudWatch Alarms
resource "aws_cloudwatch_metric_alarm" "alb_response_time" {
  alarm_name          = "${var.project_name}-alb-high-response-time"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "TargetResponseTime"
  namespace           = "AWS/ApplicationELB"
  period              = "300"
  statistic           = "Average"
  threshold           = "2.0"
  alarm_description   = "This metric monitors ALB response time"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    LoadBalancer = aws_lb.main.arn_suffix
  }

  tags = var.default_tags
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu" {
  alarm_name          = "${var.project_name}-rds-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "2"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = "300"
  statistic           = "Average"
  threshold           = "80"
  alarm_description   = "This metric monitors RDS CPU utilization"
  alarm_actions       = var.sns_topic_arn != "" ? [var.sns_topic_arn] : []

  dimensions = {
    DBInstanceIdentifier = aws_db_instance.main.id
  }

  tags = var.default_tags
}

# CloudWatch Dashboard
resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.project_name}-dashboard"

  dashboard_body = jsonencode({
    widgets = [
      {
        type   = "metric"
        x      = 0
        y      = 0
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", aws_lb.main.arn_suffix],
            [".", "TargetResponseTime", ".", "."],
            [".", "HTTPCode_Target_2XX_Count", ".", "."],
            [".", "HTTPCode_Target_4XX_Count", ".", "."],
            [".", "HTTPCode_Target_5XX_Count", ".", "."]
          ]
          period = 300
          stat   = "Sum"
          region = var.aws_region
          title  = "ALB Metrics"
        }
      },
      {
        type   = "metric"
        x      = 0
        y      = 6
        width  = 12
        height = 6

        properties = {
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", aws_db_instance.main.id],
            [".", "DatabaseConnections", ".", "."],
            [".", "ReadIOPS", ".", "."],
            [".", "WriteIOPS", ".", "."]
          ]
          period = 300
          stat   = "Average"
          region = var.aws_region
          title  = "RDS Metrics"
        }
      }
    ]
  })

  # CloudWatch dashboards don't support tags in this provider version
}
