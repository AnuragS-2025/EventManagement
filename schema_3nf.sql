-- =============================================================
--   Event & Ticket Management System — 3NF Refactored Schema
-- =============================================================
CREATE DATABASE IF NOT EXISTS event_management;
USE event_management;

-- -------------------------------------------------------------
-- 1. ROLES  (extracted from users.role ENUM → own table)
--    Eliminates: transitive dependency users.role_name → role desc
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(50)  NOT NULL UNIQUE,    -- 'admin', 'customer', …
    description VARCHAR(255) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 2. CUSTOMERS  (renamed from "users"; auth-only data separated)
--    In the original schema users held name/email (contact data)
--    mixed with password (auth data) and role (access data).
--    Here we keep one table but FK role_id avoids repeating the
--    role description inside every user row.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    password     VARCHAR(255) NOT NULL,           -- hashed
    role_id      TINYINT UNSIGNED NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- 3. VENUES  (extracted from events.venue VARCHAR)
--    Original: venue was a free-text string duplicated across
--    every event row → update anomaly (rename venue = N rows).
--    3NF fix: venue becomes its own entity; events hold venue_id.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venues (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_name   VARCHAR(255) NOT NULL,
    address      VARCHAR(255) DEFAULT NULL,
    city         VARCHAR(100) DEFAULT NULL,
    capacity     INT UNSIGNED DEFAULT NULL        -- optional physical cap
);

