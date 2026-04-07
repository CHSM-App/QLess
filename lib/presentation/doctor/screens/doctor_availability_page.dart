import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ─── UI Models ─────────────────────────────────────────────────────────────────

enum BookingMode { queue, slots, both }

class TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.bookingMode = BookingMode.queue,
    this.slotDurationMinutes = 15,
  });
}

class DaySchedule {
  final String dayName;
  final String shortName;
  bool isEnabled;
  bool isExpanded;
  List<TimeSlot> timeSlots;

  DaySchedule({
    required this.dayName,
    required this.shortName,
    this.isEnabled = false,
    this.isExpanded = false,
    List<TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? [];
}

// ─── Page ──────────────────────────────────────────────────────────────────────

class DoctorAvailabilityPage extends ConsumerStatefulWidget {
  const DoctorAvailabilityPage({super.key});

  @override
  ConsumerState<DoctorAvailabilityPage> createState() =>
      _DoctorAvailabilityPageState();
}

class _DoctorAvailabilityPageState
    extends ConsumerState<DoctorAvailabilityPage> {
  // Fixed order — must match API day name strings
  static const _dayMeta = [
    ('Monday', 'MON'),
    ('Tuesday', 'TUE'),
    ('Wednesday', 'WED'),
    ('Thursday', 'THU'),
    ('Friday', 'FRI'),
    ('Saturday', 'SAT'),
    ('Sunday', 'SUN'),
  ];

  late List<DaySchedule> _days;

  // Tracks which model instance we last hydrated from so build() doesn't
  // re-hydrate on every unrelated state change (e.g. isLoading flip).
  DoctorScheduleModel? _hydratedFrom;

  @override
  void initState() {
    super.initState();
    _days = _dayMeta
        .map((m) => DaySchedule(dayName: m.$1, shortName: m.$2))
        .toList();

    // Trigger fetch after the first frame so providers are ready
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doctorId =
          ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
      ref
          .read(doctorSettingsViewModelProvider.notifier)
          .getDoctorSchedule(doctorId);
    });
  }

  // ── Hydration: DoctorScheduleModel → _days ───────────────────────────────────

  /// Parses "HH:mm:ss" or "HH:mm" → [TimeOfDay]. Falls back to 09:00.
  TimeOfDay _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final parts = raw.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  /// API int → BookingMode: 1 = queue, 2 = slots, 3 = both
  BookingMode _intToBookingMode(int? v) {
    switch (v) {
      case 2:
        return BookingMode.slots;
      case 3:
        return BookingMode.both;
      default:
        return BookingMode.queue;
    }
  }

  void _hydrateFromModel(DoctorScheduleModel model) {
    // Index API days by lowercase name for O(1) lookup
    final apiDays = {
      for (final d in model.schedule ?? <DayScheduleModel>[])
        (d.day ?? '').toLowerCase(): d
    };

    setState(() {
      for (final day in _days) {
        final api = apiDays[day.dayName.toLowerCase()];
        if (api == null) continue;

        day.isEnabled = (api.isEnabled ?? 0) == 1;
        day.isExpanded = false;
        day.timeSlots = (api.slots ?? []).map((s) {
          return TimeSlot(
            startTime: _parseTime(s.startTime),
            endTime: _parseTime(s.endTime),
            bookingMode: _intToBookingMode(s.bookingMode),
            slotDurationMinutes: s.slotDuration ?? 15,
          );
        }).toList();
      }
    });

    _hydratedFrom = model;
  }

  // ── Build model: _days → DoctorScheduleModel ─────────────────────────────────

