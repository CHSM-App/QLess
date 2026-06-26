'use strict';

/**
 * Account deletion endpoints — called by the public landing page form.
 * No JWT required. Identity is proven via WhatsApp OTP (reuses /login/send-otp
 * and /login/verify-otp flow already in place).
 *
 * Flow:
 *   1. POST /delete-account/request
 *        • Accepts { phone, role_id }
 *        • Sends WhatsApp OTP via existing /login/send-otp logic
 *        • Always returns 200 (no user enumeration)
 *
 *   2. POST /delete-account/confirm
 *        • Accepts { phone, role_id, otp, reason? }
 *        • Verifies OTP via existing sp_otp / bcrypt flow
 *        • Upserts AccountDeletionRequests row
 *          (scheduled_for = now + 30 days, status = 'pending')
 *        • Returns scheduled_for date
 *
 *   3. POST /delete-account/cancel
 *        • Accepts { phone, role_id, otp }
 *        • Verifies fresh OTP
 *        • Marks pending request as cancelled
 */

const express = require('express');
const bcrypt  = require('bcryptjs');
const axios   = require('axios');
const db      = require('./db');
const log     = require('./middleware/logger');
const { deletionLimiter } = require('./middleware/rateLimit');

const router = express.Router();

const DELETION_DELAY_DAYS = 30;

const VALID_ROLE_IDS = [1, 2, 3]; // 1=Doctor, 2=Patient, 3=Receptionist

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────

function normalizePhone(raw) {
  if (!raw) return null;
  let n = raw.toString().trim().replace(/\D/g, '');
  if (n.startsWith('91') && n.length > 10) n = n.slice(n.length - 10);
  if (n.startsWith('0')) n = n.replace(/^0+/, '');
  return /^[6-9]\d{9}$/.test(n) ? n : null;
}

async function sendWhatsAppOtp(phone) {
  const otp = Math.floor(100000 + Math.random() * 900000).toString();

  if (!process.env.WHATSAPP_API_TOKEN) {
    throw new Error('WhatsApp API token not configured');
  }

  const waRes = await axios.post('https://api2.smsala.com/whatsapp/SendOtp', {
    PhoneNumber: `91${phone}`,
    OtpCode: otp,
    ApiToken: process.env.WHATSAPP_API_TOKEN,
    TemplateId: 463,
  });

  if (!waRes.data || waRes.data.IsSuccess !== true) {
    throw new Error('Failed to send OTP via WhatsApp');
  }

  const otp_hash = await bcrypt.hash(otp, 10);

  const dbResult = await db.request()
    .input('operation', 'send_otp')
    .input('mobile_no', phone)
    .input('otp_hash', otp_hash)
    .execute('sp_otp');

  if (dbResult.recordset[0].status === 0) {
    throw new Error(dbResult.recordset[0].message || 'Failed to save OTP');
  }

  // Return otp in non-production for dev convenience (mirrors /login/send-otp)
  return process.env.NODE_ENV !== 'production' ? otp : null;
}

