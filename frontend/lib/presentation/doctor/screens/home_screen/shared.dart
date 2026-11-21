part of '../home_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

// Page & card surfaces
// const kPageBg         = Color(0xFFF8F9FB); // grey-50
const kPageBg         = Color(0xFFFAFAFA); // grey-50
const kCardBg         = Colors.white;
const kCardBorder     = Color(0xFFE2E8F0);

// Primary (teal)
const kPrimary        = Color(0xFF1D9E75);
const kPrimaryDark    = Color(0xFF0F6E56);
const kPrimaryLight   = Color(0xFFE1F5EE);
const kPrimaryLighter = Color(0xFFF0FBF8);

// Text
const kTextPrimary    = Color(0xFF0F172A);
const kTextSecondary  = Color(0xFF64748B);
const kTextMuted      = Color(0xFF94A3B8);

const kBorder         = Color(0xFFE2E8F0);
const kHairline       = Color(0xFFE2E8F0);

// Green
const kGreen          = Color(0xFF22C55E);
const kGreenDark      = Color(0xFF166534);
const kGreenLight     = Color(0xFFF0FDF4);
const kGreenBorder    = Color(0xFFBBF7D0);

// Amber
const kAmber          = Color(0xFFF59E0B);
const kAmberDark      = Color(0xFF92400E);
const kAmberLight     = Color(0xFFFEF3C7);
const kAmberBorder    = Color(0xFFFDE68A);

// Red
const kRed            = Color(0xFFEF4444);
const kRedDark        = Color(0xFF7F1D1D);
const kRedLight       = Color(0xFFFEE2E2);
const kRedBorder      = Color(0xFFFECACA);

// Purple
const kPurple         = Color(0xFF8B5CF6);
const kPurpleDark     = Color(0xFF4C1D95);
const kPurpleLight    = Color(0xFFEDE9FE);
const kPurpleBorder   = Color(0xFFDDD6FE);

// Blue (waiting stat)
const kBlueLight      = Color(0xFFEFF6FF);
const kBlueBorder     = Color(0xFFBFDBFE);
const kBlueDark       = Color(0xFF1E40AF);

// No shadows, no gradients
const List<BoxShadow> kNoShadow = [];

// Desktop layout
const _kHomeWideBreak = 900.0;
const _kHomeFullBreak = 1300.0;
const _kHomeSideWidth = 260.0;

int? _minutesFromTimeString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final dt = DateTime.tryParse(value);
  if (dt != null) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return local.hour * 60 + local.minute;
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)?',
          caseSensitive: false)
      .firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) return null;

  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour != 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

bool _hasSessionEndedToday(String? endTime) {
  final endMinutes = _minutesFromTimeString(endTime);
  if (endMinutes == null) return false;
  final now = DateTime.now();
  return now.hour * 60 + now.minute >= endMinutes;
}

class _Tip {
  final String emoji;
  final String title;
  final String body;
  const _Tip(this.emoji, this.title, this.body);
}

const List<_Tip> _kDoctorTips = [
  _Tip('⏸', 'Pause Queue',
      'Tap Pause anytime to take a quick break — patients see the live status update instantly.'),
  _Tip('⚠️', 'Emergency Pause',
      'Use the warning icon for urgent breaks — the queue order stays intact when you resume.'),
  _Tip('⏭', 'Skip a Patient',
      'No-show? Tap Skip to move on. Skipped patients can rejoin with a fresh token.'),
  _Tip('🗓', 'Set Your Schedule',
      'Use Edit Schedule to add weekly time slots, max queue length and slot duration.'),
  _Tip('💊', 'Build Medicine Library',
      'Add common medicines once in Edit Medicine — pick them faster while prescribing.'),
  _Tip('📋', 'Patient History',
      'Open Patient History to review past visits, prescriptions and notes in one place.'),
  _Tip('🔄', 'Pull to Refresh',
      'Swipe down on the home screen to fetch the latest queue and appointment status.'),
  _Tip('✕', 'Close the Queue',
      'Tap Close at the end of a session — frees the slot and updates today\'s stats.'),
];

// ─────────────────────────────────────────────────────────────────────────────
// ARRIVED BLINK — highlights a skipped patient who tapped "I've Arrived"
// ─────────────────────────────────────────────────────────────────────────────

class _ArrivedBlinkBadge extends StatefulWidget {
  final Widget child;
  const _ArrivedBlinkBadge({required this.child});

  @override
  State<_ArrivedBlinkBadge> createState() => _ArrivedBlinkBadgeState();
}

class _ArrivedBlinkBadgeState extends State<_ArrivedBlinkBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.10 * _ctrl.value,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: kGreen.withValues(alpha: 0.35 + 0.35 * _ctrl.value),
                blurRadius: 10 + 6 * _ctrl.value,
                spreadRadius: 1 + 2 * _ctrl.value,
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN INLINE PANEL
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _WalkInDialog extends StatelessWidget {
  final VoidCallback onBooked;
  final void Function(int appointmentId)? onAutoStarted;
  const _WalkInDialog({required this.onBooked, this.onAutoStarted});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenH * 0.80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.person_add_rounded, size: 16, color: kPrimaryDark),
              ),
              const SizedBox(width: 10),
              const Text('Add Walk-in Patient',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20, color: kTextSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          // ── Body ─────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: _WalkInInlinePanel(onBooked: onBooked, onAutoStarted: onAutoStarted),
            ),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN INLINE PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _WalkInInlinePanel extends ConsumerStatefulWidget {
  final VoidCallback onBooked;
  // Server started the walk-in straight away (idle queue) — open its prescription.
  final void Function(int appointmentId)? onAutoStarted;
  const _WalkInInlinePanel({required this.onBooked, this.onAutoStarted});

  @override
  ConsumerState<_WalkInInlinePanel> createState() => _WalkInInlinePanelState();
}
