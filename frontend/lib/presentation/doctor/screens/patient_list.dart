import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  — identical to home_screen.dart
// ─────────────────────────────────────────────────────────────────────────────

const kPageBg         = Color(0xFFF8F9FB);
const kCardBg         = Colors.white;
const kCardBorder     = Color(0xFFE2E8F0);

const kPrimary        = Color(0xFF1D9E75);
const kPrimaryDark    = Color(0xFF0F6E56);
const kPrimaryLight   = Color(0xFFE1F5EE);
const kPrimaryLighter = Color(0xFFF0FBF8);

const kTextPrimary    = Color(0xFF0F172A);
const kTextSecondary  = Color(0xFF64748B);
const kTextMuted      = Color(0xFF94A3B8);

const kBorder         = Color(0xFFE2E8F0);
const kDivider        = Color(0xFFE2E8F0);
const kBg             = Color(0xFFF8F9FB);
const kHairline       = Color(0xFFE2E8F0);

const kGreen          = Color(0xFF22C55E);
const kGreenLight     = Color(0xFFF0FDF4);
const kGreenBorder    = Color(0xFFBBF7D0);
const kGreenDark      = Color(0xFF166534);

const kAmber          = Color(0xFFF59E0B);
const kAmberLight     = Color(0xFFFEF3C7);
const kAmberBorder    = Color(0xFFFDE68A);
const kAmberDark      = Color(0xFF92400E);

const kRed            = Color(0xFFEF4444);
const kRedLight       = Color(0xFFFEE2E2);
const kRedBorder      = Color(0xFFFECACA);
const kRedDark        = Color(0xFF7F1D1D);

const kPurple         = Color(0xFF8B5CF6);
const kPurpleLight    = Color(0xFFEDE9FE);
const kPurpleBorder   = Color(0xFFDDD6FE);
const kPurpleDark     = Color(0xFF4C1D95);

const kBlueLight      = Color(0xFFEFF6FF);
const kBlueBorder     = Color(0xFFBFDBFE);
const kBlueDark       = Color(0xFF1E40AF);

const _kBottomClear = 100.0;
const _kWideBreak   = 800.0;
const _kDeskSide    = 240.0;
const _kDeskDetail  = 270.0;

// Avatar palettes — (bg, border, fg)
const _avatarPalettes = [
  (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)),
  (Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFF4C1D95)),
  (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFF78350F)),
  (Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFF7F1D1D)),
  (Color(0xFFEFF6FF), Color(0xFFBFDBFE), Color(0xFF1E40AF)),
  (Color(0xFFF0FDF4), Color(0xFFBBF7D0), Color(0xFF166534)),
];

enum _Tab { today, upcoming, completed }

// ─────────────────────────────────────────────────────────────────────────────
// HELPERS
// ─────────────────────────────────────────────────────────────────────────────

String _fmtTime(String? raw) {
  if (raw == null) return '';
  final v = raw.trim();
  if (v.isEmpty || v == '--' || v.toLowerCase() == 'null') return '';
  try {
    return DateFormat('h:mm a').format(DateTime.parse(v).toUtc());
  } catch (_) {
    return v;
  }
}

String? _slotTimeLabel(String? startTime, String? endTime) {
  final s = _fmtTime(startTime);
  final e = _fmtTime(endTime);
  if (s.isEmpty && e.isEmpty) return null;
  if (s.isEmpty) return e;
  if (e.isEmpty) return s;
  return '$s – $e';
}

bool _isSlotBooking(AppointmentList a) => a.bookingType == 2;

bool _showPatientStatusText(String? status) {
  final v = status?.toLowerCase().trim();
  return v == 'skipped' || v == 'in_progress';
}

String _patientStatusLabel(String status) =>
    status[0].toUpperCase() + status.substring(1).replaceAll('_', ' ');

String _fmtDateLabel(String? raw, {bool includeYear = false}) {
  if (raw == null) return '--';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  const mo = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
  return includeYear ? '${d.day} ${mo[d.month-1]} ${d.year}' : '${d.day} ${mo[d.month-1]}';
}

String _appointmentDateLabel(String? appointmentDate, String? startTime, {bool includeYear = false}) {
  final dateLabel = _fmtDateLabel(appointmentDate, includeYear: includeYear);
  final timeLabel = _fmtTime(startTime);
  if (timeLabel.isEmpty) return dateLabel;
  if (dateLabel == '--') return timeLabel;
  return '$dateLabel | $timeLabel';
}

String? _slotAppointmentMetaLabel(String? appointmentDate, String? startTime, {bool includeYear = false}) {
  final label = _appointmentDateLabel(appointmentDate, startTime, includeYear: includeYear);
  return label == '--' ? null : label;
}

QueueState _sessionQueueState(int? status) {
  switch (status) {
    case 1: return QueueState.running;
    case 2: return QueueState.paused;
    case 3: return QueueState.stopped;
    default: return QueueState.idle;
  }
}

// ── Date filter ───────────────────────────────────────────────────────────────
enum _DateFilter { all, today, tomorrow, thisWeek, thisMonth, last3Months, last6Months, thisYear, custom }

extension _DateFilterX on _DateFilter {
  String get label => switch (this) {
    _DateFilter.all         => 'All Time',
    _DateFilter.today       => 'Today',
    _DateFilter.tomorrow    => 'Tomorrow',
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
    _DateFilter.tomorrow    => Icons.event_rounded,
    _DateFilter.thisWeek    => Icons.view_week_rounded,
    _DateFilter.thisMonth   => Icons.calendar_month_rounded,
    _DateFilter.last3Months => Icons.date_range_rounded,
    _DateFilter.last6Months => Icons.date_range_rounded,
    _DateFilter.thisYear    => Icons.calendar_today_rounded,
    _DateFilter.custom      => Icons.tune_rounded,
  };
}

bool _passesDateFilter(AppointmentList a, _DateFilter df, DateTime? customFrom, DateTime? customTo) {
  final p = DateTime.tryParse(a.appointmentDate ?? '');
  if (p == null) return df == _DateFilter.all;
  final now = DateTime.now();
  final tomorrow = DateTime(now.year, now.month, now.day + 1);
  return switch (df) {
    _DateFilter.all         => true,
    _DateFilter.today       => p.year == now.year && p.month == now.month && p.day == now.day,
    _DateFilter.tomorrow    => p.year == tomorrow.year && p.month == tomorrow.month && p.day == tomorrow.day,
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
        if (customTo != null && p.isAfter(customTo.add(const Duration(days: 1)))) return false;
        return true;
      }(),
  };
}

