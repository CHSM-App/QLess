// /doctor/insert — one router assembled from the feature files below, so every
// URL stays exactly what the app already calls.
const express = require('express');
const appointments = require('./appointments');

require('./reminders'); // registers the cron jobs

const router = express.Router();
const ownStaff = require('../../../middleware/ownStaff');
// Offline-started sessions carry queue_id = -slot_id; swap in the real one
// first, or ownStaff refuses an id no doctor owns.
router.use(require('./shared').resolveTempQueue);
ownStaff(router); // staff: only their own doctor's records
router.use(require('./notifications'));
router.use(require('./prescriptions'));
router.use(require('./schedule'));
router.use(require('./leave'));
router.use(appointments);

module.exports = router;
module.exports.closeStaleSessions = appointments.closeStaleSessions;
