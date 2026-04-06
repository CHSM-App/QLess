import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ─── Tokens ───────────────────────────────────────────────────────────────────
const _kNavy    = Color(0xFF0F172A);
const _kBlue    = Color(0xFF3B82F6);
const _kSlate   = Color(0xFF64748B);
const _kBorder  = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF8FAFC);
const _kGreen   = Color(0xFF10B981);
const _kAmber   = Color(0xFFF59E0B);

const _specialtyColors = <String, Color>{
  'cardiology':    Color(0xFFEF4444),
  'dermatology':   Color(0xFFF59E0B),
  'pediatrics':    Color(0xFF10B981),
  'orthopedics':   Color(0xFF8B5CF6),
  'neurology':     Color(0xFF3B82F6),
  'general':       Color(0xFF06B6D4),
  'gynecology':    Color(0xFFEC4899),
  'ophthalmology': Color(0xFF14B8A6),
};

Color _colorFor(String? spec) =>
    spec == null ? _kBlue : (_specialtyColors[spec.toLowerCase()] ?? _kBlue);

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ─── Date helpers ─────────────────────────────────────────────────────────────
const _months = [
  'Jan','Feb','Mar','Apr','May','Jun',
  'Jul','Aug','Sep','Oct','Nov','Dec',
];
const _fullMonths = [
  'January','February','March','April','May','June',
  'July','August','September','October','November','December',
];
const _dayAbbr = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

bool _isToday(DateTime dt) {
  final n = DateTime.now();
  return dt.year == n.year && dt.month == n.month && dt.day == n.day;
}

String _fmtDateFull(DateTime dt) {
  if (_isToday(dt)) return 'Today';
  return '${_dayAbbr[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]}';
}

/// Booking rules
bool _sessionBookable(int? mode, bool isToday) {
  switch (mode) {
    case 1: return isToday;
    case 2: return true;
    case 3: return true;
    default: return false;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class BookAppointmentScreen extends ConsumerStatefulWidget {
  final DoctorDetails doctor;
  final int?          bookingForMemberId;

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    this.bookingForMemberId,
  });

  @override
  ConsumerState<BookAppointmentScreen> createState() =>
      _BookAppointmentScreenState();
}

