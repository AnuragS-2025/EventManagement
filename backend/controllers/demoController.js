const db = require('../config/db');

exports.seedDemoData = async (req, res) => {
    try {
        // 1. Clear existing events and bookings for a clean demo (Optional, but safer for "Populate Demo")
        // We'll just add new ones to be less destructive
        
        const demoEvents = [
            ['Global Tech Summit 2024', 'A world-class gathering of tech leaders and innovators.', '2024-11-20', '09:00:00', 'Silicon Valley Center', 500, 1500.00, 'Tech', 'https://images.unsplash.com/photo-1540575861501-7ad0582373f3?auto=format&fit=crop&w=800'],
            ['Midnight Jazz Festival', 'An enchanting evening of live jazz under the stars.', '2024-10-15', '20:00:00', 'Central Park Amphitheater', 200, 250.00, 'Music', 'https://images.unsplash.com/photo-1514525253361-bee8d4872af9?auto=format&fit=crop&w=800'],
            ['Digital Art Expo', 'Exploring the intersection of art and blockchain technology.', '2024-12-05', '11:00:00', 'Modern Art Gallery', 150, 45.00, 'Workshop', 'https://images.unsplash.com/photo-1550684848-fac1c5b4e853?auto=format&fit=crop&w=800'],
            ['Startup Pitch Day', 'Watch the next generation of giants pitch to top-tier VCs.', '2024-09-28', '14:00:00', 'Innovation Hub', 100, 0.00, 'Conference', 'https://images.unsplash.com/photo-1475721027785-f74eccf877e2?auto=format&fit=crop&w=800'],
            ['Chef Masters Workshop', 'Learn culinary secrets from 3-star Michelin chefs.', '2024-11-10', '10:00:00', 'Culinary Institute', 30, 850.00, 'Food', 'https://images.unsplash.com/photo-1556910103-1c02745aae4d?auto=format&fit=crop&w=800']
        ];

        for (const event of demoEvents) {
            const [result] = await db.query(
                'INSERT INTO events (name, description, date, time, venue, total_tickets, ticket_price, category, image_url) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)',
                event
            );
            
            const eventId = result.insertId;
            
            // Generate some random bookings for each event
            const numBookings = Math.floor(Math.random() * 8) + 3; // 3 to 10 bookings
            for (let i = 0; i < numBookings; i++) {
                const qty = Math.floor(Math.random() * 3) + 1;
                const amount = qty * event[6];
                const status = Math.random() > 0.3 ? 'paid' : 'pending';
                
                // Use the first user (usually the admin or the one who registered first)
                // In a real seeder we'd create users, but here we'll just use ID 1
                const [bookingResult] = await db.query(
                    'INSERT INTO bookings (user_id, event_id, tickets_booked, status) VALUES (1, ?, ?, ?)',
                    [eventId, qty, status]
                );
                
                if (status === 'paid') {
                    await db.query(
                        'INSERT INTO payments (booking_id, amount, status) VALUES (?, ?, "completed")',
                        [bookingResult.insertId, amount]
                    );
                }
            }
        }

        res.json({ message: 'Demo data seeded successfully!' });
    } catch (error) {
        res.status(500).json({ error: error.message });
    }
};
