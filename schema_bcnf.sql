-- =============================================================
--   Event & Ticket Management System — BCNF Refactored Schema
--   Upgraded from: schema_3nf.sql
-- =============================================================
--
--  BCNF RULE: For every non-trivial FD  X → Y,  X must be a
--  superkey (i.e., X alone uniquely identifies every row).
--
--  Changes over 3NF:
--    [A] venues split → venues + venue_locations
--        FD city → country/timezone is NOT a superkey dep.
--    [B] ticket_types UNIQUE key (event_id, type_name) exposed →
--        surrogate PK verified as the only determinant
--    [C] booking_items composite candidate key exposed →
--        (booking_id, ticket_type_id) declared UNIQUE
--    [D] event_schedule extracted from events →
--        (venue_id, event_date, event_time) must be unique;
--        that composite is a candidate key separate from event.id
--    [E] ticket_code in tickets → only determinant; confirmed OK
--    [F] roles.role_name UNIQUE → second candidate key; OK in BCNF
--    [G] customers.email UNIQUE → second candidate key; OK in BCNF
-- =============================================================

CREATE DATABASE IF NOT EXISTS event_management;
USE event_management;

-- -------------------------------------------------------------
-- 1. ROLES
--    CKs: {id},  {role_name}
--    FDs: id → role_name,description  |  role_name → id,description
--    Both determinants are CKs → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 2. CUSTOMERS
--    CKs: {id},  {email}
--    FDs: id → * | email → *
--    Both determinants are CKs → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customers (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    full_name    VARCHAR(100) NOT NULL,
    email        VARCHAR(100) NOT NULL UNIQUE,
    password     VARCHAR(255) NOT NULL,
    role_id      TINYINT UNSIGNED NOT NULL,
    created_at   TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_customer_role
        FOREIGN KEY (role_id) REFERENCES roles(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- [A-1] VENUE_LOCATIONS  ← NEW, split from 3NF venues
--
--  Problem in 3NF venues:
--    venues(id, venue_name, address, city, capacity)
--
--  Hidden FD:   city → country, timezone, region
--  "city" is NOT a superkey of venues, yet it determines
--  country/timezone — a BCNF violation.
--
--  Fix: extract geographic hierarchy into venue_locations.
--  venue_locations CKs: {id}, {city, country} (composite)
--  Every FD's determinant is a CK → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venue_locations (
    id        INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    city      VARCHAR(100) NOT NULL,
    state     VARCHAR(100) DEFAULT NULL,
    country   VARCHAR(100) NOT NULL DEFAULT 'USA',
    timezone  VARCHAR(50)  NOT NULL DEFAULT 'UTC',
    CONSTRAINT uq_venue_location UNIQUE (city, state, country)
);

-- -------------------------------------------------------------
-- [A-2] VENUES  (trimmed; city/country replaced by location_id FK)
--    CKs: {id},  {venue_name, location_id}
--    FDs: id → *  |  (venue_name, location_id) → *
--    Both determinants are CKs → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS venues (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_name   VARCHAR(255) NOT NULL,
    address      VARCHAR(255) DEFAULT NULL,
    location_id  INT UNSIGNED NOT NULL,
    capacity     INT UNSIGNED DEFAULT NULL,
    CONSTRAINT fk_venue_location
        FOREIGN KEY (location_id) REFERENCES venue_locations(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_venue_name_location
        UNIQUE (venue_name, location_id)
);

-- -------------------------------------------------------------
-- [D] EVENT_SCHEDULE  ← NEW, split from 3NF events
--
--  Problem in 3NF events:
--    events(id, event_name, description, event_date, event_time,
--           venue_id, total_tickets, created_at)
--
--  Hidden FD: (venue_id, event_date, event_time) → event_id
--  A venue cannot host two events at the same date+time.
--  That composite is a CANDIDATE KEY — but event.id is the PK.
--  Having two independent CKs in one table is fine in 3NF, but
--  if any non-key attribute depends on ONLY one of the CKs and
--  not the other, we have a BCNF violation.
--
--  Specifically: event_date, event_time, venue_id are scheduling
--  data that determine each other's context independently of the
--  event's descriptive data (name, description, total_tickets).
--
--  Fix: extract scheduling into event_schedule, giving the
--  composite (event_id, venue_id, event_date, event_time) its
--  own table so the uniqueness constraint is explicit and the
--  event table's non-key columns depend solely on event.id.
--
--  event_schedule CKs: {id}, {event_id, venue_id, event_date, event_time}
--  BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_schedule (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL UNIQUE,   -- 1 schedule row per event
    venue_id    INT UNSIGNED NOT NULL,
    event_date  DATE         NOT NULL,
    event_time  TIME         NOT NULL,
    CONSTRAINT fk_sched_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_sched_venue
        FOREIGN KEY (venue_id) REFERENCES venues(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Venue cannot host two events at the same slot
    CONSTRAINT uq_venue_slot
        UNIQUE (venue_id, event_date, event_time)
);

-- -------------------------------------------------------------
-- 4. EVENTS  (descriptive data only after [D] extraction)
--    CKs: {id},  {event_name, event_date} [natural composite—optional]
--    FDs: id → event_name, description, total_tickets, created_at
--    Only id is the determinant for every non-key col → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name     VARCHAR(255) NOT NULL,
    description    TEXT         DEFAULT NULL,
    total_tickets  INT UNSIGNED NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- NOTE: event_schedule references events, so events must exist first.
-- The CREATE TABLE for event_schedule above references events(id).
-- MySQL evaluates FK at data-insert time, not at DDL time, so the
-- forward reference is safe. If your MySQL version is strict, swap
-- the order and use ALTER TABLE to add FK after events is created.

-- -------------------------------------------------------------
-- [B] TICKET_TYPES
--    CKs: {id},  {event_id, type_name}
--    FDs: id → *  |  (event_id, type_name) → id, price, quantity
--    Both determinants are CKs.
--    In 3NF the composite CK existed logically but was not
--    declared — UNIQUE constraint now makes it explicit → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS ticket_types (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL,
    type_name   VARCHAR(100) NOT NULL,
    price       DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    quantity    INT UNSIGNED  NOT NULL,
    CONSTRAINT fk_ttype_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    -- Enforce the natural composite CK explicitly
    CONSTRAINT uq_ttype_event_name
        UNIQUE (event_id, type_name)
);

-- -------------------------------------------------------------
-- 5. BOOKING_STATUSES  ← NEW
--
--  Problem in 3NF bookings:
--    bookings.status  ENUM('confirmed','cancelled','pending')
--
--  FD: status_label → meaning/description
--  The ENUM embeds values that could carry metadata. Even though
--  the current schema has no description column, BCNF requires
--  that every determinant be a superkey. An ENUM is semantically
--  a hidden lookup table where the label determines the concept.
--  Reifying it guarantees BCNF compliance and makes the status
--  set extensible without an ALTER TABLE.
--
--  CKs: {id}, {status_label} → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_statuses (
    id           TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_label VARCHAR(20) NOT NULL UNIQUE,   -- 'confirmed', 'cancelled', …
    description  VARCHAR(255) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 6. BOOKINGS  (status ENUM → status_id FK)
--    CKs: {id}
--    FDs: id → customer_id, event_id, booking_date, status_id
--    Only id determines non-key cols → BCNF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id     INT UNSIGNED    NOT NULL,
    event_id        INT UNSIGNED    NOT NULL,
    booking_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id       TINYINT UNSIGNED NOT NULL,
    CONSTRAINT fk_booking_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_booking_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_booking_status
        FOREIGN KEY (status_id) REFERENCES booking_statuses(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- [C] BOOKING_ITEMS
--    CKs: {id},  {booking_id, ticket_type_id}
--    FDs: id → *  |  (booking_id, ticket_type_id) → quantity, unit_price
--
--  In 3NF the composite CK was logically present but not enforced.
--  Declaring UNIQUE (booking_id, ticket_type_id) makes both CKs
--  explicit. Every determinant is now a CK → BCNF ✓
--
--  unit_price is a historical snapshot (price at booking time)
--  — justified denormalization for financial auditability.
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_items (
    id              INT UNSIGNED  AUTO_INCREMENT PRIMARY KEY,
    booking_id      INT UNSIGNED  NOT NULL,
    ticket_type_id  INT UNSIGNED  NOT NULL,
    quantity        INT UNSIGNED  NOT NULL CHECK (quantity >= 1),
    unit_price      DECIMAL(10,2) NOT NULL,
    CONSTRAINT fk_bitem_booking
        FOREIGN KEY (booking_id) REFERENCES bookings(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_bitem_ttype
        FOREIGN KEY (ticket_type_id) REFERENCES ticket_types(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    -- Expose the natural composite CK
    CONSTRAINT uq_bitem_booking_type
        UNIQUE (booking_id, ticket_type_id)
);

-- -------------------------------------------------------------
-- [E] TICKETS
--    CKs: {id},  {ticket_code}
--    FDs: id → *  |  ticket_code → *
--    Both determinants are CKs → BCNF ✓  (no change from 3NF)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS tickets (
    id              INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    booking_item_id INT UNSIGNED NOT NULL,
    ticket_code     VARCHAR(64)  NOT NULL UNIQUE,
    issued_at       TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_used         BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_ticket_bitem
        FOREIGN KEY (booking_item_id) REFERENCES booking_items(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- =============================================================
--  VIEWS
-- =============================================================

-- Full booking summary (replaces getMyBookings JOIN)
CREATE OR REPLACE VIEW vw_booking_summary AS
SELECT
    b.id                    AS booking_id,
    b.booking_date,
    bs.status_label         AS status,
    c.id                    AS customer_id,
    c.full_name             AS customer_name,
    c.email                 AS customer_email,
    e.id                    AS event_id,
    e.event_name,
    es.event_date,
    es.event_time,
    v.venue_name,
    vl.city,
    vl.country,
    tt.type_name            AS ticket_type,
    bi.quantity             AS tickets_booked,
    bi.unit_price,
    (bi.quantity * bi.unit_price) AS line_total
FROM bookings           b
JOIN booking_statuses   bs ON bs.id  = b.status_id
JOIN customers          c  ON c.id   = b.customer_id
JOIN events             e  ON e.id   = b.event_id
JOIN event_schedule     es ON es.event_id = e.id
JOIN venues             v  ON v.id   = es.venue_id
JOIN venue_locations    vl ON vl.id  = v.location_id
JOIN booking_items      bi ON bi.booking_id = b.id
JOIN ticket_types       tt ON tt.id  = bi.ticket_type_id;

-- Event availability (replaces getEvents/getEvent subquery)
CREATE OR REPLACE VIEW vw_event_availability AS
SELECT
    e.id                                                AS event_id,
    e.event_name,
    e.description,
    es.event_date,
    es.event_time,
    v.venue_name,
    vl.city,
    vl.country,
    e.total_tickets,
    COALESCE(SUM(bi.quantity), 0)                       AS tickets_sold,
    e.total_tickets - COALESCE(SUM(bi.quantity), 0)     AS tickets_remaining
FROM events             e
JOIN event_schedule     es  ON es.event_id = e.id
JOIN venues             v   ON v.id  = es.venue_id
JOIN venue_locations    vl  ON vl.id = v.location_id
LEFT JOIN bookings      b   ON b.event_id = e.id
LEFT JOIN booking_statuses bs ON bs.id = b.status_id AND bs.status_label = 'confirmed'
LEFT JOIN booking_items bi  ON bi.booking_id = b.id
GROUP BY e.id, e.event_name, e.description, es.event_date,
         es.event_time, v.venue_name, vl.city, vl.country, e.total_tickets;

-- =============================================================
--  TRIGGERS
-- =============================================================

DELIMITER //

-- Overbooking guard — fires on booking_items INSERT
CREATE TRIGGER trg_bcnf_before_bitem_insert
BEFORE INSERT ON booking_items
FOR EACH ROW
BEGIN
    DECLARE v_total_sold  INT UNSIGNED DEFAULT 0;
    DECLARE v_capacity    INT UNSIGNED DEFAULT 0;
    DECLARE v_event_id    INT UNSIGNED;
    DECLARE v_confirmed   TINYINT UNSIGNED;

    -- Get the confirmed status id
    SELECT id INTO v_confirmed FROM booking_statuses
    WHERE status_label = 'confirmed' LIMIT 1;

    -- Derive event from ticket_type
    SELECT event_id INTO v_event_id
    FROM ticket_types WHERE id = NEW.ticket_type_id;

    -- Sum already sold confirmed ticket quantities for this event
    SELECT COALESCE(SUM(bi.quantity), 0)
    INTO   v_total_sold
    FROM   booking_items bi
    JOIN   bookings      bk ON bk.id  = bi.booking_id
    JOIN   ticket_types  tt ON tt.id  = bi.ticket_type_id
    WHERE  tt.event_id  = v_event_id
      AND  bk.status_id = v_confirmed;

    -- Event total capacity
    SELECT total_tickets INTO v_capacity
    FROM   events WHERE id = v_event_id;

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
    ('customer', 'Can browse and book events');

-- Customers
INSERT INTO customers (full_name, email, password, role_id) VALUES
    ('Admin User', 'admin@example.com', 'hashedpassword1', 1),
    ('John Doe',   'john@example.com',  'hashedpassword2', 2);

-- Booking statuses
INSERT INTO booking_statuses (status_label, description) VALUES
    ('confirmed',  'Payment received; booking active'),
    ('cancelled',  'Booking has been cancelled'),
    ('pending',    'Awaiting payment confirmation');

-- Venue locations
INSERT INTO venue_locations (city, state, country, timezone) VALUES
    ('New York',     'NY', 'USA', 'America/New_York'),
    ('San Francisco','CA', 'USA', 'America/Los_Angeles');

-- Venues
INSERT INTO venues (venue_name, address, location_id, capacity) VALUES
    ('Central Park',      '59th to 110th St', 1, 5000),
    ('Convention Center', '1 Convention Pl',  2,  500);

-- Events (descriptive data only)
INSERT INTO events (event_name, description, total_tickets) VALUES
    ('Music Festival',  'A grand outdoor music festival.',               500),
    ('Tech Conference', 'Annual tech conference with keynote speakers.', 150);

-- Event schedules (venue + date + time, unique slot per venue)
INSERT INTO event_schedule (event_id, venue_id, event_date, event_time) VALUES
    (1, 1, '2024-12-15', '18:00:00'),
    (2, 2, '2024-11-20', '09:00:00');

-- Ticket types
INSERT INTO ticket_types (event_id, type_name, price, quantity) VALUES
    (1, 'General',  29.99, 400),
    (1, 'VIP',      89.99, 100),
    (2, 'General',  49.99, 100),
    (2, 'VIP',     149.99,  50);

-- Bookings (status_id 1 = confirmed)
INSERT INTO bookings (customer_id, event_id, status_id) VALUES (2, 1, 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (1, 1, 2, 29.99);

INSERT INTO bookings (customer_id, event_id, status_id) VALUES (2, 2, 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (2, 3, 1, 49.99);
