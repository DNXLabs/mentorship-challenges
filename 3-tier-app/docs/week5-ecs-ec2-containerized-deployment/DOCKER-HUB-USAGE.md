# Using FormApp Docker Images from Docker Hub

This guide explains how to use the pre-built FormApp Docker images from Docker Hub with your own configuration.

## 📦 Available Images

- **Web Server**: `thiago4go/formapp-web:latest`
- **API Server**: `thiago4go/formapp-api:latest`

## 🚀 Quick Start Options

### Option 1: Using Docker Compose (Recommended)

1. **Download the production template**:
   ```bash
   curl -O https://raw.githubusercontent.com/your-repo/docker-compose.production.yml
   ```

2. **Customize the environment variables** in the file:
   ```yaml
   environment:
     - DB_HOST=your-database-endpoint.com
     - DB_USER=your-username
     - DB_PASSWORD=your-password
     # ... other variables
   ```

3. **Start the application**:
   ```bash
   docker-compose -f docker-compose.production.yml up -d
   ```

### Option 2: Using Environment File

1. **Create your custom .env file**:
   ```bash
   # Copy the template
   curl -O https://raw.githubusercontent.com/your-repo/.env.template
   cp .env.template .env
   
   # Edit with your values
   nano .env
   ```

2. **Create a simple docker-compose.yml**:
   ```yaml
   version: '3.8'
   services:
     api:
       image: thiago4go/formapp-api:latest
       env_file: .env
       ports:
         - "3000:3000"
     web:
       image: thiago4go/formapp-web:latest
       ports:
         - "80:80"
       depends_on:
         - api
   ```

3. **Start the application**:
   ```bash
   docker-compose up -d
   ```

### Option 3: Direct Docker Run

```bash
# Start API container
docker run -d \
  --name formapp-api \
  -e DB_HOST=your-db-host.com \
  -e DB_USER=your-username \
  -e DB_PASSWORD=your-password \
  -e DB_NAME=your-database \
  -e NODE_ENV=production \
  -p 3000:3000 \
  thiago4go/formapp-api:latest

# Start Web container
docker run -d \
  --name formapp-web \
  --link formapp-api:api \
  -p 80:80 \
  thiago4go/formapp-web:latest
```

## ⚙️ Configuration Options

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `DB_HOST` | Database hostname | `my-rds.amazonaws.com` |
| `DB_USER` | Database username | `admin` |
| `DB_PASSWORD` | Database password | `secure123` |
| `DB_NAME` | Database name | `formapp` |

### Optional Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `NODE_ENV` | `production` | Application environment |
| `PORT` | `3000` | API server port |
| `DB_PORT` | `3306` | Database port |
| `CORS_ORIGIN` | `*` | Allowed CORS origins |
| `LOG_LEVEL` | `info` | Logging level |

## 🏗️ AWS ECS Deployment

### Task Definition Example

```json
{
  "family": "formapp-dockerhub",
  "networkMode": "bridge",
  "requiresCompatibilities": ["EC2"],
  "containerDefinitions": [
    {
      "name": "formapp-api",
      "image": "thiago4go/formapp-api:latest",
      "memory": 512,
      "portMappings": [{"hostPort": 3000, "containerPort": 3000}],
      "environment": [
        {"name": "NODE_ENV", "value": "production"},
        {"name": "DB_HOST", "value": "your-rds-endpoint.amazonaws.com"},
        {"name": "DB_NAME", "value": "formapp"}
      ],
      "secrets": [
        {
          "name": "DB_PASSWORD",
          "valueFrom": "arn:aws:secretsmanager:region:account:secret:db-password"
        }
      ]
    },
    {
      "name": "formapp-web",
      "image": "thiago4go/formapp-web:latest",
      "memory": 256,
      "portMappings": [{"hostPort": 80, "containerPort": 80}],
      "links": ["formapp-api"]
    }
  ]
}
```

## 🔒 Security Best Practices

### 1. Use AWS Secrets Manager for Sensitive Data

```bash
# Create secret
aws secretsmanager create-secret \
  --name formapp/database \
  --secret-string '{"username":"admin","password":"secure123"}'

# Reference in ECS task definition
"secrets": [
  {
    "name": "DB_USER",
    "valueFrom": "arn:aws:secretsmanager:region:account:secret:formapp/database:username::"
  },
  {
    "name": "DB_PASSWORD", 
    "valueFrom": "arn:aws:secretsmanager:region:account:secret:formapp/database:password::"
  }
]
```

### 2. Restrict CORS Origins

```bash
# Instead of CORS_ORIGIN=*
CORS_ORIGIN=https://yourdomain.com,https://www.yourdomain.com
```

### 3. Use Specific Image Tags

```yaml
# Instead of :latest, use specific versions
image: thiago4go/formapp-api:v1.0.0
```

## 🐛 Troubleshooting

### Check Container Logs

```bash
# View API logs
docker logs formapp-api

# View Web logs  
docker logs formapp-web

# Follow logs in real-time
docker logs -f formapp-api
```

### Health Check Endpoints

- **API Health**: `http://your-host:3000/health`
- **Web Health**: `http://your-host/` (should return the main page)

### Common Issues

1. **Database Connection Failed**
   - Check `DB_HOST`, `DB_USER`, `DB_PASSWORD` values
   - Ensure database is accessible from container network
   - Verify database security groups (for RDS)

2. **CORS Errors**
   - Update `CORS_ORIGIN` to include your frontend domain
   - Check browser developer tools for specific CORS errors

3. **Container Won't Start**
   - Check container logs: `docker logs container-name`
   - Verify all required environment variables are set
   - Ensure ports are not already in use

## 📚 Examples for Different Environments

### Development Environment

```yaml
services:
  api:
    image: thiago4go/formapp-api:latest
    environment:
      - NODE_ENV=development
      - DB_HOST=localhost
      - DB_USER=root
      - DB_PASSWORD=password
      - LOG_LEVEL=debug
      - CORS_ORIGIN=http://localhost:3000
```

### Production Environment

```yaml
services:
  api:
    image: thiago4go/formapp-api:latest
    environment:
      - NODE_ENV=production
      - DB_HOST=prod-rds.amazonaws.com
      - DB_USER=admin
      - DB_PASSWORD=secure-production-password
      - LOG_LEVEL=warn
      - CORS_ORIGIN=https://myapp.com
```

## 🔄 Updating to New Versions

```bash
# Pull latest images
docker pull thiago4go/formapp-api:latest
docker pull thiago4go/formapp-web:latest

# Restart containers
docker-compose down
docker-compose up -d
```

---

For more information, visit the [Docker Hub repositories](https://hub.docker.com/u/thiago4go) or check the project documentation.
