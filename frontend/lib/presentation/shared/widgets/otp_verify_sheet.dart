import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

/// Proves the user owns [mobile] before a registration or a mobile-number
/// change: sends an OTP (WhatsApp), checks the code with the server and
/// returns the short-lived `loginTicket` the server then requires. Returns
/// null if the user closes the sheet.
Future<String?> showOtpVerifySheet(
  BuildContext context,
  WidgetRef ref,
  String mobile,
) {
  final vm = ref.read(doctorLoginViewModelProvider.notifier);
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    isDismissible: false,
    constraints: const BoxConstraints(maxWidth: 480),
    builder: (_) => OtpVerifySheet(
      mobile: mobile,
      sendOtp: (m) => vm.sendOtp(OtpResponse(mobileNo: m)),
      verifyOtp: (m, otp) => vm.verifyOtp(OtpResponse(mobileNo: m, otp: otp)),
    ),
  );
}

/// Holds the last ticket so a retried submit (server error, validation
/// message) doesn't ask for a new OTP. The server accepts a ticket for 5
/// minutes; it is reused for 4, and only for the same number.
class OtpTicketCache {
  String? _mobile;
  String? _ticket;
  DateTime? _at;

  Future<String?> obtain(BuildContext context, WidgetRef ref, String mobile) async {
    final fresh = _at != null && DateTime.now().difference(_at!) < const Duration(minutes: 4);
    if (fresh && _mobile == mobile && _ticket != null) return _ticket;
    final ticket = await showOtpVerifySheet(context, ref, mobile);
    if (ticket != null) {
      _mobile = mobile;
      _ticket = ticket;
      _at = DateTime.now();
    }
    return ticket;
  }
}

class OtpVerifySheet extends StatefulWidget {
  const OtpVerifySheet({
    super.key,
    required this.mobile,
    required this.sendOtp,
    required this.verifyOtp,
  });

  final String mobile;
  final Future<OtpResponse> Function(String mobile) sendOtp;
  final Future<OtpResponse> Function(String mobile, String otp) verifyOtp;

  @override
  State<OtpVerifySheet> createState() => _OtpVerifySheetState();
}

class _OtpVerifySheetState extends State<OtpVerifySheet> {
  static const int otpLength = 6;
  static const int resendSeconds = 30;

  final _controller = TextEditingController();
  Timer? _timer;
  int _secondsLeft = 0;
  bool _busy = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // sendOtp updates a provider the parent screen watches; doing that during
    // build makes Riverpod throw and leaves the button stuck on "Sending code…".
    WidgetsBinding.instance.addPostFrameCallback((_) => _send());
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _busy = _sending = true;
      _error = null;
    });
    OtpResponse r;
    try {
      r = await widget.sendOtp(widget.mobile);
    } catch (_) {
      r = OtpResponse(status: 0);
    }
    if (!mounted) return;
    setState(() {
      _busy = _sending = false;
      if ((r.status ?? 0) != 1) _error = r.message ?? 'Could not send the OTP. Try again.';
      _secondsLeft = resendSeconds;
    });
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _secondsLeft--);
      if (_secondsLeft <= 0) t.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _controller.text.trim();
    if (code.length != otpLength) {
      setState(() => _error = 'Enter the $otpLength-digit OTP.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    OtpResponse r;
    try {
      r = await widget.verifyOtp(widget.mobile, code);
    } catch (_) {
      r = OtpResponse(status: 0);
    }
    if (!mounted) return;
    if ((r.status ?? 0) == 1 && (r.loginTicket ?? '').isNotEmpty) {
      Navigator.of(context).pop(r.loginTicket);
      return;
    }
    _controller.clear();
    setState(() {
      _busy = false;
      _error = 'Invalid OTP. Please try again.';
    });
  }

  Widget _digitBox(ThemeData theme, int i) {
    final scheme = theme.colorScheme;
    final text = _controller.text;
    final filled = i < text.length;
    final active = i == text.length && !_busy;
    final borderColor = _error != null
        ? scheme.error
        : active
            ? scheme.primary
            : scheme.outlineVariant;
    return Expanded(
      child: Container(
        height: 56,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: filled ? scheme.primary.withValues(alpha: 0.06) : scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: active ? 2 : 1),
        ),
        child: Text(filled ? text[i] : '', style: theme.textTheme.headlineSmall),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: _busy ? null : () => Navigator.of(context).pop(),
            ),
          ),
          Center(
            child: CircleAvatar(
              radius: 28,
              backgroundColor: scheme.primary.withValues(alpha: 0.12),
              child: Icon(Icons.sms_outlined, color: scheme.primary, size: 28),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verify mobile number',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text.rich(
            TextSpan(
              text: 'Enter the $otpLength-digit code sent on WhatsApp to\n',
              children: [
                TextSpan(
                  text: widget.mobile,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          // The boxes render the text of one invisible field, so typing,
          // paste, backspace and SMS autofill all behave natively.
          Stack(
            children: [
              Row(children: [for (var i = 0; i < otpLength; i++) _digitBox(theme, i)]),
              Positioned.fill(
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    key: const Key('otp_verify_field'),
                    controller: _controller,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    maxLength: otpLength,
                    showCursor: false,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(counterText: '', border: InputBorder.none),
                    onChanged: (v) {
                      setState(() => _error = null);
                      if (v.length == otpLength && !_busy) _verify();
                    },
                    onSubmitted: (_) => _busy ? null : _verify(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 28,
            child: _error == null
                ? null
                : Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
                    ),
                  ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('otp_verify_button'),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: _busy ? null : _verify,
            child: _busy
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Text(_sending ? 'Sending code…' : 'Verifying…'),
                    ],
                  )
                : const Text('Verify'),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("Didn't get the code?", style: theme.textTheme.bodyMedium),
              TextButton(
                onPressed: _busy || _secondsLeft > 0 ? null : _send,
                child: Text(_secondsLeft > 0 ? 'Resend in ${_secondsLeft}s' : 'Resend OTP'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
