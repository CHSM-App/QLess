const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
require('dotenv').config();
const auth = require('./middleware/auth');
const authorize = require('./middleware/authorize');
const { ROLE, ROLE_ID_BY_NAME, ROLE_NAME_BY_ID, resolveRoleId } = require('./middleware/roles');
const db = require('./db'); // your mssql pool wrapper
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const path = require('path');
const fs = require("fs-extra");
const { authLimiter, lookupLimiter } = require('./middleware/rateLimit');
const { upload, uploadHandler, verifyImageFiles, cleanupFiles } = require('./middleware/upload');
const log = require('./middleware/logger');

// Public base URL is required for returned image URLs to be reachable by
// clients. Fail fast at startup rather than silently building broken links.
const PUBLIC_BASE_URL = (process.env.PUBLIC_BASE_URL || '').replace(/\/+$/, '');
if (!PUBLIC_BASE_URL) {
	throw new Error('Missing required env var: PUBLIC_BASE_URL');
}

// Refresh-token lifetime. Access tokens are short (15m); the refresh token is
// what keeps the user signed in across days, so give it a long, Practo-style
// window. Override via REFRESH_TOKEN_TTL_DAYS env without a code change.
const REFRESH_TOKEN_TTL_DAYS = parseInt(process.env.REFRESH_TOKEN_TTL_DAYS, 10) || 30;
const REFRESH_TOKEN_TTL_MS = REFRESH_TOKEN_TTL_DAYS * 24 * 3600 * 1000;

// Login tickets prove "this mobile just passed OTP". Short-lived on purpose:
// long enough to finish the login call, too short to be worth stealing.
const LOGIN_TICKET_TTL = process.env.LOGIN_TICKET_TTL || '5m';

// Review/QA accounts skip the SMS OTP (mirrors frontend/lib/core/demo_accounts.dart).
// They still have to present the fixed demo OTP — the ranges alone are not a
// password. Keep both lists in sync when either side changes.
const DEMO_OTP = process.env.DEMO_OTP || '123456';
const DEMO_RANGES = [
	[9876000001, 9876000030], // doctors
	[9877000001, 9877000030], // receptionists
	[9878000001, 9878000050], // patients
];

function isDemoMobile(mobile) {
	const n = Number(String(mobile || '').replace(/\D/g, ''));
	if (!n) return false;
	return DEMO_RANGES.some(([from, to]) => n >= from && n <= to);
}

/** Digits only, last 10 — so "+91 98…", "098…" and "98…" compare equal. */
function normalizeMobile(value) {
	const digits = String(value || '').replace(/\D/g, '');
	return digits.length > 10 ? digits.slice(-10) : digits;
}

function generateRefreshToken() {
	return crypto.randomBytes(64).toString('hex');
}

// Create tokens helper
function createAccessToken(payload) {
	return jwt.sign(payload, process.env.JWT_SECRET_KEY, {
		expiresIn: process.env.JWT_ACCESS_TTL || '15m',
	});
}

/**
 * Looks the mobile up in the doctor / patient / receptionist tables and returns
 * { roleId, uid } — or null when the number holds no account at all.
 *
 * The client's `requestedRole` is only a preference, never the answer: one
 * mobile can legitimately be both a doctor and a patient, so the caller picks
 * which of their OWN roles to use, but can never claim one they do not hold.
 * Previously the role arrived in the request body and was written to the
 * session as-is, so posting role:"doctor" with a receptionist's number was
 * enough to get a doctor session.
 */
