# AWS EC2 Decoupling and Application Load Balancer Deployment Guide - IMPROVED

## Overview
This guide walks you through evolving your 3-tier application from a single EC2 instance to a decoupled, scalable architecture using Amazon RDS and Application Load Balancer (ALB). You'll transform your monolithic deployment into a robust, production-ready system that can handle growth and provides enhanced security, reliability, and operational efficiency.

> ⚠️ **Important**: This lab creates billable AWS resources. Make sure to follow the **Resource Cleanup** section at the end to avoid unnecessary charges after completing the learning exercise.

## What You'll Build

Building on your existing EC2 deployment, you'll create:
- **Database Tier**: Amazon RDS MySQL instance (managed database service)
- **Application Tier**: Multiple EC2 instances behind an Application Load Balancer
- **Load Balancing**: ALB for intelligent traffic distribution and health checks
- **Security**: Enhanced network isolation with proper security groups and NACLs
- **Monitoring**: CloudWatch integration for application insights

## Architecture Evolution

### Before (Current State)
```
Internet → EC2 Instance (Ubuntu 24.04)
├── Nginx (Port 80) → Static Files + Reverse Proxy
├── Node.js API (Port 3000) → Managed by PM2
└── MySQL (Port 3306) → Local Database
```

### After (Target Architecture)
```
Internet → Application Load Balancer
├── Target Group → Multiple EC2 Instances
│   ├── EC2 Instance 1 (Nginx + Node.js API)
└── Amazon RDS MySQL → Managed Database Service
```

## Prerequisites

### Completed Requirements
- ✅ Completed Stage 1: EC2 Self-Hosted Deployment
- ✅ Working 3-tier application on single EC2 instance
- ✅ Familiarity with AWS Console and basic networking concepts

### AWS Resources Needed
- VPC with public and private subnets
- Internet Gateway and Route Tables
- Security Groups for ALB, EC2, and RDS
- Application Load Balancer
- Amazon RDS MySQL instance
- Additional EC2 instances

### Estimated Costs
- **Application Load Balancer**: ~$16/month + data processing
- **RDS MySQL (db.t3.micro, Single-AZ)**: ~$12/month (Free Tier eligible)
- **Additional EC2 instances**: ~$8.50/month each (Free Tier eligible)
- **Data Transfer**: Minimal for development use
- **Total Estimated**: ~$35-45/month

> **Cost Optimization**: Using Single-AZ RDS reduces costs by ~50% compared to Multi-AZ. In production, Multi-AZ would cost ~$24/month for the same instance class but provides automatic failover capabilities.

## Step 0: Environment Setup and Variable Configuration

### 0.1 Set Up Your Working Environment

Before starting, let's set up a consistent environment with variables that will be used throughout this guide. This ensures consistency and reduces errors.

**Create a working directory and configuration file:**
```bash
# Create a working directory for this lab
mkdir -p ~/3tier-lab-week3
cd ~/3tier-lab-week3

# Create a configuration file to store all our variables
cat > lab-config.sh << 'EOF'
#!/bin/bash
# 3-Tier Application Lab Configuration
# This file contains all variables used throughout the deployment

# AWS Configuration
export AWS_PROFILE="your-profile-name"  # Replace with your AWS profile
export AWS_DEFAULT_REGION="ap-southeast-2"  # Replace with your preferred region

# Project Configuration
export PROJECT_NAME="3tier-app"
export ENVIRONMENT="dev"

# Network Configuration - Customize these ranges if needed
export VPC_CIDR="10.100.0.0/16"
export PUBLIC_SUBNET_1_CIDR="10.100.1.0/24"
export PRIVATE_SUBNET_1_CIDR="10.100.10.0/24"

# Availability Zones - Update these for your region
export AZ_1="${AWS_DEFAULT_REGION}a"
export AZ_2="${AWS_DEFAULT_REGION}b"

# Database Configuration
export DB_INSTANCE_ID="formapp-database"
export DB_NAME="formapp"
export DB_USERNAME="admin"
export DB_APP_USERNAME="formapp_user"
# Note: Passwords will be set interactively for security

# Security Configuration
export SSH_KEY_NAME="mentoring-key"  # Replace with your key pair name

# Resource Names (using consistent naming convention)
export VPC_NAME="${PROJECT_NAME}-vpc"
export IGW_NAME="${PROJECT_NAME}-igw"
export PUBLIC_SUBNET_1_NAME="${PROJECT_NAME}-public-subnet-1"
export PRIVATE_SUBNET_1_NAME="${PROJECT_NAME}-private-subnet-1"
export PUBLIC_RT_NAME="${PROJECT_NAME}-public-rt"
export PRIVATE_RT_NAME="${PROJECT_NAME}-private-rt"
export ALB_SG_NAME="${PROJECT_NAME}-alb-sg"
export EC2_SG_NAME="${PROJECT_NAME}-ec2-sg"
export RDS_SG_NAME="${PROJECT_NAME}-rds-sg"
export DB_SUBNET_GROUP_NAME="${PROJECT_NAME}-db-subnet-group"
export ALB_NAME="${PROJECT_NAME}-alb"
export TARGET_GROUP_NAME="${PROJECT_NAME}-tg"

# File to store resource IDs
export RESOURCE_IDS_FILE="resource-ids.txt"

# Function to save resource IDs
save_resource_id() {
    local resource_type="$1"
    local resource_id="$2"
    echo "export ${resource_type}=${resource_id}" >> "$RESOURCE_IDS_FILE"
    echo "✅ Saved ${resource_type}: ${resource_id}"
}

# Function to load saved resource IDs
load_resource_ids() {
    if [ -f "$RESOURCE_IDS_FILE" ]; then
        source "$RESOURCE_IDS_FILE"
        echo "✅ Loaded saved resource IDs"
    else
        echo "ℹ️  No saved resource IDs found"
    fi
}

# Function to display current configuration
show_config() {
    echo "=== Current Lab Configuration ==="
    echo "AWS Profile: $AWS_PROFILE"
    echo "AWS Region: $AWS_DEFAULT_REGION"
    echo "VPC CIDR: $VPC_CIDR"
    echo "Availability Zones: $AZ_1, $AZ_2"
    echo "Project Name: $PROJECT_NAME"
    echo "Environment: $ENVIRONMENT"
    echo "================================="
}

# Function to validate prerequisites
validate_prerequisites() {
    echo "=== Validating Prerequisites ==="
    
    # Check AWS CLI
    if ! command -v aws &> /dev/null; then
        echo "❌ AWS CLI not found. Please install AWS CLI."
        return 1
    fi
    
    # Check AWS credentials
    if ! aws sts get-caller-identity &> /dev/null; then
        echo "❌ AWS credentials not configured. Please run 'aws configure'."
        return 1
    fi
    
    # Check if key pair exists
    if ! aws ec2 describe-key-pairs --key-names "$SSH_KEY_NAME" &> /dev/null; then
        echo "❌ SSH key pair '$SSH_KEY_NAME' not found. Please update SSH_KEY_NAME in config."
        return 1
    fi
    
    echo "✅ All prerequisites validated"
    return 0
}

# Function to get your current public IP for security group rules
get_my_ip() {
    local my_ip=$(curl -s https://checkip.amazonaws.com)
    if [ -n "$my_ip" ]; then
        echo "$my_ip/32"
    else
        echo "0.0.0.0/0"  # Fallback - less secure
        echo "⚠️  Warning: Could not determine your IP. Using 0.0.0.0/0 (less secure)"
    fi
}

EOF

# Make the configuration file executable
chmod +x lab-config.sh

# Load the configuration
source lab-config.sh

# Display current configuration
show_config

# Validate prerequisites
validate_prerequisites
```

### 0.2 Customize Your Configuration

**Edit the configuration file to match your environment:**
```bash
# Edit the configuration file
nano lab-config.sh

# Update these variables for your environment:
# - AWS_PROFILE: Your AWS profile name
# - AWS_DEFAULT_REGION: Your preferred AWS region
# - SSH_KEY_NAME: Your EC2 key pair name
# - VPC_CIDR and subnet CIDRs if you have conflicts
# - AZ_1 and AZ_2 for your region's availability zones

# After editing, reload the configuration
source lab-config.sh
show_config
```

### 0.3 Verify Your Current Infrastructure

Let's check what infrastructure you already have from Stage 1:

```bash
# Load configuration
source lab-config.sh

# Check existing VPCs
echo "=== Existing VPCs ==="
aws ec2 describe-vpcs \
    --query 'Vpcs[*].[VpcId,CidrBlock,Tags[?Key==`Name`].Value|[0],State]' \
    --output table

# Check existing subnets
echo "=== Existing Subnets ==="
aws ec2 describe-subnets \
    --query 'Subnets[*].[SubnetId,VpcId,CidrBlock,AvailabilityZone,Tags[?Key==`Name`].Value|[0]]' \
    --output table

# Check existing security groups
echo "=== Existing Security Groups ==="
aws ec2 describe-security-groups \
    --query 'SecurityGroups[*].[GroupId,GroupName,Description,VpcId]' \
    --output table

# Check existing instances
echo "=== Existing EC2 Instances ==="
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,State.Name,Tags[?Key==`Name`].Value|[0],PublicIpAddress]' \
    --output table

# Save this information for reference
echo "=== Infrastructure Assessment Complete ==="
echo "Review the output above to understand your current infrastructure."
echo "If you have existing resources, you may need to adjust the configuration."
```

### 0.4 Decision Point: Use Existing or Create New VPC

Based on your current infrastructure, you have two options:

**Option A: Use Existing VPC (Recommended if you have one from Stage 1 / [aka. week 2])**
```bash
# If you have an existing VPC, get its details
EXISTING_VPC_ID=$(aws ec2 describe-vpcs \
    --filters "Name=is-default,Values=false" \
    --query 'Vpcs[0].VpcId' \
    --output text 2>/dev/null)

if [ "$EXISTING_VPC_ID" != "None" ] && [ -n "$EXISTING_VPC_ID" ]; then
    echo "Found existing VPC: $EXISTING_VPC_ID"
    save_resource_id "VPC_ID" "$EXISTING_VPC_ID"
    
    # Get existing VPC CIDR
    EXISTING_VPC_CIDR=$(aws ec2 describe-vpcs \
        --vpc-ids "$EXISTING_VPC_ID" \
        --query 'Vpcs[0].CidrBlock' \
        --output text)
    echo "Existing VPC CIDR: $EXISTING_VPC_CIDR"
    
    # Update configuration if needed
    if [ "$EXISTING_VPC_CIDR" != "$VPC_CIDR" ]; then
        echo "⚠️  VPC CIDR mismatch. Consider updating your configuration."
        echo "Existing: $EXISTING_VPC_CIDR, Configured: $VPC_CIDR"
    fi
else
    echo "No existing VPC found. Will create new VPC."
fi
```

**Option B: Create New VPC (Skip to Step 1 if choosing this option)**

Now let's proceed with the improved step-by-step guide.

## Step 1: Network Infrastructure Setup

### 1.1 Load Configuration and Check Prerequisites

```bash
# Always start by loading your configuration
cd ~/3tier-lab-week3
source lab-config.sh
load_resource_ids

# Validate prerequisites
validate_prerequisites

# Show current configuration
show_config
```

### 1.2 Create VPC (If You Don't Have One)

**Using AWS CLI with Variables:**
```bash
# Create VPC
echo "Creating VPC with CIDR: $VPC_CIDR"
VPC_ID=$(aws ec2 create-vpc \
    --cidr-block "$VPC_CIDR" \
    --query 'Vpc.VpcId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "VPC_ID" "$VPC_ID"
    echo "✅ Created VPC: $VPC_ID"
    
    # Tag the VPC
    aws ec2 create-tags \
        --resources "$VPC_ID" \
        --tags Key=Name,Value="$VPC_NAME" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT"
    
    # Enable DNS hostnames and resolution
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-hostnames
    aws ec2 modify-vpc-attribute --vpc-id "$VPC_ID" --enable-dns-support
    echo "✅ Enabled DNS hostnames and resolution"
else
    echo "❌ Failed to create VPC"
    exit 1
fi

# Create Internet Gateway
echo "Creating Internet Gateway..."
IGW_ID=$(aws ec2 create-internet-gateway \
    --query 'InternetGateway.InternetGatewayId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "IGW_ID" "$IGW_ID"
    echo "✅ Created Internet Gateway: $IGW_ID"
    
    # Tag the Internet Gateway
    aws ec2 create-tags \
        --resources "$IGW_ID" \
        --tags Key=Name,Value="$IGW_NAME" Key=Project,Value="$PROJECT_NAME"
    
    # Attach Internet Gateway to VPC
    aws ec2 attach-internet-gateway \
        --internet-gateway-id "$IGW_ID" \
        --vpc-id "$VPC_ID"
    echo "✅ Attached Internet Gateway to VPC"
else
    echo "❌ Failed to create Internet Gateway"
    exit 1
fi
```

**Using AWS Console:**
1. **Navigate to VPC Console → Create VPC**
2. **VPC Settings**:
   - **Resources to create**: VPC only
   - **Name**: Use the value from `$VPC_NAME` (e.g., `3tier-app-vpc`)
   - **IPv4 CIDR**: Use the value from `$VPC_CIDR` (e.g., `10.100.0.0/16`)
   - **IPv6 CIDR**: No IPv6 CIDR block
   - **Tenancy**: Default
3. **Create VPC**
4. **Create Internet Gateway**:
   - Navigate to **Internet Gateways → Create Internet Gateway**
   - **Name**: Use the value from `$IGW_NAME` (e.g., `3tier-app-igw`)
   - **Actions → Attach to VPC** → Select your VPC

### 1.3 Create Required Subnets

For this architecture, we need:
- **2 Public Subnets** (different AZs) for ALB high availability
- **2 Private Subnets** (different AZs) for RDS subnet group requirement

**Using AWS CLI with Variables:**
```bash
# Load configuration if not already loaded
source lab-config.sh
load_resource_ids

# Verify we have VPC_ID
if [ -z "$VPC_ID" ]; then
    echo "❌ VPC_ID not found. Please run VPC creation first."
    exit 1
fi

echo "Creating subnets in VPC: $VPC_ID"

# Create Public Subnet 1
echo "Creating Public Subnet 1 in $AZ_1..."
PUBLIC_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PUBLIC_SUBNET_1_CIDR" \
    --availability-zone "$AZ_1" \
    --query 'Subnet.SubnetId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "PUBLIC_SUBNET_1" "$PUBLIC_SUBNET_1"
    echo "✅ Created Public Subnet 1: $PUBLIC_SUBNET_1"
    
    # Tag and enable auto-assign public IP
    aws ec2 create-tags \
        --resources "$PUBLIC_SUBNET_1" \
        --tags Key=Name,Value="$PUBLIC_SUBNET_1_NAME" Key=Type,Value=Public Key=Project,Value="$PROJECT_NAME"
    
    aws ec2 modify-subnet-attribute \
        --subnet-id "$PUBLIC_SUBNET_1" \
        --map-public-ip-on-launch
    echo "✅ Enabled auto-assign public IP for Public Subnet 1"
else
    echo "❌ Failed to create Public Subnet 1"
    exit 1
fi

# Create Private Subnet 1
echo "Creating Private Subnet 1 in $AZ_1..."
PRIVATE_SUBNET_1=$(aws ec2 create-subnet \
    --vpc-id "$VPC_ID" \
    --cidr-block "$PRIVATE_SUBNET_1_CIDR" \
    --availability-zone "$AZ_1" \
    --query 'Subnet.SubnetId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "PRIVATE_SUBNET_1" "$PRIVATE_SUBNET_1"
    echo "✅ Created Private Subnet 1: $PRIVATE_SUBNET_1"
    
    # Tag the subnet
    aws ec2 create-tags \
        --resources "$PRIVATE_SUBNET_1" \
        --tags Key=Name,Value="$PRIVATE_SUBNET_1_NAME" Key=Type,Value=Private Key=Project,Value="$PROJECT_NAME"
else
    echo "❌ Failed to create Private Subnet 1"
    exit 1
fi

# Display subnet summary
echo "=== Subnet Creation Summary ==="
echo "Public Subnet 1: $PUBLIC_SUBNET_1 ($PUBLIC_SUBNET_1_CIDR) in $AZ_1"
echo "Private Subnet 1: $PRIVATE_SUBNET_1 ($PRIVATE_SUBNET_1_CIDR) in $AZ_1"

```

