// /login — Lookups: receptionist→doctor profile, "does this mobile exist" checks.
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	auth,
	authorize,
	db,
	log,
	receptionistsSql,
	patientsSql,
	doctorsSql,
	ROLE,
	lookupLimiter,
} = require('./shared');

// Used by receptionist login to load the linked doctor's full profile
// (mobile, email, FCM token …) — so clinic staff only: it used to answer anyone.
router.get('/getDoctorProfileByClinic', lookupLimiter, auth, authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST), async (req, res) => {
	try {
		const { clinic_id, doctor_id } = req.query;

		if (doctor_id && parseInt(doctor_id) > 0 && clinic_id) {
			const r = await db.request()
				.input('doctor_id', parseInt(doctor_id))
				.input('clinic_id', clinic_id)
				.query('SELECT * FROM dbo.doctor_login_vw WHERE doctor_id = @doctor_id AND clinic_id = @clinic_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		if (doctor_id && parseInt(doctor_id) > 0) {
			const r = await db.request()
				.input('doctor_id', parseInt(doctor_id))
				.query('SELECT * FROM dbo.doctor_login_vw WHERE doctor_id = @doctor_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		if (clinic_id) {
			const r = await db.request()
				.input('clinic_id', clinic_id)
				.query('SELECT * FROM dbo.doctor_login_vw WHERE clinic_id = @clinic_id AND doc_active_status = 0');
			return res.json(r.recordset);
		}

		res.json([]);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});

router.get('/checkPhoneDoctor', lookupLimiter, async (req, res) => {
	try {
		const {
			mobile
		} = req.query;

		const result = await db.request()
			.input('operation', 'check_phone_doctor')
			.input('mobile', mobile)
			.run(doctorsSql);

		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});

router.get('/checkPhonePatient', lookupLimiter, async (req, res) => {
	try {
		const mobile_no = req.query.mobile_no ?? req.query.mobileNo;

		const result = await db.request()
			.input('operation', 'check_phone_patient')
			.input('mobile_no', mobile_no)
			.run(patientsSql);

		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});


router.get('/mobileExistDoctor', lookupLimiter, async (req, res) => {
	try {
		const {
			mobile
		} = req.query;
		const result = await db.request()
			.input('operation', 'doctor_mobile_exist')
			.input('mobile', mobile)
			.run(doctorsSql);
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});

router.get('/mobileExistPatient', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) {
			return res.status(400).json({
				error: 'mobile_no is required'
			});
		}

		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) {
			mobile_no = mobile_no.slice(2);
		}

		if (!/^[6-9]\d{9}$/.test(mobile_no)) {
			return res.status(400).json({
				error: 'Invalid mobile number'
			});
		}

		const result = await db.request()
			.input('operation', 'patient_mobile_exist')
			.input('mobile_no', mobile_no)
			.run(patientsSql);
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({
			error: err.message
		});
	}
});


router.get('/checkPhoneReceptionist', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) return res.status(400).json({ error: 'mobile_no is required' });
		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) mobile_no = mobile_no.slice(2);

		const result = await db.request()
			.input('operation', 'check_phone_receptionist')
			.input('mobile_no', mobile_no)
			.run(receptionistsSql);

		log.debug('[ReceptionistDebug] checkPhoneReceptionist found=' + !!result.recordset?.[0]);
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});

router.get('/mobileExistReceptionist', lookupLimiter, async (req, res) => {
	try {
		let mobile_no = req.query.mobile_no ?? req.query.mobileNo;
		if (!mobile_no) {
			return res.status(400).json({ error: 'mobile_no is required' });
		}

		mobile_no = mobile_no.toString().trim().replace(/\D/g, '');
		if (mobile_no.startsWith('91') && mobile_no.length === 12) {
			mobile_no = mobile_no.slice(2);
		}

		if (!/^[6-9]\d{9}$/.test(mobile_no)) {
			return res.status(400).json({ error: 'Invalid mobile number' });
		}

		const result = await db.request()
			.input('operation', 'check_phone_receptionist')
			.input('mobile_no', mobile_no)
			.run(receptionistsSql);
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});

module.exports = router;
