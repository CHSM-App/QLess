import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qless/domain/models/otp_response.dart';
import 'package:qless/presentation/shared/widgets/otp_verify_sheet.dart';

void main() {
  late List<String> sent;
  String? result;
  bool closed = false;

  Future<void> open(WidgetTester tester, {bool verifyOk = true}) async {
    sent = [];
    result = null;
    closed = false;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () async {
              result = await showModalBottomSheet<String>(
                context: context,
                isScrollControlled: true,
                builder: (_) => OtpVerifySheet(
                  mobile: '9123400000',
                  sendOtp: (m) async {
                    sent.add(m);
                    return OtpResponse(status: 1);
                  },
                  verifyOtp: (m, otp) async => verifyOk && otp == '123456'
                      ? OtpResponse(status: 1, loginTicket: 'ticket-$m')
                      : OtpResponse(status: 0, message: 'Invalid OTP'),
                ),
              );
              closed = true;
            },
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('sends the OTP on open and returns the ticket on a right code', (tester) async {
    await open(tester);
    expect(sent, ['9123400000']);
    await tester.enterText(find.byKey(const Key('otp_verify_field')), '123456');
    await tester.tap(find.byKey(const Key('otp_verify_button')));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, 'ticket-9123400000');
  });

  testWidgets('a wrong code (auto-submitted at 6 digits) keeps the sheet open with an error', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('otp_verify_field')), '000000');
    await tester.pump();
    expect(find.text('Invalid OTP. Please try again.'), findsOneWidget);
    expect(closed, isFalse);
  });

  testWidgets('a short code is refused before calling the server', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const Key('otp_verify_field')), '12');
    await tester.tap(find.byKey(const Key('otp_verify_button')));
    await tester.pump();
    expect(find.text('Enter the 6-digit OTP.'), findsOneWidget);
  });

  testWidgets('resend is locked for 30 s, then sends again', (tester) async {
    await open(tester);
    expect(find.textContaining('Resend in'), findsOneWidget);
    await tester.pump(const Duration(seconds: 31));
    await tester.tap(find.text('Resend OTP'));
    await tester.pump();
    expect(sent.length, 2);
  });

  testWidgets('closing returns null', (tester) async {
    await open(tester);
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(closed, isTrue);
    expect(result, isNull);
  });
}
