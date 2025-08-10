# Week 6 Deployment Guide: Serverless Architecture with S3, CloudFront, API Gateway & Lambda

## 🚀 Going Fully Serverless - No Servers to Manage!

### Overview
This week, we're taking your 3-tier application completely serverless! We'll host the frontend as a static website on S3 with CloudFront for global distribution, and build the backend with API Gateway and Lambda functions—eliminating all server management while maintaining full functionality.

> ⚠️ **Important**: This builds on your existing RDS database from previous weeks. We'll be decommissioning your ECS infrastructure to replace it with a fully managed serverless architecture.

## What We'll Build

**Migration Path**: ECS Containers → **Serverless Stack**

- **S3 Static Website** hosting your frontend with global CDN
- **CloudFront Distribution** for fast, secure content delivery
- **API Gateway** for RESTful API endpoints
- **Lambda Functions** running your backend logic
- **RDS Integration** using existing database with VPC connectivity
- **Custom Domain** support (optional)

## Prerequisites

✅ **Previous weeks completed**: RDS database running and accessible  
✅ **Network infrastructure**: VPC, subnets, security groups configured  
✅ **Domain name** (optional): For custom CloudFront domain  
✅ **AWS CLI configured**: With appropriate permissions  

---

## Architecture Overview

### Before (Week 5):
```
Internet → ECS Service (Containers on EC2) → RDS
```

### After (Week 6):
```
Internet → CloudFront → S3 (Static Website)
                    ↓
                API Gateway → Lambda Functions → RDS
```

### Serverless Architecture Benefits:
- ✅ **Zero Server Management**: No EC2 instances to maintain
- ✅ **Auto Scaling**: Handles any traffic load automatically  
- ✅ **Pay-per-Use**: Only pay for actual requests and compute time
- ✅ **Global Performance**: CloudFront edge locations worldwide
- ✅ **High Availability**: Built-in redundancy across multiple AZs
- ✅ **Security**: AWS-managed infrastructure with fine-grained permissions

---

## Application Source Code

The serverless version of the application is located in the `src-serverless/` directory:

```
3-tier-app/
├── src-serverless/           # 🆕 Serverless application files
│   ├── index.html           # Frontend with API Gateway integration
│   ├── admin.html           # Admin dashboard for serverless
│   ├── error.html           # 404 error page for S3 hosting
│   └── lambda/              # Lambda function code
│       ├── package.json     # Node.js dependencies
│       └── index.js         # Lambda handler function
├── src/                     # Original application files
└── src-container/           # Container version from Week 5
```

> 📝 **Note**: The serverless version includes visual indicators (🚀 Serverless badge) and is optimized for API Gateway endpoints instead of direct server calls.

---

## Step 1: Create S3 Bucket for Static Website Hosting

### 1.1 Create S3 Bucket

**Option A: Using AWS Console (Recommended)**