async function resolveAccountRole(mobile, requestedRole) {
	const wanted = ROLE_ID_BY_NAME[String(requestedRole || '').trim().toLowerCase()] || null;

	const firstRow = (result) => (result.recordset && result.recordset[0]) || null;
	const idOf = (row, ...keys) => {
		for (const key of keys) {
			const value = row && row[key];
			if (value !== undefined && value !== null && Number(value) > 0) return Number(value);
		}
		return null;
	};

	const lookups = {
		[ROLE.DOCTOR]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'doctor_mobile_exist')
				.input('mobile', mobile)
				.execute('sp_doctor_login'));
			return row ? { roleId: ROLE.DOCTOR, uid: idOf(row, 'doctor_id', 'id') } : null;
		},
		[ROLE.PATIENT]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'patient_mobile_exist')
				.input('mobile_no', mobile)
				.execute('sp_patients'));
			return row ? { roleId: ROLE.PATIENT, uid: idOf(row, 'patient_id', 'id') } : null;
		},
		[ROLE.RECEPTIONIST]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'check_phone_receptionist')
				.input('mobile_no', mobile)
				.execute('sp_receptionist'));
			return row ? { roleId: ROLE.RECEPTIONIST, uid: idOf(row, 'recep_id', 'id') } : null;
		},
	};

	// "Doctor" on the role picker covers clinic staff too, so a doctor login
	// that finds no doctor falls through to receptionist — that is how a
	// receptionist signs in today. Patient never falls through to staff.
	const order = wanted === ROLE.PATIENT
		? [ROLE.PATIENT]
		: wanted === ROLE.RECEPTIONIST
			? [ROLE.RECEPTIONIST, ROLE.DOCTOR]
			: [ROLE.DOCTOR, ROLE.RECEPTIONIST];

	for (const roleId of order) {
		const found = await lookups[roleId]();
		if (found) return found;
	}
	return null;
}

function createRefreshTokenPayload(mobile) {
	const token = generateRefreshToken();
	return token;
}

router.post('/Createlogin', authLimiter, async (req, res) => {
	try {
		const {
			mobile,
			deviceDetails,
			role,
			loginTicket,
			otp
		} = req.body;

		if (!mobile) return res.status(400).json({
			error: 'Mobile number required'
		});
		if (!role) return res.status(400).json({
			error: 'Role required'
		});

		const normalizedMobile = normalizeMobile(mobile);

		// ── Proof of OTP ────────────────────────────────────────────────
		// Issuing tokens for any mobile that was merely POSTed here meant a
		// phone number was the only thing standing between an attacker and a
		// full session. /verify-otp now hands out a signed, short-lived ticket
		// and this route refuses to mint a session without one.
		if (isDemoMobile(normalizedMobile)) {
			if (String(otp || '') !== DEMO_OTP) {
				return res.status(401).json({ error: 'Invalid OTP' });
			}
		} else {
			if (!loginTicket) {
				return res.status(401).json({ error: 'OTP verification required' });
			}
			try {
				const ticket = jwt.verify(loginTicket, process.env.JWT_SECRET_KEY);
				if (ticket.purpose !== 'login' || normalizeMobile(ticket.mobile) !== normalizedMobile) {
					return res.status(401).json({ error: 'OTP verification required' });
				}
			} catch (err) {
				log.error('Createlogin: bad login ticket for ' + normalizedMobile + ' (' + err.message + ')');
				return res.status(401).json({ error: 'OTP verification expired. Please try again.' });
			}
		}

		// ── Role comes from the database, not from the request body ──────
		const account = await resolveAccountRole(normalizedMobile, role);
		if (!account) {
			return res.status(404).json({
				error: 'No account found for this mobile number'
			});
		}
		const roleId = account.roleId;
		const roleName = ROLE_NAME_BY_ID[roleId];

		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		const refreshToken = createRefreshTokenPayload(mobile);
		const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', refreshToken)
			.input('device_info', deviceDetails)
			.input('expires_at', expiresAt)
			.input('role', roleName)
			.execute('ManageRefreshToken');

		// role_id travels inside the token so every route can authorize on it
		// instead of trusting whatever the caller sends.
		const accessToken = createAccessToken({
			mobile,
			role_id: roleId,
			uid: account.uid,
		});

		return res.json({
			accessToken,
			refreshToken,
			roleId,
			mobile
		});
	} catch (err) {
		log.error('Createlogin error: ' + err.message);
		return res.status(500).json({
			error: err.message
		});
	}
});


