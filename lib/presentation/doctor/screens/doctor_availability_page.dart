import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess  = Color(0xFF68D391);

// ── UI Models ─────────────────────────────────────────────────────────────────
enum BookingMode { queue, slots, both }

class TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;
  int? maxQueueLength;

  TimeSlot({
    required this.startTime,
    required this.endTime,
    this.bookingMode = BookingMode.queue,
    this.slotDurationMinutes = 15,
    this.maxQueueLength,
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

// ════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════
class DoctorAvailabilityPage extends ConsumerStatefulWidget {
  const DoctorAvailabilityPage({super.key});

  @override
  ConsumerState<DoctorAvailabilityPage> createState() =>
      _DoctorAvailabilityPageState();
}

class _DoctorAvailabilityPageState
    extends ConsumerState<DoctorAvailabilityPage> {
  static const _dayMeta = [
    ('Monday', 'MON'), ('Tuesday', 'TUE'), ('Wednesday', 'WED'),
    ('Thursday', 'THU'), ('Friday', 'FRI'), ('Saturday', 'SAT'),
    ('Sunday', 'SUN'),
  ];

  late List<DaySchedule> _days;
  DoctorScheduleModel? _hydratedFrom;

  @override
  void initState() {
    super.initState();
    _days = _dayMeta
        .map((m) => DaySchedule(dayName: m.$1, shortName: m.$2))
        .toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final doctorId =
          ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
      ref.read(doctorSettingsViewModelProvider.notifier)
          .getDoctorSchedule(doctorId);
    });
  }

  // ---------------------------------------------------------------------------
  // Hydration
  // ---------------------------------------------------------------------------

  TimeOfDay _parseTime(String? raw) {
    if (raw == null || raw.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final parts = raw.split(':');
    return TimeOfDay(
      hour:   int.tryParse(parts[0]) ?? 9,
      minute: int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0,
    );
  }

  BookingMode _intToMode(int? v) => switch (v) {
    2 => BookingMode.slots, 3 => BookingMode.both, _ => BookingMode.queue,
  };

  void _hydrateFromModel(DoctorScheduleModel model) {
    final apiDays = {
      for (final d in model.schedule ?? <DayScheduleModel>[])
        (d.day ?? '').toLowerCase(): d
    };
    setState(() {
      for (final day in _days) {
        final api = apiDays[day.dayName.toLowerCase()];
        if (api == null) continue;
        day.isEnabled  = (api.isEnabled ?? 0) == 1;
        day.isExpanded = false;
        day.timeSlots  = (api.slots ?? []).map((s) => TimeSlot(
          startTime:           _parseTime(s.startTime),
          endTime:             _parseTime(s.endTime),
          bookingMode:         _intToMode(s.bookingMode),
          slotDurationMinutes: s.slotDuration ?? 15,
          maxQueueLength:      s.maxQueueLength,
        )).toList();
      }
    });
    _hydratedFrom = model;
  }

  // ---------------------------------------------------------------------------
  // Build model
  // ---------------------------------------------------------------------------

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  int _modeToInt(BookingMode m) =>
      switch (m) { BookingMode.queue => 1, BookingMode.slots => 2, BookingMode.both => 3 };

  DoctorScheduleModel _buildModel() {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    return DoctorScheduleModel(
      doctorId: doctorId,
      schedule: _days.map((day) => DayScheduleModel(
        day:       day.dayName,
        isEnabled: day.isEnabled ? 1 : 0,
        slots: day.timeSlots.map((slot) => TimeSlotModel(
          startTime:      _fmtTime(slot.startTime),
          endTime:        _fmtTime(slot.endTime),
          bookingMode:    _modeToInt(slot.bookingMode),
          slotDuration:   slot.bookingMode == BookingMode.queue
              ? null : slot.slotDurationMinutes,
          maxQueueLength: slot.maxQueueLength,
        )).toList(),
      )).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // UI mutations
  // ---------------------------------------------------------------------------

  void _toggleDay(int i, bool v) => setState(() {
    _days[i].isEnabled  = v;
    if (!v) _days[i].isExpanded = false;
  });

  void _toggleExpand(int i) => setState(() {
    if (_days[i].isEnabled) _days[i].isExpanded = !_days[i].isExpanded;
  });

  void _addSlot(int i) => setState(() {
    _days[i].timeSlots.add(TimeSlot(
      startTime: const TimeOfDay(hour: 9, minute: 0),
      endTime:   const TimeOfDay(hour: 12, minute: 0),
    ));
  });

  void _removeSlot(int di, int si) => setState(() {
    _days[di].timeSlots.removeAt(si);
    if (_days[di].timeSlots.isEmpty) {
      _days[di].isEnabled  = false;
      _days[di].isExpanded = false;
    }
  });

  void _updateSlot(int di, int si, TimeSlot updated) =>
      setState(() => _days[di].timeSlots[si] = updated);

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    // Overlap validation
    for (final day in _days) {
      if (!day.isEnabled) continue;
      final slots = day.timeSlots;
      for (int i = 0; i < slots.length; i++) {
        for (int j = i + 1; j < slots.length; j++) {
          final aS = slots[i].startTime.hour * 60 + slots[i].startTime.minute;
          final aE = slots[i].endTime.hour   * 60 + slots[i].endTime.minute;
          final bS = slots[j].startTime.hour * 60 + slots[j].startTime.minute;
          final bE = slots[j].endTime.hour   * 60 + slots[j].endTime.minute;
          if (aS < bE && bS < aE) {
            setState(() => day.isExpanded = true);
            _snack('${day.dayName} has overlapping slots.', isError: true);
            return;
          }
        }
      }
    }

    // Empty-slot validation
    final invalid = _days.where((d) => d.isEnabled && d.timeSlots.isEmpty).toList();
    if (invalid.isNotEmpty) {
      setState(() { for (final d in invalid) d.isExpanded = true; });
      _snack(
        '${invalid.map((d) => d.dayName).join(', ')} enabled but has no time slots.',
        isError: true,
      );
      return;
    }

    await ref.read(doctorSettingsViewModelProvider.notifier)
        .saveDoctorSchedule(_buildModel());
    if (!mounted) return;

    final err = ref.read(doctorSettingsViewModelProvider).errorMessage;
    if (err.isEmpty) {
      HapticFeedback.lightImpact();
      _snack('Schedule saved successfully');
    } else {
      _snack(err, isError: true);
    }
  }

  void _snack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.warning_amber_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 13, color: Colors.white))),
        ]),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: isError ? 4 : 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(doctorSettingsViewModelProvider);
    final loaded    = state.doctorSchedule;
    final isLoading = state.isLoading;
    final isTablet  = MediaQuery.of(context).size.width >= 600;

    if (loaded != null && !identical(loaded, _hydratedFrom)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _hydrateFromModel(loaded);
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(isLoading),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
                maxWidth: isTablet ? 680 : double.infinity),
            child: Column(children: [
              if (state.errorMessage.isNotEmpty && !isLoading)
                _ErrorBanner(message: state.errorMessage),
              Expanded(
                child: isLoading
                    ? const _LoadingShimmer()
                    : ListView.builder(
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 20 : 14,
                          vertical: 12,
                        ),
                        itemCount: _days.length,
                        itemBuilder: (_, i) => _DayCard(
                          schedule:     _days[i],
                          onToggle:     (v)         => _toggleDay(i, v),
                          onTapHeader:  ()           => _toggleExpand(i),
                          onAddSlot:    ()           => _addSlot(i),
                          onRemoveSlot: (si)         => _removeSlot(i, si),
                          onUpdateSlot: (si, updated)=> _updateSlot(i, si, updated),
                        ),
                      ),
              ),
              _buildSaveBar(isTablet, isLoading),
            ]),
          ),
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isLoading) => AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: kPrimary),
          ),
        ),
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Availability',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: kTextPrimary, letterSpacing: -0.2)),
          Text('Set your weekly schedule',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ]),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(isLoading ? 3.0 : 1.0),
          child: isLoading
              ? LinearProgressIndicator(
                  minHeight: 3,
                  color: kPrimary,
                  backgroundColor: kPrimaryLight)
              : Container(height: 1, color: kBorder),
        ),
      );

  Widget _buildSaveBar(bool isTablet, bool isLoading) => Container(
        padding: EdgeInsets.fromLTRB(
            isTablet ? 20 : 14, 10, isTablet ? 20 : 14, 16),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
        ),
        child: SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              disabledBackgroundColor: kPrimaryLight,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : const Text('Save Schedule',
                    style: TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      );
}

