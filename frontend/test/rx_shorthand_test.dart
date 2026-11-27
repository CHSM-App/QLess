import 'package:flutter_test/flutter_test.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';

void main() {
  test('shorthand: dosage, days, food', () {
    final r = parseRxShorthand('1-0-1 5d AF');
    expect(r.dosage, '1-0-1');
    expect(r.duration, '5 days');
    expect(r.timing, 'After Food');
  });

  test('shorthand: weeks, split "5 days", bedtime, junk ignored', () {
    expect(parseRxShorthand('0-0-1 2w hs').duration, '2 weeks');
    expect(parseRxShorthand('0-0-1 2w hs').timing, 'At Bedtime');
    expect(parseRxShorthand('½-0-½ 5 days xyz').duration, '5 days');
    expect(parseRxShorthand('1-1-1 1m').duration, '1 month');
    expect(parseRxShorthand('').dosage, isNull);
  });
}