router.post('/refreshAccessToken', authLimiter, async (req, res) => {
	log.debug('inside the refreshAccessToken route');
	try {
		const {
			refreshToken
		} = req.body;

		if (!refreshToken)
			return res.status(400).json({
				error: 'Refresh token required'
			});

		const result = await db.request()
			.input('operation', 'get')
			.input('refresh_token', refreshToken)
			.execute('ManageRefreshToken');

		const rows = result.recordset || [];


		if (!rows.length)
			return res.status(403).json({
				error: 'Invalid refresh token'
			});

		const row = rows[0];
		const mobile = row.user_mobile;

		// Columns only (never the token values) — tells us at a glance whether
		// ManageRefreshToken's `get` actually projects role_id.
		log.debug('refreshAccessToken row columns: ' + Object.keys(row).join(','));

		// The SP does not always project role_id on `get` — that is why
		// /Createlogin already needed a fallback. Returning that raw value
		// handed the client roleId null → the app stored 0, which turned a
		// receptionist session into a doctor-looking one and wiped the session
		// on the next launch. Resolve it defensively instead, and refuse to
		// answer rather than reply with an unknown role.
		const roleId = resolveRoleId(row.role_id, row.role);
		if (!roleId) {
			log.error(
				'refreshAccessToken: cannot resolve role for ' + mobile +
				' (role_id=' + row.role_id + ' role=' + row.role + ')'
			);
			return res.status(500).json({
				error: 'Could not resolve account role. Please try again.'
			});
		}

		// revoke old
		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		// create new — same role as the stored session, re-resolving only the
		// account id so the token keeps carrying who this is.
		const account = await resolveAccountRole(normalizeMobile(mobile), ROLE_NAME_BY_ID[roleId]);
		const newAccessToken = createAccessToken({
			mobile,
			role_id: roleId,
			uid: account && account.roleId === roleId ? account.uid : null,
		});

		const newRefreshToken = createRefreshTokenPayload(mobile);

		const newExpiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);
		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', newRefreshToken)
			.input('device_info', row.device_info)
			.input('expires_at', newExpiresAt)
			.input('role', ROLE_NAME_BY_ID[roleId])

			.execute('ManageRefreshToken');



		return res.json({
			accessToken: newAccessToken,
			refreshToken: newRefreshToken,
			roleId,
			mobile
		});

	} catch (err) {
		return res.status(500).json({
			error: err.message
		});
	}
});


router.post('/saveFirebaseToken', async (req, res) => {
	log.debug('inside the saveFirebaseToken route');
	try {
		const {
			role,
			firebaseToken,
			mobile
		} = req.body;

		// Validate required fields
		if (!role || !firebaseToken || !mobile) {
			return res.status(400).json({
				error: 'role, mobile and firebaseToken are required'
			});
		}


		// Save firebase token via SP
		await db.request()
			.input('operation', 'saveFirebaseToken')
			.input('mobile', mobile)
			.input('token', firebaseToken)
			.input('role', role)
			.execute('sp_doctor_login');

		return res.status(200).json({
			success: true,
			message: `Firebase token saved for ${role}`,
			mobile,
			role,
		});

	} catch (err) {
		log.error('saveFirebaseToken error: ' + err.message);
		return res.status(500).json({
			error: err.message
		});
	}
});

router.post('/logout', async (req, res) => {
	try {
		const {
			refreshToken
		} = req.body;

		if (!refreshToken) {
			return res.status(400).json({
				success: false,
				message: 'Refresh token required'
			});
		}

		const result = await db.request()
			.input('operation', 'revoke')
			.input('refresh_token', refreshToken)
			.execute('ManageRefreshToken');

		const revokedCount = result.recordset[0]?.revoked_count || 0;

		if (revokedCount > 0) {
			return res.json({
				success: true,
				message: 'Logout successful'
			});
		} else {
			return res.status(400).json({
				success: false,
				message: 'Invalid refresh token or already revoked'
			});
		}

	} catch (err) {
		log.error('logout error: ' + err.message);
		return res.status(500).json({
			success: false,
			message: 'Logout failed'
		});
	}
});


// Used by receptionist login to load the linked doctor's full profile
router.get('/getDoctorProfileByClinic', lookupLimiter, async (req, res) => {
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
			.execute('sp_doctor_login');

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
			.execute('sp_patients');

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
			.execute('sp_doctor_login');
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
			.execute('sp_patients');
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
			.execute('sp_receptionist');

		console.log('[ReceptionistDebug] checkPhoneReceptionist result:', JSON.stringify(result.recordset?.[0]));
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
			.execute('sp_receptionist');
		res.json(result.recordset);
	} catch (err) {
		res.status(500).json({ error: err.message });
	}
});


