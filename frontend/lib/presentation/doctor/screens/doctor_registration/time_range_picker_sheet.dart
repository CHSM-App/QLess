part of '../doctor_registration.dart';

class _TimeRangePickerSheetState extends State<_TimeRangePickerSheet> {
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end   = widget.initialEnd;

  DateTime _toDateTime(TimeOfDay t) => DateTime(2024, 1, 1, t.hour, t.minute);

  bool get _isValid =>
      (_start.hour * 60 + _start.minute) < (_end.hour * 60 + _end.minute);

  Widget _buildWheel(String label, TimeOfDay value, ValueChanged<TimeOfDay> onChange) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 160,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _toDateTime(value),
              onDateTimeChanged: (dt) =>
                  onChange(TimeOfDay(hour: dt.hour, minute: dt.minute)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: kBorderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Text(
              'Select Time Range',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildWheel('Start', _start, (v) => setState(() => _start = v)),
                _buildWheel('End', _end, (v) => setState(() => _end = v)),
              ],
            ),
            if (!_isValid) ...[
              const SizedBox(height: 8),
              const Text(
                'End time must be after start time.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kError,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, (_start, _end))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  disabledBackgroundColor: kBorderStrong,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotDurationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  static const _opts = [10, 15, 20, 30, 45, 60];
  const _SlotDurationPicker(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _opts.map((min) {
          final sel = value == min;
          return GestureDetector(
            onTap: () => onChanged(min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                        colors: [kPrimary, kPrimaryDark],
                      )
                    : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: sel ? kPrimary : kBorderStrong),
              ),
              child: Text(
                '${min}m',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : kTextSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ─── Wheel Picker ─────────────────────────────────────────────────────────
class _WheelPicker extends StatefulWidget {
  final int value, max;
  final ValueChanged<int> onChanged;
  const _WheelPicker(
      {super.key,
      required this.value,
      required this.max,
      required this.onChanged});

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  late final FixedExtentScrollController _ctrl;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur = widget.value.clamp(0, widget.max - 1);
    _ctrl = FixedExtentScrollController(initialItem: _cur);
  }

  @override
  void didUpdateWidget(covariant _WheelPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final target = widget.value.clamp(0, widget.max - 1);
      final delta = (target - _cur).abs();
      if (delta <= 3) {
        _ctrl.animateToItem(target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic);
      } else {
        _ctrl.jumpToItem(target);
      }
      _cur = target;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 30,
            diameterRatio: 2.0,
            perspective: 0.002,
            physics: const FixedExtentScrollPhysics(),
            controller: _ctrl,
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _cur = i);
              widget.onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max,
              builder: (_, i) {
                final sel = i == _cur;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      fontSize: sel ? 17 : 12,
                      fontWeight:
                          sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? kPrimaryDark : kTextMuted,
                    ),
                    child: Text(i.toString().padLeft(2, '0')),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
              letterSpacing: 0.1,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ],
      );
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🇮🇳', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text(
            '+91',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 22,
            child: VerticalDivider(
                color: kBorderStrong, width: 1, thickness: 1),
          ),
          SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _LocationButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: kPrimary.withValues(alpha: 0.3), width: 1),
              ),
              child: Icon(icon, color: kPrimaryDark, size: 20),
            ),
          ),
        ),
      );
}

class _GenderSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _GenderSelector(
      {required this.options,
      required this.selected,
      required this.onChanged});

  static const _iconMap = {
    'male': Icons.male_rounded,
    'female': Icons.female_rounded,
    'other': Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(options.length, (i) {
          final label = options[i];
          final icon = _iconMap[label.toLowerCase()] ??
              Icons.person_outline_rounded;
          final isSelected = selected == label;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: i < options.length - 1 ? 7 : 0),
              child: GestureDetector(
                onTap: () => onChanged(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryLight : kBgSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? kPrimary : kBorderStrong,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimary.withValues(alpha: 0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? kPrimaryDarker : kTextSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? kPrimaryDarker
                              : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: kTextMuted),
          SizedBox(width: 6),
          Text(
            'Your data is protected and encrypted',
            style: TextStyle(
              fontSize: 11.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// IMAGE SOURCE BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _ImageSourceSheet extends StatelessWidget {
  final String title;
  const _ImageSourceSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: kBorderStrong,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: kPrimaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Photo',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 1),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    icon: Icons.camera_alt_rounded,
                    iconColor: kPrimary,
                    iconBg: kPrimaryLight,
                    label: 'Camera',
                    subtitle: 'Take photo',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_library_rounded,
                    iconColor: kPurple,
                    iconBg: kPurpleLight,
                    label: 'Gallery',
                    subtitle: 'Pick photo',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: kBgSoft,
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
                color: iconBg.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: iconBg)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(height: 10),
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: iconColor)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// MAP PICKER SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _MapPickerScreen extends StatefulWidget {
  final gmap.LatLng initialLatLng;
  const _MapPickerScreen({required this.initialLatLng});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}
