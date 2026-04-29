-- =============================================================
--   Event & Ticket Management System — 5NF (PJNF) Schema
--   Upgraded from: schema_bcnf.sql (via 4NF)
-- =============================================================
--
--  5NF RULE (Project-Join Normal Form):
--  A relation R is in 5NF if every join dependency (JD) in R
--  is implied by R's candidate keys. In practice this means
--  decomposing any n-ary relationship that can be losslessly
--  reconstructed from smaller binary projections, so that no
--  redundant join paths remain.
--
--  KEY CHANGES OVER BCNF / 4NF:
--
--    [A] event_customers  — NEW binary projection
--        Extracts the customer↔event relationship out of
--        bookings.event_id, which was a redundant join path
--        (also derivable via booking_items → ticket_types).
--
--    [B] event_seats — NEW binary projection
--        Explicitly maps which seats are available per event,
--        replacing the implicit chain venue → seats ∩ event_schedule.
--
--    [C] customer_seat_assignments — NEW ternary constraint
--        Irreducible ternary (customer ↔ seat ↔ event). Replaces
--        the implicit chain bookings → tickets → seat_allocations.
--        Cannot be further decomposed without information loss.
--
--    [D] bookings.event_id REMOVED — the event for a booking is
--        always derivable via booking_items → ticket_types → events.
--        Keeping it created a JD not implied by any candidate key.
--
--    [E] event_artists & event_sponsors — carried from 4NF.
--        Binary projections that eliminated MVDs.
--
-- =============================================================

CREATE DATABASE IF NOT EXISTS event_management;
USE event_management;


-- =============================================================
--  SECTION 1: CORE ENTITY TABLES
--  These tables store independent entities. Each has a surrogate
--  PK and at least one natural candidate key (UNIQUE).
--  All FDs are implied by candidate keys → 5NF ✓
-- =============================================================