router.post('/doctor', uploadHandler(upload.fields([{
	name: "doctor_image",
	maxCount: 1
},
{
	// Flutter sends the gallery under "clinic_images" (plural, up to 5).
	// Must match the field name the client uses or multer rejects the whole
	// upload with LIMIT_UNEXPECTED_FILE before the handler ever runs.
	name: "clinic_images",
	maxCount: 5
}
])), async (req, res) => {
	try {

		// Magic-byte check: confirm the bytes really are JPEG/PNG/WebP, not a
		// polyglot file with a spoofed mime. 415 + temp cleanup on mismatch.
		if (!(await verifyImageFiles(req, res))) return;

		const {
			doctor_id,
			name,
			email,
			mobile,
			qualification,
			license_no,
			experience,
			specialization,
			role_id,
			clinic_name,
			clinic_address,
			latitude,
			longitude,
			consultation_fee,
			website_name,
			clinic_email,
			clinic_contact,
			gender_id
		} = req.body;

		const operation = doctor_id && doctor_id > 0 ? "Update" : "Insert";

		// Registration must stay open — a new doctor has no token yet. Editing
		// an existing record must not: without this, any signed-in user (a
		// receptionist, a patient) could POST a doctor_id and rewrite that
		// doctor's profile. Updates therefore require a doctor's own token.
		if (operation === "Update") {
			// auth() is synchronous: it either calls next() or answers 401 itself.
			let authenticated = false;
			auth(req, res, () => { authenticated = true; });
			if (!authenticated) return;

			if (Number(req.user.role_id) !== ROLE.DOCTOR) {
				return res.status(403).json({
					error: 'Only the doctor can update this profile.'
				});
			}
			if (req.user.uid && Number(req.user.uid) !== Number(doctor_id)) {
				return res.status(403).json({
					error: 'You can only update your own profile.'
				});
			}
		}

		// =========================
		// 1️⃣ INSERT / UPDATE
		// =========================
		const request = db.request();

		request.input("operation", operation);

		request.input("doctor_id", doctor_id || null);
		request.input("name", name);
		request.input("email", email);
		request.input("mobile", mobile);
		request.input("qualification", qualification);
		request.input("license_no", license_no);
		request.input("experience", experience);
		request.input("specialization", specialization);
		request.input("role_id", role_id);
		request.input("gender_id", gender_id);

		request.input("clinic_name", clinic_name);
		request.input("clinic_address", clinic_address);
		request.input("latitude", latitude);
		request.input("longitude", longitude);
		request.input("consultation_fee", consultation_fee);
		request.input("website_name", website_name);
		request.input("clinic_email", clinic_email);
		request.input("clinic_contact", clinic_contact);

		const result = await request.execute("sp_doctor_login");

		const row = result.recordset?.[0];
		const returnedDoctorId = row?.doctor_id;
		const returnedClinicId = row?.clinic_id;

		if (!returnedDoctorId) {
			// row.success === 0 means the SP rejected it (duplicate mobile, etc.)
			// — surface its message as a 400 so the app can show it to the user.
			const isRejection = row?.success === 0;
			return res.status(isRejection ? 400 : 500).json({
				success: false,
				message: row?.message || 'Failed to save doctor'
			});
		}

		let doctorImageUrl = null;
		let clinicImageUrls = [];

		// =========================
		// 2️⃣ DOCTOR IMAGE
		// =========================
		if (req.files?.doctor_image) {

			const file = req.files.doctor_image[0];

			const dir = path.join(__dirname, "..", "uploads", "doctor_images", returnedDoctorId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, file.filename);
			await fs.move(file.path, dest, {
				overwrite: true
			});


			doctorImageUrl = `${PUBLIC_BASE_URL}/uploads/doctor_images/${returnedDoctorId}/${file.filename}`;

			await db.request()
				.input("operation", "uploadDoctorImg")
				.input("doctor_id", returnedDoctorId)
				.input("image", doctorImageUrl)
				.execute("sp_doctor_login");
		}

		// =========================
		// 3️⃣ CLINIC IMAGE
		// =========================
		if (req.files?.clinic_images?.length) {

			const dir = path.join(__dirname, "..", "uploads", "clinic_images", returnedClinicId.toString());
			await fs.ensureDir(dir);

			// Continue sort_order after the gallery images that already exist for
			// this clinic, so newly added photos append rather than collide.
			const existingGallery = await db.request()
				.input("operation", "fetchClinicGallery")
				.input("clinic_id", returnedClinicId)
				.execute("sp_doctor_login");
			let sortOrder = existingGallery.recordset?.length || 0;

			for (const file of req.files.clinic_images) {
				const dest = path.join(dir, file.filename);
				await fs.move(file.path, dest, {
					overwrite: true
				});

				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${returnedClinicId}/${file.filename}`;
				clinicImageUrls.push(url);

				// uploadClinicGallery INSERTs into dbo.clinic_images (the gallery the
				// app reads). uploadClinicImg only overwrote clinics.image_url (single).
				await db.request()
					.input("operation", "uploadClinicGallery")
					.input("clinic_id", returnedClinicId)
					.input("image_url", url)
					.input("sort_order", sortOrder)
					.execute("sp_doctor_login");
				sortOrder++;
			}
		}

		return res.json({
			success: true,
			doctor_id: returnedDoctorId,
			clinic_id: returnedClinicId,
			doctor_image: doctorImageUrl,
			clinic_images: clinicImageUrls,
			clinic_image: clinicImageUrls[0] || null,
			message: operation === "Update" ? "Updated" : "Created"
		});

	} catch (err) {
		log.error('doctor upsert error: ' + err.message);
		// Drop any orphaned temp file the upload left behind so /uploads/temp
		// doesn't grow forever when the SP / move step fails mid-request.
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});

router.post('/patient', uploadHandler(upload.single("image")), async (req, res) => {
	try {

		// Magic-byte check: confirm bytes match the claimed image format.
		if (!(await verifyImageFiles(req, res))) return;

		const {
			patient_id,
			name,
			mobile_no,
			email,
			address,
			gender_id,
			DOB,
			blood_group_id,
			weight
		} = req.body;

		const operation = patient_id && patient_id > 0 ? "Update" : "Insert";

		// Optional fields arrive as "" over multipart/form-data when left blank —
		// SQL Server can't implicitly convert "" to decimal/int, so null them out.
		const clean = (v) => (v === "" || v === undefined ? null : v);

		const request = db.request();

		request.input("operation", operation);
		request.input("patient_id", patient_id || null);
		request.input("name", name);
		request.input("mobile_no", mobile_no);
		request.input("email", clean(email));
		request.input("Address", clean(address));
		request.input("gender_id", gender_id);
		request.input("DOB", DOB);
		request.input("blood_group_id", clean(blood_group_id));
		request.input("weight", clean(weight));

		const result = await request.execute("sp_patients");

		const returnedPatientId = result.recordset?.[0]?.patient_id;

		if (!returnedPatientId) {
			return res.status(500).json({
				success: false,
				message: "Patient failed"
			});
		}

		let imageUrl = null;

		// =========================
		// IMAGE
		// =========================
		if (req.file) {

			const dir = path.join(__dirname, "..", "uploads", "patient_images", returnedPatientId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, req.file.filename);
			await fs.move(req.file.path, dest, {
				overwrite: true
			});

			imageUrl = `${PUBLIC_BASE_URL}/uploads/patient_images/${returnedPatientId}/${req.file.filename}`;

			await db.request()
				.input("operation", "uploadPatientImg")
				.input("patient_id", returnedPatientId)
				.input("img_url", imageUrl)
				.execute("sp_patients");
		}

		return res.json({
			success: true,
			patient_id: returnedPatientId,
			image_url: imageUrl,
			message: operation === "Update" ? "Updated" : "Created"
		});

	} catch (err) {
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});


router.post('/send-otp', async (req, res) => {
	try {
		const body = req.body || {};
		let mobile_no = body.mobile_no ?? body.mobileNo ?? body.mobile;

		if (!mobile_no) {
			return res.status(400).json({
				status: 0,
				message: 'Mobile number required'
			});
		}

		if (typeof mobile_no !== 'string') {
			mobile_no = mobile_no.toString();
		}

		let normalized = mobile_no.trim().replace(/\D/g, '');

		if (normalized.startsWith('91') && normalized.length > 10) {
			normalized = normalized.slice(normalized.length - 10);
		}

		if (normalized.startsWith('0')) {
			normalized = normalized.replace(/^0+/, '');
		}

		if (!/^[6-9]\d{9}$/.test(normalized)) {
			return res.status(400).json({
				status: 0,
				message: 'Invalid mobile number'
			});
		}

		const mobile_no_cc = `91${normalized}`;

		if (!process.env.WHATSAPP_API_TOKEN) {
			return res.status(500).json({
				status: 0,
				message: 'WhatsApp API token not configured'
			});
		}

		// ✅ Generate OTP
		const otp = Math.floor(100000 + Math.random() * 900000).toString();

		// ✅ Send WhatsApp OTP
		const waResponse = await axios.post(
			"https://api2.smsala.com/whatsapp/SendOtp",
			{
				PhoneNumber: mobile_no_cc,
				OtpCode: otp,
				ApiToken: process.env.WHATSAPP_API_TOKEN,
				TemplateId: 463
			}
		);

		if (!waResponse.data || waResponse.data.IsSuccess !== true) {
			return res.status(400).json({
				status: 0,
				message: 'Failed to send OTP via WhatsApp',
				response: waResponse.data
			});
		}

		// ✅ Hash OTP
		const otp_hash = await bcrypt.hash(otp, 10);

		// ✅ Save in DB using normalized local number
		const dbResult = await db.request()
			.input('operation', 'send_otp')
			.input('mobile_no', normalized)
			.input('otp_hash', otp_hash)
			.execute('sp_otp');

		if (dbResult.recordset[0].status === 0) {
			return res.status(400).json(dbResult.recordset[0]);
		}

		res.json({
			status: 1,
			message: 'OTP sent successfully',
			otp: otp // ⚠️ remove in production
		});

	} catch (err) {
		res.status(500).json({
			status: 0,
			message: 'Server error',
			error: err?.response?.data || err.message
		});
	}
});
router.post('/verify-otp', async (req, res) => {
	const { mobile_no, otp } = req.body;

	try {
		const result = await db.request()
			.input('operation', 'verify_otp')
			.input('mobile_no', mobile_no)
			.execute('sp_otp');

		const data = result.recordset[0];

		if (data.status === 0) {
			return res.status(400).json(data);
		}

		const isMatch = await bcrypt.compare(otp, data.otp_hash);

		if (!isMatch) {
			// increase attempt
			await db.request()
				.input('operation', 'update_attempt')
				.input('mobile_no', mobile_no)
				.execute('sp_otp');

			return res.status(400).json({
				status: 0,
				message: 'Invalid OTP'
			});
		}

		// mark verified
		await db.request()
			.input('operation', 'mark_verified')
			.input('mobile_no', mobile_no)
			.execute('sp_otp');

		// Proof that this mobile passed OTP, to be handed straight back to
		// /Createlogin. Without it that route would keep issuing sessions to
		// anyone who knows a phone number.
		const loginTicket = jwt.sign(
			{ mobile: normalizeMobile(mobile_no), purpose: 'login' },
			process.env.JWT_SECRET_KEY,
			{ expiresIn: LOGIN_TICKET_TTL }
		);

		res.json({
			status: 1,
			message: 'OTP verified successfully',
			loginTicket
		});

	} catch (err) {
		console.error(err);
		res.status(500).json({ error: 'Server error' });
	}
});


router.get('/privacy', (req, res) => {
	res.sendFile(path.join(__dirname, 'privacy.html'));
});


router.get('/delete-account', (req, res) => {
	res.sendFile(path.join(__dirname, 'delete-account.html'));
});



// ════════════════════════════════════════════════════════════════════
//  DOCTOR CLINICS
// ════════════════════════════════════════════════════════════════════

router.get('/getClinicsForDoctor/:doctor_id', async (req, res) => {
	try {
		const { doctor_id } = req.params;
		if (!doctor_id) return res.status(400).json({ error: 'doctor_id required' });
		const result = await db.request()
			.input('operation', 'GetDoctorClinics')
			.input('doctor_id', parseInt(doctor_id))
			.execute('sp_doctor_login');
		return res.json(result.recordset);
	} catch (err) {
		log.error('getClinicsForDoctor error: ' + err.message);
		return res.status(500).json({ error: err.message });
	}
});

router.post('/addClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		const {
			doctor_id, clinic_name, clinic_address,
			latitude, longitude, consultation_fee,
			website_name, clinic_email, clinic_contact,
		} = req.body;

		if (!doctor_id) return res.status(400).json({ success: false, error: 'doctor_id required' });

		const result = await db.request()
			.input('operation', 'AddClinic')
			.input('doctor_id', parseInt(doctor_id))
			.input('clinic_name', clinic_name || null)
			.input('clinic_address', clinic_address || null)
			.input('latitude', latitude ? parseFloat(latitude) : null)
			.input('longitude', longitude ? parseFloat(longitude) : null)
			.input('consultation_fee', consultation_fee ? parseFloat(consultation_fee) : null)
			.input('website_name', website_name || null)
			.input('clinic_email', clinic_email || null)
			.input('clinic_contact', clinic_contact || null)
			.execute('sp_doctor_login');

		const row = result.recordset?.[0];
		if (!row?.success) {
			return res.status(400).json({ success: false, error: row?.ErrorMessage || 'Failed to add clinic' });
		}

		const returnedClinicId = row.clinic_id;
		const clinicImageUrls = [];

		if (req.files?.clinic_images?.length) {
			const dir = require('path').join(__dirname, '..', 'uploads', 'clinic_images', returnedClinicId);
			await require('fs-extra').ensureDir(dir);

			let sortOrder = 0;
			for (const file of req.files.clinic_images) {
				const dest = require('path').join(dir, file.filename);
				await require('fs-extra').move(file.path, dest, { overwrite: true });
				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${returnedClinicId}/${file.filename}`;
				clinicImageUrls.push(url);
				await db.request()
					.input('operation', 'uploadClinicGallery')
					.input('clinic_id', returnedClinicId)
					.input('image_url', url)
					.input('sort_order', sortOrder)
					.execute('sp_doctor_login');
				sortOrder++;
			}
		}

		return res.json({ success: true, clinic_id: returnedClinicId, clinic_images: clinicImageUrls });
	} catch (err) {
		log.error('addClinic error: ' + err.message);
		await cleanupFiles(req).catch(() => { });
		return res.status(500).json({ success: false, error: err.message });
	}
});

