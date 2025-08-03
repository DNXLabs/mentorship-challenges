# Week 5 Deployment Guide: ECS EC2 Containerized Deployment

## 🚀 Migrating from EC2 Auto Scaling to ECS Containers

### Overview
This week, we're modernizing your application by migrating from traditional EC2 instances to containerized deployment using Amazon ECS (Elastic Container Service) with EC2 launch type. This approach provides better resource utilization, easier deployments, and improved scalability.

> ⚠️ **Important**: This builds on your existing network infrastructure and RDS database from previous weeks. We'll be decommissioning your ALB and EC2 Auto Scaling Group to replace them with ECS services.

## What We'll Build

**Migration Path**: EC2 Auto Scaling + ALB → ECS EC2 Containers (Direct Access)

- **ECS Cluster** with EC2 instances running Docker containers
- **ECS Services** for automatic container management and scaling
- **Direct internet access** to ECS instances (no load balancer)
- **ECR or Docker Hub** for container image storage
- **CloudWatch** integration for container monitoring

## Prerequisites

✅ **Week 4 completed**: Auto Scaling Group + ALB + RDS working  
✅ **Network infrastructure**: VPC, subnets, security groups configured  
✅ **RDS database**: MySQL instance running and accessible  
✅ **Docker knowledge**: Basic understanding of containers (review containerization docs)  

---

## Architecture Overview

### Before (Week 4):
```
Internet → ALB → Auto Scaling Group (EC2 instances) → RDS
```

### After (Week 5):
```
Internet → ECS Service (Containers on EC2) → RDS
```

### Container Architecture:
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Nginx Web     │    │   Node.js API   │    │   MySQL RDS     │
│   (Port 80)     │───▶│   (Port 3000)   │───▶│   (Port 3306)   │
│   Container      │    │   Container      │    │   (Existing)    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

---

## Step 1: Prepare Container Images

You have two options for container images:

### Option A: Use Pre-built Images (Recommended for Learning)
We'll use the pre-built images from Docker Hub:
- **Web**: `thiago4go/formapp-web:latest`
- **API**: `thiago4go/formapp-api:latest`

### Option B: Build Your Own Images (Advanced)
Follow the containerization guide to build and push your own images to ECR.

For this guide, we'll use **Option A** to focus on ECS deployment concepts.

---

## Step 2: Create IAM Roles for ECS

ECS needs specific IAM roles to function properly.

### Create ECS Task Execution Role:
```bash
# Create the trust policy
cat > ecs-task-execution-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ecs-tasks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
    --role-name ecsTaskExecutionRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach the managed policy
aws iam attach-role-policy \
    --role-name ecsTaskExecutionRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy
```

### Create ECS Task Role (for application permissions):
```bash
# Create task role
aws iam create-role \
    --role-name ecsTaskRole \
    --assume-role-policy-document file://ecs-task-execution-trust-policy.json

# Attach CloudWatch logs policy
aws iam attach-role-policy \
    --role-name ecsTaskRole \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchLogsFullAccess
```

### Create ECS Instance Role:
```bash
# Create instance trust policy
cat > ecs-instance-trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

# Create the role
aws iam create-role \
    --role-name ecsInstanceRole \
    --assume-role-policy-document file://ecs-instance-trust-policy.json

# Attach the managed policy
aws iam attach-role-policy \
    --role-name ecsInstanceRole \
    --policy-arn arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role

# Create instance profile
aws iam create-instance-profile --instance-profile-name ecsInstanceProfile
aws iam add-role-to-instance-profile \
    --instance-profile-name ecsInstanceProfile \
    --role-name ecsInstanceRole
```

---

## Step 3: Create ECS Cluster

### Using AWS Console:
1. **Go to ECS → Clusters → Create Cluster**
2. **Cluster name**: `3tier-app-cluster`
3. **Infrastructure**: Amazon EC2 instances
4. **Operating system**: Amazon Linux 2
5. **EC2 instance type**: `t3.medium` (containers need more resources)
6. **Desired capacity**: `2`
7. **SSH Key pair**: Your existing key pair
8. **VPC**: Select your existing VPC
9. **Subnets**: Select your **public subnets**
10. **Security group**: Create new with the following rules:
    - **HTTP (80)**: 0.0.0.0/0 (for web access)
    - **HTTPS (443)**: 0.0.0.0/0 (for secure web access)
    - **SSH (22)**: Your IP (for management)
    - **Custom TCP (3000)**: 0.0.0.0/0 (for API access - optional)
