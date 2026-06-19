import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';

// ── Colour Palette ─────────────────────────────────────────────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF1EA898);
const kPrimaryDarker = Color(0xFF158578);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryGlow   = Color(0xFF4DD9C4);

const kBgSoft       = Color(0xFFF7FAFC);
const kSurface      = Color(0xFFFFFFFF);

const kTextPrimary   = Color(0xFF1A202C);
const kTextSecondary = Color(0xFF4A5568);
const kTextMuted     = Color(0xFF94A3B8);

const kBorder        = Color(0xFFF1F5F9);
const kBorderStrong  = Color(0xFFE2E8F0);
const kDivider       = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kSuccess    = Color(0xFF68D391);
const kWarning    = Color(0xFFF6AD55);
const kPurple      = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo      = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

class ContinueAsScreen extends ConsumerStatefulWidget {
  const ContinueAsScreen({super.key});

  @override
  ConsumerState<ContinueAsScreen> createState() => _ContinueAsScreenState();
}

class _ContinueAsScreenState extends ConsumerState<ContinueAsScreen>
    with TickerProviderStateMixin {
  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));
    _entryController.forward();
  }

  @override
  void dispose() {
    _entryController.dispose();
    super.dispose();
  }

  void _onRoleTap(String role) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => LoginScreen(role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: OrientationBuilder(
              builder: (context, orientation) {
                return orientation == Orientation.landscape
                    ? _LandscapeLayout(onRoleTap: _onRoleTap)
                    : _PortraitLayout(onRoleTap: _onRoleTap);
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PORTRAIT LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _PortraitLayout extends StatelessWidget {
  final ValueChanged<String> onRoleTap;

  const _PortraitLayout({required this.onRoleTap});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = constraints.maxHeight;
        final isSmall = screenH < 700;
        final isVerySmall = screenH < 600;

        final heroBottomPad = isVerySmall ? 44.0 : (isSmall ? 52.0 : 64.0);
        final titleSize = isVerySmall ? 22.0 : (isSmall ? 26.0 : 30.0);
        final logoSize = isVerySmall ? 56.0 : (isSmall ? 68.0 : 80.0);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // ── HERO ────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                constraints: BoxConstraints(
                  minHeight: screenH * (isVerySmall ? 0.34 : 0.40),
                ),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [kPrimaryGlow, kPrimary, kPrimaryDark],
                            stops: [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: -50,
                      right: -40,
                      child: _Blob(size: isSmall ? 130 : 160, opacity: 0.18),
                    ),
                    Positioned(
                      top: 40,
                      left: -30,
                      child: _Blob(size: isSmall ? 90 : 110, opacity: 0.12),
                    ),
                    const Positioned.fill(child: _DotPattern()),

                    SafeArea(
                      bottom: false,
                      child: SizedBox(
                      width: double.infinity,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(28, 28, 28, heroBottomPad),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            _BrandLogo(size: logoSize),
                            SizedBox(height: isVerySmall ? 14 : 20),
                            Text(
                              'HealthConnect',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.6,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Connecting doctors and patients seamlessly',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: isVerySmall ? 12 : 13.5,
                                color: Colors.white.withOpacity(0.88),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    ),

                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 36,
                        decoration: const BoxDecoration(
                          color: kSurface,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(32),
                            topRight: Radius.circular(32),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // ── BODY ────────────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: kSurface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Section header
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 24,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [kPrimary, kPrimaryDark],
                              ),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Text(
                            'Get Started',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Padding(
                        padding: EdgeInsets.only(left: 16),
                        child: Text(
                          'Choose how you want to continue',
                          style: TextStyle(
                            fontSize: 13.5,
                            color: kTextSecondary,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 22),

                      // Role cards
                      _RoleCard(
                        role: 'doctor',
                        title: 'Continue as Doctor & Receptionist',
                        subtitle: 'Manage appointments & patients',
                        chips: const ['Practice tools', 'Verified'],
                        icon: _RoleCardIcon.doctor,
                        accentColor: kPrimary,
                        accentBg: kPrimaryLight,
                        onTap: () => onRoleTap('doctor'),
                      ),
                      const SizedBox(height: 14),
                      _RoleCard(
                        role: 'patient',
                        title: 'Continue as Patient',
                        subtitle: 'Book & track appointments',
                        chips: const ['Quick care', '24/7 access'],
                        icon: _RoleCardIcon.patient,
                        accentColor: kInfo,
                        accentBg: kInfoLight,
                        onTap: () => onRoleTap('patient'),
                      ),

                      const SizedBox(height: 24),

                      // Legal text
                      const _LegalText(),

                      const SizedBox(height: 12),

                      // Secure footer
                      const _SecureFooter(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  final ValueChanged<String> onRoleTap;

  const _LandscapeLayout({required this.onRoleTap});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── LEFT BRAND PANEL ──────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [kPrimaryGlow, kPrimary, kPrimaryDarker],
                    stops: [0.0, 0.5, 1.0],
                  ),
                ),
              ),
              Positioned(top: -60, right: -60, child: _Blob(size: 220, opacity: 0.15)),
              Positioned(bottom: -80, left: -50, child: _Blob(size: 260, opacity: 0.12)),
              const Positioned.fill(child: _DotPattern()),

              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _BrandLogo(size: 88),
                        const SizedBox(height: 22),
                        const Text(
                          'HealthConnect',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            'Connecting doctors and patients seamlessly across one platform.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withOpacity(0.88),
                              height: 1.6,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        // Feature pills
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            _FeaturePill(icon: Icons.shield_outlined, label: 'Secure'),
                            _FeaturePill(icon: Icons.bolt_outlined, label: 'Fast'),
                            _FeaturePill(icon: Icons.verified_outlined, label: 'Trusted'),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // ── RIGHT PANEL: ROLE PICKER ──────────────────────────────────────
        Expanded(
          flex: 6,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 460),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 4,
                              height: 28,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [kPrimary, kPrimaryDark],
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Get Started',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                                color: kTextPrimary,
                                letterSpacing: -0.5,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 16),
                          child: Text(
                            'Choose how you want to continue',
                            style: TextStyle(
                              fontSize: 13.5,
                              color: kTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        _RoleCard(
                          role: 'doctor',
                          title: 'Continue as Doctor',
                          subtitle: 'Manage appointments & patients',
                          chips: const ['Practice tools', 'Verified'],
                          icon: _RoleCardIcon.doctor,
                          accentColor: kPrimary,
                          accentBg: kPrimaryLight,
                          onTap: () => onRoleTap('doctor'),
                        ),
                        const SizedBox(height: 14),
                        _RoleCard(
                          role: 'patient',
                          title: 'Continue as Patient',
                          subtitle: 'Book & track appointments',
                          chips: const ['Quick care', '24/7 access'],
                          icon: _RoleCardIcon.patient,
                          accentColor: kInfo,
                          accentBg: kInfoLight,
                          onTap: () => onRoleTap('patient'),
                        ),
                        const SizedBox(height: 26),
                        const _LegalText(),
                        const SizedBox(height: 12),
                        const _SecureFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ROLE CARD — premium selectable card
// ─────────────────────────────────────────────────────────────────────────────
enum _RoleCardIcon { doctor, patient }

class _RoleCard extends StatelessWidget {
  final String role;
  final String title;
  final String subtitle;
  final List<String> chips;
  final _RoleCardIcon icon;
  final Color accentColor;
  final Color accentBg;
  final VoidCallback onTap;

  const _RoleCard({
    required this.role,
    required this.title,
    required this.subtitle,
    required this.chips,
    required this.icon,
    required this.accentColor,
    required this.accentBg,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorderStrong, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          focusColor: Colors.transparent,
          hoverColor: Colors.transparent,
          overlayColor: WidgetStateProperty.all(Colors.transparent),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Icon
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: accentBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: CustomPaint(
                      size: const Size(28, 28),
                      painter: icon == _RoleCardIcon.doctor
                          ? _ButtonStethoPainter(color: accentColor)
                          : _ButtonPersonPainter(color: accentColor),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Text
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 12,
                          color: kTextSecondary,
                          height: 1.35,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: chips
                            .map((c) => _MiniChip(label: c, color: accentColor))
                            .toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Tap indicator
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: accentBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    color: accentColor,
                    size: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final String label;
  final Color color;
  const _MiniChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.18), width: 0.8),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: color,
            letterSpacing: 0.1,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED SMALL WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _LegalText extends StatelessWidget {
  const _LegalText();

  @override
  Widget build(BuildContext context) => RichText(
        textAlign: TextAlign.center,
        text: const TextSpan(
          style: TextStyle(
            fontSize: 12,
            color: kTextMuted,
            height: 1.55,
          ),
          children: [
            TextSpan(text: 'By continuing, you agree to our '),
            TextSpan(
              text: 'Terms of Service',
              style: TextStyle(
                color: kPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(text: ' and '),
            TextSpan(
              text: 'Privacy Policy',
              style: TextStyle(
                color: kPrimaryDark,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: kTextMuted),
          SizedBox(width: 6),
          Text(
            'Protected by end-to-end encryption',
            style: TextStyle(
              fontSize: 12,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withOpacity(0.25),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                fontSize: 11,
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      );
}

class _BrandLogo extends StatelessWidget {
  final double size;
  const _BrandLogo({required this.size});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.18),
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withOpacity(0.4),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.white.withOpacity(0.2),
              blurRadius: 20,
              spreadRadius: -4,
            ),
          ],
        ),
        child: Center(
          child: CustomPaint(
            size: Size(size * 0.5, size * 0.5),
            painter: _LogoIconPainter(),
          ),
        ),
      );
}

class _Blob extends StatelessWidget {
  final double size;
  final double opacity;
  const _Blob({required this.size, required this.opacity});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              Colors.white.withOpacity(opacity),
              Colors.white.withOpacity(0),
            ],
          ),
        ),
      );
}

class _DotPattern extends StatelessWidget {
  const _DotPattern();

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DotPatternPainter());
}

class _DotPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withOpacity(0.08);
    const spacing = 22.0;
    const radius = 1.1;
    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
// PAINTERS (preserved from original)
// ─────────────────────────────────────────────────────────────────────────────
class _LogoIconPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
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

    canvas.drawCircle(Offset(w * 0.28, h * 0.10), w * 0.055, fill);
    canvas.drawCircle(Offset(w * 0.72, h * 0.10), w * 0.055, fill);

    final p = Path();
    p.moveTo(w * 0.28, h * 0.15);
    p.lineTo(w * 0.28, h * 0.30);
    p.moveTo(w * 0.72, h * 0.15);
    p.lineTo(w * 0.72, h * 0.30);
    canvas.drawPath(p, stroke);

    canvas.drawArc(
      Rect.fromLTWH(w * 0.28, h * 0.24, w * 0.44, h * 0.26),
      3.14159,
      -3.14159,
      false,
      stroke,
    );

    final d = Path();
    d.moveTo(w * 0.50, h * 0.50);
    d.cubicTo(w * 0.50, h * 0.63, w * 0.68, h * 0.61, w * 0.68, h * 0.75);
    canvas.drawPath(d, stroke);

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

    canvas.drawCircle(Offset(w * 0.42, h * 0.28), w * 0.13, fill);

    final body = Path();
    body.moveTo(w * 0.10, h * 0.92);
    body.quadraticBezierTo(w * 0.42, h * 0.58, w * 0.74, h * 0.92);
    canvas.drawPath(body, stroke..strokeWidth = 2.0);

    canvas.drawCircle(Offset(w * 0.74, h * 0.30), w * 0.10, fill);

    final body2 = Path();
    body2.moveTo(w * 0.54, h * 0.94);
    body2.quadraticBezierTo(w * 0.74, h * 0.62, w * 0.94, h * 0.94);
    canvas.drawPath(body2, stroke..strokeWidth = 1.6);
  }

  @override
  bool shouldRepaint(_) => false;
}