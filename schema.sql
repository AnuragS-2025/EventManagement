-- Create Database
CREATE DATABASE IF NOT EXISTS event_management;
USE event_management;

-- Create Users Table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    password VARCHAR(255) NOT NULL,
    role ENUM('admin', 'customer') DEFAULT 'customer',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Events Table
CREATE TABLE IF NOT EXISTS events (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    date DATE NOT NULL,
    time TIME NOT NULL,
    venue VARCHAR(255) NOT NULL,
    total_tickets INT NOT NULL,
    ticket_price DECIMAL(10,2) NOT NULL DEFAULT 50.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Bookings Table
CREATE TABLE IF NOT EXISTS bookings (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    event_id INT NOT NULL,
    tickets_booked INT NOT NULL,
    status ENUM('pending', 'paid') DEFAULT 'pending',
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
);

-- Create Payments Table
CREATE TABLE IF NOT EXISTS payments (
    id INT AUTO_INCREMENT PRIMARY KEY,
    booking_id INT NOT NULL,
    amount DECIMAL(10,2) NOT NULL,
    status ENUM('pending', 'completed') DEFAULT 'pending',
    payment_date TIMESTAMP DEFAULT NULL,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
);

-- Prevent Overbooking Trigger
DELIMITER //

CREATE TRIGGER before_booking_insert
BEFORE INSERT ON bookings
FOR EACH ROW
BEGIN
    DECLARE total_booked INT;
    DECLARE capacity INT;
    
    -- Get total currently booked tickets for the event (all bookings reserve capacity)
    SELECT COALESCE(SUM(tickets_booked), 0) INTO total_booked
    FROM bookings 
    WHERE event_id = NEW.event_id;
    
    -- Get total capacity for the event
    SELECT total_tickets INTO capacity
    FROM events
    WHERE id = NEW.event_id;
    
    -- Check if new booking exceeds capacity
    IF (total_booked + NEW.tickets_booked) > capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Booking failed: Not enough tickets available.';
    END IF;
END //

DELIMITER ;

-- Sample Data: Insert Users
INSERT INTO users (name, email, password, role) VALUES 
('Admin User', 'admin@example.com', 'hashedpassword1', 'admin'),
('John Doe', 'john@example.com', 'hashedpassword2', 'customer');

-- Sample Data: Insert Events
INSERT INTO events (name, description, date, time, venue, total_tickets, ticket_price) VALUES 
('Music Festival', 'A grand outdoor music festival.', '2024-12-15', '18:00:00', 'Central Park', 500, 75.00),
('Tech Conference', 'Annual tech conference with keynote speakers.', '2024-11-20', '09:00:00', 'Convention Center', 150, 150.00);

-- Sample Data: Insert Bookings
-- John Doe books 2 tickets for the Music Festival
INSERT INTO bookings (user_id, event_id, tickets_booked) VALUES 
(2, 1, 2);

-- John Doe books 1 ticket for the Tech Conference
INSERT INTO bookings (user_id, event_id, tickets_booked) VALUES 
(2, 2, 1);