1. **Navigate to S3 Console**
   - Go to [AWS S3 Console](https://console.aws.amazon.com/s3/)
   - Click **"Create bucket"**

2. **Configure Bucket Settings**
   - **Bucket name**: `3tier-app-frontend-YYYYMMDD` (replace with current date)
   - **Region**: Choose your preferred region (e.g., `us-east-1`)
   - **Block Public Access**: **Uncheck all options** (required for static website)
   - Click **"Create bucket"**

3. **Enable Static Website Hosting**
   - Select your bucket → **Properties** tab
   - Scroll to **"Static website hosting"** → **Edit**
   - **Enable** static website hosting
   - **Index document**: `index.html`
   - **Error document**: `error.html`
   - Click **"Save changes"**

4. **Set Bucket Policy for Public Access**
   - Go to **Permissions** tab → **Bucket Policy** → **Edit**
   - Add this policy (replace `YOUR-BUCKET-NAME`):
   ```json
   {
       "Version": "2012-10-17",
       "Statement": [
           {
               "Sid": "PublicReadGetObject",
               "Effect": "Allow",
               "Principal": "*",
               "Action": "s3:GetObject",
               "Resource": "arn:aws:s3:::YOUR-BUCKET-NAME/*"
           }
       ]
   }
   ```

**Option B: Using AWS CLI**
```bash
# Set your bucket name
BUCKET_NAME="3tier-app-frontend-$(date +%Y%m%d)"

# Create bucket
aws s3 mb s3://$BUCKET_NAME

# Enable static website hosting
aws s3 website s3://$BUCKET_NAME --index-document index.html --error-document error.html

# Set bucket policy (create policy file first)
cat > bucket-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "PublicReadGetObject",
            "Effect": "Allow",
            "Principal": "*",
            "Action": "s3:GetObject",
            "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
        }
    ]
}
EOF

aws s3api put-bucket-policy --bucket $BUCKET_NAME --policy file://bucket-policy.json

# Disable block public access
aws s3api put-public-access-block --bucket $BUCKET_NAME \
    --public-access-block-configuration \
    BlockPublicAcls=false,IgnorePublicAcls=false,BlockPublicPolicy=false,RestrictPublicBuckets=false
```

### 1.2 Upload Frontend Files

**Copy the serverless frontend files to your working directory:**
```bash
# Copy serverless frontend files from the repository
cp -r 3-tier-app/src-serverless/*.html ./frontend-files/
```

**Upload to S3:**

**Option A: Using AWS Console (Recommended)**
1. Select your S3 bucket
2. Click **"Upload"**
3. **Add files**: Select the files from `3-tier-app/src-serverless/`:
   - `index.html` (main form with serverless integration)
   - `admin.html` (admin dashboard for serverless)
   - `error.html` (404 error page)
4. **Permissions**: Ensure **"Grant public-read access"** is selected
5. Click **"Upload"**

**Option B: Using AWS CLI**
```bash
# Upload files directly from source
aws s3 sync 3-tier-app/src-serverless/ s3://$BUCKET_NAME/ --exclude "lambda/*" --acl public-read

# Get website URL
echo "S3 Website URL: http://$BUCKET_NAME.s3-website-$(aws configure get region).amazonaws.com"
```

> 📝 **Note**: You'll need to update the API Gateway URL in the frontend files after creating the API Gateway in the next steps.

---

## Step 2: Create Lambda Function for Backend Logic

### 2.1 Prepare Lambda Function Code

The Lambda function code is already available in the repository at `3-tier-app/src-serverless/lambda/`. This contains:

- **`package.json`**: Node.js dependencies (mysql2, uuid)
- **`index.js`**: Complete Lambda handler with database operations

**Option A: Using AWS Console (Recommended)**

1. **Prepare the deployment package:**
   ```bash
   # Navigate to the Lambda source directory
   cd 3-tier-app/src-serverless/lambda/
   
   # Install dependencies
   npm install
   
   # Create deployment package
   zip -r lambda-deployment.zip . -x "*.git*" "*.DS_Store*"
   
   echo "✅ Lambda deployment package created: lambda-deployment.zip"
   ```

**Option B: Using AWS CLI**
```bash
# Navigate to Lambda source and create deployment package
cd 3-tier-app/src-serverless/lambda/
npm install
zip -r lambda-deployment.zip . -x "*.git*" "*.DS_Store*"
cd ../../../
```

> 📝 **Lambda Function Features**:
> - **Database Integration**: Connects to your existing RDS MySQL database
> - **CORS Support**: Handles cross-origin requests from S3-hosted frontend
> - **RESTful API**: Supports GET, POST, DELETE operations for submissions
> - **Error Handling**: Comprehensive error handling and logging
> - **VPC Configuration**: Runs in VPC to access RDS securely

### 2.2 Create IAM Role for Lambda

**Option A: Using AWS Console (Recommended)**

1. **Navigate to IAM Console**
   - Go to [AWS IAM Console](https://console.aws.amazon.com/iam/)
   - Click **"Roles"** → **"Create role"**

2. **Configure Role**
   - **Trusted entity**: **AWS service**
   - **Service**: **Lambda**
   - Click **"Next"**

3. **Attach Policies**
   - Search and select: **`AWSLambdaBasicExecutionRole`**
   - Search and select: **`AWSLambdaVPCAccessExecutionRole`**
   - Click **"Next"**

4. **Name and Create**
   - **Role name**: `3tier-lambda-execution-role`
   - **Description**: `Execution role for 3-tier serverless Lambda function`
   - Click **"Create role"**

5. **Note the Role ARN**
   - Click on the created role
   - Copy the **Role ARN** (you'll need this later)

**Option B: Using AWS CLI**
```bash
# Create trust policy for Lambda
cat > lambda-trust-policy.json << 'EOF'
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF

# Create Lambda execution role
aws iam create-role \
    --role-name "3tier-lambda-execution-role" \
    --assume-role-policy-document file://lambda-trust-policy.json

# Attach policies
aws iam attach-role-policy \
    --role-name "3tier-lambda-execution-role" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
    --role-name "3tier-lambda-execution-role" \
    --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
```

### 2.3 Create Security Group for Lambda

**Option A: Using AWS Console (Recommended)**

1. **Navigate to EC2 Console**
   - Go to [AWS EC2 Console](https://console.aws.amazon.com/ec2/)
   - Click **"Security Groups"** → **"Create security group"**

2. **Configure Security Group**
   - **Name**: `3tier-lambda-sg`
   - **Description**: `Security group for Lambda functions to access RDS`
   - **VPC**: Select your VPC (from previous weeks)

3. **Configure Rules**
   - **Outbound Rules**: Leave default (All traffic)
   - **Inbound Rules**: None needed (Lambda doesn't receive inbound traffic)
   - Click **"Create security group"**

4. **Update RDS Security Group**
   - Go to your RDS security group (from previous weeks)
   - **Edit inbound rules** → **Add rule**
   - **Type**: MySQL/Aurora (3306)
   - **Source**: Custom → Select the Lambda security group you just created
   - **Save rules**

**Option B: Using AWS CLI**
```bash
# Create security group for Lambda
LAMBDA_SG_ID=$(aws ec2 create-security-group \
    --group-name "3tier-lambda-sg" \
    --description "Security group for Lambda functions to access RDS" \
    --vpc-id "YOUR_VPC_ID" \
    --query 'GroupId' \
    --output text)

# Allow Lambda to connect to RDS
aws ec2 authorize-security-group-ingress \
    --group-id "YOUR_RDS_SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 3306 \
    --source-group "$LAMBDA_SG_ID"
```

### 2.4 Create Lambda Function

**Option A: Using AWS Console (Recommended)**

1. **Navigate to Lambda Console**
   - Go to [AWS Lambda Console](https://console.aws.amazon.com/lambda/)
   - Click **"Create function"**

2. **Configure Function**
   - **Function name**: `3tier-app-handler`
   - **Runtime**: **Node.js 18.x**
   - **Architecture**: **x86_64**
   - **Execution role**: **Use an existing role** → Select `3tier-lambda-execution-role`
   - Click **"Create function"**

3. **Upload Function Code**
   - In the **Code** tab, click **"Upload from"** → **".zip file"**
   - Upload the `lambda-deployment.zip` file you created earlier
   - Click **"Save"**

4. **Configure Environment Variables**
   - Go to **Configuration** → **Environment variables** → **Edit**
   - Add these variables:
     - `DB_HOST`: Your RDS endpoint
     - `DB_USER`: `formapp_user`
     - `DB_PASSWORD`: Your database password
     - `DB_NAME`: `formapp`
   - Click **"Save"**

5. **Configure VPC Settings**
   - Go to **Configuration** → **VPC** → **Edit**
   - **VPC**: Select your VPC
   - **Subnets**: Select private subnets (or any subnets in your VPC)
   - **Security groups**: Select the `3tier-lambda-sg` you created
   - Click **"Save"**

6. **Configure Basic Settings**
   - Go to **Configuration** → **General configuration** → **Edit**
   - **Timeout**: `30 seconds`
   - **Memory**: `512 MB`
   - Click **"Save"**

7. **Test the Function**
   - Go to **Test** tab → **Create new test event**
   - **Event template**: **Create a new event**
   - **Event name**: `test-options-cors`
   - Replace the test event with:
   ```json
   {
     "httpMethod": "OPTIONS",
     "path": "/submissions",
     "pathParameters": null,
     "body": null,
     "headers": {
       "Content-Type": "application/json"
     },
     "queryStringParameters": null,
     "requestContext": {
       "requestId": "test-request-id",
       "stage": "prod"
     }
   }
   ```
   - Click **"Test"**
   - **Expected Result**: `statusCode: 200` with CORS headers

8. **Create Second Test Event**
   - Click **"Test"** → **Configure test events** → **Create new test event**
   - **Event name**: `test-get-submissions`
   - Replace the test event with:
   ```json
   {
     "httpMethod": "GET",
     "path": "/submissions",
     "pathParameters": null,
     "body": null,
     "headers": {
       "Content-Type": "application/json"
     },
     "queryStringParameters": null,
     "requestContext": {
       "requestId": "test-request-id",
       "stage": "prod"
     }
   }
   ```
   - Click **"Test"**
   - **Expected Result**: `statusCode: 200` with empty array `[]` (if database connected) or `statusCode: 500` (if database not connected)

9. **Publish the Function**
   - Go to **Actions** → **Publish new version**
   - **Version description**: `Initial serverless deployment`
   - Click **"Publish"**
   - **Note the Version ARN** (you'll need this for API Gateway)

**Option B: Using AWS CLI**
```bash
# Create Lambda function
aws lambda create-function \
    --function-name "3tier-app-handler" \
    --runtime "nodejs18.x" \
    --role "arn:aws:iam::YOUR_ACCOUNT:role/3tier-lambda-execution-role" \
    --handler index.handler \
    --zip-file fileb://3-tier-app/src-serverless/lambda/lambda-deployment.zip \
    --timeout 30 \
    --memory-size 512 \
    --environment Variables="{
        DB_HOST=YOUR_RDS_ENDPOINT,
        DB_USER=formapp_user,
        DB_PASSWORD=YOUR_PASSWORD,
        DB_NAME=formapp
    }" \
    --vpc-config SubnetIds="subnet-xxx,subnet-yyy",SecurityGroupIds="sg-xxx"
```

---

## Step 3: Create API Gateway

### 3.1 Create REST API

**Option A: Using AWS Console (Recommended)**

1. **Navigate to API Gateway Console**
   - Go to [AWS API Gateway Console](https://console.aws.amazon.com/apigateway/)
   - Click **"Create API"**

2. **Choose API Type**
   - Select **"REST API"** (not REST API Private)
   - Click **"Build"**

3. **Configure API**
   - **API name**: `3tier-app-api`
   - **Description**: `REST API for 3-tier serverless application`
   - **Endpoint Type**: **Regional**
   - Click **"Create API"**

**Option B: Using AWS CLI**
```bash
# Create REST API
API_ID=$(aws apigateway create-rest-api \
    --name "3tier-app-api" \
    --description "REST API for 3-tier serverless application" \
    --endpoint-configuration types=REGIONAL \
    --query 'id' \
    --output text)

echo "✅ API Gateway created: $API_ID"
```

### 3.2 Create API Resources and Methods

**Option A: Using AWS Console (Recommended)**

1. **Create /submissions Resource**
   - In your API, click **"Actions"** → **"Create Resource"**
   - **Resource Name**: `submissions`
   - **Resource Path**: `/submissions`
   - **Enable API Gateway CORS**: ✅ Check this box
   - Click **"Create Resource"**

2. **Create /{id} Resource**
   - Select the `/submissions` resource
   - Click **"Actions"** → **"Create Resource"**
   - **Resource Name**: `id`
   - **Resource Path**: `/{id}`
   - **Enable API Gateway CORS**: ✅ Check this box
   - Click **"Create Resource"**

3. **Create Methods for /submissions**
   
   **GET Method:**
   - Select `/submissions` resource
   - Click **"Actions"** → **"Create Method"** → Select **"GET"** → ✓
   - **Integration type**: **Lambda Function**
   - **Use Lambda Proxy integration**: ✅ Check this box
   - **Lambda Region**: Your region
   - **Lambda Function**: `3tier-app-handler`
   - Click **"Save"** → **"OK"** (to grant permission)

   **POST Method:**
   - Select `/submissions` resource
   - Click **"Actions"** → **"Create Method"** → Select **"POST"** → ✓
   - **Integration type**: **Lambda Function**
   - **Use Lambda Proxy integration**: ✅ Check this box
   - **Lambda Function**: `3tier-app-handler`
   - Click **"Save"** → **"OK"**

4. **Create Methods for /submissions/{id}**
   
   **GET Method:**
   - Select `/submissions/{id}` resource
   - Click **"Actions"** → **"Create Method"** → Select **"GET"** → ✓
   - **Integration type**: **Lambda Function**
   - **Use Lambda Proxy integration**: ✅ Check this box
   - **Lambda Function**: `3tier-app-handler`
   - Click **"Save"** → **"OK"**

   **DELETE Method:**
   - Select `/submissions/{id}` resource
   - Click **"Actions"** → **"Create Method"** → Select **"DELETE"** → ✓
   - **Integration type**: **Lambda Function**
   - **Use Lambda Proxy integration**: ✅ Check this box
   - **Lambda Function**: `3tier-app-handler`
   - Click **"Save"** → **"OK"**

5. **Enable CORS (if not done automatically)**
   - Select each resource (`/submissions` and `/submissions/{id}`)
   - Click **"Actions"** → **"Enable CORS"**
   - **Access-Control-Allow-Origin**: `*`
   - **Access-Control-Allow-Headers**: `Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token`
   - **Access-Control-Allow-Methods**: Select all methods you created
   - Click **"Enable CORS and replace existing CORS headers"**

**Option B: Using AWS CLI**
```bash
# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
    --rest-api-id "$API_ID" \
    --query 'items[0].id' \
    --output text)

# Create /submissions resource
SUBMISSIONS_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$ROOT_RESOURCE_ID" \
    --path-part "submissions" \
    --query 'id' \
    --output text)

# Create /{id} resource
ID_RESOURCE_ID=$(aws apigateway create-resource \
    --rest-api-id "$API_ID" \
    --parent-id "$SUBMISSIONS_RESOURCE_ID" \
    --path-part "{id}" \
    --query 'id' \
    --output text)

# Create methods and integrations (detailed CLI commands available in original guide)
```

### 3.3 Deploy API

**Option A: Using AWS Console (Recommended)**

1. **Deploy the API**
   - Click **"Actions"** → **"Deploy API"**
   - **Deployment stage**: **[New Stage]**
   - **Stage name**: `prod`
   - **Stage description**: `Production stage for 3-tier serverless API`
   - Click **"Deploy"**

2. **Get API Gateway URL**
   - After deployment, you'll see the **Invoke URL**
   - Copy this URL (e.g., `https://abc123.execute-api.us-east-1.amazonaws.com/prod`)
   - This is your API Gateway endpoint

3. **Test the API**
   - Click on **GET** method under `/submissions`
   - Click **"TEST"**
   - Click **"Test"** button
   - Verify you get a successful response

**Option B: Using AWS CLI**
```bash
# Deploy API to stage
aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "prod" \
    --stage-description "Production stage for 3-tier serverless API"

# Get API Gateway endpoint URL
API_GATEWAY_URL="https://$API_ID.execute-api.$(aws configure get region).amazonaws.com/prod"
echo "✅ API Gateway URL: $API_GATEWAY_URL"
```

### 3.4 Grant Lambda Permissions (if needed)

If you created the API via CLI or encounter permission errors:

**Using AWS Console:**
1. Go to Lambda Console → Your function
2. Check if API Gateway trigger is listed
3. If not, the permissions were not set automatically

**Using AWS CLI:**
```bash
# Add permission for API Gateway to invoke Lambda
aws lambda add-permission \
    --function-name "3tier-app-handler" \
    --statement-id "apigateway-invoke-lambda" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:YOUR_REGION:YOUR_ACCOUNT:YOUR_API_ID/*/*"
```

---

## Step 4: Update Frontend with API Gateway URL

### 4.1 Update Frontend Files

**Option A: Using Text Editor (Recommended)**

1. **Update index.html**:
   - Open `3-tier-app/src-serverless/index.html` in a text editor
   - Find the line: `const API_URL = 'https://YOUR_API_GATEWAY_ID.execute-api.YOUR_REGION.amazonaws.com/prod';`
   - Replace with your actual API Gateway URL from Step 3.3
   - Save the file

2. **Update admin.html**:
   - Open `3-tier-app/src-serverless/admin.html` in a text editor
   - Find the line: `const API_URL = 'https://YOUR_API_GATEWAY_ID.execute-api.YOUR_REGION.amazonaws.com/prod';`
   - Replace with your actual API Gateway URL from Step 3.3
   - Save the file

**Option B: Using Command Line**

```bash
# Set your API Gateway URL (replace with your actual URL from Step 3.3)
API_GATEWAY_URL="https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/prod"

# Update index.html
sed -i.bak "s|https://YOUR_API_GATEWAY_ID.execute-api.YOUR_REGION.amazonaws.com/prod|$API_GATEWAY_URL|g" 3-tier-app/src-serverless/index.html

# Update admin.html
sed -i.bak "s|https://YOUR_API_GATEWAY_ID.execute-api.YOUR_REGION.amazonaws.com/prod|$API_GATEWAY_URL|g" 3-tier-app/src-serverless/admin.html

echo "✅ Frontend files updated with API Gateway URL"
```

> 📝 **Important**: Make sure to replace `YOUR_API_ID` and `YOUR_REGION` with the actual values from your API Gateway deployment in Step 3.3.
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Admin Dashboard - Serverless</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 1200px;
            margin: 0 auto;
            padding: 20px;
        }
        h1 {
            text-align: center;
            margin-bottom: 30px;
        }
        .login-container {
            max-width: 400px;
            margin: 0 auto;
            padding: 20px;
            border: 1px solid #ddd;
            border-radius: 5px;
        }
        .dashboard-container {
            display: none;
        }
        .form-group {
            margin-bottom: 15px;
        }
        .form-group label {
            display: block;
            margin-bottom: 5px;
            font-weight: bold;
        }
        .form-group input {
            width: 100%;
            padding: 8px;
            border: 1px solid #ddd;
            border-radius: 4px;
            box-sizing: border-box;
        }
        button {
            padding: 10px 15px;
            background-color: #4CAF50;
            color: white;
            border: none;
            border-radius: 4px;
            cursor: pointer;
        }
        button:hover {
            background-color: #45a049;
        }
        .error {
            color: red;
            font-size: 0.9em;
            margin-top: 5px;
        }
        table {
            width: 100%;
            border-collapse: collapse;
            margin-top: 20px;
        }
        th, td {
            padding: 12px;
            text-align: left;
            border-bottom: 1px solid #ddd;
        }
        th {
            background-color: #f2f2f2;
            font-weight: bold;
        }
        tr:hover {
            background-color: #f5f5f5;
        }
        .submission-details {
            margin-top: 20px;
            padding: 15px;
            border: 1px solid #ddd;
            border-radius: 5px;
            display: none;
        }
        .back-link {
            margin-top: 20px;
            display: block;
        }
        .filters {
            margin-bottom: 20px;
            padding: 15px;
            background-color: #f9f9f9;
            border-radius: 5px;
        }
        .filters select, .filters input {
            padding: 8px;
            margin-right: 10px;
            border: 1px solid #ddd;
            border-radius: 4px;
        }
        .serverless-badge {
            position: fixed;
            top: 10px;
            right: 10px;
            background: linear-gradient(45deg, #FF6B6B, #4ECDC4);
            color: white;
            padding: 8px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="serverless-badge">🚀 Serverless</div>
    
    <h1>Admin Dashboard</h1>
    <p><em>Powered by AWS Serverless Architecture</em></p>
    
    <!-- Login Form -->
    <div class="login-container" id="loginContainer">
        <h2>Login</h2>
        <div class="form-group">
            <label for="username">Username</label>
            <input type="text" id="username" name="username">
        </div>
        <div class="form-group">
            <label for="password">Password</label>
            <input type="password" id="password" name="password">
        </div>
        <div class="error" id="loginError"></div>
        <button type="button" onclick="login()">Login</button>
    </div>
    
    <!-- Dashboard -->
    <div class="dashboard-container" id="dashboardContainer">
        <h2>User Submissions</h2>
        
        <div class="filters">
            <label for="filterSubscription">Filter by Subscription:</label>
            <select id="filterSubscription" onchange="filterSubmissions()">
                <option value="">All</option>
                <option value="free">Free</option>
                <option value="basic">Basic</option>
                <option value="premium">Premium</option>
            </select>
            
            <label for="filterInterest">Filter by Interest:</label>
            <select id="filterInterest" onchange="filterSubmissions()">
                <option value="">All</option>
                <option value="technology">Technology</option>
                <option value="health">Health & Wellness</option>
                <option value="finance">Finance</option>
                <option value="education">Education</option>
                <option value="entertainment">Entertainment</option>
            </select>
            
            <button type="button" onclick="refreshData()">Refresh Data</button>
        </div>
        
        <table id="submissionsTable">
            <thead>
                <tr>
                    <th>Name</th>
                    <th>Email</th>
                    <th>Interest</th>
                    <th>Subscription</th>
                    <th>Submitted</th>
                    <th>Actions</th>
                </tr>
            </thead>
            <tbody id="submissionsBody">
                <!-- Submissions will be loaded here -->
            </tbody>
        </table>
        
        <div class="submission-details" id="submissionDetails">
            <h3>Submission Details</h3>
            <div id="detailsContent"></div>
            <button type="button" onclick="hideDetails()">Close</button>
        </div>
        
        <a href="/" class="back-link">Back to Form</a>
    </div>

    <script>
        const API_URL = '$API_GATEWAY_URL';
        let allSubmissions = [];
        
        // Simple admin authentication
        function login() {
            const username = document.getElementById('username').value.trim();
            const password = document.getElementById('password').value;
            
            // Simple hardcoded credentials (in a real app, this would be server-side)
            if (username === 'admin' && password === 'admin123') {
                document.getElementById('loginContainer').style.display = 'none';
                document.getElementById('dashboardContainer').style.display = 'block';
                loadSubmissions();
            } else {
                document.getElementById('loginError').textContent = 'Invalid username or password';
            }
        }
        
        // Load all submissions from the API
        async function loadSubmissions() {
            try {
                const response = await fetch(\`\${API_URL}/submissions\`);
                allSubmissions = await response.json();
                displaySubmissions(allSubmissions);
            } catch (error) {
                console.error('Error loading submissions:', error);
                alert('Failed to load submissions. Please try again.');
            }
        }
        
        // Display submissions in the table
        function displaySubmissions(submissions) {
            const tbody = document.getElementById('submissionsBody');
            tbody.innerHTML = '';
            
            if (submissions.length === 0) {
                tbody.innerHTML = '<tr><td colspan="6" style="text-align: center;">No submissions found</td></tr>';
                return;
            }
            
            submissions.forEach(submission => {
                const row = document.createElement('tr');
                
                const fullName = \`\${submission.firstName} \${submission.lastName}\`;
                const submittedDate = new Date(submission.submittedAt).toLocaleString();
                
                row.innerHTML = \`
                    <td>\${fullName}</td>
                    <td>\${submission.email}</td>
                    <td>\${submission.interests}</td>
                    <td>\${submission.subscription}</td>
                    <td>\${submittedDate}</td>
                    <td>
                        <button type="button" onclick="viewDetails('\${submission.id}')">View</button>
                        <button type="button" onclick="deleteSubmission('\${submission.id}')">Delete</button>
                    </td>
                \`;
                
                tbody.appendChild(row);
            });
        }
        
        // View submission details
        function viewDetails(id) {
            const submission = allSubmissions.find(s => s.id === id);
            if (!submission) return;
            
            const detailsDiv = document.getElementById('detailsContent');
            const submittedDate = new Date(submission.submittedAt).toLocaleString();
            
            let detailsHTML = \`
                <p><strong>Name:</strong> \${submission.firstName} \${submission.lastName}</p>
                <p><strong>Email:</strong> \${submission.email}</p>
                <p><strong>Phone:</strong> \${submission.phone || 'Not provided'}</p>
                <p><strong>Interest:</strong> \${submission.interests}</p>
                <p><strong>Subscription:</strong> \${submission.subscription}</p>
                <p><strong>Contact Frequency:</strong> \${submission.frequency}</p>
                <p><strong>Comments:</strong> \${submission.comments || 'None'}</p>
                <p><strong>Terms Accepted:</strong> \${submission.termsAccepted ? 'Yes' : 'No'}</p>
                <p><strong>Submitted:</strong> \${submittedDate}</p>
            \`;
            
            detailsDiv.innerHTML = detailsHTML;
            document.getElementById('submissionDetails').style.display = 'block';
        }
        
        // Hide details panel
        function hideDetails() {
            document.getElementById('submissionDetails').style.display = 'none';
        }
        
        // Delete a submission
        async function deleteSubmission(id) {
            if (!confirm('Are you sure you want to delete this submission?')) {
                return;
            }
            
            try {
                const response = await fetch(\`\${API_URL}/submissions/\${id}\`, {
                    method: 'DELETE'
                });
                
                if (response.ok) {
                    // Remove from local array and update display
                    allSubmissions = allSubmissions.filter(s => s.id !== id);
                    displaySubmissions(allSubmissions);
                } else {
                    alert('Failed to delete submission');
                }
            } catch (error) {
                console.error('Error deleting submission:', error);
                alert('An error occurred while deleting the submission');
            }
        }
        
        // Filter submissions
        function filterSubmissions() {
            const subscriptionFilter = document.getElementById('filterSubscription').value;
            const interestFilter = document.getElementById('filterInterest').value;
            
            let filtered = [...allSubmissions];
            
            if (subscriptionFilter) {
                filtered = filtered.filter(s => s.subscription === subscriptionFilter);
            }
            
            if (interestFilter) {
                filtered = filtered.filter(s => s.interests === interestFilter);
            }
            
            displaySubmissions(filtered);
        }
        
        // Refresh data
        function refreshData() {
            loadSubmissions();
        }
    </script>
</body>
</html>
EOF

# Create error.html for S3 static hosting
cat > frontend-serverless/error.html << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Page Not Found - 3-Tier Serverless App</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            max-width: 600px;
            margin: 100px auto;
            padding: 20px;
            text-align: center;
        }
        h1 {
            color: #e74c3c;
            font-size: 3em;
            margin-bottom: 20px;
        }
        p {
            font-size: 1.2em;
            color: #666;
            margin-bottom: 30px;
        }
        a {
            display: inline-block;
            padding: 12px 24px;
            background-color: #4CAF50;
            color: white;
            text-decoration: none;
            border-radius: 5px;
            font-weight: bold;
        }
        a:hover {
            background-color: #45a049;
        }
        .serverless-badge {
            position: fixed;
            top: 10px;
            right: 10px;
            background: linear-gradient(45deg, #FF6B6B, #4ECDC4);
            color: white;
            padding: 8px 12px;
            border-radius: 20px;
            font-size: 12px;
            font-weight: bold;
            box-shadow: 0 2px 10px rgba(0,0,0,0.2);
        }
    </style>
</head>
<body>
    <div class="serverless-badge">🚀 Serverless</div>
    
    <h1>404</h1>
    <p>Oops! The page you're looking for doesn't exist.</p>
    <p>But don't worry, our serverless architecture is still running perfectly!</p>
    
    <a href="/">Go Back Home</a>
</body>
</html>
EOF

echo "✅ Frontend files updated with API Gateway URL"
```

---

## Step 5: Upload Updated Frontend to S3

### 5.1 Upload Files to S3

**Option A: Using AWS Console (Recommended)**

1. **Upload Updated Files**:
   - Go to your S3 bucket in the AWS Console
   - Delete the old files (if any)
   - Click **"Upload"**
   - Select the updated files from `3-tier-app/src-serverless/`:
     - `index.html` (with updated API Gateway URL)
     - `admin.html` (with updated API Gateway URL)
     - `error.html`
   - **Permissions**: Ensure **"Grant public-read access"** is selected
   - Click **"Upload"**

2. **Test S3 Website**:
   - Go to your bucket → **Properties** → **Static website hosting**
   - Click on the **Bucket website endpoint** URL
   - Verify the application loads with the 🚀 Serverless badge

**Option B: Using AWS CLI**

```bash
# Set your bucket name (use the same name from Step 1)
BUCKET_NAME="your-bucket-name-from-step1"

# Upload updated files to S3
aws s3 sync 3-tier-app/src-serverless/ s3://$BUCKET_NAME/ \
    --exclude "lambda/*" \
    --exclude "local-test/*" \
    --acl public-read \
    --delete

# Get S3 website URL
AWS_REGION=$(aws configure get region)
S3_WEBSITE_URL="http://$BUCKET_NAME.s3-website-$AWS_REGION.amazonaws.com"

echo "✅ Frontend files uploaded to S3"
echo "✅ S3 Website URL: $S3_WEBSITE_URL"

# Test the website
curl -I "$S3_WEBSITE_URL"
```

> 📝 **Important**: Make sure you've updated the API Gateway URLs in both `index.html` and `admin.html` files in Step 4 before uploading.

---

## Step 6: Create CloudFront Distribution

### 6.1 Create CloudFront Distribution

**Option A: Using AWS Console (Recommended)**

1. **Navigate to CloudFront Console**
   - Go to [AWS CloudFront Console](https://console.aws.amazon.com/cloudfront/)
   - Click **"Create Distribution"**

2. **Configure Origin**
   - **Origin Domain**: Select your S3 bucket from the dropdown
     - It should show as: `your-bucket-name.s3.amazonaws.com`
   - **Origin Path**: Leave empty
   - **Name**: Keep the default name
   - **Origin Access**: **Public** (since we're using S3 static website hosting)

3. **Configure Default Cache Behavior**
   - **Viewer Protocol Policy**: **Redirect HTTP to HTTPS**
   - **Allowed HTTP Methods**: **GET, HEAD**
   - **Cache Policy**: **Caching Optimized**
   - **Origin Request Policy**: **None**
   - Leave other settings as default

4. **Configure Distribution Settings**
   - **Price Class**: **Use Only North America and Europe** (cost-effective)
   - **Alternate Domain Names (CNAMEs)**: Leave empty (unless you have a custom domain)
   - **Custom SSL Certificate**: Leave as default
   - **Default Root Object**: `index.html`
   - **Description**: `CloudFront distribution for 3-tier serverless app`

5. **Configure Custom Error Pages**
   - Click **"Add Custom Error Response"**
   - **HTTP Error Code**: `404`
   - **Customize Error Response**: **Yes**
   - **Response Page Path**: `/error.html`
   - **HTTP Response Code**: `404`
   - **Error Caching Minimum TTL**: `300`

6. **Create Distribution**
   - Review all settings
   - Click **"Create Distribution"**
   - **Note the Distribution Domain Name** (e.g., `d123456789.cloudfront.net`)

7. **Wait for Deployment**
   - Status will show **"Deploying"** initially
   - This takes **10-15 minutes** to complete
   - Status will change to **"Enabled"** when ready

8. **Test CloudFront Distribution**
   - Once deployed, access: `https://YOUR-DISTRIBUTION-DOMAIN.cloudfront.net`
   - Verify the application loads correctly

**Option B: Using AWS CLI**
```bash
# Create CloudFront distribution configuration
cat > cloudfront-config.json << EOF
{
    "CallerReference": "3tier-serverless-$(date +%s)",
    "Comment": "CloudFront distribution for 3-tier serverless app",
    "DefaultCacheBehavior": {
        "TargetOriginId": "S3-YOUR-BUCKET-NAME",
        "ViewerProtocolPolicy": "redirect-to-https",
        "MinTTL": 0,
        "ForwardedValues": {
            "QueryString": false,
            "Cookies": {
                "Forward": "none"
            }
        },
        "TrustedSigners": {
            "Enabled": false,
            "Quantity": 0
        }
    },
    "Origins": {
        "Quantity": 1,
        "Items": [
            {
                "Id": "S3-YOUR-BUCKET-NAME",
                "DomainName": "YOUR-BUCKET-NAME.s3.amazonaws.com",
                "S3OriginConfig": {
                    "OriginAccessIdentity": ""
                }
            }
        ]
    },
    "Enabled": true,
    "DefaultRootObject": "index.html",
    "CustomErrorResponses": {
        "Quantity": 1,
        "Items": [
            {
                "ErrorCode": 404,
                "ResponsePagePath": "/error.html",
                "ResponseCode": "404",
                "ErrorCachingMinTTL": 300
            }
        ]
    },
    "PriceClass": "PriceClass_100"
}
EOF

# Create CloudFront distribution
DISTRIBUTION_ID=$(aws cloudfront create-distribution \
    --distribution-config file://cloudfront-config.json \
    --query 'Distribution.Id' \
    --output text)

# Get CloudFront domain name
CLOUDFRONT_DOMAIN=$(aws cloudfront get-distribution \
    --id "$DISTRIBUTION_ID" \
    --query 'Distribution.DomainName' \
    --output text)

echo "✅ CloudFront distribution created: $DISTRIBUTION_ID"
echo "✅ CloudFront URL: https://$CLOUDFRONT_DOMAIN"
echo "⏳ Distribution is deploying (this takes 10-15 minutes)..."
```

### 6.2 Update Frontend with CloudFront URL (Optional)

Once CloudFront is deployed, you can update your frontend to use the CloudFront URL instead of the S3 website URL for better performance:

**Using AWS Console:**
1. Copy your CloudFront distribution domain name
2. Update any hardcoded URLs in your application (if any)
3. Re-upload files to S3 if needed

**Benefits of CloudFront:**
- **Global CDN**: Faster loading times worldwide
- **HTTPS by Default**: Secure connections
- **Caching**: Reduced load on S3
- **Custom Domain Support**: Can add your own domain later

---

## Step 7: Test the Serverless Application

### 7.1 Test S3 Static Website

**Option A: Using AWS Console**
1. Go to your S3 bucket → **Properties** → **Static website hosting**
2. Click on the **Bucket website endpoint** URL
3. Verify the form loads with the 🚀 Serverless badge

**Option B: Using CLI**
```bash
# Test S3 website directly
curl -I "$S3_WEBSITE_URL"

# Should return HTTP 200 OK
```

### 7.2 Test API Gateway and Lambda

```bash
# Test API Gateway endpoint
echo "Testing API Gateway..."

# Test GET /submissions (should return empty array initially)
curl -X GET "$API_GATEWAY_URL/submissions"

# Test POST /submissions (create a test submission)
curl -X POST "$API_GATEWAY_URL/submissions" \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "Test",
    "lastName": "User",
    "email": "test@example.com",
    "interests": "technology",
    "subscription": "free",
    "frequency": "weekly",
    "termsAccepted": true
  }'

echo "✅ API Gateway tests completed"
```

### 7.3 Test Complete Application Flow

1. **Access the Application**:
   - **S3 Direct**: `http://YOUR-BUCKET-NAME.s3-website-REGION.amazonaws.com`
   - **CloudFront** (after deployment): `https://YOUR-DISTRIBUTION-ID.cloudfront.net`

2. **Test Form Submission**:
   - Fill out the multi-step form
   - Submit and verify success message
   - Check that data appears in admin dashboard

3. **Test Admin Dashboard**:
   - Navigate to `/admin.html`
   - Login with: `admin` / `admin123`
   - Verify submissions are displayed
   - Test view/delete functionality

### 7.4 Monitor Lambda Function

```bash
# Check Lambda function logs
aws logs describe-log-groups --log-group-name-prefix "/aws/lambda/$LAMBDA_FUNCTION_NAME"

# View recent logs
aws logs filter-log-events \
    --log-group-name "/aws/lambda/$LAMBDA_FUNCTION_NAME" \
    --start-time $(date -d '1 hour ago' +%s)000
```

---

## Step 8: Configure Custom Domain (Optional)

### 8.1 Set Up Custom Domain for CloudFront

If you have a custom domain, you can configure it with CloudFront:

**Prerequisites:**
- Domain registered in Route 53 or external registrar
- SSL certificate in AWS Certificate Manager (ACM) in `us-east-1`

**Steps:**
1. **Request SSL Certificate** (if not already done):
   ```bash
   aws acm request-certificate \
       --domain-name "your-domain.com" \
       --domain-name "www.your-domain.com" \
       --validation-method DNS \
       --region us-east-1
   ```

2. **Update CloudFront Distribution**:
   - Go to CloudFront Console → Your Distribution → **Edit**
   - **Alternate Domain Names**: Add your domain
   - **SSL Certificate**: Select your ACM certificate
   - **Save Changes**

3. **Update DNS Records**:
   - Create CNAME record pointing your domain to CloudFront distribution

---

## Troubleshooting

### Common Issues and Solutions

#### 1. Lambda Function Can't Connect to RDS
**Symptoms**: Database connection timeouts, VPC-related errors

**Solutions**:
```bash
# Check Lambda is in correct VPC
aws lambda get-function-configuration --function-name "$LAMBDA_FUNCTION_NAME" \
    --query 'VpcConfig'

# Verify security group allows MySQL traffic
aws ec2 describe-security-groups --group-ids "$LAMBDA_SG_ID" "$RDS_SECURITY_GROUP_ID"

# Check subnet routing
aws ec2 describe-route-tables --filters "Name=association.subnet-id,Values=$LAMBDA_SUBNETS"
```

#### 2. CORS Errors in Browser
**Symptoms**: Browser console shows CORS policy errors

**Solutions**:
```bash
# Test OPTIONS request
curl -X OPTIONS "$API_GATEWAY_URL/submissions" -v

# Redeploy API Gateway
aws apigateway create-deployment \
    --rest-api-id "$API_ID" \
    --stage-name "$API_STAGE_NAME"
```

#### 3. S3 Website Returns 403 Forbidden
**Symptoms**: Cannot access S3 website, 403 errors

**Solutions**:
```bash
# Check bucket policy
aws s3api get-bucket-policy --bucket "$S3_BUCKET_NAME"

# Verify public access settings
aws s3api get-public-access-block --bucket "$S3_BUCKET_NAME"

# Re-apply bucket policy
aws s3api put-bucket-policy --bucket "$S3_BUCKET_NAME" --policy file://bucket-policy.json
```

#### 4. CloudFront Distribution Not Working
**Symptoms**: CloudFront returns errors or doesn't serve content

**Solutions**:
```bash
# Check distribution status
aws cloudfront get-distribution --id "$DISTRIBUTION_ID" \
    --query 'Distribution.Status'

# Wait for deployment to complete (can take 15+ minutes)
# Create invalidation if needed
aws cloudfront create-invalidation \
    --distribution-id "$DISTRIBUTION_ID" \
    --paths "/*"
```

### Debug Commands

```bash
# Check all resource IDs
source serverless-config.sh
load_resource_ids
cat "$RESOURCE_IDS_FILE"

# Test Lambda function directly
aws lambda invoke \
    --function-name "$LAMBDA_FUNCTION_NAME" \
    --payload '{"httpMethod":"GET","path":"/submissions"}' \
    response.json

cat response.json

# Check API Gateway deployment
aws apigateway get-deployments --rest-api-id "$API_ID"
```

---

## Cost Optimization

### Serverless Cost Benefits

**Before (ECS)**: Fixed costs for EC2 instances, ALB, etc.
**After (Serverless)**: Pay only for actual usage

**Estimated Monthly Costs** (for moderate traffic):
- **S3**: $1-5 (storage + requests)
- **CloudFront**: $1-10 (data transfer)
- **API Gateway**: $3.50 per million requests
- **Lambda**: $0.20 per million requests + compute time
- **RDS**: Unchanged (existing database)

**Total Serverless**: ~$5-20/month vs ~$50-100/month for ECS

### Cost Optimization Tips

1. **S3 Lifecycle Policies**:
   ```bash
   # Set up lifecycle policy for old versions
   aws s3api put-bucket-lifecycle-configuration \
       --bucket "$S3_BUCKET_NAME" \
       --lifecycle-configuration file://lifecycle-policy.json
   ```

2. **CloudFront Caching**:
   - Use appropriate cache headers
   - Set longer TTL for static assets

3. **Lambda Optimization**:
   - Right-size memory allocation
   - Optimize cold start times
   - Use connection pooling for database

---

## Cleanup and Resource Management

### 8.1 Clean Up Resources

When you're done testing or want to clean up:

```bash
# Load saved resource IDs
source serverless-config.sh
load_resource_ids

echo "=== Cleaning Up Serverless Resources ==="

# Delete CloudFront Distribution (takes time)
if [ -n "$DISTRIBUTION_ID" ]; then
    echo "Disabling CloudFront distribution..."
    aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" \
        --query 'DistributionConfig' > dist-config.json
    
    # Modify config to disable distribution
    jq '.Enabled = false' dist-config.json > dist-config-disabled.json
    
    ETAG=$(aws cloudfront get-distribution-config --id "$DISTRIBUTION_ID" \
        --query 'ETag' --output text)
    
    aws cloudfront update-distribution \
        --id "$DISTRIBUTION_ID" \
        --distribution-config file://dist-config-disabled.json \
        --if-match "$ETAG"
    
    echo "⏳ CloudFront distribution disabling... (this takes 15+ minutes)"
    echo "After it's disabled, delete with:"
    echo "aws cloudfront delete-distribution --id $DISTRIBUTION_ID --if-match NEW_ETAG"
fi

# Delete API Gateway
if [ -n "$API_ID" ]; then
    aws apigateway delete-rest-api --rest-api-id "$API_ID"
    echo "✅ API Gateway deleted"
fi

# Delete Lambda function
if [ -n "$LAMBDA_FUNCTION_NAME" ]; then
    aws lambda delete-function --function-name "$LAMBDA_FUNCTION_NAME"
    echo "✅ Lambda function deleted"
fi

# Delete Lambda security group
if [ -n "$LAMBDA_SG_ID" ]; then
    aws ec2 delete-security-group --group-id "$LAMBDA_SG_ID"
    echo "✅ Lambda security group deleted"
fi

# Delete IAM role
if [ -n "$LAMBDA_ROLE_NAME" ]; then
    aws iam detach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    aws iam detach-role-policy \
        --role-name "$LAMBDA_ROLE_NAME" \
        --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole
    
    aws iam delete-role --role-name "$LAMBDA_ROLE_NAME"
    echo "✅ IAM role deleted"
fi

# Empty and delete S3 bucket
if [ -n "$S3_BUCKET_NAME" ]; then
    aws s3 rm s3://"$S3_BUCKET_NAME" --recursive
    aws s3 rb s3://"$S3_BUCKET_NAME"
    echo "✅ S3 bucket deleted"
fi

# Clean up local files
rm -f bucket-policy.json cloudfront-config.json lambda-trust-policy.json
rm -f lambda-deployment.zip dist-config*.json response.json
rm -f "$RESOURCE_IDS_FILE"

echo "✅ Cleanup completed"
echo "Note: RDS database was preserved (shared with other weeks)"
```

### 8.2 Preserve Resources for Future Use

If you want to keep the serverless infrastructure:

```bash
# Save current configuration
cp "$RESOURCE_IDS_FILE" "serverless-backup-$(date +%Y%m%d).txt"

# Document your URLs
echo "=== Your Serverless Application URLs ==="
echo "S3 Website: $S3_WEBSITE_URL"
echo "CloudFront: $CLOUDFRONT_URL"
echo "API Gateway: $API_GATEWAY_URL"
echo "Admin Login: admin / admin123"
```

---

## Next Steps and Advanced Features

### Potential Enhancements

1. **Authentication & Authorization**:
   - Implement AWS Cognito for user management
   - Add JWT token-based authentication
   - Role-based access control

2. **Database Optimization**:
   - Consider Aurora Serverless for fully serverless database
   - Implement connection pooling with RDS Proxy
   - Add database caching with ElastiCache

3. **Monitoring & Observability**:
   - Set up CloudWatch dashboards
   - Implement X-Ray tracing
   - Add custom metrics and alarms

4. **CI/CD Pipeline**:
   - Automate deployments with AWS CodePipeline
   - Infrastructure as Code with AWS CDK or SAM
   - Automated testing and rollback capabilities

5. **Performance Optimization**:
   - Implement Lambda layers for shared dependencies
   - Use CloudFront edge locations for API caching
   - Optimize bundle sizes and cold starts

### Learning Resources

- **AWS Serverless Application Model (SAM)**: Framework for serverless applications
- **AWS CDK**: Infrastructure as Code with familiar programming languages
- **Serverless Framework**: Third-party framework for serverless development
- **AWS Well-Architected Serverless Lens**: Best practices for serverless architectures

---

## Summary

🎉 **Congratulations!** You've successfully migrated your 3-tier application to a fully serverless architecture!

### What You've Accomplished

✅ **Frontend**: Static website hosted on S3 with global CloudFront CDN  
✅ **Backend**: Serverless Lambda functions with API Gateway  
✅ **Database**: Integrated with existing RDS MySQL database  
✅ **Security**: VPC-enabled Lambda with proper IAM roles  
✅ **Performance**: Global content delivery and auto-scaling  
✅ **Cost Optimization**: Pay-per-use pricing model  

### Architecture Comparison

| Component | Week 5 (ECS) | Week 6 (Serverless) |
|-----------|--------------|---------------------|
| **Frontend** | Nginx on EC2 | S3 + CloudFront |
| **Backend** | Node.js on EC2 | Lambda Functions |
| **API** | Direct server calls | API Gateway |
| **Scaling** | Manual/Auto Scaling Groups | Automatic |
| **Management** | Server maintenance required | Fully managed |
| **Cost** | Fixed instance costs | Pay-per-use |

### Key Benefits Achieved

- **🚀 Zero Server Management**: No EC2 instances to patch or maintain
- **📈 Infinite Scalability**: Handles traffic spikes automatically
- **💰 Cost Efficiency**: Pay only for actual usage
- **🌍 Global Performance**: CloudFront edge locations worldwide
- **🔒 Enhanced Security**: AWS-managed infrastructure with fine-grained permissions
- **⚡ Fast Deployment**: Infrastructure changes deploy in minutes

Your application is now running on a modern, serverless architecture that scales automatically and requires minimal operational overhead!
