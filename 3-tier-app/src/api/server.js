require('dotenv').config();
const express = require('express');
const cors = require('cors');
const { v4: uuidv4 } = require('uuid');
const mysql = require('mysql2');
const app = express();
const port = process.env.PORT || 3000;

// Middleware
app.use(cors());
app.use(express.json());

// Database connection
const db = mysql.createConnection({
  host: process.env.DB_HOST || 'localhost',
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
