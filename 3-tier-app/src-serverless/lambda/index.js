const mysql = require('mysql2/promise');
const { v4: uuidv4 } = require('uuid');

// Database connection configuration
const dbConfig = {
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectTimeout: 60000,
    acquireTimeout: 60000,
    timeout: 60000
};

// CORS headers
const corsHeaders = {
    'Access-Control-Allow-Origin': '*',
    'Access-Control-Allow-Headers': 'Content-Type,X-Amz-Date,Authorization,X-Api-Key,X-Amz-Security-Token',
    'Access-Control-Allow-Methods': 'GET,POST,DELETE,OPTIONS'
};

// Response helper
const createResponse = (statusCode, body) => ({
    statusCode,
    headers: corsHeaders,
    body: JSON.stringify(body)
});

// Database connection helper
const getConnection = async () => {
    try {
        const connection = await mysql.createConnection(dbConfig);
        return connection;
    } catch (error) {
        console.error('Database connection error:', error);
        throw new Error('Database connection failed');
    }
};

// Validate email format
const isValidEmail = (email) => {
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return emailRegex.test(email);
};

// GET /submissions - Retrieve all submissions
const getSubmissions = async () => {
    let connection;
    try {
        connection = await getConnection();
        const [rows] = await connection.execute(
            'SELECT * FROM submissions ORDER BY submittedAt DESC'
        );
        return createResponse(200, rows);
    } catch (error) {
        console.error('Error fetching submissions:', error);
        return createResponse(500, { 
            error: 'Failed to fetch submissions',
            message: error.message 
        });
    } finally {
        if (connection) await connection.end();
    }
};

// GET /submissions/{id} - Retrieve specific submission
const getSubmission = async (id) => {
    let connection;
    try {
        connection = await getConnection();
        const [rows] = await connection.execute(
            'SELECT * FROM submissions WHERE id = ?',
            [id]
        );
        
        if (rows.length === 0) {
            return createResponse(404, { error: 'Submission not found' });
        }
        
        return createResponse(200, rows[0]);
    } catch (error) {
        console.error('Error fetching submission:', error);
        return createResponse(500, { 
            error: 'Failed to fetch submission',
            message: error.message 
        });
    } finally {
        if (connection) await connection.end();
    }
};

// POST /submissions - Create new submission
const createSubmission = async (body) => {
    let connection;
    try {
        const data = JSON.parse(body);
        
        // Validate required fields
        const { firstName, lastName, email, interests, subscription } = data;
        
        if (!firstName || !lastName || !email || !interests || !subscription) {
            return createResponse(400, { 
                error: 'Required fields are missing',
                required: ['firstName', 'lastName', 'email', 'interests', 'subscription']
            });
        }
        
        // Validate email format
        if (!isValidEmail(email)) {
            return createResponse(400, { error: 'Invalid email format' });
        }
        
        // Create submission object
        const submission = {
            id: uuidv4(),
            firstName: firstName.trim(),
            lastName: lastName.trim(),
            email: email.trim(),
            phone: data.phone ? data.phone.trim() : null,
            interests,
            subscription,
            frequency: data.frequency || 'weekly',
            comments: data.comments ? data.comments.trim() : null,
            termsAccepted: data.termsAccepted === true,
            submittedAt: new Date()
        };
        
        connection = await getConnection();
        await connection.execute(
            `INSERT INTO submissions 
             (id, firstName, lastName, email, phone, interests, subscription, frequency, comments, termsAccepted, submittedAt) 
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`,
            [
                submission.id,
                submission.firstName,
                submission.lastName,
                submission.email,
                submission.phone,
                submission.interests,
                submission.subscription,
                submission.frequency,
                submission.comments,
                submission.termsAccepted,
                submission.submittedAt
            ]
        );
        
        return createResponse(201, submission);
    } catch (error) {
        console.error('Error creating submission:', error);
        
        if (error instanceof SyntaxError) {
            return createResponse(400, { error: 'Invalid JSON format' });
        }
        
        return createResponse(500, { 
            error: 'Failed to create submission',
            message: error.message 
        });
    } finally {
        if (connection) await connection.end();
    }
};

// DELETE /submissions/{id} - Delete submission
const deleteSubmission = async (id) => {
    let connection;
    try {
        connection = await getConnection();
        const [result] = await connection.execute(
            'DELETE FROM submissions WHERE id = ?',
            [id]
        );
        
        if (result.affectedRows === 0) {
            return createResponse(404, { error: 'Submission not found' });
        }
        
        return createResponse(200, { message: 'Submission deleted successfully' });
    } catch (error) {
        console.error('Error deleting submission:', error);
        return createResponse(500, { 
            error: 'Failed to delete submission',
            message: error.message 
        });
    } finally {
        if (connection) await connection.end();
    }
};

// Main Lambda handler
exports.handler = async (event) => {
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const { httpMethod, path, pathParameters, body } = event;
    
    // Handle CORS preflight requests
    if (httpMethod === 'OPTIONS') {
        return createResponse(200, { message: 'CORS preflight' });
    }
    
    try {
        // Route requests based on HTTP method and path
        if (httpMethod === 'GET' && path === '/submissions') {
            return await getSubmissions();
        }
        
        if (httpMethod === 'GET' && path.startsWith('/submissions/') && pathParameters?.id) {
            return await getSubmission(pathParameters.id);
        }
        
        if (httpMethod === 'POST' && path === '/submissions') {
            return await createSubmission(body);
        }
        
        if (httpMethod === 'DELETE' && path.startsWith('/submissions/') && pathParameters?.id) {
            return await deleteSubmission(pathParameters.id);
        }
        
        // Route not found
        return createResponse(404, { error: 'Route not found' });
        
    } catch (error) {
        console.error('Handler error:', error);
        return createResponse(500, { 
            error: 'Internal server error',
            message: error.message 
        });
    }
};
