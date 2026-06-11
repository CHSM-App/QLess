import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:qless/firebase_options.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';

// ── Colour Palette (matches login + patient registration) ──────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF1EA898);
const kPrimaryDarker = Color(0xFF158578);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryGlow   = Color(0xFF4DD9C4);

const kBgSoft  = Color(0xFFF7FAFC);
const kSurface = Color(0xFFFFFFFF);
const kBg      = Color(0xFFF7FAFC);

const kTextPrimary   = Color(0xFF1A202C);
const kTextSecondary = Color(0xFF4A5568);
const kTextMuted     = Color(0xFF94A3B8);

const kBorder       = Color(0xFFF1F5F9);
const kBorderStrong = Color(0xFFE2E8F0);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess  = Color(0xFF68D391);

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String mobileNumber;
  final String role;

  /// Fixed OTP for demo/review accounts. When non-null, the code is validated
  /// locally against it and the verify-OTP API is skipped. `null` for real
  /// users, who follow the normal flow.
  final String? demoOtp;

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    required this.role,
    this.demoOtp,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends ConsumerState<OtpVerificationScreen>
    with TickerProviderStateMixin {
  static const int _otpLength = 6;
  static const int _timerSeconds = 30;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  late AnimationController _fadeController;
  late AnimationController _shakeController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _shakeAnim;

  int _secondsLeft = _timerSeconds;
  Timer? _timer;
  bool _isLoading = false;
  bool _hasError = false;

  bool get _isDoctor => widget.role == 'doctor';

  String get _maskedNumber {
    final n = widget.mobileNumber;
    if (n.length < 10) return n;
    return '${n.substring(0, 2)}******${n.substring(n.length - 2)}';
  }

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOut),
    );
    _shakeAnim = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.elasticIn),
    );

    _fadeController.forward();
    _startTimer();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNodes[0].requestFocus();
    });
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _timerSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft == 0) {
        t.cancel();
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _shakeController.dispose();
    _timer?.cancel();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes) f.dispose();
    super.dispose();
  }

  String get _otpValue => _controllers.map((c) => c.text).join();
  bool get _isFilled => _otpValue.length == _otpLength;

  void _onOtpChanged(int index, String value) {
    if (_hasError) setState(() => _hasError = false);
    if (value.length == 1 && index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _controllers[index].text.isEmpty &&
        index > 0) {
      _focusNodes[index - 1].requestFocus();
      _controllers[index - 1].clear();
      setState(() {});
    }
  }

  Future<void> _verifyOtp() async {
    if (!_isFilled) return;

    // Demo/review accounts: validate the fixed OTP locally and skip the
    // verify-OTP API. Real users (demoOtp == null) fall through unchanged.
    if (widget.demoOtp != null && _otpValue != widget.demoOtp) {
      _triggerError();
      return;
    }

    setState(() => _isLoading = true);

    // Real users: verify the OTP with the backend before logging in.
    // Demo users already passed the local check above.
    if (widget.demoOtp == null) {
      final verify = await ref
          .read(doctorLoginViewModelProvider.notifier)
          .verifyOtp(OtpResponse(mobileNo: widget.mobileNumber, otp: _otpValue));
      if (!mounted) return;
      if ((verify.status ?? 0) != 1) {
        setState(() => _isLoading = false);
        _triggerError();
        return;
      }
    }

    if (widget.role == 'doctor') {
      await ref
          .read(doctorLoginViewModelProvider.notifier)
          .checkPhoneDoctor(widget.mobileNumber);
    } else {
      await ref
          .read(patientLoginViewModelProvider.notifier)
          .checkPhonePatient(widget.mobileNumber);
    }

    final result = await ref
        .read(authViewModelProvider.notifier)
        .login(TokenResponse(mobile: widget.mobileNumber, role: widget.role));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      _triggerError();
      return;
    }

    await _printFcmToken();
    await _storeFcmToken();

    final roleId = ref.read(tokenProvider).roleId ?? 0;
    if (1 == roleId) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const DoctorBottomNav()),
        (_) => false,
      );
    } else if (2 == roleId) {
      // Recreate the key so the old PatientBottomNav element (still inactive
      // from the previous logout) doesn't clash with the new one.
      patientShellKey = GlobalKey<PatientBottomNavState>();
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PatientBottomNav(
            key: patientShellKey,
            onToggleTheme: () {},
            themeMode: ThemeMode.light,
          ),
        ),
        (_) => false,
      );
    } else {
      _triggerError();
    }
  }

  Future<void> _printFcmToken() async {
    try {
      await _ensureFirebaseInitialized();
      final token = await FirebaseMessaging.instance.getToken();
      debugPrint('FCM token (OTP verify): $token');
    } catch (e) {
      debugPrint('FCM token fetch failed (OTP verify): $e');
    }
  }

  Future<void> _storeFcmToken() async {
    try {
      await _ensureFirebaseInitialized();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      final body = TokenResponse(
        firebaseToken: token,
        role: widget.role,
        mobile: widget.mobileNumber,
      );
      await ref.read(authViewModelProvider.notifier).saveFirebaseToken(body);
    } catch (e) {
      debugPrint('FCM token store failed: $e');
    }
  }

  Future<void> _ensureFirebaseInitialized() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (e) {
      debugPrint('Firebase init failed (OTP verify): $e');
    }
  }

  void _triggerError() {
    setState(() => _hasError = true);
    _shakeController.forward(from: 0);
    for (final c in _controllers) c.clear();
    _focusNodes[0].requestFocus();
  }

  void _resendOtp() {
    if (_secondsLeft > 0) return;
    for (final c in _controllers) c.clear();
    setState(() => _hasError = false);
    _focusNodes[0].requestFocus();
    _startTimer();
    // Demo numbers have no server OTP — only real users re-request one.
    if (widget.demoOtp == null) {
      ref
          .read(doctorLoginViewModelProvider.notifier)
          .sendOtp(OtpResponse(mobileNo: widget.mobileNumber));
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: kBg,
        body: SafeArea(
          child: Column(
            children: [
              _SimpleTitleBar(
                title: 'Verify Your Number',
                subtitle: 'Enter the code we just sent',
                isDoctor: _isDoctor,
                onBack: () => Navigator.pop(context),
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: Builder(
                      builder: (context) {
                  // Decide layout from the physical screen size, NOT the
                  // keyboard-shrunk viewport. Otherwise opening the number
                  // keypad shrinks the height below the width and flips
                  // portrait -> landscape, overflowing the page.
                  final Size screen = MediaQuery.of(context).size;
                  final bool useWideLayout =
                      screen.width > screen.height || screen.width >= 600;

                  if (useWideLayout) {
                    return _LandscapeLayout(
                      isDoctor: _isDoctor,
                      maskedNumber: _maskedNumber,
                      mobileNumber: widget.mobileNumber,
                      controllers: _controllers,
                      focusNodes: _focusNodes,
                      hasError: _hasError,
                      isFilled: _isFilled,
                      isLoading: _isLoading,
                      secondsLeft: _secondsLeft,
                      shakeAnim: _shakeAnim,
                      onOtpChanged: _onOtpChanged,
                      onKeyEvent: _onKeyEvent,
                      onVerify: _verifyOtp,
                      onResend: _resendOtp,
                    );
                  }

                  return _PortraitLayout(
                    isDoctor: _isDoctor,
                    maskedNumber: _maskedNumber,
                    mobileNumber: widget.mobileNumber,
                    controllers: _controllers,
                    focusNodes: _focusNodes,
                    hasError: _hasError,
                    isFilled: _isFilled,
                    isLoading: _isLoading,
                    secondsLeft: _secondsLeft,
                    shakeAnim: _shakeAnim,
                    onOtpChanged: _onOtpChanged,
                    onKeyEvent: _onKeyEvent,
                    onVerify: _verifyOtp,
                    onResend: _resendOtp,
                  );
                      },
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
}

// ═════════════════════════════════════════════════════════════════════════════
// SIMPLE TITLE BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SimpleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final bool isDoctor;
  final VoidCallback onBack;

  const _SimpleTitleBar({
    required this.title,
    required this.subtitle,
    required this.isDoctor,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 0,
      child: Container(
        height: 74,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
        decoration: const BoxDecoration(
          color: kSurface,
          border: Border(bottom: BorderSide(color: kBorder, width: 1)),
        ),
        child: Row(
          children: [
              Material(
                color: kBgSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: const BorderSide(color: kBorderStrong, width: 0.5),
                ),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(11),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: kTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                // Clamp device font scaling so a large system font setting
                // can't overflow the fixed-height (68px) title bar.
                child: MediaQuery.withClampedTextScaling(
                  maxScaleFactor: 1.1,
                  child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                    ),
                  ],
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isDoctor
                          ? Icons.medical_services_outlined
                          : Icons.favorite_border_rounded,
                      size: 11,
                      color: kPrimaryDarker,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isDoctor ? 'Doctor' : 'Patient',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PORTRAIT LAYOUT
// ═════════════════════════════════════════════════════════════════════════════
class _PortraitLayout extends StatelessWidget {
  final bool isDoctor;
  final String maskedNumber;
  final String mobileNumber;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final bool isFilled;
  final bool isLoading;
  final int secondsLeft;
  final Animation<double> shakeAnim;
  final void Function(int, String) onOtpChanged;
  final void Function(int, KeyEvent) onKeyEvent;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _PortraitLayout({
    required this.isDoctor,
    required this.maskedNumber,
    required this.mobileNumber,
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.isFilled,
    required this.isLoading,
    required this.secondsLeft,
    required this.shakeAnim,
    required this.onOtpChanged,
    required this.onKeyEvent,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final isSmall = size.height < 700;
    final isVerySmall = size.height < 600;

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, isVerySmall ? 12 : 22, 20, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── Hero icon ────────────────────────────────────────
          _OtpHeroIcon(small: isVerySmall),
          SizedBox(height: isVerySmall ? 14 : 20),

          // ── Title + subtitle ─────────────────────────────────
          Text(
            'Enter the 6-digit code',
            style: TextStyle(
              fontSize: isVerySmall ? 19 : 22,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 13.5,
                color: kTextSecondary,
                fontWeight: FontWeight.w500,
                height: 1.5,
              ),
              children: [
                const TextSpan(text: "We've sent a verification code to\n"),
                TextSpan(
                  text: '+91 $maskedNumber',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isVerySmall ? 18 : 26),

          // ── OTP card ─────────────────────────────────────────
          _OtpCard(
            controllers: controllers,
            focusNodes: focusNodes,
            hasError: hasError,
            shakeAnim: shakeAnim,
            onOtpChanged: onOtpChanged,
            onKeyEvent: onKeyEvent,
            secondsLeft: secondsLeft,
            onResend: onResend,
          ),
          SizedBox(height: isSmall ? 18 : 24),

          // ── Verify button ────────────────────────────────────
          _VerifyButton(
            isFilled: isFilled,
            isLoading: isLoading,
            onVerify: onVerify,
          ),
          const SizedBox(height: 16),

          // ── Change number link ───────────────────────────────
          _ChangeNumberLink(
            mobileNumber: mobileNumber,
            onTap: () => Navigator.of(context).maybePop(),
          ),
          SizedBox(height: isVerySmall ? 14 : 22),

          // ── Secure footer ────────────────────────────────────
          const _SecureFooter(),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LANDSCAPE LAYOUT
// ═════════════════════════════════════════════════════════════════════════════
class _LandscapeLayout extends StatelessWidget {
  final bool isDoctor;
  final String maskedNumber;
  final String mobileNumber;
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final bool isFilled;
  final bool isLoading;
  final int secondsLeft;
  final Animation<double> shakeAnim;
  final void Function(int, String) onOtpChanged;
  final void Function(int, KeyEvent) onKeyEvent;
  final VoidCallback onVerify;
  final VoidCallback onResend;

  const _LandscapeLayout({
    required this.isDoctor,
    required this.maskedNumber,
    required this.mobileNumber,
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.isFilled,
    required this.isLoading,
    required this.secondsLeft,
    required this.shakeAnim,
    required this.onOtpChanged,
    required this.onKeyEvent,
    required this.onVerify,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 880),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // ── LEFT brand panel ─────────────────────────────────
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _OtpHeroIcon(small: true),
                    const SizedBox(height: 18),
                    const Text(
                      'Enter the\n6-digit code',
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        height: 1.15,
                        letterSpacing: -0.6,
                      ),
                    ),
                    const SizedBox(height: 10),
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.55,
                        ),
                        children: [
                          const TextSpan(
                              text: "We've sent a verification code to\n"),
                          TextSpan(
                            text: '+91 $maskedNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: kTextPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _ChangeNumberLink(
                      mobileNumber: mobileNumber,
                      onTap: () => Navigator.of(context).maybePop(),
                    ),
                  ],
                ),
              ),
            ),

            // ── RIGHT form panel ─────────────────────────────────
            Expanded(
              flex: 5,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _OtpCard(
                      controllers: controllers,
                      focusNodes: focusNodes,
                      hasError: hasError,
                      shakeAnim: shakeAnim,
                      onOtpChanged: onOtpChanged,
                      onKeyEvent: onKeyEvent,
                      secondsLeft: secondsLeft,
                      onResend: onResend,
                    ),
                    const SizedBox(height: 18),
                    _VerifyButton(
                      isFilled: isFilled,
                      isLoading: isLoading,
                      onVerify: onVerify,
                    ),
                    const SizedBox(height: 18),
                    const _SecureFooter(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OTP HERO ICON (radial gradient circle with message icon)
// ═════════════════════════════════════════════════════════════════════════════
class _OtpHeroIcon extends StatelessWidget {
  final bool small;
  const _OtpHeroIcon({this.small = false});

  @override
  Widget build(BuildContext context) {
    final double outerSize = small ? 72 : 88;
    final double iconSize = small ? 30 : 36;

    return Container(
      width: outerSize,
      height: outerSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          colors: [kPrimaryLight, Colors.white],
          stops: [0.0, 1.0],
        ),
        border: Border.all(color: kPrimary.withOpacity(0.3), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: kPrimary.withOpacity(0.18),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Center(
        child: Container(
          width: outerSize * 0.62,
          height: outerSize * 0.62,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [kPrimary, kPrimaryDark],
            ),
            boxShadow: [
              BoxShadow(
                color: kPrimary.withOpacity(0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.sms_outlined,
            color: Colors.white,
            size: iconSize,
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OTP CARD (white surface containing the input row + resend)
// ═════════════════════════════════════════════════════════════════════════════
class _OtpCard extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final Animation<double> shakeAnim;
  final void Function(int, String) onOtpChanged;
  final void Function(int, KeyEvent) onKeyEvent;
  final int secondsLeft;
  final VoidCallback onResend;

  const _OtpCard({
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.shakeAnim,
    required this.onOtpChanged,
    required this.onKeyEvent,
    required this.secondsLeft,
    required this.onResend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Icon(Icons.lock_outline_rounded,
                    color: kPrimaryDarker, size: 17),
              ),
              const SizedBox(width: 10),
              const Text(
                'Verification Code',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // OTP boxes
          _OtpBoxRow(
            controllers: controllers,
            focusNodes: focusNodes,
            hasError: hasError,
            shakeAnim: shakeAnim,
            onOtpChanged: onOtpChanged,
            onKeyEvent: onKeyEvent,
          ),

          // Error / spacer
          _ErrorText(hasError: hasError),

          const Divider(color: kBorder, height: 18, thickness: 1),

          // Resend row
          _ResendRow(secondsLeft: secondsLeft, onResend: onResend),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// OTP BOX ROW
// ═════════════════════════════════════════════════════════════════════════════
class _OtpBoxRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final bool hasError;
  final Animation<double> shakeAnim;
  final void Function(int, String) onOtpChanged;
  final void Function(int, KeyEvent) onKeyEvent;

  const _OtpBoxRow({
    required this.controllers,
    required this.focusNodes,
    required this.hasError,
    required this.shakeAnim,
    required this.onOtpChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shakeAnim,
      builder: (context, child) {
        final shake = (shakeAnim.value > 0)
            ? (8 *
                (0.5 - (shakeAnim.value - 0.5).abs()) *
                2 *
                (shakeAnim.value < 0.5 ? 1 : -1))
            : 0.0;
        return Transform.translate(offset: Offset(shake, 0), child: child);
      },
      child: LayoutBuilder(
        builder: (context, constraints) {
          const double gap = 8.0;
          final double totalGap = gap * 5;
          final double boxWidth =
              ((constraints.maxWidth - totalGap) / 6).clamp(36.0, 52.0);
          final double boxHeight = (boxWidth * 1.22).clamp(46.0, 64.0);

          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(6, (i) {
              return _OtpBox(
                controller: controllers[i],
                focusNode: focusNodes[i],
                hasError: hasError,
                boxWidth: boxWidth,
                boxHeight: boxHeight,
                onChanged: (val) => onOtpChanged(i, val),
                onKeyEvent: (event) => onKeyEvent(i, event),
              );
            }),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// ERROR TEXT
// ═════════════════════════════════════════════════════════════════════════════
class _ErrorText extends StatelessWidget {
  final bool hasError;
  const _ErrorText({required this.hasError});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      child: hasError
          ? Padding(
              key: const ValueKey('error'),
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kError.withOpacity(0.35)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.error_outline_rounded,
                        color: kError, size: 15),
                    SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'Incorrect OTP. Please try again.',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Color(0xFFC53030),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : const SizedBox(key: ValueKey('no-error'), height: 6),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// VERIFY BUTTON (gradient CTA)
// ═════════════════════════════════════════════════════════════════════════════
class _VerifyButton extends StatelessWidget {
  final bool isFilled;
  final bool isLoading;
  final VoidCallback onVerify;

  const _VerifyButton({
    required this.isFilled,
    required this.isLoading,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    final bool enabled = isFilled && !isLoading;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: enabled
            ? const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [kPrimary, kPrimaryDark],
              )
            : null,
        color: enabled ? null : kBorderStrong,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled
            ? [
                BoxShadow(
                  color: kPrimary.withOpacity(0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onVerify : null,
          borderRadius: BorderRadius.circular(14),
          child: Center(
            child: isLoading
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  )
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Verify & Continue',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: enabled ? Colors.white : kTextMuted,
                          letterSpacing: 0.3,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_rounded,
                        size: 19,
                        color: enabled ? Colors.white : kTextMuted,
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// RESEND ROW
// ═════════════════════════════════════════════════════════════════════════════
class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onResend;

  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          "Didn't receive the code?",
          style: TextStyle(
            fontSize: 12.5,
            color: kTextSecondary,
            fontWeight: FontWeight.w500,
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: secondsLeft > 0
              ? Container(
                  key: const ValueKey('timer'),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: kBgSoft,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kBorderStrong),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 12, color: kTextMuted),
                      const SizedBox(width: 4),
                      Text(
                        '${secondsLeft}s',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                )
              : Material(
                  key: const ValueKey('resend'),
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onResend,
                    borderRadius: BorderRadius.circular(20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 11, vertical: 5),
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.refresh_rounded,
                              size: 13, color: kPrimaryDarker),
                          SizedBox(width: 4),
                          Text(
                            'Resend',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: kPrimaryDarker,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CHANGE NUMBER LINK
// ═════════════════════════════════════════════════════════════════════════════
class _ChangeNumberLink extends StatelessWidget {
  final String mobileNumber;
  final VoidCallback onTap;

  const _ChangeNumberLink({
    required this.mobileNumber,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.edit_outlined, size: 14, color: kTextSecondary),
              SizedBox(width: 5),
              Text(
                'Wrong number? ',
                style: TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Change',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryDarker,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECURE FOOTER
// ═════════════════════════════════════════════════════════════════════════════
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
              fontSize: 11.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SINGLE OTP BOX
// ═════════════════════════════════════════════════════════════════════════════
class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.onChanged,
    required this.onKeyEvent,
    this.boxWidth = 46,
    this.boxHeight = 56,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;
  final double boxWidth;
  final double boxHeight;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(_handleFocus);
  }

  void _handleFocus() {
    if (!mounted) return;
    setState(() => _isFocused = widget.focusNode.hasFocus);
  }

  @override
  void dispose() {
    widget.focusNode.removeListener(_handleFocus);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final double fontSize = (widget.boxWidth * 0.46).clamp(16.0, 22.0);

    final Color bg;
    final Color borderColor;
    final double borderWidth;
    final Color textColor;

    if (widget.hasError) {
      bg = kRedLight;
      borderColor = kError;
      borderWidth = 1.6;
      textColor = const Color(0xFFC53030);
    } else if (_isFocused) {
      bg = kPrimaryLight.withOpacity(0.5);
      borderColor = kPrimary;
      borderWidth = 1.8;
      textColor = kPrimaryDarker;
    } else if (filled) {
      bg = kPrimaryLight;
      borderColor = kPrimary.withOpacity(0.5);
      borderWidth = 1.4;
      textColor = kPrimaryDarker;
    } else {
      bg = kBgSoft;
      borderColor = kBorderStrong;
      borderWidth = 1;
      textColor = kTextPrimary;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        width: widget.boxWidth,
        height: widget.boxHeight,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: _isFocused && !widget.hasError
              ? [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.15),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [],
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w800,
            color: textColor,
            height: 1,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            counterText: '',
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
