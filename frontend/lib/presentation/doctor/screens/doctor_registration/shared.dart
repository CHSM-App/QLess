part of '../doctor_registration.dart';

// ── Colour palette (matches login + patient registration) ─────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF1EA898);
const kPrimaryDarker = Color(0xFF158578);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryGlow   = Color(0xFF4DD9C4);

const kBgSoft  = Color(0xFFF7FAFC);
const kSurface = Color(0xFFFFFFFF);
const kBg      = Color(0xFFF7FAFC);

const kTextPrimary   = Color(0xFF1A202C);
const kTextSecondary = Color(0xFF4A5568);
const kTextMuted     = Color(0xFF94A3B8);

const kBorder       = Color(0xFFF1F5F9);
const kBorderStrong = Color(0xFFE2E8F0);
const kDivider      = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple     = Color(0xFF9F7AEA);
const kPurpleLight= Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);

// ─── Schedule UI Models ──────────────────────────────────────────────────────
enum BookingMode { queue, slots, both }

class _TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;
  int? maxQueueLength;

  _TimeSlot({
    required this.startTime,
    required this.endTime,
    this.bookingMode = BookingMode.queue,
    this.slotDurationMinutes = 15,
    this.maxQueueLength,
  });
}

class _DaySchedule {
  final String dayName;
  final String shortName;
  bool isEnabled = false;
  List<_TimeSlot> timeSlots;

  _DaySchedule({
    required this.dayName,
    required this.shortName,
    List<_TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? [];
}

// One "Add Slot" entry: a single Queue/Slot time range applied to whichever
// days were selected when it was added. Multiple blocks can target the same
// day (e.g. a morning Queue block and an evening Slots block on Monday).
class _ScheduleBlock {
  Set<int> dayIndices;
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;
  int? maxQueueLength;

  _ScheduleBlock({
    required this.dayIndices,
    required this.startTime,
    required this.endTime,
    required this.bookingMode,
    required this.slotDurationMinutes,
    this.maxQueueLength,
  });
}

// ═════════════════════════════════════════════════════════════════════════════
// SIMPLE TITLE BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SimpleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  /// When null the back button is hidden (e.g. once the clinic is registered).
  final VoidCallback? onBack;

  const _SimpleTitleBar({
    required this.title,
    required this.subtitle,
    this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(bottom: BorderSide(color: kBorder, width: 1)),
          ),
          child: Row(
            children: [
              if (onBack != null) ...[
                Material(
                  color: kBgSoft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                    side: const BorderSide(color: kBorderStrong, width: 0.5),
                  ),
                  child: InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(11),
                    child: const SizedBox(
                      width: 38,
                      height: 38,
                      child: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 16,
                        color: kTextPrimary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medical_services_outlined,
                        size: 11, color: kPrimaryDarker),
                    SizedBox(width: 5),
                    Text(
                      'Doctor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP PROGRESS BAR
// ═════════════════════════════════════════════════════════════════════════════
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StepDot(
            number: 1,
            label: 'Personal',
            state: currentStep == 1
                ? _StepDotState.active
                : _StepDotState.done,
          ),
          _stepLine(currentStep >= 2),
          _StepDot(
            number: 2,
            label: 'Clinic',
            state: currentStep == 2
                ? _StepDotState.active
                : currentStep > 2
                    ? _StepDotState.done
                    : _StepDotState.pending,
          ),
          _stepLine(currentStep >= 3),
          _StepDot(
            number: 3,
            label: 'Schedule',
            state: currentStep == 3
                ? _StepDotState.active
                : _StepDotState.pending,
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? kPrimary : kBorderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

enum _StepDotState { active, done, pending }

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final _StepDotState state;

  const _StepDot({
    required this.number,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color circleBg;
    Color circleFg;
    Color labelColor;
    Widget content;

    switch (state) {
      case _StepDotState.active:
        circleBg = kPrimary;
        circleFg = Colors.white;
        labelColor = kPrimaryDarker;
        content = Text(
          '$number',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: circleFg),
        );
      case _StepDotState.done:
        circleBg = kPrimaryLight;
        circleFg = kPrimaryDark;
        labelColor = kPrimaryDark;
        content = const Icon(Icons.check_rounded, size: 14, color: kPrimaryDark);
      case _StepDotState.pending:
        circleBg = kBgSoft;
        circleFg = kTextMuted;
        labelColor = kTextMuted;
        content = Text(
          '$number',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: circleFg),
        );
    }

    final isActive = state == _StepDotState.active;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isActive ? 30 : 26,
          height: isActive ? 30 : 26,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: state == _StepDotState.pending
                ? Border.all(color: kBorderStrong, width: 1)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: kPrimary.withValues(alpha: 0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: content,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isActive ? FontWeight.w800 : FontWeight.w700,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: kTextSecondary,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: kBorder, height: 22, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON (gradient CTA)
// ═════════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimary, kPrimaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withValues(alpha: 0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 19),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CLINIC PHOTO GRID
// ═════════════════════════════════════════════════════════════════════════════
class _ClinicPhotoGrid extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPreview;

  const _ClinicPhotoGrid({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < 5;
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withValues(alpha: 0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kPurpleLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinic Photos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Showcase your space (${photos.length}/5)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: kBorder, height: 22, thickness: 1),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...List.generate(
                photos.length,
                (i) => _PhotoThumb(
                  file: photos[i],
                  onRemove: () => onRemove(i),
                  onTap: () => onPreview(i),
                ),
              ),
              if (canAdd)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: kPrimaryLight.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kPrimary.withValues(alpha: 0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: kPrimaryDark, size: 28),
                        SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: kPrimaryDarker,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumb({
    required this.file,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 86,
        height: 86,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file,
                    width: 86, height: 86, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: kTextPrimary.withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      );
}

// Single tappable field showing the whole Start→End range; opens
// _TimeRangePickerSheet so both ends are picked together in one step.
class _TimeRangePicker extends StatelessWidget {
  final String start, end;
  final VoidCallback onTap;
  const _TimeRangePicker(
      {required this.start, required this.end, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorderStrong),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 15, color: kPrimaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$start  →  $end',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: kTextMuted),
            ],
          ),
        ),
      );
}

// Bottom sheet letting the user set Start and End together, in one step,
// via two side-by-side time wheels. Confirms with a single "Done" tap.
class _TimeRangePickerSheet extends StatefulWidget {
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;
  const _TimeRangePickerSheet(
      {required this.initialStart, required this.initialEnd});

  @override
  State<_TimeRangePickerSheet> createState() => _TimeRangePickerSheetState();
}
