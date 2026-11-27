// /doctor/insert — Doctor's medicine list and prescriptions.

const express = require('express');
const db = require('../../../db');
const sql = require('mssql');
const admin = require('../../../fcm');
const log = require('../../../middleware/logger');

const {
  insertNotification,
} = require('./shared');
const medicinesSql = require('../../../queries/medicines');
const prescriptionsSql = require('../../../queries/prescriptions');
const { ROLE } = require('../../../middleware/roles');
const { whatsappLimiter } = require('../../../middleware/rateLimit');
const { sendWhatsAppTemplate, indianMobile } = require('../../../whatsapp');

const router = express.Router();

router.post('/insertMedicine', async (req, res) => {
  const {
    doctor_id,
    medicine_name,
    medicine_type_id,
    brand_name,
    strength,
    components
  } = req.body;

  // Optional fields: trim, empty -> null
  const opt = (v) => (typeof v === 'string' && v.trim() ? v.trim() : null);

  try {
    const request = db.request();

    request.input('operation', 'Insert');
    request.input('doctor_id', doctor_id);
    request.input('medicine_name', medicine_name);
    request.input('medicine_type_id', medicine_type_id);
    request.input('brand_name', opt(brand_name));
    request.input('strength', opt(strength));
    request.input('components', opt(components));

    const result = await request.run(medicinesSql);

    const message = result.recordset?.[0]?.Message || 'Medicine inserted successfully';
    const medicine_id = result.recordset?.[0]?.medicine_id ?? null;
    // A medicine added offline and replayed after the first send landed is
    // already in the list — that's the outcome the doctor wanted, not an error.
    const isDuplicate = /already (exists|in your list)/i.test(message) && !req.body.offline_queued_at;

    res.status(isDuplicate ? 409 : 200).json({
      success: isDuplicate ? 0 : 1,
      message,
      medicine_id,
      data: result.recordset,
    });

  } catch (error) {
    res.status(500).json({
      success: 0,
      message: `Failed to insert medicine. ${error}`,
    });
  }
});

