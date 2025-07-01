# Database Layer - Form Submission Storage

## Overview
This directory contains the MySQL database schema and initialization scripts for the form submission application. The schema stores user registration data in a MySQL database.

## Database Schema

### Submissions Table
The main table that stores all form submission data:

| Column | Type | Constraints | Description |
|--------|------|-------------|-------------|
| id | VARCHAR(36) | PRIMARY KEY | UUID for unique identification |
| firstName | VARCHAR(100) | NOT NULL | User's first name |
| lastName | VARCHAR(100) | NOT NULL | User's last name |
| email | VARCHAR(255) | NOT NULL | User's email address |
| phone | VARCHAR(20) | NULL | Optional phone number |
| interests | VARCHAR(100) | NOT NULL | Selected area of interest |
| subscription | VARCHAR(50) | NOT NULL | Subscription type (free/basic/premium) |
| frequency | VARCHAR(50) | NOT NULL | Contact frequency preference |
| comments | TEXT | NULL | Optional user comments |
| termsAccepted | BOOLEAN | NOT NULL | Terms and conditions acceptance |
| submittedAt | TIMESTAMP | DEFAULT CURRENT_TIMESTAMP | Submission timestamp |

## MySQL Setup

### Installation
```bash
# macOS
brew install mysql
brew services start mysql

# Ubuntu/Debian
sudo apt update
sudo apt install mysql-server
sudo systemctl start mysql

# Windows
# Download MySQL installer from mysql.com
```

### Database Setup
```bash
# Secure installation (recommended)
sudo mysql_secure_installation

# Connect to MySQL
mysql -u root -p

# Create database and user
CREATE DATABASE formapp;
CREATE USER 'formapp_user'@'localhost' IDENTIFIED BY 'secure_password';
GRANT ALL PRIVILEGES ON formapp.* TO 'formapp_user'@'localhost';
FLUSH PRIVILEGES;

# Use the database
USE formapp;

# Run the schema
source init.sql;
```

## Sample Data Explanation

The initialization scripts include three sample records:

1. **John Doe** - Premium subscriber interested in technology
2. **Jane Smith** - Basic subscriber interested in health & wellness  
3. **Michael Johnson** - Free subscriber interested in finance

These records help test the application functionality and demonstrate the data structure.

## Database Connection

### MySQL Connection String
```
mysql://formapp_user:secure_password@localhost:3306/formapp
```


## Backup and Restore

### MySQL Backup and Restore
```bash
# Backup
mysqldump -u formapp_user -p formapp > backup.sql

# Restore
mysql -u formapp_user -p formapp < backup.sql
```

## Performance Considerations

### Indexing
Consider adding indexes for frequently queried columns:

```sql
CREATE INDEX idx_email ON submissions(email);
CREATE INDEX idx_subscription ON submissions(subscription);
CREATE INDEX idx_submitted_at ON submissions(submittedAt);
```

### Query Optimization
- Use LIMIT for pagination
- Add WHERE clauses for filtering
- Consider partitioning for large datasets

## Security Best Practices

1. **User Permissions**: Create dedicated database users with minimal required permissions
2. **Password Security**: Use strong passwords and consider password rotation
3. **Network Security**: Restrict database access to application servers only
4. **Data Encryption**: Enable encryption at rest and in transit
5. **Regular Backups**: Implement automated backup strategies
6. **Audit Logging**: Enable database audit logs for security monitoring

## Troubleshooting

### Common Issues

**Connection Refused**
- Verify database server is running
- Check firewall settings
- Confirm connection parameters

**Authentication Failed**
- Verify username and password
- Check user permissions
- Ensure user can connect from the application host

**Table Not Found**
- Verify database exists
- Check if schema was properly created
- Confirm table names match application code

**Data Type Errors**
- Verify column types match application expectations
- Check for NULL constraints
- Validate data formats (especially dates and UUIDs)

### Monitoring
- Monitor database performance metrics
- Set up alerts for connection issues
- Track query execution times
- Monitor disk space usage

## Development vs Production

### Development
- Use local MySQL instance
- Enable query logging for debugging
- Use sample data for testing

### Production
- Use managed MySQL service (AWS RDS, Google Cloud SQL)
- Implement connection pooling
- Set up replication for high availability
- Configure automated backups
- Monitor performance metrics
- Enable SSL/TLS encryption
