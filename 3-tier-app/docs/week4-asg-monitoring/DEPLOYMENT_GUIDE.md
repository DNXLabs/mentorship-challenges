# Week 4 Deployment Guide: Auto Scaling & Advanced Monitoring

## 🚀 Building an Unstoppable, Self-Healing Application

### Overview
Your Week 3 application is already running perfectly with ALB and RDS. Now we'll add Auto Scaling to make it truly production-ready and self-healing.

> ⚠️ **Important**: This builds directly on your Week 3 setup. Make sure your ALB and RDS are working before starting.

## What We'll Add

Building on your existing setup:
- **Auto Scaling Group** to manage multiple instances automatically
- **Launch Template** based on your current working instance
- **CloudWatch Agent** for detailed monitoring and logs
- **Scaling Policies** that respond to traffic automatically

## Prerequisites

✅ **Week 3 completed**: ALB + RDS working  
✅ **Current instance healthy**: Accessible via ALB  
✅ **Database connected**: Application using RDS successfully  

---

## Step 1: Create IAM Role for Auto Scaling Instances

Your new instances need permission to send logs to CloudWatch.

### Using AWS Console:
1. **Go to IAM → Roles → Create Role**
2. **Select**: AWS service → EC2
3. **Add policies**:
   - `CloudWatchAgentServerPolicy`
   - `AmazonSSMManagedInstanceCore`
4. **Role name**: `3tier-app-ec2-role`
5. **Create role**

### Using AWS CLI:
```bash
# Create the role
aws iam create-role \
    --role-name 3tier-app-ec2-role \
    --assume-role-policy-document '{
        "Version": "2012-10-17",
        "Statement": [{
            "Effect": "Allow",
            "Principal": {"Service": "ec2.amazonaws.com"},
            "Action": "sts:AssumeRole"
        }]
    }'

# Attach policies
aws iam attach-role-policy \
    --role-name 3tier-app-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy

aws iam attach-role-policy \
    --role-name 3tier-app-ec2-role \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore

# Create instance profile
aws iam create-instance-profile --instance-profile-name 3tier-app-ec2-profile
aws iam add-role-to-instance-profile \
    --instance-profile-name 3tier-app-ec2-profile \
    --role-name 3tier-app-ec2-role
```

---

## Step 2: Create Launch Template

This tells Auto Scaling how to create new instances identical to your current one.

### Using AWS Console:
1. **Go to EC2 → Launch Templates → Create**
2. **Template name**: `3tier-app-launch-template`
3. **AMI**: Ubuntu Server 24.04 LTS
4. **Instance type**: `t3.micro`
5. **Key pair**: Your existing key pair
6. **Security groups**: Select your existing EC2 security group
7. **IAM instance profile**: `3tier-app-ec2-profile`
8. **User data** (copy this exactly):

```bash
#!/bin/bash
# Update system
apt-get update -y

# Install packages
apt-get install -y nginx nodejs npm mysql-client

# Install PM2
npm install -g pm2

# Create app directory
mkdir -p /opt/3-tier-app/api
cd /opt/3-tier-app

# Copy your existing application code here
# (In production, you'd pull from Git repository)

# Create package.json
cat > api/package.json << 'EOF'
{
  "name": "3tier-app-api",
  "version": "1.0.0",
  "main": "server.js",
  "dependencies": {
    "express": "^4.18.2",
    "mysql2": "^3.6.0",
    "cors": "^2.8.5",
    "dotenv": "^16.3.1",
    "uuid": "^9.0.0"
  }
}
EOF

# Create your server.js (copy from your working instance)
# Create your .env with RDS connection details
# Create your HTML files

# Install dependencies
cd api && npm install && cd ..

# Configure Nginx (copy your working config)
# Start services
systemctl enable nginx
systemctl start nginx

# Start application
cd api
sudo -u ubuntu pm2 start server.js --name formapp-api
sudo -u ubuntu pm2 save
sudo -u ubuntu pm2 startup systemd -u ubuntu --hp /home/ubuntu

# Install CloudWatch Agent
wget https://s3.amazonaws.com/amazoncloudwatch-agent/ubuntu/amd64/latest/amazon-cloudwatch-agent.deb
dpkg -i amazon-cloudwatch-agent.deb

# Configure CloudWatch Agent to send Nginx logs
cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'EOF'
{
    "logs": {
        "logs_collected": {
            "files": {
                "collect_list": [
                    {
                        "file_path": "/var/log/nginx/access.log",
                        "log_group_name": "/aws/ec2/3tier-app",
                        "log_stream_name": "{instance_id}/nginx/access.log"
                    }
                ]
            }
        }
    }
}
EOF

# Start CloudWatch Agent
/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
    -a fetch-config -m ec2 \
    -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json -s
```

9. **Create launch template**

---

## Step 3: Create Auto Scaling Group

### Using AWS Console:
1. **Go to EC2 → Auto Scaling Groups → Create**
2. **Name**: `3tier-app-asg`
3. **Launch template**: Select `3tier-app-launch-template`
4. **VPC**: Select your VPC
5. **Subnets**: Select your **public subnets** (where your current instance runs)
6. **Load balancing**: 
   - Enable Application Load Balancer
   - Select your existing target group: `3tier-app-tg`
   - Health check type: ELB
7. **Group size**:
   - Desired: `2`
   - Minimum: `2` 
   - Maximum: `4`