async function verifyOtp(phone, otp) {
  const result = await db.request()
    .input('operation', 'verify_otp')
    .input('mobile_no', phone)
    .execute('sp_otp');

  const data = result.recordset[0];
  if (!data || data.status === 0) return false;

  const isMatch = await bcrypt.compare(otp, data.otp_hash);
  if (!isMatch) {
    await db.request()
      .input('operation', 'update_attempt')
      .input('mobile_no', phone)
      .execute('sp_otp');
    return false;
  }

  await db.request()
    .input('operation', 'mark_verified')
    .input('mobile_no', phone)
    .execute('sp_otp');

  return true;
}

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/request
// Sends a WhatsApp OTP to the given phone. Always 200 — prevents enumeration.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/request', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }

  try {
    const devOtp = await sendWhatsAppOtp(phone);
    log.info(`[DELETE-ACCOUNT] OTP sent phone=${phone} role_id=${roleId}`);
    return res.json({
      success: true,
      message: 'If an account exists for this number, an OTP has been sent via WhatsApp.',
      ...(devOtp ? { dev_otp: devOtp } : {}),
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] request error: ' + err.message);
    // Return 200 even on OTP send failure — no enumeration
    return res.json({
      success: true,
      message: 'If an account exists for this number, an OTP has been sent via WhatsApp.',
    });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/confirm
// Verifies OTP and schedules the account for deletion in 30 days.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/confirm', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);
  const otp    = (req.body.otp || '').toString().trim();
  const reason = req.body.reason || null;

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }
  if (!/^\d{6}$/.test(otp)) {
    return res.status(400).json({ success: false, message: 'OTP must be a 6-digit number.' });
  }

  try {
    const otpValid = await verifyOtp(phone, otp);
    if (!otpValid) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }

    const now          = new Date();
    const scheduledFor = new Date(now.getTime() + DELETION_DELAY_DAYS * 24 * 60 * 60 * 1000);

    // Check for existing pending request
    const existing = await db.request()
      .input('phone',   phone)
      .input('role_id', roleId)
      .query(`
        SELECT id, scheduled_for
        FROM AccountDeletionRequests
        WHERE phone = @phone AND role_id = @role_id AND status = 'pending'
      `);

    if (existing.recordset.length > 0) {
      return res.status(409).json({
        success: false,
        message: 'A deletion request already exists for this account.',
        scheduled_for: existing.recordset[0].scheduled_for,
      });
    }

    await db.request()
      .input('phone',           phone)
      .input('role_id',         roleId)
      .input('reason',          reason ? reason.toString().slice(0, 500) : null)
      .input('otp_verified_at', now)
      .input('scheduled_for',   scheduledFor)
      .query(`
        INSERT INTO AccountDeletionRequests
          (phone, role_id, reason, otp_verified_at, scheduled_for, status)
        VALUES
          (@phone, @role_id, @reason, @otp_verified_at, @scheduled_for, 'pending')
      `);

    log.info(`[DELETE-ACCOUNT] request created phone=${phone} role_id=${roleId} scheduled_for=${scheduledFor.toISOString()}`);

    return res.json({
      success: true,
      message: `Your account is scheduled for deletion on ${scheduledFor.toDateString()}. You can cancel before that date.`,
      scheduled_for: scheduledFor,
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] confirm error: ' + err.message);
    return res.status(500).json({ success: false, message: 'Server error. Please try again.' });
  }
});

// ─────────────────────────────────────────────────────────────────────────────
// POST /delete-account/cancel
// Cancels a pending deletion request after verifying a fresh OTP.
// ─────────────────────────────────────────────────────────────────────────────

router.post('/cancel', deletionLimiter, async (req, res) => {
  const phone  = normalizePhone(req.body.phone);
  const roleId = parseInt(req.body.role_id);
  const otp    = (req.body.otp || '').toString().trim();

  if (!phone) {
    return res.status(400).json({ success: false, message: 'Invalid phone number.' });
  }
  if (!VALID_ROLE_IDS.includes(roleId)) {
    return res.status(400).json({ success: false, message: 'Invalid role_id.' });
  }
  if (!/^\d{6}$/.test(otp)) {
    return res.status(400).json({ success: false, message: 'OTP must be a 6-digit number.' });
  }

  try {
    const otpValid = await verifyOtp(phone, otp);
    if (!otpValid) {
      return res.status(400).json({ success: false, message: 'Invalid or expired OTP.' });
    }

    const requestResult = await db.request()
      .input('phone',   phone)
      .input('role_id', roleId)
      .query(`
        SELECT id FROM AccountDeletionRequests
        WHERE phone = @phone AND role_id = @role_id AND status = 'pending'
      `);

    if (requestResult.recordset.length === 0) {
      return res.status(404).json({ success: false, message: 'No pending deletion request found for this account.' });
    }

    const requestId = requestResult.recordset[0].id;

    await db.request()
      .input('id', requestId)
      .query(`UPDATE AccountDeletionRequests SET status = 'cancelled' WHERE id = @id`);

    log.info(`[DELETE-ACCOUNT] request cancelled phone=${phone} role_id=${roleId} id=${requestId}`);

    return res.json({
      success: true,
      message: 'Your account deletion request has been cancelled. Your account is safe.',
    });
  } catch (err) {
    log.error('[DELETE-ACCOUNT] cancel error: ' + err.message);
    return res.status(500).json({ success: false, message: 'Server error. Please try again.' });
  }
});

module.exports = router;
