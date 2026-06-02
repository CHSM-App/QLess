// Demo / review accounts (already seeded in SQL Server).
//
// Reviewers (Play Store review, internal QA) sign in with these numbers using
// the fixed OTP below — no SMS is sent and the verify-OTP API is skipped. Every
// other number (real users) falls through to the normal send-OTP / verify-OTP
// flow untouched.
//
//   • Demo doctors : 9876000001 – 9876000030   (doctor_login #1–#30)
//   • Demo patients: 9878000001 – 9878000050   (Patients     #1–#50)
//
// A numeric range — NOT a prefix — because real accounts share the prefix
// (e.g. 9876000031/32 and 9878000051 are genuine users, not demo). The OTP is a
// client-side constant; it is never stored or sent.
const String kDemoOtp = '123456';

bool isDemoNumber(String mobile) {
  final n = int.tryParse(mobile);
  if (n == null) return false;
  const doctorStart = 9876000001;
  const doctorEnd = 9876000030;
  const patientStart = 9878000001;
  const patientEnd = 9878000050;
  return (n >= doctorStart && n <= doctorEnd) ||
      (n >= patientStart && n <= patientEnd);
}

/// The fixed demo OTP for a demo number, or `null` for real users.
String? demoOtpFor(String mobile) => isDemoNumber(mobile) ? kDemoOtp : null;
