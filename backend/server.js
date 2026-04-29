const express = require('express');
const cors = require('cors');
const dotenv = require('dotenv');
const path = require('path');

// Configure dotenv with path resolution
const result = dotenv.config({ path: path.resolve(__dirname, '.env') });

if (result.error) {
    console.warn('Warning: Could not load .env file. Check if it exists in the backend/ folder.');
}

const authRoutes = require('./routes/authRoutes');
const eventRoutes = require('./routes/eventRoutes');
const bookingRoutes = require('./routes/bookingRoutes');
const demoController = require('./controllers/demoController');

const app = express();

// Middleware
app.use(cors());
app.use(express.json());

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/events', eventRoutes);
app.use('/api/bookings', bookingRoutes);
app.use('/api/demo', demoController.seedDemoData);

// Base route
app.get('/', (req, res) => {
    res.send('Event and Ticket Management API is running...');
});

const PORT = process.env.PORT || 5000;
app.listen(PORT, () => {
    console.log(`Server running on port ${PORT}`);
});
