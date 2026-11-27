import 'package:flutter_test/flutter_test.dart';
import 'package:qless/presentation/shared/reports/report_screens.dart';

void main() {
  test('phone on report matches the last 10 digits', () {
    expect(reportMatchScore('', '+91 98765-43210', 'Anyone', '9876543210'), 2);
    expect(reportMatchScore('', '98765', 'Anyone', '9876543210'), 0); // too short to trust
  });

  test('name matches in any order, ignoring titles and case', () {
    expect(reportMatchScore('MR. PARAB ARJUN', '', 'Arjun Parab', ''), 1);
    expect(reportMatchScore('Arjun', '', 'Arjun Parab', ''), 1);
    expect(reportMatchScore('Arjun Patil', '', 'Arjun Parab', ''), 0);
    expect(reportMatchScore('', '', 'Arjun Parab', ''), 0);
  });
}
