import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_registration.dart';
import 'package:qless/presentation/patient/screens/patient_registration.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/shared/screens/otp_screen.dart';

// ── Colour Palette ─────────────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF1EA898);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple      = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo      = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.role = 'doctor'});

  final String role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool get isDoctor => widget.role == 'doctor';
  final _mobileCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  Future<void> _onContinue() async {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final List result;
      if (isDoctor) {
        result = await ref
            .read(doctorLoginViewModelProvider.notifier)
            .mobileExistDoctor(mobile);
      } else {
        result = await ref
            .read(patientLoginViewModelProvider.notifier)
            .mobileExistPatient(mobile);
      }

      if (!mounted) return;

      if (result.isEmpty) {
        _snack('User not found');
        return;
      }

      if (isDoctor) {
        final doctor = result.first as DoctorDetails;
        final isNotVerified = (doctor.isverified) == 1;
        if (isNotVerified) {
          _showStatusDialog(
            icon: Icons.hourglass_top_rounded,
            iconColor: kWarning,
            iconBg: kAmberLight,
            title: 'Under Verification',
            message:
                'Your account is currently being reviewed by our team. '
                'You will be notified once verification is complete.',
            buttonLabel: 'OK, Got it',
          );
          return;
        }
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mobileNumber: mobile,
            role: widget.role,
          ),
        ),
      );
    } catch (_) {
      if (mounted) _snack('Something went wrong. Try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  bool _intToBool(dynamic doctor, String key) {
    if (doctor is Map) return (doctor[key] ?? 0) == 1;
    if (key == 'doc_is_verified') return (doctor.isVerified ?? 0) == 1;
    if (key == 'doc_active_status') return (doctor.activeStatus ?? 0) == 1;
    return false;
  }

  void _showStatusDialog({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String message,
    required String buttonLabel,
  }) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                child: Icon(icon, color: iconColor, size: 30),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 22),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _goRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => isDoctor
            ? const DoctorProfileSetupScreen()
            : const PatientRegistrationScreen(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.landscape
                ? _LandscapeLayout(
                    isDoctor: isDoctor,
                    isLoading: _isLoading,
                    mobileCtrl: _mobileCtrl,
                    onContinue: _onContinue,
                    onRegister: _goRegister,
                  )
                : _PortraitLayout(
                    isDoctor: isDoctor,
                    isLoading: _isLoading,
                    mobileCtrl: _mobileCtrl,
                    onContinue: _onContinue,
                    onRegister: _goRegister,
                  );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  final bool isDoctor;
  final bool isLoading;
  final TextEditingController mobileCtrl;
  final VoidCallback onContinue;
  final VoidCallback onRegister;

  const _LandscapeLayout({
    required this.isDoctor,
    required this.isLoading,
    required this.mobileCtrl,
    required this.onContinue,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── LEFT PANEL ────────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Container(
            color: kPrimary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(36, 36),
                      painter: _StethoscopeIconPainter(),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  'HealthConnect',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    isDoctor ? 'Welcome back,\nDoctor' : 'Welcome back,\nPatient',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Colors.white70,
                      height: 1.5,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.30),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isDoctor ? '🩺 Doctor Portal' : '🏥 Patient Portal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RIGHT PANEL ───────────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isDoctor
                        ? 'Please login as doctor to continue'
                        : 'Please login as patient to continue',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: kTextSecondary,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MobileField(controller: mobileCtrl, height: 50),
                  const SizedBox(height: 18),
                  _LoginButton(
                    isLoading: isLoading,
                    onPressed: onContinue,
                    height: 50,
                  ),
                  const SizedBox(height: 16),
                  _RegisterLink(onTap: onRegister, fontSize: 12.5),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTRAIT LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _PortraitLayout extends StatelessWidget {
  final bool isDoctor;
  final bool isLoading;
  final TextEditingController mobileCtrl;
  final VoidCallback onContinue;
  final VoidCallback onRegister;

  const _PortraitLayout({
    required this.isDoctor,
    required this.isLoading,
    required this.mobileCtrl,
    required this.onContinue,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // ── TEAL HEADER ───────────────────────────────────────────────────
        Container(
          width: double.infinity,
          color: kPrimary,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.only(
                  top: 44,
                  bottom: 52,
                  left: 30,
                  right: 30,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Center(
                        child: CustomPaint(
                          size: const Size(36, 36),
                          painter: _StethoscopeIconPainter(),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'HealthConnect',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isDoctor
                          ? 'Welcome back! Please login as doctor'
                          : 'Welcome back! Please login as patient',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.white70,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              // Curved white bottom
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  height: 28,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(28),
                      topRight: Radius.circular(28),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── WHITE BODY ────────────────────────────────────────────────────
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(30, 24, 30, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _MobileField(controller: mobileCtrl, height: 52),
                  const SizedBox(height: 18),
                  _LoginButton(
                    isLoading: isLoading,
                    onPressed: onContinue,
                    height: 54,
                  ),
                  const SizedBox(height: 20),
                  _RegisterLink(onTap: onRegister, fontSize: 13),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _MobileField extends StatelessWidget {
  final TextEditingController controller;
  final double height;
  const _MobileField({required this.controller, required this.height});

  @override
  Widget build(BuildContext context) => Container(
        height: height,
        decoration: BoxDecoration(
          color: kBorder,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDivider, width: 1),
        ),
        child: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10),
          ],
          style: const TextStyle(fontSize: 14, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'Enter mobile number',
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
            prefixIcon: const Icon(Icons.phone_outlined, color: kTextMuted, size: 20),
            counterText: '',
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
          ),
        ),
      );
}

class _LoginButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  final double height;
  const _LoginButton({
    required this.isLoading,
    required this.onPressed,
    required this.height,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        height: height,
        child: ElevatedButton(
          onPressed: isLoading ? null : onPressed,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kPrimaryLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: Colors.white,
                  ),
                )
              : const Text(
                  'Login',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
        ),
      );
}

class _RegisterLink extends StatelessWidget {
  final VoidCallback onTap;
  final double fontSize;
  const _RegisterLink({required this.onTap, required this.fontSize});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'New to HealthConnect? ',
            style: TextStyle(fontSize: fontSize, color: kTextSecondary),
          ),
          GestureDetector(
            onTap: onTap,
            child: Text(
              'Register Now',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: kPrimary,
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _StethoscopeIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(Offset(w * 0.30, h * 0.09), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.70, h * 0.09), w * 0.055, fill);

    final tubePath = Path();
    tubePath.moveTo(w * 0.30, h * 0.13);
    tubePath.lineTo(w * 0.30, h * 0.28);
    tubePath.moveTo(w * 0.70, h * 0.13);
    tubePath.lineTo(w * 0.70, h * 0.28);
    canvas.drawPath(tubePath, stroke);

    final uRect = Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.40, h * 0.26);
    canvas.drawArc(uRect, 3.14159, -3.14159, false, stroke);

    final downPath = Path();
    downPath.moveTo(w * 0.50, h * 0.48);
    downPath.cubicTo(w * 0.50, h * 0.60, w * 0.66, h * 0.58, w * 0.66, h * 0.72);
    canvas.drawPath(downPath, stroke);

    canvas.drawCircle(Offset(w * 0.66, h * 0.80), w * 0.09, fill);
    canvas.drawCircle(Offset(w * 0.26, h * 0.70), w * 0.075, fill);

    final bodyPath = Path();
    bodyPath.moveTo(w * 0.10, h * 0.96);
    bodyPath.quadraticBezierTo(w * 0.26, h * 0.82, w * 0.42, h * 0.96);
    canvas.drawPath(bodyPath, stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_) => false;
}