import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/constant.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart'
    hide appointmentViewModelProvider;
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';

// ── Colours (match profile.dart) ──────────────────────────────────────────────
const _kPrimary      = Color(0xFF26C6B0);
const _kPrimaryLight = Color(0xFFD9F5F1);
const _kError        = Color(0xFFFC8181);
const _kRedLight     = Color(0xFFFEE2E2);
const _kTextPrimary  = Color(0xFF2D3748);
const _kTextSecondary= Color(0xFF718096);
const _kTextMuted    = Color(0xFFA0AEC0);
const _kBorder       = Color(0xFFEDF2F7);
const _kBorderStrong = Color(0xFFE2E8F0);

const _kOtpLength     = 6;
const _kResendSeconds = 30;

const _consequences = [
  'Your account and profile will be permanently deleted',
  'All booking history and tokens will be removed',
  'Your prescriptions will no longer be accessible',
  'Family member profiles linked to your account will be deleted',
  'This action cannot be undone',
];

const _reasons = [
  'I no longer use the app',
  'Privacy concerns',
  'Switching to another service',
  'App is not working properly',
  'Other',
];

// ─────────────────────────────────────────────────────────────────────────────
class DeleteAccountPage extends ConsumerStatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  ConsumerState<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends ConsumerState<DeleteAccountPage> {
  int    _step    = 1; // 1=consequences, 2=OTP, 3=reason+confirm
  bool   _agreed  = false;
  bool   _loading = false;
  String _error   = '';
  String _reason  = '';

  // OTP
  final List<TextEditingController> _otpCtrl =
      List.generate(_kOtpLength, (_) => TextEditingController());
  final List<FocusNode> _otpFocus =
      List.generate(_kOtpLength, (_) => FocusNode());
  int    _secondsLeft = _kResendSeconds;
  Timer? _timer;
  bool   _otpError = false;

  String get _otpValue => _otpCtrl.map((c) => c.text).join();
  bool get _otpFilled => _otpValue.length == _kOtpLength;

  // ── Derived user info ────────────────────────────────────────────────────
  String get _phone {
    final roleId = ref.read(tokenProvider).roleId ?? 0;
    if (roleId == 2) {
      return ref.read(patientLoginViewModelProvider).mobileNo ?? '';
    }
    return ref.read(doctorLoginViewModelProvider).mobile ?? '';
  }

  int get _roleId => ref.read(tokenProvider).roleId ?? 2;

  String get _maskedPhone {
    final p = _phone;
    if (p.length < 6) return p;
    return '${p.substring(0, 2)}****${p.substring(p.length - 2)}';
  }

