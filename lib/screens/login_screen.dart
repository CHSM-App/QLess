import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/providers/viewModel_provider.dart';
import 'package:qless/presentation/viewModels/doctor_login_viewmodel.dart';
import 'package:qless/screens/doctor_registration.dart';
import 'package:qless/screens/otp_screen.dart';
import 'package:qless/screens/patient_registration.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({
    super.key,
    this.role = 'doctor',
  });

  final String role;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool get isDoctor => widget.role == 'doctor';
  final _mobileCtrl = TextEditingController();
  bool _shouldReact = false;

  @override
  void dispose() {
    _mobileCtrl.dispose();
    super.dispose();
  }

  void _onContinue() {
    final mobile = _mobileCtrl.text.trim();
    if (mobile.length != 10 || !RegExp(r'^[0-9]+$').hasMatch(mobile)) {
      _snack('Enter a valid 10-digit mobile number');
      return;
    }
    _shouldReact = true;
    ref.read(doctorLoginViewModelProvider.notifier).checkPhoneNumber(mobile);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorLoginViewModelProvider);

    ref.listen<DoctorLoginState>(doctorLoginViewModelProvider, (prev, next) {
      if (!_shouldReact) return;
      next.phoneCheckResult.whenOrNull(
        data: (list) {
          _shouldReact = false;
          if (list.isNotEmpty) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => OtpVerificationScreen(
                  mobileNumber: _mobileCtrl.text.trim(),
                  role: widget.role,
                ),
              ),
            );
          } else {
            _snack('User not found');
          }
        },
        error: (e, _) {
          _shouldReact = false;
          _snack('Something went wrong. Try again.');
        },
      );
    });

    final isLoading = state.phoneCheckResult is AsyncLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 48),

                  // ── LOGO CIRCLE ─────────────────────────────
                  Container(
                    width: 72,
                    height: 72,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0F172A),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: CustomPaint(
                        size: const Size(36, 36),
                        painter: _StethoscopeIconPainter(),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  // ── TITLE ────────────────────────────────────
                  const Text(
                    'Login',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                      letterSpacing: -0.2,
                    ),
                  ),

                  const SizedBox(height: 8),

                  // ── SUBTITLE ─────────────────────────────────
                  Text(
                    isDoctor
                        ? 'Welcome back! Please login as doctor to continue'
                        : 'Welcome back! Please login as patient to continue',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── mobile FIELD ───────────────────────────────
                  Align(
                    alignment: Alignment.centerLeft,
                    child: const Text(
                      'Mobile Number',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: _mobileCtrl,
                      keyboardType: TextInputType.phone,
                      style: TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
                      decoration: InputDecoration(
                        hintText: 'Enter mobile number',
                        hintStyle: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 14,
                        ),
                        prefixIcon: Icon(
                          Icons.phone,
                          color: Color(0xFF94A3B8),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── LOGIN BUTTON ──────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
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
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── REGISTER LINK ─────────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New to HealthConnect? ',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => isDoctor
                                  ? const DoctorProfileSetupScreen()
                                  : const PatientRegistrationScreen(),
                            ),
                          );
                        },
                        child: const Text(
                          'Register Now',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Stethoscope icon for logo circle
// ─────────────────────────────────────────────
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

    // earpiece dots
    canvas.drawCircle(Offset(w * 0.30, h * 0.09), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.70, h * 0.09), w * 0.055, fill);

    // ear tubes
    final tubePath = Path();
    tubePath.moveTo(w * 0.30, h * 0.13);
    tubePath.lineTo(w * 0.30, h * 0.28);
    tubePath.moveTo(w * 0.70, h * 0.13);
    tubePath.lineTo(w * 0.70, h * 0.28);
    canvas.drawPath(tubePath, stroke);

    // U-bend
    final uRect = Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.40, h * 0.26);
    canvas.drawArc(uRect, 3.14159, -3.14159, false, stroke);

    // tube going down to chest piece
    final downPath = Path();
    downPath.moveTo(w * 0.50, h * 0.48);
    downPath.cubicTo(
      w * 0.50,
      h * 0.60,
      w * 0.66,
      h * 0.58,
      w * 0.66,
      h * 0.72,
    );
    canvas.drawPath(downPath, stroke);

    // chest piece circle
    canvas.drawCircle(Offset(w * 0.66, h * 0.80), w * 0.09, fill);

    // small person silhouette (bottom-left)
    canvas.drawCircle(Offset(w * 0.26, h * 0.70), w * 0.075, fill);
    final bodyPath = Path();
    bodyPath.moveTo(w * 0.10, h * 0.96);
    bodyPath.quadraticBezierTo(w * 0.26, h * 0.82, w * 0.42, h * 0.96);
    canvas.drawPath(bodyPath, stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_) => false;
}
