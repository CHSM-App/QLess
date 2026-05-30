import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart' show prescriptionViewModelProvider;
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/review_viewmodel.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';
import 'package:url_launcher/url_launcher.dart';

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

// ── Filter tabs ───────────────────────────────────────────────────────────────
const _filters = [
  _FilterTab('all',       'All',       Icons.list_rounded,          kPrimary, kPrimaryLight),
  _FilterTab('today',     'Today',     Icons.today_rounded,         kInfo,    kInfoLight),
  _FilterTab('upcoming',  'Upcoming',  Icons.schedule_rounded,      kPurple,  kPurpleLight),
  _FilterTab('completed', 'Completed', Icons.check_circle_rounded,  kSuccess, kGreenLight),
  _FilterTab('cancelled', 'Cancelled', Icons.cancel_rounded,        kError,   kRedLight),
];

class _FilterTab {
  final String key, label;
  final IconData icon;
  final Color color, bg;
  const _FilterTab(this.key, this.label, this.icon, this.color, this.bg);
}

// ── Date filter enum ──────────────────────────────────────────────────────────
enum _DateFilter { all, today, thisWeek, thisMonth, last3Months, last6Months, thisYear, custom }

extension _DateFilterX on _DateFilter {
  String get label => switch (this) {
    _DateFilter.all         => 'All Time',
    _DateFilter.today       => 'Today',
    _DateFilter.thisWeek    => 'This Week',
    _DateFilter.thisMonth   => 'This Month',
    _DateFilter.last3Months => 'Last 3 Months',
    _DateFilter.last6Months => 'Last 6 Months',
    _DateFilter.thisYear    => 'This Year',
    _DateFilter.custom      => 'Custom Range',
  };
  IconData get icon => switch (this) {
    _DateFilter.all         => Icons.all_inclusive_rounded,
    _DateFilter.today       => Icons.today_rounded,
    _DateFilter.thisWeek    => Icons.view_week_rounded,
    _DateFilter.thisMonth   => Icons.calendar_month_rounded,
    _DateFilter.last3Months => Icons.date_range_rounded,
    _DateFilter.last6Months => Icons.date_range_rounded,
    _DateFilter.thisYear    => Icons.calendar_today_rounded,
    _DateFilter.custom      => Icons.tune_rounded,
  };
}

// ── Helpers ───────────────────────────────────────────────────────────────────
Color _statusColor(String? s) => switch (s?.toLowerCase()) {
  'upcoming' || 'confirmed' || 'booked' => kInfo,
  'complete' || 'completed'             => kSuccess,
  'cancelled' || 'cancled'              => kError,
  'reschedule'                          => kWarning,
  _                                     => kWarning,
};
Color _statusBg(String? s) => switch (s?.toLowerCase()) {
  'upcoming' || 'confirmed' || 'booked' => kInfoLight,
  'complete' || 'completed'             => kGreenLight,
  'cancelled' || 'cancled'              => kRedLight,
  'reschedule'                          => kAmberLight,
  _                                     => kAmberLight,
};
IconData _statusIcon(String? s) => switch (s?.toLowerCase()) {
  'upcoming' || 'confirmed' || 'booked' => Icons.schedule_rounded,
  'complete' || 'completed'             => Icons.check_circle_rounded,
  'cancelled' || 'cancled'              => Icons.cancel_rounded,
  'reschedule'                          => Icons.event_repeat_rounded,
  _                                     => Icons.info_rounded,
};

/// Display label for a status chip ("reschedule" → "Reschedule needed").
String _statusLabel(String? s) => switch (s?.toLowerCase()) {
  'reschedule' => 'Reschedule needed',
  _            => _cap(s),
};

String _fmtDate(String? d) {
  if (d == null) return '—';
  final p = DateTime.tryParse(d);
  return p == null ? d : DateFormat('dd MMM yyyy').format(p);
}

String _fmtDateRel(String? d) {
  if (d == null) return '—';
  final p = DateTime.tryParse(d);
  if (p == null) return d;
  final now   = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date  = DateTime(p.year, p.month, p.day);
  final diff  = date.difference(today).inDays;
  if (diff ==  0) return 'Today';
  if (diff ==  1) return 'Tomorrow';
  if (diff == -1) return 'Yesterday';
  if (diff > 0 && diff <= 7) return 'In $diff days';
  return DateFormat('dd MMM yyyy').format(p);
}

String _fmtTime(String? t) {
  if (t == null) return '';
  final value = t.trim();
  if (value.isEmpty || value == '--' || value.toLowerCase() == 'null') {
    return '';
  }
  final p = DateTime.tryParse(value);
  return p == null ? value : DateFormat('hh:mm a').format(p);
}

bool _hasAppointmentTime(AppointmentList a) =>
    _fmtTime(a.startTime).isNotEmpty || _fmtTime(a.endTime).isNotEmpty;

String _appointmentTimePrimary(AppointmentList a) {
  final start = _fmtTime(a.startTime);
  final end = _fmtTime(a.endTime);
  if (start.isNotEmpty) return start;
  return end;
}

String _appointmentTimeSecondary(AppointmentList a) {
  final start = _fmtTime(a.startTime);
  final end = _fmtTime(a.endTime);
  if (start.isNotEmpty && end.isNotEmpty) return '– $end';
  return '';
}

String _appointmentTimeChipSub(AppointmentList a) {
  final start = _fmtTime(a.startTime);
  final end = _fmtTime(a.endTime);
  if (start.isNotEmpty && end.isNotEmpty) return 'Ends $end';
  return '';
}

