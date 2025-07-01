# API Server - Form Submission Backend

## Overview
This is a Node.js REST API server that handles form submissions for a multi-step registration form. It provides CRUD operations for user submissions and connects to a database for persistent storage.

## Technology Stack
- **Runtime**: Node.js 14+
- **Framework**: Express.js
- **Database**: MySQL
- **Additional Libraries**: CORS, UUID for unique IDs

## Features
- RESTful API endpoints for form submissions
- Input validation and sanitization
- CORS support for cross-origin requests
- UUID generation for unique submission IDs
- Error handling and proper HTTP status codes

## API Endpoints

### GET /api/submissions
- **Description**: Retrieve all form submissions
- **Response**: Array of submission objects
- **Status Codes**: 200 (success), 500 (server error)

### POST /api/submissions
- **Description**: Create a new form submission
- **Request Body**: JSON object with form data
- **Required Fields**: firstName, lastName, email, interests, subscription
- **Response**: Created submission object with generated ID
- **Status Codes**: 201 (created), 400 (validation error), 500 (server error)

### GET /api/submissions/:id
- **Description**: Retrieve a specific submission by ID
- **Parameters**: id (UUID)
- **Response**: Submission object
- **Status Codes**: 200 (success), 404 (not found), 500 (server error)

### DELETE /api/submissions/:id
- **Description**: Delete a specific submission
- **Parameters**: id (UUID)
- **Response**: Success message
- **Status Codes**: 200 (success), 404 (not found), 500 (server error)

## Database Setup

### MySQL Installation & Setup
```bash
# Install MySQL 8.0+
# macOS
brew install mysql
brew services start mysql

# Ubuntu/Debian
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql

# Create database and user
mysql -u root -p
CREATE DATABASE formapp;
CREATE USER 'formapp_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON formapp.* TO 'formapp_user'@'localhost';
FLUSH PRIVILEGES;
```

## Installation & Setup

### Prerequisites
- Node.js 14 or higher
- npm or yarn package manager
- MySQL 8.0+

### Step 1: Install Dependencies
```bash
cd api
npm install
```

### Step 2: Environment Configuration
Create a `.env` file in the api directory:

```env
# Server Configuration
PORT=3000

# MySQL Configuration
DB_HOST=localhost
DB_USER=formapp_user
DB_PASSWORD=secure_password
DB_NAME=formapp
```

### Step 3: Database Schema
Run the MySQL schema creation script:
```bash
mysql -u formapp_user -p formapp < ../database/init.sql
```

### Step 4: Start the Server
```bash
# Development
npm start

# With nodemon for auto-restart
npm install -g nodemon
nodemon server.js

# Production
NODE_ENV=production node server.js
```


## Testing the API

### Using curl
```bash
# Get all submissions
curl http://localhost:3000/api/submissions

# Create a new submission
curl -X POST http://localhost:3000/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "interests": "technology",
    "subscription": "premium"
  }'

# Get specific submission
curl http://localhost:3000/api/submissions/{submission-id}

# Delete submission
curl -X DELETE http://localhost:3000/api/submissions/{submission-id}
```

### Using Postman
Import the following collection or create requests manually:
- GET: `http://localhost:3000/api/submissions`
- POST: `http://localhost:3000/api/submissions` (with JSON body)
- GET: `http://localhost:3000/api/submissions/{id}`
- DELETE: `http://localhost:3000/api/submissions/{id}`

## Deployment Options

### Standalone Deployment
The API can run independently and serve static files:
```javascript
// Already configured in server.js
app.use(express.static('public'));
```

### Behind Reverse Proxy
Configure Nginx to proxy API requests (see `../web/nginx.conf` for configuration example).

### Production Deployment
- **PM2**: Use PM2 for process management and auto-restart
- **AWS EC2**: Deploy on EC2 with RDS MySQL database
- **Load Balancing**: Use multiple instances behind a load balancer

## Troubleshooting

### Common Issues

**Database Connection Errors**
- Verify database server is running
- Check connection credentials in environment variables
- Ensure database and tables exist

**Port Already in Use**
```bash
# Find process using port 3000
lsof -i :3000
# Kill the process
kill -9 <PID>
```

**CORS Issues**
- Verify CORS is properly configured
- Check if frontend URL is allowed
- For development, CORS is set to allow all origins

**Module Not Found**
```bash
# Reinstall dependencies
rm -rf node_modules package-lock.json
npm install
```

### Logging
Enable detailed logging by setting:
```env
NODE_ENV=development
DEBUG=*
```

## Security Considerations
- Input validation is implemented for all endpoints
- Use environment variables for sensitive configuration
- Consider implementing authentication for production use
- Add rate limiting for production deployment
- Use HTTPS in production environments

## Performance Tips
- Implement database connection pooling for high traffic
- Add caching layer (Redis) for frequently accessed data
- Use compression middleware for response optimization
- Monitor database query performance