  // ────────────────────────────────────────────────────────────────────────
  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _otpCtrl) c.dispose();
    for (final f in _otpFocus) f.dispose();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    setState(() => _secondsLeft = _kResendSeconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      if (_secondsLeft == 0) { t.cancel(); return; }
      setState(() => _secondsLeft--);
    });
  }

  void _clearError() => setState(() => _error = '');

  // ── Step 2: Send OTP ─────────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    _clearError();
    setState(() => _loading = true);
    final res = await ref
        .read(doctorLoginViewModelProvider.notifier)
        .sendOtp(OtpResponse(mobileNo: _phone));
    if (!mounted) return;
    setState(() => _loading = false);
    if ((res.status ?? 0) != 1) {
      setState(() => _error = res.message ?? 'Failed to send OTP');
      return;
    }
    setState(() { _step = 2; _otpError = false; });
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_otpFocus.isNotEmpty) _otpFocus[0].requestFocus();
    });
  }

  // ── Step 3: Verify OTP ───────────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    if (!_otpFilled) return;
    _clearError();
    setState(() { _loading = true; _otpError = false; });
    final res = await ref
        .read(doctorLoginViewModelProvider.notifier)
        .verifyOtp(OtpResponse(mobileNo: _phone, otp: _otpValue));
    if (!mounted) return;
    setState(() => _loading = false);
    if ((res.status ?? 0) != 1) {
      setState(() => _otpError = true);
      for (final c in _otpCtrl) c.clear();
      if (_otpFocus.isNotEmpty) _otpFocus[0].requestFocus();
      return;
    }
    setState(() => _step = 3);
  }

  // ── Step 3: Submit deletion ───────────────────────────────────────────────
  Future<void> _submitDeletion() async {
    _clearError();
    setState(() => _loading = true);
    try {
      final dio = Dio(BaseOptions(baseUrl: baseUrl));
      await dio.post(
        'delete-account/request',
        data: {
          'phone':   _phone,
          'role_id': _roleId,
          'reason':  _reason.isEmpty ? null : _reason,
        },
      );
      if (!mounted) return;
      await _logout();
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = e.response?.data?['message'] ?? 'Network error. Please try again.';
      setState(() { _loading = false; _error = msg; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _loading = false; _error = 'Something went wrong.'; });
    }
  }

  Future<void> _logout() async {
    await ref.read(tokenProvider.notifier).clearTokens();
    ref.read(appointmentViewModelProvider.notifier).reset();
    ref.read(favoriteViewModelProvider.notifier).reset();
    await ref.read(patientLoginViewModelProvider.notifier).logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ContinueAsScreen()),
      (_) => false,
    );
  }

  // ────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF7FAFC),
        appBar: _AppBar(step: _step),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 20, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StepIndicator(current: _step),
                const SizedBox(height: 24),
                if (_error.isNotEmpty) ...[
                  _ErrorBanner(message: _error),
                  const SizedBox(height: 16),
                ],
                if (_step == 1) _Step1(
                  agreed: _agreed,
                  loading: _loading,
                  onAgreed: (v) => setState(() => _agreed = v ?? false),
                  onContinue: _sendOtp,
                ),
                if (_step == 2) _Step2(
                  maskedPhone: _maskedPhone,
                  otpCtrl: _otpCtrl,
                  otpFocus: _otpFocus,
                  otpError: _otpError,
                  otpFilled: _otpFilled,
                  loading: _loading,
                  secondsLeft: _secondsLeft,
                  onChanged: _onOtpChanged,
                  onKeyEvent: _onKeyEvent,
                  onVerify: _verifyOtp,
                  onResend: _resendOtp,
                  onBack: () => setState(() { _step = 1; _clearError(); }),
                ),
                if (_step == 3) _Step3(
                  phone: _phone,
                  reason: _reason,
                  loading: _loading,
                  onReasonChanged: (v) => setState(() => _reason = v ?? ''),
                  onSubmit: _submitDeletion,
                  onBack: () => setState(() { _step = 2; _clearError(); }),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _onOtpChanged(int index, String value) {
    if (_otpError) setState(() => _otpError = false);
    if (value.length == 1 && index < _kOtpLength - 1) {
      _otpFocus[index + 1].requestFocus();
    }
    if (value.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
    }
    setState(() {});
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace &&
        _otpCtrl[index].text.isEmpty &&
        index > 0) {
      _otpFocus[index - 1].requestFocus();
      _otpCtrl[index - 1].clear();
      setState(() {});
    }
  }

  void _resendOtp() {
    if (_secondsLeft > 0) return;
    for (final c in _otpCtrl) c.clear();
    setState(() => _otpError = false);
    if (_otpFocus.isNotEmpty) _otpFocus[0].requestFocus();
    _startTimer();
    ref.read(doctorLoginViewModelProvider.notifier)
        .sendOtp(OtpResponse(mobileNo: _phone));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// APP BAR
// ─────────────────────────────────────────────────────────────────────────────
class _AppBar extends StatelessWidget implements PreferredSizeWidget {
  final int step;
  const _AppBar({required this.step});

  @override
  Size get preferredSize => const Size.fromHeight(60);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0,
      child: Container(
        height: 60,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: _kBorder)),
        ),
        child: Row(children: [
          Material(
            color: const Color(0xFFF7FAFC),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: const BorderSide(color: _kBorderStrong, width: 0.5),
            ),
            child: InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(10),
              child: const SizedBox(
                width: 36, height: 36,
                child: Icon(Icons.arrow_back_ios_new_rounded,
                    size: 15, color: _kTextPrimary),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Delete Account',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: _kTextPrimary)),
              Text(
                step == 1 ? 'Review consequences'
                    : step == 2 ? 'Verify your identity'
                    : 'Final confirmation',
                style: const TextStyle(fontSize: 11, color: _kTextMuted),
              ),
            ],
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _kRedLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.delete_outline_rounded, size: 12, color: _kError),
                SizedBox(width: 4),
                Text('Deletion',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _kError)),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP INDICATOR
// ─────────────────────────────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int current;
  const _StepIndicator({required this.current});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (int i = 1; i <= 3; i++) ...[
        _StepDot(number: i, active: current >= i),
        if (i < 3)
          Expanded(
            child: Container(
              height: 2,
              color: current > i ? _kError.withOpacity(0.5) : _kBorderStrong,
            ),
          ),
      ],
      const SizedBox(width: 8),
      Text(
        current == 1 ? 'Review'
            : current == 2 ? 'Verify OTP'
            : 'Confirm',
        style: const TextStyle(fontSize: 12, color: _kTextMuted),
      ),
    ]);
  }
}

class _StepDot extends StatelessWidget {
  final int number;
  final bool active;
  const _StepDot({required this.number, required this.active});

