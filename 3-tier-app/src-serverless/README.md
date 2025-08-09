# Serverless Application - Week 6

This directory contains the serverless version of the 3-tier application, designed to run on AWS serverless services.

## 📁 Directory Structure

```
src-serverless/
├── README.md           # This file
├── index.html          # Main form with serverless integration
├── admin.html          # Admin dashboard for serverless
├── error.html          # 404 error page for S3 hosting
└── lambda/             # Lambda function code
    ├── package.json    # Node.js dependencies
    └── index.js        # Lambda handler function
```

## 🚀 Architecture

**Frontend**: Static files hosted on S3 with CloudFront CDN
**Backend**: Lambda functions accessed via API Gateway
**Database**: Existing RDS MySQL database (from previous weeks)

## 🔧 Key Differences from Original Version

### Frontend Changes
- **API Integration**: Uses API Gateway endpoints instead of direct server calls
- **Visual Indicators**: Added 🚀 Serverless badge to distinguish from other versions
- **Static Hosting**: Optimized for S3 static website hosting
- **Error Handling**: Custom 404 page for S3/CloudFront

### Backend Changes
- **Lambda Handler**: Complete rewrite from Express.js to Lambda function
- **CORS Support**: Built-in CORS headers for cross-origin requests
- **VPC Integration**: Configured to run in VPC for RDS access
- **Environment Variables**: Database configuration via Lambda environment variables

## 📋 Prerequisites

Before deploying this serverless version:

1. **Existing Infrastructure**: RDS database from previous weeks
2. **AWS CLI**: Configured with appropriate permissions
3. **Node.js**: For building Lambda deployment package
4. **VPC Setup**: Existing VPC with subnets and security groups

## 🚀 Deployment

Follow the complete deployment guide in:
```
3-tier-app/docs/week6-serverless-deployment/DEPLOYMENT_GUIDE.md
```

### Quick Start

1. **Prepare Lambda Package**:
   ```bash
   cd lambda/
   npm install
   zip -r lambda-deployment.zip .
   ```

2. **Upload Frontend to S3**:
   ```bash
   aws s3 sync . s3://your-bucket-name/ --exclude "lambda/*"
   ```

3. **Deploy Lambda Function**:
   - Use AWS Console or CLI to create Lambda function
   - Upload the deployment package
   - Configure VPC and environment variables

4. **Create API Gateway**:
   - Create REST API with /submissions resource
   - Configure Lambda proxy integration
   - Enable CORS

5. **Update Frontend**:
   - Replace `YOUR_API_GATEWAY_ID` in HTML files with actual API Gateway URL

## 🔗 API Endpoints

The Lambda function provides these endpoints:

- `GET /submissions` - Retrieve all submissions
- `POST /submissions` - Create new submission
- `GET /submissions/{id}` - Get specific submission
- `DELETE /submissions/{id}` - Delete submission
- `OPTIONS /*` - CORS preflight requests

## 🎯 Features

### Frontend Features
- **Multi-step Form**: Progressive form with validation
- **Admin Dashboard**: View and manage submissions
- **Responsive Design**: Works on desktop and mobile
- **Error Handling**: User-friendly error messages

### Backend Features
- **Database Integration**: Full CRUD operations with MySQL
- **Input Validation**: Server-side validation for all fields
- **Error Handling**: Comprehensive error responses
- **CORS Support**: Handles cross-origin requests
- **Logging**: CloudWatch integration for monitoring

## 🔐 Security

- **VPC Configuration**: Lambda runs in private subnets
- **Security Groups**: Restricted database access
- **Input Sanitization**: All inputs are validated and sanitized
- **HTTPS Only**: CloudFront enforces HTTPS

## 💰 Cost Benefits

Compared to the ECS version:
- **No Fixed Costs**: Pay only for actual usage
- **Auto Scaling**: Handles traffic spikes without pre-provisioning
- **Reduced Management**: No servers to maintain
- **Global CDN**: Improved performance with CloudFront

## 🔧 Configuration

### Environment Variables (Lambda)
- `DB_HOST`: RDS endpoint
- `DB_USER`: Database username
- `DB_PASSWORD`: Database password
- `DB_NAME`: Database name

### Frontend Configuration
Update the `API_URL` constant in both HTML files with your API Gateway URL:
```javascript
const API_URL = 'https://your-api-id.execute-api.region.amazonaws.com/prod';
```

## 🐛 Troubleshooting

### Common Issues

1. **CORS Errors**: Ensure API Gateway has CORS enabled
2. **Database Connection**: Check VPC configuration and security groups
3. **Lambda Timeouts**: Increase timeout if database operations are slow
4. **S3 Access**: Verify bucket policy allows public read access

### Debug Commands

```bash
# Test Lambda function directly
aws lambda invoke --function-name your-function response.json

# Check Lambda logs
aws logs filter-log-events --log-group-name /aws/lambda/your-function

# Test API Gateway
curl -X GET https://your-api-id.execute-api.region.amazonaws.com/prod/submissions
```

## 📚 Related Documentation

- [Week 6 Deployment Guide](../docs/week6-serverless-deployment/DEPLOYMENT_GUIDE.md)
- [Original Application](../src/)
- [Container Version](../src-container/)

## 🎉 Benefits Achieved

✅ **Zero Server Management**: No EC2 instances to maintain
✅ **Auto Scaling**: Handles any traffic load automatically
✅ **Cost Efficiency**: Pay only for actual usage
✅ **Global Performance**: CloudFront edge locations worldwide
✅ **High Availability**: Built-in redundancy across multiple AZs
✅ **Fast Deployment**: Infrastructure changes deploy in minutes

This serverless architecture represents the evolution from traditional server-based applications to modern, cloud-native solutions that scale automatically and require minimal operational overhead.
