import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/doctor_profile_view.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/favorite_viewmodel.dart';
import 'package:qless/domain/models/review_model.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

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

const kFavActive = Color(0xFFE53E3E);

// ── Specialty accent/bg ───────────────────────────────────────────────────────
const _accentMap = <String, Color>{
  'cardiology':    kError,
  'dermatology':   kWarning,
  'pediatrics':    kSuccess,
  'orthopedics':   kPurple,
  'neurology':     kPurple,
  'general':       kPrimary,
  'gynecology':    Color(0xFFEC4899),
  'ophthalmology': kPrimary,
};
const _bgMap = <String, Color>{
  'cardiology':    kRedLight,
  'dermatology':   kAmberLight,
  'pediatrics':    kGreenLight,
  'orthopedics':   kPurpleLight,
  'neurology':     kPurpleLight,
  'general':       kPrimaryLight,
  'gynecology':    Color(0xFFFCE7F3),
  'ophthalmology': kPrimaryLight,
};

Color _accent(String? s) => _accentMap[s?.toLowerCase()] ?? kPrimary;
Color _bg(String? s)     => _bgMap[s?.toLowerCase()]     ?? kPrimaryLight;
String _cap(String s)    =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

// ── Date helpers ──────────────────────────────────────────────────────────────
const _months     = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const _fullMonths = ['January','February','March','April','May','June',
    'July','August','September','October','November','December'];
const _dayAbbr    = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];

bool _isToday(DateTime dt) {
  final n = DateTime.now();
  return dt.year == n.year && dt.month == n.month && dt.day == n.day;
}

String _fmtFull(DateTime dt) {
  if (_isToday(dt)) return 'Today';
  return '${_dayAbbr[dt.weekday - 1]}, ${dt.day} ${_months[dt.month - 1]}';
}

bool _bookable(int? mode, bool isToday) {
  return switch (mode) { 1 => isToday, 2 => true, 3 => true, _ => false };
}

// ════════════════════════════════════════════════════════════════════
//  FAVORITE BUTTON
// ════════════════════════════════════════════════════════════════════
class _FavoriteButton extends StatefulWidget {
  final bool initialFav;
  final void Function(bool) onToggle;
  const _FavoriteButton({required this.initialFav, required this.onToggle});

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late bool _isFav;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialFav;
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.35)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 35),
      TweenSequenceItem(tween: Tween(begin: 1.35, end: 0.88)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 30),
      TweenSequenceItem(tween: Tween(begin: 0.88, end: 1.06)
          .chain(CurveTween(curve: Curves.easeOut)), weight: 20),
      TweenSequenceItem(tween: Tween(begin: 1.06, end: 1.0)
          .chain(CurveTween(curve: Curves.easeIn)), weight: 15),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_FavoriteButton old) {
    super.didUpdateWidget(old);
    if (old.initialFav != widget.initialFav) {
      setState(() => _isFav = widget.initialFav);
    }
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _isFav = !_isFav);
    widget.onToggle(_isFav);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _isFav ? kFavActive.withOpacity(0.12) : kPrimaryLight,
            border: Border.all(
              color: _isFav ? kFavActive.withOpacity(0.4) : kPrimary.withOpacity(0.2),
            ),
            boxShadow: _isFav
                ? [BoxShadow(color: kFavActive.withOpacity(0.2), blurRadius: 8)]
                : [],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(_isFav),
                size: 17,
                color: _isFav ? kFavActive : kPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BOOK APPOINTMENT SCREEN
// ════════════════════════════════════════════════════════════════════
class BookAppointmentScreen extends ConsumerStatefulWidget {
  final DoctorDetails doctor;
  final int?          bookingForMemberId;
  final bool          initialFavorite;
  final bool          isReschedule;
  final int?          appointmentId;

  const BookAppointmentScreen({
    super.key,
    required this.doctor,
    this.bookingForMemberId,
    this.initialFavorite = false,
    this.isReschedule    = false,
    this.appointmentId,
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
  bool      _isBooking   = false;
  int?      _selectedMemberId;
  bool      _isFavorite  = false;
  int?      _favFetchedDoctorId;
  int?      _favFetchedPatientId;
  bool      _didRouteRefresh = false;
  Timer?    _queueTimer;

  String? _estimatedWaitTime;
  bool    _isEstimateLoading = false;

  @override
  void initState() {
    super.initState();
    final did    = widget.doctor.doctorId;
    final cached = did == null
        ? null
        : ref.read(favoriteViewModelProvider).doctorFavorites[did];
    _isFavorite       = cached ?? widget.initialFavorite;
    _selectedMemberId = widget.bookingForMemberId;

    _queueTimer = Timer.periodic(
        const Duration(seconds: 10), (_) { if (mounted) setState(() {}); });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (did != null) {
        ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(did);
        ref.read(appointmentViewModelProvider.notifier).getBookedSlots(did);
      }
      final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid > 0) {
        ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(pid);
      }
      _tryFetchFavorite();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRouteRefresh) { _didRouteRefresh = true; return; }
    _favFetchedDoctorId  = null;
    _favFetchedPatientId = null;
    _tryFetchFavorite();
  }

  @override
  void dispose() {
    _queueTimer?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _fmtDateApi(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  String _toApiTime(String display) {
    final parts = display.trim().split(' ');
    final hm    = parts[0].split(':');
    int h       = int.parse(hm[0]);
    final m     = hm[1];
    final isPm  = parts.length > 1 && parts[1].toUpperCase() == 'PM';
    if (isPm && h != 12) h += 12;
    if (!isPm && h == 12) h = 0;
    return '${h.toString().padLeft(2, '0')}:$m';
  }

  TimeOfDay _parseTime(String? iso) {
    if (iso == null || iso.isEmpty) return const TimeOfDay(hour: 9, minute: 0);
    final dt = DateTime.tryParse(iso);
    if (dt != null) return TimeOfDay(hour: dt.hour, minute: dt.minute);
    final parts = iso.split(':');
    return TimeOfDay(
        hour: int.tryParse(parts[0]) ?? 9,
        minute: parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0);
  }

  String _fmtTime(String? iso) {
    final t  = _parseTime(iso);
    final sf = t.hour < 12 ? 'AM' : 'PM';
    final h  = t.hour == 0 ? 12 : (t.hour > 12 ? t.hour - 12 : t.hour);
    return '${h.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')} $sf';
  }