// ═════════════════════════════════════════════════════════════════════════════
// MAIN SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class PatientListScreen extends ConsumerStatefulWidget {
  final int? doctorId;
  const PatientListScreen({super.key, this.doctorId});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  final _searchCtrl = TextEditingController();
  String _query = '';
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _idSub;
  AppointmentList? _selected;
  _Tab _activeTab = _Tab.upcoming;

  _DateFilter _upcomingFilter  = _DateFilter.tomorrow;
  DateTime?   _upcomingFrom;
  DateTime?   _upcomingTo;
  bool        _upcomingSortNewest = true;

  _DateFilter _completedFilter = _DateFilter.today;
  DateTime?   _completedFrom;
  DateTime?   _completedTo;
  bool        _completedSortNewest = true;

  bool get _onCompletedTab => _activeTab == _Tab.completed;

  _DateFilter get _dateFilter => _onCompletedTab ? _completedFilter : _upcomingFilter;
  set _dateFilter(_DateFilter v) => _onCompletedTab ? _completedFilter = v : _upcomingFilter = v;

  DateTime? get _customFrom => _onCompletedTab ? _completedFrom : _upcomingFrom;
  set _customFrom(DateTime? v) => _onCompletedTab ? _completedFrom = v : _upcomingFrom = v;

  DateTime? get _customTo => _onCompletedTab ? _completedTo : _upcomingTo;
  set _customTo(DateTime? v) => _onCompletedTab ? _completedTo = v : _upcomingTo = v;

  bool get _sortNewest => _onCompletedTab ? _completedSortNewest : _upcomingSortNewest;
  set _sortNewest(bool v) => _onCompletedTab ? _completedSortNewest = v : _upcomingSortNewest = v;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() {
        _activeTab = _tabCtrl.index == 0 ? _Tab.upcoming : _Tab.completed;
        _selected  = null;
      });
    });
    _searchCtrl.addListener(() => setState(() => _query = _searchCtrl.text.toLowerCase()));
    _idSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) {
        if (widget.doctorId != null) return;
        if (next != null && next > 0) _refresh(force: false);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) { if (mounted) _refresh(force: false); });
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _idSub.close();
    super.dispose();
  }

  int get _doctorId =>
      widget.doctorId ?? ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  void _refresh({required bool force}) {
    if (_hasFetched && !force) return;
    final id = _doctorId;
    if (id == 0) return;
    _hasFetched = true;
    ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(id);
  }

  DateTime? _pd(String? s) => s == null ? null : DateTime.tryParse(s.trim());

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isAfter(DateTime? d) {
    if (d == null) return false;
    final t = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return DateTime(d.year, d.month, d.day).isAfter(t);
  }

  bool _match(AppointmentList a) {
    if (_query.isEmpty) return true;
    return (a.patientName?.toLowerCase().contains(_query) ?? false) ||
        (a.status?.toLowerCase().contains(_query) ?? false) ||
        (a.queueNumber?.toString().contains(_query) ?? false);
  }

  List<AppointmentList> _todayList(List<AppointmentList> all) => all
      .where((a) {
        final s = a.status?.toLowerCase().trim() ?? '';
        return (s == 'booked' || s == 'skipped' || s == 'in_progress') &&
            _isToday(_pd(a.appointmentDate)) && _match(a);
      })
      .toList()
    ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

  List<AppointmentList> _upcomingList(List<AppointmentList> all) {
    final list = all
        .where((a) =>
            (a.status?.toLowerCase().trim() ?? '') == 'booked' &&
            _isAfter(_pd(a.appointmentDate)) && _match(a) &&
            _passesDateFilter(a, _upcomingFilter, _upcomingFrom, _upcomingTo))
        .toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a.appointmentDate ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b.appointmentDate ?? '') ?? DateTime(0);
      return _upcomingSortNewest ? db.compareTo(da) : da.compareTo(db);
    });
    return list;
  }

  List<AppointmentList> _completedList(List<AppointmentList> all) {
    final list = all
        .where((a) {
          final s = a.status?.toLowerCase().trim() ?? '';
          return (s == 'completed' || s == 'done' || s == 'closed') && _match(a) &&
              _passesDateFilter(a, _completedFilter, _completedFrom, _completedTo);
        })
        .toList();
    list.sort((a, b) {
      final da = DateTime.tryParse(a.appointmentDate ?? '') ?? DateTime(0);
      final db = DateTime.tryParse(b.appointmentDate ?? '') ?? DateTime(0);
      return _completedSortNewest ? db.compareTo(da) : da.compareTo(db);
    });
    return list;
  }

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
          backgroundColor: isError ? kRed : kPrimaryDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          duration: const Duration(seconds: 2),
        ),
      );

  DateTime? _instantOf(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
    try { return DateTime.parse(v).toUtc(); } catch (_) { return null; }
  }

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = _doctorId;
    if (pid == 0 || did == 0) { _snack('Missing info', isError: true); return; }
    final status = p.status?.toLowerCase() ?? '';
    if (status != 'in_progress') {
      if (status == 'booked') {
        final slotStart = _instantOf(p.startTime);
        if (slotStart != null && DateTime.now().toUtc().isBefore(slotStart)) {
          _snack('Scheduled for ${_fmtTime(p.startTime)} — start once the slot begins.', isError: true);
          return;
        }
      }
      try {
        final res = await ref.read(appointmentViewModelProvider.notifier).startSession(
          AppointmentRequestModel(doctorId: did, patientId: pid, appointmentId: p.appointmentId ?? 0),
        );
        if (!mounted) return;
        if (res.success != true) { _snack(res.message ?? 'Could not start session', isError: true); return; }
      } catch (e) {
        if (mounted) _snack('Failed to start session: $e', isError: true);
        return;
      }
    }
    if (!mounted) return;
    final clinicId = ref.read(doctorLoginViewModelProvider).clinic_id;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PrescriptionScreen(
        patientId: pid, doctorId: did,
        userTypeId: p.userType ?? 1,
        appointmentId: p.appointmentId ?? 0,
        patientName: p.patientName ?? 'Patient',
        patientAge: _ageStr(p.dob),
        patientGender: p.gender,
        queueNumber: p.queueNumber,
        patientStatus: p.status ?? 'booked',
        symptoms: p.symptoms,
        clinicId: clinicId,
      ),
    ));
    if (!mounted) return;
    _hasFetched = false;
    _refresh(force: true);
  }

  Future<void> _skipPatient(AppointmentList p) async {
    final did = _doctorId;
    if (did == 0) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).queueSkip(
        AppointmentRequestModel(
          doctorId: did, appointmentId: p.appointmentId ?? 0,
          patientId: p.patientId ?? 0, isNext: 0,
        ),
      );
      if (!mounted) return;
      _snack(res.success == true ? (res.message ?? 'Patient skipped') : (res.message ?? 'Skip failed'),
          isError: res.success != true);
    } catch (e) {
      if (mounted) _snack('Failed to skip: $e', isError: true);
    }
  }

  void _viewPrescription(AppointmentList p) {
    if ((p.patientId ?? 0) == 0) { _snack('Missing info', isError: true); return; }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DoctorPrescriptionDetailScreen(
        appointmentId: p.appointmentId ?? 0,
        patientId: p.patientId ?? 0,
        patientName: p.patientName ?? 'Patient',
        patientAge: _ageStr(p.dob),
        patientGender: p.gender,
        queueNumber: p.queueNumber,
      ),
    ));
  }

  Future<void> _cancelByDoctor(AppointmentList p) async {
    final did = _doctorId;
    if (did == 0) { _snack('Missing info', isError: true); return; }
    if (ref.read(connectivityNotifierProvider).isOffline) {
      _snack('No internet connection.', isError: true);
      return;
    }
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).cancelByDoctor(
        AppointmentRequestModel(doctorId: did, appointmentId: p.appointmentId ?? 0),
      );
      if (!mounted) return;
      _snack(res.success == true ? (res.message ?? 'Appointment cancelled') : (res.message ?? 'Cancel failed'),
          isError: res.success != true);
    } catch (e) {
      if (mounted) _snack('Failed to cancel: $e', isError: true);
    }
  }

  void _cancelConfirm(AppointmentList p) => showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
            child: const Icon(Icons.cancel_outlined, color: kRed, size: 22),
          ),
          const SizedBox(height: 12),
          const Text('Cancel Appointment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 6),
          Text('Cancel appointment for ${p.patientName ?? 'this patient'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBorder),
                foregroundColor: kTextSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('No', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _cancelByDoctor(p); },
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('Yes, Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    ),
  );

  void _viewPatientInfo(AppointmentList p) {
    final (avBg, _, avFg) = _avatarPalettes[(p.appointmentId ?? 0) % _avatarPalettes.length];
    final name  = p.patientName ?? 'Patient';
    final inits = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final isSlot = _isSlotBooking(p);
    final status = p.status?.toLowerCase().trim() ?? '';
    final showStatusText = _showPatientStatusText(status);
    final slotMeta = isSlot ? _slotAppointmentMetaLabel(p.appointmentDate, p.startTime, includeYear: true) : null;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 60, height: 60,
              decoration: BoxDecoration(color: avBg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(inits, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: avFg)),
            ),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
                textAlign: TextAlign.center),
            if (p.gender != null || p.dob != null) ...[
              const SizedBox(height: 4),
              Text(
                [if (p.gender != null) p.gender!, if (_ageStr(p.dob) != null) _ageStr(p.dob)!].join(' | '),
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1, color: kDivider),
            if (showStatusText) _DetailRow('Status', _patientStatusLabel(status)),
            if (p.specialization != null) _DetailRow('Specialty', p.specialization!),
            _DetailRow('Date', isSlot && slotMeta != null ? slotMeta : _fmtDateLabel(p.appointmentDate, includeYear: true)),
            if (!isSlot) _DetailRow('Token', (p.queueNumber ?? 0).toString().padLeft(2, '0')),
            _DetailRow('Appointment ID', '${p.appointmentId ?? '--'}'),
            if (p.symptoms != null && p.symptoms!.isNotEmpty) _DetailRow('Symptoms', p.symptoms!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimaryDark, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  String? _ageStr(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    final n = DateTime.now();
    var y = n.year - d.year;
    if (n.month < d.month || (n.month == d.month && n.day < d.day)) y--;
    return y < 0 ? null : '$y yrs';
  }

  // ── Queue Controls ────────────────────────────────────────────────────────

  Future<bool> _confirm({
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    Color confirmColor = kPrimaryDark,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: confirmColor),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(confirmLabel, style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    return ok ?? false;
  }

  Future<void> _onQueueStart(int? queueId) async {
    final sessions = ref.read(appointmentViewModelProvider).todayQueueResult?.value ?? [];
    String? rawStart;
    for (final dynamic s in sessions) {
      if (s.queueId == queueId) { rawStart = s.startTime as String?; break; }
    }
    final slotStart = _instantOf(rawStart);
    if (slotStart != null && DateTime.now().toUtc().isBefore(slotStart)) {
      _snack('Queue starts at ${_fmtTime(rawStart)} — please wait.', isError: true);
      return;
    }
    final ok = await _confirm(
      title: 'Start Queue?',
      message: 'Patients will be notified that the queue is now live.',
      confirmLabel: 'Start',
      confirmColor: kPrimaryDark,
    );
    if (!ok) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue started');
    } catch (_) {
      _snack('Failed to start queue', isError: true);
    }
  }

  Future<void> _onQueuePause(int? queueId) async {
    final ok = await _confirm(
      title: 'Pause Queue?',
      message: 'Queue will be paused. Patients will be notified.',
      confirmLabel: 'Pause',
      confirmColor: Colors.orange,
    );
    if (!ok) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
    } catch (_) {
      _snack('Failed to pause queue', isError: true);
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
    final vmState     = ref.read(appointmentViewModelProvider);
    final allPatients = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final sessions    = vmState.todayQueueResult?.value ?? [];

    final matchingSession = sessions.where((s) => s.queueId == queueId).toList();
    final queueStartTime  = matchingSession.isEmpty
        ? null : DateTime.tryParse(matchingSession.first.startTime ?? '');

    final queuePending = allPatients.where((p) {
      if (p.queueId != queueId) return false;
      final st = (p.status?.toLowerCase() ?? '');
      return st == 'booked' || st == 'in_progress';
    }).length;
    final queueSkipped = allPatients.where((p) {
      if (p.queueId != queueId) return false;
      return (p.status?.toLowerCase() ?? '') == 'skipped';
    }).length;
    final earlierSlotPending = queueStartTime == null ? 0
        : allPatients.where((p) {
            if (p.bookingType != 2) return false;
            final st = (p.status?.toLowerCase() ?? '');
            if (st != 'booked' && st != 'skipped') return false;
            final pTime = DateTime.tryParse(p.startTime ?? '');
            return pTime != null && pTime.isBefore(queueStartTime);
          }).length;
    final totalCancel = queuePending + earlierSlotPending + queueSkipped;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(color: kRedLight, shape: BoxShape.circle, border: Border.all(color: kRedBorder)),
            child: const Icon(Icons.close_rounded, color: kRed, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('Close Queue?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 8),
          const Text('Are you sure you want to close this queue?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.5)),
          if (totalCancel > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAmberBorder),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: kAmberDark),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$totalCancel patient${totalCancel == 1 ? '' : 's'} will be cancelled',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kAmberDark)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (queuePending > 0) '$queuePending pending in this queue',
                      if (queueSkipped > 0) '$queueSkipped skipped in this queue',
                      if (earlierSlotPending > 0) '$earlierSlotPending from earlier slots',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 11, color: kAmberDark, height: 1.3),
                  ),
                ])),
              ]),
            ),
          ],
          const SizedBox(height: 4),
        ]),
        actions: [
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kRedLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRedBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Yes, Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRedDark)),
              ),
            )),
          ]),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue closed');
    } catch (_) {
      _snack('Failed to close queue', isError: true);
    }
  }

  Future<void> _onQueueEmergency(int? queueId) async {
    if (queueId == null) { _snack('Queue ID not available', isError: true); return; }
    if (ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId)) {
      _snack('Already emergency paused');
      return;
    }
    final confirmed = await _showEmergencyDialog();
    if (confirmed != true) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).queuePauseEmergency(queueId);
      _snack(res.message ?? 'Queue paused (emergency)');
    } catch (_) {
      _snack('Failed to pause queue', isError: true);
    }
  }

  Future<bool?> _showEmergencyDialog() => showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 52, height: 52,
          decoration: BoxDecoration(
            color: kPurpleLight, shape: BoxShape.circle, border: Border.all(color: kPurpleBorder)),
          child: const Icon(Icons.warning_amber_rounded, color: kPurple, size: 26),
        ),
        const SizedBox(height: 14),
        const Text('Emergency Pause?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 8),
        const Text('Pause the queue immediately?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.5)),
        const SizedBox(height: 4),
      ]),
      actions: [
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(ctx, false),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
              alignment: Alignment.center,
              child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(ctx, true),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: kPurpleLight, borderRadius: BorderRadius.circular(12), border: Border.all(color: kPurpleBorder)),
              alignment: Alignment.center,
              child: const Text('Yes, Pause', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPurpleDark)),
            ),
          )),
        ]),
      ],
    ),
  );

  // ── BUILD ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide      = MediaQuery.of(context).size.width >= _kWideBreak;
    final vmState     = ref.watch(appointmentViewModelProvider);
    final async       = vmState.patientAppointmentsList;
    final qs          = vmState.queueState;
    final allSessions = vmState.todayQueueResult?.value ?? [];

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(children: [
        _buildHeader(),
        Expanded(
          child: async.when(
            loading: () => const _SkeletonPatientList(),
            error: (e, _) => _ErrorView(onRetry: () => _refresh(force: true)),
            data: (all) {
              final today     = _todayList(all);
              final upcoming  = _upcomingList(all);
              final completed = _completedList(all);
              return isWide
                  ? _buildDesktop(today: today, upcoming: upcoming, completed: completed,
                      qs: qs, allSessions: allSessions, allAppointments: all)
                  : _buildMobile(today: today, upcoming: upcoming, completed: completed,
                      qs: qs, allSessions: allSessions, allAppointments: all);
            },
          ),
        ),
      ]),
    );
  }

  bool get _hasDateFilter =>
      _activeTab != _Tab.today && (_dateFilter != _DateFilter.all || !_sortNewest);

  String _fmtDateChip(DateTime d) {
    const m = ['','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${d.day} ${m[d.month]} ${d.year}';
  }

  void _showDateFilterSheet() => showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PatientDateFilterSheet(
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

  // ── Header ────────────────────────────────────────────────────────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row + search icon (matches Medicines page)
              Row(
                children: [
                  Expanded(
                    child: AppExpandableHeaderSearch(
                      controller: _searchCtrl,
                      leadingIcon: Icons.people_alt_rounded,
                      alwaysShowLeadingIcon: true,
                      title: 'Patients',
                      subtitle: 'Manage your queue',
                      hintText: 'Search by name, status or queue...',
                      accentColor: kPrimary,
                      leadingBackgroundColor: kPrimaryLight,
                      titleColor: kTextPrimary,
                      subtitleColor: kTextSecondary,
                      fieldColor: kPageBg,
                      borderColor: kBorder,
                      iconColor: kTextMuted,
                      textColor: kTextPrimary,
                    ),
                  ),
                  if (_activeTab != _Tab.today) ...[
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _showDateFilterSheet,
                      child: Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: _hasDateFilter ? kPrimaryLight : kPageBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: _hasDateFilter ? kPrimary : kBorder),
                        ),
                        child: Icon(Icons.tune_rounded,
                            color: _hasDateFilter ? kPrimaryDark : kTextMuted, size: 18),
                      ),
                    ),
                  ],
                ],
              ),

              // Active filter chips
              if (_hasDateFilter) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    if (_dateFilter != _DateFilter.all)
                      _filterChip(
                        icon: _dateFilter.icon,
                        label: _dateFilter == _DateFilter.custom && _customFrom != null
                            ? '${_fmtDateChip(_customFrom!)} – ${_customTo != null ? _fmtDateChip(_customTo!) : '…'}'
                            : _dateFilter.label,
                        onRemove: () => setState(() => _dateFilter = _DateFilter.all),
                      ),
                    if (!_sortNewest)
                      _filterChip(
                        icon: Icons.arrow_upward_rounded,
                        label: 'Oldest First',
                        onRemove: () => setState(() => _sortNewest = true),
                      ),
                  ],
                ),
              ],

              const SizedBox(height: 8),

              // Pill tab bar
              Container(
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F5F3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kHairline),
                ),
                child: TabBar(
                  controller: _tabCtrl,
                  labelColor: Colors.white,
                  unselectedLabelColor: kTextSecondary,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: kPrimaryDark,
                    borderRadius: BorderRadius.circular(17),
                  ),
                  indicatorPadding: const EdgeInsets.all(3),
                  labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
                  unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                  dividerColor: Colors.transparent,
                  splashFactory: NoSplash.splashFactory,
                  overlayColor: WidgetStateProperty.all(Colors.transparent),
                  tabs: const [
                    // Tab(text: 'Current Queue'),
                    Tab(text: 'Upcoming'),
                    Tab(text: 'Completed'),
                  ],
                ),
              ),
            //  const Divider(height: 1, color: kBorder),
            ],
          ),
        ),
      ),
    );
  }

  Widget _filterChip({required IconData icon, required String label, required VoidCallback onRemove}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
          color: kPrimaryLight,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF9FE1CB)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: kPrimaryDark, size: 11),
          const SizedBox(width: 5),
          Text(label, style: const TextStyle(fontSize: 11, color: kPrimaryDark, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GestureDetector(onTap: onRemove,
              child: const Icon(Icons.close_rounded, color: kPrimaryDark, size: 12)),
        ]),
      );

  Widget _buildMobile({
    required List<AppointmentList> today,
    required List<AppointmentList> upcoming,
    required List<AppointmentList> completed,
    required QueueState qs,
    required List<dynamic> allSessions,
    required List<AppointmentList> allAppointments,
  }) {
    return TabBarView(
      controller: _tabCtrl,
      children: [
        _PatientListBody(
          patients: upcoming, tab: _Tab.upcoming, qs: qs,
          onStart: _startSession, onSkip: _skipPatient,
          onPrescription: _viewPrescription, onCancel: _cancelConfirm,
          onView: _viewPatientInfo,
          extraBottom: _kBottomClear,
        ),
        _PatientListBody(
          patients: completed, tab: _Tab.completed, qs: qs,
          onStart: _startSession, onSkip: _skipPatient,
          onPrescription: _viewPrescription, onCancel: _cancelConfirm,
          extraBottom: _kBottomClear,
        ),
      ],
    );
  }

  Widget _buildDesktop({
    required List<AppointmentList> today,
    required List<AppointmentList> upcoming,
    required List<AppointmentList> completed,
    required QueueState qs,
    required List<dynamic> allSessions,
    required List<AppointmentList> allAppointments,
  }) {
    final list = switch (_activeTab) {
      _Tab.today     => today,
      _Tab.upcoming  => upcoming,
      _Tab.completed => completed,
    };
    return Row(children: [
      _DesktopSidebar(
        activeTab: _activeTab,
        todayCount: upcoming.length,
        completedCount: completed.length,
        total: upcoming.length + completed.length,
        searchCtrl: _searchCtrl,
        onTabChange: (t) => setState(() {
          _activeTab = t;
          _selected  = null;
          _tabCtrl.animateTo(t == _Tab.completed ? 1 : 0);
        }),
      ),
      Expanded(
        child: _PatientListBody(
                patients: list, tab: _activeTab, qs: qs,
                onStart: _startSession, onSkip: _skipPatient,
                onPrescription: _viewPrescription, onCancel: _cancelConfirm,
                onView: _activeTab != _Tab.completed ? _viewPatientInfo : null,
                extraBottom: 0,
                selected: _selected,
                onSelect: (p) => setState(() => _selected = p),
              ),
      ),
      SizedBox(
        width: _kDeskDetail,
        child: _DetailPanel(
          patient: _selected, tab: _activeTab,
          onStart: _startSession, onSkip: _skipPatient,
          onPrescription: _viewPrescription, onCancel: _cancelConfirm,
        ),
      ),
    ]);
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SESSION-GROUPED BODY
// ═════════════════════════════════════════════════════════════════════════════
class _SessionGroupedBody extends StatefulWidget {
  final List<dynamic> allSessions;
  final List<AppointmentList> allAppointments;
  final List<AppointmentList> todayPatients;
  final QueueState qs;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final double extraBottom;
  final AppointmentList? selected;
  final void Function(AppointmentList)? onSelect;
  final Future<void> Function() onRefresh;
  final Future<void> Function(int? queueId) onQueueStart;
  final Future<void> Function(int? queueId) onQueuePause;
  final Future<void> Function(int? queueId) onQueueStop;
  final Future<void> Function(int? queueId) onQueueEmergency;
  final Set<int> emergencyQueueIds;

  const _SessionGroupedBody({
    required this.allSessions,
    required this.allAppointments,
    required this.todayPatients,
    required this.qs,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.extraBottom,
    required this.onRefresh,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    required this.emergencyQueueIds,
    this.selected,
    this.onSelect,
  });

  @override
  State<_SessionGroupedBody> createState() => _SessionGroupedBodyState();
}

class _SessionGroupedBodyState extends State<_SessionGroupedBody> {
  final Map<int, bool> _expanded = {};

  bool _shouldShow(dynamic session) {
    if (_isStaleQueueDate(session.queueDate as String?)) return false;
    final qs      = session.queueStatus ?? 0;
    final hasSlot = _slotTimeLabel(session.startTime as String?, session.endTime as String?) != null;
    if (qs == 3) return false;
    if (qs == 0 && !hasSlot) return false;
    return true;
  }

  bool _isStaleQueueDate(String? queueDate) {
    final d = DateTime.tryParse(queueDate ?? '');
    if (d == null) return false;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day).isBefore(DateTime(now.year, now.month, now.day));
  }

  List<({int? slotId, List<AppointmentList> patients})> _groupSlotPatients(
      List<AppointmentList> slotPatients) {
    final order = <int?>[];
    final map   = <int?, List<AppointmentList>>{};
    for (final p in slotPatients) {
      final key = p.slotId;
      if (!map.containsKey(key)) { order.add(key); map[key] = []; }
      map[key]!.add(p);
    }
    return order.map((k) => (slotId: k, patients: map[k]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = widget.allSessions.where(_shouldShow).toList()
      ..sort((a, b) {
        final aT = DateTime.tryParse(a.startTime as String? ?? '');
        final bT = DateTime.tryParse(b.startTime as String? ?? '');
        if (aT == null && bT == null) return 0;
        if (aT == null) return 1;
        if (bT == null) return -1;
        return aT.compareTo(bT);
      });

    final slotPatients = widget.todayPatients.where((p) => p.bookingType == 2).toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    final slotGroups = _groupSlotPatients(slotPatients);

    if (visibleSessions.isEmpty && slotPatients.isEmpty) {
      return _PatientListBody(
        patients: widget.todayPatients, tab: _Tab.today, qs: widget.qs,
        onStart: widget.onStart, onSkip: widget.onSkip,
        onPrescription: widget.onPrescription, onCancel: widget.onCancel,
        extraBottom: widget.extraBottom, selected: widget.selected, onSelect: widget.onSelect,
      );
    }

    // Build unified sorted list
    final unified = <Object>[
      ...visibleSessions.asMap().entries.map((e) => _StandaloneSessionItem(session: e.value, globalIndex: e.key)),
      ...slotGroups,
    ];

    DateTime? _startTimeOf(Object obj) {
      if (obj is _StandaloneSessionItem) return DateTime.tryParse(obj.session.startTime as String? ?? '');
      final g = obj as ({int? slotId, List<AppointmentList> patients});
      if (g.patients.isEmpty) return null;
      return DateTime.tryParse(g.patients.first.startTime ?? '');
    }

    unified.sort((a, b) {
      final aT = _startTimeOf(a);
      final bT = _startTimeOf(b);
      if (aT == null && bT == null) return 0;
      if (aT == null) return 1;
      if (bT == null) return -1;
      return aT.compareTo(bT);
    });

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + widget.extraBottom),
        itemCount: unified.length,
        itemBuilder: (_, i) {
          final obj = unified[i];

          if (obj is _StandaloneSessionItem) {
            final session  = obj.session;
            final queueId  = session.queueId as int? ?? obj.globalIndex;
            final expandKey = -(queueId + 1);
            final isExpanded = _expanded[expandKey] ?? true;
            final sessionPatients = widget.todayPatients
                .where((p) => (p.bookingType == null || p.bookingType == 1) && p.queueId == queueId)
                .toList();
            final qs       = _sessionQueueState(session.queueStatus as int?);
            final slotLabel = _slotTimeLabel(session.startTime as String?, session.endTime as String?);
            final hasIP     = sessionPatients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
            final currentPt = sessionPatients.where((p) => p.appointmentId == (session.currentServing as int?)).firstOrNull
                ?? sessionPatients.where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').firstOrNull;
            final isEmerg   = widget.emergencyQueueIds.contains(queueId);

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _SessionAccordion(
                key: ValueKey('session_$queueId'),
                session: session,
                sessionIndex: obj.globalIndex,
                slotLabel: slotLabel,
                queueState: qs,
                sessionPatients: sessionPatients,
                currentPatient: currentPt,
                isExpanded: isExpanded,
                selected: widget.selected,
                isEmergency: isEmerg,
                onToggle: () => setState(() => _expanded[expandKey] = !isExpanded),
                onExpandFullscreen: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => _QueueFullscreenPage(
                      sessionIndex: obj.globalIndex,
                      slotLabel: slotLabel,
                      queueState: qs,
                      sessionPatients: sessionPatients,
                      isEmergency: isEmerg,
                      globalQs: widget.qs,
                      onStart: widget.onStart,
                      onSkip: widget.onSkip,
                      onPrescription: widget.onPrescription,
                      onCancel: widget.onCancel,
                      onQueueStart: () => widget.onQueueStart(queueId),
                      onQueuePause: () => widget.onQueuePause(queueId),
                      onQueueStop:  () => widget.onQueueStop(queueId),
                      onQueueEmergency: () => widget.onQueueEmergency(queueId),
                    ),
                  ),
                ),
                onStart: widget.onStart,
                onSkip: widget.onSkip,
                onPrescription: widget.onPrescription,
                onCancel: widget.onCancel,
                onSelect: widget.onSelect,
                globalQs: widget.qs,
                onQueueStart: () => widget.onQueueStart(queueId),
                onQueuePause: () => widget.onQueuePause(queueId),
                onQueueStop:  () => widget.onQueueStop(queueId),
                onQueueEmergency: () => widget.onQueueEmergency(queueId),
              ),
            );
          }

          // Slot booking group
          final group    = obj as ({int? slotId, List<AppointmentList> patients});
          final groupKey = group.slotId ?? -1;
          final isExpanded = _expanded[groupKey] ?? true;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _SlotBookingsSection(
              key: ValueKey('slot_${group.slotId}'),
              slotId: group.slotId,
              patients: group.patients,
              isExpanded: isExpanded,
              onToggle: () => setState(() => _expanded[groupKey] = !isExpanded),
              selected: widget.selected,
              onStart: widget.onStart,
              onSkip: widget.onSkip,
              onPrescription: widget.onPrescription,
              onCancel: widget.onCancel,
              onSelect: widget.onSelect,
              qs: widget.qs,
            ),
          );
        },
      ),
    );
  }
}