  String _timeOfDayToString(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  /// BookingMode → API int: queue = 1, slots = 2, both = 3
  int _bookingModeToInt(BookingMode mode) {
    switch (mode) {
      case BookingMode.queue:
        return 1;
      case BookingMode.slots:
        return 2;
      case BookingMode.both:
        return 3;
    }
  }

  DoctorScheduleModel _buildScheduleModel() {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

    return DoctorScheduleModel(
      doctorId: doctorId,
      schedule: _days.map((day) {
        return DayScheduleModel(
          day: day.dayName,
          isEnabled: day.isEnabled ? 1 : 0,
          slots: day.timeSlots.map((slot) {
            return TimeSlotModel(
              startTime: _timeOfDayToString(slot.startTime),
              endTime: _timeOfDayToString(slot.endTime),
              bookingMode: _bookingModeToInt(slot.bookingMode),
              // slotDuration is irrelevant for queue-only mode
              slotDuration: slot.bookingMode == BookingMode.queue
                  ? null
                  : slot.slotDurationMinutes,
            );
          }).toList(),
        );
      }).toList(),
    );
  }

  // ── UI mutations ─────────────────────────────────────────────────────────────

  void _toggleDay(int index, bool value) {
    setState(() {
      _days[index].isEnabled = value;
      if (!value) _days[index].isExpanded = false;
    });
  }

  void _toggleExpand(int index) {
    setState(() {
      if (_days[index].isEnabled) {
        _days[index].isExpanded = !_days[index].isExpanded;
      }
    });
  }

  void _addTimeSlot(int dayIndex) {
    setState(() {
      _days[dayIndex].timeSlots.add(
        TimeSlot(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime: const TimeOfDay(hour: 12, minute: 0),
        ),
      );
    });
  }

  void _removeTimeSlot(int dayIndex, int slotIndex) {
    setState(() {
      _days[dayIndex].timeSlots.removeAt(slotIndex);
      // Auto-disable the day when its last slot is removed
      if (_days[dayIndex].timeSlots.isEmpty) {
        _days[dayIndex].isEnabled = false;
        _days[dayIndex].isExpanded = false;
      }
    });
  }

  void _updateTimeSlot(int dayIndex, int slotIndex, TimeSlot updated) {
    setState(() => _days[dayIndex].timeSlots[slotIndex] = updated);
  }

  // ── Save ─────────────────────────────────────────────────────────────────────

  Future<void> _saveSchedule() async {
    // Validation: overlapping slots within the same day
    for (final day in _days) {
      if (!day.isEnabled) continue;
      final slots = day.timeSlots;
      for (int i = 0; i < slots.length; i++) {
        for (int j = i + 1; j < slots.length; j++) {
          final aStart = slots[i].startTime.hour * 60 + slots[i].startTime.minute;
          final aEnd   = slots[i].endTime.hour   * 60 + slots[i].endTime.minute;
          final bStart = slots[j].startTime.hour * 60 + slots[j].startTime.minute;
          final bEnd   = slots[j].endTime.hour   * 60 + slots[j].endTime.minute;
          if (aStart < bEnd && bStart < aEnd) {
            setState(() => day.isExpanded = true);
            _showSnackBar(
              '${day.dayName} has overlapping time slots. '
              'Please fix them before saving.',
              isError: true,
            );
            return;
          }
        }
      }
    }

    // Validation: every enabled day must have ≥1 slot
    final invalidDays =
        _days.where((d) => d.isEnabled && d.timeSlots.isEmpty).toList();

    if (invalidDays.isNotEmpty) {
      final names = invalidDays.map((d) => d.dayName).join(', ');
      setState(() {
        for (final day in invalidDays) {
          day.isExpanded = true;
        }
      });
      _showSnackBar(
        '$names ${invalidDays.length == 1 ? 'is' : 'are'} enabled but '
        '${invalidDays.length == 1 ? 'has' : 'have'} no time slots. '
        'Please add at least one slot or turn the day off.',
        isError: true,
      );
      return;
    }

    // Delegate to ViewModel
    await ref
        .read(doctorSettingsViewModelProvider.notifier)
        .saveDoctorSchedule(_buildScheduleModel());

    if (!mounted) return;

    final error = ref.read(doctorSettingsViewModelProvider).errorMessage;
    if (error.isEmpty) {
      HapticFeedback.lightImpact();
      _showSnackBar('Schedule saved successfully');
    } else {
      _showSnackBar(error, isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.warning_amber_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(
                child:
                    Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor:
            isError ? const Color(0xFFE05C3A) : const Color(0xFF2D7DD2),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final settingsState = ref.watch(doctorSettingsViewModelProvider);

    // Hydrate _days whenever a new schedule arrives — guarded by identity check
    // to avoid repeated setState on unrelated state updates (isLoading, etc.)
    final loaded = settingsState.doctorSchedule;
    if (loaded != null && !identical(loaded, _hydratedFrom)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrateFromModel(loaded);
      });
    }

    final isLoading = settingsState.isLoading;
    final isTablet = MediaQuery.of(context).size.width >= 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FC),
      appBar: _buildAppBar(isLoading),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints:
                BoxConstraints(maxWidth: isTablet ? 680 : double.infinity),
            child: Column(
              children: [
                // Inline error banner (shown after a failed load or save)
                if (settingsState.errorMessage.isNotEmpty && !isLoading)
                  _ErrorBanner(message: settingsState.errorMessage),

                Expanded(
                  child: isLoading
                      ? const _LoadingShimmer()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(
                            horizontal: isTablet ? 24 : 16,
                            vertical: 16,
                          ),
                          itemCount: _days.length,
                          itemBuilder: (context, index) {
                            return _DayCard(
                              schedule: _days[index],
                              onToggle: (val) => _toggleDay(index, val),
                              onTapHeader: () => _toggleExpand(index),
                              onAddSlot: () => _addTimeSlot(index),
                              onRemoveSlot: (si) =>
                                  _removeTimeSlot(index, si),
                              onUpdateSlot: (si, updated) =>
                                  _updateTimeSlot(index, si, updated),
                            );
                          },
                        ),
                ),

                _buildSaveBar(isTablet, isLoading),
              ],
            ),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLoading) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Availability',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F1923),
              letterSpacing: -0.5,
            ),
          ),
          Text(
            'Set your weekly schedule',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(isLoading ? 2.0 : 1.0),
        child: isLoading
            ? const LinearProgressIndicator(
                minHeight: 2,
                color: Color(0xFF2D7DD2),
                backgroundColor: Color(0xFFEEEFF3),
              )
            : Container(height: 1, color: const Color(0xFFEEEFF3)),
      ),
    );
  }

  Widget _buildSaveBar(bool isTablet, bool isLoading) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          isTablet ? 24 : 16, 12, isTablet ? 24 : 16, 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFEEEFF3))),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : _saveSchedule,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2D7DD2),
            disabledBackgroundColor:
                const Color(0xFF2D7DD2).withOpacity(0.5),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Save Schedule',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}