  List<String> _buildSlots(DoctorAvailabilityModel avail) {
    final start = _parseTime(avail.startTime);
    final end   = _parseTime(avail.endTime);
    final dur   = avail.slotDuration ?? 10;
    final slots = <String>[];
    int cur     = start.hour * 60 + start.minute;
    final endM  = end.hour * 60 + end.minute;
    while (cur + dur <= endM) {
      final h  = cur ~/ 60;
      final m  = cur % 60;
      final sf = h < 12 ? 'AM' : 'PM';
      final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
      slots.add(
          '${dh.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $sf');
      cur += dur;
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

  bool _isQueueSession(DoctorAvailabilityModel avail) {
    final isToday = _selectedDate != null && _isToday(_selectedDate!);
    return avail.bookingMode == 1 || (avail.bookingMode == 3 && isToday);
  }

  Future<void> _fetchQueueEstimate() async {
    final did = widget.doctor.doctorId;
    if (did == null || !mounted) return;
    setState(() { _isEstimateLoading = true; _estimatedWaitTime = null; });

    await ref.read(appointmentViewModelProvider.notifier)
        .queuePreviewEstimate(AppointmentRequestModel(doctorId: did,slotId: _selectedSlotId));
    if (!mounted) return;

    final qd = ref.read(appointmentViewModelProvider).queuePreviewEstimateResponse;
    String? label;
    if (qd != null) {
      final mins    = qd.estimatedMinutes;
      final arrival = qd.estimatedArrivalTime;
      final ahead   = qd.patientsAhead;
      if (mins != null && arrival != null) {
        label = '~$mins min  ·  arrives around $arrival'
            '${ahead != null ? '  ($ahead ahead)' : ''}';
      } else if (mins != null) {
        label = '~$mins min wait';
      } else if (arrival != null) {
        label = 'Arrives around $arrival';
      }
    }
    setState(() { _estimatedWaitTime = label; _isEstimateLoading = false; });
  }

  void _pickDate(DateTime date, List<DoctorAvailabilityModel> sessions) {
    final isToday  = _isToday(date);
    final bookable = sessions.where((s) => _bookable(s.bookingMode, isToday)).toList();
    setState(() {
      _selectedDate      = date;
      _selectedSlotId    = bookable.length == 1 ? bookable.first.slotId : null;
      _selectedTime      = null;
      _estimatedWaitTime = null;
      _isEstimateLoading = false;
    });

    if (widget.doctor.doctorId != null) {
      ref.read(appointmentViewModelProvider.notifier).getAppointmentAvailability(
        AppointmentRequestModel(
          doctorId: widget.doctor.doctorId,
          appointmentDate: _fmtDateApi(date),
        ),
      );
    }
    if (bookable.length == 1 && _isQueueSession(bookable.first)) {
      _fetchQueueEstimate();
    }
  }

  void _onSessionPicked(int? slotId) {
    final enabled = ref.read(doctorsViewModelProvider).doctorAvailabilities
        .where((a) => a.isEnabled == true).toList();
    setState(() {
      _selectedSlotId    = slotId;
      _selectedTime      = null;
      _estimatedWaitTime = null;
      _isEstimateLoading = false;
    });
    if (slotId == null) return;
    final picked = enabled.firstWhere(
      (a) => a.slotId == slotId, orElse: () => DoctorAvailabilityModel());
    if (_isQueueSession(picked)) _fetchQueueEstimate();
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state     = ref.watch(doctorsViewModelProvider);
    final apptState = ref.watch(appointmentViewModelProvider);
    final patState  = ref.watch(patientLoginViewModelProvider);
    final famState  = ref.watch(familyViewModelProvider);
    final members   = famState.allfamilyMembers.maybeWhen(
        data: (m) => m, orElse: () => <FamilyMember>[]);

    final did    = widget.doctor.doctorId;
    final cached = did == null
        ? null
        : ref.watch(favoriteViewModelProvider).doctorFavorites[did];
    if (cached != null && cached != _isFavorite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isFavorite = cached);
      });
    }

    // Booked times for selected date
    final bookedTimes = <String>{};
    if (_selectedDate != null) {
      final ds = _fmtDateApi(_selectedDate!);
      for (final s in apptState.bookedSlots) {
        if (s.bookingDate?.startsWith(ds) == true && s.startTime != null) {
          bookedTimes.add(_fmtTime(s.startTime));
        }
      }
    }

