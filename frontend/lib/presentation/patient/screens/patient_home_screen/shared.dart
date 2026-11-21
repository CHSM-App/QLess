part of '../patient_home_screen.dart';

// ── Colour Palette ─────────────────────────────────────────────────
const kPageBg = Color(0xFFF8F9FB);
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF1EA898);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);

const kBorder = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);

// Darker variants of the status colours. The base tones are tuned for fills
// and borders; on their own light backgrounds (kGreenLight/kAmberLight/
// kRedLight) they wash out, so text and icons use these instead. Each keeps
// the hue of its base colour and only drops in lightness, so they read as the
// same family rather than a second, louder palette.
const kSuccessDark = Color(0xFF2F855A);
const kWarningDark = Color(0xFFB7791F);
const kErrorDark = Color(0xFFC53030);

// Banner text ink. Neutral on purpose: a tinted background reads best with
// plain dark text, letting the fill, icon and border carry the status colour.
const kBannerInk = Color(0xFF1F2933);
const kPurple = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

// ── Specialty colour/icon helpers ──────────────────────────────────
const _kAccentPalette = [
  Color(0xFFFC8181),
  Color(0xFFF6AD55),
  Color(0xFF68D391),
  Color(0xFF9F7AEA),
  Color(0xFF3B82F6),
  Color(0xFF26C6B0),
  Color(0xFFF687B3),
  Color(0xFF4FD1C5),
  Color(0xFFED8936),
  Color(0xFF667EEA),
];
const _kIconPalette = <IconData>[
  Icons.favorite_rounded,
  Icons.face_retouching_natural,
  Icons.child_care_rounded,
  Icons.accessibility_new_rounded,
  Icons.psychology_rounded,
  Icons.local_hospital_rounded,
  Icons.pregnant_woman_rounded,
  Icons.visibility_rounded,
  Icons.medical_services_rounded,
  Icons.hearing_rounded,
];

int _hashIndex(String? s, int length) {
  if (s == null || s.isEmpty) return 0;
  var h = 0;
  for (final c in s.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % length;
}

Color _accentForSpec(String? s) =>
    _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
IconData _iconForSpec(String? s) =>
    _kIconPalette[_hashIndex(s, _kIconPalette.length)];

List<Map<String, dynamic>> _buildSpecialtyList(List<DoctorDetails> doctors) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final d in doctors) {
    final s = d.specialization?.trim();
    if (s != null && s.isNotEmpty && seen.add(s.toLowerCase())) {
      result.add({
        'name': s,
        'icon': _iconForSpec(s),
        'color': _accentForSpec(s),
      });
    }
  }
  return result;
}

// ── Flat card helper ────────────────────────────────────────────────
// Replaces the old neomorphic (soft-UI) surface with a clean flat card:
// white surface, a hairline border, and only a whisper of shadow so cards
// still separate from the page without the heavy embossed look. Every call
// site that used to ask for a "pressed" (inset) look now gets a subtly
// tinted flat surface instead — same call signature, flatter result.
const _kCardBorder = Color(0xFFEDF1F5);
const _kCardShadow = Color(0x0F1A202C);

BoxDecoration _neoBox({
  double radius = 14,
  Color color = Colors.white,
  bool pressed = false,
  Border? border,
}) {
  return BoxDecoration(
    color: pressed ? kPrimaryLight.withValues(alpha: 0.55) : color,
    borderRadius: BorderRadius.circular(radius),
    border:
        border ??
        Border.all(
          color: pressed ? kPrimary.withValues(alpha: 0.18) : _kCardBorder,
          width: 1,
        ),
    boxShadow: pressed
        ? const []
        : const [
            BoxShadow(color: _kCardShadow, offset: Offset(0, 2), blurRadius: 8),
          ],
  );
}

// ── Doctor avatar helper ───────────────────────────────────────────
Color _avatarBg(String? spec) {
  final c = _accentForSpec(spec);
  return c.withValues(alpha: 0.15);
}

Widget _doctorAvatar(String? spec, {double size = 46}) {
  final color = _accentForSpec(spec);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _avatarBg(spec),
      borderRadius: BorderRadius.circular(size * 0.27),
      border: Border.all(color: color.withValues(alpha: 0.2), width: 1.5),
    ),
    child: Icon(_iconForSpec(spec), color: color, size: size * 0.44),
  );
}

// ── Time helpers ───────────────────────────────────────────────────
DateTime? _timeTodayFromRaw(String? raw) {
  final value = raw?.trim();
  if (value == null ||
      value.isEmpty ||
      value == '--' ||
      value.toLowerCase() == 'null') {
    return null;
  }

  final now = DateTime.now();
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    final u = iso.toUtc();
    return DateTime(now.year, now.month, now.day, u.hour, u.minute);
  }

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([aApP][mM])?$',
  ).firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || minute > 59) return null;

  final meridiem = match.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    if (hour == 12) hour = 0;
    if (meridiem == 'pm') hour += 12;
  } else if (hour > 23) {
    return null;
  }

  return DateTime(now.year, now.month, now.day, hour, minute);
}

// ── Shimmer ────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.15,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: _anim.value),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  LOCATION SHEET
// ════════════════════════════════════════════════════════════════════
const List<String> _allCities = [
  'Bengaluru, IN',
  'Mumbai, IN',
  'Delhi, IN',
  'Hyderabad, IN',
  'Pune, IN',
  'Chennai, IN',
  'Kolkata, IN',
  'Ahmedabad, IN',
  'Jaipur, IN',
  'Surat, IN',
  'Lucknow, IN',
  'Kanpur, IN',
  'Nagpur, IN',
  'Indore, IN',
  'Thane, IN',
  'Bhopal, IN',
  'Visakhapatnam, IN',
  'Patna, IN',
  'Vadodara, IN',
  'Ghaziabad, IN',
  'Ludhiana, IN',
  'Agra, IN',
  'Nashik, IN',
  'Faridabad, IN',
  'Meerut, IN',
  'Rajkot, IN',
  'Varanasi, IN',
  'Srinagar, IN',
  'Aurangabad, IN',
  'Dhanbad, IN',
  'Amritsar, IN',
  'Navi Mumbai, IN',
  'Coimbatore, IN',
  'Madurai, IN',
  'Vijayawada, IN',
  'Guwahati, IN',
  'Chandigarh, IN',
  'Hubli, IN',
  'Mysuru, IN',
  'Tiruchirappalli, IN',
];

class _LocationSheet extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<String> onSelected;
  const _LocationSheet({
    required this.currentLocation,
    required this.onSelected,
  });
  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}
