// /login — Receptionist accounts (created and edited by their doctor).
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	auth,
	authorize,
	db,
	path,
	fs,
	log,
	receptionistsSql,
	UPLOADS_DIR,
	ownStaff,
	PUBLIC_BASE_URL,
	ROLE,
	upload,
	uploadHandler,
	verifyImageFiles,
	cleanupFiles,
} = require('./shared');

//  RECEPTIONIST — CREATE / UPDATE  (same pattern as /patient)
// ════════════════════════════════════════════════════════════════════
router.post('/receptionist', auth, authorize(ROLE.DOCTOR, ROLE.RECEPTIONIST), uploadHandler(upload.single("image")), ownStaff.check, async (req, res) => {
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
		log.debug('[ReceptionistDebug] save receptionist body', {
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

		const result = await request.run(receptionistsSql);

		const row = result.recordset?.[0];
		log.debug('[ReceptionistDebug] save receptionist result', row);

		if (!row?.success) {
			return res.status(400).json({
				success: false,
				message: row?.message || 'Receptionist operation failed',
			});
		}

		const returnedRecepId = row.recep_id || recep_id;
		let imageUrl = null;

		if (req.file) {
			const dir = path.join(UPLOADS_DIR, 'receptionist_images', returnedRecepId.toString());
			await fs.ensureDir(dir);

			const dest = path.join(dir, req.file.filename);
			await fs.move(req.file.path, dest, { overwrite: true });

			imageUrl = `${PUBLIC_BASE_URL}/uploads/receptionist_images/${returnedRecepId}/${req.file.filename}`;

			await db.request()
				.input('operation', 'uploadReceptionistImg')
				.input('recep_id', returnedRecepId)
				.input('img_url', imageUrl)
				.run(receptionistsSql);
		}

		return res.json({
			success: true,
			recep_id: returnedRecepId,
			image_url: imageUrl,
			message: operation === 'Update' ? 'Updated' : 'Created',
		});

	} catch (err) {
		log.error('[ReceptionistDebug] save receptionist failed', {
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