8. **Scaling policies**:
   - Target tracking scaling policy
   - Metric: Average CPU Utilization
   - Target value: `70`
9. **Create Auto Scaling Group**

### Using AWS CLI:
```bash
# Get your subnet IDs (public subnets)
SUBNETS=$(aws ec2 describe-subnets \
    --filters "Name=tag:Type,Values=Public" \
    --query 'Subnets[*].SubnetId' \
    --output text | tr '\t' ',')

# Get your target group ARN
TARGET_GROUP_ARN=$(aws elbv2 describe-target-groups \
    --names "3tier-app-tg" \
    --query 'TargetGroups[0].TargetGroupArn' \
    --output text)

# Create Auto Scaling Group
aws autoscaling create-auto-scaling-group \
    --auto-scaling-group-name 3tier-app-asg \
    --launch-template LaunchTemplateName=3tier-app-launch-template,Version='$Latest' \
    --min-size 2 \
    --max-size 4 \
    --desired-capacity 2 \
    --target-group-arns "$TARGET_GROUP_ARN" \
    --health-check-type ELB \
    --health-check-grace-period 300 \
    --vpc-zone-identifier "$SUBNETS"

# Create scaling policy
aws autoscaling put-scaling-policy \
    --auto-scaling-group-name 3tier-app-asg \
    --policy-name 3tier-app-cpu-scaling \
    --policy-type TargetTrackingScaling \
    --target-tracking-configuration '{
        "TargetValue": 70.0,
        "PredefinedMetricSpecification": {
            "PredefinedMetricType": "ASGAverageCPUUtilization"
        }
    }'
```

---

## Step 4: Set Up Monitoring and Alerts

### Create CloudWatch Log Group:
```bash
aws logs create-log-group --log-group-name /aws/ec2/3tier-app
aws logs put-retention-policy --log-group-name /aws/ec2/3tier-app --retention-in-days 7
```

### Create SNS Topic for Alerts:
```bash
# Create topic
SNS_ARN=$(aws sns create-topic --name 3tier-app-alerts --query 'TopicArn' --output text)

# Subscribe your email
aws sns subscribe --topic-arn "$SNS_ARN" --protocol email --notification-endpoint your-email@example.com
```

### Create CloudWatch Alarm:
```bash
aws cloudwatch put-metric-alarm \
    --alarm-name "3tier-app-high-cpu" \
    --alarm-description "Alert when ASG CPU is high" \
    --metric-name CPUUtilization \
    --namespace AWS/AutoScaling \
    --statistic Average \
    --period 300 \
    --threshold 70 \
    --comparison-operator GreaterThanThreshold \
    --evaluation-periods 2 \
    --alarm-actions "$SNS_ARN" \
    --dimensions Name=AutoScalingGroupName,Value=3tier-app-asg
```

---

## Step 5: Test and Validate

### 1. Check Auto Scaling Group:
- Go to EC2 → Auto Scaling Groups
- Verify `3tier-app-asg` shows 2 running instances
- Check Activity tab for launch history

### 2. Check Load Balancer:
- Go to EC2 → Target Groups → `3tier-app-tg`
- Verify 2 healthy targets (your new ASG instances)

### 3. Test Application:
- Visit your ALB DNS name
- Refresh multiple times - you should see different instance IDs
- Submit forms to verify database connectivity

### 4. Check CloudWatch:
- Go to CloudWatch → Log groups
- Verify `/aws/ec2/3tier-app` has log streams from your instances

### 5. Test Scaling (Optional):
```bash
# Generate load to trigger scaling
for i in {1..1000}; do
  curl -s http://YOUR-ALB-DNS-NAME/ > /dev/null &
done
```

---

## Step 6: Clean Up Your Original Instance

Once Auto Scaling is working:

1. **Remove original instance from target group**:
   - Go to Target Groups → `3tier-app-tg` → Targets
   - Select your original instance → Actions → Deregister

2. **Terminate original instance** (optional):
   - Go to EC2 → Instances
   - Select your Week 3 instance → Instance State → Terminate

---

## Success! 🎉

Your application now has:
- ✅ **Auto Scaling**: Automatically adds/removes instances based on demand
- ✅ **Self-Healing**: Unhealthy instances are automatically replaced
- ✅ **Load Distribution**: Traffic spread across multiple instances
- ✅ **Advanced Monitoring**: Detailed logs and metrics in CloudWatch
- ✅ **Automated Alerts**: Email notifications for issues

## What You've Achieved

🚀 **True Elasticity**: Your app scales automatically with traffic  
🛡️ **High Availability**: Multiple instances across availability zones  
👀 **Deep Observability**: Comprehensive logging and monitoring  
🤖 **Zero Touch Operations**: Fully automated infrastructure management  

Your 3-tier application is now production-ready and unstoppable!

---

## Troubleshooting

**Instances not launching?**
- Check IAM role permissions
- Verify security group allows ALB traffic
- Check user data script logs: `/var/log/user-data.log`

**Targets unhealthy?**
- Verify application starts correctly
- Check security group rules
- Ensure health check path returns 200

**Scaling not working?**
- Check CloudWatch metrics are being published
- Verify scaling policy configuration
- Allow 5-10 minutes for scaling actions

**No logs in CloudWatch?**
- Verify IAM permissions for CloudWatch Agent
- Check agent configuration and status
- Ensure log group exists