  @override
  Widget build(BuildContext context) => Container(
    width: 30, height: 30,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: active ? _kError : _kBorderStrong,
    ),
    alignment: Alignment.center,
    child: Text('$number',
        style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: active ? Colors.white : _kTextMuted)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ERROR BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      color: _kRedLight,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: _kError.withOpacity(0.3)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline_rounded, size: 16, color: _kError),
      const SizedBox(width: 8),
      Expanded(
        child: Text(message,
            style: const TextStyle(fontSize: 13, color: Color(0xFFC53030))),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 1 — Consequences + agree
// ─────────────────────────────────────────────────────────────────────────────
class _Step1 extends StatelessWidget {
  final bool agreed;
  final bool loading;
  final ValueChanged<bool?> onAgreed;
  final VoidCallback onContinue;

  const _Step1({
    required this.agreed,
    required this.loading,
    required this.onAgreed,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _kRedLight,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kError.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.warning_amber_rounded, color: _kError, size: 18),
            SizedBox(width: 8),
            Text('What will be deleted',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFFC53030))),
          ]),
          const SizedBox(height: 12),
          ..._consequences.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Icon(Icons.close_rounded, size: 14, color: _kError),
              const SizedBox(width: 8),
              Expanded(child: Text(c,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9B2C2C), height: 1.4))),
            ]),
          )),
        ]),
      ),

      const SizedBox(height: 20),

      GestureDetector(
        onTap: () => onAgreed(!agreed),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Checkbox(
            value: agreed,
            onChanged: onAgreed,
            activeColor: _kError,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 12),
              child: Text(
                'I understand that deleting my account is permanent and all my data will be lost.',
                style: TextStyle(fontSize: 13, color: _kTextSecondary, height: 1.4),
              ),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 24),

      _PrimaryButton(
        label: 'Continue',
        icon: Icons.arrow_forward_rounded,
        enabled: agreed && !loading,
        loading: loading,
        color: _kError,
        onTap: onContinue,
      ),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 2 — OTP
// ─────────────────────────────────────────────────────────────────────────────
class _Step2 extends StatelessWidget {
  final String maskedPhone;
  final List<TextEditingController> otpCtrl;
  final List<FocusNode> otpFocus;
  final bool otpError, otpFilled, loading;
  final int secondsLeft;
  final void Function(int, String) onChanged;
  final void Function(int, KeyEvent) onKeyEvent;
  final VoidCallback onVerify, onResend, onBack;

  const _Step2({
    required this.maskedPhone,
    required this.otpCtrl,
    required this.otpFocus,
    required this.otpError,
    required this.otpFilled,
    required this.loading,
    required this.secondsLeft,
    required this.onChanged,
    required this.onKeyEvent,
    required this.onVerify,
    required this.onResend,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.04),
                blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: const [
            Icon(Icons.sms_outlined, color: _kPrimary, size: 18),
            SizedBox(width: 8),
            Text('Verify Your Identity',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary)),
          ]),
          const SizedBox(height: 10),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                  fontSize: 13, color: _kTextSecondary, height: 1.5),
              children: [
                const TextSpan(text: 'OTP sent to '),
                TextSpan(
                  text: '+91 $maskedPhone',
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, color: _kTextPrimary),
                ),
                const TextSpan(text: ' via WhatsApp'),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // OTP boxes
          LayoutBuilder(builder: (ctx, constraints) {
            const gap = 8.0;
            final boxW = ((constraints.maxWidth - gap * 5) / 6).clamp(36.0, 52.0);
            final boxH = (boxW * 1.22).clamp(46.0, 62.0);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(_kOtpLength, (i) => _OtpBox(
                controller: otpCtrl[i],
                focusNode: otpFocus[i],
                hasError: otpError,
                boxW: boxW, boxH: boxH,
                onChanged: (v) => onChanged(i, v),
                onKeyEvent: (e) => onKeyEvent(i, e),
              )),
            );
          }),

          if (otpError) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: _kRedLight,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _kError.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.error_outline_rounded, color: _kError, size: 14),
                SizedBox(width: 6),
                Text('Incorrect OTP. Please try again.',
                    style: TextStyle(fontSize: 12, color: Color(0xFFC53030))),
              ]),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(color: _kBorder, height: 1),
          const SizedBox(height: 12),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Didn't receive the code?",
                  style: TextStyle(fontSize: 12, color: _kTextSecondary)),
              secondsLeft > 0
                  ? Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: _kBorderStrong),
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.timer_outlined,
                            size: 12, color: _kTextMuted),
                        const SizedBox(width: 4),
                        Text('${secondsLeft}s',
                            style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _kTextSecondary)),
                      ]),
                    )
                  : GestureDetector(
                      onTap: onResend,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _kPrimaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.refresh_rounded,
                              size: 13, color: Color(0xFF158578)),
                          SizedBox(width: 4),
                          Text('Resend',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF158578))),
                        ]),
                      ),
                    ),
            ],
          ),
        ]),
      ),

      const SizedBox(height: 20),

      _PrimaryButton(
        label: 'Verify & Continue',
        icon: Icons.arrow_forward_rounded,
        enabled: otpFilled && !loading,
        loading: loading,
        color: _kError,
        onTap: onVerify,
      ),
      const SizedBox(height: 12),
      _SecondaryButton(label: 'Back', onTap: onBack),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STEP 3 — Reason + final confirm