// ─── Error Banner ─────────────────────────────────────────────────────────────
class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        color: kRedLight.withOpacity(0.6),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: kError, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(message,
              style: const TextStyle(fontSize: 12, color: kError))),
        ]),
      );
}

// ─── Loading Shimmer ──────────────────────────────────────────────────────────
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 0.9).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          itemCount: 7,
          itemBuilder: (_, __) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            height: 66,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kBorder),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10)),
                ),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 11, width: 72,
                        decoration: BoxDecoration(
                            color: kBorder,
                            borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 5),
                    Container(height: 9, width: 48,
                        decoration: BoxDecoration(
                            color: kBorder,
                            borderRadius: BorderRadius.circular(4))),
                  ],
                )),
                Container(width: 42, height: 22,
                    decoration: BoxDecoration(
                        color: kBorder,
                        borderRadius: BorderRadius.circular(11))),
              ]),
            ),
          ),
        ),
      );
}

// ─── Day Card ─────────────────────────────────────────────────────────────────
class _DayCard extends StatelessWidget {
  final DaySchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapHeader;
  final VoidCallback onAddSlot;
  final ValueChanged<int> onRemoveSlot;
  final void Function(int, TimeSlot) onUpdateSlot;

  const _DayCard({
    required this.schedule,     required this.onToggle,
    required this.onTapHeader,  required this.onAddSlot,
    required this.onRemoveSlot, required this.onUpdateSlot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: schedule.isEnabled
              ? kPrimary.withOpacity(0.3)
              : kBorder,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(children: [
        _buildHeader(),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _buildExpanded(),
          crossFadeState: (schedule.isExpanded && schedule.isEnabled)
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeInOut,
        ),
      ]),
    );
  }

  Widget _buildHeader() => InkWell(
        onTap: onTapHeader,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            // Day abbreviation badge
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: schedule.isEnabled ? kPrimaryLight : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(schedule.shortName,
                  style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: schedule.isEnabled ? kPrimary : kTextMuted,
                      letterSpacing: 0.5)),
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(schedule.dayName,
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: schedule.isEnabled ? kTextPrimary : kTextMuted)),
              Text(
                schedule.isEnabled
                    ? (schedule.timeSlots.isEmpty
                        ? 'No slots added'
                        : '${schedule.timeSlots.length} time slot${schedule.timeSlots.length > 1 ? 's' : ''}')
                    : 'Unavailable',
                style: const TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ])),
            if (schedule.isEnabled)
              AnimatedRotation(
                turns: schedule.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(Icons.keyboard_arrow_down_rounded,
                    color: kTextMuted, size: 20),
              ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: schedule.isEnabled,
                onChanged: onToggle,
                activeColor: kPrimary,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
      );

  Widget _buildExpanded() => Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kBorder))),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ...schedule.timeSlots.asMap().entries.map((e) =>
              _TimeSlotCard(
                index:       e.key,
                slot:        e.value,
                allSlots:    schedule.timeSlots,
                onRemove:    () => onRemoveSlot(e.key),
                onUpdate:    (updated) => onUpdateSlot(e.key, updated),
              )),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onAddSlot,
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Time Slot',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              style: OutlinedButton.styleFrom(
                foregroundColor: kPrimary,
                side: const BorderSide(color: kPrimary, width: 1.5),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
        ]),
      );
}