String _cap(String? s) {
  if (s == null || s.isEmpty) return '—';
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

// Start time as minutes-of-day for ordering same-date appointments
// (earliest time first). Appointments without a time sort to the end.
int _startMinutes(AppointmentList a) {
  final t = a.startTime;
  if (t == null || t.trim().isEmpty) return 1 << 30;
  final parsed = DateTime.tryParse(t.trim());
  if (parsed != null) return parsed.hour * 60 + parsed.minute;
  final parts = t.trim().split(':');
  if (parts.length >= 2) {
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    return h * 60 + m;
  }
  return 1 << 30;
}

Future<void> openMap(double lat, double lng, String? label) async {
  final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=${Uri.encodeComponent(label ?? 'Clinic')}');
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// ── Status filter logic ───────────────────────────────────────────────────────
bool _isToday(AppointmentList a) {
  final p = DateTime.tryParse(a.appointmentDate ?? '');
  if (p == null) return false;
  // Cancelled/completed appointments belong in their own tabs, not Today —
  // Today shows what's actively happening today.
  final s = a.status?.toLowerCase();
  if (_isCancelStatus(s) || s == 'completed' || s == 'complete') return false;
  final n = DateTime.now();
  return p.year == n.year && p.month == n.month && p.day == n.day;
}

// All cancellation status variants — 'cancelled' (patient self-cancel),
// 'cancled' (doctor cancel — 'CancleD' lowercased), and 'canceld' (legacy
// typo from old 'cancelD' rows). Centralized so every filter agrees.
bool _isCancelStatus(String? s) {
  final l = s?.toLowerCase();
  return l == 'cancelled' || l == 'cancled' || l == 'canceld';
}

bool _isUpcoming(AppointmentList a) {
  final p = DateTime.tryParse(a.appointmentDate ?? '');
  if (p == null) return false;
  final s = a.status?.toLowerCase();
  if (_isCancelStatus(s) || s == 'completed' || s == 'complete') return false;
  final n = DateTime.now();
  return DateTime(p.year, p.month, p.day).isAfter(DateTime(n.year, n.month, n.day));
}

bool _isCompleted(AppointmentList a) {
  final s = a.status?.toLowerCase();
  return s == 'completed' || s == 'complete';
}

bool _isCancelled(AppointmentList a) {
  return _isCancelStatus(a.status);
}

// ── Date filter logic ─────────────────────────────────────────────────────────
bool _passesDateFilter(AppointmentList a, _DateFilter df,
    DateTime? customFrom, DateTime? customTo) {
  final p = DateTime.tryParse(a.appointmentDate ?? '');
  if (p == null) return df == _DateFilter.all;
  final now = DateTime.now();
  return switch (df) {
    _DateFilter.all         => true,
    _DateFilter.today       => p.year == now.year && p.month == now.month && p.day == now.day,
    _DateFilter.thisWeek    => p.isAfter(
        DateTime(now.year, now.month, now.day)
            .subtract(Duration(days: now.weekday - 1))
            .subtract(const Duration(seconds: 1))),
    _DateFilter.thisMonth   => p.year == now.year && p.month == now.month,
    _DateFilter.last3Months => p.isAfter(now.subtract(const Duration(days: 90))),
    _DateFilter.last6Months => p.isAfter(now.subtract(const Duration(days: 180))),
    _DateFilter.thisYear    => p.year == now.year,
    _DateFilter.custom      => () {
        if (customFrom != null && p.isBefore(customFrom)) return false;
        if (customTo != null &&
            p.isAfter(customTo.add(const Duration(days: 1)))) return false;
        return true;
      }(),
  };
}

List<AppointmentList> applyFilter(
    List<AppointmentList> list, String filter, String search,
    _DateFilter dateFilter, DateTime? customFrom, DateTime? customTo) {
  return list.where((a) {
    final matchSearch = search.isEmpty ||
        (a.patientName?.toLowerCase().contains(search.toLowerCase()) ?? false);
    final matchStatus = switch (filter) {
      'today'     => _isToday(a),
      'upcoming'  => _isUpcoming(a),
      'completed' => _isCompleted(a),
      'cancelled' => _isCancelled(a),
      _           => true,
    };
    final matchDate = _passesDateFilter(a, dateFilter, customFrom, customTo);
    return matchSearch && matchStatus && matchDate;
  }).toList();
}

// ════════════════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════════════════
class AppointmentScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onTabChange;
  const AppointmentScreen({super.key, this.onTabChange});

  @override
  ConsumerState<AppointmentScreen> createState() => AppointmentScreenState();
}

class AppointmentScreenState extends ConsumerState<AppointmentScreen>
    with SingleTickerProviderStateMixin {
  String _search       = '';
  String _filterStatus = 'today';
  bool   _didFetch     = false;
  bool   _isFetching   = false;
  bool   _isWaiting    = false;
  bool   _idMissing    = false;
  bool   _didReadRouteArgs = false; // honour route args (e.g. filter=cancelled) once
  int?   _pendingDetailApptId;      // notification tap: auto-open this appt's detail
  int?   _pendingRatingApptId;      // 'Appointment Complete' notification: open review dialog

  // ── Date filter state ──────────────────────────────────────────────
  _DateFilter _dateFilter = _DateFilter.all;
  DateTime?   _customFrom;
  DateTime?   _customTo;
  bool        _sortNewest = true;

  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _filters.length, vsync: this, initialIndex: 1);
    _tabCtrl.addListener(_syncFilterToSettledTab);
    _tabCtrl.animation?.addListener(_syncFilterToSwipeProgress);
    Future.microtask(_fetch);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour route args (e.g. notification tap with {'filter': 'cancelled'})
    // — switch to that tab once on entry.
    if (_didReadRouteArgs) return;
    _didReadRouteArgs = true;

    final args = ModalRoute.of(context)?.settings.arguments;
    if (args is Map) {
      if (args['filter'] is String) {
        final filterKey = args['filter'] as String;
        final idx = _filters.indexWhere((f) => f.key == filterKey);
        if (idx != -1 && _tabCtrl.index != idx) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _tabCtrl.animateTo(idx);
          });
        }
      }
      // Notification-tap deep link: auto-open the detail sheet for this
      // specific appointment once the list finishes loading.
      final rawId = args['appointment_id'];
      final apptId = rawId is int ? rawId : int.tryParse('$rawId');
      if (apptId != null && apptId > 0) _pendingDetailApptId = apptId;
    }
  }

  @override
  void dispose() {
    _tabCtrl.animation?.removeListener(_syncFilterToSwipeProgress);
    _tabCtrl.removeListener(_syncFilterToSettledTab);
    _tabCtrl.dispose();
    super.dispose();
  }

  void _setFilterIndex(int index) {
    final next = _filters[index].key;
    if (_filterStatus == next) return;
    setState(() => _filterStatus = next);
  }

  void _syncFilterToSettledTab() {
    if (!_tabCtrl.indexIsChanging) _setFilterIndex(_tabCtrl.index);
  }

  void _syncFilterToSwipeProgress() {
    if (_tabCtrl.indexIsChanging) return;
    final value = _tabCtrl.animation?.value;
    if (value == null) return;
    final index = value.round().clamp(0, _filters.length - 1).toInt();
    _setFilterIndex(index);
  }

  bool _isLive(AppointmentList a) {
    if ((a.status?.toLowerCase() ?? '') != 'booked') return false;
    if (a.bookingType != 1) return false;
    final d = DateTime.tryParse(a.appointmentDate ?? '');
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> refreshOnVisible() async {
    _didFetch = false;
    await _fetch(force: true);
  }

  Future<void> _fetch({bool force = false}) async {
    if (_isFetching || (_didFetch && !force)) return;
    _isFetching = true;
    try {
      final notifier = ref.read(patientLoginViewModelProvider.notifier);
      var pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid == 0) {
        if (!_isWaiting) setState(() { _isWaiting = true; _idMissing = false; });
        await notifier.loadFromStoragePatient();
        pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
        if (mounted) setState(() => _isWaiting = false);
        if (pid == 0) { if (mounted) setState(() => _idMissing = true); return; }
      }
      _didFetch = true;
      await ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(pid);
    } finally {
      _isFetching = false;
    }
  }

  void _openDetail(AppointmentList a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailSheet(
        appointment: a,
        onCancel:     _canCancel(a)     ? () { Navigator.pop(context); _handleCancel(a); }     : null,
        onReschedule: _canReschedule(a) ? () { Navigator.pop(context); _handleReschedule(a); } : null,
      ),
    );
  }

  // Auto-open the detail sheet for an appointment_id passed in via route
  // arguments or applyDeepLink. Only consume the pending id when we actually
  // find the matching row — otherwise the FIRST rebuild (which happens
  // before the appointments fetch resolves) would swallow the id and the
  // subsequent rebuild with the loaded list would no-op.
  void _maybeOpenPendingDetail(List<AppointmentList> list) {
    final targetId = _pendingDetailApptId;
    if (targetId == null) return;
    AppointmentList? found;
    for (final a in list) {
      if (a.appointmentId == targetId) { found = a; break; }
    }
    if (found == null) return;
    _pendingDetailApptId = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _openDetail(found!);
    });
  }

  // Called by the patient shell (PatientBottomNav) when a notification tap
  // drops the user on the in-shell Appointments tab with deep-link args.
  // Unlike the route-args path in didChangeDependencies (which fires once),
  // this is replayable so the same screen instance handles repeated taps.
  void applyDeepLink({String? filter, int? appointmentId}) {
    if (filter != null) {
      final idx = _filters.indexWhere((f) => f.key == filter);
      if (idx != -1 && _tabCtrl.index != idx) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _tabCtrl.animateTo(idx);
        });
      }
    }
    if (appointmentId != null && appointmentId > 0) {
      setState(() => _pendingDetailApptId = appointmentId);
      // Force a refetch so the new appointment id is in the list when the
      // next build calls _maybeOpenPendingDetail.
      refreshOnVisible();
    }
  }

  // 'Appointment Complete — review it' notification: jump straight to the
  // review dialog for this appointment, skipping the detail sheet. We need
  // the appointment row (doctor name, doctor_id, patient_id) which we look
  // up from the loaded list in _maybeOpenRatingDialog on the next build.
  //
  // Also switch the underlying tab to Completed — the appointment must be
  // completed for the Rate action to be valid, and landing on the right
  // tab gives the patient correct context when they close the dialog
  // (otherwise they see "Today" with no sign of the appointment they just
  // reviewed, which feels broken).
  void applyRatingDeepLink(int appointmentId) {
    if (appointmentId <= 0) return;
    final idx = _filters.indexWhere((f) => f.key == 'completed');
    if (idx != -1 && _tabCtrl.index != idx) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabCtrl.animateTo(idx);
      });
    }
    setState(() => _pendingRatingApptId = appointmentId);
    refreshOnVisible();
  }

  // Mirror of _maybeOpenPendingDetail but for the rating dialog. Fires from
  // build's data callback once the list contains the matched appointment.
  // Skips silently if the patient already submitted a review for it.
  void _maybeOpenRatingDialog(List<AppointmentList> list) {
    final targetId = _pendingRatingApptId;
    if (targetId == null) return;
    AppointmentList? found;
    for (final a in list) {
      if (a.appointmentId == targetId) { found = a; break; }
    }
    if (found == null) return;
    _pendingRatingApptId = null;
    // Defer to next frame so the build that invoked us has settled before
    // the modal pushes another route on top.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_canReview(found!)) {
        _handleReview(context, found);
      }
    });
  }

  bool _canReview(AppointmentList a) {
    final s = a.status?.toLowerCase();
    return (s == 'completed' || s == 'complete') &&
        a.appointmentId != null && a.doctorId != null && a.patientId != null &&
        (a.isReviewed != true);
  }

  bool _canCancel(AppointmentList a) {
    final s = a.status?.toLowerCase();
    return (s == 'upcoming' || s == 'booked' || s == 'confirmed') &&
        a.appointmentId != null;
  }

  bool _canReschedule(AppointmentList a) {
    final s = a.status?.toLowerCase();
    // Schedule-change reschedule: doctor removed/changed the slot, so the
    // patient must rebook. Allow regardless of original booking type
    // (their slot no longer exists).
    if (s == 'reschedule') {
      return a.appointmentId != null && a.doctorId != null;
    }
    if (a.bookingType == 1) return false;
    return (s == 'upcoming' || s == 'booked' || s == 'confirmed') &&
        a.appointmentId != null && a.doctorId != null;
  }

  Future<void> _handleCancel(AppointmentList a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48, height: 48,
                decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
                child: const Icon(Icons.cancel_outlined, size: 24, color: kError),
              ),
              const SizedBox(height: 12),
              const Text('Cancel Appointment',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const SizedBox(height: 6),
              const Text('Are you sure you want to cancel this appointment?',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        foregroundColor: kTextSecondary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Yes, Cancel',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref.read(appointmentViewModelProvider.notifier).cancelAppointment(a.appointmentId!);
    if (!mounted) return;
    final id = ref.read(patientLoginViewModelProvider).patientId;
    if (id != null && id != 0) {
      ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(id);
    }
  }

  Future<void> _handleReschedule(AppointmentList a) async {
    final doctor = DoctorDetails(
      doctorId: a.doctorId, name: a.doctorName,
      specialization: a.specialization, experience: a.experience,
      clinicName: a.clinicName, clinicAddress: a.clinicAddress,
      latitude: a.latitude, longitude: a.longitude,
      clinicContact: a.clinicContact,
    );
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          doctor: doctor,
          isReschedule: true,
          appointmentId: a.appointmentId,
          initialDate: DateTime.tryParse(a.appointmentDate ?? ''),
        ),
      ),
    );
    if (ok == true && mounted) {
      final id = ref.read(patientLoginViewModelProvider).patientId;
      if (id != null && id != 0) {
        ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(id);
      }
    }
  }

  Future<void> _handleViewPrescription(AppointmentList a) async {
    if (a.appointmentId == null || a.patientId == null) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
      ),
    );
    try {
      await ref
          .read(prescriptionViewModelProvider.notifier)
          .appointmentWisePrescription(a.appointmentId!);
      if (!mounted) return;
      Navigator.pop(context);
      final details =
          ref.read(prescriptionViewModelProvider).appointmentWisePrescriptions;
      if (details == null || details.isEmpty) {
        _snack('No prescription found for this appointment', isError: true);
        return;
      }
      final prescriptionId = details.first.prescriptionId;
      if (prescriptionId == null) {
        _snack('Prescription not available', isError: true);
        return;
      }
      final rx = PatientPrescription.fromFlatList(
        details,
        fallbackPatientId: a.patientId!,
        fallbackPatientName: a.patientName ?? 'Patient',
      );
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => PatientPrescriptionViewScreen(
            prescriptionId: prescriptionId,
            fallback: rx,
            patientId: a.patientId!,
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      Navigator.pop(context);
      _snack('Failed to load prescription', isError: true);
    }
  }

  Future<void> _handleReview(BuildContext ctx, AppointmentList a) async {
    final input = await showAppointmentReviewDialog(ctx, doctorName: a.doctorName ?? 'Doctor');
    if (input == null) return;
    await ref.read(reviewViewModelProvider.notifier).submitReview(
      ReviewRequestModel(
        appointmentId: a.appointmentId!, doctorId: a.doctorId!,
        patientId: a.patientId!, rating: input.rating, comment: input.comment,
        reviewedByUserId: ref.read(patientLoginViewModelProvider).patientId!,
      ),
    );
  }
