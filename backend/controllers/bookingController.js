const db = require('../config/db');

// Initiate booking and create pending payment for Pay at Venue
exports.bookTickets = async (req, res) => {
    try {
        let { event_id, tickets_booked } = req.body;
        const user_id = req.user.id;

        event_id = Number(event_id);
        tickets_booked = Number(tickets_booked);

        if (!event_id || !tickets_booked || isNaN(event_id) || isNaN(tickets_booked) || tickets_booked <= 0) {
            return res.status(400).json({ message: 'Invalid input: Event ID and positive ticket quantity required.' });
        }

        const [eventRows] = await db.query('SELECT ticket_price FROM events WHERE id = ?', [event_id]);
        if (eventRows.length === 0) {
             return res.status(404).json({ message: 'Event not found.' });
        }

        const ticket_price = Number(parseFloat(eventRows[0].ticket_price) || 50);
        const amount = tickets_booked * ticket_price;

        if (isNaN(amount) || amount <= 0) {
             return res.status(400).json({ message: 'Invalid payment amount calculation (NaN or zero).' });
        }

        // Insert booking as pending
        const [bookingResult] = await db.query('INSERT INTO bookings (user_id, event_id, tickets_booked, status) VALUES (?, ?, ?, ?)',
            [user_id, event_id, tickets_booked, 'pending']);
            
        const booking_id = bookingResult.insertId || (Array.isArray(bookingResult) ? bookingResult[0].insertId : null);

        if (!booking_id) {
            throw new Error("Failed to retrieve booking ID after insertion.");
        }

        // Insert payment as pending
        await db.query('INSERT INTO payments (booking_id, amount, status) VALUES (?, ?, ?)',
            [booking_id, amount, 'pending']);
            
        res.status(201).json({ 
            message: 'Booking successful. Pay at Venue.', 
            booking_id, 
            amount
        });
    } catch (error) {
        if (error.code === 'ER_SIGNAL_EXCEPTION' || error.sqlState === '45000') {
            return res.status(400).json({ message: 'Booking failed: Not enough tickets available.' });
        }
        console.error('[Booking Error]', error);
        res.status(500).json({ error: error.message });
    }
};

// Mark booking as paid (Admin action)
exports.markAsPaid = async (req, res) => {
    try {
        const { id } = req.params;
        
        await db.query('UPDATE payments SET status = ?, payment_date = CURRENT_TIMESTAMP WHERE booking_id = ?', 
            ['completed', id]);
        
        await db.query('UPDATE bookings SET status = ? WHERE id = ?', ['paid', id]);
        
        res.json({ message: 'Booking marked as paid successfully!' });
    } catch (error) {
        console.error('[Payment Update Error]', error);
        res.status(500).json({ error: error.message });
    }
};

// Get my bookings
exports.getMyBookings = async (req, res) => {
    try {
        const user_id = req.user.id;
        const [bookings] = await db.query(`
            SELECT b.id, b.tickets_booked, b.booking_date, b.status, e.name as event_name, e.date, e.time, e.venue, e.image_url, e.category 
            FROM bookings b 
            JOIN events e ON b.event_id = e.id 

            WHERE b.user_id = ?
            ORDER BY b.booking_date DESC
        `, [user_id]);
        
        res.json(bookings);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Get all bookings for admin
exports.getAllBookings = async (req, res) => {
    try {
        const [bookings] = await db.query(`
            SELECT 
                b.id AS booking_id, 
                b.booking_date, 
                b.tickets_booked, 
                b.status AS booking_status,
                u.id AS customer_id, 
                u.name AS customer_name, 
                u.email AS customer_email, 
                p.amount,
                p.status AS payment_status,
                e.name AS event_name,
                e.image_url,
                e.category
            FROM bookings b
            JOIN users u ON b.user_id = u.id
            JOIN events e ON b.event_id = e.id
            LEFT JOIN payments p ON p.booking_id = b.id
            ORDER BY b.booking_date DESC
        `);
        
        res.json(bookings);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Cancel booking (Customer or Admin)
exports.cancelBooking = async (req, res) => {
    try {
        const { id } = req.params;
        const user_id = req.user.id;
        const user_role = req.user.role;

        // Check if booking exists and belongs to user (unless admin)
        const [rows] = await db.query('SELECT status, user_id FROM bookings WHERE id = ?', [id]);
        if (rows.length === 0) return res.status(404).json({ message: 'Booking not found.' });

        const booking = rows[0];
        if (user_role !== 'admin' && booking.user_id !== user_id) {
            return res.status(403).json({ message: 'Unauthorized to cancel this booking.' });
        }

        // Only pending bookings can be cancelled (for simplicity, or add admin override)
        if (user_role !== 'admin' && booking.status !== 'pending') {
            return res.status(400).json({ message: 'Only pending bookings can be cancelled.' });
        }

        await db.query('DELETE FROM bookings WHERE id = ?', [id]);
        res.json({ message: 'Booking cancelled successfully.' });
    } catch (error) {
        console.error('[Booking Cancel Error]', error);
        res.status(500).json({ error: error.message });
    }
};

