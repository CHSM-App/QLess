import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';

class OtpVerificationScreen extends ConsumerStatefulWidget {
  final String mobileNumber;
  final String role; // 'doctor' or 'patient'

  const OtpVerificationScreen({
    super.key,
    required this.mobileNumber,
    required this.role,
  });

  @override
  ConsumerState<OtpVerificationScreen> createState() =>
      _OtpVerificationScreenState();
}

class _OtpVerificationScreenState
    extends ConsumerState<OtpVerificationScreen>
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
  Color get _accentColor =>
      _isDoctor ? const Color(0xFF0F172A) : const Color(0xFF0F172A);

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

    _fadeAnim =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
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
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  String get _otpValue =>
      _controllers.map((c) => c.text).join();

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
    final result = await ref
        .read(authViewModelProvider.notifier)
        .login(TokenResponse(mobile: widget.mobileNumber));

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (result == null) {
      setState(() => _hasError = true);
      _shakeController.forward(from: 0);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
      return;
    }

    final roleId = ref.read(tokenProvider).roleId ?? 0;
    if (roleId == 1) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const DoctorBottomNav()),
      );
    } else if (roleId == 2) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const PatientBottomNav()),
      );
    } else {
      setState(() => _hasError = true);
      _shakeController.forward(from: 0);
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    }
  }
  void _showSuccess() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: Color(0xFF10B981), size: 34),
              ),
              const SizedBox(height: 16),
              const Text(
                'Verified!',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your number has been\nsuccessfully verified.',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    // proceed to home
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Continue',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
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

  void _resendOtp() {
    if (_secondsLeft > 0) return;
    for (final c in _controllers) {
      c.clear();
    }
    setState(() => _hasError = false);
    _focusNodes[0].requestFocus();
    _startTimer();
    // TODO: trigger resend OTP API call
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: Color(0xFF0F172A), size: 20),
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
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const SizedBox(height: 12),

                // ── ICON ──────────────────────────────────────
                AnimatedContainer(
                  duration: const Duration(milliseconds: 350),
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    color: _accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _accentColor.withOpacity(0.28),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.sms_outlined,
                      color: Colors.white, size: 30),
                ),

                const SizedBox(height: 22),

                // ── TITLE ─────────────────────────────────────
                const Text(
                  'OTP Verification',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                    letterSpacing: -0.4,
                  ),
                ),

                const SizedBox(height: 10),

                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: Color(0xFF64748B),
                      height: 1.55,
                    ),
                    children: [
                      const TextSpan(
                          text: 'We sent a 6-digit code to\n'),
                      TextSpan(
                        text: '+91 $_maskedNumber',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 36),

                // ── OTP FIELDS ────────────────────────────────
                AnimatedBuilder(
                  animation: _shakeAnim,
                  builder: (context, child) {
                    final shake = (_shakeAnim.value > 0)
                        ? (8 *
                            (0.5 -
                                (_shakeAnim.value - 0.5).abs()) *
                            2 *
                            (_shakeAnim.value < 0.5 ? 1 : -1))
                        : 0.0;
                    return Transform.translate(
                      offset: Offset(shake, 0),
                      child: child,
                    );
                  },
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: List.generate(_otpLength, (i) {
                      return _OtpBox(
                        controller: _controllers[i],
                        focusNode: _focusNodes[i],
                        hasError: _hasError,
                        accentColor: _accentColor,
                        onChanged: (val) => _onOtpChanged(i, val),
                        onKeyEvent: (event) => _onKeyEvent(i, event),
                      );
                    }),
                  ),
                ),

                // ── ERROR TEXT ────────────────────────────────
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _hasError
                      ? Padding(
                          key: const ValueKey('error'),
                          padding: const EdgeInsets.only(top: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.error_outline_rounded,
                                  color: Color(0xFFEF4444), size: 15),
                              SizedBox(width: 5),
                              Text(
                                'Incorrect OTP. Please try again.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFFEF4444),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : const SizedBox(key: ValueKey('no-error'), height: 12),
                ),

                const SizedBox(height: 32),

                // ── VERIFY BUTTON ─────────────────────────────
                AnimatedOpacity(
                  opacity: _isFilled ? 1.0 : 0.55,
                  duration: const Duration(milliseconds: 250),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 350),
                    width: double.infinity,
                    height: 54,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: _isDoctor
                            ? [
                                const Color(0xFF0F172A),
                                const Color(0xFF1E3A5F),
                              ]
                            : [
                                const Color(0xFF0F172A),
                                const Color(0xFF1E3A5F),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: _isFilled
                          ? [
                              BoxShadow(
                                color: _accentColor.withOpacity(0.30),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : [],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: (_isFilled && !_isLoading) ? _verifyOtp : null,
                        child: Center(
                          child: _isLoading
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
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // ── RESEND ────────────────────────────────────
                Column(
                  children: [
                    const Text(
                      "Didn't receive the code?",
                      style: TextStyle(
                        fontSize: 13,
                        color: Color(0xFF64748B),
                      ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _secondsLeft > 0
                          ? Row(
                              key: const ValueKey('timer'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.timer_outlined,
                                    size: 14, color: Color(0xFF94A3B8)),
                                const SizedBox(width: 5),
                                Text(
                                  'Resend in ${_secondsLeft}s',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                              ],
                            )
                          : GestureDetector(
                              key: const ValueKey('resend'),
                              onTap: _resendOtp,
                              child: Text(
                                'Resend OTP',
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  color: _accentColor,
                                  decoration: TextDecoration.underline,
                                  decorationColor: _accentColor,
                                ),
                              ),
                            ),
                    ),
                  ],
                ),

                const Spacer(),

                // ── ROLE BADGE ────────────────────────────────
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accentColor.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                        color: _accentColor.withOpacity(0.18)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _isDoctor
                            ? Icons.medical_services_outlined
                            : Icons.person_outline_rounded,
                        size: 14,
                        color: _accentColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Logging in as ${_isDoctor ? 'Doctor' : 'Patient'}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: _accentColor,
                        ),
                      ),
                    ],
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

// ─────────────────────────────────────────────
// Single OTP input box
// ─────────────────────────────────────────────
class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.accentColor,
    required this.onChanged,
    required this.onKeyEvent,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final Color accentColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

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

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 56,
        decoration: BoxDecoration(
          color: widget.hasError
              ? const Color(0xFFFEF2F2)
              : filled
                  ? widget.accentColor.withOpacity(0.07)
                  : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: widget.hasError
                ? const Color(0xFFEF4444)
                : _isFocused
                    ? widget.accentColor
                    : filled
                        ? widget.accentColor.withOpacity(0.4)
                        : const Color(0xFFE2E8F0),
            width: _isFocused ? 2 : 1.5,
          ),
          boxShadow: _isFocused && !widget.hasError
              ? [
                  BoxShadow(
                    color: widget.accentColor.withOpacity(0.18),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
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
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: widget.hasError
                ? const Color(0xFFEF4444)
                : widget.accentColor,
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

