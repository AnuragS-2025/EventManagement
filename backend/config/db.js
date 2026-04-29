const mysql = require('mysql2');
const dotenv = require('dotenv');
const path = require('path');

// Load .env from the current directory (backend/)
const envPath = path.resolve(__dirname, '../.env');
const result = dotenv.config({ path: envPath });

console.log('--- Database Config Debug ---');
console.log('Searching for .env at:', envPath);

if (result.error) {
    console.error('Error loading .env file:', result.error.message);
} else {
    console.log('.env file loaded successfully');
}

// Log check (without showing full password for security, but showing enough to verify it's loaded)
console.log('DB_HOST:', process.env.DB_HOST || 'MISSING');
console.log('DB_USER:', process.env.DB_USER || 'MISSING');
console.log('DB_NAME:', process.env.DB_NAME || 'MISSING');
console.log('DB_PASSWORD:', process.env.DB_PASSWORD ? '********' : 'MISSING');
console.log('-----------------------------');

if (!process.env.DB_HOST || !process.env.DB_USER || !process.env.DB_NAME) {
    console.error('CRITICAL ERROR: Missing required database environment variables.');
    process.exit(1);
}

const pool = mysql.createPool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT || 3306,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    waitForConnections: true,
    connectionLimit: 10,
    queueLimit: 0
});

// Soft migration logic
pool.getConnection((err, connection) => {
    if (err) {
        console.error('Database connection failed:', err.message);
    } else {
        console.log('Database connected successfully');
        
        // Ensure payments table exists
        connection.query(`
            CREATE TABLE IF NOT EXISTS payments (
                id INT AUTO_INCREMENT PRIMARY KEY,
                booking_id INT NOT NULL,
                amount DECIMAL(10,2) NOT NULL,
                status VARCHAR(20) DEFAULT 'pending',
                payment_date TIMESTAMP NULL DEFAULT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
            )
        `, () => {
            // Ensure payment_date column exists if table was already created
            connection.query(`ALTER TABLE payments ADD COLUMN IF NOT EXISTS payment_date TIMESTAMP NULL DEFAULT NULL`, () => {
            // Update events table
            connection.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS ticket_price DECIMAL(10,2) DEFAULT 0.00`, () => {
                connection.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS image_url VARCHAR(500) DEFAULT NULL`, () => {
                    connection.query(`ALTER TABLE events ADD COLUMN IF NOT EXISTS category VARCHAR(50) DEFAULT 'General'`, () => {
                        // Update bookings table status
                        connection.query(`ALTER TABLE bookings MODIFY COLUMN status ENUM('pending', 'paid', 'confirmed') DEFAULT 'pending'`, () => {
                            // Update trigger
                            connection.query(`DROP TRIGGER IF EXISTS before_booking_insert`, () => {
                                connection.query(`
                                    CREATE TRIGGER before_booking_insert
                                    BEFORE INSERT ON bookings
                                    FOR EACH ROW
                                    BEGIN
                                        DECLARE total_booked INT;
                                        DECLARE capacity INT;
                                        SELECT COALESCE(SUM(tickets_booked), 0) INTO total_booked FROM bookings WHERE event_id = NEW.event_id;
                                        SELECT total_tickets INTO capacity FROM events WHERE id = NEW.event_id;
                                        IF (total_booked + NEW.tickets_booked) > capacity THEN
                                            SIGNAL SQLSTATE '45000' SET MESSAGE_TEXT = 'Booking failed: Not enough tickets available.';
                                        END IF;
                                    END;
                                `, () => {
                                    connection.release();
                                    console.log('Database migrations completed');
                                });
                            });
                        });
                    });
                });
            });
        });
    }
});

module.exports = pool.promise();
