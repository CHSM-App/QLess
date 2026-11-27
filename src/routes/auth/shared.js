// Shared by the /login routes (src/routes/auth/*): requires, settings and the
// OTP / token / profile-ownership helpers. Moved verbatim from routes/auth.js.
const jwt = require('jsonwebtoken');
require('dotenv').config();
const auth = require('../../middleware/auth');
const authorize = require('../../middleware/authorize');
const { ROLE, ROLE_ID_BY_NAME, ROLE_NAME_BY_ID, resolveRoleId } = require('../../middleware/roles');
const db = require('../../db');
const crypto = require('crypto');
const bcrypt = require('bcryptjs');
const axios = require('axios');
const path = require('path');
const fs = require("fs-extra");
const { authLimiter, lookupLimiter, otpSendLimiter, otpVerifyLimiter } = require('../../middleware/rateLimit');
const { upload, uploadHandler, verifyImageFiles, cleanupFiles } = require('../../middleware/upload');
const log = require('../../middleware/logger');
const receptionistsSql = require('../../queries/receptionists');
const patientsSql = require('../../queries/patients');
const refreshTokensSql = require('../../queries/refreshTokens');
const doctorsSql = require('../../queries/doctors');
const otpSql = require('../../queries/otp');
const UPLOADS_DIR = require('../../uploads');
const ownStaff = require('../../middleware/ownStaff');
const { isDemoMobile, demoOtp } = require('../../demo');

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

/** Digits only, last 10 — so "+91 98…", "098…" and "98…" compare equal. */
function normalizeMobile(value) {
	const digits = String(value || '').replace(/\D/g, '');
	return digits.length > 10 ? digits.slice(-10) : digits;
}

/**
 * Proof that the caller owns this mobile right now: the short-lived ticket
 * /verify-otp hands out, or — for store-review demo numbers only — the demo
 * OTP. Returns null when proven, otherwise the reason (used by login and by
 * registration, so a phone number alone never buys an account or a session).
 */
function otpProofError(mobile, { loginTicket, otp } = {}) {
	const normalizedMobile = normalizeMobile(mobile);
	if (isDemoMobile(normalizedMobile)) {
		return String(otp || '') === demoOtp() ? null : 'Invalid OTP';
	}
	if (!loginTicket) return 'OTP verification required';
	try {
		const ticket = jwt.verify(loginTicket, process.env.JWT_SECRET_KEY, { algorithms: ['HS256'] });
		if (ticket.purpose !== 'login' || normalizeMobile(ticket.mobile) !== normalizedMobile) {
			return 'OTP verification required';
		}
		return null;
	} catch (err) {
		log.error('bad login ticket for ' + normalizedMobile + ' (' + err.message + ')');
		return 'OTP verification expired. Please try again.';
	}
}

/**
 * Registration (Insert) and a profile Update that changes the mobile number
 * must come with OTP proof for that number. Until the app version that sends
 * it is out (flag env var = 'true'), a missing proof is only logged.
 * Returns false after answering 401 itself.
 */
async function checkOtpProof(req, res, mobile, flag, what) {
	const proofError = otpProofError(mobile, req.body || {});
	if (!proofError) return true;
	if (process.env[flag] === 'true') {
		await cleanupFiles(req).catch(() => { });
		res.status(401).json({ error: proofError });
		return false;
	}
	log.warn(`${what} without OTP proof (${proofError}) for ${normalizeMobile(mobile)} — allowed until ${flag}=true`);
	return true;
}

function checkSignupProof(req, res, mobile) {
	return checkOtpProof(req, res, mobile, 'SIGNUP_REQUIRES_OTP', 'registration');
}

// Call after requireOwnProfile (req.user is set). No mobile in the body, or
// the signed-in number itself, needs no proof.
function checkMobileChangeProof(req, res, mobile) {
	if (!mobile || normalizeMobile(mobile) === normalizeMobile(req.user.mobile)) return true;
	return checkOtpProof(req, res, mobile, 'MOBILE_CHANGE_REQUIRES_OTP', 'mobile change');
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
			// doctor_mobile_exist also returns receptionist mobiles (doctor_id
			// NULL) for the "mobile exists" screen — only a real doctor_id counts,
			// or a receptionist posting role "doctor" got a doctor session.
			const result = await db.request()
				.input('operation', 'doctor_mobile_exist')
				.input('mobile', mobile)
				.run(doctorsSql);
			const row = (result.recordset || []).find((r) => idOf(r, 'doctor_id', 'id'));
			return row ? { roleId: ROLE.DOCTOR, uid: idOf(row, 'doctor_id', 'id') } : null;
		},
		[ROLE.PATIENT]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'patient_mobile_exist')
				.input('mobile_no', mobile)
				.run(patientsSql));
			return row ? { roleId: ROLE.PATIENT, uid: idOf(row, 'patient_id', 'id') } : null;
		},
		[ROLE.RECEPTIONIST]: async () => {
			const row = firstRow(await db.request()
				.input('operation', 'check_phone_receptionist')
				.input('mobile_no', mobile)
				.run(receptionistsSql));
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

/**
 * Profile *updates* need the owner's own token. Registration stays open (a
 * new user has no token yet); editing must not — otherwise anyone could POST
 * an existing patient_id / doctor_id and rewrite that profile, mobile number
 * included, then sign in to it by OTP. A token without uid is refused too.
 * Answers 401/403 itself (and drops uploaded temp files); returns false then.
 */
async function requireOwnProfile(req, res, roleId, id) {
	let authenticated = false;
	auth(req, res, () => { authenticated = true; }); // synchronous: calls next() or answers 401
	if (authenticated && Number(req.user.role_id) === roleId && Number(req.user.uid) > 0
		&& Number(req.user.uid) === Number(id)) return true;
	await cleanupFiles(req).catch(() => { });
	if (authenticated) res.status(403).json({ error: 'You can only update your own profile.' });
	return false;
}

function createRefreshTokenPayload(mobile) {
	const token = generateRefreshToken();
	return token;
}

module.exports = {
	jwt,
	auth,
	authorize,
	db,
	crypto,
	bcrypt,
	axios,
	path,
	fs,
	log,
	receptionistsSql,
	patientsSql,
	refreshTokensSql,
	doctorsSql,
	otpSql,
	UPLOADS_DIR,
	ownStaff,
	PUBLIC_BASE_URL,
	REFRESH_TOKEN_TTL_DAYS,
	REFRESH_TOKEN_TTL_MS,
	LOGIN_TICKET_TTL,
	ROLE,
	ROLE_ID_BY_NAME,
	ROLE_NAME_BY_ID,
	resolveRoleId,
	authLimiter,
	lookupLimiter,
	otpSendLimiter,
	otpVerifyLimiter,
	upload,
	uploadHandler,
	verifyImageFiles,
	cleanupFiles,
	isDemoMobile,
	demoOtp,
	normalizeMobile,
	otpProofError,
	checkOtpProof,
	checkSignupProof,
	checkMobileChangeProof,
	generateRefreshToken,
	createAccessToken,
	resolveAccountRole,
	requireOwnProfile,
	createRefreshTokenPayload,
};