11. **Auto Scaling**: Enable
12. **Create**

### Using AWS CLI:
```bash
# Create the cluster
aws ecs create-cluster --cluster-name 3tier-app-cluster

# Get your subnet IDs
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=tag:Type,Values=Public" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')

# Create security group for ECS instances
ECS_SG_ID=$(aws ec2 create-security-group \
    --group-name 3tier-app-ecs-sg \
    --description "Security group for ECS instances" \
    --vpc-id $(aws ec2 describe-vpcs --filters "Name=is-default,Values=false" --query 'Vpcs[0].VpcId' --output text) \
    --query 'GroupId' --output text)

# Allow HTTP access from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 80 \
    --cidr 0.0.0.0/0

# Allow HTTPS access from internet
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 443 \
    --cidr 0.0.0.0/0

# Allow SSH access (replace with your IP)
aws ec2 authorize-security-group-ingress \
    --group-id $ECS_SG_ID \
    --protocol tcp \
    --port 22 \
    --cidr YOUR_IP/32

# Create capacity provider (Auto Scaling Group for ECS)
aws ecs create-capacity-provider \
    --name 3tier-app-capacity-provider \
    --auto-scaling-group-provider '{
        "autoScalingGroupArn": "arn:aws:autoscaling:REGION:ACCOUNT:autoScalingGroup:*:autoScalingGroupName/3tier-app-ecs-asg",
        "managedScaling": {
            "status": "ENABLED",
            "targetCapacity": 80,
            "minimumScalingStepSize": 1,
            "maximumScalingStepSize": 4
        },
        "managedTerminationProtection": "DISABLED"
    }'
```

---

## Step 4: Create CloudWatch Log Group

```bash
# Create log group for ECS containers
aws logs create-log-group --log-group-name /ecs/formapp
aws logs put-retention-policy --log-group-name /ecs/formapp --retention-in-days 7
```

---

## Step 5: Create ECS Task Definition

Create a task definition that defines your containers:

```bash
# Get your account ID and region
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION=$(aws configure get region)

# Create task definition file
cat > formapp-task-definition.json << EOF
{
  "family": "formapp-task-ec2",
  "networkMode": "bridge",
  "requiresCompatibilities": ["EC2"],
  "executionRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskExecutionRole",
  "taskRoleArn": "arn:aws:iam::${ACCOUNT_ID}:role/ecsTaskRole",
  "containerDefinitions": [
    {
      "name": "formapp-web",
      "image": "thiago4go/formapp-web:latest",
      "memory": 256,
      "memoryReservation": 128,
      "portMappings": [
        {
          "hostPort": 80,
          "containerPort": 80,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "links": ["formapp-api"],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/formapp",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "web"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "wget -q -O - http://localhost/ || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      },
      "dependsOn": [
        {
          "containerName": "formapp-api",
          "condition": "HEALTHY"
        }
      ]
    },
    {
      "name": "formapp-api",
      "image": "thiago4go/formapp-api:latest",
      "memory": 512,
      "memoryReservation": 256,
      "portMappings": [
        {
          "hostPort": 3000,
          "containerPort": 3000,
          "protocol": "tcp"
        }
      ],
      "essential": true,
      "environment": [
        {
          "name": "NODE_ENV",
          "value": "production"
        },
        {
          "name": "PORT",
          "value": "3000"
        },
        {
          "name": "DB_HOST",
          "value": "YOUR_RDS_ENDPOINT"
        },
        {
          "name": "DB_PORT",
          "value": "3306"
        },
        {
          "name": "DB_NAME",
          "value": "formapp"
        },
        {
          "name": "DB_USER",
          "value": "YOUR_DB_USER"
        },
        {
          "name": "DB_PASSWORD",
          "value": "YOUR_DB_PASSWORD"
        },
        {
          "name": "CORS_ORIGIN",
          "value": "*"
        },
        {
          "name": "LOG_LEVEL",
          "value": "info"
        }
      ],
      "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
          "awslogs-group": "/ecs/formapp",
          "awslogs-region": "${REGION}",
          "awslogs-stream-prefix": "api"
        }
      },
      "healthCheck": {
        "command": [
          "CMD-SHELL",
          "wget -q -O - http://localhost:3000/health || exit 1"
        ],
        "interval": 30,
        "timeout": 5,
        "retries": 3,
        "startPeriod": 60
      }
    }
  ]
}
EOF

# Update with your RDS details
echo "⚠️  IMPORTANT: Update the DB_HOST, DB_USER, and DB_PASSWORD in the task definition file!"
echo "Your RDS endpoint can be found in the AWS Console → RDS → Databases"

# Register the task definition
aws ecs register-task-definition --cli-input-json file://formapp-task-definition.json
```