class _BookAppointmentScreenState
    extends ConsumerState<BookAppointmentScreen> {
  DateTime? _selectedDate;
  int?      _selectedSlotId;
  String?   _selectedTime;
  bool      _isBooking = false;
  int?      _selectedMemberId; // null = patient themselves

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.bookingForMemberId;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final id = widget.doctor.doctorId;
      if (id != null) {
        ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(id);
        ref.read(appointmentViewModelProvider.notifier).getBookedSlots(id);
      }
      final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (patientId > 0) {
        ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(patientId);
      }
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  String _formatDateForApi(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  /// Converts display time "09:30 AM" → "09:30" in 24-hour format for the API.
  String _toApiTime(String displayTime) {
    final parts = displayTime.trim().split(' ');
    final hm    = parts[0].split(':');
    int hour    = int.parse(hm[0]);
    final min   = hm[1];
    final isPm  = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return '${hour.toString().padLeft(2, '0')}:$min';
  }

  TimeOfDay _parseTime(String? iso) {
    if (iso == null) return const TimeOfDay(hour: 9, minute: 0);
    final dt = DateTime.tryParse(iso);
    if (dt == null) return const TimeOfDay(hour: 9, minute: 0);
    return TimeOfDay(hour: dt.hour, minute: dt.minute);
  }

  String _fmtTime(String? iso) {
    final t      = _parseTime(iso);
    final suffix = t.hour < 12 ? 'AM' : 'PM';
    final h      = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $suffix';
  }

  /// Generate time-slot strings for [avail].
  List<String> _buildSlots(DoctorAvailabilityModel avail) {
    final start    = _parseTime(avail.startTime);
    final end      = _parseTime(avail.endTime);
    final duration = avail.slotDuration ?? 10;
    final slots    = <String>[];
    int cur        = start.hour * 60 + start.minute;
    final endMin   = end.hour * 60 + end.minute;
    while (cur + duration <= endMin) {
      final h      = cur ~/ 60;
      final m      = cur % 60;
      final suffix = h < 12 ? 'AM' : 'PM';
      final dh     = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      slots.add(
          '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $suffix');
      cur += duration;
    }
    return slots;
  }

  Map<String, List<DoctorAvailabilityModel>> _grouped(
      List<DoctorAvailabilityModel> all) {
    final map = <String, List<DoctorAvailabilityModel>>{};
    for (final a in all) {
      final day = a.dayOfWeek ?? '';
      if (day.isEmpty) continue;
      map.putIfAbsent(day, () => []).add(a);
    }
    return map;
  }

  void _pickDate(
    DateTime date,
    List<DoctorAvailabilityModel> sessions,
  ) {
    final isToday  = _isToday(date);
    final bookable = sessions
        .where((s) => _sessionBookable(s.bookingMode, isToday))
        .toList();
    setState(() {
      _selectedDate   = date;
      _selectedSlotId = bookable.length == 1 ? bookable.first.slotId : null;
      _selectedTime   = null;
    });

    if (widget.doctor.doctorId != null) {
      ref.read(appointmentViewModelProvider.notifier).getAppointmentAvailability(
        AppointmentRequestModel(
          doctorId: widget.doctor.doctorId,
          appointmentDate: _formatDateForApi(date),
        ),
      );
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state           = ref.watch(doctorsViewModelProvider);
    final appointmentState = ref.watch(appointmentViewModelProvider);
    final patientState    = ref.watch(patientLoginViewModelProvider);
    final familyState     = ref.watch(familyViewModelProvider);
    final isDark          = Theme.of(context).brightness == Brightness.dark;
    final familyMembers   = familyState.allfamilyMembers.maybeWhen(
      data: (m) => m,
      orElse: () => <FamilyMember>[],
    );

    // Build set of booked display-time strings for the selected date
    final bookedTimesForDate = <String>{};
    if (_selectedDate != null) {
      final dateStr = _formatDateForApi(_selectedDate!);
      for (final slot in appointmentState.bookedSlots) {
        if (slot.bookingDate != null &&
            slot.bookingDate!.startsWith(dateStr) &&
            slot.startTime != null) {
          bookedTimesForDate.add(_fmtTime(slot.startTime));
        }
      }
    }

    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      // Booking completed
      if (next.bookingResponse != null &&
          next.bookingResponse != prev?.bookingResponse &&
          !next.isLoading) {
        final msg = next.bookingResponse!.message ?? 'Appointment booked!';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: _kGreen),
        );
        setState(() => _isBooking = false);
        Navigator.pop(context, true);
        return;
      }
      // Booking error
      if (next.error != null &&
          next.error != prev?.error &&
          !next.isLoading &&
          _isBooking) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: Colors.red),
        );
        setState(() => _isBooking = false);
      }
    });

    final enabled = state.doctorAvailabilities
        .where((a) => a.isEnabled == true)
        .toList();
    final grouped = _grouped(enabled);

    final selectedAvail = _selectedSlotId == null
        ? null
        : enabled.firstWhere(
            (a) => a.slotId == _selectedSlotId,
            orElse: () => DoctorAvailabilityModel(),
          );

    final dayIsToday = _selectedDate != null && _isToday(_selectedDate!);
    final mode       = selectedAvail?.bookingMode ?? 0;
    final isQueue    = mode == 1 || (mode == 3 && dayIsToday);
    final canConfirm = selectedAvail != null &&
        _sessionBookable(mode, dayIsToday) &&
        (isQueue || _selectedTime != null);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : _kSurface,
      body: CustomScrollView(
        slivers: [
          // ── Collapsing header ──────────────────────────────────────────
          _DoctorHeader(
            doctor: widget.doctor,
            isDark: isDark,
            onBack: () => Navigator.pop(context),
          ),

          // ── Booking for ────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _BookingForDropdown(
              patientState:     patientState,
              members:          familyMembers,
              selectedMemberId: _selectedMemberId,
              onSelected:       (id) => setState(() => _selectedMemberId = id),
              isDark:           isDark,
            ),
          ),

          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(child: CircularProgressIndicator(color: _kBlue)),
            )
          else if (grouped.isEmpty)
            SliverFillRemaining(
              child: _NoAvailability(onBack: () => Navigator.pop(context)),
            )
          else
            SliverToBoxAdapter(
              child: _BookingBody(
                isDark:              isDark,
                grouped:             grouped,
                enabled:             enabled,
                selectedDate:        _selectedDate,
                selectedSlotId:      _selectedSlotId,
                selectedTime:        _selectedTime,
                selectedAvail:       selectedAvail,
                dayIsToday:          dayIsToday,
                bookedTimesForDate:  bookedTimesForDate,
                onPickDate:          (date, sessions) =>
                    _pickDate(date, sessions),
                onPickSession:       (slotId) => setState(() {
                  _selectedSlotId = slotId;
                  _selectedTime   = null;
                }),
                onPickTime:          (t) => setState(() => _selectedTime = t),
                buildSlots:          _buildSlots,
                fmtTime:             _fmtTime,
              ),
            ),
        ],
      ),
      bottomNavigationBar: canConfirm
          ? _ConfirmBar(
              isDark:       isDark,
              isQueue:      isQueue,
              selectedDate: _selectedDate,
              selectedSlot: _selectedTime,
              isLoading:    _isBooking,
              onConfirm:    _onConfirm,
            )
          : null,
    );
  }

  void _onConfirm() {
    if (_isBooking || _selectedDate == null) return;

    final patientState    = ref.read(patientLoginViewModelProvider);
    final isForMember     = _selectedMemberId != null;
    final patientId       = isForMember ? _selectedMemberId : patientState.patientId;
    final userType        = isForMember ? 2 : 1;

    final doctorsState = ref.read(doctorsViewModelProvider);
    final avail = _selectedSlotId == null
        ? null
        : doctorsState.doctorAvailabilities.cast<DoctorAvailabilityModel?>().firstWhere(
            (a) => a?.slotId == _selectedSlotId,
            orElse: () => null,
          );
    final isToday = _isToday(_selectedDate!);
    final mode    = avail?.bookingMode ?? 0;
    final isQueue = mode == 1 || (mode == 3 && isToday);

    final startTime = isQueue
        ? null
        : (_selectedTime != null ? _toApiTime(_selectedTime!) : null);

    setState(() => _isBooking = true);
    ref.read(appointmentViewModelProvider.notifier).bookAppointment(
      AppointmentRequestModel(
        doctorId:        widget.doctor.doctorId,
        patientId:       patientId,
        appointmentDate: _formatDateForApi(_selectedDate!),
        startTime:       startTime,
        userType:        userType,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR HEADER  (SliverAppBar)
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorHeader extends StatelessWidget {
  final DoctorDetails doctor;
  final bool          isDark;
  final VoidCallback  onBack;

  const _DoctorHeader({
    required this.doctor,
    required this.isDark,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final specColor = _colorFor(doctor.specialization);
    final initial   = (doctor.name?.isNotEmpty ?? false)
        ? doctor.name![0].toUpperCase()
        : 'D';

    return SliverAppBar(
      expandedHeight: 148,
      pinned:          true,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: _kNavy),
        onPressed: onBack,
      ),
      title: const Text(
        'Book Appointment',
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: _kNavy,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: _kBorder),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          padding:
              const EdgeInsets.fromLTRB(20, 0, 20, 16),
          alignment: Alignment.bottomLeft,
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [specColor, specColor.withValues(alpha: 0.55)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(initial,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: Colors.white)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Dr. ${doctor.name ?? 'Unknown'}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: _kNavy,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        if (doctor.specialization != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: specColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(5),
                            ),
                            child: Text(
                              _capitalize(doctor.specialization!),
                              style: TextStyle(
                                fontSize: 10.5,
                                fontWeight: FontWeight.w600,
                                color: specColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (doctor.clinicName != null)
                          Flexible(
                            child: Text(
                              doctor.clinicName!,
                              style: const TextStyle(
                                  fontSize: 11, color: _kSlate),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              if (doctor.consultationFee != null)
                Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₹${doctor.consultationFee!.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF059669),
                      ),
                    ),
                    const Text('consult fee',
                        style: TextStyle(fontSize: 9.5, color: _kSlate)),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING FOR DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────

class _BookingForDropdown extends StatelessWidget {
  final PatientLoginState   patientState;
  final List<FamilyMember>  members;
  final int?                selectedMemberId;
  final ValueChanged<int?>  onSelected;
  final bool                isDark;

  const _BookingForDropdown({
    required this.patientState,
    required this.members,
    required this.selectedMemberId,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: _kNavy.withValues(alpha: 0.12),
              child: Text(
                (patientState.name?.isNotEmpty ?? false)
                    ? patientState.name![0].toUpperCase()
                    : 'M',
                style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700, color: _kNavy),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(patientState.name ?? 'Me',
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
                const Text('You',
                    style: TextStyle(fontSize: 10, color: _kSlate)),
              ],
            ),
          ],
        ),
      ),
      ...members.map((m) {
        return DropdownMenuItem<int?>(
          value: m.memberId,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: _kBlue.withValues(alpha: 0.12),
                child: Text(
                  m.memberName?.isNotEmpty == true
                      ? m.memberName![0].toUpperCase()
                      : '?',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700, color: _kBlue),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.memberName ?? '?',
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: _kNavy)),
                  if (m.relationName?.isNotEmpty == true)
                    Text(m.relationName!,
                        style: const TextStyle(fontSize: 10, color: _kSlate)),
                ],
              ),
            ],
          ),
        );
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded, color: _kBlue, size: 18),
          const SizedBox(width: 8),
          const Text('Booking for',
              style: TextStyle(fontSize: 13, color: _kSlate)),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedMemberId,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 18, color: _kBlue),
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700, color: _kBlue),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: items,
                onChanged: (val) => onSelected(val),
                selectedItemBuilder: (_) => [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(patientState.name ?? 'Me',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _kBlue)),
                  ),
                  ...members.map(
                    (m) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(m.memberName ?? 'Member',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _kBlue)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING BODY
// ─────────────────────────────────────────────────────────────────────────────

class _BookingBody extends StatelessWidget {
  final bool          isDark;
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final List<DoctorAvailabilityModel> enabled;
  final DateTime?     selectedDate;
  final int?          selectedSlotId;
  final String?       selectedTime;
  final DoctorAvailabilityModel? selectedAvail;
  final bool          dayIsToday;
  final Set<String>  bookedTimesForDate;
  final void Function(DateTime, List<DoctorAvailabilityModel>) onPickDate;
  final ValueChanged<int?>   onPickSession;
  final ValueChanged<String> onPickTime;
  final List<String> Function(DoctorAvailabilityModel) buildSlots;
  final String Function(String?) fmtTime;

  const _BookingBody({
    required this.isDark,
    required this.grouped,
    required this.enabled,
    required this.selectedDate,
    required this.selectedSlotId,
    required this.selectedTime,
    required this.selectedAvail,
    required this.dayIsToday,
    required this.bookedTimesForDate,
    required this.onPickDate,
    required this.onPickSession,
    required this.onPickTime,
    required this.buildSlots,
    required this.fmtTime,
  });

  @override
  Widget build(BuildContext context) {
    // Bookable sessions for the selected date
    final sessionsForDate = selectedDate == null
        ? <DoctorAvailabilityModel>[]
        : (grouped[_dayName(selectedDate!.weekday)] ?? [])
            .where((s) => _sessionBookable(s.bookingMode, dayIsToday))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Calendar strip ─────────────────────────────────────────────
          _CalendarStrip(
            grouped:      grouped,
            selectedDate: selectedDate,
            onDateSelected: (date) {
              final dayName  = _dayName(date.weekday);
              final sessions = grouped[dayName] ?? [];
              onPickDate(date, sessions);
            },
          ),

          // ── Selected date badge ────────────────────────────────────────
          if (selectedDate != null) ...[
            const SizedBox(height: 16),
            _SelectedDateBadge(date: selectedDate!, isDark: isDark),
          ],

          // ── Session picker (>1 bookable session on this date) ──────────
          if (sessionsForDate.length > 1) ...[
            const SizedBox(height: 20),
            _label('Select Session'),
            const SizedBox(height: 10),
            _SessionRow(
              sessions:       sessionsForDate,
              selectedSlotId: selectedSlotId,
              onSelected:     onPickSession,
              fmtTime:        fmtTime,
            ),
          ],

          // ── Booking section ────────────────────────────────────────────
          if (selectedAvail != null) ...[
            const SizedBox(height: 24),
            if (selectedAvail!.bookingMode == 1 ||
                (selectedAvail!.bookingMode == 3 && dayIsToday))
              _QueueCard(avail: selectedAvail!)
            else
              _SlotPicker(
                slots:             buildSlots(selectedAvail!),
                selected:          selectedTime,
                isDark:            isDark,
                bookedTimes:       bookedTimesForDate,
                onSelected:        onPickTime,
              ),
          ],
        ],
      ),
    );
  }

  String _dayName(int weekday) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday',
    ];
    return names[(weekday - 1).clamp(0, 6)];
  }
}