router.put('/updateClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		const {
			clinic_id, doctor_id, clinic_name, clinic_address,
			latitude, longitude, consultation_fee,
			website_name, clinic_email, clinic_contact,
		} = req.body;

		if (!clinic_id || !doctor_id) return res.status(400).json({ success: false, error: 'clinic_id and doctor_id required' });

		await db.request()
			.input('operation', 'UpdateClinic')
			.input('clinic_id', clinic_id)
			.input('doctor_id', parseInt(doctor_id))
			.input('clinic_name', clinic_name || null)
			.input('clinic_address', clinic_address || null)
			.input('latitude', latitude ? parseFloat(latitude) : null)
			.input('longitude', longitude ? parseFloat(longitude) : null)
			.input('consultation_fee', consultation_fee ? parseFloat(consultation_fee) : null)
			.input('website_name', website_name || null)
			.input('clinic_email', clinic_email || null)
			.input('clinic_contact', clinic_contact || null)
			.execute('sp_doctor_login');

		if (req.files?.clinic_images?.length) {
			const dir = require('path').join(__dirname, '..', 'uploads', 'clinic_images', clinic_id);
			await require('fs-extra').ensureDir(dir);
			let sortOrder = 0;
			for (const file of req.files.clinic_images) {
				const dest = require('path').join(dir, file.filename);
				await require('fs-extra').move(file.path, dest, { overwrite: true });
				const url = `${PUBLIC_BASE_URL}/uploads/clinic_images/${clinic_id}/${file.filename}`;
				await db.request()
					.input('operation', 'uploadClinicGallery')
					.input('clinic_id', clinic_id)
					.input('image_url', url)
					.input('sort_order', sortOrder)
					.execute('sp_doctor_login');
				sortOrder++;
			}
		}

		return res.json({ success: true, clinic_id });
	} catch (err) {
		log.error('updateClinic error: ' + err.message);
		await cleanupFiles(req).catch(() => { });
		return res.status(500).json({ success: false, error: err.message });
	}
});