    // Listeners
    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      if (!widget.isReschedule &&
          next.bookingResponse != null &&
          next.bookingResponse != prev?.bookingResponse &&
          !next.isLoading) {
        _snack(next.bookingResponse!.message ?? 'Appointment booked!');
        setState(() => _isBooking = false);
        Navigator.pop(context, true);
        return;
      }
      if (widget.isReschedule &&
          next.isSuccess &&
          next.rescheduleResponse != null &&
          next.rescheduleResponse != prev?.rescheduleResponse &&
          !next.isLoading) {
        _snack(next.rescheduleResponse!.message ?? 'Appointment rescheduled!');
        setState(() => _isBooking = false);
        Navigator.pop(context, true);
        return;
      }
      if (next.error != null && next.error != prev?.error &&
          !next.isLoading && _isBooking) {
        _snack(next.error!, isError: true);
        setState(() => _isBooking = false);
      }
    });

    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      if (prev?.patientId != next.patientId) _tryFetchFavorite();
    });

    ref.listen<FavoriteState>(favoriteViewModelProvider, (prev, next) {
      final did = widget.doctor.doctorId;
      if (did == null) return;
      final nextFav = next.doctorFavorites[did];
      if (nextFav != null && nextFav != prev?.doctorFavorites[did] && mounted) {
        setState(() => _isFavorite = nextFav);
      }
      if (next.error != null && next.error != prev?.error && mounted) {
        _snack(next.error!, isError: true);
      }
    });

    // Availability
    final enabled  = state.doctorAvailabilities
        .where((a) => a.isEnabled == true).toList();
    final grouped  = _grouped(enabled);
    final selAvail = _selectedSlotId == null
        ? null
        : enabled.firstWhere(
            (a) => a.slotId == _selectedSlotId,
            orElse: () => DoctorAvailabilityModel());
    final dayIsToday = _selectedDate != null && _isToday(_selectedDate!);
    final mode       = selAvail?.bookingMode ?? 0;
    final isQueue    = mode == 1 || (mode == 3 && dayIsToday);

    // Queue open-time check
    String? queueOpenTimeStr;
    bool isQueueOpen = true;
    if (isQueue && dayIsToday && selAvail != null) {
      final leadMin = widget.doctor.qStartSection ?? widget.doctor.leadTime ?? 0;
      if (leadMin > 0) {
        final sessionStart = _parseTime(selAvail.startTime);
        final openMin      = sessionStart.hour * 60 + sessionStart.minute - leadMin;
        if (openMin >= 0) {
          final openH = openMin ~/ 60;
          final openM = openMin % 60;
          final sf    = openH < 12 ? 'AM' : 'PM';
          final dh    = openH == 0 ? 12 : (openH > 12 ? openH - 12 : openH);
          queueOpenTimeStr =
              '${dh.toString().padLeft(2, '0')}:${openM.toString().padLeft(2, '0')} $sf';
          final nowMin = DateTime.now().hour * 60 + DateTime.now().minute;
          isQueueOpen  = nowMin >= openMin;
        }
      }
    }

    final canConfirm = selAvail != null &&
        _bookable(mode, dayIsToday) &&
        (isQueue || _selectedTime != null) &&
        (!isQueue || !dayIsToday || isQueueOpen);

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          _AppBar(
            doctor:       widget.doctor,
            isFavorite:   _isFavorite,
            isReschedule: widget.isReschedule,
            onBack:       () => Navigator.pop(context),
            onFavToggle:  _handleFavoriteToggle,
          ),
          SliverToBoxAdapter(
            child: _StatsRow(doctor: widget.doctor),
          ),
          SliverToBoxAdapter(
            child: _BookingFor(
              patState:         patState,
              members:          members,
              selectedMemberId: _selectedMemberId,
              onSelected: (id) => setState(() => _selectedMemberId = id),
            ),
          ),
          if (state.isLoading)
            const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(
                    color: kPrimary, strokeWidth: 2.5),
              ),
            )
          else if (grouped.isEmpty)
            SliverFillRemaining(
              child: _NoAvail(onBack: () => Navigator.pop(context)),
            )
          else
            SliverToBoxAdapter(
              child: _Body(
                grouped:           grouped,
                enabled:           enabled,
                selectedDate:      _selectedDate,
                selectedSlotId:    _selectedSlotId,
                selectedTime:      _selectedTime,
                selectedAvail:     selAvail,
                dayIsToday:        dayIsToday,
                bookedTimes:       bookedTimes,
                queueOpenTimeStr:  queueOpenTimeStr,
                isQueueOpen:       isQueueOpen,
                estimatedWaitTime: _estimatedWaitTime,
                isEstimateLoading: _isEstimateLoading,
                onPickDate:        _pickDate,
                onPickSession:     _onSessionPicked,
                onPickTime: (t) => setState(() => _selectedTime = t),
                buildSlots:        _buildSlots,
                fmtTime:           _fmtTime,
              ),
            ),
        ],
      ),
      bottomNavigationBar: canConfirm
          ? _ConfirmBar(
              isQueue:        isQueue,
              isReschedule:   widget.isReschedule,
              selectedDate:   _selectedDate,
              selectedSlot:   _selectedTime,
              queueStartTime: isQueue ? _fmtTime(selAvail!.startTime) : null,
              // fee:            widget.doctor.consultationFee,
              isLoading:      _isBooking,
              onConfirm:      _onConfirm,
            )
          : null,
    );
  }

  // ---------------------------------------------------------------------------
  // Snack / Favorite helpers
  // ---------------------------------------------------------------------------

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        backgroundColor: isError ? kError : kPrimary,
        duration: const Duration(seconds: 2),
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white, size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ]),
      ),
    );
  }

  void _showFavSnack(bool added) {
    _snack(
      added
          ? 'Dr. ${widget.doctor.name ?? ''} added to favourites'
          : 'Removed from favourites',
      isError: false,
    );
  }

  void _tryFetchFavorite() {
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) return;
    if (_favFetchedDoctorId == did && _favFetchedPatientId == pid) return;
    _favFetchedDoctorId  = did;
    _favFetchedPatientId = pid;
    ref.read(favoriteViewModelProvider.notifier).fetchFavoriteStatus(pid, did);
  }

  Future<void> _handleFavoriteToggle(bool v) async {
    final prev = _isFavorite;
    setState(() => _isFavorite = v);
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) {
      setState(() => _isFavorite = prev);
      _snack('Please login to use favourites', isError: true);
      return;
    }
    final notifier = ref.read(favoriteViewModelProvider.notifier);
    final ok = v
        ? await notifier.addFavoriteDoctor(pid, did)
        : await notifier.deleteFavoriteDoctor(pid, did);
    if (!ok) {
      setState(() => _isFavorite = prev);
      _snack(ref.read(favoriteViewModelProvider).error ??
          'Failed to update favourites', isError: true);
      return;
    }
    _showFavSnack(v);
  }

  void _onConfirm() {
    if (_isBooking || _selectedDate == null) return;
    final ds    = ref.read(doctorsViewModelProvider);
    final avail = _selectedSlotId == null
        ? null
        : ds.doctorAvailabilities.cast<DoctorAvailabilityModel?>()
            .firstWhere((a) => a?.slotId == _selectedSlotId,
                orElse: () => null);
    final isToday = _isToday(_selectedDate!);
    final mode    = avail?.bookingMode ?? 0;
    final isQueue = mode == 1 || (mode == 3 && isToday);
    final start   =
        isQueue ? null : (_selectedTime != null ? _toApiTime(_selectedTime!) : null);

    setState(() => _isBooking = true);

    if (widget.isReschedule) {
      ref.read(appointmentViewModelProvider.notifier).rescheduleAppointment(
        AppointmentRequestModel(
          appointmentId:   widget.appointmentId,
          doctorId:        widget.doctor.doctorId,
          appointmentDate: _fmtDateApi(_selectedDate!),
          startTime:       start,
          slotId:          _selectedSlotId,
        ),
      );
    } else {
      final ps          = ref.read(patientLoginViewModelProvider);
      final isForMember = _selectedMemberId != null;
      ref.read(appointmentViewModelProvider.notifier).bookAppointment(
        AppointmentRequestModel(
          doctorId:        widget.doctor.doctorId,
          patientId:       isForMember ? _selectedMemberId : ps.patientId,
          appointmentDate: _fmtDateApi(_selectedDate!),
          startTime:       start,
          userType:        isForMember ? 2 : 1,
          slotId:          _selectedSlotId,
        ),
      );
    }
  }
}

