import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:qless/firebase_options.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';

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

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String mobileNumber;
  final String role;

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    required this.role,
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
  late Animation<double> _slideAnim;
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
      duration: const Duration(milliseconds: 600),
    );
    _shakeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<double>(begin: 30, end: 0).animate(
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
    setState(() => _isLoading = true);

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
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => PatientBottomNav(
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
    // TODO: trigger resend OTP API call
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: kPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AnimatedBuilder(
        animation: _fadeAnim,
        builder: (context, child) => Opacity(
          opacity: _fadeAnim.value,
          child: Transform.translate(
            offset: Offset(0, _slideAnim.value),
            child: child,
          ),
        ),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final bool useWideLayout =
                  constraints.maxWidth > constraints.maxHeight ||
                      constraints.maxWidth >= 600;

              if (useWideLayout) {
                return _LandscapeLayout(
                  isDoctor: _isDoctor,
                  maskedNumber: _maskedNumber,
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
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LANDSCAPE / WIDE LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _LandscapeLayout extends StatelessWidget {
  final bool isDoctor;
  final String maskedNumber;
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
    final bool isShortLandscape = size.height < 420 && size.width > size.height;
    final double iconSize = isShortLandscape ? 48.0 : 64.0;
    final double titleFontSize = isShortLandscape ? 15.0 : 19.0;
    final double subtitleFontSize = isShortLandscape ? 11.0 : 12.5;
    final double rightPadV = isShortLandscape ? 12.0 : 20.0;
    final double rightPadH = isShortLandscape ? 24.0 : 32.0;

    return Row(
      children: [
        // ── LEFT PANEL ────────────────────────────────────────────────────
        Expanded(
          flex: 4,
          child: Container(
            color: kPrimary,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: iconSize,
                  height: iconSize,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.18),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.sms_outlined,
                    color: Colors.white,
                    size: isShortLandscape ? 20 : 28,
                  ),
                ),

                SizedBox(height: isShortLandscape ? 10 : 18),

                Text(
                  'OTP Verification',
                  style: TextStyle(
                    fontSize: titleFontSize,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),

                SizedBox(height: isShortLandscape ? 6 : 10),

                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      style: TextStyle(
                        fontSize: subtitleFontSize,
                        color: Colors.white70,
                        height: 1.55,
                      ),
                      children: [
                        const TextSpan(text: 'We sent a 6-digit code to\n'),
                        TextSpan(
                          text: '+91 $maskedNumber',
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                SizedBox(height: isShortLandscape ? 10 : 20),

                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isShortLandscape ? 4 : 7,
                  ),
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
                            : Icons.person_outline_rounded,
                        size: 13,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Logging in as ${isDoctor ? 'Doctor' : 'Patient'}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // ── RIGHT PANEL ───────────────────────────────────────────────────
        Expanded(
          flex: 6,
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: rightPadH,
                vertical: rightPadV,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Enter the 6-digit code',
                    style: TextStyle(
                      fontSize: isShortLandscape ? 14 : 17,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                      letterSpacing: -0.2,
                    ),
                  ),
                  SizedBox(height: isShortLandscape ? 14 : 20),
                  _OtpBoxRow(
                    controllers: controllers,
                    focusNodes: focusNodes,
                    hasError: hasError,
                    shakeAnim: shakeAnim,
                    onOtpChanged: onOtpChanged,
                    onKeyEvent: onKeyEvent,
                  ),
                  _ErrorText(hasError: hasError),
                  SizedBox(height: isShortLandscape ? 14 : 20),
                  _VerifyButton(
                    isFilled: isFilled,
                    isLoading: isLoading,
                    isDoctor: isDoctor,
                    onVerify: onVerify,
                  ),
                  SizedBox(height: isShortLandscape ? 10 : 16),
                  _ResendRow(
                    secondsLeft: secondsLeft,
                    onResend: onResend,
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
// PORTRAIT LAYOUT
// ─────────────────────────────────────────────────────────────────────────────
class _PortraitLayout extends StatelessWidget {
  final bool isDoctor;
  final String maskedNumber;
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
    final bool isSmall = size.height < 680;
    final double iconSize = isSmall ? 54.0 : 68.0;
    final double titleFontSize = isSmall ? 20.0 : 24.0;
    final double subFontSize = isSmall ? 12.5 : 13.5;

    return Column(
      children: [
        // ── TEAL HEADER ───────────────────────────────────────────────────
        Container(
          color: kPrimary,
          width: double.infinity,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: EdgeInsets.only(
                  top: isSmall ? 20 : 28,
                  bottom: 48,
                  left: 30,
                  right: 30,
                ),
                child: Column(
                  children: [
                    Container(
                      width: iconSize,
                      height: iconSize,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.35),
                          width: 1.5,
                        ),
                      ),
                      child: Icon(
                        Icons.sms_outlined,
                        color: Colors.white,
                        size: isSmall ? 24 : 30,
                      ),
                    ),
                    SizedBox(height: isSmall ? 14 : 18),
                    Text(
                      'OTP Verification',
                      style: TextStyle(
                        fontSize: titleFontSize,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: -0.4,
                      ),
                    ),
                    SizedBox(height: isSmall ? 6 : 10),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: subFontSize,
                          color: Colors.white70,
                          height: 1.55,
                        ),
                        children: [
                          const TextSpan(text: 'We sent a 6-digit code to\n'),
                          TextSpan(
                            text: '+91 $maskedNumber',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
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
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.07),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(height: isSmall ? 20 : 28),

                const Text(
                  'Enter the 6-digit code',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.2,
                  ),
                ),

                SizedBox(height: isSmall ? 20 : 28),

                _OtpBoxRow(
                  controllers: controllers,
                  focusNodes: focusNodes,
                  hasError: hasError,
                  shakeAnim: shakeAnim,
                  onOtpChanged: onOtpChanged,
                  onKeyEvent: onKeyEvent,
                ),

                _ErrorText(hasError: hasError),

                SizedBox(height: isSmall ? 20 : 28),

                _VerifyButton(
                  isFilled: isFilled,
                  isLoading: isLoading,
                  isDoctor: isDoctor,
                  onVerify: onVerify,
                ),

                SizedBox(height: isSmall ? 18 : 24),

                _ResendRow(secondsLeft: secondsLeft, onResend: onResend),

                const Spacer(),

                // Role badge
                Container(
                  margin: EdgeInsets.only(bottom: isSmall ? 14 : 24),
                  padding: EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: isSmall ? 6 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: kPrimary.withOpacity(0.30)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isDoctor
                            ? Icons.medical_services_outlined
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: kPrimaryDark,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Logging in as ${isDoctor ? 'Doctor' : 'Patient'}',
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: kPrimaryDark,
                        ),
                      ),
                    ],
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
// SHARED WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

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
          final double totalGap = 5 * 8.0;
          final double boxWidth =
              ((constraints.maxWidth - totalGap) / 6).clamp(36.0, 54.0);
          final double boxHeight = (boxWidth * 1.22).clamp(44.0, 66.0);

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
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  Icon(Icons.error_outline_rounded, color: kError, size: 15),
                  SizedBox(width: 5),
                  Text(
                    'Incorrect OTP. Please try again.',
                    style: TextStyle(
                      fontSize: 13,
                      color: kError,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            )
          : const SizedBox(key: ValueKey('no-error'), height: 12),
    );
  }
}

class _VerifyButton extends StatelessWidget {
  final bool isFilled;
  final bool isLoading;
  final bool isDoctor;
  final VoidCallback onVerify;

  const _VerifyButton({
    required this.isFilled,
    required this.isLoading,
    required this.isDoctor,
    required this.onVerify,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedOpacity(
      opacity: isFilled ? 1.0 : 0.5,
      duration: const Duration(milliseconds: 250),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: (isFilled && !isLoading) ? onVerify : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            disabledBackgroundColor: kPrimaryLight,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : const Text(
                  'Verify OTP',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.2,
                  ),
                ),
        ),
      ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  final int secondsLeft;
  final VoidCallback onResend;

  const _ResendRow({required this.secondsLeft, required this.onResend});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          "Didn't receive the code?",
          style: TextStyle(fontSize: 13, color: kTextSecondary),
        ),
        const SizedBox(height: 8),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: secondsLeft > 0
              ? Row(
                  key: const ValueKey('timer'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer_outlined,
                        size: 14, color: kTextMuted),
                    const SizedBox(width: 5),
                    Text(
                      'Resend in ${secondsLeft}s',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                )
              : GestureDetector(
                  key: const ValueKey('resend'),
                  onTap: onResend,
                  child: const Text(
                    'Resend OTP',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                      color: kPrimary,
                      decoration: TextDecoration.underline,
                      decorationColor: kPrimary,
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SINGLE OTP BOX
// ─────────────────────────────────────────────────────────────────────────────
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
    widget.focusNode.addListener(() {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final double fontSize = (widget.boxWidth * 0.48).clamp(16.0, 24.0);

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: widget.boxWidth,
        height: widget.boxHeight,
        decoration: BoxDecoration(
          color: widget.hasError
              ? kRedLight
              : filled
                  ? kPrimaryLight
                  : kBorder,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: widget.hasError
                ? kError
                : _isFocused
                    ? kPrimary
                    : filled
                        ? kPrimaryDark.withOpacity(0.4)
                        : kDivider,
            width: _isFocused ? 2 : 1.5,
          ),
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
            color: widget.hasError ? kError : kPrimary,
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