abstract class _ListItem {}
class _StandaloneSessionItem extends _ListItem {
  final dynamic session;
  final int globalIndex;
  _StandaloneSessionItem({required this.session, required this.globalIndex});
}

// ═════════════════════════════════════════════════════════════════════════════
// SESSION ACCORDION
// ═════════════════════════════════════════════════════════════════════════════
class _SessionAccordion extends StatelessWidget {
  final dynamic session;
  final int sessionIndex;
  final String? slotLabel;
  final QueueState queueState;
  final QueueState globalQs;
  final List<AppointmentList> sessionPatients;
  final AppointmentList? currentPatient;
  final bool isExpanded;
  final bool isEmergency;
  final AppointmentList? selected;
  final VoidCallback onToggle;
  final VoidCallback onExpandFullscreen;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final void Function(AppointmentList)? onSelect;
  final VoidCallback onQueueStart, onQueuePause, onQueueStop, onQueueEmergency;

  const _SessionAccordion({
    super.key,
    required this.session,
    required this.sessionIndex,
    required this.slotLabel,
    required this.queueState,
    required this.globalQs,
    required this.sessionPatients,
    required this.currentPatient,
    required this.isExpanded,
    required this.isEmergency,
    required this.onToggle,
    required this.onExpandFullscreen,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (queueState == QueueState.stopped) return const SizedBox.shrink();

    final (Color borderColor, double borderWidth) = switch (queueState) {
      QueueState.running => (kPrimary, 2.0),
      QueueState.paused  => (kAmber, 1.5),
      _                  => (kCardBorder, 1.0),
    };

    final hasIP     = sessionPatients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
    final nextBooked = sessionPatients
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final queueActive = queueState == QueueState.running || queueState == QueueState.paused;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: isExpanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Text('S${sessionIndex + 1}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: kPrimaryDark)),
              ),
              const SizedBox(width: 10),
              if (slotLabel != null)
                Expanded(child: Row(children: [
                  const Icon(Icons.access_time_rounded, size: 13, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(child: Text(slotLabel!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                      overflow: TextOverflow.ellipsis)),
                ]))
              else
                const Expanded(child: Text('Session',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary))),
              const SizedBox(width: 8),
              _QueueStateBadge(state: queueState),
              const SizedBox(width: 6),
              // Fullscreen expand button
              GestureDetector(
                onTap: onExpandFullscreen,
                child: Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(7),
                    border: Border.all(color: const Color(0xFF9FE1CB)),
                  ),
                  child: const Icon(Icons.open_in_full_rounded, size: 14, color: kPrimaryDark),
                ),
              ),
              const SizedBox(width: 6),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
              ),
            ]),
          ),
        ),

        // Body
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Divider(height: 1, color: kHairline),
              const SizedBox(height: 10),

              // Live queue controls
              _LiveQueueCard(
                patients: sessionPatients,
                qs: queueState,
                onQueueStart: onQueueStart,
                onQueuePause: onQueuePause,
                onQueueStop: onQueueStop,
                onQueueEmergency: onQueueEmergency,
                isEmergencyPaused: isEmergency,
              ),

              // Patient list
              if (sessionPatients.isEmpty)
                _emptyPatients()
              else ...[
                _sectionLabel('Waiting', sessionPatients.length),
                ...sessionPatients.map((p) {
                  final status = p.status?.toLowerCase() ?? '';
                  final isIP   = status == 'in_progress';
                  bool accessible = false;
                  if (isIP) { accessible = true; }
                  else if (status == 'skipped') { accessible = true; }
                  else if (queueActive && status == 'booked') {
                    accessible = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                  }
                  final effectiveAccessible = status == 'skipped' ? accessible : queueActive && accessible;
                  final VoidCallback? effectiveSkip = queueActive && accessible && status == 'booked'
                      ? () => onSkip(p) : null;

                  return Padding(
                    padding: const EdgeInsets.only(top: 7),
                    child: _PatientCard(
                      key: ValueKey(p.appointmentId),
                      patient: p, tab: _Tab.today,
                      accessible: effectiveAccessible,
                      selected: selected?.appointmentId == p.appointmentId,
                      highlightBorder: isIP && queueActive,
                      onTap: onSelect != null ? () => onSelect!(p) : null,
                      onStart: () => onStart(p),
                      onSkip: effectiveSkip,
                      onPrescription: () => onPrescription(p),
                      onCancel: () => onCancel(p),
                    ),
                  );
                }),
              ],
            ]),
          ),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }

  Widget _emptyPatients() => Container(
    padding: const EdgeInsets.symmetric(vertical: 16),
    alignment: Alignment.center,
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle, border: Border.all(color: const Color(0xFF9FE1CB))),
        child: const Icon(Icons.inbox_rounded, color: kPrimaryDark, size: 18),
      ),
      const SizedBox(height: 8),
      const Text('No patients waiting', style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
    ]),
  );

  Widget _sectionLabel(String label, int count) => Padding(
    padding: const EdgeInsets.only(bottom: 6, top: 2),
    child: Row(children: [
      Container(width: 3, height: 14, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20)),
        child: Text('$count', style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
      ),
    ]),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// QUEUE FULLSCREEN PAGE
