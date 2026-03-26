
import 'package:flutter/material.dart';
import 'package:qless/screens/doctor_login_screen.dart';

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
  backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(flex: 5),

              // ── LOGO CIRCLE ─────────────────────────────
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

              // ── TITLE ────────────────────────────────────
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

              // ── SUBTITLE ─────────────────────────────────
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

              // ── CONTINUE AS DOCTOR (filled black) ────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
              onPressed: () {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => const DoctorLoginScreen()),
  );
},
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
                      // stethoscope + person combined icon
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

              // ── CONTINUE AS PATIENT (white outlined) ─────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: OutlinedButton(
                  onPressed: () {
                    // Navigator.pushNamed(context, '/patient-login');
                  },
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
                      // person/group icon
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

              // ── FOOTER ───────────────────────────────────
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
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Logo circle: stethoscope + small person
// matches the screenshot icon exactly
// ─────────────────────────────────────────────
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

    // ── earpiece dots ────────────────────────
    canvas.drawCircle(Offset(w * 0.30, h * 0.09), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.70, h * 0.09), w * 0.055, fill);

    // ── ear tubes (angled outward) ───────────
    final tubePath = Path();
    // left ear tube going down-inward
    tubePath.moveTo(w * 0.30, h * 0.13);
    tubePath.lineTo(w * 0.30, h * 0.28);
    // right ear tube going down-inward
    tubePath.moveTo(w * 0.70, h * 0.13);
    tubePath.lineTo(w * 0.70, h * 0.28);
    canvas.drawPath(tubePath, stroke);

    // ── U-bend connecting both tubes ─────────
    final uRect = Rect.fromLTWH(w * 0.30, h * 0.22, w * 0.40, h * 0.26);
    canvas.drawArc(uRect, 3.14159, -3.14159, false, stroke);

    // ── tube going down-right to chest piece ─
    final downPath = Path();
    downPath.moveTo(w * 0.50, h * 0.48);
    downPath.cubicTo(
      w * 0.50, h * 0.60,
      w * 0.66, h * 0.58,
      w * 0.66, h * 0.72,
    );
    canvas.drawPath(downPath, stroke);

    // ── chest piece circle ───────────────────
    canvas.drawCircle(Offset(w * 0.66, h * 0.80), w * 0.09, fill);

    // ── small person silhouette (bottom-left) ─
    // head
    canvas.drawCircle(Offset(w * 0.26, h * 0.70), w * 0.075, fill);
    // body arc
    final bodyPath = Path();
    bodyPath.moveTo(w * 0.10, h * 0.96);
    bodyPath.quadraticBezierTo(
      w * 0.26, h * 0.82,
      w * 0.42, h * 0.96,
    );
    canvas.drawPath(bodyPath, stroke..strokeWidth = 1.8);
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────
// Button icon: small stethoscope (Doctor btn)
// ─────────────────────────────────────────────
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

// ─────────────────────────────────────────────
// Button icon: person/group (Patient btn)
// ─────────────────────────────────────────────
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

    // second person head (smaller, right)
    canvas.drawCircle(Offset(w * 0.74, h * 0.30), w * 0.10, fill);

    // second person body arc
    final body2 = Path();
    body2.moveTo(w * 0.54, h * 0.94);
    body2.quadraticBezierTo(w * 0.74, h * 0.62, w * 0.94, h * 0.94);
    canvas.drawPath(body2, stroke..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_) => false;
}