// ════════════════════════════════════════════════════════════════════
//  APP BAR WITH GOOGLE MAPS INTEGRATION
// ════════════════════════════════════════════════════════════════════
class _AppBar extends StatelessWidget {
  final DoctorDetails       doctor;
  final bool                isFavorite;
  final bool                isReschedule;
  final VoidCallback        onBack;
  final void Function(bool) onFavToggle;

  const _AppBar({
    required this.doctor,    required this.isFavorite,
    required this.onBack,    required this.onFavToggle,
    this.isReschedule = false,
  });

  // ─── Google Maps Helper ──────────────────────────────────────────────────
  Future<void> _openGoogleMaps(BuildContext context) async {
    final lat = doctor.latitude;
    final lng = doctor.longitude;
    
    if (lat == null || lng == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Location coordinates not available'),
          backgroundColor: kError,
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    // Create Google Maps URL with coordinates
    final googleMapsUrl = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    
    try {
      if (await canLaunchUrl(Uri.parse(googleMapsUrl))) {
        await launchUrl(
          Uri.parse(googleMapsUrl),
          mode: LaunchMode.externalApplication,
        );
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not open Google Maps'),
              backgroundColor: kError,
              duration: Duration(seconds: 2),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening map: $e'),
            backgroundColor: kError,
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ac      = _accent(doctor.specialization);
    final specBg  = _bg(doctor.specialization);
    final initial = (doctor.name?.isNotEmpty ?? false)
        ? doctor.name![0].toUpperCase() : 'D';

    return SliverAppBar(
      expandedHeight:   150,
      pinned:           true,
      backgroundColor:  Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation:        0,
      leading: GestureDetector(
        onTap: onBack,
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: kPrimaryLight, borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 15, color: kPrimary),
        ),
      ),
      title: Text(
        isReschedule ? 'Reschedule' : 'Book Appointment',
        style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: -0.2),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 14),
          child: _FavoriteButton(
              initialFav: isFavorite, onToggle: onFavToggle),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorder),
      ),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          alignment: Alignment.bottomLeft,
          child: Row(
  children: [
    // Avatar
    Stack(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: ac.withOpacity(0.12),
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: ac.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initial,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: ac,
            ),
          ),
        ),
        if (isFavorite)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: kFavActive,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: const Icon(
                Icons.favorite_rounded,
                size: 8,
                color: Colors.white,
              ),
            ),
          ),
      ],
    ),

    const SizedBox(width: 12),

    // Name + details
    Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dr. ${doctor.name ?? 'Unknown'}',
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          const SizedBox(height: 4),

          Row(
            children: [
              if (doctor.specialization != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: specBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _cap(doctor.specialization!),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: ac,
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
                      fontSize: 11,
                      color: kTextMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),

          // Address (no icon here now)
          if (doctor.clinicAddress != null) ...[
            const SizedBox(height: 4),
            Text(
              doctor.clinicAddress!,
              style: const TextStyle(
                fontSize: 10,
                color: kTextMuted,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ],
      ),
    ),

    // 🗺️ Map Icon (RIGHT SIDE)
    if (doctor.clinicAddress != null)
      GestureDetector(
        onTap: () => _openGoogleMaps(context),
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.map_rounded,
            size: 18,
            color: kPrimary,
          ),
        ),
      ),

    // Fee
    // if (doctor.consultationFee != null)
    //   Column(
    //     mainAxisSize: MainAxisSize.min,
    //     crossAxisAlignment: CrossAxisAlignment.end,
    //     children: [
    //       Text(
    //         '₹${doctor.consultationFee!.toStringAsFixed(0)}',
    //         style: const TextStyle(
    //           fontSize: 16,
    //           fontWeight: FontWeight.w700,
    //           color: kSuccess,
    //         ),
    //       ),
    //       const Text(
    //         'consult fee',
    //         style: TextStyle(fontSize: 10, color: kTextMuted),
    //       ),
    //     ],
    //   ),
  ],
),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  STATS ROW
// ════════════════════════════════════════════════════════════════════
class _StatsRow extends ConsumerWidget {
  final DoctorDetails doctor;
  const _StatsRow({required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviews  = ref.watch(reviewViewModelProvider).reviews ?? <ReviewModel>[];
    final avgRating = reviews.isEmpty
        ? 0.0
        : reviews.fold<double>(0, (acc, r) =>
              acc + (r.rating?.toDouble() ?? 0)) /
            reviews.length;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
      child: Row(
        children: [
          _StatBox(label: 'Experience',
              value: doctor.experience != null
                  ? '${doctor.experience} yrs' : '--'),
          const SizedBox(width: 8),
          _StatBox(
            label: reviews.isEmpty ? 'Rating' : '${reviews.length} reviews',
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.star_rounded, color: kWarning, size: 14),
                const SizedBox(width: 2),
                Text(
                  avgRating == 0 ? '--' : avgRating.toStringAsFixed(1),
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatBox(label: 'Patients', value: '1.2k+'),
          const SizedBox(width: 8),
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.push(context,
                  MaterialPageRoute(
                      builder: (_) => DoctorProfileScreen(doctor: doctor))),
              child: Container(
                height: 58,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withOpacity(0.25)),
                ),
                child: const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_outline_rounded,
                        color: kPrimary, size: 16),
                    SizedBox(height: 3),
                    Text('Profile',
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kPrimary)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String  label;
  final String? value;
  final Widget? child;
  const _StatBox({required this.label, this.value, this.child});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          height: 58,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: kTextMuted)),
              const SizedBox(height: 3),
              child ??
                  Text(value ?? '--',
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  BOOKING FOR DROPDOWN
// ════════════════════════════════════════════════════════════════════
class _BookingFor extends StatelessWidget {
  final PatientLoginState  patState;
  final List<FamilyMember> members;
  final int?               selectedMemberId;
  final ValueChanged<int?> onSelected;

  const _BookingFor({
    required this.patState, required this.members,
    required this.selectedMemberId, required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Row(children: [
          CircleAvatar(
            radius: 13,
            backgroundColor: kPrimary.withOpacity(0.15),
            child: Text(
              (patState.name?.isNotEmpty ?? false)
                  ? patState.name![0].toUpperCase() : 'M',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: kPrimary)),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(patState.name ?? 'Me',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              const Text('You',
                  style: TextStyle(fontSize: 10, color: kTextMuted)),
            ],
          ),
        ]),
      ),
      ...members.map((m) => DropdownMenuItem<int?>(
            value: m.memberId,
            child: Row(children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: kPurple.withOpacity(0.12),
                child: Text(
                  m.memberName?.isNotEmpty == true
                      ? m.memberName![0].toUpperCase() : '?',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kPurple)),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(m.memberName ?? '?',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  if (m.relationName?.isNotEmpty == true)
                    Text(m.relationName!,
                        style: const TextStyle(
                            fontSize: 10, color: kTextMuted)),
                ],
              ),
            ]),
          )),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: kPrimaryLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.person_outline_rounded, color: kPrimary, size: 14),
        const SizedBox(width: 8),
        const Text('Booking for',
            style: TextStyle(fontSize: 12, color: kTextSecondary)),
        const SizedBox(width: 4),
        Expanded(
          child: DropdownButtonHideUnderline(
            child: DropdownButton<int?>(
              value: selectedMemberId,
              isDense: true,
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 15, color: kPrimary),
              dropdownColor: Colors.white,
              borderRadius: BorderRadius.circular(12),
              items: items,
              onChanged: onSelected,
              selectedItemBuilder: (_) => [
                _dropSel(patState.name ?? 'Me'),
                ...members.map(
                    (m) => _dropSel(m.memberName ?? 'Member')),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _dropSel(String text) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimary)),
      );
}