-- -------------------------------------------------------------
-- 4. EVENTS  (venue_name → venue_id FK; ticket count stays here
--    because total_tickets is a property of the event itself)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name     VARCHAR(255) NOT NULL,
    description    TEXT         DEFAULT NULL,
    event_date     DATE         NOT NULL,
    event_time     TIME         NOT NULL,
    venue_id       INT UNSIGNED NOT NULL,
    total_tickets  INT UNSIGNED NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_event_venue
        FOREIGN KEY (venue_id) REFERENCES venues(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- 5. TICKET_TYPES  (new entity — makes the model extensible)
--    Separates ticket category (VIP, General, …) from bookings.
--    Each type has its own price → no price repeating in tickets.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_types (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL,
    type_name   VARCHAR(100) NOT NULL,            -- 'General', 'VIP', …
    price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    quantity    INT UNSIGNED NOT NULL,             -- tickets in this tier
    CONSTRAINT fk_ttype_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- 6. BOOKINGS  (header — one row per transaction)
--    Original bookings mixed "how many tickets" with the booking
--    itself.  Now a booking is just the header; actual ticket
--    allocation lives in booking_items (see below).
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT UNSIGNED NOT NULL,
    event_id        INT UNSIGNED NOT NULL,
    booking_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status          ENUM('confirmed','cancelled','pending') DEFAULT 'confirmed',
    CONSTRAINT fk_booking_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_booking_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- 7. BOOKING_ITEMS  (line items — replaces tickets_booked INT)
--    Original: a single column "tickets_booked" in bookings meant
--    you could only book one ticket type per booking.
--    3NF fix: each line item references a ticket_type, so the
--    price is NOT stored here (it comes from ticket_types) and
--    multi-type bookings are supported without repeating groups.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_items (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT UNSIGNED NOT NULL,
    ticket_type_id  INT UNSIGNED NOT NULL,
    quantity        INT UNSIGNED NOT NULL CHECK (quantity >= 1),
    -- unit_price snapshot preserved for historical accuracy
    unit_price      DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_bitem_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_bitem_ttype
        FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- 8. TICKETS  (individual seat/entry records — optional layer)
--    Each physical ticket is a row; references booking_items so
--    they know which booking + type they belong to.
--    ticket_code is the unique QR / barcode value per seat.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_item_id INT UNSIGNED NOT NULL,
    ticket_code     VARCHAR(64)  NOT NULL UNIQUE,  -- QR / barcode
    issued_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_used         BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_ticket_bitem
        FOREIGN KEY (booking_item_id) REFERENCES booking_items(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =============================================================
--  VIEWS  (convenience — replaces hand-written JOINs in code)
-- =============================================================

-- Booking summary used by getMyBookings
CREATE OR REPLACE VIEW vw_booking_summary AS
SELECT
    b.id              AS booking_id,
    b.booking_date,
    b.status,
    c.id              AS customer_id,
    c.full_name       AS customer_name,
    c.email           AS customer_email,
    e.id              AS event_id,
    e.event_name,
    e.event_date,
    e.event_time,
    v.venue_name,
    v.city,
    tt.type_name      AS ticket_type,
    bi.quantity       AS tickets_booked,
    bi.unit_price,
    (bi.quantity * bi.unit_price) AS line_total
FROM bookings        b
JOIN customers       c  ON c.id  = b.customer_id
JOIN events          e  ON e.id  = b.event_id
JOIN venues          v  ON v.id  = e.venue_id
JOIN booking_items   bi ON bi.booking_id = b.id
JOIN ticket_types    tt ON tt.id = bi.ticket_type_id;

-- Event availability used by getEvents / getEvent
CREATE OR REPLACE VIEW vw_event_availability AS
SELECT
    e.id            AS event_id,
    e.event_name,
    e.description,
    e.event_date,
    e.event_time,
    v.venue_name,
    v.city,
    e.total_tickets,
    COALESCE(SUM(bi.quantity), 0)                   AS tickets_sold,
    e.total_tickets - COALESCE(SUM(bi.quantity), 0) AS tickets_remaining
FROM events         e
JOIN venues         v  ON v.id = e.venue_id
LEFT JOIN bookings  b  ON b.event_id = e.id AND b.status = 'confirmed'
LEFT JOIN booking_items bi ON bi.booking_id = b.id
GROUP BY e.id, e.event_name, e.description, e.event_date,
         e.event_time, v.venue_name, v.city, e.total_tickets;

-- =============================================================
--  TRIGGERS
-- =============================================================

DELIMITER //

-- Prevent overbooking when a booking_item is inserted
CREATE TRIGGER trg_before_booking_item_insert
BEFORE INSERT ON booking_items
FOR EACH ROW
BEGIN
    DECLARE v_total_sold  INT UNSIGNED DEFAULT 0;
    DECLARE v_capacity    INT UNSIGNED DEFAULT 0;
    DECLARE v_event_id    INT UNSIGNED;

    -- Find event from ticket_type
    SELECT event_id INTO v_event_id
    FROM ticket_types WHERE id = NEW.ticket_type_id;

    -- Total already sold for this event (confirmed bookings)
    SELECT COALESCE(SUM(bi.quantity), 0)
    INTO v_total_sold
    FROM booking_items bi
    JOIN bookings      b  ON b.id = bi.booking_id
    JOIN ticket_types  tt ON tt.id = bi.ticket_type_id
    WHERE tt.event_id = v_event_id
      AND b.status    = 'confirmed';

    -- Capacity for this event
    SELECT total_tickets INTO v_capacity
    FROM events WHERE id = v_event_id;

    IF (v_total_sold + NEW.quantity) > v_capacity THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Booking failed: Not enough tickets available.';
    END IF;
END //

DELIMITER ;

-- =============================================================
--  SAMPLE DATA
-- =============================================================

-- Roles
INSERT INTO roles (role_name, description) VALUES
    ('admin',    'Full system access'),
    ('customer', 'Can browse events and book tickets');

-- Customers  (role_id 1 = admin, 2 = customer)
INSERT INTO customers (full_name, email, password, role_id) VALUES
    ('Admin User', 'admin@example.com', 'hashedpassword1', 1),
    ('John Doe',   'john@example.com',  'hashedpassword2', 2);

-- Venues
INSERT INTO venues (venue_name, address, city, capacity) VALUES
    ('Central Park',       '59th to 110th St', 'New York',   5000),
    ('Convention Center',  '1 Convention Pl',  'San Francisco', 500);

-- Events  (venue_id 1 = Central Park, 2 = Convention Center)
INSERT INTO events (event_name, description, event_date, event_time, venue_id, total_tickets) VALUES
    ('Music Festival',  'A grand outdoor music festival.',            '2024-12-15', '18:00:00', 1, 500),
    ('Tech Conference', 'Annual tech conference with keynote speakers.', '2024-11-20', '09:00:00', 2, 150);

-- Ticket types  (event 1 = Music Festival, event 2 = Tech Conference)
INSERT INTO ticket_types (event_id, type_name, price, quantity) VALUES
    (1, 'General', 29.99, 400),
    (1, 'VIP',     89.99, 100),
    (2, 'General', 49.99, 100),
    (2, 'VIP',    149.99,  50);

-- Booking: John Doe books 2 General tickets for Music Festival
INSERT INTO bookings (customer_id, event_id, status) VALUES (2, 1, 'confirmed');
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (1, 1, 2, 29.99);

-- Booking: John Doe books 1 General ticket for Tech Conference
INSERT INTO bookings (customer_id, event_id, status) VALUES (2, 2, 'confirmed');
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (2, 3, 1, 49.99);