bool get _hasDateFilter => 
    _filterStatus != 'today' && // 
    (_dateFilter != _DateFilter.all || !_sortNewest);

  String _fmtDateChip(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  void _showDateFilterSheet() => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _AppointmentDateFilterSheet(
          current: _dateFilter,
          customFrom: _customFrom,
          customTo: _customTo,
          sortNewest: _sortNewest,
          onApply: (f, from, to, newest) => setState(() {
            _dateFilter = f;
            _customFrom = from;
            _customTo   = to;
            _sortNewest = newest;
          }),
        ),
      );

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      final prevId = prev?.patientId ?? 0;
      final nextId = next.patientId ?? 0;
      if (nextId != 0 && prevId != nextId) { _didFetch = false; _fetch(); }
      if (_idMissing && nextId != 0) setState(() => _idMissing = false);
    });

    ref.listen<ReviewState>(reviewViewModelProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        _snack(next.error!, isError: true);
      }
      if (next.isSuccess && next.isSuccess != prev?.isSuccess) {
        _snack('Thanks for your review!');
        final id = ref.read(patientLoginViewModelProvider).patientId;
        if (id != null && id != 0) {
          ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(id);
        }
      }
    });

    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) _snack(next.error!, isError: true);
      if (next.isSuccess && next.rescheduleResponse != null &&
          next.rescheduleResponse != prev?.rescheduleResponse) {
        _snack(next.rescheduleResponse?.message ?? 'Appointment rescheduled');
      }
      if (next.isSuccess && next.cancelResponse != null &&
          next.cancelResponse != prev?.cancelResponse) {
        _snack(next.cancelResponse?.message ?? 'Appointment cancelled');
      }
    });

    final vmState    = ref.watch(appointmentViewModelProvider);
    final loginState = ref.watch(patientLoginViewModelProvider);
    final async      = vmState.patientAppointmentsList;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isWaiting
                  ? _buildLoading('Loading your account…')
                  : _idMissing && (loginState.patientId ?? 0) == 0
                      ? _buildMissingLogin()
                      : async == null
                          ? _buildLoading('Fetching appointments…')
                          : async.when(
                              loading: () => _buildLoading('Fetching appointments…'),
                              error: (_, __) => _buildError(),
                              data: (list) {
                                _maybeOpenPendingDetail(list);
                                _maybeOpenRatingDialog(list);
                                return _buildTabContent(list);
                              },
                            ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              size: 15, color: Colors.white),
          const SizedBox(width: 8),
          Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white))),
        ]),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      child: Column(
        children: [
          // Title row
          Padding(
            padding: EdgeInsets.fromLTRB(
                16, MediaQuery.of(context).padding.top + 12, 16, 0),
            child: Row(
              children: [
                // AppExpandableHeaderSearch ne already leadingIcon render karta —
                // ek separate Container dakhavla tar duplicate calendar disto.
                Expanded(
                  child: AppExpandableHeaderSearch(
                    leadingIcon: Icons.calendar_month_rounded,
                    alwaysShowLeadingIcon: true,
                    title: 'Appointments',
                    subtitle: 'Manage your schedule',
                    hintText: 'Search by patient name...',
                    accentColor: kPrimary,
                    leadingBackgroundColor: kPrimaryLight,
                    titleColor: kTextPrimary,
                    subtitleColor: kTextMuted,
                    fieldColor: const Color(0xFFF7F8FA),
                    borderColor: kBorder,
                    iconColor: kTextMuted,
                    textColor: kTextPrimary,
                    onChanged: (v) => setState(() => _search = v),
                  ),
                ),
                if (_filterStatus != 'today') ...[
                  const SizedBox(width: 8),
                  // ── Date filter button ──────────────────────────
                  GestureDetector(
                    onTap: _showDateFilterSheet,
                    child: Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _hasDateFilter ? kPrimary : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: _hasDateFilter ? kPrimary : kBorder),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: _hasDateFilter ? Colors.white : kPrimary, size: 18),
                    ),
                  ),
                ],
                // const SizedBox(width: 6),
                // // ── Sort button ─────────────────────────────────
                // GestureDetector(
                //   onTap: () => setState(() => _sortNewest = !_sortNewest),
                //   child: Container(
                //     width: 40, height: 40,
                //     decoration: BoxDecoration(
                //       color: const Color(0xFFF7F8FA),
                //       borderRadius: BorderRadius.circular(10),
                //       border: Border.all(color: kBorder),
                //     ),
                //     child: Icon(
                //       _sortNewest
                //           ? Icons.arrow_downward_rounded
                //           : Icons.arrow_upward_rounded,
                //       color: kPrimary, size: 17,
                //     ),
                //   ),
                // ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // ── Active date filter chips ────────────────────────────
       // ── Active date filter chips ────────────────────────────────────────────
if (_hasDateFilter)
  Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 0, 14, 6),
    child: Wrap(
      spacing: 6, runSpacing: 6,
      children: [
      if (_dateFilter != _DateFilter.all && _dateFilter != _DateFilter.today)
  _filterChip(
    icon: _dateFilter.icon,
    label: _dateFilter == _DateFilter.custom && _customFrom != null
        ? '${_fmtDateChip(_customFrom!)} – ${_customTo != null ? _fmtDateChip(_customTo!) : '…'}'
        : _dateFilter.label,
    color: kPrimary,
    onRemove: () => setState(() => _dateFilter = _DateFilter.all),
  ),
        if (!_sortNewest)
          _filterChip(
            icon: Icons.arrow_upward_rounded,
            label: 'Oldest First',
            color: kPrimary,
            onRemove: () => setState(() => _sortNewest = true),
          ),
      ],
    ),
  ),
          // Pill filter tabs — horizontal scroll
          SizedBox(
            height: 34,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
              itemCount: _filters.length,
              itemBuilder: (_, i) {
                final f   = _filters[i];
                final sel = _filterStatus == f.key;
                return GestureDetector(
                  onTap: () {
                    setState(() => _filterStatus = f.key);
                    _tabCtrl.animateTo(i);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: const EdgeInsets.only(right: 6),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: sel ? f.color : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: sel ? f.color : kBorder, width: 1),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(f.icon,
                            size: 12,
                            color: sel ? Colors.white : f.color),
                        const SizedBox(width: 5),
                        Text(f.label,
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: sel ? Colors.white : kTextSecondary)),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: kBorder),
        ],
      ),
    );
  }