// ════════════════════════════════════════════════════════════════════
//  BODY
// ════════════════════════════════════════════════════════════════════
class _Body extends StatelessWidget {
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final List<DoctorAvailabilityModel> enabled;
  final DateTime?    selectedDate;
  final int?         selectedSlotId;
  final String?      selectedTime;
  final DoctorAvailabilityModel? selectedAvail;
  final bool         dayIsToday;
  final Set<String>  bookedTimes;
  final String?      queueOpenTimeStr;
  final bool         isQueueOpen;
  final String?      estimatedWaitTime;
  final bool         isEstimateLoading;

  final void Function(DateTime, List<DoctorAvailabilityModel>) onPickDate;
  final ValueChanged<int?>    onPickSession;
  final ValueChanged<String>  onPickTime;
  final List<String> Function(DoctorAvailabilityModel) buildSlots;
  final String Function(String?) fmtTime;

  const _Body({
    required this.grouped, required this.enabled,
    required this.selectedDate, required this.selectedSlotId,
    required this.selectedTime, required this.selectedAvail,
    required this.dayIsToday, required this.bookedTimes,
    required this.onPickDate, required this.onPickSession,
    required this.onPickTime, required this.buildSlots, required this.fmtTime,
    this.queueOpenTimeStr, this.isQueueOpen = true,
    this.estimatedWaitTime, this.isEstimateLoading = false,
  });

  String _dayName(int w) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    return n[(w - 1).clamp(0, 6)];
  }

  @override
  Widget build(BuildContext context) {
    final sessions = selectedDate == null
        ? <DoctorAvailabilityModel>[]
        : (grouped[_dayName(selectedDate!.weekday)] ?? [])
            .where((s) => _bookable(s.bookingMode, dayIsToday))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 100),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _CalendarStrip(
          grouped:        grouped,
          selectedDate:   selectedDate,
          onDateSelected: (date) =>
              onPickDate(date, grouped[_dayName(date.weekday)] ?? []),
        ),
        if (selectedDate != null) ...[
          const SizedBox(height: 12),
          _DateBadge(date: selectedDate!),
        ],
        if (sessions.length > 1) ...[
          const SizedBox(height: 18),
          _sectionLabel('Select Session'),
          const SizedBox(height: 8),
          _SessionRow(
            sessions:       sessions,
            selectedSlotId: selectedSlotId,
            onSelected:     onPickSession,
            fmtTime:        fmtTime,
          ),
        ],
        if (selectedAvail != null) ...[
          const SizedBox(height: 20),
          if (selectedAvail!.bookingMode == 1 ||
              (selectedAvail!.bookingMode == 3 && dayIsToday))
            _QueueCard(
              avail:             selectedAvail!,
              queueOpenTimeStr:  queueOpenTimeStr,
              isQueueOpen:       isQueueOpen,
              estimatedWaitTime: estimatedWaitTime,
              isEstimateLoading: isEstimateLoading,
            )
          else
            _SlotPicker(
              slots:       buildSlots(selectedAvail!),
              selected:    selectedTime,
              isToday:     dayIsToday,
              bookedTimes: bookedTimes,
              onSelected:  onPickTime,
            ),
        ],
      ]),
    );
  }
}