// ═════════════════════════════════════════════════════════════════════════════
class _QueueFullscreenPage extends StatelessWidget {
  final int sessionIndex;
  final String? slotLabel;
  final QueueState queueState;
  final QueueState globalQs;
  final List<AppointmentList> sessionPatients;
  final bool isEmergency;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final VoidCallback onQueueStart, onQueuePause, onQueueStop, onQueueEmergency;

  const _QueueFullscreenPage({
    required this.sessionIndex,
    required this.slotLabel,
    required this.queueState,
    required this.globalQs,
    required this.sessionPatients,
    required this.isEmergency,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final hasIP = sessionPatients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
    final nextBooked = sessionPatients
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final queueActive = queueState == QueueState.running || queueState == QueueState.paused;

    final title = slotLabel ?? 'Session ${sessionIndex + 1}';

    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Compact header — back + title + state badge
            Container(
              color: Colors.white,
              padding: const EdgeInsets.fromLTRB(8, 8, 12, 8),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 20, color: kTextSecondary),
                  onPressed: () => Navigator.pop(context),
                  splashRadius: 20,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
                ),
                _QueueStateBadge(state: queueState),
              ]),
            ),
            const Divider(height: 1, color: kBorder),

            // Scrollable content — live queue card + patient list
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
                children: [
                  _LiveQueueCard(
                    patients: sessionPatients,
                    qs: queueState,
                    onQueueStart: onQueueStart,
                    onQueuePause: onQueuePause,
                    onQueueStop: onQueueStop,
                    onQueueEmergency: onQueueEmergency,
                    isEmergencyPaused: isEmergency,
                    showTokenBoxes: true,
                  ),
                  if (sessionPatients.isEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 32),
                      alignment: Alignment.center,
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle,
                              border: Border.all(color: const Color(0xFF9FE1CB))),
                          child: const Icon(Icons.inbox_rounded, color: kPrimaryDark, size: 22),
                        ),
                        const SizedBox(height: 10),
                        const Text('No patients waiting',
                            style: TextStyle(color: kTextMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                      ]),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8, top: 2),
                      child: Row(children: [
                        Container(width: 3, height: 14, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(3))),
                        const SizedBox(width: 7),
                        const Text('Waiting', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20)),
                          child: Text('${sessionPatients.length}',
                              style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
                        ),
                      ]),
                    ),
                    ...sessionPatients.map((p) {
                      final status = p.status?.toLowerCase() ?? '';
                      final isIP   = status == 'in_progress';
                      bool accessible = false;
                      if (isIP) { accessible = true; }
                      else if (status == 'skipped') { accessible = true; }
                      else if (queueActive && status == 'booked') {
                        accessible = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                      }
                      final effectiveAccessible = status == 'skipped' ? accessible : queueActive && accessible;
                      final VoidCallback? effectiveSkip = queueActive && accessible && status == 'booked'
                          ? () => onSkip(p) : null;

                      return Padding(
                        padding: const EdgeInsets.only(top: 7),
                        child: _PatientCard(
                          key: ValueKey(p.appointmentId),
                          patient: p,
                          tab: _Tab.today,
                          accessible: effectiveAccessible,
                          selected: false,
                          highlightBorder: isIP && queueActive,
                          onStart: () => onStart(p),
                          onSkip: effectiveSkip,
                          onPrescription: () => onPrescription(p),
                          onCancel: () => onCancel(p), onTap: () {  },
                        ),
                      );
                    }),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// LIVE QUEUE CARD
