# 3-Tier Form Application

## Overview
This is a complete 3-tier web application for user registration with a multi-step form interface. The application demonstrates modern web architecture patterns and can be deployed using various technology stacks.

## Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Web Tier      │    │   API Tier      │    │ Database Tier   │
│                 │    │                 │    │                 │
│ • HTML/CSS/JS   │◄──►│ • Node.js       │◄──►│ • MySQL         │
│ • Nginx         │    │ • Express.js    │    │                 │
│ • Static Files  │    │ • REST API      │    │                 │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### Recommended Technology Stack
- **Web Server**: Nginx (high performance, production-ready)
- **API Server**: Node.js with Express.js (JavaScript full-stack)
- **Database**: MySQL (reliable, widely supported)

### Tier Breakdown

**🌐 Web Tier** (`web/`)
- Multi-step registration form with validation
- Admin dashboard for managing submissions
- Responsive design with vanilla HTML/CSS/JavaScript
- Served by Nginx with reverse proxy to API

**⚙️ API Tier** (`api/`)
- RESTful API built with Node.js and Express
- CRUD operations for form submissions
- Input validation and error handling
- CORS support and UUID generation

**🗄️ Database Tier** (`database/`)
- MySQL database with submissions table
- Sample data for testing
- Backup and restore procedures

## Features

### User Features
- **Multi-step form** with intuitive navigation
- **Real-time validation** with helpful error messages
- **Responsive design** that works on all devices
- **Success confirmation** after submission
- **Professional styling** with clean UI

### Admin Features
- **Dashboard authentication** (demo: admin/admin123)
- **View all submissions** in sortable table format
- **Filter and search** submissions by criteria
- **Detailed view** of individual submissions
- **Delete submissions** with confirmation
- **Real-time data refresh**

### Technical Features
- **RESTful API** with proper HTTP status codes
- **Input validation** on both client and server side
- **Error handling** with user-friendly messages
- **CORS support** for cross-origin requests
- **Production-ready stack** with proven technologies

## Quick Start Guide

### Prerequisites
- Node.js 14+
- MySQL 8.0+
- Nginx

### Setup Instructions
```bash
# 1. Set up MySQL database
mysql -u root -p
CREATE DATABASE formapp;
CREATE USER 'formapp_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON formapp.* TO 'formapp_user'@'localhost';
USE formapp;
source database/init.sql;

# 2. Set up API server
cd api
npm install
cat > .env << EOF
DB_HOST=localhost
DB_USER=formapp_user
DB_PASSWORD=secure_password
DB_NAME=formapp
PORT=3000
EOF
npm start

# 3. Set up Nginx web server
sudo cp web/*.html /usr/share/nginx/html/
sudo cp web/nginx.conf /etc/nginx/sites-available/formapp
sudo ln -s /etc/nginx/sites-available/formapp /etc/nginx/sites-enabled/
sudo nginx -s reload

# 4. Access the application
# User form: http://localhost
# Admin dashboard: http://localhost/admin.html
```

## API Endpoints

### Submissions Management
```
GET    /api/submissions     # Get all submissions
POST   /api/submissions     # Create new submission
GET    /api/submissions/:id # Get specific submission
DELETE /api/submissions/:id # Delete submission
```

### Example API Usage
```bash
# Create a submission
curl -X POST http://localhost:3000/api/submissions \
  -H "Content-Type: application/json" \
  -d '{
    "firstName": "John",
    "lastName": "Doe",
    "email": "john@example.com",
    "interests": "technology",
    "subscription": "premium"
  }'

# Get all submissions
curl http://localhost:3000/api/submissions

# Delete a submission
curl -X DELETE http://localhost:3000/api/submissions/{id}
```

## Database Schema