Widget _sectionLabel(String t) => Text(
      t.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: kTextMuted,
          letterSpacing: 0.8),
    );

// ════════════════════════════════════════════════════════════════════
//  CALENDAR STRIP
// ════════════════════════════════════════════════════════════════════
class _CalendarStrip extends StatefulWidget {
  final Map<String, List<DoctorAvailabilityModel>> grouped;
  final DateTime?              selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  const _CalendarStrip({
    required this.grouped, required this.selectedDate,
    required this.onDateSelected,
  });
  @override State<_CalendarStrip> createState() => _CalendarStripState();
}

class _CalendarStripState extends State<_CalendarStrip> {
  final _scroll = ScrollController();
  static const _cw = 52.0, _gap = 6.0, _days = 28;

  @override
  void dispose() { _scroll.dispose(); super.dispose(); }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final today = DateTime.now();
      for (int i = 0; i < _days; i++) {
        final d = today.add(Duration(days: i));
        if (_avail(d)) {
          final off = i * (_cw + _gap) - 16;
          if (_scroll.hasClients) {
            _scroll.animateTo(
              off.clamp(0.0, _scroll.position.maxScrollExtent),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
          break;
        }
      }
    });
  }

  bool _avail(DateTime dt) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final s = widget.grouped[n[(dt.weekday - 1).clamp(0, 6)]];
    return s?.any((a) => _bookable(a.bookingMode, _isToday(dt))) == true;
  }

  Color? _dot(DateTime dt) {
    const n = ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'];
    final s = widget.grouped[n[(dt.weekday - 1).clamp(0, 6)]];
    if (s == null) return null;
    final isToday = _isToday(dt);
    final b = s.where((a) => _bookable(a.bookingMode, isToday)).toList();
    if (b.isEmpty) return null;
    if (b.any((a) => a.bookingMode == 1) && isToday) return kWarning;
    if (b.any((a) => a.bookingMode == 3)) return isToday ? kWarning : kPrimary;
    return kPrimary;
  }

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final items = <_CalItem>[];
    DateTime? lastM;
    for (int i = 0; i < _days; i++) {
      final d = today.add(Duration(days: i));
      if (lastM == null || d.month != lastM.month) {
        items.add(_CalItem.header('${_fullMonths[d.month - 1]} ${d.year}'));
        lastM = d;
      }
      items.add(_CalItem.date(d));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Select Date'),
      const SizedBox(height: 10),
      SizedBox(
        height: 86,
        child: ListView.builder(
          controller:      _scroll,
          scrollDirection: Axis.horizontal,
          itemCount:       items.length,
          itemBuilder: (_, i) {
            final item = items[i];
            if (item.isHeader) {
              return Container(
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.only(right: 10, bottom: 10),
                child: Text(item.label!,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted)),
              );
            }
            final dt    = item.dt!;
            final avail = _avail(dt);
            final dot   = _dot(dt);
            final isSel = widget.selectedDate?.year == dt.year &&
                widget.selectedDate?.month == dt.month &&
                widget.selectedDate?.day == dt.day;

            return Padding(
              padding: const EdgeInsets.only(right: _gap),
              child: GestureDetector(
                onTap: avail ? () => widget.onDateSelected(dt) : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: _cw,
                  decoration: BoxDecoration(
                    color: isSel
                        ? kPrimary
                        : (avail ? Colors.white : Colors.transparent),
                    borderRadius: BorderRadius.circular(12),
                    border: isSel
                        ? null
                        : (avail ? Border.all(color: kBorder) : null),
                    boxShadow: isSel
                        ? [BoxShadow(
                            color: kPrimary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3))]
                        : null,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(_dayAbbr[dt.weekday - 1],
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: isSel
                                  ? Colors.white.withOpacity(0.8)
                                  : (avail
                                      ? (dt.weekday >= 6
                                          ? kPrimary
                                          : kTextMuted)
                                      : kTextMuted.withOpacity(0.3)))),
                      const SizedBox(height: 4),
                      Text('${dt.day}',
                          style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isSel
                                  ? Colors.white
                                  : (avail
                                      ? kTextPrimary
                                      : kTextMuted.withOpacity(0.3)))),
                      const SizedBox(height: 4),
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSel
                              ? Colors.white.withOpacity(0.7)
                              : (dot ?? Colors.transparent),
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
    ]);
  }
}

class _CalItem {
  final bool isHeader; final String? label; final DateTime? dt;
  const _CalItem._({required this.isHeader, this.label, this.dt});
  factory _CalItem.header(String l) => _CalItem._(isHeader: true, label: l);
  factory _CalItem.date(DateTime d)  => _CalItem._(isHeader: false, dt: d);
}

// ════════════════════════════════════════════════════════════════════
//  DATE BADGE
// ════════════════════════════════════════════════════════════════════
class _DateBadge extends StatelessWidget {
  final DateTime date;
  const _DateBadge({required this.date});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: kPrimaryLight,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kPrimary.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.event_rounded, size: 14, color: kPrimary),
          const SizedBox(width: 8),
          Text(_fmtFull(date),
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kPrimary)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SESSION ROW
// ════════════════════════════════════════════════════════════════════
class _SessionRow extends StatelessWidget {
  final List<DoctorAvailabilityModel> sessions;
  final int?                          selectedSlotId;
  final ValueChanged<int?>            onSelected;
  final String Function(String?)      fmtTime;

  const _SessionRow({
    required this.sessions, required this.selectedSlotId,
    required this.onSelected, required this.fmtTime,
  });