// ─── Time Slot Card ───────────────────────────────────────────────────────────
class _TimeSlotCard extends StatefulWidget {
  final int index;
  final TimeSlot slot;
  final List<TimeSlot> allSlots;
  final VoidCallback onRemove;
  final ValueChanged<TimeSlot> onUpdate;

  const _TimeSlotCard({
    required this.index,   required this.slot,
    required this.allSlots, required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_TimeSlotCard> createState() => _TimeSlotCardState();
}

class _TimeSlotCardState extends State<_TimeSlotCard> {
  late TimeSlot _local;
  late TextEditingController _queueCtrl;

  @override
  void initState() {
    super.initState();
    _local = TimeSlot(
      startTime:           widget.slot.startTime,
      endTime:             widget.slot.endTime,
      bookingMode:         widget.slot.bookingMode,
      slotDurationMinutes: widget.slot.slotDurationMinutes,
      maxQueueLength:      widget.slot.maxQueueLength,
    );
    _queueCtrl = TextEditingController(
        text: _local.maxQueueLength != null ? '${_local.maxQueueLength}' : '');
  }

  @override
  void dispose() { _queueCtrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(covariant _TimeSlotCard old) {
    super.didUpdateWidget(old);
    if (old.slot.maxQueueLength != widget.slot.maxQueueLength) {
      _queueCtrl.text = widget.slot.maxQueueLength != null
          ? '${widget.slot.maxQueueLength}' : '';
      _local.maxQueueLength = widget.slot.maxQueueLength;
    }
  }

  void _update() => widget.onUpdate(_local);

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _overlaps(TimeOfDay start, TimeOfDay end) {
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
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final newStart = isStart ? picked : _local.startTime;
    final newEnd   = isStart ? _local.endTime : picked;
    if (_overlaps(newStart, newEnd)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded, color: Colors.white, size: 15),
            SizedBox(width: 8),
            Expanded(child: Text('This time overlaps with another slot.',
                style: TextStyle(fontSize: 13, color: Colors.white))),
          ]),
          backgroundColor: kError,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        ));
      }
      return;
    }
    setState(() => isStart ? _local.startTime = picked : _local.endTime = picked);
    _update();
  }

  String _fmtTime(TimeOfDay t) {
    final h      = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m      = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _modeLabel(BookingMode m) =>
      switch (m) { BookingMode.queue => 'Queue', BookingMode.slots => 'Slots', BookingMode.both => 'Both' };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        Row(children: [
          Container(
            width: 20, height: 20,
            decoration: BoxDecoration(
                color: kPrimaryLight, shape: BoxShape.circle),
            alignment: Alignment.center,
            child: Text('${widget.index + 1}',
                style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: kPrimary)),
          ),
          const SizedBox(width: 8),
          const Text('Time Slot',
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: kTextPrimary)),
          const Spacer(),
          GestureDetector(
            onTap: widget.onRemove,
            child: Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(7)),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, size: 14, color: kError),
            ),
          ),
        ]),
        const SizedBox(height: 10),

        // Time pickers
        Row(children: [
          Expanded(child: _TimePicker(
            label: 'Start', time: _fmtTime(_local.startTime),
            onTap: () => _pickTime(true),
          )),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('→',
                style: TextStyle(fontSize: 14, color: kTextMuted,
                    fontWeight: FontWeight.w400)),
          ),
          Expanded(child: _TimePicker(
            label: 'End', time: _fmtTime(_local.endTime),
            onTap: () => _pickTime(false),
          )),
        ]),
        const SizedBox(height: 12),

        // Booking mode
        const Text('Booking Mode',
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600,
                color: kTextSecondary, letterSpacing: 0.2)),
        const SizedBox(height: 6),
        Row(
          children: BookingMode.values
              .where((m) => m != BookingMode.both)
              .toList()
              .asMap()
              .entries
              .map((e) {
            final mode = e.value;
            final isLast = e.key == 1;
            final sel  = _local.bookingMode == mode;
            return Expanded(
              child: GestureDetector(
                onTap: () { setState(() => _local.bookingMode = mode); _update(); },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 140),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? kPrimary : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? kPrimary : kBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(_modeLabel(mode),
                      style: TextStyle(
                          fontSize: 12, fontWeight: FontWeight.w600,
                          color: sel ? Colors.white : kTextSecondary)),
                ),
              ),
            );
          }).toList(),
        ),

        // Max queue length
        if (_local.bookingMode == BookingMode.queue ||
            _local.bookingMode == BookingMode.both) ...[
          const SizedBox(height: 12),
          const Text('Max Queue Length',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: kTextSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 6),
          Container(
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder),
            ),
            child: Row(children: [
              const SizedBox(width: 10),
              const Icon(Icons.people_alt_rounded, size: 15, color: kPrimary),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _queueCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600,
                      color: kTextPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'e.g. 20',
                    hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (val) {
                    setState(() =>
                        _local.maxQueueLength = val.isEmpty ? null : int.tryParse(val));
                    _update();
                  },
                ),
              ),
              Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(6)),
                child: const Text('patients',
                    style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: kPrimary)),
              ),
            ]),
          ),
        ],

        // Slot duration
        if (_local.bookingMode == BookingMode.slots ||
            _local.bookingMode == BookingMode.both) ...[
          const SizedBox(height: 12),
          const Text('Slot Duration',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: kTextSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 6),
          _SlotDurationPicker(
            value: _local.slotDurationMinutes,
            onChanged: (val) {
              setState(() => _local.slotDurationMinutes = val);
              _update();
            },
          ),
        ],
      ]),
    );
  }
}

// ─── Time Picker Button ───────────────────────────────────────────────────────
class _TimePicker extends StatelessWidget {
  final String label, time;
  final VoidCallback onTap;
  const _TimePicker({required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: kTextMuted, letterSpacing: 0.3)),
            const SizedBox(height: 2),
            Row(children: [
              const Icon(Icons.access_time_rounded, size: 12, color: kPrimary),
              const SizedBox(width: 4),
              Text(time,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ]),
          ]),
        ),
      );
}

// ─── Slot Duration Picker ─────────────────────────────────────────────────────
class _SlotDurationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  static const _opts = [10, 15, 20, 30, 45, 60];

  const _SlotDurationPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7, runSpacing: 7,
        children: _opts.map((min) {
          final sel = value == min;
          return GestureDetector(
            onTap: () => onChanged(min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(color: sel ? kPrimary : kBorder),
              ),
              child: Text('${min}m',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : kTextSecondary)),
            ),
          );
        }).toList(),
      );
}