Widget _filterChip({
  required IconData icon, 
  required String label,
  required VoidCallback onRemove,
  Color color = kPrimary, // ← add this
}) =>
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15), 
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 11),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
        const SizedBox(width: 5),
        GestureDetector(
          onTap: onRemove,
          child: Icon(Icons.close_rounded, color: color, size: 12),
        ),
      ]),
    );
  // ---------------------------------------------------------------------------
  // Tab content
  // ---------------------------------------------------------------------------
  Widget _buildTabContent(List<AppointmentList> appointments) {
    return TabBarView(
      controller: _tabCtrl,
      children: _filters.map((f) {
        var list = applyFilter(
            appointments, f.key, _search, _dateFilter, _customFrom, _customTo);

        // Apply sort order: by date (direction per _sortNewest), then within
        // the same day always by earliest appointment time first.
        list = List<AppointmentList>.from(list)..sort((a, b) {
          final da = DateTime.tryParse(a.appointmentDate ?? '') ?? DateTime(0);
          final db = DateTime.tryParse(b.appointmentDate ?? '') ?? DateTime(0);
          final dayA = DateTime(da.year, da.month, da.day);
          final dayB = DateTime(db.year, db.month, db.day);
          final dateCmp = _sortNewest ? dayB.compareTo(dayA) : dayA.compareTo(dayB);
          if (dateCmp != 0) return dateCmp;
          return _startMinutes(a).compareTo(_startMinutes(b));
        });

        Future<void> onRefresh() async {
          final id = ref.read(patientLoginViewModelProvider).patientId;
          if (id != null && id != 0) {
            await ref
                .read(appointmentViewModelProvider.notifier)
                .getPatientAppointments(id);
          }
        }

        if (list.isEmpty && !vmState.isLoading) {
          return RefreshIndicator(
            color: kPrimary,
            strokeWidth: 2,
            onRefresh: onRefresh,
            child: CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverFillRemaining(
                  child: _emptyState(f),
                ),
              ],
            ),
          );
        }

        return RefreshIndicator(
          color: kPrimary,
          strokeWidth: 2,
          onRefresh: onRefresh,
          child: ListView.builder(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
            itemCount: list.length,
            itemBuilder: (_, i) {
              final a    = list[i];
              final live = _isLive(a);
              return _AppointmentCard(
                appointment:          a,
                onViewDetails:        () => _openDetail(a),
                onViewPrescription:   _isCompleted(a) && a.appointmentId != null ? () => _handleViewPrescription(a) : null,
                onReview:             _canReview(a) ? () => _handleReview(context, a) : null,
                onCancel:             _canCancel(a) ? () => _handleCancel(a) : null,
                onReschedule:         _canReschedule(a) ? () => _handleReschedule(a) : null,
                queueNumber:          live ? (a.myQueueNumber ?? a.queueNumber) : null,
                isLiveQueue:          live,
                queueStarted:         live ? (a.queueStarted ?? false) : false,
                isMyTurn:             live ? (a.isMyTurn ?? false) : false,
                patientsAhead:        live ? a.patientsAhead : null,
                estimatedArrivalTime: live ? a.estimatedArrivalTime : null,
                queueState:           a.queueState,
              );
            },
          ),
        );
      }).toList(),
    );
  }

  AppointmentState get vmState => ref.read(appointmentViewModelProvider);

  // ---------------------------------------------------------------------------
  // States
  // ---------------------------------------------------------------------------
  Widget _buildLoading(String msg) {
    if (msg.contains('Fetching')) {
      return _buildSkeletonList();
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
          ),
          const SizedBox(height: 12),
          Text(msg, style: const TextStyle(fontSize: 13, color: kTextMuted)),
        ],
      ),
    );
  }

  Widget _emptyState(_FilterTab f) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(
                  color: f.bg, shape: BoxShape.circle),
              child: Icon(f.icon, size: 26, color: f.color),
            ),
            const SizedBox(height: 12),
            Text('No ${f.label.toLowerCase()} appointments',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            const SizedBox(height: 4),
            const Text('Pull down to refresh',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
            // Show clear filter button when date filter is active
            if (_hasDateFilter) ...[
              const SizedBox(height: 14),
              TextButton.icon(
                onPressed: () => setState(() {
                  _dateFilter = _DateFilter.all;
                  _sortNewest = true;
                }),
                icon: const Icon(Icons.clear_all_rounded, size: 15),
                label: const Text('Clear Date Filter',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                style: TextButton.styleFrom(foregroundColor: kPrimary),
              ),
            ],
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60, height: 60,
                decoration: const BoxDecoration(
                    color: kRedLight, shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 26, color: kError),
              ),
              const SizedBox(height: 12),
              const Text("Couldn't load appointments",
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              const SizedBox(height: 4),
              const Text('Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 12, color: kTextSecondary, height: 1.5)),
              const SizedBox(height: 16),
              SizedBox(
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary, elevation: 0,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () {
                    final id = ref.read(patientLoginViewModelProvider).patientId;
                    if (id != null && id != 0) {
                      ref.read(appointmentViewModelProvider.notifier)
                          .getPatientAppointments(id);
                    }
                  },
                  child: const Text('Retry',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildMissingLogin() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: kAmberLight, shape: BoxShape.circle),
              child: const Icon(Icons.lock_outline_rounded,
                  size: 26, color: kWarning),
            ),
            const SizedBox(height: 12),
            const Text('Session Expired',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            const SizedBox(height: 4),
            const Text('Please login again to view your appointments.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12, color: kTextSecondary, height: 1.5)),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  DATE FILTER BOTTOM SHEET  (appointment-specific)
// ════════════════════════════════════════════════════════════════════
class _AppointmentDateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom, customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

  const _AppointmentDateFilterSheet({
    required this.current,
    required this.customFrom,
    required this.customTo,
    required this.sortNewest,
    required this.onApply,
  });

  @override
  State<_AppointmentDateFilterSheet> createState() =>
      _AppointmentDateFilterSheetState();
}

class _AppointmentDateFilterSheetState
    extends State<_AppointmentDateFilterSheet> {
  late _DateFilter _sel;
  late DateTime?   _from, _to;
  late bool        _newest;

  @override
  void initState() {
    super.initState();
    _sel    = widget.current;
    _from   = widget.customFrom;
    _to     = widget.customTo;
    _newest = widget.sortNewest;
  }

  String _fmt(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  Future<void> _pick(bool isFrom) async {
    final p = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
          data: Theme.of(ctx).copyWith(
              colorScheme: const ColorScheme.light(primary: kPrimary)),
          child: child!),
    );
    if (p != null) setState(() => isFrom ? _from = p : _to = p);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Handle
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Row(children: [
            const Text('Filter by Date',
                style: TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const Spacer(),
            TextButton(
              onPressed: () => setState(() {
                _sel = _DateFilter.all; _from = null; _to = null; _newest = true;
              }),
              child: const Text('Reset',
                  style: TextStyle(
                      color: kError, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ]),
          const SizedBox(height: 8),

          // Preset chips
          Wrap(
            spacing: 7, runSpacing: 7,
            children: _DateFilter.values
                .where((f) => f != _DateFilter.custom)
                .map((f) {
              final sel = _sel == f;
              return GestureDetector(
                onTap: () => setState(() => _sel = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 11, vertical: 7),
                  decoration: BoxDecoration(
                    color: sel ? kPrimary : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: sel ? kPrimary : kBorder,
                        width: sel ? 1.5 : 1),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(f.icon,
                        color: sel ? Colors.white : kTextMuted, size: 12),
                    const SizedBox(width: 5),
                    Text(f.label,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : kTextSecondary)),
                  ]),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 10),

          // Custom range
          GestureDetector(
            onTap: () => setState(() => _sel = _DateFilter.custom),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _sel == _DateFilter.custom
                    ? kPrimaryLight
                    : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _sel == _DateFilter.custom ? kPrimary : kBorder,
                    width: _sel == _DateFilter.custom ? 1.5 : 1),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Icon(Icons.tune_rounded,
                        color: _sel == _DateFilter.custom
                            ? kPrimary : kTextMuted, size: 15),
                    const SizedBox(width: 7),
                    Text('Custom Date Range',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600,
                            color: _sel == _DateFilter.custom
                                ? kPrimary : kTextMuted)),
                  ]),
                  if (_sel == _DateFilter.custom) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      Expanded(child: _datePick('From', _from, () => _pick(true))),
                      const SizedBox(width: 8),
                      Expanded(child: _datePick('To', _to, () => _pick(false))),
                    ]),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Sort order
          const Text('Sort Order',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _sortBtn('Newest First', Icons.arrow_downward_rounded,
                _newest, () => setState(() => _newest = true))),
            const SizedBox(width: 8),
            Expanded(child: _sortBtn('Oldest First', Icons.arrow_upward_rounded,
                !_newest, () => setState(() => _newest = false))),
          ]),
          const SizedBox(height: 16),

          // Apply button
          SizedBox(
            width: double.infinity, height: 46,
            child: ElevatedButton(
              onPressed: () {
                widget.onApply(_sel, _from, _to, _newest);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary, foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Apply Filter',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _datePick(String label, DateTime? val, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
          child: Row(children: [
            const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 13),
            const SizedBox(width: 7),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label,
                  style: const TextStyle(fontSize: 10, color: kTextMuted)),
              Text(val != null ? _fmt(val) : 'Select',
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: val != null ? kTextPrimary : kTextMuted)),
            ]),
          ]),
        ),
      );

  Widget _sortBtn(String label, IconData icon, bool sel, VoidCallback onTap) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: sel ? kPrimary : const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: sel ? kPrimary : kBorder),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: sel ? Colors.white : kTextMuted, size: 14),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : kTextSecondary)),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD  (unchanged)
