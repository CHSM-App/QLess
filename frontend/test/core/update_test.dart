import 'package:flutter_test/flutter_test.dart';
import 'package:qless/core/update/semver.dart';
import 'package:qless/core/update/update_check_provider.dart';

UpdateStateResult run({
  String current = '1.0.6',
  String latest = '',
  String min = '',
  String below = '',
  bool force = false,
}) {
  final s = evaluateUpdate(
    currentVersion: current,
    latestVersion: latest,
    minimumSupportedVersion: min,
    forceUpdateBelowVersion: below,
    forceUpdateFlag: force,
  );
  return UpdateStateResult(s.updateAvailable, s.forceUpdate);
}

class UpdateStateResult {
  final bool available;
  final bool force;
  UpdateStateResult(this.available, this.force);
}

void main() {
  extraCases();
  group('SemVer', () {
    test('tryParse handles valid, build metadata, and invalid input', () {
      expect(SemVer.tryParse('1.2.3'), const SemVer(1, 2, 3));
      expect(SemVer.tryParse('1.0.6+8'), const SemVer(1, 0, 6));
      expect(SemVer.tryParse('v2.1'), const SemVer(2, 1, 0));
      expect(SemVer.tryParse(''), isNull);
      expect(SemVer.tryParse(null), isNull);
      expect(SemVer.tryParse('abc'), isNull);
      expect(SemVer.tryParse('1.x.0'), isNull);
    });

    test('comparison operators', () {
      expect(SemVer.tryParse('1.0.10')! > SemVer.tryParse('1.0.9')!, isTrue);
      expect(SemVer.tryParse('1.10.0')! > SemVer.tryParse('1.9.9')!, isTrue);
      expect(SemVer.tryParse('2.0.0')! >= SemVer.tryParse('2.0.0')!, isTrue);
      expect(SemVer.tryParse('1.0.0')! < SemVer.tryParse('1.0.1')!, isTrue);
      expect(SemVer.tryParse('1.0.0')! <= SemVer.tryParse('1.0.0')!, isTrue);
      expect(SemVer.tryParse('1.0')! == SemVer.tryParse('1.0.0')!, isTrue);
    });
  });

  group('evaluateUpdate', () {
    test('up to date when latest <= current', () {
      final r = run(latest: '1.0.6');
      expect(r.available, isFalse);
      expect(run(latest: '1.0.5').available, isFalse);
    });

    test('up to date when versions are unparsable / not configured', () {
      expect(run(latest: '').available, isFalse);
      expect(run(latest: 'garbage').available, isFalse);
      expect(run(current: 'bad', latest: '2.0.0').available, isFalse);
    });

    test('optional update when latest > current and no force rule matches', () {
      final r = run(latest: '1.1.0', min: '1.0.0', below: '1.0.0');
      expect(r.available, isTrue);
      expect(r.force, isFalse);
    });

    test('force via force_update flag', () {
      final r = run(latest: '1.1.0', force: true);
      expect(r.available, isTrue);
      expect(r.force, isTrue);
    });

    test('force when current < minimum_supported_version', () {
      expect(run(latest: '1.1.0', min: '1.0.7').force, isTrue);
    });

    test('force when current < force_update_below_version', () {
      expect(run(latest: '1.1.0', below: '1.0.7').force, isTrue);
    });

    test('no force when current equals the thresholds', () {
      final r = run(latest: '1.1.0', min: '1.0.6', below: '1.0.6');
      expect(r.force, isFalse);
    });
  });
}

// Extra cases for dialog text pass-through and parsing edge cases.
void extraCases() {
  group('evaluateUpdate extras', () {
    test('Remote Config title/message pass through; empty stays empty', () {
      final s = evaluateUpdate(
        currentVersion: '1.0.6',
        latestVersion: '1.0.7',
        title: 'Hi',
        message: '',
      );
      expect(s.dialogTitle, 'Hi');
      expect(s.dialogMessage, '');
    });

    test('latest_version with build number still compares by x.y.z', () {
      final s = evaluateUpdate(currentVersion: '1.0.6', latestVersion: '1.0.7+9');
      expect(s.updateAvailable, isTrue);
    });
  });
}