// ═════════════════════════════════════════════════════════════════════════════
class _LiveQueueCard extends StatelessWidget {
  final List<AppointmentList> patients;
  final QueueState qs;
  final VoidCallback onQueueStart, onQueuePause, onQueueStop;
  final VoidCallback? onQueueEmergency;
  final bool isEmergencyPaused;
  final bool showTokenBoxes;

  const _LiveQueueCard({
    required this.patients,
    required this.qs,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    this.onQueueEmergency,
    this.isEmergencyPaused = false,
    this.showTokenBoxes = false,
  });

  @override
  Widget build(BuildContext context) {
    if (qs == QueueState.stopped) return const SizedBox.shrink();

    final isRunning = qs == QueueState.running;
    final isPaused  = qs == QueueState.paused;

    final ip = patients.firstWhere(
      (p) => (p.status?.toLowerCase() ?? '') == 'in_progress',
      orElse: () => AppointmentList(),
    );
    final hasIP  = (ip.appointmentId ?? 0) != 0;
    final booked = patients.where((p) => (p.status?.toLowerCase() ?? '') == 'booked').toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current   = hasIP ? ip : booked.firstOrNull;
    final next      = hasIP ? booked.firstOrNull : (booked.length > 1 ? booked[1] : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryLight),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top row
          Row(children: [
            _PulseDot(),
            const SizedBox(width: 6),
            const Text('LIVE QUEUE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: kPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined, size: 10, color: kPrimaryDark),
                const SizedBox(width: 3),
                Text('${patients.length}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
              ]),
            ),
            const Spacer(),
            // Play/Pause
            _QueueIconBtn(
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              bg:    isRunning ? kAmberLight : kPrimaryLight,
              border: isRunning ? kAmberBorder : const Color(0xFF9FE1CB),
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning ? onQueuePause : onQueueStart,
            ),
            // Close
            if (!isEmergencyPaused) ...[
              const SizedBox(width: 5),
              _QueueIconBtn(
                icon: Icons.close_rounded,
                color: kRedDark, bg: kRedLight, border: kRedBorder,
                tooltip: 'Close queue',
                onTap: onQueueStop,
              ),
            ],
            // Emergency
            if (onQueueEmergency != null) ...[
              const SizedBox(width: 5),
              _QueueIconBtn(
                icon: Icons.warning_amber_rounded,
                color: kPurpleDark, bg: kPurpleLight, border: kPurpleBorder,
                tooltip: 'Emergency pause',
                onTap: onQueueEmergency!,
              ),
            ],
          ]),
          if (showTokenBoxes) ...[
            const SizedBox(height: 10),
            Row(children: [
              _TokBox(label: 'CURRENT',   value: current != null ? (current.queueNumber ?? 0).toString().padLeft(2,'0') : '--', isActive: true),
              const SizedBox(width: 5),
              _TokBox(label: 'UP NEXT',   value: next != null ? (next.queueNumber ?? 0).toString().padLeft(2,'0') : '--'),
              const SizedBox(width: 5),
              _TokBox(label: 'REMAINING', value: patients.length.toString().padLeft(2,'0'), isGreen: true),
            ]),
          ],
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SLOT BOOKINGS SECTION
// ═════════════════════════════════════════════════════════════════════════════
class _SlotBookingsSection extends StatelessWidget {
  final int? slotId;
  final List<AppointmentList> patients;
  final QueueState qs;
  final bool isExpanded;
  final VoidCallback onToggle;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final AppointmentList? selected;
  final void Function(AppointmentList)? onSelect;

  const _SlotBookingsSection({
    super.key,
    required this.patients, required this.qs, required this.isExpanded,
    required this.onToggle, required this.onStart, required this.onSkip,
    required this.onPrescription, required this.onCancel,
    this.slotId, this.selected, this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBlueBorder),
      ),
      child: Column(children: [
        InkWell(
          onTap: onToggle,
          borderRadius: BorderRadius.vertical(
            top: const Radius.circular(14),
            bottom: isExpanded ? Radius.zero : const Radius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
            child: Row(children: [
              Container(
                width: 26, height: 26,
                decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: const Icon(Icons.calendar_month_rounded, size: 14, color: kBlueDark),
              ),
              const SizedBox(width: 10),
              const Expanded(child: Text('Slot Bookings',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(20)),
                child: Text('${patients.length}',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kBlueDark)),
              ),
              const SizedBox(width: 8),
              AnimatedRotation(
                turns: isExpanded ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
              ),
            ]),
          ),
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: Column(children: [
            const Divider(height: 1, color: kHairline),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                children: patients.map((p) {
                  final status = p.status?.toLowerCase() ?? '';
                  final accessible = status == 'booked' || status == 'in_progress' || status == 'skipped';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: _PatientCard(
                      key: ValueKey(p.appointmentId),
                      patient: p, tab: _Tab.today,
                      accessible: accessible,
                      selected: selected?.appointmentId == p.appointmentId,
                      onTap: onSelect != null ? () => onSelect!(p) : null,
                      onStart: () => onStart(p),
                      onSkip: accessible && status == 'booked' ? () => onSkip(p) : null,
                      onPrescription: () => onPrescription(p),
                      onCancel: () => onCancel(p),
                    ),
                  );
                }).toList(),
              ),
            ),
          ]),
          crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
        ),
      ]),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PATIENT LIST BODY  (Completed tab)