// ─────────────────────────────────────────────────────────────────────────────
class _Step3 extends StatelessWidget {
  final String phone, reason;
  final bool loading;
  final ValueChanged<String?> onReasonChanged;
  final VoidCallback onSubmit, onBack;

  const _Step3({
    required this.phone,
    required this.reason,
    required this.loading,
    required this.onReasonChanged,
    required this.onSubmit,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Reason for deleting (optional)',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _kTextPrimary)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            value: reason.isEmpty ? null : reason,
            hint: const Text('Select a reason…',
                style: TextStyle(fontSize: 13, color: _kTextMuted)),
            items: _reasons
                .map((r) => DropdownMenuItem(value: r, child: Text(r,
                    style: const TextStyle(fontSize: 13))))
                .toList(),
            onChanged: onReasonChanged,
            decoration: InputDecoration(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorderStrong)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: _kBorderStrong)),
            ),
          ),
        ]),
      ),

      const SizedBox(height: 16),

      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _kRedLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kError.withOpacity(0.2)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Final Confirmation',
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFFC53030))),
          const SizedBox(height: 6),
          Text('Deleting account for +91 $phone. This cannot be undone.',
              style: const TextStyle(
                  fontSize: 13, color: Color(0xFF9B2C2C), height: 1.4)),
        ]),
      ),

      const SizedBox(height: 24),

      _PrimaryButton(
        label: 'Delete My Account',
        icon: Icons.delete_forever_rounded,
        enabled: !loading,
        loading: loading,
        color: _kError,
        onTap: onSubmit,
      ),
      const SizedBox(height: 12),
      _SecondaryButton(label: 'Back', onTap: onBack),
    ]);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED BUTTON WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool enabled, loading;
  final Color color;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.enabled,
    required this.loading,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      height: 52,
      decoration: BoxDecoration(
        color: enabled ? color : _kBorderStrong,
        borderRadius: BorderRadius.circular(13),
        boxShadow: enabled
            ? [BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 14,
                offset: const Offset(0, 5))]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled ? onTap : null,
          borderRadius: BorderRadius.circular(13),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(label,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: enabled ? Colors.white : _kTextMuted)),
                      const SizedBox(width: 6),
                      Icon(icon,
                          size: 17,
                          color: enabled ? Colors.white : _kTextMuted),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SecondaryButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: onTap,
    style: OutlinedButton.styleFrom(
      side: const BorderSide(color: _kBorderStrong),
      foregroundColor: _kTextSecondary,
      minimumSize: const Size(double.infinity, 48),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13)),
    ),
    child: Text(label,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// OTP BOX
// ─────────────────────────────────────────────────────────────────────────────
class _OtpBox extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool hasError;
  final double boxW, boxH;
  final ValueChanged<String> onChanged;
  final ValueChanged<KeyEvent> onKeyEvent;

  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.hasError,
    required this.boxW,
    required this.boxH,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    widget.focusNode.addListener(() {
      if (mounted) setState(() => _focused = widget.focusNode.hasFocus);
    });
  }

  @override
  Widget build(BuildContext context) {
    final filled = widget.controller.text.isNotEmpty;
    final Color bg;
    final Color border;
    const double bw = 1.5;

    if (widget.hasError) {
      bg = _kRedLight; border = _kError;
    } else if (_focused) {
      bg = _kPrimaryLight.withOpacity(0.6); border = _kPrimary;
    } else if (filled) {
      bg = _kPrimaryLight; border = _kPrimary.withOpacity(0.5);
    } else {
      bg = const Color(0xFFF7FAFC); border = _kBorderStrong;
    }

    return KeyboardListener(
      focusNode: FocusNode(),
      onKeyEvent: widget.onKeyEvent,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: widget.boxW, height: widget.boxH,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: border, width: bw),
        ),
        child: TextField(
          controller: widget.controller,
          focusNode: widget.focusNode,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 1,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: _kTextPrimary, height: 1),
          decoration: const InputDecoration(
              border: InputBorder.none,
              counterText: '',
              contentPadding: EdgeInsets.zero),
          onChanged: widget.onChanged,
        ),
      ),
    );
  }
}