// ════════════════════════════════════════════════════════════════════
class _AppointmentCard extends StatelessWidget {
  final AppointmentList appointment;
  final VoidCallback  onViewDetails;
  final VoidCallback? onViewPrescription;
  final VoidCallback? onReview, onCancel, onReschedule;
  final int?    queueNumber;
  final bool    isLiveQueue, queueStarted, isMyTurn;
  final int?    patientsAhead;
  final String? estimatedArrivalTime;
  final String? queueState;

  const _AppointmentCard({
    required this.appointment,
    required this.onViewDetails,
    this.onViewPrescription,
    this.onReview, this.onCancel, this.onReschedule,
    this.queueNumber,
    this.isLiveQueue    = false,
    this.queueStarted   = false,
    this.isMyTurn       = false,
    this.patientsAhead,
    this.estimatedArrivalTime,
    this.queueState,
  });

  @override
  Widget build(BuildContext context) {
    final a      = appointment;
    final sColor = _statusColor(a.status);
    final sBg    = _statusBg(a.status);
    final sIcon  = _statusIcon(a.status);
    final hasMap = a.latitude != null && a.longitude != null;
    final init   = (a.patientName ?? '?')[0].toUpperCase();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onViewDetails,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          alignment: Alignment.center,
                          child: Text(init,
                              style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  color: kPrimary)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.patientName ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded,
                                      size: 10, color: kTextMuted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(a.doctorName ?? '—',
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: kTextSecondary),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: sBg,
                              borderRadius: BorderRadius.circular(6)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sIcon, size: 10, color: sColor),
                              const SizedBox(width: 4),
                              Text(
                                  a.status?.toLowerCase() == 'cancled'
                                      ? 'Cancelled by Doctor'
                                      : _statusLabel(a.status),
                                  style: TextStyle(
                                      color: sColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600)),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: kBorder),
                    ),

                    Row(
                      children: [
                        Expanded(
                          child: _infoTile(
                            icon: Icons.calendar_today_rounded,
                            iconFg: kInfo, iconBg: kInfoLight,
                            top: _fmtDateRel(a.appointmentDate),
                            bottom: _fmtDate(a.appointmentDate),
                          ),
                        ),
                        if (_hasAppointmentTime(a))
                          Expanded(
                            child: _infoTile(
                              icon: Icons.access_time_rounded,
                              iconFg: kSuccess,
                              iconBg: kGreenLight,
                              top: _appointmentTimePrimary(a),
                              bottom: _appointmentTimeSecondary(a),
                            ),
                          ),
                      ],
                    ),

                    if (isLiveQueue) ...[
                      const SizedBox(height: 8),
                      _LiveQueueBanner(
                        queueNumber:          queueNumber,
                        queueStarted:         queueStarted,
                        isMyTurn:             isMyTurn,
                        estimatedArrivalTime: estimatedArrivalTime,
                        patientsAhead:        patientsAhead,
                        queueState:           queueState,
                      ),
                    ],

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              onPressed: onViewPrescription ?? onViewDetails,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(
                                  onViewPrescription != null
                                      ? 'View Prescription'
                                      : 'View Details',
                                  style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ),
                        if (onReview != null) ...[
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              onPressed: onReview,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kPrimary,
                                side: const BorderSide(color: kPrimary),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              ),
                              child: const Text('Review',
                                  style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600)),
                            ),
                          ),
                        ],
                        if (onReschedule != null) ...[
                          const SizedBox(width: 6),
                          _iconBtn(Icons.edit_calendar_rounded,
                              kAmberLight, kWarning, onReschedule!),
                        ],
                        if (onCancel != null &&
                            queueState?.toLowerCase() != 'queue closed') ...[
                          const SizedBox(width: 6),
                          _iconBtn(Icons.cancel_rounded,
                              kRedLight, kError, onCancel!),
                        ],
                        const SizedBox(width: 6),
                        if (hasMap) ...[
                          _iconBtn(Icons.map_rounded, kInfoLight, kInfo,
                              () => openMap(
                                  a.latitude!, a.longitude!, a.clinicName)),
                          const SizedBox(width: 6),
                        ],
                        _iconBtn(
                          Icons.call_rounded, kPrimaryLight, kPrimary,
                          () => showDialog(
                            context: context,
                            builder: (ctx) => Dialog(
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 44, height: 44,
                                      decoration: const BoxDecoration(
                                          color: kPrimaryLight,
                                          shape: BoxShape.circle),
                                      child: const Icon(Icons.call_rounded,
                                          color: kPrimary, size: 22),
                                    ),
                                    const SizedBox(height: 10),
                                    const Text('Contact',
                                        style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: kTextPrimary)),
                                    const SizedBox(height: 16),
                                    if (a.clinicContact?.isNotEmpty == true)
                                      _callOption(
                                          ctx,
                                          'Call Clinic',
                                          a.clinicName ?? 'Clinic',
                                          a.clinicContact!,
                                          Icons.local_hospital_rounded,
                                          kWarning,
                                          kAmberLight)
                                    else
                                      const Text('No contact available',
                                          style: TextStyle(
                                              fontSize: 13,
                                              color: kTextMuted)),
                                    const SizedBox(height: 14),
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextButton(
                                        onPressed: () => Navigator.pop(ctx),
                                        child: const Text('Cancel',
                                            style: TextStyle(
                                                color: kTextSecondary,
                                                fontSize: 13)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        if (queueNumber != null &&
            queueState?.toLowerCase() != 'queue closed')
          Positioned(
            top: -7, left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                      color: kPrimary.withOpacity(0.35),
                      blurRadius: 6,
                      offset: const Offset(0, 2)),
                ],
              ),
              child: Text('Q$queueNumber',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3)),
            ),
          ),
      ],
    );
  }

  Widget _infoTile({
    required IconData icon,
    required Color iconFg,
    required Color iconBg,
    required String top,
    required String bottom,
  }) =>
      Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(6)),
            child: Icon(icon, size: 12, color: iconFg),
          ),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(top,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              if (bottom.isNotEmpty)
                Text(bottom,
                    style: const TextStyle(
                        fontSize: 11, color: kTextSecondary)),
            ],
          ),
        ],
      );

  Widget _iconBtn(
          IconData icon, Color bg, Color fg, VoidCallback onTap) =>
      SizedBox(
        width: 36, height: 36,
        child: ElevatedButton(
          onPressed: onTap,
          style: ElevatedButton.styleFrom(
            backgroundColor: bg,
            elevation: 0,
            padding: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: Icon(icon, color: fg, size: 16),
        ),
      );

  Widget _callOption(BuildContext ctx, String title, String subtitle,
          String number, IconData icon, Color fg, Color bg) =>
      GestureDetector(
        onTap: () async {
          Navigator.pop(ctx);
          final uri = Uri(scheme: 'tel', path: number);
          if (await canLaunchUrl(uri)) await launchUrl(uri);
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: bg.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: fg.withOpacity(0.2)),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: fg)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: kTextSecondary),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            Icon(Icons.call_rounded, size: 16, color: fg),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  LIVE QUEUE BANNER  (unchanged)
// ════════════════════════════════════════════════════════════════════
class _LiveQueueBanner extends StatefulWidget {
  final int?    queueNumber;
  final bool    queueStarted, isMyTurn;
  final String? estimatedArrivalTime;
  final String? queueState;
  final int?    patientsAhead;

