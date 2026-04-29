const express = require('express');
const router = express.Router();
const bookingController = require('../controllers/bookingController');
const { verifyToken, verifyAdmin } = require('../middleware/auth');

// Protected routes (Customer or Admin can book)
router.post('/', verifyToken, bookingController.bookTickets);
router.get('/my-bookings', verifyToken, bookingController.getMyBookings);
router.get('/all', verifyAdmin, bookingController.getAllBookings);
router.put('/:id/mark-paid', verifyAdmin, bookingController.markAsPaid);
router.delete('/:id', verifyToken, bookingController.cancelBooking);

module.exports = router;