### Submissions Table
```sql
CREATE TABLE submissions (
  id VARCHAR(36) PRIMARY KEY,           -- UUID
  firstName VARCHAR(100) NOT NULL,      -- User's first name
  lastName VARCHAR(100) NOT NULL,       -- User's last name
  email VARCHAR(255) NOT NULL,          -- Email address
  phone VARCHAR(20),                    -- Optional phone
  interests VARCHAR(100) NOT NULL,      -- Selected interest
  subscription VARCHAR(50) NOT NULL,    -- Subscription type
  frequency VARCHAR(50) NOT NULL,       -- Contact frequency
  comments TEXT,                        -- Optional comments
  termsAccepted BOOLEAN NOT NULL,       -- Terms acceptance
  submittedAt TIMESTAMP DEFAULT NOW()   -- Submission time
);
```

## Development Workflow

### Local Development
```bash
# Terminal 1: Start MySQL
mysql.server start

# Terminal 2: Start API server
cd api
npm start

# Terminal 3: Start Nginx
sudo nginx

# Access application at http://localhost
```

### Making Changes
1. **Frontend changes**: Edit files in `web/` directory
2. **API changes**: Edit files in `api/` directory, restart server
3. **Database changes**: Update schema in `database/` directory
4. **Testing**: Use browser dev tools and API testing tools

## Deployment Options

### Production Deployment
- **Database**: MySQL with proper user management and security
- **API**: Node.js with PM2 process manager for reliability
- **Web**: Nginx with SSL/TLS certificates and caching
- **Security**: HTTPS, firewall, regular updates
- **Monitoring**: Log aggregation and performance monitoring

## Security Considerations

### Current Security Features
- Input validation on client and server
- SQL injection prevention through parameterized queries
- CORS configuration for cross-origin requests
- Basic admin authentication (demo purposes)

### Production Security Enhancements
- **Authentication**: Implement JWT or session-based auth
- **HTTPS**: Enable SSL/TLS certificates
- **Rate Limiting**: Prevent API abuse
- **Input Sanitization**: Enhanced validation and escaping
- **Database Security**: Encrypted connections, user permissions
- **Monitoring**: Security event logging and alerting

## Performance Optimization

### Database Performance
- Add indexes on frequently queried columns
- Implement connection pooling
- Use database query optimization
- Consider read replicas for high traffic

### API Performance
- Implement caching (Redis)
- Add compression middleware
- Use CDN for static assets
- Monitor and optimize slow queries

### Frontend Performance
- Minify CSS and JavaScript
- Optimize images and assets
- Implement lazy loading
- Use browser caching effectively

## Troubleshooting

### Common Issues

**Database Connection Failed**
```bash
# Check if MySQL is running
sudo systemctl status mysql

# Verify connection credentials
mysql -u formapp_user -p formapp

# Check firewall settings
sudo ufw status
```

**API Server Won't Start**
```bash
# Check if port 3000 is in use
lsof -i :3000

# Verify Node.js version
node --version  # Should be 14+

# Check for missing dependencies
npm install
```

**Frontend Not Loading**
```bash
# Check Nginx status
sudo systemctl status nginx

# Verify file permissions
ls -la /usr/share/nginx/html/

# Check browser console for errors
# Open Developer Tools > Console
```

**CORS Errors**
- Ensure API server has CORS enabled
- Check if Nginx proxy configuration is correct
- Verify API_URL in JavaScript files points to correct endpoint

## Documentation

### Detailed Setup Guides
- **API Documentation**: See `api/README.md`
- **Database Setup**: See `database/README.md`
- **Frontend Guide**: See `web/README.md`

### Getting Help
- Check the troubleshooting sections in each README
- Review browser console and server logs
- Test API endpoints with curl or Postman
- Verify database connectivity and schema

## Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly across all tiers
5. Submit a pull request

### Code Style
- Use consistent indentation (2 spaces)
- Add comments for complex logic
- Follow REST API conventions
- Validate all user inputs
- Handle errors gracefully

## License

This project is open source and available under the MIT License.