router.delete('/deleteClinic/:clinic_id/:doctor_id', auth, authorize(ROLE.DOCTOR), async (req, res) => {
	try {
		const { clinic_id, doctor_id } = req.params;
		if (!clinic_id || !doctor_id) return res.status(400).json({ success: false, error: 'clinic_id and doctor_id required' });

		const result = await db.request()
			.input('operation', 'DeleteClinic')
			.input('clinic_id', clinic_id)
			.input('doctor_id', parseInt(doctor_id))
			.execute('sp_doctor_login');

		const row = result.recordset?.[0];
		if (!row?.success) {
			return res.status(400).json({ success: false, error: row?.message || 'Cannot delete clinic' });
		}
		return res.json({ success: true });
	} catch (err) {
		log.error('deleteClinic error: ' + err.message);
		return res.status(500).json({ success: false, error: err.message });
	}
});

// ════════════════════════════════════════════════════════════════════

//  RECEPTIONIST — CREATE / UPDATE  (same pattern as /patient)
// ════════════════════════════════════════════════════════════════════
router.post('/receptionist', auth, authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST), uploadHandler(upload.single("image")), async (req, res) => {
	try {
		if (!(await verifyImageFiles(req, res))) return;

		// Doctors manage their staff; a receptionist may only edit their own
		// record (the app shows them this screen as "Personal Information").
		if (Number(req.user.role_id) === ROLE.RECEPTIONIST) {
			const ownId = Number(req.user.uid);
			const targetId = Number(req.body.recep_id);
			if (!ownId || !targetId || ownId !== targetId) {
				return res.status(403).json({
					success: false,
					message: 'You can only edit your own profile.'
				});
			}
		}

		const {
			recep_id,
			name,
			mobile_no,
			email,
			address,
			gender_id,
			clinic_id,
			doctor_id,
		} = req.body;
		console.log('[ReceptionistDebug] save receptionist body:', {
			recep_id,
			name,
			mobile_no,
			email,
			gender_id,
			clinic_id,
			doctor_id,
			hasImage: !!req.file,
		});

		const parsedRecepId = recep_id ? parseInt(recep_id) : null;
		const parsedGenderId = gender_id ? parseInt(gender_id) : null;
		const parsedDoctorId = doctor_id ? parseInt(doctor_id) : null;
		const operation = parsedRecepId && parsedRecepId > 0 ? 'Update' : 'Insert';

		const request = db.request();
		request.input('operation', operation);
		request.input('recep_id', parsedRecepId);
		request.input('name', name);
		request.input('mobile_no', mobile_no);
		request.input('email', email || null);
		request.input('Address', address || null);
		request.input('gender_id', parsedGenderId);
		request.input('clinic_id', (clinic_id != null && clinic_id !== undefined && String(clinic_id) !== '0') ? clinic_id : null);
		request.input('doctor_id', parsedDoctorId);

		const result = await request.execute('sp_receptionist');

		const row = result.recordset?.[0];
		console.log('[ReceptionistDebug] save receptionist result:', row);

		if (!row?.success) {
			return res.status(400).json({
				success: false,
				message: row?.message || 'Receptionist operation failed',
			});
		}

		const returnedRecepId = row.recep_id || recep_id;
		let imageUrl = null;

		if (req.file) {
			const dir = path.join(__dirname, '..', 'uploads', 'receptionist_images', returnedRecepId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, req.file.filename);
			await fs.move(req.file.path, dest, { overwrite: true });

			imageUrl = `${PUBLIC_BASE_URL}/uploads/receptionist_images/${returnedRecepId}/${req.file.filename}`;

			await db.request()
				.input('operation', 'uploadReceptionistImg')
				.input('recep_id', returnedRecepId)
				.input('img_url', imageUrl)
				.execute('sp_receptionist');
		}

		return res.json({
			success: true,
			recep_id: returnedRecepId,
			image_url: imageUrl,
			message: operation === 'Update' ? 'Updated' : 'Created',
		});

	} catch (err) {
		console.error('[ReceptionistDebug] save receptionist CATCH full:', {
			message: err?.message,
			code: err?.code,
			number: err?.number,
			state: err?.state,
			class: err?.class,
			lineNumber: err?.lineNumber,
			procName: err?.procName,
			originalMessage: err?.originalError?.message,
			preceding: err?.precedingErrors?.map(e => e.message),
		});
		const errMsg = err?.originalError?.message || err?.message || err?.toString() || 'Unknown error';
		await cleanupFiles(req).catch(() => { });
		res.status(500).json({ success: false, error: errMsg });
	}
});


module.exports = router;