**Using AWS Console:**
1. **Navigate to VPC Console → Subnets → Create Subnet**
2. **Create Public Subnet 1**:
   - **VPC**: Select your VPC
   - **Subnet Name**: Use value from `$PUBLIC_SUBNET_1_NAME` (e.g., `3tier-app-public-subnet-1`)
   - **Availability Zone**: Use value from `$AZ_1` (e.g., `ap-southeast-2a`)
   - **IPv4 CIDR**: Use value from `$PUBLIC_SUBNET_1_CIDR` (e.g., `10.100.1.0/24`)
3. **Create Private Subnet 1**:
   - **Subnet Name**: Use value from `$PRIVATE_SUBNET_1_NAME`
   - **Availability Zone**: Same as Public Subnet 1 (`$AZ_1`)
   - **IPv4 CIDR**: Use value from `$PRIVATE_SUBNET_1_CIDR`
4. **Enable Auto-assign Public IP**:
   - Select each public subnet → **Actions → Edit subnet settings**
   - Check **Enable auto-assign public IPv4 address**

### 1.4 Configure Route Tables

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Verify required variables
if [ -z "$VPC_ID" ] || [ -z "$IGW_ID" ]; then
    echo "❌ Missing VPC_ID or IGW_ID. Please run previous steps first."
    exit 1
fi

# Get the main route table ID
MAIN_RT=$(aws ec2 describe-route-tables \
    --filters "Name=vpc-id,Values=$VPC_ID" "Name=association.main,Values=true" \
    --query 'RouteTables[0].RouteTableId' \
    --output text)

if [ "$MAIN_RT" != "None" ]; then
    save_resource_id "MAIN_RT" "$MAIN_RT"
    echo "✅ Found main route table: $MAIN_RT"
else
    echo "❌ Could not find main route table"
    exit 1
fi

# Create public route table
echo "Creating public route table..."
PUBLIC_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query 'RouteTable.RouteTableId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "PUBLIC_RT" "$PUBLIC_RT"
    echo "✅ Created public route table: $PUBLIC_RT"
    
    # Tag the public route table
    aws ec2 create-tags \
        --resources "$PUBLIC_RT" \
        --tags Key=Name,Value="$PUBLIC_RT_NAME" Key=Type,Value=Public Key=Project,Value="$PROJECT_NAME"
    
    # Add route to Internet Gateway
    aws ec2 create-route \
        --route-table-id "$PUBLIC_RT" \
        --destination-cidr-block 0.0.0.0/0 \
        --gateway-id "$IGW_ID"
    echo "✅ Added internet route to public route table"
    
    # Associate public subnets with public route table
    aws ec2 associate-route-table \
        --subnet-id "$PUBLIC_SUBNET_1" \
        --route-table-id "$PUBLIC_RT"
    echo "✅ Associated public subnets with public route table"
else
    echo "❌ Failed to create public route table"
    exit 1
fi