// ─── Error Banner ──────────────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: const Color(0xFFFFF3F0),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: Color(0xFFE05C3A), size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message,
                style:
                    const TextStyle(fontSize: 13, color: Color(0xFFE05C3A))),
          ),
        ],
      ),
    );
  }
}

// ─── Loading Shimmer ───────────────────────────────────────────────────────────

class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();

  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _anim,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        itemCount: 7,
        itemBuilder: (_, __) => Container(
          margin: const EdgeInsets.only(bottom: 10),
          height: 72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFEEEFF3)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 12,
                        width: 80,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        height: 10,
                        width: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF2F3F7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F3F7),
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Day Card ──────────────────────────────────────────────────────────────────

class _DayCard extends StatelessWidget {
  final DaySchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapHeader;
  final VoidCallback onAddSlot;
  final ValueChanged<int> onRemoveSlot;
  final void Function(int, TimeSlot) onUpdateSlot;

  const _DayCard({
    required this.schedule,
    required this.onToggle,
    required this.onTapHeader,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onUpdateSlot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: schedule.isEnabled
              ? const Color(0xFF2D7DD2).withOpacity(0.25)
              : const Color(0xFFEEEFF3),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildHeader(),
          AnimatedCrossFade(
            firstChild: const SizedBox(width: double.infinity),
            secondChild: _buildExpandedContent(),
            crossFadeState: (schedule.isExpanded && schedule.isEnabled)
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
            sizeCurve: Curves.easeInOut,
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: onTapHeader,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: schedule.isEnabled
                    ? const Color(0xFF2D7DD2).withOpacity(0.1)
                    : const Color(0xFFF2F3F7),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                schedule.shortName,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: schedule.isEnabled
                      ? const Color(0xFF2D7DD2)
                      : const Color(0xFFB0B5BF),
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.dayName,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: schedule.isEnabled
                          ? const Color(0xFF0F1923)
                          : const Color(0xFFB0B5BF),
                    ),
                  ),
                  if (schedule.isEnabled && schedule.timeSlots.isNotEmpty)
                    Text(
                      '${schedule.timeSlots.length} time slot${schedule.timeSlots.length > 1 ? 's' : ''}',
                      style:
                          TextStyle(fontSize: 12, color: Colors.grey[500]),
                    )
                  else if (!schedule.isEnabled)
                    Text('Unavailable',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400]))
                  else
                    Text('No slots added',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey[400])),
                ],
              ),
            ),
            if (schedule.isEnabled)
              AnimatedRotation(
                turns: schedule.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: Icon(Icons.keyboard_arrow_down_rounded,
                    color: Colors.grey[400], size: 22),
              ),
            const SizedBox(width: 8),
            Transform.scale(
              scale: 0.85,
              child: Switch(
                value: schedule.isEnabled,
                onChanged: onToggle,
                activeColor: const Color(0xFF2D7DD2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedContent() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFEEEFF3))),
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ...schedule.timeSlots.asMap().entries.map((entry) {
            return _TimeSlotCard(
              index: entry.key,
              slot: entry.value,
              allSlots: schedule.timeSlots,
              onRemove: () => onRemoveSlot(entry.key),
              onUpdate: (updated) => onUpdateSlot(entry.key, updated),
            );
          }),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddSlot,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add Time Slot'),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF2D7DD2),
                side: const BorderSide(
                    color: Color(0xFF2D7DD2), width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Time Slot Card ────────────────────────────────────────────────────────────

class _TimeSlotCard extends StatefulWidget {
  final int index;
  final TimeSlot slot;
  final List<TimeSlot> allSlots;
  final VoidCallback onRemove;
  final ValueChanged<TimeSlot> onUpdate;

  const _TimeSlotCard({
    required this.index,
    required this.slot,
    required this.allSlots,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_TimeSlotCard> createState() => _TimeSlotCardState();
}

class _TimeSlotCardState extends State<_TimeSlotCard> {
  late TimeSlot _local;

  @override
  void initState() {
    super.initState();
    _local = TimeSlot(
      startTime: widget.slot.startTime,
      endTime: widget.slot.endTime,
      bookingMode: widget.slot.bookingMode,
      slotDurationMinutes: widget.slot.slotDurationMinutes,
    );
  }

  void _update() => widget.onUpdate(_local);

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _overlapsWithOther(TimeOfDay start, TimeOfDay end) {
    final s = _toMin(start);
    final e = _toMin(end);
    for (int i = 0; i < widget.allSlots.length; i++) {
      if (i == widget.index) continue;
      final os = _toMin(widget.allSlots[i].startTime);
      final oe = _toMin(widget.allSlots[i].endTime);
      if (s < oe && os < e) return true;
    }
    return false;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _local.startTime : _local.endTime,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme:
              const ColorScheme.light(primary: Color(0xFF2D7DD2)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      final newStart = isStart ? picked : _local.startTime;
      final newEnd   = isStart ? _local.endTime : picked;
      if (_overlapsWithOther(newStart, newEnd)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: Colors.white, size: 18),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'This time overlaps with another slot.',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFE05C3A),
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 3),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
        return;
      }
      setState(() =>
          isStart ? _local.startTime = picked : _local.endTime = picked);
      _update();
    }
  }

  String _formatTime(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _modeLabel(BookingMode mode) {
    switch (mode) {
      case BookingMode.queue:
        return 'Queue';
      case BookingMode.slots:
        return 'Slots';
      case BookingMode.both:
        return 'Both';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEFF3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: const Color(0xFF2D7DD2).withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  '${widget.index + 1}',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2D7DD2),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              const Text(
                'Time Slot',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0F1923)),
              ),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(7),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded,
                      size: 16, color: Colors.red),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Time pickers
          Row(
            children: [
              Expanded(
                child: _TimePicker(
                  label: 'Start',
                  time: _formatTime(_local.startTime),
                  onTap: () => _pickTime(true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Text('→',
                    style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[400],
                        fontWeight: FontWeight.w300)),
              ),
              Expanded(
                child: _TimePicker(
                  label: 'End',
                  time: _formatTime(_local.endTime),
                  onTap: () => _pickTime(false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Booking mode selector
          const Text(
            'Booking Mode',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF6B7280),
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: BookingMode.values
                .where((mode) => mode != BookingMode.both)
                .toList()
                .asMap()
                .entries
                .map((entry) {
              final mode       = entry.value;
              final isLast     = entry.key == 1; // queue, slots — 2 items
              final isSelected = _local.bookingMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() => _local.bookingMode = mode);
                    _update();
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    margin: EdgeInsets.only(right: isLast ? 0 : 8),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? const Color(0xFF2D7DD2)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? const Color(0xFF2D7DD2)
                            : const Color(0xFFDDE0E8),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _modeLabel(mode),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : const Color(0xFF6B7280),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),

          // Slot duration (only for slots / both)
          if (_local.bookingMode == BookingMode.slots ||
              _local.bookingMode == BookingMode.both) ...[
            const SizedBox(height: 14),
            const Text(
              'Slot Duration',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF6B7280),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            _SlotDurationPicker(
              value: _local.slotDurationMinutes,
              onChanged: (val) {
                setState(() => _local.slotDurationMinutes = val);
                _update();
              },
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Time Picker Button ────────────────────────────────────────────────────────

class _TimePicker extends StatelessWidget {
  final String label;
  final String time;
  final VoidCallback onTap;

  const _TimePicker(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: const Color(0xFFDDE0E8)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF9CA3AF),
                    letterSpacing: 0.5)),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: Color(0xFF2D7DD2)),
                const SizedBox(width: 5),
                Text(time,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F1923))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Slot Duration Picker ──────────────────────────────────────────────────────

class _SlotDurationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  static const _options = [10, 15, 20, 30, 45, 60];

  const _SlotDurationPicker(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _options.map((min) {
        final isSelected = value == min;
        return GestureDetector(
          onTap: () => onChanged(min),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color:
                  isSelected ? const Color(0xFF2D7DD2) : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2D7DD2)
                    : const Color(0xFFDDE0E8),
              ),
            ),
            child: Text(
              '${min}m',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? Colors.white
                    : const Color(0xFF6B7280),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}