---

## Step 6: Create ECS Service

Now create the ECS service that will manage your containers without a load balancer:

### Using AWS Console:
1. **Go to ECS → Clusters → 3tier-app-cluster → Services → Create**
2. **Launch type**: EC2
3. **Task definition**: `formapp-task-ec2:1`
4. **Service name**: `formapp-service`
5. **Number of tasks**: `2`
6. **Deployment type**: Rolling update
7. **Load balancing**: **Skip this section** (no load balancer)
8. **Auto Scaling**: Enable
   - **Minimum**: 2
   - **Maximum**: 6
   - **Target tracking**: CPU utilization 70%
9. **Create service**

### Using AWS CLI:
```bash
# Create service without load balancer
aws ecs create-service \
    --cluster 3tier-app-cluster \
    --service-name formapp-service \
    --task-definition formapp-task-ec2:1 \
    --desired-count 2 \
    --launch-type EC2 \
    --deployment-configuration maximumPercent=200,minimumHealthyPercent=50 \
    --enable-execute-command

# Create auto scaling target
aws application-autoscaling register-scalable-target \
    --service-namespace ecs \
    --resource-id service/3tier-app-cluster/formapp-service \
    --scalable-dimension ecs:service:DesiredCount \
    --min-capacity 2 \
    --max-capacity 6

# Create scaling policy
aws application-autoscaling put-scaling-policy \
    --service-namespace ecs \
    --resource-id service/3tier-app-cluster/formapp-service \
    --scalable-dimension ecs:service:DesiredCount \
    --policy-name formapp-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-scaling-policy-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ECSServiceAverageCPUUtilization"
        }
    }'
```

---

## Step 7: Update Security Groups

Ensure your ECS instances can communicate with RDS and accept direct internet traffic:

```bash
# Get ECS cluster security group ID
ECS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=3tier-app-ecs-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# Ensure ECS instances can reach RDS
RDS_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=*rds*" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

# Allow ECS instances to connect to RDS
aws ec2 authorize-security-group-ingress \
    --group-id $RDS_SG_ID \
    --protocol tcp \
    --port 3306 \
    --source-group $ECS_SG_ID

# Verify ECS security group allows HTTP traffic from internet (should already be configured)
aws ec2 describe-security-groups --group-ids $ECS_SG_ID
```

---

## Step 8: Test and Validate

### 1. Check ECS Cluster:
```bash
# Check cluster status
aws ecs describe-clusters --clusters 3tier-app-cluster

# Check service status
aws ecs describe-services --cluster 3tier-app-cluster --services formapp-service

# List running tasks
aws ecs list-tasks --cluster 3tier-app-cluster --service-name formapp-service
```

### 2. Get ECS Instance Public IPs:
```bash
# Get ECS container instance ARNs
CONTAINER_INSTANCES=$(aws ecs list-container-instances \
    --cluster 3tier-app-cluster \
    --query 'containerInstanceArns' \
    --output text)

# Get EC2 instance IDs
for arn in $CONTAINER_INSTANCES; do
    INSTANCE_ID=$(aws ecs describe-container-instances \
        --cluster 3tier-app-cluster \
        --container-instances $arn \
        --query 'containerInstances[0].ec2InstanceId' \
        --output text)
    
    # Get public IP
    PUBLIC_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text)
    
    echo "ECS Instance: $INSTANCE_ID - Public IP: $PUBLIC_IP"
    echo "Access your application at: http://$PUBLIC_IP"
done
```

### 3. Test Application:
- Visit each ECS instance's public IP address in a browser
- Test form submission to verify database connectivity
- Check that the application loads properly on all instances

### 4. Check Container Logs:
```bash
# Get task ARN
TASK_ARN=$(aws ecs list-tasks \
    --cluster 3tier-app-cluster \
    --service-name formapp-service \
    --query 'taskArns[0]' \
    --output text)

# View logs in CloudWatch
aws logs tail /ecs/formapp --follow

# Or use ECS exec to connect to container
aws ecs execute-command \
    --cluster 3tier-app-cluster \
    --task $TASK_ARN \
    --container formapp-web \
    --interactive \
    --command "/bin/bash"
```

