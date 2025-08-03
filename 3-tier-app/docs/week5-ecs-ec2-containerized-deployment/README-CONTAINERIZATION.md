# 3-Tier Application Containerization Guide

This guide covers containerizing and deploying the 3-tier application using Docker and AWS ECS with EC2 instances.

## 📋 Table of Contents

- [Architecture Overview](#architecture-overview)
- [Prerequisites](#prerequisites)
- [Local Development](#local-development)
- [AWS ECS Deployment](#aws-ecs-deployment)
- [Configuration](#configuration)
- [Monitoring and Troubleshooting](#monitoring-and-troubleshooting)

## 🏗️ Architecture Overview

### Container Architecture
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx Web     │    │   Node.js API   │    │   MySQL RDS     │
│   (Port 80)     │───▶│   (Port 3000)   │───▶│   (Port 3306)   │
│                 │    │                 │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### AWS ECS EC2 Deployment
- **ECS Cluster**: EC2 instances running Docker containers
- **Application Load Balancer**: Routes traffic to web containers
- **RDS MySQL**: Managed database service
- **ECR**: Container image registry
- **CloudWatch**: Logging and monitoring

## 🔧 Prerequisites

### Local Development
- Docker and Docker Compose
- Node.js 18+ (for local testing)
- MySQL client (optional, for database testing)

### AWS Deployment
- AWS CLI configured with appropriate permissions
- AWS Account with ECS, ECR, RDS, and VPC permissions
- RDS MySQL instance (see RDS setup section)

## 🚀 Local Development

### 1. Environment Setup

Copy and configure the environment file:
```bash
cp .env .env.local
# Edit .env.local with your local settings
```

### 2. Start the Application

```bash
# Start all services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down
```

### 3. Access the Application

- **Web Interface**: http://localhost
- **API Health Check**: http://localhost:3000/health
- **Database**: localhost:3306 (if needed for direct access)

### 4. Development Workflow

```bash
# Rebuild after code changes
docker-compose up --build

# Rebuild specific service
docker-compose up --build api

# View service logs
docker-compose logs api
docker-compose logs web
docker-compose logs db
```

## ☁️ AWS ECS Deployment

### 1. RDS Setup

First, create an RDS MySQL instance:

```bash
# Create RDS subnet group
aws rds create-db-subnet-group \
    --db-subnet-group-name formapp-subnet-group \
    --db-subnet-group-description "Subnet group for FormApp RDS" \
    --subnet-ids subnet-12345678 subnet-87654321

# Create RDS instance
aws rds create-db-instance \
    --db-instance-identifier formapp-db \
    --db-instance-class db.t3.micro \
    --engine mysql \
    --engine-version 8.0.35 \
    --master-username admin \
    --master-user-password YourSecurePassword123! \
    --allocated-storage 20 \
    --db-subnet-group-name formapp-subnet-group \
    --vpc-security-group-ids sg-12345678 \
    --db-name formapp \
    --backup-retention-period 7 \
    --storage-encrypted
```

### 2. ECS Cluster Setup

```bash
# Create ECS cluster
aws ecs create-cluster --cluster-name formapp-cluster

# Create launch template for EC2 instances
aws ec2 create-launch-template \
    --launch-template-name formapp-launch-template \
    --launch-template-data '{
        "ImageId": "ami-0c02fb55956c7d316",
        "InstanceType": "t3.medium",
        "IamInstanceProfile": {"Name": "ecsInstanceRole"},
        "SecurityGroupIds": ["sg-12345678"],
        "UserData": "IyEvYmluL2Jhc2gKZWNobyBFQ1NfQ0xVU1RFUj1mb3JtYXBwLWNsdXN0ZXIgPj4gL2V0Yy9lY3MvZWNzLmNvbmZpZw=="
    }'

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name formapp-asg \
    --launch-template LaunchTemplateName=formapp-launch-template,Version=1 \
    --min-size 1 \
    --max-size 3 \
    --desired-capacity 2 \
    --vpc-zone-identifier "subnet-12345678,subnet-87654321"
```

### 3. Deploy Application

```bash
# Set required environment variables
export RDS_ENDPOINT="your-rds-endpoint.region.rds.amazonaws.com"
export AWS_REGION="us-east-1"

# Run deployment script
./deploy-to-ecs-ec2.sh
```

### 4. Create ECS Service

```bash
# Create Application Load Balancer target group
aws elbv2 create-target-group \
    --name formapp-targets \
    --protocol HTTP \
    --port 80 \
    --vpc-id vpc-12345678 \
    --health-check-path /

# Create ECS service
aws ecs create-service \
    --cluster formapp-cluster \
    --service-name formapp-service \
    --task-definition formapp-task-ec2 \
    --desired-count 2 \
    --launch-type EC2 \
    --load-balancers targetGroupArn=arn:aws:elasticloadbalancing:region:account:targetgroup/formapp-targets/1234567890123456,containerName=formapp-web,containerPort=80
```

## ⚙️ Configuration

### Environment Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `NODE_ENV` | Application environment | `production` | No |
| `PORT` | API server port | `3000` | No |
| `DB_HOST` | Database hostname | `db` | Yes |
| `DB_PORT` | Database port | `3306` | No |
| `DB_NAME` | Database name | `formapp` | Yes |
| `DB_USER` | Database username | `root` | Yes |
| `DB_PASSWORD` | Database password | - | Yes |
| `CORS_ORIGIN` | CORS allowed origins | `*` | No |
| `LOG_LEVEL` | Logging level | `info` | No |

### AWS Secrets Manager

For production deployment, store sensitive data in AWS Secrets Manager:

```bash
# Create database credentials secret
aws secretsmanager create-secret \
    --name formapp/db-credentials \
    --description "Database credentials for FormApp" \
    --secret-string '{"username":"admin","password":"YourSecurePassword123!"}'
```

## 📊 Monitoring and Troubleshooting

### CloudWatch Logs

View application logs:
```bash
# API logs
aws logs tail /ecs/formapp --log-stream-name-prefix api --follow

# Web logs
aws logs tail /ecs/formapp --log-stream-name-prefix web --follow
```

### Health Checks

- **API Health**: `GET /health`
- **Web Health**: `GET /` (returns 200 if nginx is serving)

### Common Issues

1. **Database Connection Issues**
   - Check RDS security group allows connections from ECS
   - Verify RDS endpoint in environment variables
   - Check database credentials in Secrets Manager

2. **Container Startup Issues**
   - Check CloudWatch logs for error messages
   - Verify ECR images are pushed correctly
   - Check ECS task definition configuration

3. **Load Balancer Issues**
   - Verify target group health checks
   - Check security group rules for ALB
   - Ensure containers are registering with target group

### Useful Commands

```bash
# Check ECS service status
aws ecs describe-services --cluster formapp-cluster --services formapp-service

# View running tasks
aws ecs list-tasks --cluster formapp-cluster --service-name formapp-service

# Check task logs
aws ecs describe-tasks --cluster formapp-cluster --tasks TASK_ARN

# Scale service
aws ecs update-service --cluster formapp-cluster --service formapp-service --desired-count 3
```

## 🔄 CI/CD Integration

The deployment script can be integrated into CI/CD pipelines:

```yaml
# Example GitHub Actions workflow
name: Deploy to ECS
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-east-1
      - name: Deploy to ECS
        run: |
          cd src
          export RDS_ENDPOINT=${{ secrets.RDS_ENDPOINT }}
          ./deploy-to-ecs-ec2.sh
```

## 📚 Additional Resources

- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [AWS RDS MySQL Documentation](https://docs.aws.amazon.com/rds/latest/userguide/CHAP_MySQL.html)
- [Application Load Balancer Guide](https://docs.aws.amazon.com/elasticloadbalancing/latest/application/)

---

For questions or issues, refer to the main project documentation or create an issue in the repository.