// ═════════════════════════════════════════════════════════════════════════════
class _PatientListBody extends ConsumerWidget {
  final List<AppointmentList> patients;
  final _Tab tab;
  final QueueState qs;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final void Function(AppointmentList)? onView;
  final double extraBottom;
  final AppointmentList? selected;
  final void Function(AppointmentList)? onSelect;

  const _PatientListBody({
    required this.patients, required this.tab, required this.qs,
    required this.onStart, required this.onSkip,
    required this.onPrescription, required this.onCancel,
    required this.extraBottom,
    this.onView, this.selected, this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (patients.isEmpty) return _EmptyState(tab: tab);

    final hasIP       = tab == _Tab.today && patients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
    final isQueueActive = qs == QueueState.running || qs == QueueState.paused;
    final booked      = tab == _Tab.today
        ? (patients.where((p) => (p.status?.toLowerCase() ?? '') == 'booked').toList()
            ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0)))
        : <AppointmentList>[];
    final firstBooked = booked.firstOrNull;

    final onRefresh = () async {
      ref.read(appointmentViewModelProvider.notifier)
          .fetchPatientAppointments(ref.read(doctorLoginViewModelProvider).doctorId ?? 0);
      await Future.delayed(const Duration(milliseconds: 600));
    };

    // ── Upcoming tab: date-grouped view ──────────────────────────────
    if (tab == _Tab.upcoming) {
      final groups = <String, List<AppointmentList>>{};
      for (final p in patients) {
        groups.putIfAbsent(p.appointmentDate ?? '', () => []).add(p);
      }
      final sortedDates = groups.keys.toList()
        ..sort((a, b) => (DateTime.tryParse(a) ?? DateTime(0))
            .compareTo(DateTime.tryParse(b) ?? DateTime(0)));

      // Flat items: (String,int) = date header+count, AppointmentList = card
      final items = <Object>[];
      for (final date in sortedDates) {
        final list = groups[date]!;
        items.add((date, list.length));
        items.addAll(list);
      }

      return RefreshIndicator(
        color: kPrimary,
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + extraBottom),
          itemCount: items.length + 1,
          itemBuilder: (ctx, i) {
            if (i == 0) {
              return _SectionHeader(
                title: 'Upcoming',
                badge: '${patients.length} scheduled',
              );
            }
            final item = items[i - 1];
            if (item is (String, int)) {
              return _DateGroupHeader(dateStr: item.$1, count: item.$2);
            }
            final p = item as AppointmentList;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _PatientCard(
                key: ValueKey(p.appointmentId),
                patient: p, tab: tab,
                accessible: true,
                selected: selected?.appointmentId == p.appointmentId,
                onTap: onSelect != null ? () => onSelect!(p) : null,
                onStart: () => onStart(p),
                onSkip: null,
                onPrescription: () => onPrescription(p),
                onCancel: () => onCancel(p),
                onView: onView != null ? () => onView!(p) : null,
              ),
            );
          },
        ),
      );
    }

    // ── Completed: date-grouped view ─────────────────────────────────
    if (tab == _Tab.completed) {
      final groups = <String, List<AppointmentList>>{};
      for (final p in patients) {
        groups.putIfAbsent(p.appointmentDate ?? '', () => []).add(p);
      }
      final sortedDates = groups.keys.toList()
        ..sort((a, b) => (DateTime.tryParse(b) ?? DateTime(0))
            .compareTo(DateTime.tryParse(a) ?? DateTime(0))); // newest first

      final items = <Object>[];
      for (final date in sortedDates) {
        final list = groups[date]!;
        items.add((date, list.length));
        items.addAll(list);
      }

      return RefreshIndicator(
        color: kPrimary,
        onRefresh: onRefresh,
        child: ListView.builder(
          padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + extraBottom),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final item = items[i];
            if (item is (String, int)) {
              return _DateGroupHeader(dateStr: item.$1, count: item.$2);
            }
            final p = item as AppointmentList;
            return Padding(
              padding: const EdgeInsets.only(bottom: 7),
              child: _PatientCard(
                key: ValueKey(p.appointmentId),
                patient: p, tab: tab,
                accessible: false,
                selected: selected?.appointmentId == p.appointmentId,
                onTap: onSelect != null ? () => onSelect!(p) : null,
                onStart: () => onStart(p),
                onSkip: null,
                onPrescription: () => onPrescription(p),
                onCancel: () => onCancel(p),
                onView: onView != null ? () => onView!(p) : null,
              ),
            );
          },
        ),
      );
    }

    // ── Today: flat list ──────────────────────────────────────────────
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 10, 12, 10 + extraBottom),
        itemCount: patients.length + 1,
        itemBuilder: (ctx, i) {
          if (i == 0) {
            return _SectionHeader(title: 'Waiting', badge: '${patients.length} left');
          }
          final p      = patients[i - 1];
          final status = p.status?.toLowerCase() ?? '';
          bool accessible = true;
          if (status == 'in_progress') { accessible = true; }
          else if (status == 'skipped') { accessible = true; }
          else if (!isQueueActive) { accessible = false; }
          else if (status == 'booked') {
            accessible = !hasIP && p.queueNumber == firstBooked?.queueNumber;
          }
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: _PatientCard(
              key: ValueKey(p.appointmentId),
              patient: p, tab: tab,
              accessible: accessible,
              selected: selected?.appointmentId == p.appointmentId,
              onTap: onSelect != null ? () => onSelect!(p) : null,
              onStart: () => onStart(p),
              onSkip: accessible && status == 'booked' ? () => onSkip(p) : null,
              onPrescription: () => onPrescription(p),
              onCancel: () => onCancel(p),
              onView: onView != null ? () => onView!(p) : null,
            ),
          );
        },
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PATIENT CARD
// ═════════════════════════════════════════════════════════════════════════════
class _PatientCard extends ConsumerWidget {
  final AppointmentList patient;
  final _Tab tab;
  final bool accessible, selected, highlightBorder;
  final VoidCallback? onTap, onSkip, onView;
  final VoidCallback onStart, onPrescription, onCancel;

  const _PatientCard({
    super.key,
    required this.patient, required this.tab,
    required this.accessible, required this.selected,
    required this.onTap, required this.onStart,
    required this.onSkip, required this.onPrescription, required this.onCancel,
    this.highlightBorder = false, this.onView,
  });

  (Color, Color, Color) get _av =>
      _avatarPalettes[(patient.appointmentId ?? 0) % _avatarPalettes.length];

  String get _inits => (patient.patientName ?? '?')
      .trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();