### 5. Test Load Distribution:
Since there's no load balancer, you can test each instance individually:
```bash
# Test each instance
for ip in $(aws ec2 describe-instances \
    --filters "Name=tag:aws:ecs:cluster-name,Values=3tier-app-cluster" \
    --query 'Reservations[*].Instances[*].PublicIpAddress' \
    --output text); do
    echo "Testing instance: $ip"
    curl -s http://$ip/ | grep -o '<title>.*</title>'
done
```

---

## Step 9: Decommission Old Infrastructure

Once ECS is working properly, clean up the old infrastructure:

### 1. Remove Old Auto Scaling Group:
```bash
# Scale down to 0
aws autoscaling update-auto-scaling-group \
    --auto-scaling-group-name 3tier-app-asg \
    --desired-capacity 0 \
    --min-size 0

# Wait for instances to terminate, then delete ASG
aws autoscaling delete-auto-scaling-group \
    --auto-scaling-group-name 3tier-app-asg \
    --force-delete
```

### 2. Delete Old Load Balancer and Target Group:
```bash
# Get old ALB ARN
OLD_ALB_ARN=$(aws elbv2 describe-load-balancers \
    --names 3tier-app-alb \
    --query 'LoadBalancers[0].LoadBalancerArn' \
    --output text)

# Get old target group ARN
OLD_TG_ARN=$(aws elbv2 describe-target-groups \
    --names 3tier-app-tg \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Delete old ALB
aws elbv2 delete-load-balancer --load-balancer-arn $OLD_ALB_ARN

# Wait for ALB to be deleted, then delete target group
aws elbv2 delete-target-group --target-group-arn $OLD_TG_ARN
```

### 3. Clean Up Launch Template:
```bash
aws ec2 delete-launch-template --launch-template-name 3tier-app-launch-template
```

### 4. Clean Up Old Security Groups (Optional):
```bash
# Delete old ALB security group if it exists
OLD_ALB_SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=3tier-app-alb-sg" \
    --query 'SecurityGroups[0].GroupId' \
    --output text)

if [ "$OLD_ALB_SG_ID" != "None" ]; then
    aws ec2 delete-security-group --group-id $OLD_ALB_SG_ID
fi
```

---

## Success! 🎉

Your application is now running on ECS with containers and direct internet access! You've achieved:

- ✅ **Containerized Architecture**: Application runs in Docker containers
- ✅ **ECS Management**: Automatic container orchestration and health monitoring
- ✅ **Improved Resource Utilization**: Better density and efficiency
- ✅ **Easier Deployments**: Container-based deployments with rollback capabilities
- ✅ **Auto Scaling**: Service-level scaling based on metrics
- ✅ **Enhanced Monitoring**: Container-specific logs and metrics
- ✅ **Simplified Architecture**: Direct access without load balancer complexity

## What You've Achieved

🚀 **Modern Container Platform**: Your app runs on industry-standard containers  
📦 **Simplified Deployments**: New versions deployed as container images  
🔄 **Rolling Updates**: Zero-downtime deployments with automatic rollback  
📊 **Better Observability**: Container-level monitoring and logging  
💰 **Cost Optimization**: Better resource utilization + no ALB costs  
🎯 **Direct Access**: Simplified architecture with direct instance access  

Your 3-tier application is now running on a modern, containerized platform without the complexity and cost of a load balancer!

---

## Troubleshooting

**Tasks not starting?**
- Check IAM roles and permissions
- Verify task definition JSON syntax
- Check container image availability
- Review CloudWatch logs for errors

**Can't access application via public IP?**
- Verify ECS instances are in public subnets
- Check security group allows HTTP (port 80) from 0.0.0.0/0
- Ensure ECS instances have public IP addresses
- Verify containers are running and healthy

**Containers failing health checks?**
- Check application startup time vs. health check timing
- Verify health check endpoints return 200 status
- Review container logs for application errors
- Ensure proper environment variable configuration

**Database connection issues?**
- Verify RDS security group allows ECS security group access
- Check database credentials in task definition
- Ensure RDS endpoint is correct and accessible
- Test database connectivity from ECS instances

**Multiple instances showing different behavior?**
- Check if all containers have the same configuration
- Verify all instances can reach the database
- Review container logs on each instance
- Ensure consistent environment variables across tasks

**Auto scaling not working?**
- Check CloudWatch metrics are being published
- Verify scaling policy configuration
- Allow 5-10 minutes for scaling actions
- Review ECS service events for scaling activities

## Next Steps

- **Week 6**: Migrate to ECS Fargate (serverless containers)
- **Week 7**: Implement CI/CD pipeline with container deployments
- **Week 8**: Add service mesh and advanced container networking
