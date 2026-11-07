/// Minimal semantic version (major.minor.patch). Build metadata ("+8") and
/// pre-release suffixes ("-beta") are ignored for comparison.
class SemVer implements Comparable<SemVer> {
  final int major;
  final int minor;
  final int patch;

  const SemVer(this.major, [this.minor = 0, this.patch = 0]);

  static final RegExp _pattern = RegExp(r'^v?(\d+)(?:\.(\d+))?(?:\.(\d+))?$');

  /// Returns null for empty / malformed input (e.g. Remote Config not set).
  static SemVer? tryParse(String? input) {
    if (input == null) return null;
    var s = input.trim();
    if (s.isEmpty) return null;
    s = s.split('+').first.split('-').first;
    final m = _pattern.firstMatch(s);
    if (m == null) return null;
    return SemVer(
      int.parse(m.group(1)!),
      int.parse(m.group(2) ?? '0'),
      int.parse(m.group(3) ?? '0'),
    );
  }

  @override
  int compareTo(SemVer other) {
    if (major != other.major) return major.compareTo(other.major);
    if (minor != other.minor) return minor.compareTo(other.minor);
    return patch.compareTo(other.patch);
  }

  bool operator <(SemVer other) => compareTo(other) < 0;
  bool operator <=(SemVer other) => compareTo(other) <= 0;
  bool operator >(SemVer other) => compareTo(other) > 0;
  bool operator >=(SemVer other) => compareTo(other) >= 0;

  @override
  bool operator ==(Object other) => other is SemVer && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}
