const express = require('express');
const router = express.Router();
const jwt = require('jsonwebtoken');
require('dotenv').config();
const auth = require('./middleware/auth');
const db = require('./db'); // your mssql pool wrapper
const crypto = require('crypto');
const path = require('path');
const multer = require("multer");
const fs = require("fs-extra");

const storage = multer.diskStorage({
	destination: async (req, file, cb) => {
		const tempDir = path.join(__dirname, "..", "uploads", "temp");
		await fs.ensureDir(tempDir);
		cb(null, tempDir);
	},
	filename: (req, file, cb) => {
		const name = file.originalname.replace(/\s+/g, "_");
		cb(null, Date.now() + "-" + name);
	}
});

const upload = multer({
	storage
});
var bodyParser = require('body-parser');

function generateRefreshToken() {
	return crypto.randomBytes(64).toString('hex');
}

// Create tokens helper
function createAccessToken(payload) {
	return jwt.sign(payload, process.env.JWT_SECRET_KEY, {
		expiresIn: '1m'
	}); // production: 15m
}

function createRefreshTokenPayload(mobile) {
	const token = generateRefreshToken();
	return token;
}

router.post('/Createlogin', async (req, res) => {
	try {
		const {
			mobile,
			deviceDetails,
			role
		} = req.body; // ✅ add role

		if (!mobile) return res.status(400).json({
			error: 'Mobile number required'
		});
		if (!role) return res.status(400).json({
			error: 'Role required'
		}); // optional but recommended

		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		const refreshToken = createRefreshTokenPayload(mobile);
		const expiresAt = new Date(Date.now() + 7 * 24 * 3600 * 1000);

		const result = await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', refreshToken)
			.input('device_info', deviceDetails)
			.input('expires_at', expiresAt)
			.input('role', role) // 'doctor' or 'patient'
			.execute('ManageRefreshToken');


		const roleId = result.recordset?.[0]?.role_id;

		const accessToken = createAccessToken({
			mobile
		});

		return res.json({
			accessToken,
			refreshToken,
			roleId,
			mobile
		});
	} catch (err) {
		console.error(err);
		return res.status(500).json({
			error: err.message
		});
	}
});


router.post('/refreshAccessToken', async (req, res) => {
	console.log("inside the refreshAccessToken route");
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
		const roleId = row.role_id;

		// revoke old
		await db.request()
			.input('operation', 'revoke')
			.input('user_mobile', mobile)
			.execute('ManageRefreshToken');

		// create new
		const newAccessToken = createAccessToken({
			mobile
		});

		const newRefreshToken = createRefreshTokenPayload(mobile);

		const newExpiresAt = new Date(Date.now() + 7 * 24 * 3600 * 1000);
		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', newRefreshToken)
			.input('device_info', row.device_info)
			.input('expires_at', newExpiresAt)
			.input('role', row.role_id == 1 ? 'doctor' : 'patient')

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
	console.log("inside the saveFirebaseToken route");
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
		console.error("saveFirebaseToken error:", err.message);
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
		console.error(err);
		return res.status(500).json({
			success: false,
			message: 'Logout failed'
		});
	}
});


router.get('/checkPhoneDoctor', async (req, res) => {
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

router.get('/checkPhonePatient', async (req, res) => {
	try {
		console.log('query:', req.query); // <-- add this
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


router.get('/mobileExistDoctor', async (req, res) => {
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

router.get('/mobileExistPatient', async (req, res) => {
	try {
		const {
			mobile_no
		} = req.query;
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


router.post('/doctor', upload.fields([{
		name: "doctor_image",
		maxCount: 1
	},
	{
		name: "clinic_image",
		maxCount: 1
	}
]), async (req, res) => {
	try {

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

		const returnedDoctorId = result.recordset?.[0]?.doctor_id;
		const returnedClinicId = result.recordset?.[0]?.clinic_id;

		if (!returnedDoctorId) {
			return res.status(500).json({
				success: false,
				message: result
			});
		}

		let doctorImageUrl = null;
		let clinicImageUrl = null;

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

			doctorImageUrl = `https://qless.vengurlatech.com/uploads/doctor_images/${returnedDoctorId}/${file.filename}`;

			await db.request()
				.input("operation", "uploadDoctorImg")
				.input("doctor_id", returnedDoctorId)
				.input("image", doctorImageUrl)
				.execute("sp_doctor_login");
		}

		// =========================
		// 3️⃣ CLINIC IMAGE
		// =========================
		if (req.files?.clinic_image) {

			const file = req.files.clinic_image[0];

			const dir = path.join(__dirname, "..", "uploads", "clinic_images", returnedClinicId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, file.filename);
			await fs.move(file.path, dest, {
				overwrite: true
			});

			clinicImageUrl = `https://qless.vengurlatech.com/uploads/clinic_images/${returnedClinicId}/${file.filename}`;

			await db.request()
				.input("operation", "uploadClinicImg")
				.input("clinic_id", returnedClinicId)
				.input("image_url", clinicImageUrl)
				.execute("sp_doctor_login");
		}

		return res.json({
			success: true,
			doctor_id: returnedDoctorId,
			clinic_id: returnedClinicId,
			doctor_image: doctorImageUrl,
			clinic_image: clinicImageUrl,
			message: operation === "Update" ? "Updated" : "Created"
		});

	} catch (err) {
		console.error(err);
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});

router.post('/patient', upload.single("image"), async (req, res) => {
	try {

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

		const request = db.request();

		request.input("operation", operation);
		request.input("patient_id", patient_id || null);
		request.input("name", name);
		request.input("mobile_no", mobile_no);
		request.input("email", email);
		request.input("Address", address);
		request.input("gender_id", gender_id);
		request.input("DOB", DOB);
		request.input("blood_group_id", blood_group_id);
		request.input("weight", weight);

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

			imageUrl = `https://qless.vengurlatech.com/uploads/patient_images/${returnedPatientId}/${req.file.filename}`;

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
		res.status(500).json({
			success: false,
			error: err.message
		});
	}
});

router.get('/privacy', (req, res) => {
	res.sendFile(path.join(__dirname, 'privacy.html'));
});


module.exports = router;