import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';

class QlessSplashScreen extends ConsumerStatefulWidget {
  final Widget nextScreen;
  const QlessSplashScreen({super.key, required this.nextScreen});

  @override
  ConsumerState<QlessSplashScreen> createState() => _QlessSplashScreenState();
}

class _QlessSplashScreenState extends ConsumerState<QlessSplashScreen>
    with TickerProviderStateMixin {
  List<int> _activeIds = [];
  final Set<int> _leavingIds = {};
  final Set<int> _enteringIds = {};
  int _nextId = 0;
  static const int _queueSize = 4;

  Timer? _queueTimer;
  Timer? _tipTimer;
  Timer? _navTimer;

  late AnimationController _walkController;
  late AnimationController _logoController;
  late AnimationController _tipController;
  late Animation<double> _logoFade;
  late Animation<double> _logoSlide;
  late Animation<double> _tipFade;

  int _tipIndex = 0;
  static const List<String> _tips = [
    'Stay hydrated — drink 8 glasses of water daily 💧',
    'A 10-minute walk can boost your mood instantly 🚶',
    'Quality sleep is the body\'s best medicine 🌙',
    'Your next doctor is just a tap away 🩺',
    'Early check-ups prevent bigger problems later 📋',
    'Breathe deeply — reduce stress in 60 seconds 🌿',
    'Skip the wait, not the care ✨',
  ];

  @override
  void initState() {
    super.initState();

    for (int i = 0; i < _queueSize; i++) {
      _activeIds.add(_nextId++);
    }

    _walkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    )..repeat(reverse: true);

    _logoController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _logoFade = CurvedAnimation(parent: _logoController, curve: Curves.easeOut);
    _logoSlide = Tween<double>(begin: 22, end: 0).animate(
      CurvedAnimation(parent: _logoController, curve: Curves.easeOutCubic),
    );
    _logoController.forward();

    _tipController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _tipFade = CurvedAnimation(parent: _tipController, curve: Curves.easeInOut);
    _tipController.forward();

    _queueTimer = Timer.periodic(
      const Duration(milliseconds: 2000),
      (_) => _advanceQueue(),
    );

    _tipTimer = Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (!mounted) return;
      _tipController.reverse().then((_) {
        if (!mounted) return;
        setState(() => _tipIndex = (_tipIndex + 1) % _tips.length);
        _tipController.forward();
      });
    });

    _navTimer = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      checkLogin();
    });
  }

  Future<void> checkLogin() async {
    await ref.read(tokenProvider.notifier).loadTokens();
    final tokenState = ref.read(tokenProvider);

    if (tokenState.isLoggedIn) {
      if (tokenState.roleId == 1) {
        await ref.read(doctorLoginViewModelProvider.notifier).loadFromStorage();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DoctorBottomNav()),
        );
      } else if (tokenState.roleId == 2) {
        await ref
            .read(patientLoginViewModelProvider.notifier)
            .loadFromStoragePatient();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PatientBottomNav(
              onToggleTheme: () {},
              themeMode: ThemeMode.light,
            ),
          ),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ContinueAsScreen()),
        );
      }
    } else {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const ContinueAsScreen()),
      );
    }
  }

  void _advanceQueue() {
    if (!mounted) return;
    setState(() {
      final leaverId = _activeIds.removeAt(0);
      _leavingIds.add(leaverId);

      final newId = _nextId++;
      _activeIds.add(newId);
      _enteringIds.add(newId);

      Future.delayed(const Duration(milliseconds: 80), () {
        if (mounted) setState(() => _enteringIds.remove(newId));
      });

      Future.delayed(const Duration(milliseconds: 700), () {
        if (mounted) setState(() => _leavingIds.remove(leaverId));
      });
    });
  }

  @override
  void dispose() {
    _walkController.dispose();
    _logoController.dispose();
    _tipController.dispose();
    _queueTimer?.cancel();
    _tipTimer?.cancel();
    _navTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenW = MediaQuery.of(context).size.width;

    // Queue geometry — persons closer together
    const double personW = 28.0;
    const double personSpacing = 38.0; // tighter spacing
    final double totalQueueW = personSpacing * (_queueSize - 1) + personW;
    final double queueLeft = (screenW - totalQueueW) / 2 + 10;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 3),

            // ── LOGO ────────────────────────────────────────────
            AnimatedBuilder(
              animation: _logoController,
              builder: (_, __) => Opacity(
                opacity: _logoFade.value,
                child: Transform.translate(
                  offset: Offset(0, _logoSlide.value),
                  child: const _Logo(),
                ),
              ),
            ),

            const Spacer(flex: 2),

            // ── QUEUE SCENE ──────────────────────────────────────
            SizedBox(
              height: 100,
              width: double.infinity,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // ── LEAVING persons (slide left + fade out) ───
                  ..._leavingIds.map((id) {
                    // slide to just left of leftmost slot
                    final targetLeft = queueLeft - personW - 16;
                    return AnimatedPositioned(
                      key: ValueKey('p_$id'),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeIn,
                      bottom: 0,
                      left: targetLeft,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 400),
                        opacity: 0.0,
                        child: _Person(
                          walkAnim: _walkController,
                          colorIndex: id % 4,
                        ),
                      ),
                    );
                  }),

                  // ── ACTIVE persons (shift left smoothly) ──────
                  ..._activeIds.asMap().entries.map((e) {
                    final slot = e.key;
                    final id = e.value;
                    final isEntering = _enteringIds.contains(id);
                    final left = queueLeft + slot * personSpacing;

                    return AnimatedPositioned(
                      key: ValueKey('p_$id'),
                      duration: const Duration(milliseconds: 700),
                      curve: Curves.easeInOut,
                      bottom: 0,
                      left: left,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 350),
                        opacity: isEntering ? 0.0 : 1.0,
                        child: _Person(
                          walkAnim: _walkController,
                          colorIndex: id % 4,
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            const Spacer(flex: 2),

            // ── HEALTH TIP ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 44),
              child: FadeTransition(
                opacity: _tipFade,
                child: Text(
                  _tips[_tipIndex],
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: Color(0xFF64748B),
                    height: 1.6,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 18),

            // ── DOT INDICATORS ───────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(_tips.length, (i) {
                final active = i == _tipIndex;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: active ? 20 : 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: active
                        ? const Color(0xFF0F172A)
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),

            const Spacer(flex: 3),

            const Padding(
              padding: EdgeInsets.only(bottom: 28),
              child: Text(
                'Connecting patients & doctors',
                style: TextStyle(
                  fontSize: 11,
                  color: Color(0xFFCBD5E1),
                  letterSpacing: 0.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOGO
// ─────────────────────────────────────────────────────────────────────────────
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: const BoxDecoration(
            color: Color(0xFF0F172A),
            shape: BoxShape.circle,
          ),
          child: const Center(
            child: Text(
              'Q',
              style: TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -1,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Qless',
          style: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: Color(0xFF0F172A),
            letterSpacing: -1.2,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Skip the wait. Not the care.',
          style: TextStyle(
            fontSize: 13,
            color: Color(0xFF94A3B8),
            letterSpacing: 0.1,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PERSON
// ─────────────────────────────────────────────────────────────────────────────
class _Person extends StatelessWidget {
  final Animation<double> walkAnim;
  final int colorIndex;

  const _Person({required this.walkAnim, required this.colorIndex});

  // All slate/grey tones — no black tints
  static const _shades = [
    Color(0xFF94A3B8), // slate-400
    Color(0xFF64748B), // slate-500
    Color(0xFF7C8FA6), // between
    Color(0xFF8899B0), // softer mid
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: walkAnim,
      builder: (_, __) => SizedBox(
        width: 28,
        height: 72,
        child: CustomPaint(
          painter: _PersonPainter(
            t: walkAnim.value,
            color: _shades[colorIndex],
          ),
        ),
      ),
    );
  }
}

class _PersonPainter extends CustomPainter {
  final double t;
  final Color color;

  const _PersonPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final bob = (t < 0.5 ? t : 1.0 - t) * 2 * 1.4;

    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final thick = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    // Head
    const headR = 7.0;
    final headY = headR + 1.5 - bob * 0.4;
    canvas.drawCircle(Offset(cx, headY), headR, fill);

    // Torso
    final shoulderY = headY + headR + 2.0;
    final hipY = shoulderY + 18 - bob * 0.3;
    final torsoW = 12.0;
    final torsoRect = Rect.fromLTWH(
      cx - torsoW / 2,
      shoulderY,
      torsoW,
      hipY - shoulderY,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(torsoRect, const Radius.circular(4)),
      fill,
    );

    // Arms
    final armRootY = shoulderY + 3;
    final shoulderX = 6.0;
    final elbowDrop = 5.0;
    final handDrop = 12.0;

    final leftShoulder = Offset(cx - shoulderX, armRootY);
    final rightShoulder = Offset(cx + shoulderX, armRootY);
    final leftElbow = Offset(cx - shoulderX - 2, armRootY + elbowDrop);
    final rightElbow = Offset(cx + shoulderX + 2, armRootY + elbowDrop);
    final leftHand = Offset(cx - shoulderX - 1, armRootY + handDrop);
    final rightHand = Offset(cx + shoulderX + 1, armRootY + handDrop);

    thick.strokeWidth = 2.6;
    canvas.drawPath(
      Path()
        ..moveTo(leftShoulder.dx, leftShoulder.dy)
        ..lineTo(leftElbow.dx, leftElbow.dy)
        ..lineTo(leftHand.dx, leftHand.dy),
      thick,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rightShoulder.dx, rightShoulder.dy)
        ..lineTo(rightElbow.dx, rightElbow.dy)
        ..lineTo(rightHand.dx, rightHand.dy),
      thick,
    );

    // Legs
    final legTop = hipY;
    const legLen = 22.0;
    final hipSpread = 4.0;
    final kneeDrop = 10.0;
    final footOut = 4.0;

    final leftHip = Offset(cx - hipSpread, legTop);
    final rightHip = Offset(cx + hipSpread, legTop);
    final leftKnee = Offset(cx - hipSpread - 2, legTop + kneeDrop);
    final rightKnee = Offset(cx + hipSpread + 2, legTop + kneeDrop);
    final leftFoot = Offset(cx - hipSpread - footOut, legTop + legLen);
    final rightFoot = Offset(cx + hipSpread + footOut, legTop + legLen);

    thick.strokeWidth = 3.0;
    canvas.drawPath(
      Path()
        ..moveTo(leftHip.dx, leftHip.dy)
        ..lineTo(leftKnee.dx, leftKnee.dy)
        ..lineTo(leftFoot.dx, leftFoot.dy),
      thick,
    );
    canvas.drawPath(
      Path()
        ..moveTo(rightHip.dx, rightHip.dy)
        ..lineTo(rightKnee.dx, rightKnee.dy)
        ..lineTo(rightFoot.dx, rightFoot.dy),
      thick,
    );

    // Feet (small line to ground)
    canvas.drawLine(
      Offset(leftFoot.dx - 2, leftFoot.dy),
      Offset(leftFoot.dx + 4, leftFoot.dy),
      thick..strokeWidth = 2.2,
    );
    canvas.drawLine(
      Offset(rightFoot.dx - 4, rightFoot.dy),
      Offset(rightFoot.dx + 2, rightFoot.dy),
      thick..strokeWidth = 2.2,
    );
  }

  @override
  bool shouldRepaint(_PersonPainter old) => old.t != t;
}
