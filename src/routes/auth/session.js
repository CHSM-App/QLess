// /login — Sessions: OTP login, token refresh, FCM token, logout.
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	auth,
	db,
	log,
	refreshTokensSql,
	doctorsSql,
	REFRESH_TOKEN_TTL_MS,
	ROLE,
	ROLE_NAME_BY_ID,
	resolveRoleId,
	authLimiter,
	normalizeMobile,
	otpProofError,
	createAccessToken,
	resolveAccountRole,
	createRefreshTokenPayload,
} = require('./shared');

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
		const proofError = otpProofError(normalizedMobile, { loginTicket, otp });
		if (proofError) return res.status(401).json({ error: proofError });

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
			.run(refreshTokensSql);

		const refreshToken = createRefreshTokenPayload(mobile);
		const expiresAt = new Date(Date.now() + REFRESH_TOKEN_TTL_MS);

		await db.request()
			.input('operation', 'insert')
			.input('user_mobile', mobile)
			.input('refresh_token', refreshToken)
			.input('device_info', deviceDetails)
			.input('expires_at', expiresAt)
			.input('role', roleName)
			.run(refreshTokensSql);

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
			.run(refreshTokensSql);

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
			.run(refreshTokensSql);

		// create new — same role as the stored session, re-resolving only the
		// account id so the token keeps carrying who this is.
		const account = await resolveAccountRole(normalizeMobile(mobile), ROLE_NAME_BY_ID[roleId]);
		// A doctor an admin blocked (or a removed receptionist) no longer resolves:
		// end the session here — the old refresh token is already revoked above.
		if ((roleId === ROLE.DOCTOR || roleId === ROLE.RECEPTIONIST) && !(account && account.roleId === roleId)) {
			return res.status(403).json({ code: 'DOCTOR_BLOCKED', error: 'Your account has been blocked. Please contact support.' });
		}
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

			.run(refreshTokensSql);



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


// The push token is stored against the *signed-in* account: mobile and role
// come from the access token, never from the body. Without that, anyone could
// register their own device for someone else's mobile and receive (and steal)
// that person's appointment, queue and prescription notifications.
router.post('/saveFirebaseToken', auth, async (req, res) => {
	log.debug('inside the saveFirebaseToken route');
	try {
		const { firebaseToken } = req.body;
		const mobile = req.user.mobile;
		const role = ROLE_NAME_BY_ID[Number(req.user.role_id)];

		if (!firebaseToken) {
			return res.status(400).json({ error: 'firebaseToken is required' });
		}
		if (!mobile || !role || role === 'admin') {
			return res.status(403).json({ error: 'This session cannot register a push token.' });
		}


		// Save firebase token via SP
		await db.request()
			.input('operation', 'saveFirebaseToken')
			.input('mobile', mobile)
			.input('token', firebaseToken)
			.input('role', role)
			.run(doctorsSql);

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
			.run(refreshTokensSql);

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

module.exports = router;
