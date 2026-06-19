import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/demo_accounts.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_registration.dart';
import 'package:qless/presentation/patient/screens/patient_registration.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/shared/screens/otp_screen.dart';
import 'package:qless/domain/models/receptionist_model.dart';

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

class _LoginScreenState extends ConsumerState<LoginScreen>
    with TickerProviderStateMixin {
  bool get isDoctor => widget.role == 'doctor';
  final _mobileCtrl = TextEditingController();
  final _focusNode = FocusNode();
  bool _isLoading = false;
  bool _isFocused = false;

  late AnimationController _entryController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      setState(() => _isFocused = _focusNode.hasFocus);
    });

    _entryController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _fadeAnim = CurvedAnimation(parent: _entryController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _entryController, curve: Curves.easeOutCubic));

    _entryController.forward();
  }

  @override
  void dispose() {
    _mobileCtrl.dispose();
    _focusNode.dispose();
    _entryController.dispose();
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
      if (isDoctor) {
        // First check if mobile belongs to a doctor
        final doctorResult = await ref
            .read(doctorLoginViewModelProvider.notifier)
            .mobileExistDoctor(mobile);

        if (!mounted) return;

        if (doctorResult.isEmpty) {
          // Not a doctor — check if it's a receptionist
          final receptionistResult = await ref
              .read(receptionistLoginViewModelProvider.notifier)
              .mobileExistReceptionist(mobile);

          if (!mounted) return;

          if (receptionistResult.isEmpty) {
            _snack('User not found');
            return;
          }
          // Receptionist found — proceed to OTP (role stays 'doctor' so
          // otp_screen detects receptionist automatically via mobileExistReceptionist)
        } else {
          // Doctor found — run verification check
          if (!isDemoNumber(mobile)) {
            final doctor = doctorResult.first;
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
        }
      } else {
        final patientResult = await ref
            .read(patientLoginViewModelProvider.notifier)
            .mobileExistPatient(mobile);

        if (!mounted) return;

        if (patientResult.isEmpty) {
          _snack('User not found');
          return;
        }
      }

      // Real users get a server-generated OTP via SMS.
      if (!isDemoNumber(mobile)) {
        final otpRes = await ref
            .read(doctorLoginViewModelProvider.notifier)
            .sendOtp(OtpResponse(mobileNo: mobile));
        if (!mounted) return;
        if ((otpRes.status ?? 0) != 1) {
          _snack((otpRes.message?.isNotEmpty ?? false)
              ? otpRes.message!
              : 'Unable to send OTP. Please try again.');
          return;
        }
        _snack('OTP sent successfully');
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mobileNumber: mobile,
            role: widget.role,
            demoOtp: demoOtpFor(mobile),
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
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (_) => Dialog(
        backgroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 32, 28, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    colors: [iconBg, iconBg.withOpacity(0.4)],
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withOpacity(0.18),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(icon, color: iconColor, size: 34),
              ),
              const SizedBox(height: 22),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: kTextSecondary,
                  height: 1.55,
                ),
              ),
              const SizedBox(height: 26),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: Text(
                    buttonLabel,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.2,
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
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: kTextPrimary,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
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
                    ? _LandscapeLayout(
                        isDoctor: isDoctor,
                        isLoading: _isLoading,
                        mobileCtrl: _mobileCtrl,
                        focusNode: _focusNode,
                        isFocused: _isFocused,
                        onContinue: _onContinue,
                        onRegister: _goRegister,
                      )
                    : _PortraitLayout(
                        isDoctor: isDoctor,
                        isLoading: _isLoading,
                        mobileCtrl: _mobileCtrl,
                        focusNode: _focusNode,
                        isFocused: _isFocused,
                        onContinue: _onContinue,
                        onRegister: _goRegister,
                      );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE LAYOUT — Split panel, premium look
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  final bool isDoctor;
  final bool isLoading;
  final TextEditingController mobileCtrl;
  final FocusNode focusNode;
  final bool isFocused;
  final VoidCallback onContinue;
  final VoidCallback onRegister;

  const _LandscapeLayout({
    required this.isDoctor,
    required this.isLoading,
    required this.mobileCtrl,
    required this.focusNode,
    required this.isFocused,
    required this.onContinue,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // ── LEFT BRAND PANEL ──────────────────────────────────────────────
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              // Gradient background
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
              // Decorative blobs
              Positioned(
                top: -60,
                right: -60,
                child: _Blob(size: 220, opacity: 0.15),
              ),
              Positioned(
                bottom: -80,
                left: -50,
                child: _Blob(size: 260, opacity: 0.12),
              ),
              // Dotted pattern overlay
              const Positioned.fill(child: _DotPattern()),
              // Content
              SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _BrandLogo(size: 84),
                        const SizedBox(height: 22),
                        const Text(
                          'HealthConnect',
                          style: TextStyle(
                            fontSize: 29,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(30),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.35),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isDoctor
                                    ? Icons.medical_services_outlined
                                    : Icons.favorite_border_rounded,
                                color: Colors.white,
                                size: 13,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                isDoctor ? 'Doctor & Receptionist Portal' : 'Patient Portal',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 28),
                        Container(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Text(
                            isDoctor
                                ? 'Manage your practice and connect with patients seamlessly.'
                                : 'Quality healthcare is just a tap away. Welcome back.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13.5,
                              color: Colors.white.withOpacity(0.88),
                              height: 1.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Feature pills
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: isDoctor
                              ? const [
                                  _FeaturePill(icon: Icons.shield_outlined, label: 'Verified'),
                                  _FeaturePill(icon: Icons.bolt_outlined, label: 'Fast Access'),
                                  _FeaturePill(icon: Icons.lock_outline, label: 'Secure'),
                                ]
                              : const [
                                  _FeaturePill(icon: Icons.event_available_outlined, label: '24/7 Booking'),
                                  _FeaturePill(icon: Icons.bolt_outlined, label: 'Quick Care'),
                                  _FeaturePill(icon: Icons.lock_outline, label: 'Private'),
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

        // ── RIGHT FORM PANEL ──────────────────────────────────────────────
        Expanded(
          flex: 6,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
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
                              'Welcome Back',
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
                        Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: Text(
                            isDoctor
                                ? 'Sign in to access your doctor dashboard'
                                : 'Sign in to manage your appointments',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: kTextSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        const _FieldLabel(text: 'Mobile Number'),
                        const SizedBox(height: 10),
                        _MobileField(
                          controller: mobileCtrl,
                          focusNode: focusNode,
                          isFocused: isFocused,
                          height: 56,
                        ),
                        const SizedBox(height: 8),
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, size: 12, color: kTextMuted),
                              SizedBox(width: 5),
                              Text(
                                'We\'ll send a verification code via SMS',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: kTextMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 26),
                        _LoginButton(
                          isLoading: isLoading,
                          onPressed: onContinue,
                          height: 56,
                        ),
                        const SizedBox(height: 22),
                        const _OrDivider(),
                        const SizedBox(height: 22),
                        _RegisterCard(onTap: onRegister, isDoctor: isDoctor),
                        const SizedBox(height: 18),
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
// PORTRAIT LAYOUT — Mobile-first hero design
// ─────────────────────────────────────────────────────────────────────────────
class _PortraitLayout extends StatelessWidget {
  final bool isDoctor;
  final bool isLoading;
  final TextEditingController mobileCtrl;
  final FocusNode focusNode;
  final bool isFocused;
  final VoidCallback onContinue;
  final VoidCallback onRegister;

  const _PortraitLayout({
    required this.isDoctor,
    required this.isLoading,
    required this.mobileCtrl,
    required this.focusNode,
    required this.isFocused,
    required this.onContinue,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenH = constraints.maxHeight;
        // Scale down hero on small screens so form is always visible
        final isSmall = screenH < 700;
        final isVerySmall = screenH < 600;

        final heroVPad = isVerySmall ? 16.0 : (isSmall ? 20.0 : 24.0);
        final heroBottomPad = isVerySmall ? 44.0 : (isSmall ? 52.0 : 64.0);
        final titleSize = isVerySmall ? 22.0 : (isSmall ? 26.0 : 29.0);
        final logoSize = isVerySmall ? 44.0 : (isSmall ? 50.0 : 56.0);
        final gapBeforeTitle = isVerySmall ? 16.0 : (isSmall ? 20.0 : 28.0);
        final gapTopRowToLogo = isVerySmall ? 16.0 : (isSmall ? 20.0 : 28.0);

        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Column(
            children: [
              // ── HERO HEADER (self-sizing, no IntrinsicHeight) ───────────
              Container(
                width: double.infinity,
                child: Stack(
                  children: [
                    // Gradient bg
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
                    // Decorative blobs
                    Positioned(
                      top: -50,
                      right: -40,
                      child: _Blob(size: isSmall ? 130 : 160, opacity: 0.18),
                    ),
                    Positioned(
                      top: 30,
                      left: -30,
                      child: _Blob(size: isSmall ? 90 : 110, opacity: 0.12),
                    ),
                    // Dot pattern
                    const Positioned.fill(child: _DotPattern()),

                    // Content
                    SafeArea(
                      bottom: false,
                      child: Padding(
                        padding: EdgeInsets.fromLTRB(
                            28, heroVPad, 28, heroBottomPad),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Role badge top
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.30),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        isDoctor
                                            ? Icons.medical_services_outlined
                                            : Icons.favorite_border_rounded,
                                        color: Colors.white,
                                        size: 12,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        isDoctor ? 'Doctor Portal' : 'Patient Portal',
                                        style: const TextStyle(
                                          fontSize: 11,
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const Spacer(),
                                // Help icon
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.18),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.25),
                                      width: 1,
                                    ),
                                  ),
                                  child: const Icon(
                                    Icons.help_outline_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: gapTopRowToLogo),
                            Row(
                              children: [
                                _BrandLogo(size: logoSize),
                                const SizedBox(width: 14),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'HealthConnect',
                                      style: TextStyle(
                                        fontSize: isVerySmall ? 18 : 22,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                        letterSpacing: -0.4,
                                      ),
                                    ),
                                    Text(
                                      'Care, simplified',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.white.withOpacity(0.85),
                                        fontWeight: FontWeight.w400,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: gapBeforeTitle),
                            Text(
                              isVerySmall ? 'Welcome back 👋' : 'Welcome\nback 👋',
                              style: TextStyle(
                                fontSize: titleSize,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: -0.8,
                                height: 1.1,
                              ),
                            ),
                            SizedBox(height: isVerySmall ? 6 : 10),
                            Text(
                              isDoctor
                                  ? 'Sign in to manage appointments and patients'
                                  : 'Sign in to book and track your appointments',
                              style: TextStyle(
                                fontSize: isVerySmall ? 12.5 : 14,
                                color: Colors.white.withOpacity(0.88),
                                height: 1.5,
                                fontWeight: FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Curved white bottom
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

              // ── FORM CARD ───────────────────────────────────────────────
              Container(
                width: double.infinity,
                color: kSurface,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Card with form
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: kSurface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: kBorder, width: 1),
                            boxShadow: [
                              BoxShadow(
                                color: kTextPrimary.withOpacity(0.04),
                                blurRadius: 24,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 36,
                                    height: 36,
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Icon(
                                      Icons.lock_outline_rounded,
                                      color: kPrimaryDark,
                                      size: 18,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Sign In',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w800,
                                            color: kTextPrimary,
                                          ),
                                        ),
                                        SizedBox(height: 2),
                                        Text(
                                          'Use your registered mobile',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: kTextSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 22),
                              const _FieldLabel(text: 'Mobile Number'),
                              const SizedBox(height: 10),
                              _MobileField(
                                controller: mobileCtrl,
                                focusNode: focusNode,
                                isFocused: isFocused,
                                height: 56,
                              ),
                              const SizedBox(height: 10),
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Row(
                                  children: [
                                    Icon(Icons.info_outline,
                                        size: 12, color: kTextMuted),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'We\'ll send a 6-digit code via SMS',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: kTextMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 22),
                              _LoginButton(
                                isLoading: isLoading,
                                onPressed: onContinue,
                                height: 56,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        const _OrDivider(),
                        const SizedBox(height: 20),
                        _RegisterCard(onTap: onRegister, isDoctor: isDoctor),
                        const SizedBox(height: 24),
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
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel({required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            text,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              color: kError,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      );
}

class _MobileField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isFocused;
  final double height;

  const _MobileField({
    required this.controller,
    required this.focusNode,
    required this.isFocused,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      height: height,
      decoration: BoxDecoration(
        color: isFocused ? kSurface : kBgSoft,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isFocused ? kPrimary : kBorderStrong,
          width: isFocused ? 1.6 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                  color: kPrimary.withOpacity(0.12),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ]
            : [],
      ),
      child: Row(
        children: [
          // Country code chip
          Container(
            margin: const EdgeInsets.only(left: 6),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: isFocused ? kPrimaryLight : Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isFocused ? kPrimary.withOpacity(0.3) : kBorderStrong,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🇮🇳', style: TextStyle(fontSize: 16)),
                const SizedBox(width: 6),
                Text(
                  '+91',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isFocused ? kPrimaryDark : kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            width: 1,
            height: 24,
            color: kBorderStrong,
          ),
          // Number input
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              keyboardType: TextInputType.phone,
              maxLength: 10,
              cursorColor: kPrimary,
              cursorWidth: 1.6,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ],
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
              decoration: const InputDecoration(
                hintText: '98765 43210',
                hintStyle: TextStyle(
                  color: kTextMuted,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.5,
                ),
                counterText: '',
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
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
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: height,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimary, kPrimaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isLoading ? null : onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Continue',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: Colors.white,
                          size: 19,
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) => const Row(
        children: [
          Expanded(child: Divider(color: kBorderStrong, thickness: 1)),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'OR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextMuted,
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(child: Divider(color: kBorderStrong, thickness: 1)),
        ],
      );
}

class _RegisterCard extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDoctor;

  const _RegisterCard({required this.onTap, required this.isDoctor});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kPrimaryLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: kPrimary.withOpacity(0.25),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_add_alt_1_rounded,
                  color: kPrimaryDark,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'New to HealthConnect?',
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Create an account',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: kPrimaryDark,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
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
            painter: _StethoscopeIconPainter(),
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
  Widget build(BuildContext context) => CustomPaint(
        painter: _DotPatternPainter(),
      );
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
// STETHOSCOPE PAINTER
// ─────────────────────────────────────────────────────────────────────────────
class _StethoscopeIconPainter extends CustomPainter {
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