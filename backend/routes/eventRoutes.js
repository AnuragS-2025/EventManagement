const express = require('express');
const router = express.Router();
const eventController = require('../controllers/eventController');
const { verifyAdmin } = require('../middleware/auth');

router.get('/', eventController.getEvents);
router.get('/:id', eventController.getEvent);

// Admin only routes
router.post('/', verifyAdmin, eventController.createEvent);
router.put('/:id', verifyAdmin, eventController.updateEvent);
router.delete('/:id', verifyAdmin, eventController.deleteEvent);

module.exports = router;