# Create private route table
echo "Creating private route table..."
PRIVATE_RT=$(aws ec2 create-route-table \
    --vpc-id "$VPC_ID" \
    --query 'RouteTable.RouteTableId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "PRIVATE_RT" "$PRIVATE_RT"
    echo "✅ Created private route table: $PRIVATE_RT"
    
    # Tag the private route table
    aws ec2 create-tags \
        --resources "$PRIVATE_RT" \
        --tags Key=Name,Value="$PRIVATE_RT_NAME" Key=Type,Value=Private Key=Project,Value="$PROJECT_NAME"
    
    # Associate private subnets with private route table
    aws ec2 associate-route-table \
        --subnet-id "$PRIVATE_SUBNET_1" \
        --route-table-id "$PRIVATE_RT"
    
    echo "✅ Associated private subnets with private route table"
else
    echo "❌ Failed to create private route table"
    exit 1
fi

# Display route table summary
echo "=== Route Table Configuration Summary ==="
echo "Main Route Table: $MAIN_RT"
echo "Public Route Table: $PUBLIC_RT (with internet gateway route)"
echo "Private Route Table: $PRIVATE_RT (no internet access)"
```

### 1.5 Create Security Groups with Clear Rules

> **🔒 Security Best Practice**: We'll create three security groups with specific purposes and use security group references instead of IP addresses for internal communication.

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Get your current public IP for SSH access
MY_IP=$(get_my_ip)
echo "Your current public IP: $MY_IP"

# Create ALB Security Group
echo "Creating ALB Security Group..."
ALB_SG=$(aws ec2 create-security-group \
    --group-name "$ALB_SG_NAME" \
    --description "Security group for Application Load Balancer - allows HTTP/HTTPS from internet" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "ALB_SG" "$ALB_SG"
    echo "✅ Created ALB Security Group: $ALB_SG"
    
    # Tag the security group
    aws ec2 create-tags \
        --resources "$ALB_SG" \
        --tags Key=Name,Value="$ALB_SG_NAME" Key=Purpose,Value="Load Balancer" Key=Project,Value="$PROJECT_NAME"
    
    # Add inbound rules to ALB Security Group
    echo "Adding inbound rules to ALB Security Group..."
    
    # HTTP from anywhere
    aws ec2 authorize-security-group-ingress \
        --group-id "$ALB_SG" \
        --protocol tcp \
        --port 80 \
        --cidr 0.0.0.0/0 \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-from-internet}]'
    
    # HTTPS from anywhere (optional but recommended)
    aws ec2 authorize-security-group-ingress \
        --group-id "$ALB_SG" \
        --protocol tcp \
        --port 443 \
        --cidr 0.0.0.0/0 \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTPS-from-internet}]'
    
    echo "✅ Added HTTP and HTTPS inbound rules to ALB Security Group"
else
    echo "❌ Failed to create ALB Security Group"
    exit 1
fi

# Create EC2 Security Group
echo "Creating EC2 Security Group..."
EC2_SG=$(aws ec2 create-security-group \
    --group-name "$EC2_SG_NAME" \
    --description "Security group for EC2 instances - allows traffic from ALB and SSH from admin" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "EC2_SG" "$EC2_SG"
    echo "✅ Created EC2 Security Group: $EC2_SG"
    
    # Tag the security group
    aws ec2 create-tags \
        --resources "$EC2_SG" \
        --tags Key=Name,Value="$EC2_SG_NAME" Key=Purpose,Value="Web Servers" Key=Project,Value="$PROJECT_NAME"
    
    # Add inbound rules to EC2 Security Group
    echo "Adding inbound rules to EC2 Security Group..."
    
    # HTTP from ALB only
    aws ec2 authorize-security-group-ingress \
        --group-id "$EC2_SG" \
        --protocol tcp \
        --port 80 \
        --source-group "$ALB_SG" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=HTTP-from-ALB}]'
    
    # API port from ALB only
    aws ec2 authorize-security-group-ingress \
        --group-id "$EC2_SG" \
        --protocol tcp \
        --port 3000 \
        --source-group "$ALB_SG" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=API-from-ALB}]'
    
    # SSH from your IP only
    aws ec2 authorize-security-group-ingress \
        --group-id "$EC2_SG" \
        --protocol tcp \
        --port 22 \
        --cidr "$MY_IP" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=SSH-from-admin}]'
    
    echo "✅ Added HTTP, API, and SSH inbound rules to EC2 Security Group"
else
    echo "❌ Failed to create EC2 Security Group"
    exit 1
fi

# Create RDS Security Group
echo "Creating RDS Security Group..."
RDS_SG=$(aws ec2 create-security-group \
    --group-name "$RDS_SG_NAME" \
    --description "Security group for RDS database - allows MySQL from EC2 instances only" \
    --vpc-id "$VPC_ID" \
    --query 'GroupId' \
    --output text)

if [ $? -eq 0 ]; then
    save_resource_id "RDS_SG" "$RDS_SG"
    echo "✅ Created RDS Security Group: $RDS_SG"
    
    # Tag the security group
    aws ec2 create-tags \
        --resources "$RDS_SG" \
        --tags Key=Name,Value="$RDS_SG_NAME" Key=Purpose,Value="Database" Key=Project,Value="$PROJECT_NAME"
    
    # Add inbound rule to RDS Security Group (MySQL from EC2 only)
    echo "Adding MySQL inbound rule to RDS Security Group..."
    aws ec2 authorize-security-group-ingress \
        --group-id "$RDS_SG" \
        --protocol tcp \
        --port 3306 \
        --source-group "$EC2_SG" \
        --tag-specifications 'ResourceType=security-group-rule,Tags=[{Key=Name,Value=MySQL-from-EC2}]'
    
    echo "✅ Added MySQL inbound rule to RDS Security Group"
    
    # Remove default outbound rule (RDS doesn't need outbound access)
    DEFAULT_OUTBOUND_RULE=$(aws ec2 describe-security-groups \
        --group-ids "$RDS_SG" \
        --query 'SecurityGroups[0].IpPermissionsEgress[0].IpRanges[0].CidrIp' \
        --output text 2>/dev/null)
    
    if [ "$DEFAULT_OUTBOUND_RULE" = "0.0.0.0/0" ]; then
        aws ec2 revoke-security-group-egress \
            --group-id "$RDS_SG" \
            --protocol -1 \
            --cidr 0.0.0.0/0 2>/dev/null || echo "ℹ️  Default outbound rule already removed or doesn't exist"
        echo "✅ Removed default outbound rule from RDS Security Group"
    fi
else
    echo "❌ Failed to create RDS Security Group"
    exit 1
fi

# Display security group summary
echo "=== Security Group Configuration Summary ==="
echo "ALB Security Group: $ALB_SG"
echo "  - Inbound: HTTP (80) and HTTPS (443) from 0.0.0.0/0"
echo "  - Outbound: All traffic (default)"
echo ""
echo "EC2 Security Group: $EC2_SG"
echo "  - Inbound: HTTP (80) from ALB SG, API (3000) from ALB SG, SSH (22) from $MY_IP"
echo "  - Outbound: All traffic (default)"
echo ""
echo "RDS Security Group: $RDS_SG"
echo "  - Inbound: MySQL (3306) from EC2 SG"
echo "  - Outbound: None (removed default)"
```

**Using AWS Console:**
Navigate to **EC2 Console → Security Groups** and create the following security groups:

**1. ALB Security Group**:
- **Create Security Group**
- **Security Group Name**: Use value from `$ALB_SG_NAME` (e.g., `3tier-app-alb-sg`)
- **Description**: `Security group for Application Load Balancer - allows HTTP/HTTPS from internet`
- **VPC**: Select your VPC
- **Inbound Rules**:
  - **Type**: HTTP, **Port**: 80, **Source**: 0.0.0.0/0, **Description**: HTTP from internet
  - **Type**: HTTPS, **Port**: 443, **Source**: 0.0.0.0/0, **Description**: HTTPS from internet
- **Outbound Rules**: Leave default (All traffic to 0.0.0.0/0)

**2. EC2 Security Group**:
- **Security Group Name**: Use value from `$EC2_SG_NAME` (e.g., `3tier-app-ec2-sg`)
- **Description**: `Security group for EC2 instances - allows traffic from ALB and SSH from admin`
- **VPC**: Select your VPC
- **Inbound Rules**:
  - **Type**: HTTP, **Port**: 80, **Source**: Select ALB Security Group, **Description**: HTTP from ALB
  - **Type**: Custom TCP, **Port**: 3000, **Source**: Select ALB Security Group, **Description**: API from ALB
  - **Type**: SSH, **Port**: 22, **Source**: My IP (automatically detects), **Description**: SSH from admin
- **Outbound Rules**: Leave default

**3. RDS Security Group**:
- **Security Group Name**: Use value from `$RDS_SG_NAME` (e.g., `3tier-app-rds-sg`)
- **Description**: `Security group for RDS database - allows MySQL from EC2 instances only`
- **VPC**: Select your VPC
- **Inbound Rules**:
  - **Type**: MySQL/Aurora, **Port**: 3306, **Source**: Select EC2 Security Group, **Description**: MySQL from EC2
- **Outbound Rules**: Remove all (not needed for RDS)

> **🔒 Security Explanation**: 
> - **ALB SG**: Only allows HTTP/HTTPS from the internet
> - **EC2 SG**: Only allows traffic from ALB (not direct internet access) + SSH from your IP
> - **RDS SG**: Only allows MySQL from EC2 instances (complete isolation from internet)
> - Using security group references instead of IP ranges creates dynamic, scalable security rules
### 1.6 Configure Network ACLs (Critical for Database Connectivity)

> ⚠️ **Critical Step**: Network ACLs (NACLs) are stateless and require explicit inbound AND outbound rules. This step is essential for RDS connectivity and is often the cause of connection timeouts.

**Understanding Network ACLs vs Security Groups:**
- **Security Groups**: Stateful (return traffic automatically allowed)
- **Network ACLs**: Stateless (must explicitly allow both directions)
- **Default Behavior**: Most default NACLs allow all traffic, but custom NACLs may be restrictive

#### 1.6.1 Identify and Analyze Current Network ACLs

```bash
# Load configuration
source lab-config.sh
load_resource_ids

echo "=== Analyzing Network ACL Configuration ==="

# Get Network ACL for private subnets (where RDS will reside)
PRIVATE_NACL_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PRIVATE_SUBNET_1" \
    --query 'NetworkAcls[0].NetworkAclId' \
    --output text)

if [ "$PRIVATE_NACL_ID" != "None" ]; then
    save_resource_id "PRIVATE_NACL_ID" "$PRIVATE_NACL_ID"
    echo "✅ Found Private Network ACL: $PRIVATE_NACL_ID"
else
    echo "❌ Could not find private subnet Network ACL"
    exit 1
fi

# Get Network ACL for public subnets (where EC2 will reside)
PUBLIC_NACL_ID=$(aws ec2 describe-network-acls \
    --filters "Name=association.subnet-id,Values=$PUBLIC_SUBNET_1" \
    --query 'NetworkAcls[0].NetworkAclId' \
    --output text)

if [ "$PUBLIC_NACL_ID" != "None" ]; then
    save_resource_id "PUBLIC_NACL_ID" "$PUBLIC_NACL_ID"
    echo "✅ Found Public Network ACL: $PUBLIC_NACL_ID"
else
    echo "❌ Could not find public subnet Network ACL"
    exit 1
fi

# Check if they're the same (using default VPC NACL)
if [ "$PRIVATE_NACL_ID" = "$PUBLIC_NACL_ID" ]; then
    echo "ℹ️  Both subnets use the same Network ACL (likely default VPC NACL)"
    echo "This is normal for simple VPC setups."
fi

# Display current NACL rules
echo "=== Current Private Subnet NACL Rules ==="
aws ec2 describe-network-acls \
    --network-acl-ids "$PRIVATE_NACL_ID" \
    --query 'NetworkAcls[0].Entries[?Protocol==`6`].[RuleNumber,Egress,RuleAction,CidrBlock,PortRange.From,PortRange.To]' \
    --output table

echo "=== Current Public Subnet NACL Rules ==="
aws ec2 describe-network-acls \
    --network-acl-ids "$PUBLIC_NACL_ID" \
    --query 'NetworkAcls[0].Entries[?Protocol==`6`].[RuleNumber,Egress,RuleAction,CidrBlock,PortRange.From,PortRange.To]' \
    --output table
```

#### 1.6.2 Check if NACL Rules Need to be Added

```bash
# Function to check if a NACL rule exists
check_nacl_rule() {
    local nacl_id="$1"
    local port="$2"
    local egress="$3"
    local cidr="$4"
    
    local rule_exists=$(aws ec2 describe-network-acls \
        --network-acl-ids "$nacl_id" \
        --query "NetworkAcls[0].Entries[?Protocol==\`6\` && PortRange.From==\`$port\` && Egress==\`$egress\` && CidrBlock==\`$cidr\`]" \
        --output text)
    
    if [ -n "$rule_exists" ]; then
        return 0  # Rule exists
    else
        return 1  # Rule doesn't exist
    fi
}

# Function to find next available rule number
find_next_rule_number() {
    local nacl_id="$1"
    local egress="$2"
    local start_number="$3"
    
    for i in $(seq $start_number 200); do
        local rule_exists=$(aws ec2 describe-network-acls \
            --network-acl-ids "$nacl_id" \
            --query "NetworkAcls[0].Entries[?RuleNumber==\`$i\` && Egress==\`$egress\`]" \
            --output text)
        
        if [ -z "$rule_exists" ]; then
            echo "$i"
            return
        fi
    done
    
    echo "999"  # Fallback
}

echo "=== Checking Required NACL Rules ==="

# Check if MySQL rules exist for private subnet NACL
if check_nacl_rule "$PRIVATE_NACL_ID" "3306" "false" "$VPC_CIDR"; then
    echo "✅ MySQL inbound rule already exists in private NACL"
else
    echo "⚠️  MySQL inbound rule missing in private NACL - will add"
    NEED_PRIVATE_MYSQL_IN=true
fi

if check_nacl_rule "$PRIVATE_NACL_ID" "1024" "true" "$VPC_CIDR"; then
    echo "✅ Ephemeral outbound rule already exists in private NACL"
else
    echo "⚠️  Ephemeral outbound rule missing in private NACL - will add"
    NEED_PRIVATE_EPHEMERAL_OUT=true
fi

# Check if MySQL rules exist for public subnet NACL (if different)
if [ "$PUBLIC_NACL_ID" != "$PRIVATE_NACL_ID" ]; then
    if check_nacl_rule "$PUBLIC_NACL_ID" "3306" "true" "$PRIVATE_SUBNET_1_CIDR"; then
        echo "✅ MySQL outbound rule already exists in public NACL"
    else
        echo "⚠️  MySQL outbound rule missing in public NACL - will add"
        NEED_PUBLIC_MYSQL_OUT=true
    fi
    
    if check_nacl_rule "$PUBLIC_NACL_ID" "1024" "false" "$PRIVATE_SUBNET_1_CIDR"; then
        echo "✅ Ephemeral inbound rule already exists in public NACL"
    else
        echo "⚠️  Ephemeral inbound rule missing in public NACL - will add"
        NEED_PUBLIC_EPHEMERAL_IN=true
    fi
fi
```

#### 1.6.3 Add Required NACL Rules (Only if Needed)

```bash
echo "=== Adding Required NACL Rules ==="

# Add rules to private subnet NACL (for RDS)
if [ "$NEED_PRIVATE_MYSQL_IN" = true ]; then
    RULE_NUM=$(find_next_rule_number "$PRIVATE_NACL_ID" "false" "110")
    echo "Adding MySQL inbound rule to private NACL (rule number: $RULE_NUM)..."
    
    aws ec2 create-network-acl-entry \
        --network-acl-id "$PRIVATE_NACL_ID" \
        --rule-number "$RULE_NUM" \
        --protocol tcp \
        --port-range From=3306,To=3306 \
        --cidr-block "$VPC_CIDR" \
        --rule-action allow
    
    if [ $? -eq 0 ]; then
        echo "✅ Added MySQL inbound rule (3306) to private NACL"
    else
        echo "❌ Failed to add MySQL inbound rule to private NACL"
    fi
fi

if [ "$NEED_PRIVATE_EPHEMERAL_OUT" = true ]; then
    RULE_NUM=$(find_next_rule_number "$PRIVATE_NACL_ID" "true" "110")
    echo "Adding ephemeral outbound rule to private NACL (rule number: $RULE_NUM)..."
    
    aws ec2 create-network-acl-entry \
        --network-acl-id "$PRIVATE_NACL_ID" \
        --rule-number "$RULE_NUM" \
        --protocol tcp \
        --port-range From=1024,To=65535 \
        --cidr-block "$VPC_CIDR" \
        --rule-action allow \
        --egress
    
    if [ $? -eq 0 ]; then
        echo "✅ Added ephemeral outbound rule (1024-65535) to private NACL"
    else
        echo "❌ Failed to add ephemeral outbound rule to private NACL"
    fi
fi

# Add rules to public subnet NACL (for EC2) if different from private
if [ "$PUBLIC_NACL_ID" != "$PRIVATE_NACL_ID" ]; then
    if [ "$NEED_PUBLIC_MYSQL_OUT" = true ]; then
        RULE_NUM=$(find_next_rule_number "$PUBLIC_NACL_ID" "true" "120")
        echo "Adding MySQL outbound rule to public NACL (rule number: $RULE_NUM)..."
        
        # Calculate private subnet CIDR range (covers both private subnets)
        PRIVATE_CIDR_RANGE="10.100.10.0/23"  # Covers 10.100.10.0/24 and 10.100.11.0/24
        
        aws ec2 create-network-acl-entry \
            --network-acl-id "$PUBLIC_NACL_ID" \
            --rule-number "$RULE_NUM" \
            --protocol tcp \
            --port-range From=3306,To=3306 \
            --cidr-block "$PRIVATE_CIDR_RANGE" \
            --rule-action allow \
            --egress
        
        if [ $? -eq 0 ]; then
            echo "✅ Added MySQL outbound rule (3306) to public NACL"
        else
            echo "❌ Failed to add MySQL outbound rule to public NACL"
        fi
    fi
    
    if [ "$NEED_PUBLIC_EPHEMERAL_IN" = true ]; then
        RULE_NUM=$(find_next_rule_number "$PUBLIC_NACL_ID" "false" "120")
        echo "Adding ephemeral inbound rule to public NACL (rule number: $RULE_NUM)..."
        
        aws ec2 create-network-acl-entry \
            --network-acl-id "$PUBLIC_NACL_ID" \
            --rule-number "$RULE_NUM" \
            --protocol tcp \
            --port-range From=1024,To=65535 \
            --cidr-block "$PRIVATE_CIDR_RANGE" \
            --rule-action allow
        
        if [ $? -eq 0 ]; then
            echo "✅ Added ephemeral inbound rule (1024-65535) to public NACL"
        else
            echo "❌ Failed to add ephemeral inbound rule to public NACL"
        fi
    fi
fi

echo "=== NACL Configuration Complete ==="
```

#### 1.6.4 Verify NACL Configuration

```bash
echo "=== Final NACL Configuration ==="

echo "Private Subnet NACL ($PRIVATE_NACL_ID) - TCP Rules:"
aws ec2 describe-network-acls \
    --network-acl-ids "$PRIVATE_NACL_ID" \
    --query 'NetworkAcls[0].Entries[?Protocol==`6`].[RuleNumber,Egress,RuleAction,CidrBlock,PortRange.From,PortRange.To]' \
    --output table

if [ "$PUBLIC_NACL_ID" != "$PRIVATE_NACL_ID" ]; then
    echo "Public Subnet NACL ($PUBLIC_NACL_ID) - TCP Rules:"
    aws ec2 describe-network-acls \
        --network-acl-ids "$PUBLIC_NACL_ID" \
        --query 'NetworkAcls[0].Entries[?Protocol==`6`].[RuleNumber,Egress,RuleAction,CidrBlock,PortRange.From,PortRange.To]' \
        --output table
fi

echo "✅ NACL configuration verified"
```

**Using AWS Console:**
1. **Navigate to VPC Console → Network ACLs**
2. **Find the NACL associated with your private subnets**
3. **Check Inbound Rules** - ensure there's a rule allowing:
   - **Type**: MySQL/Aurora (3306)
   - **Source**: Your VPC CIDR (e.g., 10.100.0.0/16)
   - **Allow/Deny**: Allow
4. **Check Outbound Rules** - ensure there's a rule allowing:
   - **Type**: Custom TCP
   - **Port Range**: 1024-65535
   - **Destination**: Your VPC CIDR
   - **Allow/Deny**: Allow
5. **If rules are missing, add them with rule numbers that don't conflict**

> **🔍 NACL Troubleshooting Tips:**
> - Rule numbers determine precedence (lower numbers processed first)
> - DENY rules with lower numbers will block ALLOW rules with higher numbers
> - Default VPC NACLs usually allow all traffic (rules 100 and *)
> - Custom NACLs start with DENY all, requiring explicit ALLOW rules
> - Always test connectivity after NACL changes

## Step 2: Amazon RDS Setup

### 2.1 Create RDS Subnet Group

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Verify we have the required subnet IDs
if [ -z "$PRIVATE_SUBNET_1" ]; then
    echo "❌ Private subnet IDs not found. Please run subnet creation first."
    exit 1
fi

echo "Creating RDS DB Subnet Group..."
echo "Using subnets: $PRIVATE_SUBNET_1"

# Create DB subnet group 
aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Subnet group for $PROJECT_NAME database in private subnets" \
    --subnet-ids "$PRIVATE_SUBNET_1" \
    --tags Key=Name,Value="$DB_SUBNET_GROUP_NAME" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT"

if [ $? -eq 0 ]; then
    echo "✅ Created DB Subnet Group: $DB_SUBNET_GROUP_NAME"
    
    # Verify creation and display details
    echo "=== DB Subnet Group Details ==="
    aws rds describe-db-subnet-groups \
        --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
        --query 'DBSubnetGroups[0].[DBSubnetGroupName,VpcId,SubnetGroupStatus,Subnets[*].[SubnetIdentifier,SubnetAvailabilityZone.Name]]' \
        --output table
else
    echo "❌ Failed to create DB Subnet Group"
    exit 1
fi
```

**Using AWS Console:**
1. **Navigate to RDS Console → Subnet Groups**
2. **Create DB Subnet Group**:
   - **Name**: Use value from `$DB_SUBNET_GROUP_NAME` (e.g., `3tier-app-db-subnet-group`)
   - **Description**: `Subnet group for 3tier-app database in private subnets`
   - **VPC**: Select your VPC
   - **Availability Zones**: Select both AZs where your private subnets are located
   - **Subnets**: Select both private subnets
3. **Create**

### 2.2 Set Database Passwords Securely

```bash
# Set database passwords securely (not stored in files)
echo "=== Database Password Configuration ==="
echo "You need to set passwords for:"
echo "1. RDS Admin User ($DB_USERNAME)"
echo "2. Application User ($DB_APP_USERNAME)"
echo ""

# Get admin password
echo -n "Enter password for RDS admin user ($DB_USERNAME): "
read -s DB_PASSWORD
echo ""

# Validate password strength
if [ ${#DB_PASSWORD} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters long"
    exit 1
fi

# Get application user password
echo -n "Enter password for application user ($DB_APP_USERNAME): "
read -s DB_APP_PASSWORD
echo ""

# Validate password strength
if [ ${#DB_APP_PASSWORD} -lt 8 ]; then
    echo "❌ Password must be at least 8 characters long"
    exit 1
fi

echo "✅ Passwords configured"
```

### 2.3 Create RDS MySQL Instance

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Verify required variables
if [ -z "$RDS_SG" ] || [ -z "$DB_SUBNET_GROUP_NAME" ]; then
    echo "❌ Missing RDS security group or DB subnet group. Please run previous steps first."
    exit 1
fi

echo "Creating RDS MySQL instance..."
echo "Instance ID: $DB_INSTANCE_ID"
echo "Database Name: $DB_NAME"
echo "Admin Username: $DB_USERNAME"
echo "Security Group: $RDS_SG"
echo "Subnet Group: $DB_SUBNET_GROUP_NAME"
echo "Availability Zone: $AZ_1"

# Create RDS MySQL instance
aws rds create-db-instance \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version 8.0.35 \
    --master-username "$DB_USERNAME" \
    --master-user-password "$DB_PASSWORD" \
    --allocated-storage 20 \
    --storage-type gp2 \
    --storage-encrypted \
    --vpc-security-group-ids "$RDS_SG" \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --availability-zone "$AZ_1" \
    --db-name "$DB_NAME" \
    --backup-retention-period 7 \
    --no-multi-az \
    --no-publicly-accessible \
    --enable-performance-insights \
    --performance-insights-retention-period 7 \
    --monitoring-interval 60 \
    --tags Key=Name,Value="$DB_INSTANCE_ID" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT"

if [ $? -eq 0 ]; then
    echo "✅ RDS instance creation initiated: $DB_INSTANCE_ID"
    echo "⏳ This will take 10-15 minutes to complete..."
    
    # Save the instance ID
    save_resource_id "DB_INSTANCE_ID" "$DB_INSTANCE_ID"
else
    echo "❌ Failed to create RDS instance"
    exit 1
fi

# Monitor creation status
echo "=== Monitoring RDS Creation Status ==="
echo "You can monitor the progress with:"
echo "aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus]' --output table"
```

**Using AWS Console:**
1. **Navigate to RDS Console → Create Database**
2. **Choose Database Creation Method**: Standard create
3. **Engine Options**:
   - **Engine Type**: MySQL
   - **Version**: MySQL 8.0.35 (or latest available)
   - **Template**: Free tier (for learning/development)

4. **Settings**:
   - **DB Instance Identifier**: Use value from `$DB_INSTANCE_ID` (e.g., `formapp-database`)
   - **Master Username**: Use value from `$DB_USERNAME` (e.g., `admin`)
   - **Master Password**: Use the password you set earlier
   - **Confirm Password**: Re-enter your password

5. **Instance Configuration**:
   - **DB Instance Class**: `db.t3.micro` (Free Tier eligible)
   - **Storage Type**: General Purpose SSD (gp2)
   - **Allocated Storage**: 20 GB
   - **Enable Storage Autoscaling**: Yes (maximum 100 GB)

6. **Connectivity**:
   - **VPC**: Select your VPC
   - **DB Subnet Group**: Select your DB subnet group
   - **Public Access**: No (important for security!)
   - **VPC Security Groups**: Choose existing → Select your RDS security group
   - **Availability Zone**: Select the same AZ as your first private subnet
   - **Database Port**: 3306

7. **Additional Configuration**:
   - **Initial Database Name**: Use value from `$DB_NAME` (e.g., `formapp`)
   - **DB Parameter Group**: default.mysql8.0
   - **Option Group**: default:mysql-8-0
   - **Backup Retention Period**: 7 days
   - **Multi-AZ Deployment**: No (for learning/cost optimization)
   - **Enable Enhanced Monitoring**: Yes (60 seconds interval)
   - **Enable Performance Insights**: Yes (7 days retention - free)

8. **Click Create Database**

### 2.4 Wait for RDS Instance and Get Endpoint

**Monitor RDS Creation:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

echo "=== Waiting for RDS Instance to be Available ==="
echo "This typically takes 10-15 minutes..."

# Function to check RDS status
check_rds_status() {
    aws rds describe-db-instances \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --query 'DBInstances[0].DBInstanceStatus' \
        --output text 2>/dev/null
}

# Wait for RDS instance to be available with progress updates
echo "Current status: $(check_rds_status)"
echo "Waiting for status to become 'available'..."

# Wait with timeout
TIMEOUT=1200  # 20 minutes
ELAPSED=0
INTERVAL=30

while [ $ELAPSED -lt $TIMEOUT ]; do
    STATUS=$(check_rds_status)
    echo "$(date '+%H:%M:%S') - Status: $STATUS"
    
    if [ "$STATUS" = "available" ]; then
        echo "✅ RDS instance is now available!"
        break
    elif [ "$STATUS" = "failed" ] || [ "$STATUS" = "incompatible-parameters" ]; then
        echo "❌ RDS instance creation failed with status: $STATUS"
        exit 1
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Timeout waiting for RDS instance to become available"
    exit 1
fi

# Get the RDS endpoint
echo "=== Getting RDS Endpoint ==="
RDS_ENDPOINT=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBInstances[0].Endpoint.Address' \
    --output text)

if [ "$RDS_ENDPOINT" != "None" ] && [ -n "$RDS_ENDPOINT" ]; then
    save_resource_id "RDS_ENDPOINT" "$RDS_ENDPOINT"
    echo "✅ RDS Endpoint: $RDS_ENDPOINT"
    
    # Save endpoint to a file for easy reference
    echo "$RDS_ENDPOINT" > rds-endpoint.txt
    echo "✅ RDS endpoint saved to rds-endpoint.txt"
    
    # Display RDS instance details
    echo "=== RDS Instance Details ==="
    aws rds describe-db-instances \
        --db-instance-identifier "$DB_INSTANCE_ID" \
        --query 'DBInstances[0].[DBInstanceIdentifier,DBInstanceStatus,Engine,EngineVersion,DBInstanceClass,AllocatedStorage,Endpoint.Address,Endpoint.Port,AvailabilityZone,MultiAZ]' \
        --output table
else
    echo "❌ Could not retrieve RDS endpoint"
    exit 1
fi
```

**Using AWS Console:**
The RDS instance will take 10-15 minutes to create. While waiting:
1. **Navigate to RDS Console → Databases**
2. **Monitor the status** - it will show "Creating" then "Available"
3. **Once available, note the endpoint** (you'll need this later)
4. **The endpoint will look like**: `formapp-database.xxxxxxxxxx.your-region.rds.amazonaws.com`

> **Production Consideration**: In production environments, you would enable **Multi-AZ deployment** for automatic failover to a standby instance in another AZ. This provides high availability but increases costs (~2x). For learning purposes, single-AZ is sufficient to understand RDS concepts.
### 2.5 Test Network Connectivity to RDS

Before proceeding with database setup, let's verify network connectivity:

```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Get your current EC2 instance (from Stage 1)
CURRENT_INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

if [ "$CURRENT_INSTANCE_ID" = "None" ] || [ -z "$CURRENT_INSTANCE_ID" ]; then
    echo "❌ No running EC2 instance found. Please ensure your Stage 1 instance is running."
    exit 1
fi

CURRENT_INSTANCE_IP=$(aws ec2 describe-instances \
    --instance-ids "$CURRENT_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text)

echo "✅ Found current EC2 instance: $CURRENT_INSTANCE_ID ($CURRENT_INSTANCE_IP)"
save_resource_id "CURRENT_INSTANCE_ID" "$CURRENT_INSTANCE_ID"
save_resource_id "CURRENT_INSTANCE_IP" "$CURRENT_INSTANCE_IP"

# Test connectivity to RDS
echo "=== Testing Network Connectivity to RDS ==="
echo "RDS Endpoint: $RDS_ENDPOINT"
echo "Testing from EC2 instance: $CURRENT_INSTANCE_IP"

# Create a connectivity test script
cat > test-rds-connectivity.sh << 'EOF'
#!/bin/bash
RDS_ENDPOINT="$1"

echo "=== RDS Connectivity Test ==="
echo "Testing connection to: $RDS_ENDPOINT:3306"

# Test DNS resolution
echo "1. Testing DNS resolution..."
nslookup "$RDS_ENDPOINT"
if [ $? -eq 0 ]; then
    echo "✅ DNS resolution successful"
else
    echo "❌ DNS resolution failed"
    exit 1
fi

# Test port connectivity
echo "2. Testing port connectivity..."
timeout 10 nc -zv "$RDS_ENDPOINT" 3306
if [ $? -eq 0 ]; then
    echo "✅ Port 3306 is reachable"
else
    echo "❌ Port 3306 is not reachable"
    echo "This could indicate:"
    echo "  - Security group rules are incorrect"
    echo "  - Network ACL rules are missing"
    echo "  - RDS instance is not available"
    exit 1
fi

# Test with telnet (more detailed)
echo "3. Testing with telnet..."
(echo > /dev/tcp/"$RDS_ENDPOINT"/3306) 2>/dev/null
if [ $? -eq 0 ]; then
    echo "✅ TCP connection successful"
else
    echo "❌ TCP connection failed"
    exit 1
fi

echo "✅ All connectivity tests passed!"
EOF

chmod +x test-rds-connectivity.sh

# Copy script to EC2 and run it
echo "Copying connectivity test to EC2 instance..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    test-rds-connectivity.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

echo "Running connectivity test on EC2 instance..."
ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "bash /tmp/test-rds-connectivity.sh $RDS_ENDPOINT"

if [ $? -eq 0 ]; then
    echo "✅ Network connectivity to RDS verified successfully"
else
    echo "❌ Network connectivity test failed"
    echo "Please check:"
    echo "1. Security group rules (EC2 SG allows outbound, RDS SG allows inbound from EC2 SG)"
    echo "2. Network ACL rules (allow MySQL traffic both directions)"
    echo "3. RDS instance status (should be 'available')"
    exit 1
fi
```

## Step 3: Database Migration and Setup

### 3.1 Connect to Your Current EC2 Instance

```bash
# Load configuration
source lab-config.sh
load_resource_ids

echo "=== Connecting to EC2 Instance for Database Setup ==="
echo "Instance: $CURRENT_INSTANCE_ID ($CURRENT_INSTANCE_IP)"
echo "SSH Key: $SSH_KEY_NAME"

# Test SSH connectivity first
echo "Testing SSH connectivity..."
ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o ConnectTimeout=10 -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" "echo 'SSH connection successful'"

if [ $? -eq 0 ]; then
    echo "✅ SSH connection verified"
    echo ""
    echo "To connect manually, use:"
    echo "ssh -i ~/.ssh/$SSH_KEY_NAME.pem ubuntu@$CURRENT_INSTANCE_IP"
else
    echo "❌ SSH connection failed"
    echo "Please check:"
    echo "1. EC2 instance is running"
    echo "2. Security group allows SSH from your IP"
    echo "3. SSH key file exists and has correct permissions"
    exit 1
fi
```

### 3.2 Backup and Export Current Database

```bash
# Create database backup script
cat > backup-database.sh << 'EOF'
#!/bin/bash
echo "=== Database Backup Process ==="

# Check if MySQL is running locally
echo "1. Checking local MySQL service..."
sudo systemctl status mysql --no-pager -l
MYSQL_STATUS=$?

if [ $MYSQL_STATUS -eq 0 ]; then
    echo "✅ Local MySQL is running"
    
    # Check for existing database
    echo "2. Checking for existing formapp database..."
    mysql -u root -p -e "SHOW DATABASES LIKE 'formapp';" 2>/dev/null | grep formapp
    
    if [ $? -eq 0 ]; then
        echo "✅ Found formapp database"
        
        # Get database credentials from application config
        if [ -f ~/mentorship-challenges/3-tier-app/src/api/.env ]; then
            echo "3. Reading database credentials from .env file..."
            source ~/mentorship-challenges/3-tier-app/src/api/.env
            
            # Create backup
            echo "4. Creating database backup..."
            mysqldump -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" > formapp_backup.sql 2>/dev/null
            
            if [ $? -eq 0 ]; then
                echo "✅ Database backup created successfully"
                ls -la formapp_backup.sql
                echo "Backup size: $(du -h formapp_backup.sql | cut -f1)"
                
                # Show sample of backup
                echo "5. Backup sample (first 20 lines):"
                head -20 formapp_backup.sql
                
                # Count records
                echo "6. Checking record counts..."
                mysql -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) as total_submissions FROM submissions;" 2>/dev/null
            else
                echo "❌ Database backup failed"
                echo "Trying with root user..."
                mysqldump -u root -p formapp > formapp_backup.sql
            fi
        else
            echo "⚠️  .env file not found, trying with default credentials..."
            mysqldump -u root -p formapp > formapp_backup.sql
        fi
    else
        echo "ℹ️  No existing formapp database found"
        echo "Will create fresh database on RDS"
        touch formapp_backup.sql  # Create empty backup file
    fi
else
    echo "ℹ️  Local MySQL is not running"
    echo "Will create fresh database on RDS"
    touch formapp_backup.sql  # Create empty backup file
fi

echo "=== Backup process completed ==="
EOF

chmod +x backup-database.sh

# Copy and run backup script on EC2
echo "Running database backup on EC2 instance..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    backup-database.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "bash /tmp/backup-database.sh"
```

### 3.3 Install MySQL Client and Setup RDS Database

```bash
# Create RDS setup script
cat > setup-rds-database.sh << EOF
#!/bin/bash
RDS_ENDPOINT="$1"
DB_USERNAME="$2"
DB_NAME="$3"

echo "=== RDS Database Setup ==="
echo "RDS Endpoint: \$RDS_ENDPOINT"
echo "Database Name: \$DB_NAME"
echo "Admin Username: \$DB_USERNAME"

# Install MySQL client if not already installed
echo "1. Installing MySQL client..."
sudo apt-get update -qq
sudo apt-get install -y mysql-client

# Test connection to RDS
echo "2. Testing connection to RDS..."
echo "Please enter the RDS admin password when prompted:"
mysql -h "\$RDS_ENDPOINT" -u "\$DB_USERNAME" -p -e "SELECT VERSION();"

if [ \$? -eq 0 ]; then
    echo "✅ Successfully connected to RDS"
else
    echo "❌ Failed to connect to RDS"
    exit 1
fi

# Import existing data if backup exists and has content
echo "3. Checking for existing data backup..."
if [ -f formapp_backup.sql ] && [ -s formapp_backup.sql ]; then
    echo "Found backup file with data, importing..."
    echo "Please enter the RDS admin password when prompted:"
    mysql -h "\$RDS_ENDPOINT" -u "\$DB_USERNAME" -p "\$DB_NAME" < formapp_backup.sql
    
    if [ \$? -eq 0 ]; then
        echo "✅ Data imported successfully"
        
        # Verify import
        echo "Verifying imported data..."
        mysql -h "\$RDS_ENDPOINT" -u "\$DB_USERNAME" -p "\$DB_NAME" -e "SHOW TABLES;"
        mysql -h "\$RDS_ENDPOINT" -u "\$DB_USERNAME" -p "\$DB_NAME" -e "SELECT COUNT(*) as total_submissions FROM submissions;" 2>/dev/null || echo "No submissions table found"
    else
        echo "❌ Data import failed"
    fi
else
    echo "No existing data found, will create fresh schema"
fi

echo "=== RDS setup completed ==="
EOF

# Copy and run RDS setup script
echo "Setting up RDS database..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    setup-rds-database.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "bash /tmp/setup-rds-database.sh $RDS_ENDPOINT $DB_USERNAME $DB_NAME"
```

### 3.4 Create Database Schema and Application User

```bash
# Create database schema setup script
cat > create-database-schema.sh << EOF
#!/bin/bash
RDS_ENDPOINT="$1"
DB_USERNAME="$2"
DB_NAME="$3"
DB_APP_USERNAME="$4"

echo "=== Creating Database Schema and Application User ==="

# Create SQL script for schema and user setup
cat > /tmp/setup_database.sql << 'SQL_EOF'
-- Create database if it doesn't exist
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
USE ${DB_NAME};

-- Create submissions table
CREATE TABLE IF NOT EXISTS submissions (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    email VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_created_at (created_at),
    INDEX idx_email (email)
);

-- Create application user
CREATE USER IF NOT EXISTS '${DB_APP_USERNAME}'@'%' IDENTIFIED BY '${DB_APP_PASSWORD}';

-- Grant privileges to application user
GRANT SELECT, INSERT, UPDATE, DELETE ON ${DB_NAME}.* TO '${DB_APP_USERNAME}'@'%';
FLUSH PRIVILEGES;

-- Verify setup
SELECT 'Database setup completed' as status;
SHOW TABLES;
SELECT User, Host FROM mysql.user WHERE User = '${DB_APP_USERNAME}';
SHOW GRANTS FOR '${DB_APP_USERNAME}'@'%';
SQL_EOF

# Replace variables in SQL script
sed -i "s/\${DB_NAME}/$DB_NAME/g" /tmp/setup_database.sql
sed -i "s/\${DB_APP_USERNAME}/$DB_APP_USERNAME/g" /tmp/setup_database.sql
sed -i "s/\${DB_APP_PASSWORD}/$DB_APP_PASSWORD/g" /tmp/setup_database.sql

echo "Executing database setup script..."
echo "Please enter the RDS admin password when prompted:"
mysql -h "\$RDS_ENDPOINT" -u "\$DB_USERNAME" -p < /tmp/setup_database.sql

if [ \$? -eq 0 ]; then
    echo "✅ Database schema and user created successfully"
    
    # Test application user connection
    echo "Testing application user connection..."
    echo "Please enter the application user password when prompted:"
    mysql -h "\$RDS_ENDPOINT" -u "$DB_APP_USERNAME" -p "$DB_NAME" -e "SELECT COUNT(*) as table_count FROM information_schema.tables WHERE table_schema = '$DB_NAME';"
    
    if [ \$? -eq 0 ]; then
        echo "✅ Application user connection verified"
    else
        echo "❌ Application user connection failed"
    fi
else
    echo "❌ Database setup failed"
    exit 1
fi

echo "=== Database schema setup completed ==="
EOF

# Copy and run schema setup script
echo "Creating database schema and application user..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    create-database-schema.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

# Pass the application password securely
ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "DB_APP_PASSWORD='$DB_APP_PASSWORD' bash /tmp/create-database-schema.sh $RDS_ENDPOINT $DB_USERNAME $DB_NAME $DB_APP_USERNAME"
```

## Step 4: Update Application Configuration

### 4.1 Update API Environment Configuration

```bash
# Create application configuration update script
cat > update-app-config.sh << EOF
#!/bin/bash
RDS_ENDPOINT="$1"
DB_APP_USERNAME="$2"
DB_NAME="$3"

echo "=== Updating Application Configuration ==="

# Navigate to API directory
cd ~/mentorship-challenges/3-tier-app/src/api || {
    echo "❌ API directory not found"
    exit 1
}

# Backup current .env file
if [ -f .env ]; then
    cp .env .env.backup.$(date +%Y%m%d_%H%M%S)
    echo "✅ Backed up existing .env file"
fi

# Create new .env file with RDS configuration
cat > .env << ENV_EOF
# Server Configuration
PORT=3000

# MySQL Configuration (RDS)
DB_HOST=\$RDS_ENDPOINT
DB_USER=\$DB_APP_USERNAME
DB_PASSWORD=\$DB_APP_PASSWORD
DB_NAME=\$DB_NAME

# Application Configuration
NODE_ENV=production
LOG_LEVEL=info
ENV_EOF

# Replace variables
sed -i "s/\\\$RDS_ENDPOINT/$RDS_ENDPOINT/g" .env
sed -i "s/\\\$DB_APP_USERNAME/$DB_APP_USERNAME/g" .env
sed -i "s/\\\$DB_NAME/$DB_NAME/g" .env
sed -i "s/\\\$DB_APP_PASSWORD/$DB_APP_PASSWORD/g" .env

# Secure the environment file
chmod 600 .env

echo "✅ Updated .env file with RDS configuration"
echo "Configuration:"
cat .env | grep -v PASSWORD

echo "=== Application configuration updated ==="
EOF

# Copy and run configuration update script
echo "Updating application configuration..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    update-app-config.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "DB_APP_PASSWORD='$DB_APP_PASSWORD' bash /tmp/update-app-config.sh $RDS_ENDPOINT $DB_APP_USERNAME $DB_NAME"
```

### 4.2 Test RDS Connection and Restart Application

```bash
# Create application testing script
cat > test-app-with-rds.sh << 'EOF'
#!/bin/bash
echo "=== Testing Application with RDS ==="

# Navigate to API directory
cd ~/mentorship-challenges/3-tier-app/src/api

# Check PM2 status
echo "1. Current PM2 status:"
pm2 status

# Restart PM2 to pick up new configuration
echo "2. Restarting application with new RDS configuration..."
pm2 restart formapp-api

# Wait for application to start
sleep 5

# Check PM2 logs for database connection
echo "3. Checking application logs for database connection..."
pm2 logs formapp-api --lines 20

# Test API endpoint
echo "4. Testing API endpoint..."
curl -s http://localhost:3000/api/submissions | head -100

# Test database connectivity directly
echo "5. Testing direct database connection..."
source .env
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT COUNT(*) as total_submissions FROM submissions;" 2>/dev/null || echo "Direct database test failed"

# Test full application
echo "6. Testing full application..."
curl -s -I http://localhost/

# Test API through Nginx
echo "7. Testing API through Nginx..."
curl -s http://localhost/api/submissions | head -100

echo "=== Application testing completed ==="
EOF

# Copy and run application testing script
echo "Testing application with RDS..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    test-app-with-rds.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "bash /tmp/test-app-with-rds.sh"

if [ $? -eq 0 ]; then
    echo "✅ Application successfully configured with RDS"
else
    echo "❌ Application configuration with RDS failed"
    echo "Please check the logs and troubleshoot connectivity issues"
fi
```

### 4.3 Test API Functionality with Sample Data

```bash
# Create API functionality test script
cat > test-api-functionality.sh << 'EOF'
#!/bin/bash
echo "=== Testing API Functionality ==="

# Test API submission
echo "1. Testing API submission..."
RESPONSE=$(curl -s -X POST http://localhost:3000/api/submissions \
  -H "Content-Type: application/json" \
  -d '{"name":"RDS Test User","email":"rds-test@example.com","message":"Testing RDS connection and API functionality"}')

echo "API Response: $RESPONSE"

# Wait a moment for data to be saved
sleep 2

# Verify submission was saved
echo "2. Verifying submission was saved..."
curl -s http://localhost:3000/api/submissions | jq '.[] | select(.name=="RDS Test User")'

# Test through Nginx (full stack)
echo "3. Testing through Nginx (full stack)..."
curl -s -X POST http://localhost/api/submissions \
  -H "Content-Type: application/json" \
  -d '{"name":"Full Stack Test","email":"fullstack@example.com","message":"Testing complete application stack with RDS"}'

# Verify full stack submission
echo "4. Verifying full stack submission..."
curl -s http://localhost/api/submissions | jq '.[] | select(.name=="Full Stack Test")'

echo "=== API functionality testing completed ==="
EOF

# Copy and run API functionality test
echo "Testing API functionality..."
scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    test-api-functionality.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/

ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
    ubuntu@"$CURRENT_INSTANCE_IP" \
    "bash /tmp/test-api-functionality.sh"
```

### 4.4 Optional: Stop Local MySQL Service

```bash
# Create local MySQL cleanup script
cat > cleanup-local-mysql.sh << 'EOF'
#!/bin/bash
echo "=== Cleaning Up Local MySQL Service ==="

# Check if local MySQL is running
if sudo systemctl is-active --quiet mysql; then
    echo "Local MySQL is running"
    
    # Show current system resources
    echo "Current system resources:"
    free -h
    
    # Stop and disable local MySQL
    echo "Stopping local MySQL service..."
    sudo systemctl stop mysql
    sudo systemctl disable mysql
    
    echo "✅ Local MySQL service stopped and disabled"
    
    # Show resources after stopping MySQL
    echo "System resources after stopping MySQL:"
    free -h
    
    # Verify API still works with RDS
    echo "Verifying API still works with RDS..."
    curl -s http://localhost/api/submissions | head -100
    
    if [ $? -eq 0 ]; then
        echo "✅ Application successfully using RDS instead of local MySQL"
    else
        echo "❌ Application not working with RDS"
        echo "Starting local MySQL again..."
        sudo systemctl start mysql
    fi
else
    echo "ℹ️  Local MySQL is not running"
fi

echo "=== Local MySQL cleanup completed ==="
EOF

# Ask user if they want to stop local MySQL
echo ""
echo "Do you want to stop the local MySQL service now that RDS is working? (y/n)"
read -r STOP_MYSQL

if [ "$STOP_MYSQL" = "y" ] || [ "$STOP_MYSQL" = "Y" ]; then
    echo "Stopping local MySQL service..."
    scp -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
        cleanup-local-mysql.sh ubuntu@"$CURRENT_INSTANCE_IP":/tmp/
    
    ssh -i ~/.ssh/"$SSH_KEY_NAME".pem -o StrictHostKeyChecking=no \
        ubuntu@"$CURRENT_INSTANCE_IP" \
        "bash /tmp/cleanup-local-mysql.sh"
else
    echo "Keeping local MySQL service running"
fi
```

### 4.5 Troubleshooting Common Issues

```bash
# Create troubleshooting script
cat > troubleshoot-rds-connection.sh << 'EOF'
#!/bin/bash
echo "=== RDS Connection Troubleshooting ==="

# Load environment variables
cd ~/mentorship-challenges/3-tier-app/src/api
source .env

echo "Configuration:"
echo "DB_HOST: $DB_HOST"
echo "DB_USER: $DB_USER"
echo "DB_NAME: $DB_NAME"

# Test 1: DNS Resolution
echo "1. Testing DNS resolution..."
nslookup "$DB_HOST"

# Test 2: Port connectivity
echo "2. Testing port connectivity..."
nc -zv "$DB_HOST" 3306

# Test 3: MySQL client connection
echo "3. Testing MySQL client connection..."
mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASSWORD" "$DB_NAME" -e "SELECT 1 as connection_test;"

# Test 4: Check PM2 logs
echo "4. Recent PM2 logs:"
pm2 logs formapp-api --lines 10

# Test 5: Check Nginx logs
echo "5. Recent Nginx access logs:"
sudo tail -5 /var/log/nginx/access.log

echo "6. Recent Nginx error logs:"
sudo tail -5 /var/log/nginx/error.log

# Test 6: System resources
echo "7. System resources:"
free -h
df -h

echo "=== Troubleshooting completed ==="
EOF

echo ""
echo "If you encounter issues, you can run troubleshooting with:"
echo "scp -i ~/.ssh/$SSH_KEY_NAME.pem troubleshoot-rds-connection.sh ubuntu@$CURRENT_INSTANCE_IP:/tmp/"
echo "ssh -i ~/.ssh/$SSH_KEY_NAME.pem ubuntu@$CURRENT_INSTANCE_IP 'bash /tmp/troubleshoot-rds-connection.sh'"
```

> **🔧 Common Troubleshooting Issues:**
> - **Connection Refused**: Check security group rules and NACL configuration
> - **Authentication Failed**: Verify database user credentials
> - **Timeout**: Check Network ACL rules for both inbound and outbound traffic
> - **Application Errors**: Check PM2 logs with `pm2 logs formapp-api --lines 50`
> - **DNS Issues**: Verify RDS endpoint is correct and accessible
## Step 5: Create Application Load Balancer

### 5.1 Create Target Group with Health Checks

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Verify required variables
if [ -z "$VPC_ID" ] || [ -z "$CURRENT_INSTANCE_ID" ]; then
    echo "❌ Missing VPC_ID or CURRENT_INSTANCE_ID. Please run previous steps first."
    exit 1
fi

echo "=== Creating Target Group ==="
echo "Target Group Name: $TARGET_GROUP_NAME"
echo "VPC: $VPC_ID"
echo "Health Check Path: /"

# Create target group
TARGET_GROUP_ARN=$(aws elbv2 create-target-group \
    --name "$TARGET_GROUP_NAME" \
    --protocol HTTP \
    --port 80 \
    --vpc-id "$VPC_ID" \
    --health-check-protocol HTTP \
    --health-check-path / \
    --health-check-interval-seconds 30 \
    --health-check-timeout-seconds 5 \
    --healthy-threshold-count 2 \
    --unhealthy-threshold-count 2 \
    --matcher HttpCode=200 \
    --tags Key=Name,Value="$TARGET_GROUP_NAME" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

if [ $? -eq 0 ] && [ "$TARGET_GROUP_ARN" != "None" ]; then
    save_resource_id "TARGET_GROUP_ARN" "$TARGET_GROUP_ARN"
    echo "✅ Created Target Group: $TARGET_GROUP_ARN"
    
    # Display target group details
    echo "=== Target Group Details ==="
    aws elbv2 describe-target-groups \
        --target-group-arns "$TARGET_GROUP_ARN" \
        --query 'TargetGroups[0].[TargetGroupName,Protocol,Port,HealthCheckPath,HealthCheckIntervalSeconds,HealthyThresholdCount,UnhealthyThresholdCount]' \
        --output table
else
    echo "❌ Failed to create Target Group"
    exit 1
fi

# Register current EC2 instance with the target group
echo "=== Registering EC2 Instance with Target Group ==="
echo "Instance: $CURRENT_INSTANCE_ID"

aws elbv2 register-targets \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --targets Id="$CURRENT_INSTANCE_ID",Port=80

if [ $? -eq 0 ]; then
    echo "✅ Registered instance $CURRENT_INSTANCE_ID with target group"
    
    # Wait a moment and check target health
    echo "Waiting 10 seconds before checking target health..."
    sleep 10
    
    echo "=== Initial Target Health Check ==="
    aws elbv2 describe-target-health \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
        --output table
else
    echo "❌ Failed to register instance with target group"
    exit 1
fi
```

**Using AWS Console:**
1. **Navigate to EC2 Console → Target Groups**
2. **Create Target Group**:
   - **Choose Target Type**: Instances
   - **Target Group Name**: Use value from `$TARGET_GROUP_NAME` (e.g., `3tier-app-tg`)
   - **Protocol**: HTTP
   - **Port**: 80
   - **VPC**: Select your VPC
   - **Protocol Version**: HTTP1

3. **Health Check Settings**:
   - **Health Check Protocol**: HTTP
   - **Health Check Path**: `/` (this will check your main page)
   - **Health Check Port**: Traffic port
   - **Healthy Threshold**: 2 consecutive successful checks
   - **Unhealthy Threshold**: 2 consecutive failed checks
   - **Timeout**: 5 seconds
   - **Interval**: 30 seconds
   - **Success Codes**: 200

4. **Register Targets**:
   - **Available Instances**: Select your current EC2 instance
   - **Port**: 80
   - Click "Include as pending below"
   - **Create Target Group**

### 5.2 Create Application Load Balancer

**Using AWS CLI with Variables:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

# Verify required variables
if [ -z "$PUBLIC_SUBNET_1" ] || [ -z "$ALB_SG" ]; then
    echo "❌ Missing required subnet IDs or ALB security group. Please run previous steps first."
    exit 1
fi

echo "=== Creating Application Load Balancer ==="
echo "ALB Name: $ALB_NAME"
echo "Subnets: $PUBLIC_SUBNET_1"
echo "Security Group: $ALB_SG"

# Create Application Load Balancer
ALB_ARN=$(aws elbv2 create-load-balancer \
    --name "$ALB_NAME" \
    --subnets "$PUBLIC_SUBNET_1" \
    --security-groups "$ALB_SG" \
    --scheme internet-facing \
    --type application \
    --ip-address-type ipv4 \
    --tags Key=Name,Value="$ALB_NAME" Key=Project,Value="$PROJECT_NAME" Key=Environment,Value="$ENVIRONMENT" \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

if [ $? -eq 0 ] && [ "$ALB_ARN" != "None" ]; then
    save_resource_id "ALB_ARN" "$ALB_ARN"
    echo "✅ Created Application Load Balancer: $ALB_ARN"
    
    # Get ALB DNS name
    ALB_DNS=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].DNSName' \
        --output text)
    
    if [ "$ALB_DNS" != "None" ]; then
        save_resource_id "ALB_DNS" "$ALB_DNS"
        echo "✅ ALB DNS Name: $ALB_DNS"
        
        # Save DNS name to file for easy reference
        echo "$ALB_DNS" > alb-dns-name.txt
        echo "✅ ALB DNS name saved to alb-dns-name.txt"
    fi
    
    # Display ALB details
    echo "=== Application Load Balancer Details ==="
    aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].[LoadBalancerName,DNSName,State.Code,Type,Scheme]' \
        --output table
else
    echo "❌ Failed to create Application Load Balancer"
    exit 1
fi

# Create listener
echo "=== Creating ALB Listener ==="
LISTENER_ARN=$(aws elbv2 create-listener \
    --load-balancer-arn "$ALB_ARN" \
    --protocol HTTP \
    --port 80 \
    --default-actions Type=forward,TargetGroupArn="$TARGET_GROUP_ARN" \
    --tags Key=Name,Value="$ALB_NAME-listener" Key=Project,Value="$PROJECT_NAME" \
    --query 'Listeners[0].ListenerArn' \
    --output text)

if [ $? -eq 0 ] && [ "$LISTENER_ARN" != "None" ]; then
    save_resource_id "LISTENER_ARN" "$LISTENER_ARN"
    echo "✅ Created ALB Listener: $LISTENER_ARN"
    
    # Display listener details
    echo "=== Listener Details ==="
    aws elbv2 describe-listeners \
        --listener-arns "$LISTENER_ARN" \
        --query 'Listeners[0].[Protocol,Port,DefaultActions[0].Type,DefaultActions[0].TargetGroupArn]' \
        --output table
else
    echo "❌ Failed to create ALB Listener"
    exit 1
fi

# Wait for ALB to become active
echo "=== Waiting for ALB to become active ==="
echo "This may take 2-3 minutes..."

aws elbv2 wait load-balancer-available --load-balancer-arns "$ALB_ARN"

if [ $? -eq 0 ]; then
    echo "✅ ALB is now active and ready to receive traffic"
    
    # Final status check
    ALB_STATE=$(aws elbv2 describe-load-balancers \
        --load-balancer-arns "$ALB_ARN" \
        --query 'LoadBalancers[0].State.Code' \
        --output text)
    
    echo "ALB State: $ALB_STATE"
    echo "ALB DNS: $ALB_DNS"
    echo ""
    echo "🎉 Your application is now accessible at: http://$ALB_DNS"
else
    echo "❌ Timeout waiting for ALB to become active"
    exit 1
fi
```

**Using AWS Console:**
1. **Navigate to EC2 Console → Load Balancers**
2. **Create Load Balancer → Application Load Balancer**:
   - **Load Balancer Name**: Use value from `$ALB_NAME` (e.g., `3tier-app-alb`)
   - **Scheme**: Internet-facing
   - **IP Address Type**: IPv4

3. **Network Mapping**:
   - **VPC**: Select your VPC
   - **Mappings**: Select both public subnets (in different AZs)
   - **Security Groups**: Remove default, select your ALB security group

4. **Listeners and Routing**:
   - **Protocol**: HTTP
   - **Port**: 80
   - **Default Action**: Forward to target group
   - **Target Group**: Select your target group

5. **Review and Create Load Balancer**

### 5.3 Monitor Target Health and Test ALB

**Monitor Target Health:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

echo "=== Monitoring Target Health ==="
echo "Target Group: $TARGET_GROUP_ARN"
echo "Monitoring health checks (this may take 2-3 minutes)..."

# Function to check target health
check_target_health() {
    aws elbv2 describe-target-health \
        --target-group-arn "$TARGET_GROUP_ARN" \
        --query 'TargetHealthDescriptions[0].TargetHealth.State' \
        --output text 2>/dev/null
}

# Monitor health with timeout
TIMEOUT=300  # 5 minutes
ELAPSED=0
INTERVAL=15

while [ $ELAPSED -lt $TIMEOUT ]; do
    HEALTH_STATE=$(check_target_health)
    TIMESTAMP=$(date '+%H:%M:%S')
    
    echo "[$TIMESTAMP] Target Health: $HEALTH_STATE"
    
    if [ "$HEALTH_STATE" = "healthy" ]; then
        echo "✅ Target is healthy! ALB is ready to serve traffic."
        break
    elif [ "$HEALTH_STATE" = "unhealthy" ]; then
        echo "⚠️  Target is unhealthy. Checking details..."
        aws elbv2 describe-target-health \
            --target-group-arn "$TARGET_GROUP_ARN" \
            --query 'TargetHealthDescriptions[0].[Target.Id,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' \
            --output table
    fi
    
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

if [ $ELAPSED -ge $TIMEOUT ]; then
    echo "❌ Timeout waiting for target to become healthy"
    echo "Please check:"
    echo "1. EC2 instance is running and responding on port 80"
    echo "2. Security group allows ALB to reach EC2 on port 80"
    echo "3. Application is serving content at the health check path (/)"
    exit 1
fi
```

**Test ALB Functionality:**
```bash
# Load configuration
source lab-config.sh
load_resource_ids

echo "=== Testing ALB Functionality ==="
echo "ALB DNS: $ALB_DNS"

# Test 1: Basic connectivity
echo "1. Testing basic HTTP connectivity..."
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")
echo "HTTP Status: $HTTP_STATUS"

if [ "$HTTP_STATUS" = "200" ]; then
    echo "✅ ALB is responding with HTTP 200"
else
    echo "❌ ALB returned HTTP $HTTP_STATUS"
fi

# Test 2: Get response headers
echo "2. Testing response headers..."
curl -I "http://$ALB_DNS/"

# Test 3: Test API endpoint through ALB
echo "3. Testing API endpoint through ALB..."
API_RESPONSE=$(curl -s "http://$ALB_DNS/api/submissions" | head -200)
echo "API Response (first 200 chars): $API_RESPONSE"

# Test 4: Test main page content
echo "4. Testing main page content..."
MAIN_PAGE=$(curl -s "http://$ALB_DNS/" | grep -o '<title>.*</title>')
echo "Page title: $MAIN_PAGE"

# Test 5: Multiple requests to verify consistency
echo "5. Testing multiple requests for consistency..."
for i in {1..5}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")
    echo "Request $i: HTTP $STATUS"
    sleep 1
done

echo "=== ALB Testing Complete ==="
echo ""
echo "🎉 Your application is now accessible through the Application Load Balancer!"
echo "🌐 URL: http://$ALB_DNS"
echo "📊 Admin Panel: http://$ALB_DNS/admin.html"
echo "🔗 API Endpoint: http://$ALB_DNS/api/submissions"
```

### 5.4 Verify Target Health Troubleshooting

**Create comprehensive health check script:**
```bash
# Create target health troubleshooting script
cat > troubleshoot-target-health.sh << 'EOF'
#!/bin/bash
echo "=== Target Health Troubleshooting ==="

# Check if Nginx is running
echo "1. Checking Nginx status..."
sudo systemctl status nginx --no-pager -l

# Check if application is running
echo "2. Checking PM2 application status..."
pm2 status

# Test local application response
echo "3. Testing local application response..."
curl -I http://localhost/
curl -I http://localhost:3000/

# Check Nginx configuration
echo "4. Checking Nginx configuration..."
sudo nginx -t

# Check recent Nginx logs
echo "5. Recent Nginx access logs..."
sudo tail -10 /var/log/nginx/access.log

echo "6. Recent Nginx error logs..."
sudo tail -10 /var/log/nginx/error.log

# Check PM2 logs
echo "7. Recent PM2 logs..."
pm2 logs formapp-api --lines 10

# Check system resources
echo "8. System resources..."
free -h
df -h

# Check network connectivity
echo "9. Network interfaces..."
ip addr show

echo "=== Troubleshooting completed ==="
EOF

echo ""
echo "If targets are showing as unhealthy, you can run detailed troubleshooting:"
echo "scp -i ~/.ssh/$SSH_KEY_NAME.pem troubleshoot-target-health.sh ubuntu@$CURRENT_INSTANCE_IP:/tmp/"
echo "ssh -i ~/.ssh/$SSH_KEY_NAME.pem ubuntu@$CURRENT_INSTANCE_IP 'bash /tmp/troubleshoot-target-health.sh'"
```

### 5.5 Common ALB Issues and Solutions

**Security Group Issues:**
```bash
# Check security group rules
echo "=== Checking Security Group Configuration ==="

# ALB Security Group - should allow HTTP from internet
echo "ALB Security Group ($ALB_SG) Inbound Rules:"
aws ec2 describe-security-groups \
    --group-ids "$ALB_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp,UserIdGroupPairs[*].GroupId]' \
    --output table

# EC2 Security Group - should allow HTTP from ALB
echo "EC2 Security Group ($EC2_SG) Inbound Rules:"
aws ec2 describe-security-groups \
    --group-ids "$EC2_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[*].CidrIp,UserIdGroupPairs[*].GroupId]' \
    --output table

# Verify ALB can reach EC2
echo "Expected: EC2 SG should allow port 80 from ALB SG ($ALB_SG)"
```

**Target Registration Issues:**
```bash
# Check target registration
echo "=== Checking Target Registration ==="
aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,Target.Port,TargetHealth.State,TargetHealth.Reason,TargetHealth.Description]' \
    --output table

# Check if instance is in correct subnets
echo "Instance Subnet:"
aws ec2 describe-instances \
    --instance-ids "$CURRENT_INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].[InstanceId,SubnetId,VpcId,State.Name]' \
    --output table

echo "ALB Subnets:"
aws elbv2 describe-load-balancers \
    --load-balancer-arns "$ALB_ARN" \
    --query 'LoadBalancers[0].AvailabilityZones[*].[ZoneName,SubnetId]' \
    --output table
```

> **🔧 Common ALB Issues:**
> - **Target Unhealthy**: Check if application is running and responding on port 80
> - **Connection Timeout**: Verify security group rules allow ALB → EC2 communication
> - **502 Bad Gateway**: Application is not responding or crashed
> - **503 Service Unavailable**: No healthy targets available
> - **DNS Not Resolving**: ALB may still be provisioning (wait 2-3 minutes)
## Step 6: Comprehensive Testing and Validation

### 6.1 End-to-End Application Testing

**Create comprehensive testing script:**
```bash
# Create comprehensive testing script
cat > comprehensive-test.sh << 'EOF'
#!/bin/bash
ALB_DNS="$1"

if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <ALB_DNS_NAME>"
    exit 1
fi

echo "=== Comprehensive Application Testing ==="
echo "Testing ALB: $ALB_DNS"
echo "Timestamp: $(date)"

# Test 1: Basic connectivity and response time
echo "1. Testing basic connectivity and response time..."
RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "http://$ALB_DNS/")
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")

echo "   HTTP Status: $HTTP_STATUS"
echo "   Response Time: ${RESPONSE_TIME}s"

if [ "$HTTP_STATUS" = "200" ]; then
    echo "   ✅ Main page accessible"
else
    echo "   ❌ Main page not accessible (HTTP $HTTP_STATUS)"
fi

# Test 2: API endpoint functionality
echo "2. Testing API endpoint..."
API_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/api/submissions")
echo "   API Status: $API_STATUS"

if [ "$API_STATUS" = "200" ]; then
    echo "   ✅ API endpoint accessible"
    
    # Get current submission count
    SUBMISSION_COUNT=$(curl -s "http://$ALB_DNS/api/submissions" | jq length 2>/dev/null || echo "unknown")
    echo "   Current submissions: $SUBMISSION_COUNT"
else
    echo "   ❌ API endpoint not accessible (HTTP $API_STATUS)"
fi

# Test 3: Form submission functionality
echo "3. Testing form submission..."
SUBMIT_RESPONSE=$(curl -s -X POST "http://$ALB_DNS/api/submissions" \
    -H "Content-Type: application/json" \
    -d '{"name":"ALB Test User","email":"alb-test@example.com","message":"Testing form submission through ALB"}' \
    -w "%{http_code}")

echo "   Submission response: $SUBMIT_RESPONSE"

# Wait and verify submission was saved
sleep 2
NEW_SUBMISSION=$(curl -s "http://$ALB_DNS/api/submissions" | jq '.[] | select(.name=="ALB Test User")' 2>/dev/null)

if [ -n "$NEW_SUBMISSION" ]; then
    echo "   ✅ Form submission successful and data saved"
else
    echo "   ❌ Form submission failed or data not saved"
fi

# Test 4: Admin page accessibility
echo "4. Testing admin page..."
ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/admin.html")
echo "   Admin page status: $ADMIN_STATUS"

if [ "$ADMIN_STATUS" = "200" ]; then
    echo "   ✅ Admin page accessible"
else
    echo "   ❌ Admin page not accessible (HTTP $ADMIN_STATUS)"
fi

# Test 5: Load testing with multiple concurrent requests
echo "5. Testing with multiple concurrent requests..."
for i in {1..10}; do
    (curl -s -o /dev/null -w "%{http_code}\n" "http://$ALB_DNS/" &)
done | sort | uniq -c

# Test 6: Database consistency test
echo "6. Testing database consistency..."
INITIAL_COUNT=$(curl -s "http://$ALB_DNS/api/submissions" | jq length 2>/dev/null || echo "0")

# Submit multiple entries
for i in {1..3}; do
    curl -s -X POST "http://$ALB_DNS/api/submissions" \
        -H "Content-Type: application/json" \
        -d "{\"name\":\"Consistency Test $i\",\"email\":\"test$i@example.com\",\"message\":\"Testing database consistency $i\"}" > /dev/null
done

sleep 3
FINAL_COUNT=$(curl -s "http://$ALB_DNS/api/submissions" | jq length 2>/dev/null || echo "0")

echo "   Initial count: $INITIAL_COUNT"
echo "   Final count: $FINAL_COUNT"
echo "   Expected increase: 3"

if [ "$FINAL_COUNT" -gt "$INITIAL_COUNT" ]; then
    echo "   ✅ Database consistency maintained"
else
    echo "   ❌ Database consistency issue detected"
fi

echo "=== Testing completed ==="
EOF

chmod +x comprehensive-test.sh

# Run comprehensive testing
source lab-config.sh
load_resource_ids

echo "Running comprehensive application testing..."
./comprehensive-test.sh "$ALB_DNS"
```

### 6.2 Performance and Load Testing

**Basic performance testing:**
```bash
# Create performance testing script
cat > performance-test.sh << 'EOF'
#!/bin/bash
ALB_DNS="$1"

if [ -z "$ALB_DNS" ]; then
    echo "Usage: $0 <ALB_DNS_NAME>"
    exit 1
fi

echo "=== Performance Testing ==="

# Check if Apache Bench is available
if ! command -v ab &> /dev/null; then
    echo "Installing Apache Bench..."
    sudo apt-get update -qq
    sudo apt-get install -y apache2-utils
fi

# Test 1: Basic load test
echo "1. Basic load test (100 requests, 10 concurrent)..."
ab -n 100 -c 10 "http://$ALB_DNS/" | grep -E "(Requests per second|Time per request|Failed requests)"

# Test 2: API load test
echo "2. API load test (50 requests, 5 concurrent)..."
ab -n 50 -c 5 "http://$ALB_DNS/api/submissions" | grep -E "(Requests per second|Time per request|Failed requests)"

# Test 3: Sustained load test
echo "3. Sustained load test (60 seconds, 5 concurrent users)..."
ab -t 60 -c 5 "http://$ALB_DNS/" | grep -E "(Requests per second|Time per request|Failed requests|Complete requests)"

# Test 4: Response time analysis
echo "4. Response time analysis (20 requests)..."
for i in {1..20}; do
    RESPONSE_TIME=$(curl -o /dev/null -s -w "%{time_total}" "http://$ALB_DNS/")
    echo "Request $i: ${RESPONSE_TIME}s"
done | sort -n

echo "=== Performance testing completed ==="
EOF

chmod +x performance-test.sh

# Run performance testing
echo "Running performance testing..."
./performance-test.sh "$ALB_DNS"
```

### 6.3 High Availability Testing (Optional - for multiple instances)

**If you have multiple instances, test failover:**
```bash
# Create failover testing script
cat > test-failover.sh << 'EOF'
#!/bin/bash
ALB_DNS="$1"
TARGET_GROUP_ARN="$2"

if [ -z "$ALB_DNS" ] || [ -z "$TARGET_GROUP_ARN" ]; then
    echo "Usage: $0 <ALB_DNS_NAME> <TARGET_GROUP_ARN>"
    exit 1
fi

echo "=== High Availability Testing ==="

# Get list of healthy targets
echo "1. Current healthy targets:"
aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].[Target.Id,TargetHealth.State]' \
    --output table

HEALTHY_TARGETS=$(aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query 'TargetHealthDescriptions[?TargetHealth.State==`healthy`].Target.Id' \
    --output text)

HEALTHY_COUNT=$(echo $HEALTHY_TARGETS | wc -w)
echo "Number of healthy targets: $HEALTHY_COUNT"

if [ "$HEALTHY_COUNT" -lt 2 ]; then
    echo "⚠️  Need at least 2 healthy targets for failover testing"
    echo "Skipping failover test"
    return 0
fi

# Test continuous availability during simulated failure
echo "2. Testing continuous availability..."
FIRST_TARGET=$(echo $HEALTHY_TARGETS | cut -d' ' -f1)
echo "Will simulate failure of target: $FIRST_TARGET"

# Start continuous testing in background
(
    for i in {1..60}; do
        STATUS=$(curl -s -o /dev/null -w "%{http_code}" "http://$ALB_DNS/")
        echo "$(date '+%H:%M:%S') - HTTP $STATUS"
        sleep 2
    done
) &
CONTINUOUS_TEST_PID=$!

# Wait 10 seconds, then stop the first instance
sleep 10
echo "Stopping instance $FIRST_TARGET..."
aws ec2 stop-instances --instance-ids "$FIRST_TARGET"

# Wait for health checks to detect failure
sleep 60

# Check target health
echo "3. Target health after simulated failure:"
aws elbv2 describe-target-health \
    --target-group-arn "$TARGET_GROUP_ARN" \
    --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
    --output table

# Stop continuous testing
kill $CONTINUOUS_TEST_PID 2>/dev/null

echo "4. Restarting stopped instance..."
aws ec2 start-instances --instance-ids "$FIRST_TARGET"

echo "=== Failover testing completed ==="
echo "Review the continuous availability log above to see if there were any service interruptions"
EOF

chmod +x test-failover.sh

# Note: Only run this if you have multiple instances
echo "Failover testing script created. Run only if you have multiple instances:"
echo "./test-failover.sh $ALB_DNS $TARGET_GROUP_ARN"
```

### 6.4 Security Validation

**Validate security configuration:**
```bash
# Create security validation script
cat > validate-security.sh << 'EOF'
#!/bin/bash
echo "=== Security Configuration Validation ==="

# Load configuration
source lab-config.sh
load_resource_ids

# Test 1: Verify RDS is not publicly accessible
echo "1. Checking RDS public accessibility..."
RDS_PUBLIC=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBInstances[0].PubliclyAccessible' \
    --output text)

if [ "$RDS_PUBLIC" = "False" ]; then
    echo "   ✅ RDS is not publicly accessible"
else
    echo "   ❌ RDS is publicly accessible (security risk)"
fi

# Test 2: Verify RDS is in private subnets
echo "2. Checking RDS subnet placement..."
RDS_SUBNETS=$(aws rds describe-db-instances \
    --db-instance-identifier "$DB_INSTANCE_ID" \
    --query 'DBInstances[0].DBSubnetGroup.Subnets[*].SubnetIdentifier' \
    --output text)

echo "   RDS is in subnets: $RDS_SUBNETS"

for subnet in $RDS_SUBNETS; do
    SUBNET_TYPE=$(aws ec2 describe-subnets \
        --subnet-ids "$subnet" \
        --query 'Subnets[0].Tags[?Key==`Type`].Value' \
        --output text)
    echo "   Subnet $subnet type: $SUBNET_TYPE"
done

# Test 3: Verify security group rules
echo "3. Checking security group configurations..."

echo "   ALB Security Group ($ALB_SG):"
aws ec2 describe-security-groups \
    --group-ids "$ALB_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,IpRanges[0].CidrIp]' \
    --output table

echo "   EC2 Security Group ($EC2_SG):"
aws ec2 describe-security-groups \
    --group-ids "$EC2_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,UserIdGroupPairs[0].GroupId,IpRanges[0].CidrIp]' \
    --output table

echo "   RDS Security Group ($RDS_SG):"
aws ec2 describe-security-groups \
    --group-ids "$RDS_SG" \
    --query 'SecurityGroups[0].IpPermissions[*].[IpProtocol,FromPort,ToPort,UserIdGroupPairs[0].GroupId]' \
    --output table

# Test 4: Test direct database access (should fail from internet)
echo "4. Testing direct database access from internet (should fail)..."
timeout 10 nc -zv "$RDS_ENDPOINT" 3306 2>&1 | grep -q "Connection refused\|timed out"
if [ $? -eq 0 ]; then
    echo "   ✅ Direct database access from internet is blocked"
else
    echo "   ❌ Direct database access from internet is possible (security risk)"
fi

# Test 5: Verify HTTPS redirect (if configured)
echo "5. Testing HTTPS configuration..."
HTTPS_STATUS=$(curl -s -o /dev/null -w "%{http_code}" "https://$ALB_DNS/" 2>/dev/null || echo "000")
if [ "$HTTPS_STATUS" = "200" ]; then
    echo "   ✅ HTTPS is configured and working"
elif [ "$HTTPS_STATUS" = "000" ]; then
    echo "   ℹ️  HTTPS not configured (acceptable for learning lab)"
else
    echo "   ⚠️  HTTPS returns HTTP $HTTPS_STATUS"
fi

echo "=== Security validation completed ==="
EOF

chmod +x validate-security.sh

# Run security validation
echo "Running security validation..."
./validate-security.sh
```

### 6.5 Monitoring and Observability

**Set up basic monitoring:**
```bash
# Create monitoring setup script
cat > setup-monitoring.sh << 'EOF'
#!/bin/bash
echo "=== Setting Up Basic Monitoring ==="

# Load configuration
source lab-config.sh
load_resource_ids

# Create CloudWatch dashboard
echo "1. Creating CloudWatch dashboard..."
DASHBOARD_BODY=$(cat << DASHBOARD_EOF
{
    "widgets": [
        {
            "type": "metric",
            "x": 0,
            "y": 0,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/ApplicationELB", "RequestCount", "LoadBalancer", "$(echo $ALB_ARN | cut -d'/' -f2-)" ],
                    [ ".", "TargetResponseTime", ".", "." ],
                    [ ".", "HTTPCode_Target_2XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_4XX_Count", ".", "." ],
                    [ ".", "HTTPCode_Target_5XX_Count", ".", "." ]
                ],
                "period": 300,
                "stat": "Sum",
                "region": "$AWS_DEFAULT_REGION",
                "title": "ALB Metrics"
            }
        },
        {
            "type": "metric",
            "x": 0,
            "y": 6,
            "width": 12,
            "height": 6,
            "properties": {
                "metrics": [
                    [ "AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", "$DB_INSTANCE_ID" ],
                    [ ".", "DatabaseConnections", ".", "." ],
                    [ ".", "ReadIOPS", ".", "." ],
                    [ ".", "WriteIOPS", ".", "." ]
                ],
                "period": 300,
                "stat": "Average",
                "region": "$AWS_DEFAULT_REGION",
                "title": "RDS Metrics"
            }
        }
    ]
}
DASHBOARD_EOF
)

aws cloudwatch put-dashboard \
    --dashboard-name "$PROJECT_NAME-dashboard" \
    --dashboard-body "$DASHBOARD_BODY"

if [ $? -eq 0 ]; then
    echo "   ✅ CloudWatch dashboard created: $PROJECT_NAME-dashboard"
else
    echo "   ❌ Failed to create CloudWatch dashboard"
fi

# Create basic alarms
echo "2. Creating CloudWatch alarms..."

# ALB high response time alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "$PROJECT_NAME-high-response-time" \
    --alarm-description "ALB response time is high" \
    --metric-name TargetResponseTime \
    --namespace AWS/ApplicationELB \
    --statistic Average \
    --period 300 \
    --threshold 2.0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=LoadBalancer,Value="$(echo $ALB_ARN | cut -d'/' -f2-)" \
    --tags Key=Project,Value="$PROJECT_NAME"

# RDS high CPU alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "$PROJECT_NAME-rds-high-cpu" \
    --alarm-description "RDS CPU utilization is high" \
    --metric-name CPUUtilization \
    --namespace AWS/RDS \
    --statistic Average \
    --period 300 \
    --threshold 80.0 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --dimensions Name=DBInstanceIdentifier,Value="$DB_INSTANCE_ID" \
    --tags Key=Project,Value="$PROJECT_NAME"

echo "   ✅ CloudWatch alarms created"

echo "3. Monitoring URLs:"
echo "   CloudWatch Dashboard: https://$AWS_DEFAULT_REGION.console.aws.amazon.com/cloudwatch/home?region=$AWS_DEFAULT_REGION#dashboards:name=$PROJECT_NAME-dashboard"
echo "   ALB Metrics: https://$AWS_DEFAULT_REGION.console.aws.amazon.com/ec2/v2/home?region=$AWS_DEFAULT_REGION#LoadBalancers:search=$ALB_NAME"
echo "   RDS Metrics: https://$AWS_DEFAULT_REGION.console.aws.amazon.com/rds/home?region=$AWS_DEFAULT_REGION#database:id=$DB_INSTANCE_ID;is-cluster=false"

echo "=== Monitoring setup completed ==="
EOF

chmod +x setup-monitoring.sh

# Run monitoring setup
echo "Setting up monitoring..."
./setup-monitoring.sh
```

### 6.6 Final Validation Checklist

**Create final validation checklist:**
```bash
# Create validation checklist
cat > final-validation.sh << 'EOF'
#!/bin/bash
echo "=== Final Validation Checklist ==="

# Load configuration
source lab-config.sh
load_resource_ids

VALIDATION_PASSED=0
VALIDATION_TOTAL=0

# Function to check and report
check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    VALIDATION_TOTAL=$((VALIDATION_TOTAL + 1))
    echo -n "[$VALIDATION_TOTAL] $description... "
    
    result=$(eval "$command" 2>/dev/null)
    if [ "$result" = "$expected" ] || [[ "$result" =~ $expected ]]; then
        echo "✅ PASS"
        VALIDATION_PASSED=$((VALIDATION_PASSED + 1))
    else
        echo "❌ FAIL (got: $result, expected: $expected)"
    fi
}

echo "Validating 3-Tier Application Deployment..."
echo ""

# Infrastructure checks
check_item "VPC exists and is available" \
    "aws ec2 describe-vpcs --vpc-ids $VPC_ID --query 'Vpcs[0].State' --output text" \
    "available"

check_item "Public subnets exist" \
    "aws ec2 describe-subnets --subnet-ids $PUBLIC_SUBNET_1 --query 'length(Subnets)' --output text" \
    "1"

check_item "Private subnets exist" \
    "aws ec2 describe-subnets --subnet-ids $PRIVATE_SUBNET_1 --query 'length(Subnets)' --output text" \
    "2"

check_item "ALB is active" \
    "aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN --query 'LoadBalancers[0].State.Code' --output text" \
    "active"

check_item "RDS is available" \
    "aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].DBInstanceStatus' --output text" \
    "available"

check_item "Target is healthy" \
    "aws elbv2 describe-target-health --target-group-arn $TARGET_GROUP_ARN --query 'TargetHealthDescriptions[0].TargetHealth.State' --output text" \
    "healthy"

# Application functionality checks
check_item "Main page accessible via ALB" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_DNS/" \
    "200"

check_item "API endpoint accessible via ALB" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_DNS/api/submissions" \
    "200"

check_item "Admin page accessible via ALB" \
    "curl -s -o /dev/null -w '%{http_code}' http://$ALB_DNS/admin.html" \
    "200"

# Security checks
check_item "RDS is not publicly accessible" \
    "aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID --query 'DBInstances[0].PubliclyAccessible' --output text" \
    "False"

check_item "RDS security group allows only EC2 access" \
    "aws ec2 describe-security-groups --group-ids $RDS_SG --query 'SecurityGroups[0].IpPermissions[0].UserIdGroupPairs[0].GroupId' --output text" \
    "$EC2_SG"

# Database functionality check
SUBMISSION_TEST=$(curl -s -X POST "http://$ALB_DNS/api/submissions" \
    -H "Content-Type: application/json" \
    -d '{"name":"Validation Test","email":"validation@example.com","message":"Final validation test"}' \
    -w "%{http_code}")

check_item "Form submission works" \
    "echo '$SUBMISSION_TEST'" \
    "200"

# Summary
echo ""
echo "=== Validation Summary ==="
echo "Passed: $VALIDATION_PASSED/$VALIDATION_TOTAL tests"

if [ "$VALIDATION_PASSED" -eq "$VALIDATION_TOTAL" ]; then
    echo "🎉 ALL VALIDATIONS PASSED!"
    echo ""
    echo "Your 3-tier application is successfully deployed and working!"
    echo "🌐 Application URL: http://$ALB_DNS"
    echo "📊 Admin Panel: http://$ALB_DNS/admin.html (admin/admin123)"
    echo "🔗 API Endpoint: http://$ALB_DNS/api/submissions"
else
    echo "⚠️  Some validations failed. Please review and fix the issues above."
fi

echo ""
echo "=== Architecture Summary ==="
echo "✅ VPC with public and private subnets across 2 AZs"
echo "✅ Application Load Balancer for high availability"
echo "✅ EC2 instances in public subnets (web tier)"
echo "✅ RDS MySQL in private subnets (database tier)"
echo "✅ Security groups with least privilege access"
echo "✅ Network ACLs configured for database connectivity"
echo "✅ CloudWatch monitoring and alarms"
EOF

chmod +x final-validation.sh

# Run final validation
echo "Running final validation..."
./final-validation.sh
```

> **🎯 Success Criteria:**
> - All validation tests pass
> - Application accessible via ALB DNS name
> - Database connectivity working through RDS
> - Security groups properly configured
> - No direct internet access to database
> - Health checks passing
> - Form submissions saving to RDS database
## Step 7: Resource Cleanup (Important!)

> ⚠️ **Cost Management**: After completing this learning lab, it's crucial to clean up resources to avoid ongoing charges. Follow this section carefully to ensure all billable resources are properly deleted.

### 7.1 Pre-Cleanup Verification and Documentation

**Document your working application:**
```bash
# Create documentation script
cat > document-deployment.sh << 'EOF'
#!/bin/bash
echo "=== Documenting Deployment Before Cleanup ==="

# Load configuration
source lab-config.sh
load_resource_ids

# Create documentation directory
mkdir -p deployment-documentation
cd deployment-documentation

# Take screenshots of working application (manual step)
echo "📸 MANUAL STEP: Take screenshots of:"
echo "   1. Main application: http://$ALB_DNS"
echo "   2. Admin panel: http://$ALB_DNS/admin.html"
echo "   3. API response: http://$ALB_DNS/api/submissions"
echo "   4. AWS Console showing ALB, RDS, and EC2 resources"
echo ""

# Document final test
echo "🧪 Final functionality test:"
curl -s "http://$ALB_DNS/" | grep -o '<title>.*</title>' > final-test.txt
curl -s "http://$ALB_DNS/api/submissions" | jq length >> final-test.txt 2>/dev/null || echo "API accessible" >> final-test.txt

# Document architecture
cat > architecture-summary.txt << ARCH_EOF
3-Tier Application Architecture Summary
=====================================

Deployment Date: $(date)
AWS Region: $AWS_DEFAULT_REGION
Project: $PROJECT_NAME

Infrastructure Components:
- VPC: $VPC_ID ($VPC_CIDR)
- Public Subnets: $PUBLIC_SUBNET_1
- Private Subnets: $PRIVATE_SUBNET_1
- Application Load Balancer: $ALB_DNS
- RDS Database: $RDS_ENDPOINT
- EC2 Instance: $CURRENT_INSTANCE_ID

Security Groups:
- ALB Security Group: $ALB_SG
- EC2 Security Group: $EC2_SG  
- RDS Security Group: $RDS_SG

Application URLs:
- Main Application: http://$ALB_DNS
- Admin Panel: http://$ALB_DNS/admin.html
- API Endpoint: http://$ALB_DNS/api/submissions

Key Achievements:
✅ Decoupled database tier using Amazon RDS
✅ Load balancer for high availability
✅ Network security with proper isolation
✅ Managed database with automated backups
✅ Scalable architecture foundation
ARCH_EOF

# Save resource IDs for reference
cp ../resource-ids.txt ./resource-ids-backup.txt

echo "✅ Documentation saved to deployment-documentation/"
echo "📁 Files created:"
ls -la

cd ..
EOF

chmod +x document-deployment.sh

# Run documentation
echo "Creating deployment documentation..."
./document-deployment.sh
```

### 7.2 Automated Cleanup Script

**Create comprehensive cleanup script:**
```bash
# Create automated cleanup script
cat > cleanup-resources.sh << 'EOF'
#!/bin/bash
echo "=== 3-Tier Application Resource Cleanup ==="
echo "⚠️  This will delete billable AWS resources!"
echo ""

# Load configuration
source lab-config.sh
load_resource_ids

# Function to confirm deletion
confirm_deletion() {
    local resource_type="$1"
    echo -n "Delete $resource_type? (y/N): "
    read -r response
    if [[ "$response" =~ ^[Yy]$ ]]; then
        return 0
    else
        echo "Skipping $resource_type deletion"
        return 1
    fi
}

# Function to wait for resource deletion
wait_for_deletion() {
    local check_command="$1"
    local resource_name="$2"
    local timeout="${3:-300}"
    
    echo "Waiting for $resource_name deletion..."
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        if ! eval "$check_command" &>/dev/null; then
            echo "✅ $resource_name deleted successfully"
            return 0
        fi
        sleep 10
        elapsed=$((elapsed + 10))
        echo "  Still waiting... (${elapsed}s)"
    done
    echo "⚠️  Timeout waiting for $resource_name deletion"
    return 1
}

# Estimate cost savings
echo "=== Estimated Monthly Cost Savings ==="
echo "💰 Application Load Balancer: ~\$16/month"
echo "💰 RDS MySQL (db.t3.micro): ~\$12/month"
echo "💰 Additional EC2 instances: ~\$8.50/month each"
echo "💰 Total estimated savings: ~\$35-45/month"
echo ""

# Confirm cleanup
echo "Do you want to proceed with resource cleanup? (y/N)"
read -r PROCEED

if [[ ! "$PROCEED" =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled"
    exit 0
fi

# 1. Delete Application Load Balancer
if [ -n "$ALB_ARN" ] && confirm_deletion "Application Load Balancer"; then
    echo "Deleting Application Load Balancer..."
    aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN"
    
    if [ $? -eq 0 ]; then
        echo "✅ ALB deletion initiated"
        wait_for_deletion "aws elbv2 describe-load-balancers --load-balancer-arns $ALB_ARN" "ALB" 300
    else
        echo "❌ Failed to delete ALB"
    fi
fi

# 2. Delete Target Group
if [ -n "$TARGET_GROUP_ARN" ] && confirm_deletion "Target Group"; then
    echo "Deleting Target Group..."
    aws elbv2 delete-target-group --target-group-arn "$TARGET_GROUP_ARN"
    
    if [ $? -eq 0 ]; then
        echo "✅ Target Group deleted"
    else
        echo "❌ Failed to delete Target Group"
    fi
fi

# 3. Delete RDS Instance
if [ -n "$DB_INSTANCE_ID" ] && confirm_deletion "RDS Database Instance"; then
    echo "Deleting RDS instance..."
    echo "⚠️  This will permanently delete your database!"
    echo -n "Type 'DELETE' to confirm: "
    read -r DELETE_CONFIRM
    
    if [ "$DELETE_CONFIRM" = "DELETE" ]; then
        aws rds delete-db-instance \
            --db-instance-identifier "$DB_INSTANCE_ID" \
            --skip-final-snapshot \
            --delete-automated-backups
        
        if [ $? -eq 0 ]; then
            echo "✅ RDS deletion initiated (this will take 5-10 minutes)"
            wait_for_deletion "aws rds describe-db-instances --db-instance-identifier $DB_INSTANCE_ID" "RDS instance" 600
        else
            echo "❌ Failed to delete RDS instance"
        fi
    else
        echo "RDS deletion cancelled"
    fi
fi

# 4. Delete DB Subnet Group
if [ -n "$DB_SUBNET_GROUP_NAME" ] && confirm_deletion "DB Subnet Group"; then
    echo "Deleting DB Subnet Group..."
    aws rds delete-db-subnet-group --db-subnet-group-name "$DB_SUBNET_GROUP_NAME"
    
    if [ $? -eq 0 ]; then
        echo "✅ DB Subnet Group deleted"
    else
        echo "❌ Failed to delete DB Subnet Group (may still be in use)"
    fi
fi

# 5. Terminate additional EC2 instances (keep original from Stage 1)
echo "Checking for additional EC2 instances to terminate..."
ADDITIONAL_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=3-tier-app-instance-2,3-tier-app-instance-3" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[*].Instances[*].InstanceId' \
    --output text)

if [ -n "$ADDITIONAL_INSTANCES" ] && confirm_deletion "Additional EC2 Instances"; then
    echo "Terminating additional instances: $ADDITIONAL_INSTANCES"
    aws ec2 terminate-instances --instance-ids $ADDITIONAL_INSTANCES
    
    if [ $? -eq 0 ]; then
        echo "✅ Additional instances termination initiated"
        wait_for_deletion "aws ec2 describe-instances --instance-ids $ADDITIONAL_INSTANCES --query 'Reservations[*].Instances[?State.Name!=\`terminated\`]' --output text" "additional instances" 300
    else
        echo "❌ Failed to terminate additional instances"
    fi
fi

# 6. Delete custom AMI and snapshots
AMI_ID=$(aws ec2 describe-images --owners self --filters "Name=name,Values=3-tier-app-ami" --query 'Images[0].ImageId' --output text 2>/dev/null)
if [ "$AMI_ID" != "None" ] && [ -n "$AMI_ID" ] && confirm_deletion "Custom AMI and Snapshots"; then
    echo "Deleting custom AMI and snapshots..."
    
    # Get snapshot ID before deregistering AMI
    SNAPSHOT_ID=$(aws ec2 describe-images --image-ids "$AMI_ID" --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text 2>/dev/null)
    
    # Deregister AMI
    aws ec2 deregister-image --image-id "$AMI_ID"
    echo "✅ AMI deregistered: $AMI_ID"
    
    # Delete associated snapshot
    if [ "$SNAPSHOT_ID" != "None" ] && [ -n "$SNAPSHOT_ID" ]; then
        aws ec2 delete-snapshot --snapshot-id "$SNAPSHOT_ID"
        echo "✅ Snapshot deleted: $SNAPSHOT_ID"
    fi
fi

# 7. Delete Security Groups (in correct order)
echo "Deleting security groups..."

# Delete RDS security group first
if [ -n "$RDS_SG" ] && confirm_deletion "RDS Security Group"; then
    aws ec2 delete-security-group --group-id "$RDS_SG" 2>/dev/null && echo "✅ RDS security group deleted" || echo "⚠️  Could not delete RDS security group (may still be in use)"
fi

# Delete ALB security group
if [ -n "$ALB_SG" ] && confirm_deletion "ALB Security Group"; then
    aws ec2 delete-security-group --group-id "$ALB_SG" 2>/dev/null && echo "✅ ALB security group deleted" || echo "⚠️  Could not delete ALB security group (may still be in use)"
fi

# Delete EC2 security group (only if not in use by original instance)
if [ -n "$EC2_SG" ]; then
    INSTANCES_USING_SG=$(aws ec2 describe-instances --filters "Name=instance.group-id,Values=$EC2_SG" "Name=instance-state-name,Values=running" --query 'Reservations[*].Instances[*].InstanceId' --output text)
    
    if [ -z "$INSTANCES_USING_SG" ] && confirm_deletion "EC2 Security Group"; then
        aws ec2 delete-security-group --group-id "$EC2_SG" 2>/dev/null && echo "✅ EC2 security group deleted" || echo "⚠️  Could not delete EC2 security group"
    else
        echo "ℹ️  Keeping EC2 security group (still in use by: $INSTANCES_USING_SG)"
    fi
fi

# 8. Delete additional subnets (keep original from Stage 1)
if confirm_deletion "Additional Subnets"; then
    echo "Deleting additional subnets..."
    
    # Only delete if they're not the default/original subnets
    for subnet in "$PRIVATE_SUBNET_1" ; do
        if [ -n "$subnet" ]; then
            aws ec2 delete-subnet --subnet-id "$subnet" 2>/dev/null && echo "✅ Deleted subnet: $subnet" || echo "⚠️  Could not delete subnet: $subnet"
        fi
    done
fi

# 9. Delete additional route tables
if confirm_deletion "Additional Route Tables"; then
    echo "Deleting additional route tables..."
    
    for rt in "$PUBLIC_RT" "$PRIVATE_RT"; do
        if [ -n "$rt" ] && [ "$rt" != "$MAIN_RT" ]; then
            aws ec2 delete-route-table --route-table-id "$rt" 2>/dev/null && echo "✅ Deleted route table: $rt" || echo "⚠️  Could not delete route table: $rt"
        fi
    done
fi

# 10. Delete CloudWatch alarms and dashboard
if confirm_deletion "CloudWatch Monitoring Resources"; then
    echo "Deleting CloudWatch resources..."
    
    # Delete alarms
    aws cloudwatch delete-alarms --alarm-names "$PROJECT_NAME-high-response-time" "$PROJECT_NAME-rds-high-cpu" 2>/dev/null && echo "✅ CloudWatch alarms deleted"
    
    # Delete dashboard
    aws cloudwatch delete-dashboards --dashboard-names "$PROJECT_NAME-dashboard" 2>/dev/null && echo "✅ CloudWatch dashboard deleted"
fi

echo ""
echo "=== Cleanup Summary ==="
echo "✅ Cleanup process completed"
echo ""
echo "Resources that should be deleted:"
echo "  - Application Load Balancer (~\$16/month saved)"
echo "  - RDS Database Instance (~\$12/month saved)"
echo "  - Additional EC2 instances (~\$8.50/month each saved)"
echo "  - Custom AMI and snapshots"
echo "  - Additional security groups"
echo "  - CloudWatch alarms and dashboard"
echo ""
echo "Resources kept from Stage 1:"
echo "  - Original VPC and basic networking"
echo "  - Original EC2 instance (if still needed)"
echo "  - Original security group"
echo "  - SSH key pair"
echo ""
echo "⚠️  Please verify in AWS Console that resources are deleted"
echo "💰 Check your billing dashboard to confirm cost reductions"
EOF

chmod +x cleanup-resources.sh
```

### 7.3 Manual Cleanup Verification

**Create verification script:**
```bash
# Create cleanup verification script
cat > verify-cleanup.sh << 'EOF'
#!/bin/bash
echo "=== Cleanup Verification ==="

# Load configuration
source lab-config.sh
load_resource_ids

echo "Checking for remaining billable resources..."
echo ""

# Check ALB
echo "1. Application Load Balancers:"
ALB_COUNT=$(aws elbv2 describe-load-balancers --query 'length(LoadBalancers)' --output text 2>/dev/null || echo "0")
if [ "$ALB_COUNT" = "0" ]; then
    echo "   ✅ No load balancers found"
else
    echo "   ⚠️  Found $ALB_COUNT load balancer(s):"
    aws elbv2 describe-load-balancers --query 'LoadBalancers[*].[LoadBalancerName,State.Code]' --output table
fi

# Check RDS
echo "2. RDS Instances:"
RDS_COUNT=$(aws rds describe-db-instances --query 'length(DBInstances)' --output text 2>/dev/null || echo "0")
if [ "$RDS_COUNT" = "0" ]; then
    echo "   ✅ No RDS instances found"
else
    echo "   ⚠️  Found $RDS_COUNT RDS instance(s):"
    aws rds describe-db-instances --query 'DBInstances[*].[DBInstanceIdentifier,DBInstanceStatus]' --output table
fi

# Check EC2 instances
echo "3. Running EC2 Instances:"
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[*].Instances[*].[InstanceId,InstanceType,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output table

# Check EBS snapshots
echo "4. Custom EBS Snapshots:"
SNAPSHOT_COUNT=$(aws ec2 describe-snapshots --owner-ids self --query 'length(Snapshots)' --output text 2>/dev/null || echo "0")
if [ "$SNAPSHOT_COUNT" = "0" ]; then
    echo "   ✅ No custom snapshots found"
else
    echo "   ⚠️  Found $SNAPSHOT_COUNT custom snapshot(s):"
    aws ec2 describe-snapshots --owner-ids self --query 'Snapshots[*].[SnapshotId,Description,State,VolumeSize]' --output table
fi

# Check AMIs
echo "5. Custom AMIs:"
AMI_COUNT=$(aws ec2 describe-images --owners self --query 'length(Images)' --output text 2>/dev/null || echo "0")
if [ "$AMI_COUNT" = "0" ]; then
    echo "   ✅ No custom AMIs found"
else
    echo "   ⚠️  Found $AMI_COUNT custom AMI(s):"
    aws ec2 describe-images --owners self --query 'Images[*].[ImageId,Name,State]' --output table
fi

# Check NAT Gateways (expensive if accidentally created)
echo "6. NAT Gateways:"
NAT_COUNT=$(aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'length(NatGateways)' --output text 2>/dev/null || echo "0")
if [ "$NAT_COUNT" = "0" ]; then
    echo "   ✅ No NAT gateways found"
else
    echo "   ⚠️  Found $NAT_COUNT NAT gateway(s) (expensive!):"
    aws ec2 describe-nat-gateways --filter "Name=state,Values=available" --query 'NatGateways[*].[NatGatewayId,State,SubnetId]' --output table
fi

# Estimate remaining costs
echo ""
echo "=== Estimated Remaining Monthly Costs ==="
REMAINING_INSTANCES=$(aws ec2 describe-instances --filters "Name=instance-state-name,Values=running" --query 'length(Reservations[*].Instances[*])' --output text)
echo "💰 Running EC2 instances: $REMAINING_INSTANCES × ~\$8.50 = ~\$$(($REMAINING_INSTANCES * 8))50/month"

if [ "$RDS_COUNT" -gt 0 ]; then
    echo "💰 RDS instances: $RDS_COUNT × ~\$12 = ~\$$(($RDS_COUNT * 12))/month"
fi

if [ "$ALB_COUNT" -gt 0 ]; then
    echo "💰 Load balancers: $ALB_COUNT × ~\$16 = ~\$$(($ALB_COUNT * 16))/month"
fi

if [ "$NAT_COUNT" -gt 0 ]; then
    echo "💰 NAT gateways: $NAT_COUNT × ~\$45 = ~\$$(($NAT_COUNT * 45))/month"
fi

echo ""
echo "=== Cleanup Verification Complete ==="
echo "🔍 Review the resources above"
echo "💰 Check your AWS billing dashboard for cost confirmation"
echo "📧 Consider setting up billing alerts for future deployments"
EOF

chmod +x verify-cleanup.sh

# Run verification
echo "Running cleanup verification..."
./verify-cleanup.sh
```

### 7.4 Cost Monitoring Setup

**Set up billing alerts:**
```bash
# Create billing alert setup script
cat > setup-billing-alerts.sh << 'EOF'
#!/bin/bash
echo "=== Setting Up Billing Alerts ==="

# Check if billing alerts are enabled
BILLING_ENABLED=$(aws cloudwatch describe-alarms --alarm-names "billing-alert-*" --query 'length(MetricAlarms)' --output text 2>/dev/null || echo "0")

echo "Setting up billing alert for learning account..."
echo -n "Enter your email for billing alerts: "
read -r EMAIL

echo -n "Enter monthly budget threshold (e.g., 20 for \$20): "
read -r THRESHOLD

# Create SNS topic for billing alerts
TOPIC_ARN=$(aws sns create-topic --name billing-alerts --query 'TopicArn' --output text)
echo "Created SNS topic: $TOPIC_ARN"

# Subscribe email to topic
aws sns subscribe --topic-arn "$TOPIC_ARN" --protocol email --notification-endpoint "$EMAIL"
echo "✅ Email subscription created (check your email to confirm)"

# Create billing alarm
aws cloudwatch put-metric-alarm \
    --alarm-name "billing-alert-$THRESHOLD" \
    --alarm-description "Billing alert when charges exceed \$$THRESHOLD" \
    --metric-name EstimatedCharges \
    --namespace AWS/Billing \
    --statistic Maximum \
    --period 86400 \
    --threshold "$THRESHOLD" \
    --comparison-operator GreaterThanThreshold \
    --dimensions Name=Currency,Value=USD \
    --evaluation-periods 1 \
    --alarm-actions "$TOPIC_ARN" \
    --region us-east-1

echo "✅ Billing alarm created for \$$THRESHOLD threshold"
echo "📧 You will receive email alerts if monthly charges exceed \$$THRESHOLD"
EOF

chmod +x setup-billing-alerts.sh

echo ""
echo "To set up billing alerts for future deployments:"
echo "./setup-billing-alerts.sh"
```

### 7.5 Final Cleanup Summary

**Create final summary:**
```bash
echo "=== Final Cleanup Instructions ==="
echo ""
echo "🧹 To clean up all resources:"
echo "   ./cleanup-resources.sh"
echo ""
echo "🔍 To verify cleanup completion:"
echo "   ./verify-cleanup.sh"
echo ""
echo "💰 To set up billing alerts:"
echo "   ./setup-billing-alerts.sh"
echo ""
echo "📁 Your deployment documentation is saved in:"
echo "   deployment-documentation/"
echo ""
echo "=== What Gets Deleted vs. Kept ==="
echo ""
echo "✅ DELETED (saves ~\$35-45/month):"
echo "   - Application Load Balancer"
echo "   - RDS Database Instance"
echo "   - Additional EC2 instances"
echo "   - Custom AMI and snapshots"
echo "   - Additional security groups"
echo "   - Additional subnets and route tables"
echo "   - CloudWatch alarms and dashboard"
echo ""
echo "✅ KEPT (from Stage 1):"
echo "   - Original VPC and basic networking"
echo "   - Original EC2 instance (if still needed)"
echo "   - Original security group"
echo "   - SSH key pair"
echo ""
echo "⚠️  IMPORTANT REMINDERS:"
echo "   1. Run cleanup scripts to avoid ongoing charges"
echo "   2. Verify cleanup in AWS Console"
echo "   3. Check billing dashboard after cleanup"
echo "   4. Set up billing alerts for future learning"
echo "   5. Keep documentation for your portfolio"
echo ""
echo "🎓 CONGRATULATIONS!"
echo "You've successfully completed the 3-Tier Application"
echo "deployment with AWS RDS and Application Load Balancer!"
```

---

## Conclusion

**🎉 Congratulations!** You've successfully evolved your 3-tier application from a monolithic single-instance deployment to a robust, scalable, and highly available architecture. Your application now features:

### Key Achievements

✨ **Enhanced Reliability**: Load balancer distributes traffic with health checks  
🔐 **Improved Security**: Database isolated in private subnets with proper access controls  
📈 **Better Scalability**: Foundation ready for auto-scaling and additional features  
⚙️ **Reduced Operations**: Managed RDS database reduces maintenance overhead  
🏆 **Production-Ready**: Following AWS best practices for enterprise applications  

### Your Application URLs

Your application is now accessible through the Application Load Balancer:

- **Main Application**: `http://YOUR-ALB-DNS-NAME/`
- **Admin Dashboard**: `http://YOUR-ALB-DNS-NAME/admin.html` (admin/admin123)
- **API Endpoint**: `http://YOUR-ALB-DNS-NAME/api/submissions`

> Replace `YOUR-ALB-DNS-NAME` with your actual ALB DNS name from the `alb-dns-name.txt` file

### What You've Learned

Through this challenge, you've gained hands-on experience with:

- **Amazon RDS**: Managed database service setup and configuration
- **Application Load Balancer**: Traffic distribution and health monitoring  
- **VPC Networking**: Subnets, security groups, and network isolation
- **Network ACLs**: Stateless network security configuration
- **High Availability**: Multi-AZ deployment patterns
- **Security Best Practices**: Least privilege access and network segmentation
- **Database Migration**: Safe data migration from local to managed database
- **Infrastructure Scaling**: Preparing applications for growth
- **Automation**: Using scripts and variables for consistent deployments

### Next Steps for Continued Learning

Your application is now ready for advanced features:

1. **Multi-AZ RDS**: Enable Multi-AZ deployment for production-grade database availability
2. **Auto Scaling**: Implement Auto Scaling Groups for automatic capacity management
3. **SSL/TLS**: Add HTTPS with AWS Certificate Manager
4. **Caching**: Implement ElastiCache for improved performance
5. **Monitoring**: Set up comprehensive CloudWatch dashboards and alarms
6. **CI/CD**: Automate deployments with AWS CodePipeline
7. **Containerization**: Migrate to Amazon ECS or EKS
8. **Serverless**: Explore AWS Lambda for API functions

### Cost Management Reminder

**Don't forget to clean up resources** to avoid ongoing charges:

```bash
# Run the cleanup script
./cleanup-resources.sh

# Verify cleanup completion
./verify-cleanup.sh

# Set up billing alerts for future learning
./setup-billing-alerts.sh
```

Keep building, keep learning, and enjoy your robust, cloud-native application! 🚀

---

*This enhanced guide is part of the DNX Solutions Mentorship Program, designed to build practical AWS skills through hands-on experience with clear instructions, comprehensive error handling, and automated scripts for consistent deployments.*
