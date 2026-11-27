// /login — Static pages linked from the app and the stores.
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	path,
} = require('./shared');

router.get('/privacy', (req, res) => {
	res.sendFile(path.join(__dirname, '..', '..', 'static', 'privacy.html'));
});


router.get('/terms', (req, res) => {
	res.sendFile(path.join(__dirname, '..', '..', 'static', 'terms.html'));
});


router.get('/delete-account', (req, res) => {
	res.sendFile(path.join(__dirname, '..', '..', 'static', 'delete-account.html'));
});

module.exports = router;