  Color _modeColor(int? m) => switch (m) {
    1 => kWarning, 2 => kPrimary, 3 => kSuccess, _ => kTextMuted,
  };

  String _modeLabel(int? m) => switch (m) {
    1 => 'Queue', 2 => 'Slots', 3 => 'Queue + Slots', _ => 'Session',
  };

  @override
  Widget build(BuildContext context) => Column(
        children: sessions.map((s) {
          final sel   = selectedSlotId == s.slotId;
          final color = _modeColor(s.bookingMode);
          return GestureDetector(
            onTap: () => onSelected(s.slotId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: sel ? kPrimary : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: sel ? kPrimary : kBorder,
                    width: sel ? 1.5 : 1),
              ),
              child: Row(children: [
                Icon(Icons.access_time_rounded,
                    size: 15,
                    color: sel ? Colors.white : kPrimary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${fmtTime(s.startTime)}  –  ${fmtTime(s.endTime)}',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : kTextPrimary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: sel
                        ? Colors.white.withOpacity(0.15)
                        : color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    _modeLabel(s.bookingMode),
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: sel ? Colors.white : color),
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      );
}

// ════════════════════════════════════════════════════════════════════
//  QUEUE CARD
// ════════════════════════════════════════════════════════════════════
class _QueueCard extends StatelessWidget {
  final DoctorAvailabilityModel avail;
  final String? queueOpenTimeStr;
  final bool    isQueueOpen;
  final String? estimatedWaitTime;
  final bool    isEstimateLoading;

  const _QueueCard({
    required this.avail,
    this.queueOpenTimeStr,
    this.isQueueOpen      = true,
    this.estimatedWaitTime,
    this.isEstimateLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final noteColor = isQueueOpen ? kSuccess : kError;
    final noteBg    = isQueueOpen
        ? kGreenLight.withOpacity(0.4)
        : kRedLight.withOpacity(0.4);
    final noteIcon  = isQueueOpen
        ? Icons.check_circle_rounded
        : Icons.access_time_rounded;
    final noteText  = !isQueueOpen && queueOpenTimeStr != null
        ? 'Queue booking opens at $queueOpenTimeStr'
        : 'Queue booking is open';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Queue Booking'),
      const SizedBox(height: 8),

      // Open/closed status
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: noteBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: noteColor.withOpacity(0.3)),
        ),
        child: Row(children: [
          Icon(noteIcon, size: 15, color: noteColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(noteText,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: noteColor)),
          ),
        ]),
      ),
      const SizedBox(height: 8),

      // Estimate banner
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        transitionBuilder: (child, anim) =>
            FadeTransition(opacity: anim, child: child),
        child: isEstimateLoading
            ? _EstimateBanner.loading(key: const ValueKey('loading'))
            : (estimatedWaitTime?.isNotEmpty == true)
                ? _EstimateBanner.value(
                    key: const ValueKey('value'),
                    text: estimatedWaitTime!)
                : const SizedBox.shrink(key: ValueKey('empty')),
      ),

      if (estimatedWaitTime?.isNotEmpty == true || isEstimateLoading)
        const SizedBox(height: 8),

      // Walk-in card
      Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kAmberLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kWarning.withOpacity(0.3)),
        ),
        child: Row(children: [
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kWarning.withOpacity(0.15),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(Icons.confirmation_number_rounded,
                size: 20, color: kWarning),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Walk-in Queue',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary)),
                const SizedBox(height: 2),
                Text('Show up today  ·  ${avail.slotDuration ?? 10} min per patient',
                    style: const TextStyle(
                        fontSize: 12, color: kTextSecondary)),
              ],
            ),
          ),
        ]),
      ),
    ]);
  }
}

class _EstimateBanner extends StatelessWidget {
  final bool    _isLoading;
  final String? _text;

  const _EstimateBanner.loading({super.key})
      : _isLoading = true, _text = null;
  const _EstimateBanner.value({super.key, required String text})
      : _isLoading = false, _text = text;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: kInfoLight.withOpacity(0.4),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kInfo.withOpacity(0.25)),
        ),
        child: Row(children: [
          if (_isLoading)
            const SizedBox(
              width: 14, height: 14,
              child: CircularProgressIndicator(
                  strokeWidth: 1.8, color: kInfo),
            )
          else
            const Icon(Icons.hourglass_top_rounded,
                size: 14, color: kInfo),
          const SizedBox(width: 8),
          if (_isLoading)
            const Text('Fetching estimated wait time…',
                style: TextStyle(fontSize: 12, color: kTextMuted))
          else
            Expanded(
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 12, color: kInfo),
                  children: [
                    const TextSpan(text: 'Estimated wait: '),
                    TextSpan(
                      text: _text,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SLOT PICKER
// ════════════════════════════════════════════════════════════════════
class _SlotPicker extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final bool                 isToday;
  final Set<String>          bookedTimes;
  final ValueChanged<String> onSelected;

  const _SlotPicker({
    required this.slots,       required this.selected,
    required this.bookedTimes, required this.onSelected,
    this.isToday = false,
  });

  int _mins(String slot) {
    final p  = slot.split(':');
    final h  = int.tryParse(p[0]) ?? 0;
    final r  = p[1].split(' ');
    final m  = int.tryParse(r[0]) ?? 0;
    final sf = r[1];
    var hr   = h;
    if (sf == 'PM' && hr != 12) hr += 12;
    if (sf == 'AM' && hr == 12) hr = 0;
    return hr * 60 + m;
  }

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
          child: Text('No slots available',
              style: TextStyle(color: kTextMuted, fontSize: 13)),
        ),
      );
    }
    final nowMins = isToday
        ? DateTime.now().hour * 60 + DateTime.now().minute : -1;
    final morning   = slots.where((s) => _mins(s) < 720).toList();
    final afternoon = slots.where((s) {
      final m = _mins(s); return m >= 720 && m < 1020;
    }).toList();
    final evening   = slots.where((s) => _mins(s) >= 1020).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Select Time Slot'),
      const SizedBox(height: 12),
      if (morning.isNotEmpty) ...[
        _SlotGroupHeader(
            icon: Icons.wb_sunny_outlined, label: 'Morning'),
        const SizedBox(height: 8),
        _SlotGrid(
            slots: morning, selected: selected,
            booked: bookedTimes, nowMins: nowMins,
            onSelected: onSelected),
        const SizedBox(height: 14),
      ],
      if (afternoon.isNotEmpty) ...[
        _SlotGroupHeader(
            icon: Icons.wb_twilight_outlined, label: 'Afternoon'),
        const SizedBox(height: 8),
        _SlotGrid(
            slots: afternoon, selected: selected,
            booked: bookedTimes, nowMins: nowMins,
            onSelected: onSelected),
        const SizedBox(height: 14),
      ],
      if (evening.isNotEmpty) ...[
        _SlotGroupHeader(
            icon: Icons.nights_stay_outlined, label: 'Evening'),
        const SizedBox(height: 8),
        _SlotGrid(
            slots: evening, selected: selected,
            booked: bookedTimes, nowMins: nowMins,
            onSelected: onSelected),
      ],
    ]);
  }
}

