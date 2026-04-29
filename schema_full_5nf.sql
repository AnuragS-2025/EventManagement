-- =============================================================
--   Event & Ticket Management System — Fully Normalized Schema
--   Normalization Level: 5NF (Project-Join Normal Form)
-- =============================================================

CREATE DATABASE IF NOT EXISTS event_management;
USE event_management;

-- =============================================================
--  SECTION 1: CORE DIMENSIONAL ENTITIES (1NF - 3NF Compliant)
--  These entities form the independent foundations.
-- =============================================================

-- 1. ROLES
-- Extracts role names to avoid partial dependencies
CREATE TABLE roles (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255)
);

-- 2. USERS (Customers / Admins)
-- Only attributes fully dependent on the user ID are kept.
CREATE TABLE users (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    password     VARCHAR(255) NOT NULL,
    role_id      TINYINT UNSIGNED NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (role_id) REFERENCES roles(id) ON UPDATE CASCADE
);

-- 3. VENUE LOCATIONS
-- BC/3NF FIx: Extracts geographical hierarchy out of venues
CREATE TABLE venue_locations (
    id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city      VARCHAR(100) NOT NULL,
    state     VARCHAR(100),
    country   VARCHAR(100) NOT NULL DEFAULT 'USA',
    timezone  VARCHAR(50)  NOT NULL DEFAULT 'UTC',
    CONSTRAINT uq_location UNIQUE (city, state, country)
);

-- 4. VENUES
CREATE TABLE venues (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_name   VARCHAR(255) NOT NULL,
    address      VARCHAR(255),
    location_id  INT UNSIGNED NOT NULL,
    capacity     INT UNSIGNED,
    FOREIGN KEY (location_id) REFERENCES venue_locations(id) ON UPDATE CASCADE
);

-- 5. SEATS (Venue architectural layout)
CREATE TABLE seats (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_id    INT UNSIGNED NOT NULL,
    section     VARCHAR(50)  NOT NULL,
    seat_row    VARCHAR(10)  NOT NULL,
    seat_number VARCHAR(10)  NOT NULL,
    CONSTRAINT uq_venue_seat UNIQUE (venue_id, section, seat_row, seat_number),
    FOREIGN KEY (venue_id) REFERENCES venues(id) ON DELETE CASCADE
);

-- 6. EVENTS (Descriptive data only)
CREATE TABLE events (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name     VARCHAR(255) NOT NULL,
    description    TEXT,
    total_tickets  INT UNSIGNED NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- 7. EVENT SCHEDULE (Isolates temporal scheduling away from event description)
CREATE TABLE event_schedule (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL UNIQUE,
    venue_id    INT UNSIGNED NOT NULL,
    event_date  DATE         NOT NULL,
    event_time  TIME         NOT NULL,
    CONSTRAINT uq_venue_slot UNIQUE (venue_id, event_date, event_time),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (venue_id) REFERENCES venues(id)
);

-- 8. TICKET TYPES
CREATE TABLE ticket_types (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL,
    type_name   VARCHAR(100) NOT NULL,
    price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    quantity    INT UNSIGNED  NOT NULL,
    CONSTRAINT uq_ttype_event_name UNIQUE (event_id, type_name),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE
);

-- 9. ARTISTS
CREATE TABLE artists (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    artist_name VARCHAR(255) NOT NULL,
    genre       VARCHAR(100)
);

-- 10. SPONSORS
CREATE TABLE sponsors (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sponsor_name VARCHAR(255) NOT NULL,
    industry     VARCHAR(100)
);

-- 11. STATUS LOOKUPS
CREATE TABLE booking_statuses (
    id           TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_label VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE payment_statuses (
    id           TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_label VARCHAR(20) NOT NULL UNIQUE
);

CREATE TABLE payment_methods (
    id           TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    method_name  VARCHAR(50) NOT NULL UNIQUE
);

-- =============================================================
--  SECTION 2: 4NF & 5NF DECOMPOSITIONS
--  Decomposing multi-valued and join dependencies into binaries.
-- =============================================================

-- 12. EVENT ARTISTS (4NF: Removes Multi-Valued Dependency)
CREATE TABLE event_artists (
    event_id  INT UNSIGNED NOT NULL,
    artist_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, artist_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (artist_id) REFERENCES artists(id) ON DELETE CASCADE
);

-- 13. EVENT SPONSORS (4NF: Removes Multi-Valued Dependency)
CREATE TABLE event_sponsors (
    event_id   INT UNSIGNED NOT NULL,
    sponsor_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, sponsor_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (sponsor_id) REFERENCES sponsors(id) ON DELETE CASCADE
);

-- 14. EVENT CUSTOMERS (5NF Binary Projection)
-- Eliminates redundant join path inside bookings
CREATE TABLE event_customers (
    event_id    INT UNSIGNED NOT NULL,
    user_id     INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, user_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
);

-- 15. EVENT SEATS (5NF Binary Projection)
-- Eliminates multi-table traversal to see available event seats
CREATE TABLE event_seats (
    event_id INT UNSIGNED NOT NULL,
    seat_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, seat_id),
    FOREIGN KEY (event_id) REFERENCES events(id) ON DELETE CASCADE,
    FOREIGN KEY (seat_id) REFERENCES seats(id) ON DELETE CASCADE
);


-- =============================================================
--  SECTION 3: TRANSACTIONAL LEVEL
-- =============================================================

-- 16. BOOKINGS
-- Reverted 5NF: event_id is removed! Derived canonically from ticket mapping.
CREATE TABLE bookings (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    user_id      INT UNSIGNED NOT NULL,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id    TINYINT UNSIGNED NOT NULL,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (status_id) REFERENCES booking_statuses(id) ON UPDATE CASCADE
);

-- 17. BOOKING ITEMS
CREATE TABLE booking_items (
    id              INT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT UNSIGNED  NOT NULL,
    ticket_type_id  INT UNSIGNED  NOT NULL,
    quantity        INT UNSIGNED  NOT NULL CHECK (quantity >= 1),
    unit_price      DECIMAL(10,2) NOT NULL,
    CONSTRAINT uq_bitem_booking_type UNIQUE (booking_id, ticket_type_id),
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(id)
);

-- 18. PAYMENTS (New implementation fully normalized)
CREATE TABLE payments (
    id                 INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_id         INT UNSIGNED NOT NULL,
    payment_method_id  TINYINT UNSIGNED NOT NULL,
    payment_status_id  TINYINT UNSIGNED NOT NULL,
    amount             DECIMAL(10,2) NOT NULL,
    payment_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    transaction_ref    VARCHAR(100) UNIQUE,
    FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE,
    FOREIGN KEY (payment_method_id) REFERENCES payment_methods(id),
    FOREIGN KEY (payment_status_id) REFERENCES payment_statuses(id)
);

-- 19. TICKETS
CREATE TABLE tickets (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_item_id INT UNSIGNED NOT NULL,
    ticket_code     VARCHAR(64)  NOT NULL UNIQUE,
    issued_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_used         BOOLEAN DEFAULT FALSE,
    FOREIGN KEY (booking_item_id) REFERENCES booking_items(id) ON DELETE CASCADE
);

-- 20. CUSTOMER SEAT ASSIGNMENTS (5NF Irreducible Ternary)
-- Unifies the user, event, and seat constraint directly.
CREATE TABLE customer_seat_assignments (
    event_id    INT UNSIGNED NOT NULL,
    user_id     INT UNSIGNED NOT NULL,
    seat_id     INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, seat_id),
    FOREIGN KEY (event_id, user_id) REFERENCES event_customers(event_id, user_id) ON DELETE CASCADE,
    FOREIGN KEY (event_id, seat_id) REFERENCES event_seats(event_id, seat_id) ON DELETE CASCADE
);