-- -------------------------------------------------------------
-- 1. ROLES
--    CKs: {id}, {role_name}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS roles (
    id          TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    role_name   VARCHAR(50)  NOT NULL UNIQUE,
    description VARCHAR(255) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 2. CUSTOMERS
--    CKs: {id}, {email}
--    No join dependencies. 5NF ✓
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
-- 3. VENUE_LOCATIONS
--    CKs: {id}, {city, state, country}
--    No join dependencies. 5NF ✓
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
-- 4. VENUES
--    CKs: {id}, {venue_name, location_id}
--    No join dependencies. 5NF ✓
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
-- 5. SEATS  (physical layout of a venue)
--    CKs: {id}, {venue_id, section, seat_row, seat_number}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS seats (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    venue_id    INT UNSIGNED NOT NULL,
    section     VARCHAR(50)  NOT NULL,
    seat_row    VARCHAR(10)  NOT NULL,
    seat_number VARCHAR(10)  NOT NULL,
    CONSTRAINT uq_venue_seat
        UNIQUE (venue_id, section, seat_row, seat_number),
    CONSTRAINT fk_seat_venue
        FOREIGN KEY (venue_id) REFERENCES venues(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- 6. EVENTS  (descriptive data only — scheduling is separate)
--    CKs: {id}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS events (
    id             INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_name     VARCHAR(255) NOT NULL,
    description    TEXT         DEFAULT NULL,
    total_tickets  INT UNSIGNED NOT NULL,
    created_at     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- -------------------------------------------------------------
-- 7. ARTISTS
--    CKs: {id}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS artists (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    artist_name VARCHAR(255) NOT NULL,
    genre       VARCHAR(100) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 8. SPONSORS
--    CKs: {id}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS sponsors (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    sponsor_name VARCHAR(255) NOT NULL,
    industry     VARCHAR(100) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 9. BOOKING_STATUSES
--    CKs: {id}, {status_label}
--    No join dependencies. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS booking_statuses (
    id           TINYINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    status_label VARCHAR(20)  NOT NULL UNIQUE,
    description  VARCHAR(255) DEFAULT NULL
);

-- -------------------------------------------------------------
-- 10. TICKET_TYPES
--     CKs: {id}, {event_id, type_name}
--     No join dependencies. 5NF ✓
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
    CONSTRAINT uq_ttype_event_name
        UNIQUE (event_id, type_name)
);


-- =============================================================
--  SECTION 2: BINARY RELATIONSHIP TABLES  (5NF Projections)
--
--  These tables represent the lossless binary decompositions
--  of multi-way relationships. Each captures exactly ONE
--  independent fact. The original multi-way facts are
--  recoverable via natural joins of these projections.
-- =============================================================

-- -------------------------------------------------------------
-- 11. EVENT_SCHEDULE  (binary: event ↔ venue + timeslot)
--     CKs: {event_id}, {venue_id, event_date, event_time}
--     Constraint: a venue cannot host two events simultaneously.
--     No further decomposable JD. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_schedule (
    id          INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    event_id    INT UNSIGNED NOT NULL UNIQUE,
    venue_id    INT UNSIGNED NOT NULL,
    event_date  DATE         NOT NULL,
    event_time  TIME         NOT NULL,
    CONSTRAINT fk_sched_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_sched_venue
        FOREIGN KEY (venue_id) REFERENCES venues(id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT uq_venue_slot
        UNIQUE (venue_id, event_date, event_time)
);

-- -------------------------------------------------------------
-- [E-1] 12. EVENT_ARTISTS  (binary: event ↔ artist)
--       Carried from 4NF. Eliminates MVD Event ->> Artist.
--       PK is the full composite — pure binary relation. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_artists (
    event_id  INT UNSIGNED NOT NULL,
    artist_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, artist_id),
    CONSTRAINT fk_ea_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ea_artist
        FOREIGN KEY (artist_id) REFERENCES artists(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- [E-2] 13. EVENT_SPONSORS  (binary: event ↔ sponsor)
--       Carried from 4NF. Eliminates MVD Event ->> Sponsor.
--       PK is the full composite — pure binary relation. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_sponsors (
    event_id   INT UNSIGNED NOT NULL,
    sponsor_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, sponsor_id),
    CONSTRAINT fk_es_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_es_sponsor
        FOREIGN KEY (sponsor_id) REFERENCES sponsors(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- [A] 14. EVENT_CUSTOMERS  (binary: event ↔ customer)
--
--  ★ 5NF DECOMPOSITION ★
--
--  Problem in BCNF:
--    bookings(id, customer_id, event_id, booking_date, status_id)
--
--    The customer↔event relationship lived inside bookings, but
--    it was ALSO derivable through:
--      booking_items.ticket_type_id → ticket_types.event_id
--
--    This dual derivation path constitutes a join dependency:
--      JD(*{ id, customer_id, booking_date, status_id },
--          { customer_id, event_id })
--    where the second projection is reconstructable from
--    booking_items ⋈ ticket_types. The JD is NOT implied by
--    the candidate key {id}, violating 5NF.
--
--  Fix: Extract the binary fact "customer C attends event E"
--  into its own projection. Bookings no longer store event_id.
--
--  CK: {event_id, customer_id} → 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_customers (
    event_id    INT UNSIGNED NOT NULL,
    customer_id INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, customer_id),
    CONSTRAINT fk_ec_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_ec_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- [B] 15. EVENT_SEATS  (binary: event ↔ seat)
--
--  ★ 5NF DECOMPOSITION ★
--
--  Problem in BCNF:
--    Seat availability per event was IMPLICIT — inferred by
--    joining event_schedule (event→venue) with seats (venue→seats).
--    Any query asking "which seats are open for event E?" required
--    traversing: event_schedule → venues → seats, a three-table
--    join path that is itself a join dependency:
--      JD(*{ event_id, venue_id }, { venue_id, seat_id })
--
--  Fix: Store the binary fact "seat S is available at event E"
--  directly. This projection is lossless when combined with
--  event_schedule (for venue context) and seats (for layout).
--
--  CK: {event_id, seat_id} → 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS event_seats (
    event_id INT UNSIGNED NOT NULL,
    seat_id  INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, seat_id),
    CONSTRAINT fk_evs_event
        FOREIGN KEY (event_id) REFERENCES events(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_evs_seat
        FOREIGN KEY (seat_id) REFERENCES seats(id)
        ON UPDATE CASCADE ON DELETE CASCADE
);

-- -------------------------------------------------------------
-- [C] 16. CUSTOMER_SEAT_ASSIGNMENTS  (ternary: customer ↔ seat ↔ event)
--
--  ★ 5NF IRREDUCIBLE TERNARY ★
--
--  This is the minimum irreducible relation. It CANNOT be
--  decomposed into binary (customer,seat) + (customer,event)
--  without information loss because:
--    - A customer can attend multiple events at the same venue
--    - The same seat is reused across events
--    - Knowing (C attends E) and (C has seat S) and (S is at E)
--      does NOT uniquely determine that C has seat S at event E
--      when C attends multiple events with overlapping seat sets.
--
--  However, combined with the binary projections event_customers
--  and event_seats, ALL assignment facts are recoverable:
--    customer_seat_assignments
--      ⊆ event_customers ⋈ event_seats (on event_id)
--
--  FK constraints enforce referential integrity against both
--  binary projections, guaranteeing the assignment is valid.
--
--  PK: (event_id, seat_id) — one customer per seat per event.
--  5NF ✓  (no further decomposable JD)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS customer_seat_assignments (
    event_id    INT UNSIGNED NOT NULL,
    customer_id INT UNSIGNED NOT NULL,
    seat_id     INT UNSIGNED NOT NULL,
    PRIMARY KEY (event_id, seat_id),
    CONSTRAINT fk_csa_event_customer
        FOREIGN KEY (event_id, customer_id)
        REFERENCES event_customers(event_id, customer_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_csa_event_seat
        FOREIGN KEY (event_id, seat_id)
        REFERENCES event_seats(event_id, seat_id)
        ON UPDATE CASCADE ON DELETE CASCADE
);


-- =============================================================
--  SECTION 3: TRANSACTION TABLES
--  These tables record transactional/temporal business facts.
--  They reference entities and binary projections via FKs.
-- =============================================================

-- -------------------------------------------------------------
-- [D] 17. BOOKINGS  (transaction header — event_id REMOVED)
--
--  ★ 5NF FIX ★
--
--  In BCNF, bookings stored event_id redundantly alongside the
--  derivable path booking_items → ticket_types → events.
--  This redundancy is now eliminated. The event for any booking
--  is always obtained via:
--    SELECT DISTINCT tt.event_id
--    FROM booking_items bi
--    JOIN ticket_types tt ON tt.id = bi.ticket_type_id
--    WHERE bi.booking_id = <booking_id>;
--
--  The canonical customer↔event fact lives in event_customers.
--
--  CK: {id}. All non-key cols depend only on {id}. 5NF ✓
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS bookings (
    id           INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    customer_id  INT UNSIGNED    NOT NULL,
    booking_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    status_id    TINYINT UNSIGNED NOT NULL,
    CONSTRAINT fk_booking_customer
        FOREIGN KEY (customer_id) REFERENCES customers(id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT fk_booking_status
        FOREIGN KEY (status_id) REFERENCES booking_statuses(id)
        ON UPDATE CASCADE ON DELETE RESTRICT
);

-- -------------------------------------------------------------
-- 18. BOOKING_ITEMS  (line items per booking)
--     CKs: {id}, {booking_id, ticket_type_id}
--     unit_price = historical snapshot (justified denormalization).
--     No decomposable JD. 5NF ✓
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
    CONSTRAINT uq_bitem_booking_type
        UNIQUE (booking_id, ticket_type_id)
);

-- -------------------------------------------------------------
-- 19. TICKETS  (individual issued tickets)
--     CKs: {id}, {ticket_code}
--     No decomposable JD. 5NF ✓
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
--  SECTION 4: VIEWS  (convenience layer for application queries)
--
--  Views reconstruct the denormalized facts that the 5NF
--  decomposition spread across multiple tables. Application
--  code queries views instead of hand-writing complex JOINs.
-- =============================================================

-- -----------------------------------------------------------------
-- vw_booking_summary
-- Replaces getMyBookings JOIN — reconstructs the full booking
-- context including event (derived through ticket_types, not
-- bookings.event_id which no longer exists).
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_booking_summary AS
SELECT
    b.id                              AS booking_id,
    b.booking_date,
    bs.status_label                   AS status,
    c.id                              AS customer_id,
    c.full_name                       AS customer_name,
    c.email                           AS customer_email,
    e.id                              AS event_id,
    e.event_name,
    es.event_date,
    es.event_time,
    v.venue_name,
    vl.city,
    vl.country,
    tt.type_name                      AS ticket_type,
    bi.quantity                       AS tickets_booked,
    bi.unit_price,
    (bi.quantity * bi.unit_price)     AS line_total
FROM bookings           b
JOIN booking_statuses   bs ON bs.id  = b.status_id
JOIN customers          c  ON c.id   = b.customer_id
JOIN booking_items      bi ON bi.booking_id = b.id
JOIN ticket_types       tt ON tt.id  = bi.ticket_type_id
-- ↓ Event derived via ticket_types (5NF: no event_id in bookings)
JOIN events             e  ON e.id   = tt.event_id
JOIN event_schedule     es ON es.event_id = e.id
JOIN venues             v  ON v.id   = es.venue_id
JOIN venue_locations    vl ON vl.id  = v.location_id;

-- -----------------------------------------------------------------
-- vw_event_availability
-- Replaces getEvents/getEvent subquery — calculates remaining
-- tickets per event. Joins through ticket_types → booking_items
-- to reach confirmed bookings.
-- -----------------------------------------------------------------
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
    COALESCE(sold.tickets_sold, 0)                      AS tickets_sold,
    e.total_tickets - COALESCE(sold.tickets_sold, 0)    AS tickets_remaining
FROM events             e
JOIN event_schedule     es  ON es.event_id = e.id
JOIN venues             v   ON v.id  = es.venue_id
JOIN venue_locations    vl  ON vl.id = v.location_id
LEFT JOIN (
    -- Subquery: total confirmed tickets sold per event
    SELECT
        tt.event_id,
        SUM(bi.quantity) AS tickets_sold
    FROM booking_items   bi
    JOIN ticket_types    tt ON tt.id  = bi.ticket_type_id
    JOIN bookings        b  ON b.id   = bi.booking_id
    JOIN booking_statuses bs ON bs.id = b.status_id
    WHERE bs.status_label = 'confirmed'
    GROUP BY tt.event_id
) sold ON sold.event_id = e.id;

-- -----------------------------------------------------------------
-- vw_event_artists_list
-- Convenience view: artists performing at each event.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_event_artists_list AS
SELECT
    e.id            AS event_id,
    e.event_name,
    a.id            AS artist_id,
    a.artist_name,
    a.genre
FROM events        e
JOIN event_artists ea ON ea.event_id = e.id
JOIN artists       a  ON a.id = ea.artist_id;

-- -----------------------------------------------------------------
-- vw_event_sponsors_list
-- Convenience view: sponsors backing each event.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_event_sponsors_list AS
SELECT
    e.id             AS event_id,
    e.event_name,
    s.id             AS sponsor_id,
    s.sponsor_name,
    s.industry
FROM events         e
JOIN event_sponsors es ON es.event_id = e.id
JOIN sponsors       s  ON s.id = es.sponsor_id;

-- -----------------------------------------------------------------
-- vw_seat_availability
-- Which seats are still open for a given event.
-- -----------------------------------------------------------------
CREATE OR REPLACE VIEW vw_seat_availability AS
SELECT
    evs.event_id,
    e.event_name,
    s.id            AS seat_id,
    s.section,
    s.seat_row,
    s.seat_number,
    CASE
        WHEN csa.customer_id IS NOT NULL THEN 'assigned'
        ELSE 'available'
    END             AS seat_status,
    csa.customer_id AS assigned_to_customer_id
FROM event_seats                evs
JOIN events                     e   ON e.id  = evs.event_id
JOIN seats                      s   ON s.id  = evs.seat_id
LEFT JOIN customer_seat_assignments csa
    ON  csa.event_id = evs.event_id
    AND csa.seat_id  = evs.seat_id;


-- =============================================================
--  SECTION 5: TRIGGERS
-- =============================================================

DELIMITER //

-- -----------------------------------------------------------------
-- Overbooking guard — fires before a booking_item is inserted.
-- Derives the event from ticket_types (since bookings no longer
-- stores event_id) and checks total confirmed quantity against
-- event capacity.
-- -----------------------------------------------------------------
CREATE TRIGGER trg_5nf_before_bitem_insert
BEFORE INSERT ON booking_items
FOR EACH ROW
BEGIN
    DECLARE v_total_sold  INT UNSIGNED DEFAULT 0;
    DECLARE v_capacity    INT UNSIGNED DEFAULT 0;
    DECLARE v_event_id    INT UNSIGNED;
    DECLARE v_confirmed   TINYINT UNSIGNED;

    -- Get the 'confirmed' status id
    SELECT id INTO v_confirmed
    FROM booking_statuses
    WHERE status_label = 'confirmed' LIMIT 1;

    -- Derive event from ticket_type
    SELECT event_id INTO v_event_id
    FROM ticket_types WHERE id = NEW.ticket_type_id;

    -- Sum already-sold confirmed quantities for this event
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

-- -----------------------------------------------------------------
-- Seat double-booking guard — fires before a customer_seat_assignment
-- is inserted. Ensures the seat is not already assigned for this event.
-- (The PK already enforces uniqueness of (event_id, seat_id), so this
-- trigger provides a user-friendly error message.)
-- -----------------------------------------------------------------
CREATE TRIGGER trg_5nf_before_seat_assign
BEFORE INSERT ON customer_seat_assignments
FOR EACH ROW
BEGIN
    DECLARE v_existing INT DEFAULT 0;

    SELECT COUNT(*) INTO v_existing
    FROM customer_seat_assignments
    WHERE event_id = NEW.event_id
      AND seat_id  = NEW.seat_id;

    IF v_existing > 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Seat assignment failed: Seat is already assigned for this event.';
    END IF;
END //

DELIMITER ;


-- =============================================================
--  SECTION 6: SAMPLE DATA
-- =============================================================

-- Roles
INSERT INTO roles (role_name, description) VALUES
    ('admin',    'Full system access'),
    ('customer', 'Can browse and book events');

-- Customers (role_id 1 = admin, 2 = customer)
INSERT INTO customers (full_name, email, password, role_id) VALUES
    ('Admin User',  'admin@example.com',  'hashedpassword1', 1),
    ('John Doe',    'john@example.com',   'hashedpassword2', 2),
    ('Jane Smith',  'jane@example.com',   'hashedpassword3', 2);

-- Booking statuses
INSERT INTO booking_statuses (status_label, description) VALUES
    ('confirmed',  'Payment received; booking active'),
    ('cancelled',  'Booking has been cancelled'),
    ('pending',    'Awaiting payment confirmation');

-- Venue locations
INSERT INTO venue_locations (city, state, country, timezone) VALUES
    ('New York',      'NY', 'USA', 'America/New_York'),
    ('San Francisco', 'CA', 'USA', 'America/Los_Angeles');

-- Venues
INSERT INTO venues (venue_name, address, location_id, capacity) VALUES
    ('Central Park',      '59th to 110th St', 1, 5000),
    ('Convention Center', '1 Convention Pl',  2,  500);

-- Seats (sample seats for Convention Center, venue_id = 2)
INSERT INTO seats (venue_id, section, seat_row, seat_number) VALUES
    (2, 'A', '1', '1'), (2, 'A', '1', '2'), (2, 'A', '1', '3'),
    (2, 'A', '1', '4'), (2, 'A', '1', '5'),
    (2, 'B', '1', '1'), (2, 'B', '1', '2'), (2, 'B', '1', '3'),
    (2, 'B', '1', '4'), (2, 'B', '1', '5');

-- Events (descriptive data only)
INSERT INTO events (event_name, description, total_tickets) VALUES
    ('Music Festival',  'A grand outdoor music festival.',               500),
    ('Tech Conference', 'Annual tech conference with keynote speakers.', 150);

-- Event schedules
INSERT INTO event_schedule (event_id, venue_id, event_date, event_time) VALUES
    (1, 1, '2024-12-15', '18:00:00'),
    (2, 2, '2024-11-20', '09:00:00');

-- Artists
INSERT INTO artists (artist_name, genre) VALUES
    ('The Lumineers',   'Indie Folk'),
    ('Daft Punk',       'Electronic'),
    ('Adele',           'Pop');

-- Sponsors
INSERT INTO sponsors (sponsor_name, industry) VALUES
    ('TechCorp',    'Technology'),
    ('SoundWave',   'Audio Equipment'),
    ('EventBrite',  'Event Management');

-- Event ↔ Artist (binary projection)
INSERT INTO event_artists (event_id, artist_id) VALUES
    (1, 1), (1, 2), (1, 3),   -- Music Festival: 3 artists
    (2, 2);                     -- Tech Conference: 1 artist (DJ set)

-- Event ↔ Sponsor (binary projection)
INSERT INTO event_sponsors (event_id, sponsor_id) VALUES
    (1, 2), (1, 3),            -- Music Festival: 2 sponsors
    (2, 1), (2, 3);            -- Tech Conference: 2 sponsors

-- Event ↔ Customer (binary projection — who is attending)
INSERT INTO event_customers (event_id, customer_id) VALUES
    (1, 2),  -- John Doe → Music Festival
    (2, 2),  -- John Doe → Tech Conference
    (2, 3);  -- Jane Smith → Tech Conference

-- Event ↔ Seat (binary projection — seats open for Tech Conference)
INSERT INTO event_seats (event_id, seat_id) VALUES
    (2, 1), (2, 2), (2, 3), (2, 4), (2, 5),
    (2, 6), (2, 7), (2, 8), (2, 9), (2, 10);

-- Customer ↔ Seat ↔ Event (irreducible ternary assignment)
INSERT INTO customer_seat_assignments (event_id, customer_id, seat_id) VALUES
    (2, 2, 3),   -- John Doe  → Tech Conference, Section A, Row 1, Seat 3
    (2, 3, 7);   -- Jane Smith → Tech Conference, Section B, Row 1, Seat 2

-- Ticket types
INSERT INTO ticket_types (event_id, type_name, price, quantity) VALUES
    (1, 'General',  29.99, 400),
    (1, 'VIP',      89.99, 100),
    (2, 'General',  49.99, 100),
    (2, 'VIP',     149.99,  50);

-- Bookings (status_id 1 = confirmed)
-- John Doe books 2 General tickets for Music Festival
INSERT INTO bookings (customer_id, booking_date, status_id) VALUES (2, NOW(), 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (1, 1, 2, 29.99);

-- John Doe books 1 General ticket for Tech Conference
INSERT INTO bookings (customer_id, booking_date, status_id) VALUES (2, NOW(), 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (2, 3, 1, 49.99);

-- Jane Smith books 1 VIP ticket for Tech Conference
INSERT INTO bookings (customer_id, booking_date, status_id) VALUES (3, NOW(), 1);
INSERT INTO booking_items (booking_id, ticket_type_id, quantity, unit_price)
    VALUES (3, 4, 1, 149.99);
