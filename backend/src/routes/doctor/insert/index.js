// /doctor/insert — one router assembled from the feature files below, so every
// URL stays exactly what the app already calls.
const express = require('express');
const appointments = require('./appointments');

require('./reminders'); // registers the cron jobs

const router = express.Router();
router.use(require('./notifications'));
router.use(require('./prescriptions'));
router.use(require('./schedule'));
router.use(require('./leave'));
router.use(appointments);

module.exports = router;
module.exports.closeStaleSessions = appointments.closeStaleSessions;
