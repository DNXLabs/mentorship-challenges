-- Create database
CREATE DATABASE IF NOT EXISTS formapp;
USE formapp;

-- Create submissions table
CREATE TABLE IF NOT EXISTS submissions (
  id VARCHAR(36) PRIMARY KEY,
  firstName VARCHAR(100) NOT NULL,
  lastName VARCHAR(100) NOT NULL,
  email VARCHAR(255) NOT NULL,
  phone VARCHAR(20),
  interests VARCHAR(100) NOT NULL,
  subscription VARCHAR(50) NOT NULL,
  frequency VARCHAR(50) NOT NULL,
  comments TEXT,
  termsAccepted BOOLEAN NOT NULL,
  submittedAt TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Insert some sample data
INSERT INTO submissions (id, firstName, lastName, email, phone, interests, subscription, frequency, comments, termsAccepted, submittedAt) VALUES
  (UUID(), 'John', 'Doe', 'john.doe@example.com', '1234567890', 'technology', 'premium', 'weekly', 'Looking forward to learning more!', true, NOW()),
  (UUID(), 'Jane', 'Smith', 'jane.smith@example.com', '9876543210', 'health', 'basic', 'monthly', 'Interested in wellness programs', true, NOW()),
  (UUID(), 'Michael', 'Johnson', 'michael.j@example.com', NULL, 'finance', 'free', 'daily', NULL, true, NOW());
