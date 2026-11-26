// /login — OTP: send and verify (verify hands out the short-lived loginTicket).
// Moved verbatim from routes/auth.js (Wave 6); helpers live in ./shared.js.
const express = require('express');
const router = express.Router();
const {
	jwt,
	crypto,
	db,
	bcrypt,
	axios,
	log,
	otpSql,
	LOGIN_TICKET_TTL,
	otpSendLimiter,
	otpVerifyLimiter,
	normalizeMobile,
} = require('./shared');

router.post('/send-otp', otpSendLimiter, async (req, res) => {
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

		// Dev fallback while the WhatsApp provider is down: OTP_TO_CONSOLE=1 in
		// .env prints the code in the server terminal instead of sending it.
		// Never in production — anyone reading the logs could sign in as anyone.
		const otpToConsole = process.env.OTP_TO_CONSOLE === '1' && process.env.NODE_ENV !== 'production';

		if (!otpToConsole && !process.env.WHATSAPP_API_TOKEN) {
			return res.status(500).json({
				status: 0,
				message: 'WhatsApp API token not configured'
			});
		}

		// ✅ Generate OTP
		const otp = crypto.randomInt(100000, 1000000).toString();

		// ✅ Send WhatsApp OTP (or print it, see otpToConsole)
		const waResponse = otpToConsole
			? (console.log(`\n[OTP] ${normalized} → ${otp}\n`), { data: { IsSuccess: true } })
			: await axios.post(
				"https://api2.smsala.com/whatsapp/SendOtp",
				{
					PhoneNumber: mobile_no_cc,
					OtpCode: otp,
					ApiToken: process.env.WHATSAPP_API_TOKEN,
					TemplateId: 463
				}
			);

		if (!waResponse.data || waResponse.data.IsSuccess !== true) {
			log.error('send-otp: WhatsApp provider refused: ' + JSON.stringify(waResponse.data).slice(0, 500));
			return res.status(400).json({
				status: 0,
				message: 'Failed to send OTP via WhatsApp'
			});
		}

		// ✅ Hash OTP
		const otp_hash = await bcrypt.hash(otp, 10);

		// ✅ Save in DB using normalized local number
		const dbResult = await db.request()
			.input('operation', 'send_otp')
			.input('mobile_no', normalized)
			.input('otp_hash', otp_hash)
			.run(otpSql);

		if (dbResult.recordset[0].status === 0) {
			return res.status(400).json(dbResult.recordset[0]);
		}

		// Never echo the code: with it in the response anyone could sign in as
		// any mobile number (the app does not read it). Demo numbers cover testing.
		res.json({
			status: 1,
			message: 'OTP sent successfully'
		});

	} catch (err) {
		res.status(500).json({
			status: 0,
			message: 'Server error',
			error: err?.response?.data || err.message
		});
	}
});
router.post('/verify-otp', otpVerifyLimiter, async (req, res) => {
	const body = req.body || {};
	// Same key /send-otp stored the code under, however the number is typed.
	const mobile_no = normalizeMobile(body.mobile_no ?? body.mobileNo ?? body.mobile);
	const otp = String(body.otp ?? '').trim();
	if (!/^[6-9]\d{9}$/.test(mobile_no) || !/^\d{6}$/.test(otp)) {
		return res.status(400).json({ status: 0, message: 'Mobile number and 6-digit OTP required' });
	}

	try {
		const result = await db.request()
			.input('operation', 'verify_otp')
			.input('mobile_no', mobile_no)
			.run(otpSql);

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
				.run(otpSql);

			return res.status(400).json({
				status: 0,
				message: 'Invalid OTP'
			});
		}

		// mark verified
		await db.request()
			.input('operation', 'mark_verified')
			.input('mobile_no', mobile_no)
			.run(otpSql);

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
		log.error('verify-otp error: ' + err.message);
		res.status(500).json({ error: 'Server error' });
	}
});

module.exports = router;
