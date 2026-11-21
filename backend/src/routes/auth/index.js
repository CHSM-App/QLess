// /login router, split by area (was one 1,340-line routes/auth.js).
// Mounted in this order, which is the order the routes had in that file.
const express = require('express');
const router = express.Router();

router.use(require('./session'));
router.use(require('./lookups'));
router.use(require('./signup'));
router.use(require('./otp'));
router.use(require('./pages'));
router.use(require('./clinics'));
router.use(require('./receptionist'));

module.exports = router;
