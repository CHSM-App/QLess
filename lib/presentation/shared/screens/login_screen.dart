import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/doctor/screens/doctor_registration.dart';
import 'package:qless/presentation/shared/screens/otp_screen.dart';
import 'package:qless/presentation/patient/screens/patient_registration.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

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
    if (isDoctor) {
      ref.read(doctorLoginViewModelProvider.notifier).checkPhoneNumber(mobile);
    } else {
      ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
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
    final isDoctor = this.isDoctor;
    bool isLoading = false;

    if (isDoctor) {
      final state = ref.watch(doctorLoginViewModelProvider);
      isLoading = state.phoneCheckResult is AsyncLoading;

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
    } else {
      final state = ref.watch(patientLoginViewModelProvider);
      isLoading = state.patientPhoneCheck is AsyncLoading;

      ref.listen<PatientLoginState>(patientLoginViewModelProvider,
          (prev, next) {
        if (!_shouldReact) return;
        next.patientPhoneCheck.whenOrNull(
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
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.landscape
                ? _LandscapeLayout(
                    isDoctor: isDoctor,
                    isLoading: isLoading,
                    mobileCtrl: _mobileCtrl,
                    onContinue: _onContinue,
                    onRegister: _goRegister,
                  )
                : _PortraitLayout(
                    isDoctor: isDoctor,
                    isLoading: isLoading,
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
// Left panel: dark branding  |  Right panel: white form
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
        // ── LEFT PANEL: dark branding ─────────────────────────────────────
        Expanded(
          flex: 5,
          child: Container(
            color: const Color(0xFF0F172A),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo circle
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.25),
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
                    isDoctor
                        ? 'Welcome back,\nDoctor'
                        : 'Welcome back,\nPatient',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Role badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.15),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    isDoctor ? '🩺 Doctor Portal' : '🏥 Patient Portal',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RIGHT PANEL: login form ───────────────────────────────────────
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
                      color: Color(0xFF0F172A),
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
                      color: Color(0xFF64748B),
                      height: 1.45,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Mobile number label
                  const Text(
                    'Mobile Number',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),

                  const SizedBox(height: 8),

                  // Mobile field
                  Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: TextField(
                      controller: mobileCtrl,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: const InputDecoration(
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
                        contentPadding: EdgeInsets.symmetric(vertical: 15),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Login button
                  SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F172A),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
                  ),

                  const SizedBox(height: 16),

                  // Register link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'New to HealthConnect? ',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFF64748B),
                        ),
                      ),
                      GestureDetector(
                        onTap: onRegister,
                        child: const Text(
                          'Register Now',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ),
                    ],
                  ),
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
// PORTRAIT LAYOUT  (original vertical layout — unchanged)
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
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 48),

              // Logo circle
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

              // Mobile number label
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mobile Number',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F172A),
                  ),
                ),
              ),

              const SizedBox(height: 8),

              // Mobile field
              Container(
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  controller: mobileCtrl,
                  keyboardType: TextInputType.phone,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF0F172A),
                  ),
                  decoration: const InputDecoration(
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

              // Login button
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isLoading ? null : onContinue,
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

              // Register link
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
                    onTap: onRegister,
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
    );
  }
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
      w * 0.50, h * 0.60,
      w * 0.66, h * 0.58,
      w * 0.66, h * 0.72,
    );
    canvas.drawPath(downPath, stroke);

    // chest piece circle
    canvas.drawCircle(Offset(w * 0.66, h * 0.80), w * 0.09, fill);

    // small person head
    canvas.drawCircle(Offset(w * 0.26, h * 0.70), w * 0.075, fill);

    // small person body arc
    final bodyPath = Path();
    bodyPath.moveTo(w * 0.10, h * 0.96);
    bodyPath.quadraticBezierTo(w * 0.26, h * 0.82, w * 0.42, h * 0.96);
    canvas.drawPath(bodyPath, stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_) => false;
}