-- =============================================================
--  SECTION 4: SAMPLE INSERT DATA
-- =============================================================

INSERT INTO roles (role_name) VALUES ('admin'), ('customer');
INSERT INTO booking_statuses (status_label) VALUES ('confirmed'), ('pending'), ('cancelled');
INSERT INTO payment_statuses (status_label) VALUES ('success'), ('failed'), ('refunded');
INSERT INTO payment_methods (method_name) VALUES ('credit_card'), ('paypal'), ('stripe');

INSERT INTO users (full_name, email, password, role_id) VALUES
    ('Admin Bob', 'admin@events.com', 'h4sh3d', 1),
    ('Alice User', 'alice@gmail.com', 'h4sh3d', 2);

INSERT INTO venue_locations (city, state, country) VALUES ('Austin', 'TX', 'USA');
INSERT INTO venues (venue_name, address, location_id, capacity) VALUES ('Moody Center', '2001 Robert Dedman Dr', 1, 15000);
INSERT INTO seats (venue_id, section, seat_row, seat_number) VALUES 
    (1, 'Lower', 'A', '1'), (1, 'Lower', 'A', '2');

INSERT INTO events (event_name, description, total_tickets) VALUES ('TX Country Fest', 'Live festival indoors', 10000);
INSERT INTO event_schedule (event_id, venue_id, event_date, event_time) VALUES (1, 1, '2025-06-15', '19:00:00');

INSERT INTO ticket_types (event_id, type_name, price, quantity) VALUES 
    (1, 'Standard Admission', 50.00, 9000), 
    (1, 'VIP Pit', 150.00, 1000);

-- Artists & Sponsors 
INSERT INTO artists (artist_name, genre) VALUES ('George Strait', 'Country');
INSERT INTO sponsors (sponsor_name, industry) VALUES ('Lone Star Beer', 'Beverage');

-- Resolving MVDs manually
INSERT INTO event_artists (event_id, artist_id) VALUES (1, 1);
INSERT INTO event_sponsors (event_id, sponsor_id) VALUES (1, 1);

-- Booking Process Data
INSERT INTO bookings (user_id, status_id) VALUES (2, 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price) VALUES (1, 1, 2, 50.00);

-- Payment logging
INSERT INTO payments (booking_id, payment_method_id, payment_status_id, amount, transaction_ref)
    VALUES (1, 1, 1, 100.00, 'TXN-938475938');

-- Generating tickets
INSERT INTO tickets (booking_item_id, ticket_code) VALUES 
    (1, 'QR-001-XYZ'), 
    (1, 'QR-002-ABC');

-- 5NF Linkages
INSERT INTO event_customers (event_id, user_id) VALUES (1, 2);
INSERT INTO event_seats (event_id, seat_id) VALUES (1, 1), (1, 2);
INSERT INTO customer_seat_assignments (event_id, user_id, seat_id) VALUES 
    (1, 2, 1), 
    (1, 2, 2);