  const _LiveQueueBanner({
    this.queueNumber, this.queueStarted = false,
    this.isMyTurn = false, this.estimatedArrivalTime,
    this.patientsAhead, this.queueState,
  });

  @override
  State<_LiveQueueBanner> createState() => _LiveQueueBannerState();
}

class _LiveQueueBannerState extends State<_LiveQueueBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double>   _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  bool get _isClosed =>
      widget.queueState?.toLowerCase() == 'queue closed';

  bool get _hasEstRow =>
      !_isClosed &&
      (widget.estimatedArrivalTime != null || widget.patientsAhead != null);

  @override
  Widget build(BuildContext context) {
    final myTurn    = widget.isMyTurn;
    final started   = widget.queueStarted;
    final q         = widget.queueNumber;
    final ahead     = widget.patientsAhead;
    final arrival   = widget.estimatedArrivalTime;
    final queueState = widget.queueState ?? '';

    final topColor  = myTurn || started ? kSuccess : kWarning;
    final topBg     = topColor.withOpacity(0.07);
    final topBorder = topColor.withOpacity(0.25);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: topBg,
            borderRadius: _hasEstRow
                ? const BorderRadius.vertical(top: Radius.circular(10))
                : BorderRadius.circular(10),
            border: Border.all(color: topBorder),
          ),
          child: Row(
            children: [
              if (started)
                AnimatedBuilder(
                  animation: _pulse,
                  builder: (_, __) => Container(
                    width: 8, height: 8,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: topColor.withOpacity(_pulse.value)),
                  ),
                )
              else
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: kWarning.withOpacity(0.6)),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: myTurn
                            ? "It's your turn!  "
                            : started
                                ? 'Queue position  '
                                : _isClosed
                                    ? ''
                                    : 'Queue token  ',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: kTextSecondary),
                      ),
                      if (!myTurn && !_isClosed)
                        TextSpan(
                          text: q != null ? '#$q' : '—',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: q != null ? topColor : kTextMuted),
                        ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: myTurn
                      ? kSuccess
                      : (started ? kSuccess : kWarning),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (started) ...[
                      const Icon(Icons.circle, size: 6, color: Colors.white),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      myTurn ? 'YOUR TURN' : queueState,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_hasEstRow)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: (myTurn ? kSuccess : kWarning).withOpacity(0.06),
              borderRadius:
                  const BorderRadius.vertical(bottom: Radius.circular(10)),
              border: Border(
                left:   BorderSide(color: topBorder),
                right:  BorderSide(color: topBorder),
                bottom: BorderSide(color: topBorder),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  myTurn
                      ? Icons.notifications_active_rounded
                      : Icons.hourglass_top_rounded,
                  size: 12,
                  color: myTurn ? kSuccess : kWarning,
                ),
                const SizedBox(width: 6),
                if (myTurn)
                  const Text('Please proceed to the doctor',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kSuccess))
                else if (started && ahead == 0)
                  const Text('Your turn next',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kWarning))
                else if (arrival != null)
                  Text('Est. arrival: $arrival',
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kWarning)),
                if (!myTurn && started && ahead != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: kWarning.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                        ahead == 0 ? 'Next' : '$ahead ahead',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: kWarning)),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DETAIL BOTTOM SHEET  (unchanged)