  String get _info {
    final parts = <String>[];
    if (patient.gender != null) parts.add(patient.gender!);
    final d = patient.dob == null ? null : DateTime.tryParse(patient.dob!);
    if (d != null) {
      final n = DateTime.now();
      var y = n.year - d.year;
      if (n.month < d.month || (n.month == d.month && n.day < d.day)) y--;
      if (y >= 0) parts.add('$y yrs');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isReceptionist = ref.watch(tokenProvider).roleId == 3;
    final (avBg, avBd, avFg) = _av;
    final status   = (patient.status ?? '').toLowerCase().trim();
    final isIP     = status == 'in_progress';
    final isSlot   = _isSlotBooking(patient);
    final showStat = _showPatientStatusText(status);

    final metaLabel = switch (tab) {
      _Tab.today when isSlot  => _slotTimeLabel(patient.startTime, patient.endTime),
      _Tab.today              => null,
      _ when isSlot           => _slotAppointmentMetaLabel(patient.appointmentDate, patient.startTime),
      _                       => _fmtDateLabel(patient.appointmentDate),
    };

    final (Color sBg, Color sFg, Color sDot) = switch (status) {
      'in_progress'                        => (kPrimaryLight, kPrimaryDark, kPrimary),
      'skipped'                            => (kAmberLight,   kAmberDark,   kAmber),
      'completed' || 'done' || 'closed'    => (kGreenLight,   kGreenDark,   kGreen),
      _                                    => (kRedLight,      kRedDark,     kRed),
    };

    final Color borderColor = selected
        ? kPrimary
        : highlightBorder ? kPrimary
        : isIP ? kPrimary
        : status == 'skipped' ? kAmber
        : kCardBorder;
    final double borderWidth = (selected || highlightBorder || isIP) ? 1.5 : 1.0;

    // Receptionist skip
    VoidCallback? effectiveOnSkip = onSkip;
    if (isReceptionist && tab == _Tab.today && status == 'booked' && onSkip == null) {
      final did = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
      if (did > 0) {
        effectiveOnSkip = () {
          ref.read(appointmentViewModelProvider.notifier).queueSkip(
            AppointmentRequestModel(
              doctorId: did,
              appointmentId: patient.appointmentId ?? 0,
              patientId: patient.patientId ?? 0,
              isNext: 0,
            ),
          );
        };
      }
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(patient.patientName ?? 'Patient',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: kTextPrimary, letterSpacing: -0.1, height: 1.15),
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 1),
              Text(_info, style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
              const SizedBox(height: 4),
              Wrap(spacing: 4, runSpacing: 3, children: [
                if (showStat) _DotChip(label: _patientStatusLabel(status), bg: sBg, fg: sFg, dot: sDot),
                if (metaLabel != null) _Chip(label: metaLabel, bg: kBlueLight, fg: kBlueDark),
              ]),
            ])),
            if (!isSlot) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                decoration: BoxDecoration(
                  color: avBg, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: avBd),
                ),
                child: Column(children: [
                  const Text('TOKEN', style: TextStyle(fontSize: 7.5, color: kTextMuted,
                      fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                  const SizedBox(height: 1),
                  Text((patient.queueNumber ?? 0).toString().padLeft(2, '0'),
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: avFg, height: 1)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            if (tab == _Tab.today) ...[
              if (effectiveOnSkip != null) ...[
                Expanded(child: _ActionBtn(
                  label: 'Skip', bg: kRedLight, fg: kRedDark, border: kRedBorder,
                  onTap: effectiveOnSkip,
                )),
                if (!isReceptionist) const SizedBox(width: 7),
              ],
              if (!isReceptionist && accessible)
                Expanded(flex: 2, child: _ActionBtn(
                  label: isIP ? 'Continue' : status == 'skipped' ? 'Recall' : 'Start Session',
                  bg: kPrimaryDark,
                  fg: Colors.white,
                  onTap: onStart,
                )),
            ] else if (tab == _Tab.upcoming) ...[
              Expanded(child: _ActionBtn(
                  label: 'View', bg: kPrimaryLight, fg: kPrimaryDark, border: const Color(0xFF9FE1CB), onTap: onView)),
              const SizedBox(width: 7),
              Expanded(child: _ActionBtn(
                  label: 'Cancel', bg: kRedLight, fg: kRedDark, border: kRedBorder, onTap: onCancel)),
            ] else ...[
              Expanded(child: _ActionBtn(
                  label: 'View Prescription', bg: kPurpleLight, fg: kPurpleDark, border: kPurpleBorder, onTap: onPrescription)),
            ],
          ]),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DESKTOP COMPONENTS
// ═════════════════════════════════════════════════════════════════════════════
class _DesktopSidebar extends StatelessWidget {
  final _Tab activeTab;
  final int todayCount, completedCount, total;
  final TextEditingController searchCtrl;
  final void Function(_Tab) onTabChange;

  const _DesktopSidebar({
    required this.activeTab, required this.todayCount, required this.completedCount,
    required this.total, required this.searchCtrl, required this.onTabChange,
  });

  @override
  Widget build(BuildContext context) => Container(
    width: _kDeskSide,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: kBorder)),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Container(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
        child: Row(children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.people_alt_outlined, color: kPrimary, size: 15),
          ),
          const SizedBox(width: 8),
          const Text('Queue', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: AppExpandableHeaderSearch(
          controller: searchCtrl,
          leadingIcon: Icons.search_rounded,
          title: 'Search',
          subtitle: 'Patients',
          hintText: 'Search patients...',
          height: 36,
          accentColor: kPrimary,
          leadingBackgroundColor: kPrimaryLight,
          titleColor: kTextPrimary,
          subtitleColor: kTextMuted,
          fieldColor: kPageBg,
          borderColor: kBorder,
          iconColor: kTextMuted,
          textColor: kTextPrimary,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(children: [
          _SideNavItem(icon: Icons.access_time_rounded, label: 'Upcoming',
              count: todayCount, selected: activeTab == _Tab.upcoming,
              onTap: () => onTabChange(_Tab.upcoming)),
          const SizedBox(height: 4),
          _SideNavItem(icon: Icons.check_circle_outline_rounded, label: 'Completed',
              count: completedCount, selected: activeTab == _Tab.completed,
              onTap: () => onTabChange(_Tab.completed)),
        ]),
      ),
      const SizedBox(height: 14),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('OVERVIEW', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700,
            letterSpacing: 1.2, color: kTextMuted)),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8, childAspectRatio: 1.4,
          children: [
            _MiniStat('Total',   total,          kPrimary),
            _MiniStat('Waiting', todayCount,     kPrimary),
            _MiniStat('Done',    completedCount, kGreen),
          ],
        ),
      ),
    ]),
  );
}

class _SideNavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _SideNavItem({required this.icon, required this.label,
      required this.count, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? kPrimaryLight : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: const Color(0xFF9FE1CB)) : null,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: selected ? kPrimary : kTextMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            color: selected ? kPrimaryDark : kTextSecondary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? kPrimaryDark : kPrimaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text('$count', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w700,
              color: selected ? Colors.white : kPrimaryDark)),
        ),
      ]),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MiniStat(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kPageBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color, height: 1)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextSecondary)),
    ]),
  );
}

class _DetailPanel extends StatelessWidget {
  final AppointmentList? patient;
  final _Tab tab;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;

  const _DetailPanel({required this.patient, required this.tab,
      required this.onStart, required this.onSkip,
      required this.onPrescription, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    if (patient == null) {
      return Container(
        decoration: const BoxDecoration(
          color: kPageBg, border: Border(left: BorderSide(color: kBorder))),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.person_search_rounded, size: 40, color: kTextMuted),
          SizedBox(height: 10),
          Text('Select a patient',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary)),
          SizedBox(height: 3),
          Text('to view details', style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
    }

    final p      = patient!;
    final isSlot = _isSlotBooking(p);
    final status = p.status?.toLowerCase().trim() ?? '';
    final showStat = _showPatientStatusText(status);
    final (avBg, avBd, avFg) = _avatarPalettes[(p.appointmentId ?? 0) % _avatarPalettes.length];
    final name  = p.patientName ?? 'Patient';
    final inits = name.trim().split(' ').take(2).map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final slotMeta = isSlot ? _slotAppointmentMetaLabel(p.appointmentDate, p.startTime, includeYear: true) : null;

    return Container(
      decoration: const BoxDecoration(
        color: kPageBg, border: Border(left: BorderSide(color: kBorder))),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Container(
            width: 60, height: 60,
            decoration: BoxDecoration(color: avBg, shape: BoxShape.circle, border: Border.all(color: avBd)),
            alignment: Alignment.center,
            child: Text(inits, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: avFg)),
          ),
          const SizedBox(height: 8),
          Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: 2),
          if (p.gender != null) Text(p.gender!, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
          if (!isSlot) ...[
            Container(
              margin: const EdgeInsets.symmetric(vertical: 12),
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: BoxDecoration(
                color: kPrimaryLighter, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kPrimaryLight)),
              width: double.infinity,
              child: Column(children: [
                Text((p.queueNumber ?? 0).toString().padLeft(2, '0'),
                    style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w700, color: kPrimary, height: 1)),
                const SizedBox(height: 3),
                const Text('Token', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ]),
            ),
          ],
          const Divider(height: 1, color: kDivider),
          if (showStat) _DetailRow('Status', _patientStatusLabel(status)),
          if (p.specialization != null) _DetailRow('Specialty', p.specialization!),
          _DetailRow('Date', isSlot && slotMeta != null ? slotMeta : _fmtDateLabel(p.appointmentDate, includeYear: true)),
          _DetailRow('Appt. ID', '${p.appointmentId ?? '--'}'),
          const SizedBox(height: 14),
          if (tab == _Tab.today) ...[
            _PanelBtn(label: 'Start Session', bg: kPrimaryDark, fg: Colors.white, onTap: () => onStart(p)),
            const SizedBox(height: 8),
            _PanelBtn(label: 'Skip', bg: kRedLight, fg: kRedDark, border: kRedBorder, onTap: () => onSkip(p)),
          ] else if (tab == _Tab.upcoming)
            _PanelBtn(label: 'Cancel', bg: kRedLight, fg: kRedDark, border: kRedBorder, onTap: () => onCancel(p))
          else
            _PanelBtn(label: 'View Prescription', bg: kPurpleLight, fg: kPurpleDark, border: kPurpleBorder, onTap: () => onPrescription(p)),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SHARED SMALL WIDGETS
// ═════════════════════════════════════════════════════════════════════════════

class _DateGroupHeader extends StatelessWidget {
  final String dateStr;
  final int count;
  const _DateGroupHeader({required this.dateStr, required this.count});

  @override
  Widget build(BuildContext context) {
    final d   = DateTime.tryParse(dateStr);
    final now = DateTime.now();
    final isToday    = d != null && d.year == now.year && d.month == now.month && d.day == now.day;
    final isTomorrow = d != null && DateTime(d.year, d.month, d.day) ==
        DateTime(now.year, now.month, now.day + 1);

    final label = d == null
        ? dateStr
        : isToday
            ? 'Today, ${DateFormat('d MMMM yyyy').format(d)}'
            : isTomorrow
                ? 'Tomorrow, ${DateFormat('d MMMM yyyy').format(d)}'
                : DateFormat('EEEE, d MMMM yyyy').format(d);

    final barColor = isToday ? kPrimary : isTomorrow ? kAmber : kTextMuted;
    final textColor = isToday ? kPrimary : isTomorrow ? kAmberDark : kTextPrimary;
    final badgeBg  = isToday ? kPrimaryLight : isTomorrow ? kAmberLight : const Color(0xFFF1F5F9);
    final badgeFg  = isToday ? kPrimaryDark  : isTomorrow ? kAmberDark  : kTextSecondary;

    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
      child: Row(children: [
        Container(
          width: 3, height: 14,
          decoration: BoxDecoration(color: barColor, borderRadius: BorderRadius.circular(4)),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(label,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: textColor)),
        ),
        const SizedBox(width: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(color: badgeBg, borderRadius: BorderRadius.circular(20)),
          child: Text('$count',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: badgeFg)),
        ),
      ]),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? badge;
  const _SectionHeader({required this.title, this.badge});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Row(children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      ]),
      if (badge != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF9FE1CB))),
          child: Text(badge!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryDark)),
        ),
    ]),
  );
}

