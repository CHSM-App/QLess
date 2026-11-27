// Store-review / QA demo accounts (mirror frontend/lib/core/demo_accounts.dart).
// They sign in with DEMO_OTP instead of a WhatsApp code, so they are OFF unless
// DEMO_ENABLED=true — some of these numbers may well belong to real people.
// In production the server refuses to start with demo on and the default OTP.
const RANGES = [
  [9000000001, 9000000001], // Dr. Manoj Swant (doctor)
  [9876000001, 9876000030], // doctors
  [9877000001, 9877000030], // receptionists
  [9878000001, 9878000050], // patients
];
const DEFAULT_OTP = '123456';

const demoEnabled = () => process.env.DEMO_ENABLED === 'true';
const demoOtp = () => process.env.DEMO_OTP || DEFAULT_OTP;

/** True for a demo number (any format: "+91 98…", "098…") while demo is enabled. */
function isDemoMobile(mobile) {
  if (!demoEnabled()) return false;
  const n = Number(String(mobile || '').replace(/\D/g, '').slice(-10));
  return n > 0 && RANGES.some(([from, to]) => n >= from && n <= to);
}

module.exports = { isDemoMobile, demoOtp, demoEnabled, DEFAULT_OTP };