// ════════════════════════════════════════════════════════════════════
class _DetailSheet extends StatelessWidget {
  final AppointmentList appointment;
  final VoidCallback? onCancel, onReschedule;

  const _DetailSheet({
    required this.appointment,
    this.onCancel,
    this.onReschedule,
  });

  @override
  Widget build(BuildContext context) {
    final a      = appointment;
    final sIcon  = _statusIcon(a.status);
    final hasMap = a.latitude != null && a.longitude != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, ctrl) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView(
                controller: ctrl,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [kPrimaryDark, kPrimary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 52, height: 52,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(13),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            (a.patientName ?? '?')[0].toUpperCase(),
                            style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.patientName ?? 'Unknown',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              const SizedBox(height: 2),
                              Text(
                                '${a.gender ?? '—'}  ·  DOB: ${_fmtDate(a.dob)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color:
                                        Colors.white.withOpacity(0.85)),
                              ),
                              const SizedBox(height: 7),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color:
                                      Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                      color: Colors.white
                                          .withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(sIcon,
                                        size: 11,
                                        color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(_statusLabel(a.status),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionLabel('Schedule'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _schedChip(
                          icon: Icons.calendar_today_rounded,
                          fg: kInfo, bg: kInfoLight,
                          label: 'Date',
                          value: _fmtDate(a.appointmentDate),
                          sub: _fmtDateRel(a.appointmentDate),
                        ),
                      ),
                      if (_hasAppointmentTime(a)) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _schedChip(
                            icon: Icons.access_time_filled_rounded,
                            fg: kSuccess, bg: kGreenLight,
                            label: 'Time',
                            value: _appointmentTimePrimary(a),
                            sub: _appointmentTimeChipSub(a),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),

                  _sectionLabel('Doctor'),
                  const SizedBox(height: 8),
                  _infoCard(
                    child: Row(
                      children: [
                        Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                              color: kPrimaryLight,
                              borderRadius: BorderRadius.circular(11)),
                          child: const Icon(Icons.person_rounded,
                              color: kPrimary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.doctorName ?? '—',
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: kTextPrimary)),
                              const SizedBox(height: 2),
                              Text(a.specialization ?? '—',
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: kPrimary,
                                      fontWeight: FontWeight.w500)),
                              if (a.experience != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                    '${a.experience} yrs experience',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: kTextSecondary)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionLabel('Clinic'),
                  const SizedBox(height: 8),
                  _infoCard(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                  color: kAmberLight,
                                  borderRadius: BorderRadius.circular(10)),
                              child: const Icon(
                                  Icons.local_hospital_rounded,
                                  color: kWarning, size: 18),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(a.clinicName ?? '—',
                                      style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w700,
                                          color: kTextPrimary)),
                                  if (a.clinicAddress != null)
                                    Text(a.clinicAddress!,
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: kTextSecondary)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasMap) ...[
                          const SizedBox(height: 10),
                          const Divider(height: 1, color: kBorder),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity, height: 38,
                            child: ElevatedButton.icon(
                              onPressed: () => openMap(
                                  a.latitude!,
                                  a.longitude!,
                                  a.clinicName),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kInfoLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(10)),
                              ),
                              icon: const Icon(Icons.map_rounded,
                                  color: kInfo, size: 16),
                              label: const Text('Open in Maps',
                                  style: TextStyle(
                                      color: kInfo,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  _sectionLabel('Details'),
                  const SizedBox(height: 8),
                  _infoCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        _detailRow(Icons.badge_rounded, kInfoLight, kInfo,
                            'Patient', a.patientName ?? '—'),
                        _divLine(),
                        _detailRow(Icons.wc_rounded, kPurpleLight,
                            kPurple, 'Gender', a.gender ?? '—'),
                        _divLine(),
                        _detailRow(Icons.cake_rounded, kAmberLight,
                            kWarning, 'Date of Birth', _fmtDate(a.dob)),
                        if (a.queueNumber != null) ...[
                          _divLine(),
                          _detailRow(Icons.queue_rounded, kGreenLight,
                              kSuccess, 'Queue No.', 'Q #${a.queueNumber}'),
                        ],
                        if (a.bookingFor != null) ...[
                          _divLine(),
                          _detailRow(Icons.people_rounded, kPurpleLight,
                              kPurple, 'Booking For', a.bookingFor!),
                        ],
                        if (a.cancelledBy != null) ...[
                          _divLine(),
                          _detailRow(Icons.cancel_rounded, kRedLight,
                              kError, 'Cancelled By', _cap(a.cancelledBy)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  if (onReschedule != null || onCancel != null) ...[
                    Row(
                      children: [
                        if (onReschedule != null)
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: onReschedule,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kAmberLight,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                icon: const Icon(
                                    Icons.edit_calendar_rounded,
                                    color: kWarning, size: 16),
                                label: const Text('Reschedule',
                                    style: TextStyle(
                                        color: kWarning,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ),
                          ),
                        if (onReschedule != null && onCancel != null)
                          const SizedBox(width: 10),
                        if (onCancel != null)
                          Expanded(
                            child: SizedBox(
                              height: 44,
                              child: ElevatedButton.icon(
                                onPressed: onCancel,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: kRedLight,
                                  elevation: 0,
                                  shape: RoundedRectangleBorder(
                                      borderRadius:
                                          BorderRadius.circular(10)),
                                ),
                                icon: const Icon(Icons.cancel_rounded,
                                    color: kError, size: 16),
                                label: const Text('Cancel',
                                    style: TextStyle(
                                        color: kError,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13)),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                  ],

                  SizedBox(
                    height: 46, width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Close',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Text(
        t.toUpperCase(),
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: kTextMuted,
            letterSpacing: 1.0),
      );

  Widget _infoCard({required Widget child, EdgeInsetsGeometry? padding}) =>
      Container(
        padding: padding ?? const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: child,
      );

  Widget _schedChip({
    required IconData icon,
    required Color fg, required Color bg,
    required String label, required String value, required String sub,
  }) =>
      Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 14, color: fg),
            ),
            const SizedBox(height: 7),
            Text(label,
                style: const TextStyle(fontSize: 11, color: kTextSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            if (sub.isNotEmpty)
              Text(sub,
                  style: const TextStyle(fontSize: 11, color: kTextSecondary)),
          ],
        ),
      );

  Widget _detailRow(IconData icon, Color bg, Color fg, String label,
          String value) =>
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                  color: bg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 13, color: fg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 12, color: kTextSecondary)),
            ),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ],
        ),
      );

  Widget _divLine() =>
      const Divider(height: 1, color: kBorder, indent: 13, endIndent: 13);
}