Widget _label(String text) => Padding(
      padding: const EdgeInsets.only(bottom: 0),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: _kSlate,
          letterSpacing: 1.1,
        ),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// CALENDAR STRIP  — 28-day horizontal scroll
// ─────────────────────────────────────────────────────────────────────────────

class _CalendarStrip extends StatefulWidget {
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final DateTime?             selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _CalendarStrip({
    required this.grouped,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  final ScrollController _scroll = ScrollController();

  static const _cellW  = 52.0;
  static const _gapW   = 6.0;
  static const _days   = 28;

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  // Scroll so first available date is visible
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now();
      for (int i = 0; i < _days; i++) {
        final d = today.add(Duration(days: i));
        if (_isAvailable(d)) {
          final offset = i * (_cellW + _gapW) - 16;
          if (_scroll.hasClients) {
            _scroll.animateTo(
              offset.clamp(0.0, _scroll.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          break;
        }
      }
    });
  }

  bool _isAvailable(DateTime dt) {
    const names = [
      'Monday','Tuesday','Wednesday','Thursday',
      'Friday','Saturday','Sunday',
    ];
    final dayName = names[(dt.weekday - 1).clamp(0, 6)];
    final sessions = widget.grouped[dayName];
    if (sessions == null || sessions.isEmpty) return false;
    final isToday = _isToday(dt);
    return sessions.any((s) => _sessionBookable(s.bookingMode, isToday));
  }

  Color? _dotColor(DateTime dt) {
    const names = [
      'Monday','Tuesday','Wednesday','Thursday',
      'Friday','Saturday','Sunday',
    ];
    final dayName = names[(dt.weekday - 1).clamp(0, 6)];
    final sessions = widget.grouped[dayName];
    if (sessions == null) return null;
    final isToday = _isToday(dt);
    final bookable = sessions
        .where((s) => _sessionBookable(s.bookingMode, isToday))
        .toList();
    if (bookable.isEmpty) return null;
    // Pick representative color
    if (bookable.any((s) => s.bookingMode == 1) && isToday) return _kAmber;
    if (bookable.any((s) => s.bookingMode == 3)) {
      return isToday ? _kAmber : _kBlue;
    }
    return _kBlue;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();

    // Group dates by month for headers
    // Build list items: MonthHeader or DateCell
    final items = <_CalItem>[];
    DateTime? lastMonth;
    for (int i = 0; i < _days; i++) {
      final d = today.add(Duration(days: i));
      if (lastMonth == null || d.month != lastMonth.month) {
        items.add(_CalItem.monthHeader('${_fullMonths[d.month - 1]} ${d.year}'));
        lastMonth = d;
      }
      items.add(_CalItem.date(d));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Select Date'),
        const SizedBox(height: 10),
        SizedBox(
          height: 88,
          child: ListView.builder(
            controller:    _scroll,
            scrollDirection: Axis.horizontal,
            itemCount:     items.length,
            itemBuilder:   (_, i) {
              final item = items[i];
              if (item.isHeader) {
                return _MonthLabel(label: item.monthLabel!);
              }
              final dt         = item.date!;
              final available  = _isAvailable(dt);
              final dotColor   = _dotColor(dt);
              final isSelected = widget.selectedDate != null &&
                  widget.selectedDate!.year == dt.year &&
                  widget.selectedDate!.month == dt.month &&
                  widget.selectedDate!.day == dt.day;
              final isWeekend  = dt.weekday >= 6;

              return Padding(
                padding: const EdgeInsets.only(right: _gapW),
                child: GestureDetector(
                  onTap: available ? () => widget.onDateSelected(dt) : null,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: _cellW,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _kNavy
                          : (available ? Colors.white : Colors.transparent),
                      borderRadius: BorderRadius.circular(12),
                      border: isSelected
                          ? null
                          : (available
                              ? Border.all(color: _kBorder)
                              : null),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: _kNavy.withValues(alpha: 0.2),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              )
                            ]
                          : [],
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _dayAbbr[dt.weekday - 1],
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.7)
                                : (available
                                    ? (isWeekend ? _kBlue : _kSlate)
                                    : _kSlate.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${dt.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: isSelected
                                ? Colors.white
                                : (available
                                    ? _kNavy
                                    : _kSlate.withValues(alpha: 0.3)),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? Colors.white.withValues(alpha: 0.6)
                                : (dotColor ?? Colors.transparent),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// Simple data class to hold either a month header or a date cell
class _CalItem {
  final bool      isHeader;
  final String?   monthLabel;
  final DateTime? date;

  const _CalItem._({required this.isHeader, this.monthLabel, this.date});

  factory _CalItem.monthHeader(String label) =>
      _CalItem._(isHeader: true, monthLabel: label);

  factory _CalItem.date(DateTime dt) =>
      _CalItem._(isHeader: false, date: dt);
}

class _MonthLabel extends StatelessWidget {
  final String label;
  const _MonthLabel({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        alignment: Alignment.bottomLeft,
        padding: const EdgeInsets.only(right: 10, bottom: 10),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: _kSlate,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SELECTED DATE BADGE
// ─────────────────────────────────────────────────────────────────────────────

class _SelectedDateBadge extends StatelessWidget {
  final DateTime date;
  final bool     isDark;

  const _SelectedDateBadge({required this.date, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: BoxDecoration(
        color: _kNavy.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kNavy.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          const Icon(Icons.event_rounded, size: 15, color: _kNavy),
          const SizedBox(width: 8),
          Text(
            _fmtDateFull(date),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kNavy,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SESSION ROW  — horizontal chips when >1 session on the same date
// ─────────────────────────────────────────────────────────────────────────────

class _SessionRow extends StatelessWidget {
  final List<DoctorAvailabilityModel> sessions;
  final int?                          selectedSlotId;
  final ValueChanged<int?>            onSelected;
  final String Function(String?)      fmtTime;

  const _SessionRow({
    required this.sessions,
    required this.selectedSlotId,
    required this.onSelected,
    required this.fmtTime,
  });

  Color _modeColor(int? mode) {
    switch (mode) {
      case 1:  return _kAmber;
      case 2:  return _kBlue;
      case 3:  return _kGreen;
      default: return _kSlate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: sessions.map((s) {
        final sel   = selectedSlotId == s.slotId;
        final color = _modeColor(s.bookingMode);
        return GestureDetector(
          onTap: () => onSelected(s.slotId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            margin: const EdgeInsets.only(bottom: 8),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: sel ? _kNavy : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: sel ? _kNavy : _kBorder,
                width: sel ? 1.5 : 1,
              ),
              boxShadow: sel
                  ? [
                      BoxShadow(
                        color: _kNavy.withValues(alpha: 0.14),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [],
            ),
            child: Row(
              children: [
                Icon(Icons.access_time_rounded,
                    size: 15,
                    color: sel ? Colors.white : _kBlue),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${fmtTime(s.startTime)}  –  ${fmtTime(s.endTime)}',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : _kNavy,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withValues(alpha: 0.15)
                        : color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    s.bookingMode == 1
                        ? 'Queue'
                        : s.bookingMode == 2
                            ? 'Slots'
                            : 'Queue + Slots',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : color,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _QueueCard extends StatelessWidget {
  final DoctorAvailabilityModel avail;
  const _QueueCard({required this.avail});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _kAmber.withValues(alpha: 0.12),
            _kAmber.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kAmber.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: _kAmber.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.confirmation_number_rounded,
                size: 22, color: _kAmber),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Walk-in Queue',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _kNavy,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Show up today · ${avail.slotDuration ?? 10} min per patient',
                  style: const TextStyle(fontSize: 12, color: _kSlate),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SLOT PICKER  — grouped by Morning / Afternoon / Evening
// ─────────────────────────────────────────────────────────────────────────────

class _SlotPicker extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final bool                 isDark;
  final Set<String>          bookedTimes;
  final ValueChanged<String> onSelected;

  const _SlotPicker({
    required this.slots,
    required this.selected,
    required this.isDark,
    required this.bookedTimes,
    required this.onSelected,
  });

  // Parse "09:30 AM" → minutes since midnight
  int _toMinutes(String slot) {
    final parts  = slot.split(':');
    final hPart  = int.tryParse(parts[0]) ?? 0;
    final rest   = parts[1].split(' ');
    final m      = int.tryParse(rest[0]) ?? 0;
    final suffix = rest[1];
    var h        = hPart;
    if (suffix == 'PM' && h != 12) h += 12;
    if (suffix == 'AM' && h == 12) h = 0;
    return h * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('No slots available',
              style: TextStyle(color: _kSlate, fontSize: 13)),
        ),
      );
    }

    // Group slots
    final morning   = slots.where((s) => _toMinutes(s) < 720).toList();  // < 12:00
    final afternoon = slots.where((s) {
      final m = _toMinutes(s);
      return m >= 720 && m < 1020;                                         // 12:00–17:00
    }).toList();
    final evening   = slots.where((s) => _toMinutes(s) >= 1020).toList(); // ≥ 17:00

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Select Time Slot'),
        const SizedBox(height: 12),
        if (morning.isNotEmpty) ...[
          _SlotGroupHeader(icon: Icons.wb_sunny_outlined, label: 'Morning'),
          const SizedBox(height: 8),
          _SlotGrid(slots: morning, selected: selected, isDark: isDark,
              bookedTimes: bookedTimes, onSelected: onSelected),
          const SizedBox(height: 16),
        ],
        if (afternoon.isNotEmpty) ...[
          _SlotGroupHeader(icon: Icons.wb_twilight_outlined, label: 'Afternoon'),
          const SizedBox(height: 8),
          _SlotGrid(slots: afternoon, selected: selected, isDark: isDark,
              bookedTimes: bookedTimes, onSelected: onSelected),
          const SizedBox(height: 16),
        ],
        if (evening.isNotEmpty) ...[
          _SlotGroupHeader(icon: Icons.nights_stay_outlined, label: 'Evening'),
          const SizedBox(height: 8),
          _SlotGrid(slots: evening, selected: selected, isDark: isDark,
              bookedTimes: bookedTimes, onSelected: onSelected),
        ],
      ],
    );
  }
}

class _SlotGroupHeader extends StatelessWidget {
  final IconData icon;
  final String   label;

  const _SlotGroupHeader({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 14, color: _kSlate),
          const SizedBox(width: 5),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: _kSlate,
            ),
          ),
        ],
      );
}

class _SlotGrid extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final bool                 isDark;
  final Set<String>          bookedTimes;
  final ValueChanged<String> onSelected;

  const _SlotGrid({
    required this.slots,
    required this.selected,
    required this.isDark,
    required this.bookedTimes,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: slots.map((slot) {
        final isSel    = selected == slot;
        final isBooked = bookedTimes.contains(slot);
        return GestureDetector(
          onTap: isBooked ? null : () => onSelected(slot),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isBooked
                  ? (isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9))
                  : isSel
                      ? _kBlue
                      : (isDark ? const Color(0xFF1E293B) : Colors.white),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isBooked ? const Color(0xFFCBD5E1) : (isSel ? _kBlue : _kBorder),
              ),
              boxShadow: isSel && !isBooked
                  ? [
                      BoxShadow(
                        color: _kBlue.withValues(alpha: 0.25),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : [],
            ),
            child: Text(
              slot,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isBooked
                    ? const Color(0xFFCBD5E1)
                    : (isSel ? Colors.white : _kNavy),
                decoration: isBooked ? TextDecoration.lineThrough : null,
                decorationColor: const Color(0xFFCBD5E1),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CONFIRM BAR
// ─────────────────────────────────────────────────────────────────────────────

class _ConfirmBar extends StatelessWidget {
  final bool         isDark;
  final bool         isQueue;
  final DateTime?    selectedDate;
  final String?      selectedSlot;
  final bool         isLoading;
  final VoidCallback onConfirm;

  const _ConfirmBar({
    required this.isDark,
    required this.isQueue,
    required this.selectedDate,
    required this.selectedSlot,
    required this.isLoading,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = selectedDate != null ? _fmtDateFull(selectedDate!) : '';
    final label   = isQueue
        ? 'Confirm Queue  ·  $dateStr'
        : '$selectedSlot  ·  $dateStr';

    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: const Border(top: BorderSide(color: _kBorder)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 12,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: isLoading ? null : onConfirm,
          style: ElevatedButton.styleFrom(
            backgroundColor: _kNavy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _kNavy.withValues(alpha: 0.6),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isQueue
                          ? Icons.confirmation_number_rounded
                          : Icons.calendar_month_rounded,
                      size: 17,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// NO AVAILABILITY
// ─────────────────────────────────────────────────────────────────────────────

class _NoAvailability extends StatelessWidget {
  final VoidCallback onBack;
  const _NoAvailability({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child:
                  const Icon(Icons.event_busy_rounded, size: 32, color: _kBlue),
            ),
            const SizedBox(height: 16),
            const Text(
              'No availability found',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w700, color: _kNavy),
            ),
            const SizedBox(height: 8),
            const Text(
              'This doctor has no available slots at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: _kSlate, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onBack,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                    horizontal: 28, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }
}
