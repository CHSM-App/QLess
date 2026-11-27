// /login — Doctor and patient profiles: registration (Insert) and edit (Update).
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	db,
	path,
	fs,
	log,
	patientsSql,
	doctorsSql,
	UPLOADS_DIR,
	PUBLIC_BASE_URL,
	ROLE,
	upload,
	uploadHandler,
	verifyImageFiles,
	cleanupFiles,
	otpProofError,
	checkSignupProof,
	checkMobileChangeProof,
	requireOwnProfile,
} = require('./shared');

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
		if (operation === "Update" && !(await requireOwnProfile(req, res, ROLE.DOCTOR, doctor_id))) return;
		if (operation === "Update" && !(await checkMobileChangeProof(req, res, mobile))) return;
		if (operation === "Insert" && !(await checkSignupProof(req, res, mobile))) return;

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

		const result = await request.run(doctorsSql);

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

			const dir = path.join(UPLOADS_DIR, "doctor_images", returnedDoctorId.toString());
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
				.run(doctorsSql);
		}

		// =========================
		// 3️⃣ CLINIC IMAGE
		// =========================
		if (req.files?.clinic_images?.length) {

			const dir = path.join(UPLOADS_DIR, "clinic_images", returnedClinicId.toString());
			await fs.ensureDir(dir);

			// Continue sort_order after the gallery images that already exist for
			// this clinic, so newly added photos append rather than collide.
			const existingGallery = await db.request()
				.input("operation", "fetchClinicGallery")
				.input("clinic_id", returnedClinicId)
				.run(doctorsSql);
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
					.run(doctorsSql);
				sortOrder++;
			}
		}

		// The app signs the new doctor in right after registering with the
		// ticket /verify-otp gave it — echoed back only when it is valid for this
		// mobile. (This route used to mint a fresh ticket for whatever mobile was
		// POSTed: register any unused number, be logged in, no OTP.)
		const loginTicket = operation === "Insert" && !otpProofError(mobile, { loginTicket: req.body.loginTicket })
			? req.body.loginTicket
			: undefined;

		return res.json({
			success: true,
			doctor_id: returnedDoctorId,
			clinic_id: returnedClinicId,
			doctor_image: doctorImageUrl,
			clinic_images: clinicImageUrls,
			clinic_image: clinicImageUrls[0] || null,
			message: operation === "Update" ? "Updated" : "Created",
			...(loginTicket ? { loginTicket } : {})
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
		if (operation === "Update" && !(await requireOwnProfile(req, res, ROLE.PATIENT, patient_id))) return;
		if (operation === "Update" && !(await checkMobileChangeProof(req, res, mobile_no))) return;
		if (operation === "Insert" && !(await checkSignupProof(req, res, mobile_no))) return;

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

		const result = await request.run(patientsSql);

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

			const dir = path.join(UPLOADS_DIR, "patient_images", returnedPatientId.toString());
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
				.run(patientsSql);
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

module.exports = router;