// ════════════════════════════════════════════════════════════════════
//  REVIEW DIALOG — responsive + half-star (Practo/Google-style)
//
//  - Rating is a `double` so half-stars round-trip end-to-end (UI →
//    ReviewRequestModel → API → DB DECIMAL).
//  - Tap detection: tap on the LEFT half of a star sets rating to N.5,
//    RIGHT half sets it to N.0.
//  - Width is clamped responsive so the dialog feels right on phones,
//    tablets, and desktop without overflowing.
//  - Wrapped in SingleChildScrollView so the keyboard never pushes the
//    Submit button off-screen on short devices.
// ════════════════════════════════════════════════════════════════════
class AppointmentReviewInput {
  final double rating;
  final String comment;
  const AppointmentReviewInput({required this.rating, required this.comment});
}

Future<AppointmentReviewInput?> showAppointmentReviewDialog(
  BuildContext context, {
  required String doctorName,
  String? doctorSpecialty,
  String? doctorInitials,
}) {
  final commentCtrl = TextEditingController();
  double rating = 0.0;

  const starColors = <Color>[
    Colors.transparent,
    Color(0xFFE24B4A), Color(0xFFEF9F27),
    Color(0xFF639922), Color(0xFF1D9E75), Color(0xFF378ADD),
  ];
  const starLabels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];
  const starSize = 40.0;
  const starGap = 6.0;

  String fmtRating(double r) =>
      r == r.truncateToDouble() ? r.toStringAsFixed(0) : r.toStringAsFixed(1);

  return showDialog<AppointmentReviewInput>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.55),
    barrierDismissible: false,
    builder: (ctx) {
      final mq = MediaQuery.of(ctx);
      // Phones: 92% width; tablets/desktop: cap at 420 so the row of stars
      // doesn't sprawl across a wide screen.
      final maxDialogWidth =
          mq.size.width >= 600 ? 420.0 : (mq.size.width * 0.92);

      return StatefulBuilder(
        builder: (ctx, setState) {
          // Whole-star "bucket" used for label/colour (3.5 → "Very good").
          final activeIdx   = rating.ceil().clamp(0, 5);
          final activeColor =
              activeIdx > 0 ? starColors[activeIdx] : kTextMuted;

          return Dialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            backgroundColor: Colors.white,
            elevation: 12,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: maxDialogWidth,
                minWidth: 280,
              ),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // ── Header ────────────────────────────────────────
                      Row(
                        children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [kPrimary, kPrimaryDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(13),
                              boxShadow: [
                                BoxShadow(
                                  color: kPrimary.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              (doctorInitials ??
                                      (doctorName.length >= 2
                                          ? doctorName.substring(0, 2)
                                          : doctorName))
                                  .toUpperCase(),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Rate your visit',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: kTextPrimary,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Dr. $doctorName${doctorSpecialty != null ? ' · $doctorSpecialty' : ''}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Close',
                            visualDensity: VisualDensity.compact,
                            icon: const Icon(Icons.close_rounded,
                                size: 20, color: kTextMuted),
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      Container(height: 1, color: kBorder),
                      const SizedBox(height: 16),

                      // ── Prompt + stars ────────────────────────────────
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'How was your experience?',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Stars row — each star detects left/right-half tap
                      // for .5 vs .0 precision (industry-standard pattern).
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: List.generate(5, (i) {
                            final idx = i + 1; // 1..5
                            final fill =
                                (rating - (idx - 1)).clamp(0.0, 1.0);

                            IconData icon;
                            if (fill >= 1.0) {
                              icon = Icons.star_rounded;
                            } else if (fill >= 0.5) {
                              icon = Icons.star_half_rounded;
                            } else {
                              icon = Icons.star_outline_rounded;
                            }

                            return Padding(
                              padding: EdgeInsets.only(
                                  right: i == 4 ? 0 : starGap),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  final leftHalf =
                                      details.localPosition.dx <
                                          starSize / 2;
                                  setState(() {
                                    rating = idx - (leftHalf ? 0.5 : 0.0);
                                  });
                                },
                                child: AnimatedSwitcher(
                                  duration:
                                      const Duration(milliseconds: 120),
                                  transitionBuilder: (c, anim) =>
                                      ScaleTransition(
                                          scale: anim, child: c),
                                  child: Icon(
                                    icon,
                                    key: ValueKey(
                                        '$idx-${icon.codePoint}'),
                                    size: starSize,
                                    color: fill > 0 ? activeColor : kBorder,
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Live label — "3.5 — Very good"
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 180),
                        child: rating > 0
                            ? Padding(
                                key: ValueKey(rating),
                                padding: const EdgeInsets.only(top: 2),
                                child: Text(
                                  '${fmtRating(rating)}  ·  ${starLabels[activeIdx]}',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: activeColor,
                                    letterSpacing: 0.1,
                                  ),
                                ),
                              )
                            : const SizedBox(height: 17),
                      ),

                      const SizedBox(height: 14),

                      // ── Comment ───────────────────────────────────────
                      TextField(
                        controller: commentCtrl,
                        maxLines: 3,
                        minLines: 3,
                        textInputAction: TextInputAction.newline,
                        style: const TextStyle(
                            fontSize: 13, color: kTextPrimary),
                        decoration: InputDecoration(
                          hintText: 'Write a short review (optional)',
                          hintStyle: const TextStyle(
                              fontSize: 13, color: kTextMuted),
                          filled: true,
                          fillColor: const Color(0xFFF7F8FA),
                          contentPadding: const EdgeInsets.all(12),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: kBorder),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(
                                color: kPrimary, width: 1.5),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ── Actions ───────────────────────────────────────
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                side: const BorderSide(color: kBorder),
                                foregroundColor: kTextSecondary,
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton(
                              onPressed: rating <= 0
                                  ? null
                                  : () => Navigator.pop(
                                        ctx,
                                        AppointmentReviewInput(
                                          rating: rating,
                                          comment:
                                              commentCtrl.text.trim(),
                                        ),
                                      ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                disabledBackgroundColor: kPrimaryLight,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(
                                    vertical: 12),
                                shape: RoundedRectangleBorder(
                                    borderRadius:
                                        BorderRadius.circular(12)),
                              ),
                              child: Text(
                                rating <= 0
                                    ? 'Submit'
                                    : 'Submit ${fmtRating(rating)} stars',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

// ════════════════════════════════════════════════════════════════════
//  SHIMMER SKELETON  (unchanged)
// ════════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer(
      {this.width = double.infinity, this.height = 16, this.radius = 8});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = Tween<double>(begin: -2, end: 2)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          gradient: LinearGradient(
            begin: Alignment(_anim.value - 1, 0),
            end: Alignment(_anim.value + 1, 0),
            colors: const [
              Color(0xFFEDF2F7), Color(0xFFE2E8F0),
              Color(0xFFCBD5E0), Color(0xFFE2E8F0), Color(0xFFEDF2F7),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Shimmer(width: 44, height: 44, radius: 12),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Shimmer(width: 140, height: 13),
                    const SizedBox(height: 6),
                    _Shimmer(width: 100, height: 10),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _Shimmer(width: 70, height: 22, radius: 6),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: kBorder),
          ),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    _Shimmer(width: 26, height: 26, radius: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Shimmer(height: 12, width: 80),
                          const SizedBox(height: 4),
                          _Shimmer(height: 10, width: 60),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    _Shimmer(width: 26, height: 26, radius: 6),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _Shimmer(height: 12, width: 60),
                          const SizedBox(height: 4),
                          _Shimmer(height: 10, width: 50),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _Shimmer(height: 36, radius: 10)),
              const SizedBox(width: 6),
              _Shimmer(width: 36, height: 36, radius: 10),
              const SizedBox(width: 6),
              _Shimmer(width: 36, height: 36, radius: 10),
            ],
          ),
        ],
      ),
    );
  }
}

Widget _buildSkeletonList() {
  return ListView.builder(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
    itemCount: 4,
    itemBuilder: (_, __) => const _SkeletonCard(),
  );
}