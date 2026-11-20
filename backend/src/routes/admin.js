const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
const path = require('path');
const crypto = require('crypto');
require('dotenv').config();

const auth = require('../middleware/auth');
const authorize = require('../middleware/authorize');
const { ROLE } = require('../middleware/roles');
const { authLimiter } = require('../middleware/rateLimit');
const db = require('../db');
const log = require('../middleware/logger');

// There is no admin table — a single shared staff credential (env vars)
// mints a token carrying ROLE.ADMIN. Good enough for one support team;
// revisit with a real admin table if more than one person needs their own
// login.
function constantTimeEqual(a, b) {
	const bufA = Buffer.from(String(a));
	const bufB = Buffer.from(String(b));
	if (bufA.length !== bufB.length) return false;
	return crypto.timingSafeEqual(bufA, bufB);
}

// Unauthenticated static page — it handles its own login form and only
// calls the protected routes below once it has a token.
router.get('/', (req, res) => {
	res.sendFile(path.join(__dirname, '..', 'static', 'admin-panel.html'));
});

router.post('/login', authLimiter, (req, res) => {
	const { username, password } = req.body || {};
	const envUser = process.env.ADMIN_USERNAME;
	const envPass = process.env.ADMIN_PASSWORD;

	if (!envUser || !envPass) {
		log.error('admin login attempted but ADMIN_USERNAME/ADMIN_PASSWORD are not set');
		return res.status(500).json({ error: 'Admin panel is not configured.' });
	}

	if (!username || !password ||
		!constantTimeEqual(username, envUser) ||
		!constantTimeEqual(password, envPass)) {
		return res.status(401).json({ error: 'Invalid credentials' });
	}

	const accessToken = jwt.sign(
		{ role_id: ROLE.ADMIN, uid: 'admin' },
		process.env.JWT_SECRET_KEY,
		{ expiresIn: '4h' }
	);

	return res.json({ accessToken });
});

// Everything below requires a valid admin token.
router.use(auth, authorize(ROLE.ADMIN));

router.get('/doctors/pending', async (req, res) => {
	try {
		const result = await db.request()
			.input('operation', 'ListPendingDoctors')
			.execute('sp_doctor_login');
		res.json(result.recordset);
	} catch (err) {
		log.error('admin ListPendingDoctors error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

router.post('/doctors/:id/verify', async (req, res) => {
	const doctorId = parseInt(req.params.id, 10);
	if (!doctorId) return res.status(400).json({ error: 'Invalid doctor id' });

	try {
		const result = await db.request()
			.input('operation', 'VerifyDoctor')
			.input('doctor_id', doctorId)
			.execute('sp_doctor_login');
		res.json(result.recordset?.[0] || { success: true });
	} catch (err) {
		log.error('admin VerifyDoctor error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

router.post('/doctors/:id/reject', async (req, res) => {
	const doctorId = parseInt(req.params.id, 10);
	if (!doctorId) return res.status(400).json({ error: 'Invalid doctor id' });

	try {
		// Reuses the existing soft-delete operation — a rejected doctor should
		// disappear from the pending queue and be unable to log in, exactly
		// like a deleted one.
		const result = await db.request()
			.input('operation', 'DeleteDoctor')
			.input('doctor_id', doctorId)
			.execute('sp_doctor_login');
		res.json(result.recordset?.[0] || { success: true });
	} catch (err) {
		log.error('admin reject doctor error: ' + err.message);
		res.status(500).json({ error: err.message });
	}
});

module.exports = router;