class _SlotGroupHeader extends StatelessWidget {
  final IconData icon;
  final String   label;
  const _SlotGroupHeader({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
        Icon(icon, size: 13, color: kTextMuted),
        const SizedBox(width: 5),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kTextMuted)),
      ]);
}

class _SlotGrid extends StatelessWidget {
  final List<String>         slots;
  final String?              selected;
  final Set<String>          booked;
  final int                  nowMins;
  final ValueChanged<String> onSelected;

  const _SlotGrid({
    required this.slots,    required this.selected,
    required this.booked,   required this.nowMins,
    required this.onSelected,
  });

  int _slotMins(String slot) {
    final p  = slot.split(':');
    final h  = int.tryParse(p[0]) ?? 0;
    final r  = p[1].split(' ');
    final m  = int.tryParse(r[0]) ?? 0;
    final sf = r[1];
    var hr   = h;
    if (sf == 'PM' && hr != 12) hr += 12;
    if (sf == 'AM' && hr == 12) hr = 0;
    return hr * 60 + m;
  }

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 8, runSpacing: 8,
        children: slots.map((slot) {
          final isSel    = selected == slot;
          final isBooked = booked.contains(slot);
          final isPast   = nowMins >= 0 && _slotMins(slot) <= nowMins;
          final disabled = isBooked || isPast;

          return GestureDetector(
            onTap: disabled ? null : () => onSelected(slot),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: disabled
                    ? const Color(0xFFF7F8FA)
                    : isSel
                        ? kPrimary
                        : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: disabled
                      ? kBorder
                      : (isSel ? kPrimary : kBorder),
                ),
              ),
              child: Text(slot,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: disabled
                          ? kTextMuted
                          : (isSel ? Colors.white : kTextPrimary),
                      decoration:
                          isBooked ? TextDecoration.lineThrough : null,
                      decorationColor: kTextMuted)),
            ),
          );
        }).toList(),
      );
}

// ════════════════════════════════════════════════════════════════════
//  CONFIRM BAR
// ════════════════════════════════════════════════════════════════════
class _ConfirmBar extends StatelessWidget {
  final bool         isQueue;
  final bool         isReschedule;
  final DateTime?    selectedDate;
  final String?      selectedSlot;
  final String?      queueStartTime;
  // final double?      fee;
  final bool         isLoading;
  final VoidCallback onConfirm;

  const _ConfirmBar({
    required this.isQueue,      required this.selectedDate,
    required this.selectedSlot, 
    // required this.fee,
    required this.isLoading,    required this.onConfirm,
    this.queueStartTime, this.isReschedule = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = selectedDate != null ? _fmtFull(selectedDate!) : '';
    final label   = isQueue
        ? 'Queue  ·  $dateStr'
        : '$selectedSlot  ·  $dateStr';

    return Container(
      padding: EdgeInsets.fromLTRB(
          14, 10, 14, 10 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        if (selectedSlot != null || isQueue)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Selected slot',
                    style: TextStyle(
                        fontSize: 11, color: kTextMuted)),
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary),
                    overflow: TextOverflow.ellipsis),
              ]),
              const Spacer(),
              // if (fee != null)
                // Column(
                //   crossAxisAlignment: CrossAxisAlignment.end,
                  // children: [
                  //   const Text('Consult fee',
                  //       style: TextStyle(
                  //           fontSize: 11, color: kTextMuted)),
                  //   Text('₹${fee!.toStringAsFixed(0)}',
                  //       style: const TextStyle(
                  //           fontSize: 15,
                  //           fontWeight: FontWeight.w700,
                  //           color: kSuccess)),
                  // ],
                // ),
            ]),
          ),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: isLoading ? null : onConfirm,
            style: ElevatedButton.styleFrom(
              backgroundColor:         kPrimary,
              foregroundColor:         Colors.white,
              disabledBackgroundColor: kPrimaryLight,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: isLoading
                ? const SizedBox(
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2.5))
                : Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isReschedule
                            ? Icons.edit_calendar_rounded
                            : (isQueue
                                ? Icons.confirmation_number_rounded
                                : Icons.calendar_month_rounded),
                        size: 17,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        isReschedule
                            ? 'Reschedule Appointment'
                            : 'Confirm Appointment',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NO AVAILABILITY
// ════════════════════════════════════════════════════════════════════
class _NoAvail extends StatelessWidget {
  final VoidCallback onBack;
  const _NoAvail({required this.onBack});

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.event_busy_rounded,
                  size: 28, color: kPrimary),
            ),
            const SizedBox(height: 14),
            const Text('No availability found',
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text(
              'This doctor has no available slots at the moment.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: kTextSecondary, height: 1.5),
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 44,
              child: ElevatedButton(
                onPressed: onBack,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Go Back',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      );
}