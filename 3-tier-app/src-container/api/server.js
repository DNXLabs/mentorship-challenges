require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const mysql = require('mysql2');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors({
  origin: process.env.CORS_ORIGIN || '*',
  methods: process.env.CORS_METHODS || 'GET,POST,PUT,DELETE,OPTIONS',
  credentials: process.env.CORS_CREDENTIALS === 'true'
}));
app.use(express.json());

// Request logging middleware
if (process.env.ENABLE_REQUEST_LOGGING === 'true') {
  app.use((req, res, next) => {
    console.log(`${new Date().toISOString()} - ${req.method} ${req.path}`);
    next();
  });
}

// Database connection
const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
  port: process.env.DB_PORT || 3306,
  user: process.env.DB_USER || 'root',
  password: process.env.DB_PASSWORD || 'password',
  database: process.env.DB_NAME || 'formapp'
});

// Connect to database
db.connect((err) => {
  if (err) {
    console.error('Error connecting to database:', err);
    return;
  }
  console.log('Connected to database');
});

// Health check endpoint for ECS
app.get('/health', (req, res) => {
  // Check database connection
  db.ping((err) => {
    if (err) {
      console.error('Database health check failed:', err);
      return res.status(503).json({ 
        status: 'unhealthy', 
        database: 'disconnected',
        timestamp: new Date().toISOString()
      });
    }
    
    res.status(200).json({ 
      status: 'healthy', 
      database: 'connected',
      timestamp: new Date().toISOString(),
      version: process.env.npm_package_version || '1.0.0'
    });
  });
});

// Routes for form submissions
app.get('/api/submissions', (req, res) => {
  db.query('SELECT * FROM submissions ORDER BY submittedAt DESC', (err, results) => {
    if (err) {
      console.error('Error fetching submissions:', err);
      return res.status(500).json({ error: 'Failed to fetch submissions' });
    }
    res.json(results);
  });
});

app.post('/api/submissions', (req, res) => {
  const { 
    firstName, lastName, email, phone, 
    interests, subscription, frequency, 
    comments, termsAccepted 
  } = req.body;
  
  // Validate required fields
  if (!firstName || !lastName || !email || !interests || !subscription) {
    return res.status(400).json({ error: 'Required fields are missing' });
  }
  
  // Validate email format
  const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
  if (!emailRegex.test(email)) {
    return res.status(400).json({ error: 'Invalid email format' });
  }
  
  const submission = {
    id: uuidv4(),
    firstName,
    lastName,
    email,
    phone: phone || null,
    interests,
    subscription,
    frequency: frequency || 'weekly',
    comments: comments || null,
    termsAccepted: termsAccepted === true,
    submittedAt: new Date()
  };
  
  db.query('INSERT INTO submissions SET ?', submission, (err, result) => {
    if (err) {
      console.error('Error creating submission:', err);
      return res.status(500).json({ error: 'Failed to create submission' });
    }
    res.status(201).json(submission);
  });
});

app.get('/api/submissions/:id', (req, res) => {
  const { id } = req.params;
  
  db.query('SELECT * FROM submissions WHERE id = ?', id, (err, results) => {
    if (err) {
      console.error('Error fetching submission:', err);
      return res.status(500).json({ error: 'Failed to fetch submission' });
    }
    
    if (results.length === 0) {
      return res.status(404).json({ error: 'Submission not found' });
    }
    
    res.json(results[0]);
  });
});

app.delete('/api/submissions/:id', (req, res) => {
  const { id } = req.params;
  
  db.query('DELETE FROM submissions WHERE id = ?', id, (err, result) => {
    if (err) {
      console.error('Error deleting submission:', err);
      return res.status(500).json({ error: 'Failed to delete submission' });
    }
    
    if (result.affectedRows === 0) {
      return res.status(404).json({ error: 'Submission not found' });
    }
    
    res.json({ message: 'Submission deleted successfully' });
  });
});

// Serve static files (for EC2 deployment)
app.use(express.static('public'));

// Start server
app.listen(port, () => {
  console.log(`Server running on port ${port}`);
});
