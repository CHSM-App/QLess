import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLogin();
  }

  Future<void> _checkLogin() async {
    await ref.read(tokenProvider.notifier).loadTokens();
    final tokenState = ref.read(tokenProvider);
    if (!mounted) return;
    if (tokenState.isLoggedIn) {
      if (tokenState.roleId == 1) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorBottomNav()),
        );
      } else if (tokenState.roleId == 2) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PatientBottomNav(onToggleTheme: () {  }, themeMode: ThemeMode.light,)),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SplashScreen()),
        );
      }
    }
  }

  void _goDoctor() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(role: 'doctor')),
      );

  void _goPatient() => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(role: 'patient')),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: OrientationBuilder(
          builder: (context, orientation) {
            return orientation == Orientation.landscape
                ? _LandscapeLayout(
                    onDoctorTap: _goDoctor,
                    onPatientTap: _goPatient,
                  )
                : _PortraitLayout(
                    onDoctorTap: _goDoctor,
                    onPatientTap: _goPatient,
                  );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE LAYOUT
// Left panel: dark branding  |  Right panel: white action buttons
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  final VoidCallback onDoctorTap;
  final VoidCallback onPatientTap;

  const _LandscapeLayout({
    required this.onDoctorTap,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── LEFT PANEL ────────────────────────────────────────────────────
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
                      painter: _LogoIconPainter(),
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

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Connecting doctors and\npatients seamlessly',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12.5,
                      color: Color(0xFF94A3B8),
                      height: 1.5,
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Get Started',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),

                const SizedBox(height: 6),

                const Text(
                  'Choose how you want to continue',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF64748B),
                  ),
                ),

                const SizedBox(height: 28),

                // Doctor button
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    onPressed: onDoctorTap,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(20, 20),
                          painter:
                              _ButtonStethoPainter(color: Colors.white),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue as Doctor',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // Patient button
                SizedBox(
                  height: 50,
                  child: OutlinedButton(
                    onPressed: onPatientTap,
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFFD1D5DB),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CustomPaint(
                          size: const Size(20, 20),
                          painter: _ButtonPersonPainter(
                              color: const Color(0xFF0F172A)),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Continue as Patient',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                const Text(
                  'By continuing, you agree to our Terms & Privacy Policy',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Color(0xFF9CA3AF),
                    height: 1.5,
                  ),
                ),
              ],
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
  final VoidCallback onDoctorTap;
  final VoidCallback onPatientTap;

  const _PortraitLayout({
    required this.onDoctorTap,
    required this.onPatientTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Spacer(flex: 5),

          // Logo circle
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: CustomPaint(
                size: const Size(42, 42),
                painter: _LogoIconPainter(),
              ),
            ),
          ),

          const SizedBox(height: 22),

          const Text(
            'HealthConnect',
            style: TextStyle(
              fontSize: 27,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.2,
            ),
          ),

          const SizedBox(height: 9),

          const Text(
            'Connecting doctors and patients seamlessly',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13.5,
              color: Color(0xFF64748B),
              height: 1.45,
            ),
          ),

          const SizedBox(height: 44),

          // Doctor button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: onDoctorTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(22, 22),
                    painter: _ButtonStethoPainter(color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue as Doctor',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Patient button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: OutlinedButton(
              onPressed: onPatientTap,
              style: OutlinedButton.styleFrom(
                backgroundColor: Colors.white,
                side: const BorderSide(
                  color: Color(0xFFD1D5DB),
                  width: 1.5,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CustomPaint(
                    size: const Size(22, 22),
                    painter: _ButtonPersonPainter(
                        color: const Color(0xFF0F172A)),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Continue as Patient',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const Spacer(flex: 4),

          const Text(
            'By continuing, you agree to our Terms & Privacy Policy',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),

          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS
// ─────────────────────────────────────────────────────────────────────────────

class _LogoIconPainter extends CustomPainter {
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

    // tube down to chest piece
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

class _ButtonStethoPainter extends CustomPainter {
  final Color color;
  const _ButtonStethoPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    // dots
    canvas.drawCircle(Offset(w * 0.28, h * 0.10), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.72, h * 0.10), w * 0.055, fill);

    // tubes
    final p = Path();
    p.moveTo(w * 0.28, h * 0.15);
    p.lineTo(w * 0.28, h * 0.30);
    p.moveTo(w * 0.72, h * 0.15);
    p.lineTo(w * 0.72, h * 0.30);
    canvas.drawPath(p, stroke);

    // U bend
    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, h * 0.24, w * 0.44, h * 0.26),
      3.14159,
      -3.14159,
      false,
      stroke,
    );

    // down tube
    final d = Path();
    d.moveTo(w * 0.50, h * 0.50);
    d.cubicTo(w * 0.50, h * 0.63, w * 0.68, h * 0.61, w * 0.68, h * 0.75);
    canvas.drawPath(d, stroke);

    // chest piece
    canvas.drawCircle(Offset(w * 0.68, h * 0.83), w * 0.09, fill);
  }

  @override
  bool shouldRepaint(_) => false;
}

class _ButtonPersonPainter extends CustomPainter {
  final Color color;
  const _ButtonPersonPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    // main person head
    canvas.drawCircle(Offset(w * 0.42, h * 0.28), w * 0.13, fill);

    // main person body
    final body = Path();
    body.moveTo(w * 0.10, h * 0.92);
    body.quadraticBezierTo(w * 0.42, h * 0.58, w * 0.74, h * 0.92);
    canvas.drawPath(body, stroke..strokeWidth = 2.0);

    // second person head
    canvas.drawCircle(Offset(w * 0.74, h * 0.30), w * 0.10, fill);

    // second person body
    final body2 = Path();
    body2.moveTo(w * 0.54, h * 0.94);
    body2.quadraticBezierTo(w * 0.74, h * 0.62, w * 0.94, h * 0.94);
    canvas.drawPath(body2, stroke..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_) => false;
}