router.post('/insertPrescription', async (req, res) => {
  const {
    patient_id,
    doctor_id,
    prescription_date,
    symptoms,
    diagnosis,
    user_type,
    appointment_id,
    clinical_notes,
    follow_up_date,
    follow_up_time,
    advice,
    investigation,
    medicines = [],
    clinic_id,
  } = req.body;

  if (!patient_id) {
    return res.status(400).json({ success: false, message: 'patient_id is required' });
  }

  if (!doctor_id) {
    return res.status(400).json({ success: false, message: 'doctor_id is required' });
  }

  if (!Array.isArray(medicines)) {
    return res.status(400).json({ success: false, message: 'medicines must be an array' });
  }

  const clean = (v) => (v === '' || v === undefined ? null : v);

  if (clean(follow_up_time) !== null && !/^([01]\d|2[0-3]):[0-5]\d(:[0-5]\d)?$/.test(follow_up_time)) {
    return res.status(400).json({ success: false, message: 'follow_up_time must be HH:mm' });
  }

  // Clinic stock per line: 'clinic' takes qty_given out of the clinic's stock,
  // 'outside' (or nothing, as older apps send) is bought at a medical shop.
  // Checked up front so a bad line never leaves a half-saved prescription.
  const stock = [];
  for (const med of medicines) {
    const source = ['clinic', 'outside'].includes(med?.source) ? med.source : null;
    const qty = Number(med?.qty_given);
    const price = med?.unit_price === undefined || med?.unit_price === null || med?.unit_price === ''
      ? null : Number(med.unit_price);
    if (source === 'clinic' && !clinic_id) {
      return res.status(400).json({ success: false, message: 'clinic_id is required when a medicine is given from clinic stock' });
    }
    if (source === 'clinic' && !(qty > 0)) {
      return res.status(400).json({ success: false, message: 'qty_given must be more than 0 for a medicine given from clinic stock' });
    }
    if (price !== null && !(price >= 0)) {
      return res.status(400).json({ success: false, message: 'unit_price must be 0 or more' });
    }
    stock.push({
      source,
      administered_at_clinic: med?.administered_at_clinic ? 1 : 0,
      qty_given: source === 'clinic' ? qty : (qty > 0 ? qty : null),
      unit_price: price,
    });
  }

  let prescription_id = null;
  let saved = false; // all medicine rows written — never undo after this
  // Each medicine is its own SP call. If one fails after the header row was
  // written, remove what was saved so a retry (offline replay) starts clean
  // instead of hitting the duplicate check with medicines missing.
  const undoPartial = async () => {
    if (!prescription_id || saved) return;
    try {
      await db.request()
        .input('prescription_id', sql.Int, prescription_id)
        .query(`DELETE FROM Clinic_Stock_Movement WHERE presc_med_id IN
                  (SELECT presc_med_id FROM PrescriptionMedicine WHERE prescription_id = @prescription_id);
                DELETE FROM PrescriptionMedicine WHERE prescription_id = @prescription_id;
                DELETE FROM patient_records WHERE prescription_id = @prescription_id;`);
    } catch (e) {
      log.error(`[insertPrescription] undo of ${prescription_id} failed: ` + e.message);
    }
  };

  try {
    // One prescription per appointment. A retry (offline replay, or a resend
    // after a timeout whose first attempt actually landed) must not create a
    // duplicate or re-notify the patient — return the existing one.
    if (parseInt(appointment_id) > 0) {
      const existing = await db.request()
        .input('appointment_id', sql.Int, parseInt(appointment_id))
        .query('SELECT TOP 1 prescription_id FROM patient_records WHERE appointment_id = @appointment_id');
      const existingId = existing.recordset?.[0]?.prescription_id;
      if (existingId) {
        log.info(`[insertPrescription] appointment ${appointment_id} already has prescription ${existingId} — skipped duplicate`);
        return res.json({ success: true, prescription_id: existingId, message: 'Prescription already saved' });
      }
    }

    let patientToken = null;
    let doctorName = null;


    const rows = medicines.length > 0 ? medicines : [null];

    for (let i = 0; i < rows.length; i++) {
      const med = rows[i];

      const request = db.request();

      request.input('operation', 'Insert');
      request.input('prescription_id', prescription_id ?? 0);
      request.input('patient_id', patient_id);
      request.input('doctor_id', doctor_id);
      request.input('prescription_date', clean(prescription_date) ?? new Date());
      request.input('symptoms', clean(symptoms));
      request.input('diagnosis', clean(diagnosis));
      request.input('clinical_notes', clean(clinical_notes));
      request.input('follow_up_date', clean(follow_up_date));
      request.input('follow_up_time', clean(follow_up_time));
      request.input('advice', clean(advice));
      request.input('investigation', clean(investigation));
      request.input('created_at', new Date());
      request.input('user_type', user_type);
      request.input('appointment_id', appointment_id);
      request.input('clinic_id', clinic_id || null);

      request.input('medicine_id', med?.medicine_id ?? null);
      request.input('medicine_type_id', med?.medicine_type_id ?? null);
      request.input('frequency', clean(med?.frequency));
      request.input('duration', clean(med?.duration));
      request.input('timing', clean(med?.timing));
      request.input('tablet_dosage', clean(med?.tablet_dosage));
      request.input('syrup_dosage_ml', clean(med?.syrup_dosage_ml));
      request.input('inj_dosage', clean(med?.inj_dosage));
      request.input('inj_route', clean(med?.inj_route));
      request.input('drops_count', clean(med?.drops_count));
      request.input('drops_application', clean(med?.drops_application));
      request.input('lotion_apply_area', clean(med?.lotion_apply_area));
      request.input('spray_puffs', clean(med?.spray_puffs));
      request.input('spray_usage', clean(med?.spray_usage));
      request.input('lotion_usage', clean(med?.lotion_usage));

      // ── Powders ───────────────────────────────────────────────
      request.input('powder_dosage', clean(med?.powder_dosage));
      request.input('powder_form', clean(med?.powder_form));

      // ── Inhalers ──────────────────────────────────────────────
      request.input('inhaler_puffs', clean(med?.inhaler_puffs));
      request.input('inhaler_type', clean(med?.inhaler_type));
      request.input('inhaler_technique', clean(med?.inhaler_technique));
      request.input('inhaler_usage', clean(med?.inhaler_usage));

      // ── Clinic stock ──────────────────────────────────────────
      if (med) {
        request.input('source', stock[i].source);
        request.input('administered_at_clinic', stock[i].administered_at_clinic);
        request.input('qty_given', stock[i].qty_given);
        request.input('unit_price', stock[i].unit_price);
        request.input('created_by_id', Number(req.user.uid));
        request.input('created_by_role', Number(req.user.role_id));
      }

      const result = await request.run(prescriptionsSql);

      const row = result.recordset?.[0];

      if (!row || row.success === 0) {
        await undoPartial();
        return res.status(500).json({
          success: false,
          message: row?.message || 'Prescription failed'
        });
      }

      // ✅ FIRST CALL → GET ID + TOKEN
      if (i === 0) {
        prescription_id = row.prescription_id;
        // SP may return the FCM token under either alias; accept both.
        patientToken = row.token || row.fcm_token;
        // Doctor name is optional — used to personalise the "Appointment
        // Complete — review it" body. Falls back below if the SP doesn't
        // return it.
        doctorName = row.doctor_name || row.doctorName || null;
        log.debug('[insertPrescription] SP row keys: ' + Object.keys(row).join(', '));
        log.debug('[insertPrescription] patientToken: ' + (patientToken ? '[REDACTED]' : 'null'));

        if (!prescription_id) {
          return res.status(500).json({
            success: false,
            message: 'Failed to create prescription'
          });
        }
      }
    }

    saved = true;

    // sp_prescription doesn't always echo the patient's FCM token. Fallback is a
    // direct read from patients.token (same column populated by sp_doctor_login's
    // 'saveFirebaseToken' op for role='patient', and used in the reverse lookup
    // at the top of this file).
    if (!patientToken) {
      try {
        const tokenLookup = await db.request()
          .input('patient_id', patient_id)
          .query('SELECT TOP 1 token FROM patients WHERE patient_id = @patient_id');
        patientToken = tokenLookup.recordset?.[0]?.token || null;
        log.debug('[insertPrescription] token fetched via patients fallback: ' + (patientToken ? '[REDACTED]' : 'null'));
      } catch (lookupErr) {
        log.error('[insertPrescription] token lookup failed: ' + lookupErr.message);
      }
    }

    // 🔔 SEND TWO NOTIFICATIONS — completing a consultation triggers both:
    //   1) "Appointment Complete — review it"  → opens the review dialog
    //   2) "Prescription Assigned — tap to view" → opens the prescription
    // The review one fires only when we have an appointment_id to attach
    // to (the dialog needs it). Both share the cached patientToken so we
    // don't double-lookup.
    const drLabel = doctorName ? `Dr. ${doctorName}` : 'the doctor';

    if (appointment_id) {
      const reviewTitle = 'Appointment Complete';
      const reviewBody =
        `Your appointment with ${drLabel} is complete. Tap to leave a review.`;

      await insertNotification(
        patient_id, reviewTitle, reviewBody, 'rating', appointment_id,
      );

      if (patientToken) {
        try {
          await admin.messaging().send({
            token: patientToken,
            notification: { title: reviewTitle, body: reviewBody },
            // appointment_id lets the frontend look up the row and pop the
            // review dialog with doctor/patient context already populated.
            data: {
              type: 'rating',
              appointment_id: String(appointment_id),
            },
          });
        } catch (err) {
          log.error('[insertPrescription] review FCM FAILED: ' + (err.code || '') + ' ' + err.message);
        }
      }
    } else {
      log.warn('[insertPrescription] appointment_id missing — review notification skipped');
    }

    const presTitle = 'Prescription Assigned';
    const presBody = 'Doctor has assigned prescription to you. Please review it.';

    // Inbox row first — patient_id is already known here, no token lookup needed.
    await insertNotification(patient_id, presTitle, presBody, 'prescription', prescription_id);

    if (patientToken) {
      try {
        const fcmResp = await admin.messaging().send({
          token: patientToken,
          notification: { title: presTitle, body: presBody },
          data: {
            type: 'prescription',
            prescription_id: String(prescription_id),
          },
        });
        log.info('[insertPrescription] FCM send OK: ' + fcmResp);
      } catch (err) {
        log.error('[insertPrescription] FCM send FAILED: ' + (err.code || '') + ' ' + err.message);
      }
    } else {
      log.warn('[insertPrescription] no patientToken — push skipped (inbox row saved)');
    }

    return res.status(200).json({
      success: true,
      prescription_id,
      message: 'Prescription created successfully'
    });

  } catch (err) {
    log.error('Error in /insertPrescription: ' + err.message);
    await undoPartial();
    return res.status(500).json({
      success: false,
      message: err.message
    });
  }
});

