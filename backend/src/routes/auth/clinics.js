// /login — Doctor clinics: list, add, update, delete.
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	auth,
	authorize,
	db,
	path,
	log,
	doctorsSql,
	UPLOADS_DIR,
	ownStaff,
	PUBLIC_BASE_URL,
	ROLE,
	upload,
	uploadHandler,
	verifyImageFiles,
	cleanupFiles,
} = require('./shared');

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
			.run(doctorsSql);
		return res.json(result.recordset);
	} catch (err) {
		log.error('getClinicsForDoctor error: ' + err.message);
		return res.status(500).json({ error: err.message });
	}
});

router.post('/addClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), ownStaff.check, async (req, res) => {
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
			.run(doctorsSql);

		const row = result.recordset?.[0];
		if (!row?.success) {
			return res.status(400).json({ success: false, error: row?.ErrorMessage || 'Failed to add clinic' });
		}

		const returnedClinicId = row.clinic_id;
		const clinicImageUrls = [];

		if (req.files?.clinic_images?.length) {
			const dir = path.join(UPLOADS_DIR, 'clinic_images', returnedClinicId);
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
					.run(doctorsSql);
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

router.put('/updateClinic', auth, authorize(ROLE.DOCTOR), uploadHandler(upload.fields([{ name: 'clinic_images', maxCount: 5 }])), ownStaff.check, async (req, res) => {
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
			.run(doctorsSql);

		if (req.files?.clinic_images?.length) {
			const dir = path.join(UPLOADS_DIR, 'clinic_images', clinic_id);
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
					.run(doctorsSql);
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

router.delete('/deleteClinic/:clinic_id/:doctor_id', auth, authorize(ROLE.DOCTOR), ownStaff.check, async (req, res) => {
	try {
		const { clinic_id, doctor_id } = req.params;
		if (!clinic_id || !doctor_id) return res.status(400).json({ success: false, error: 'clinic_id and doctor_id required' });

		const result = await db.request()
			.input('operation', 'DeleteClinic')
			.input('clinic_id', clinic_id)
			.input('doctor_id', parseInt(doctor_id))
			.run(doctorsSql);

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

module.exports = router;