class _QueueStateBadge extends StatelessWidget {
  final QueueState state;
  const _QueueStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color dot, String label) = switch (state) {
      QueueState.running => (kPrimaryLight, kPrimaryDark, kPrimary, 'Running'),
      QueueState.paused  => (kAmberLight,   kAmberDark,   kAmber,   'Paused'),
      QueueState.stopped => (const Color(0xFFF1F5F9), kTextSecondary, kTextMuted, 'Closed'),
      QueueState.idle    => (kRedLight,      kRedDark,     kRed,     'Idle'),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg)),
      ]),
    );
  }
}

class _QueueIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg, border;
  final String tooltip;
  final VoidCallback? onTap;
  const _QueueIconBtn({required this.icon, required this.color, required this.bg,
      required this.border, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    preferBelow: false,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28, height: 28,
        decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border)),
        alignment: Alignment.center,
        child: Icon(icon, size: 15, color: color),
      ),
    ),
  );
}

class _TokBox extends StatelessWidget {
  final String label, value;
  final bool isActive, isGreen;
  const _TokBox({required this.label, required this.value, this.isActive = false, this.isGreen = false});

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        color: isActive ? kPrimaryDark : isGreen ? kGreenLight : kPrimaryLighter,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? null : Border.all(color: isGreen ? kGreenBorder : kPrimaryLight),
      ),
      child: Column(children: [
        Text(label, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: .7,
            color: isActive ? Colors.white.withOpacity(0.75) : isGreen ? kGreenDark : kTextSecondary)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1,
            color: isActive ? Colors.white : isGreen ? kGreenDark : kTextPrimary)),
      ]),
    ),
  );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6),
        border: Border.all(color: fg.withOpacity(0.25))),
    child: Text(label, style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.2)),
  );
}

class _DotChip extends StatelessWidget {
  final String label;
  final Color bg, fg, dot;
  const _DotChip({required this.label, required this.bg, required this.fg, required this.dot});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20),
        border: Border.all(color: dot.withOpacity(0.25))),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.2)),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final Color? border;
  final VoidCallback? onTap;
  const _ActionBtn({required this.label, required this.bg, required this.fg, this.border, required this.onTap});

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap != null ? 1.0 : 0.4,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border != null ? Border.all(color: border!) : null,
        ),
        alignment: Alignment.center,
        child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fg, letterSpacing: 0.1)),
      ),
    ),
  );
}

class _PanelBtn extends StatelessWidget {
  final String label;
  final Color bg, fg;
  final Color? border;
  final VoidCallback onTap;
  const _PanelBtn({required this.label, required this.bg, required this.fg, this.border, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(10),
        border: border != null ? Border.all(color: border!) : null,
      ),
      alignment: Alignment.center,
      child: Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: fg)),
    ),
  );
}

class _DetailRow extends StatelessWidget {
  final String k, v;
  const _DetailRow(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
      Flexible(child: Text(v, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
          textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
    ]),
  );
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .35, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: Container(width: 7, height: 7, decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle)),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// PILL TAB BAR
// ═════════════════════════════════════════════════════════════════════════════
class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final int todayCount, completedCount;
  const _PillTabBar({required this.controller, required this.todayCount, required this.completedCount});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
    child: Container(
      height: 46,
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kHairline),
      ),
      child: TabBar(
        controller: controller,
        labelColor: Colors.white,
        unselectedLabelColor: kTextSecondary,
        indicatorSize: TabBarIndicatorSize.tab,
        indicator: BoxDecoration(color: kPrimaryDark, borderRadius: BorderRadius.circular(17)),
        indicatorPadding: const EdgeInsets.all(3),
        labelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, letterSpacing: 0.1),
        unselectedLabelStyle: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
        dividerColor: Colors.transparent,
        splashFactory: NoSplash.splashFactory,
        overlayColor: WidgetStateProperty.all(Colors.transparent),
        tabs: [
          Tab(text: 'Upcoming ($todayCount)'),
          Tab(text: 'Completed ($completedCount)'),
        ],
      ),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// EMPTY / ERROR / SKELETON
// ═════════════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final _Tab tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9FE1CB))),
        child: const Icon(Icons.person_search_rounded, size: 26, color: kPrimaryDark),
      ),
      const SizedBox(height: 12),
      Text(
        switch (tab) {
          _Tab.today     => 'No patients today',
          _Tab.upcoming  => 'No upcoming appointments',
          _Tab.completed => 'No completed appointments',
        },
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary),
      ),
      const SizedBox(height: 4),
      const Text('Pull down to refresh', style: TextStyle(fontSize: 12, color: kTextMuted)),
    ]),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 56, height: 56,
        decoration: BoxDecoration(color: kRedLight, shape: BoxShape.circle, border: Border.all(color: kRedBorder)),
        child: const Icon(Icons.wifi_off_rounded, color: kRed, size: 24),
      ),
      const SizedBox(height: 12),
      const Text('Failed to load appointments',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(height: 4),
      const Text('Check your connection and try again',
          style: TextStyle(fontSize: 12, color: kTextMuted)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryDark, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

class _SkeletonPatientList extends StatelessWidget {
  const _SkeletonPatientList();

  @override
  Widget build(BuildContext context) => Column(children: [
    Container(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Container(
          height: 46,
          decoration: BoxDecoration(
            color: const Color(0xFFF0F5F3),
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(4),
          child: const Row(children: [
            Expanded(child: _Shimmer(width: double.infinity, height: double.infinity, radius: 17)),
            SizedBox(width: 4),
            Expanded(child: _Shimmer(width: double.infinity, height: double.infinity, radius: 17)),
          ]),
        ),
      ),
    ),
    Expanded(
      child: ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 80),
        children: const [
          _Shimmer(width: double.infinity, height: 180, radius: 14),
          SizedBox(height: 12),
          _Shimmer(width: double.infinity, height: 100, radius: 12),
          SizedBox(height: 10),
          _Shimmer(width: double.infinity, height: 100, radius: 12),
        ],
      ),
    ),
  ]);
}

class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer({required this.width, required this.height, this.radius = 6});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))..repeat(reverse: true);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut)),
    child: Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(color: const Color(0xFFE2E8F0), borderRadius: BorderRadius.circular(widget.radius)),
    ),
  );
}

// ═════════════════════════════════════════════════════════════════════════════
// DATE FILTER BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _PatientDateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom, customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

  const _PatientDateFilterSheet({
    required this.current, required this.customFrom,
    required this.customTo, required this.sortNewest, required this.onApply,
  });

  @override
  State<_PatientDateFilterSheet> createState() => _PatientDateFilterSheetState();
}

class _PatientDateFilterSheetState extends State<_PatientDateFilterSheet> {
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
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Center(child: Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 36, height: 4,
          decoration: BoxDecoration(color: kBorder, borderRadius: BorderRadius.circular(2)),
        )),
        Row(children: [
          const Text('Filter by Date',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const Spacer(),
          TextButton(
            onPressed: () => setState(() { _sel = _DateFilter.all; _from = null; _to = null; _newest = true; }),
            child: const Text('Reset', style: TextStyle(color: kRed, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ]),
        const SizedBox(height: 8),
        Wrap(
          spacing: 7, runSpacing: 7,
          children: _DateFilter.values.where((f) => f != _DateFilter.custom).map((f) {
            final sel = _sel == f;
            return GestureDetector(
              onTap: () => setState(() => _sel = f),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
                decoration: BoxDecoration(
                  color: sel ? kPrimaryDark : kPageBg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: sel ? kPrimaryDark : kBorder, width: sel ? 1.5 : 1),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(f.icon, color: sel ? Colors.white : kTextMuted, size: 12),
                  const SizedBox(width: 5),
                  Text(f.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                      color: sel ? Colors.white : kTextSecondary)),
                ]),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
        GestureDetector(
          onTap: () => setState(() => _sel = _DateFilter.custom),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _sel == _DateFilter.custom ? kPrimaryLight : kPageBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _sel == _DateFilter.custom ? kPrimary : kBorder,
                width: _sel == _DateFilter.custom ? 1.5 : 1),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Icon(Icons.tune_rounded,
                    color: _sel == _DateFilter.custom ? kPrimary : kTextMuted, size: 15),
                const SizedBox(width: 7),
                Text('Custom Date Range', style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600,
                    color: _sel == _DateFilter.custom ? kPrimary : kTextMuted)),
              ]),
              if (_sel == _DateFilter.custom) ...[
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(child: _datePick('From', _from, () => _pick(true))),
                  const SizedBox(width: 8),
                  Expanded(child: _datePick('To', _to, () => _pick(false))),
                ]),
              ],
            ]),
          ),
        ),
        const SizedBox(height: 14),
        const Text('Sort Order',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _sortBtn('Newest First', Icons.arrow_downward_rounded, _newest, () => setState(() => _newest = true))),
          const SizedBox(width: 8),
          Expanded(child: _sortBtn('Oldest First', Icons.arrow_upward_rounded, !_newest, () => setState(() => _newest = false))),
        ]),
        const SizedBox(height: 16),
        SizedBox(
          width: double.infinity, height: 46,
          child: ElevatedButton(
            onPressed: () { widget.onApply(_sel, _from, _to, _newest); Navigator.pop(context); },
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryDark, foregroundColor: Colors.white, elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Apply Filter', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }

  Widget _datePick(String label, DateTime? val, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: kBorder)),
      child: Row(children: [
        const Icon(Icons.calendar_today_rounded, color: kPrimary, size: 13),
        const SizedBox(width: 7),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: const TextStyle(fontSize: 10, color: kTextMuted)),
          Text(val != null ? _fmt(val) : 'Select',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: val != null ? kTextPrimary : kTextMuted)),
        ]),
      ]),
    ),
  );

  Widget _sortBtn(String label, IconData icon, bool sel, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: sel ? kPrimaryDark : kPageBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sel ? kPrimaryDark : kBorder),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Icon(icon, color: sel ? Colors.white : kTextMuted, size: 14),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
            color: sel ? Colors.white : kTextSecondary)),
      ]),
    ),
  );
}