// WhatsApp the patient their prescription (doctor) or follow-up reminder
// (doctor or reception). The number comes from the patient record, never the
// client; ownStaff has already checked the appointment is this doctor's.
const fmtDate = (d) => new Date(d).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric', timeZone: 'UTC' });
const fmtTime = (hhmm) => {
  const [h, m] = String(hhmm).split(':').map(Number);
  return `${String(h % 12 || 12).padStart(2, '0')}:${String(m).padStart(2, '0')} ${h < 12 ? 'AM' : 'PM'}`;
};

router.post('/sendWhatsApp', whatsappLimiter, async (req, res) => {
  const appointmentId = parseInt(req.body.appointment_id);
  const { kind } = req.body;
  if (!(appointmentId > 0) || !['prescription', 'followup'].includes(kind)) {
    return res.status(400).json({ success: false, message: "appointment_id and kind ('prescription' | 'followup') are required" });
  }
  if (kind === 'prescription' && Number(req.user.role_id) !== ROLE.DOCTOR) {
    return res.status(403).json({ success: false, message: 'Only the doctor can send the prescription' });
  }

  try {
    const { recordset: rows } = await db.request()
      .input('appointment_id', sql.Int, appointmentId)
      .query(`SELECT v.patient_name, v.doctor_name, v.clinic_name, v.clinic_contact,
                     v.follow_up_date, v.follow_up_time, v.advice,
                     v.medicine_name, v.frequency, v.duration,
                     CASE WHEN v.user_type = 1 THEN pt.mobile_no
                          ELSE COALESCE(NULLIF(fm.mobile_no, ''), head.mobile_no) END AS mobile
              FROM dbo.prescription_vw v
              LEFT JOIN dbo.Patients pt ON v.user_type = 1 AND pt.patient_id = v.patient_id
              LEFT JOIN dbo.family_members fm ON v.user_type = 2 AND fm.member_id = v.patient_id
              LEFT JOIN dbo.Patients head ON head.patient_id = fm.family_id
              WHERE v.appointment_id = @appointment_id
              ORDER BY v.presc_med_id`);
    const rx = rows[0];
    if (!rx) return res.status(404).json({ success: false, message: 'No prescription for this appointment yet' });

    const mobile = indianMobile(rx.mobile);
    if (!mobile) return res.status(400).json({ success: false, message: 'Patient has no valid mobile number' });

    const followUp = rx.follow_up_date
      ? `${fmtDate(rx.follow_up_date)}${rx.follow_up_time ? ` at ${fmtTime(rx.follow_up_time)}` : ''}`
      : null;
    if (kind === 'followup' && !followUp) {
      return res.status(400).json({ success: false, message: 'No follow-up date set on this prescription' });
    }

    const doctor = `Dr. ${rx.doctor_name}`;
    const contact = rx.clinic_contact || '-';
    if (kind === 'prescription') {
      const meds = rows.filter((r) => r.medicine_name)
        .map((r) => [r.medicine_name, r.frequency, r.duration && `× ${r.duration}`].filter(Boolean).join(' '))
        .join('; ') || 'No medicines';
      await sendWhatsAppTemplate(mobile, process.env.WHATSAPP_RX_TEMPLATE_ID,
        [rx.patient_name, doctor, rx.clinic_name, meds, followUp || 'Not required', contact]);
    } else {
      await sendWhatsAppTemplate(mobile, process.env.WHATSAPP_FOLLOWUP_TEMPLATE_ID,
        [rx.patient_name, doctor, rx.clinic_name, followUp, contact]);
    }

    log.info(`[sendWhatsApp] ${kind} sent for appointment ${appointmentId}`);
    return res.json({ success: true, message: 'Sent on WhatsApp' });
  } catch (err) {
    log.error('Error in /sendWhatsApp: ' + err.message);
    return res.status(500).json({ success: false, message: err.message });
  }
});

module.exports = router;
