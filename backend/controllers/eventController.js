const db = require('../config/db');

// Get all events
exports.getEvents = async (req, res) => {
    try {
        const [events] = await db.query(`
            SELECT e.*, 
            COALESCE((SELECT SUM(tickets_booked) FROM bookings WHERE event_id = e.id), 0) as tickets_sold 
            FROM events e 
            ORDER BY date ASC
        `);
        res.json(events);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Get single event
exports.getEvent = async (req, res) => {
    try {
        const [event] = await db.query(`
            SELECT e.*, 
            COALESCE((SELECT SUM(tickets_booked) FROM bookings WHERE event_id = e.id), 0) as tickets_sold 
            FROM events e 
            WHERE id = ?
        `, [req.params.id]);
        
        if (event.length === 0) return res.status(404).json({ message: 'Event not found' });
        res.json(event[0]);
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Create event (Admin)
exports.createEvent = async (req, res) => {
    try {
        const { name, description, date, time, venue, total_tickets, ticket_price, category, image_url } = req.body;
        await db.query(
            'INSERT INTO events (name, description, date, time, venue, total_tickets, ticket_price, category, image_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
            [name, description, date, time, venue, total_tickets, ticket_price || 0, category || 'General', image_url]
        );
        res.status(201).json({ message: 'Event created successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Update event (Admin)
exports.updateEvent = async (req, res) => {
    try {
        const { name, description, date, time, venue, total_tickets, ticket_price, category, image_url } = req.body;
        await db.query(
            'UPDATE events SET name=?, description=?, date=?, time=?, venue=?, total_tickets=?, ticket_price=?, category=?, image_url=? WHERE id=?',
            [name, description, date, time, venue, total_tickets, ticket_price || 0, category || 'General', image_url, req.params.id]
        );
        res.json({ message: 'Event updated successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};

// Delete event (Admin)
exports.deleteEvent = async (req, res) => {
    try {
        await db.query('DELETE FROM events WHERE id = ?', [req.params.id]);
        res.json({ message: 'Event deleted successfully' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
