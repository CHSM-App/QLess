import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

const kPrimary        = Color(0xFF26C6B0);
const kPrimaryDark    = Color(0xFF2BB5A0);
const kPrimaryLight   = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);
const _kGradFrom      = Color(0xFF4DD9C8);
const _kGradTo        = Color(0xFF2BB5A0);

const kTextPrimary    = Color(0xFF2D3748);
const kTextSecondary  = Color(0xFF718096);
const kTextMuted      = Color(0xFFA0AEC0);

const kBorder         = Color(0xFFEDF2F7);
const kDivider        = Color(0xFFE5E7EB);
const kBg             = Color(0xFFF7F8FA);

const kSuccess        = Color(0xFF68D391);
const kGreenLight     = Color(0xFFDCFCE7);
const kGreenBorder    = Color(0xFFC6F6D5);
const kGreenDark      = Color(0xFF276749);

const kWarning        = Color(0xFFF6AD55);
const kAmberLight     = Color(0xFFFEF3C7);
const kAmberBorder    = Color(0xFFFCEFC7);
const kAmberDark      = Color(0xFF975A16);

const kError          = Color(0xFFFC8181);
const kRedLight       = Color(0xFFFEE2E2);
const kRedBorder      = Color(0xFFFED7D7);
const kRedDark        = Color(0xFFC53030);

const kPurple         = Color(0xFF9F7AEA);
const kPurpleLight    = Color(0xFFEDE9FE);
const kPurpleBorder   = Color(0xFFE9D5FF);
const kPurpleDark     = Color(0xFF6B46C1);

const kInfo           = Color(0xFF3B82F6);
const kInfoLight      = Color(0xFFDBEAFE);
const kInfoDark       = Color(0xFF1E40AF);

// ── Premium medical surface tokens (matched to home_screen) ─────────────────
const kHairline       = Color(0xFFE8EEF1);
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [_kGradFrom, _kGradTo],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient kCardGlassGradient = LinearGradient(
  colors: [Colors.white, Color(0xFFFBFEFD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

const _kBottomClear = 100.0;
const _kWideBreak   = 800.0;
const _kDeskSide    = 240.0;
const _kDeskDetail  = 270.0;

const _avatarPalette = [
  (bg: Color(0xFFE0F5F1), fg: Color(0xFF2BB5A0)),
  (bg: Color(0xFFEDE9FE), fg: Color(0xFF6B46C1)),
  (bg: Color(0xFFFEF3C7), fg: Color(0xFF975A16)),
  (bg: Color(0xFFDBEAFE), fg: Color(0xFF1E40AF)),
  (bg: Color(0xFFFEE2E2), fg: Color(0xFFC53030)),
  (bg: Color(0xFFDCFCE7), fg: Color(0xFF276749)),
];

enum _Tab { today, upcoming, completed }

String _fmtTime(String? raw) {
  if (raw == null) return '';
  final value = raw.trim();
  if (value.isEmpty || value == '--' || value.toLowerCase() == 'null') {
    return '';
  }
  try {
    return DateFormat('h:mm a').format(DateTime.parse(value).toUtc());
  } catch (_) {
    return value;
  }
}

String? _slotTimeLabel(String? startTime, String? endTime) {
  final startLabel = _fmtTime(startTime);
  final endLabel = _fmtTime(endTime);
  if (startLabel.isEmpty && endLabel.isEmpty) return null;
  if (startLabel.isEmpty) return endLabel;
  if (endLabel.isEmpty) return startLabel;
  return '$startLabel - $endLabel';
}

bool _isSlotBooking(AppointmentList appointment) => appointment.bookingType == 2;

String _fmtDateLabel(String? raw, {bool includeYear = false}) {
  if (raw == null) return '--';
  final d = DateTime.tryParse(raw);
  if (d == null) return raw;
  const mo = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  return includeYear ? '${d.day} ${mo[d.month - 1]} ${d.year}' : '${d.day} ${mo[d.month - 1]}';
}

String _appointmentDateLabel(
  String? appointmentDate,
  String? startTime, {
  bool includeYear = false,
}) {
  final dateLabel = _fmtDateLabel(appointmentDate, includeYear: includeYear);
  final timeLabel = _fmtTime(startTime);
  if (timeLabel.isEmpty) return dateLabel;
  if (dateLabel == '--') return timeLabel;
  return '$dateLabel | $timeLabel';
}

String? _slotAppointmentMetaLabel(
  String? appointmentDate,
  String? startTime, {
  bool includeYear = false,
}) {
  final label = _appointmentDateLabel(
    appointmentDate,
    startTime,
    includeYear: includeYear,
  );
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

// ════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════════════════════════
class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

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
  _Tab _activeTab = _Tab.today;

  // Per-tab filter state. Upcoming defaults to "All Time"; the Completed
  // (Current Complete Queue) tab defaults to "Today" so it opens showing only
  // today's completed. Both tabs' lists are computed every build, so they read
  // their own backing fields directly — the routed getters/setters below are
  // only for the shared filter UI, which always acts on the active tab.
  _DateFilter _upcomingFilter = _DateFilter.all;
  DateTime?   _upcomingFrom;
  DateTime?   _upcomingTo;
  bool        _upcomingSortNewest = true;

  _DateFilter _completedFilter = _DateFilter.today;
  DateTime?   _completedFrom;
  DateTime?   _completedTo;
  bool        _completedSortNewest = true;

  bool get _onCompletedTab => _activeTab == _Tab.completed;

  _DateFilter get _dateFilter =>
      _onCompletedTab ? _completedFilter : _upcomingFilter;
  set _dateFilter(_DateFilter v) =>
      _onCompletedTab ? _completedFilter = v : _upcomingFilter = v;

  DateTime? get _customFrom => _onCompletedTab ? _completedFrom : _upcomingFrom;
  set _customFrom(DateTime? v) =>
      _onCompletedTab ? _completedFrom = v : _upcomingFrom = v;

  DateTime? get _customTo => _onCompletedTab ? _completedTo : _upcomingTo;
  set _customTo(DateTime? v) =>
      _onCompletedTab ? _completedTo = v : _upcomingTo = v;

  bool get _sortNewest =>
      _onCompletedTab ? _completedSortNewest : _upcomingSortNewest;
  set _sortNewest(bool v) =>
      _onCompletedTab ? _completedSortNewest = v : _upcomingSortNewest = v;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _tabCtrl.addListener(() {
      if (!_tabCtrl.indexIsChanging) return;
      setState(() {
        _activeTab = _Tab.values[_tabCtrl.index];
        _selected  = null;
      });
    });
    _searchCtrl.addListener(
      () => setState(() => _query = _searchCtrl.text.toLowerCase()),
    );
    _idSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) { if (next != null && next > 0) _refresh(force: false); },
    );
    WidgetsBinding.instance.addPostFrameCallback(
      (_) { if (mounted) _refresh(force: false); },
    );
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _idSub.close();
    super.dispose();
  }

  int get _doctorId => ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

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
          content: Row(children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg,
                style: const TextStyle(fontSize: 13, color: Colors.white))),
          ]),
          backgroundColor: isError ? kError : kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          duration: const Duration(seconds: 2),
        ),
      );

  // A scheduled time as a UTC instant, parsed exactly the way _fmtTime()
  // formats it so the guard matches the time shown on the card.
  DateTime? _instantOf(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
    try {
      return DateTime.parse(v).toUtc();
    } catch (_) {
      return null;
    }
  }

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = _doctorId;
    if (pid == 0 || did == 0) { _snack('Missing info', isError: true); return; }

    // ── Slot-time guard ──────────────────────────────────────────────
    // A fresh ('booked') session can't be started before its scheduled
    // slot/queue time. 'in_progress' (Continue) and 'skipped' (recall)
    // are intentionally exempt — those flows are already underway.
    final status = p.status?.toLowerCase() ?? '';

    // ── Continue (already in_progress) ───────────────────────────────
    // This patient's session is already running — 'Continue' just reopens
    // the consult screen. START_SESSION would reject in_progress, so skip
    // the backend call entirely and go straight to the prescription screen.
    if (status != 'in_progress') {
      // ── Slot-time guard ────────────────────────────────────────────
      // A fresh ('booked') session can't be started before its scheduled
      // slot/queue time. 'skipped' (recall) is exempt — already underway.
      if (status == 'booked') {
        final slotStart = _instantOf(p.startTime);
        if (slotStart != null &&
            DateTime.now().toUtc().isBefore(slotStart)) {
          _snack(
            'Scheduled for ${_fmtTime(p.startTime)} — you can start once the slot time begins.',
            isError: true,
          );
          return;
        }
      }

      try {
        final res = await ref.read(appointmentViewModelProvider.notifier).startSession(
          AppointmentRequestModel(
            doctorId: did, patientId: pid, appointmentId: p.appointmentId ?? 0,
          ),
        );
        if (!mounted) return;
        // Backend blocks starting a session while another patient is still
        // in_progress (returns success=false). Surface that message here and
        // do NOT open the prescription screen.
        if (res.success != true) {
          _snack(res.message ?? 'Could not start session', isError: true);
          return;
        }
      } catch (e) {
        if (mounted) _snack('Failed to start session: $e', isError: true);
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
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
        ),
      ),
    );
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
          patientId: p.patientId ?? 0,
          isNext: 0,
        ),
      );
      if (!mounted) return;
      if (res.success == true) {
        // VM.queueSkip already refetched the list+queue — no extra call here.
        _snack(res.message ?? 'Patient skipped');
      } else {
        _snack(res.message ?? 'Skip failed', isError: true);
      }
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
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).cancelByDoctor(
        AppointmentRequestModel(
          doctorId: did,
          appointmentId: p.appointmentId ?? 0,
        ),
      );
      if (!mounted) return;
      if (res.success == true) {
        // VM.cancelByDoctor already refetched the list+queue — no extra call.
        _snack(res.message ?? 'Appointment cancelled');
      } else {
        _snack(res.message ?? 'Cancel failed', isError: true);
      }
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
            child: const Icon(Icons.cancel_outlined, color: kError, size: 22),
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
              child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _cancelByDoctor(p); },
              style: ElevatedButton.styleFrom(
                backgroundColor: kError, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('Yes, Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    ),
  );

  void _viewPatientInfo(AppointmentList p) {
    final av = _avatarPalette[(p.appointmentId ?? 0) % _avatarPalette.length];
    final name = p.patientName ?? 'Patient';
    final inits = name.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    final isSlot = _isSlotBooking(p);
    final slotMeta = isSlot
        ? _slotAppointmentMetaLabel(p.appointmentDate, p.startTime, includeYear: true)
        : null;

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
              decoration: BoxDecoration(color: av.bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(inits,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: av.fg)),
            ),
            const SizedBox(height: 10),
            Text(name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary),
                textAlign: TextAlign.center),
            if (p.gender != null || p.dob != null) ...[
              const SizedBox(height: 4),
              Text(
                [if (p.gender != null) p.gender!, if (_ageStr(p.dob) != null) _ageStr(p.dob)!]
                    .join(' | '),
                style: const TextStyle(fontSize: 12, color: kTextSecondary),
              ),
            ],
            const SizedBox(height: 14),
            const Divider(height: 1, color: kDivider),
            _DetailRow('Status',
                (p.status ?? 'Unknown')[0].toUpperCase() +
                    (p.status ?? 'unknown').substring(1).replaceAll('_', ' ')),
            if (p.specialization != null) _DetailRow('Specialty', p.specialization!),
            _DetailRow(
              'Date',
              isSlot && slotMeta != null
                  ? slotMeta
                  : _fmtDateLabel(p.appointmentDate, includeYear: true),
            ),
            if (!isSlot)
              _DetailRow('Token', (p.queueNumber ?? 0).toString().padLeft(2, '0')),
            _DetailRow('Appointment ID', '${p.appointmentId ?? '--'}'),
            if (p.symptoms != null && p.symptoms!.isNotEmpty)
              _DetailRow('Symptoms', p.symptoms!),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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

  Future<void> _onQueueStart(int? queueId) async {
    // ── Slot-time guard ──────────────────────────────────────────────
    // Don't allow the queue session to be started before its slot time.
    final sessions =
        ref.read(appointmentViewModelProvider).todayQueueResult?.value ??
            const [];
    String? rawStart;
    for (final dynamic s in sessions) {
      if (s.queueId == queueId) {
        rawStart = s.startTime as String?;
        break;
      }
    }
    final slotStart = _instantOf(rawStart);
    if (slotStart != null && DateTime.now().toUtc().isBefore(slotStart)) {
      _snack(
        'Queue starts at ${_fmtTime(rawStart)} — please wait until the slot time begins.',
        isError: true,
      );
      return;
    }

    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue started');
      // VM.queueStart already refetched the list+queue — no extra call here.
    } catch (_) {
      _snack('Failed to start queue', isError: true);
    }
  }

  Future<void> _onQueuePause(int? queueId) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
      // VM.queuePause already refetched the list+queue — no extra call here.
    } catch (_) {
      _snack('Failed to pause queue', isError: true);
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
    // Compute patients that will be cancelled on stop:
    //   • queue's own pending (booked / in_progress)
    //   • earlier-time slot patients still pending (booked / skipped)
    final vmState     = ref.read(appointmentViewModelProvider);
    final allPatients = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final sessions    = vmState.todayQueueResult?.value ?? [];

    final matchingSession = sessions.where((s) => s.queueId == queueId).toList();
    final queueStartTime  = matchingSession.isEmpty
        ? null
        : DateTime.tryParse(matchingSession.first.startTime ?? '');

    final queuePending = allPatients.where((p) {
      if (p.queueId != queueId) return false;
      final st = (p.status?.toLowerCase() ?? '');
      return st == 'booked' || st == 'in_progress';
    }).length;

    final queueSkipped = allPatients.where((p) {
      if (p.queueId != queueId) return false;
      return (p.status?.toLowerCase() ?? '') == 'skipped';
    }).length;

    final earlierSlotPatients = queueStartTime == null
        ? <AppointmentList>[]
        : allPatients.where((p) {
            if (p.bookingType != 2) return false;
            final st = (p.status?.toLowerCase() ?? '');
            if (st != 'booked' && st != 'skipped') return false;
            final pTime = DateTime.tryParse(p.startTime ?? '');
            return pTime != null && pTime.isBefore(queueStartTime);
          }).toList();
    final earlierSlotPending = earlierSlotPatients.length;

    final totalCancel = queuePending + earlierSlotPending + queueSkipped;

    final confirmed = await showDialog<bool>(
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
              child: const Icon(Icons.stop_circle_outlined, color: kError, size: 22),
            ),
            const SizedBox(height: 12),
            const Text('Close Queue?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text('Are you sure you want to close this queue?',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
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
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(
                        '$totalCancel patient${totalCancel == 1 ? '' : 's'} will be cancelled',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700, color: kAmberDark),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (queuePending > 0) '$queuePending pending in this queue',
                          if (queueSkipped > 0) '$queueSkipped skipped in this queue',
                          if (earlierSlotPending > 0) '$earlierSlotPending from earlier slots',
                        ].join(' · '),
                        style: const TextStyle(fontSize: 11, color: kAmberDark, height: 1.3),
                      ),
                    ]),
                  ),
                ]),
              ),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton(
                onPressed: () => Navigator.pop(ctx, false),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kBorder),
                  foregroundColor: kTextSecondary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: kError, foregroundColor: Colors.white, elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: const Text('Yes, Close', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              )),
            ]),
          ]),
        ),
      ),
    );
    if (confirmed != true) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue closed');
      // VM.queueStop already refetched the list+queue — no extra call here.
    } catch (_) {
      _snack('Failed to close queue', isError: true);
    }
  }

  // Emergency pause — same behaviour as the home screen. Confirmation is
  // handled in [_showEmergencyDialog]; this just fires the call.
  Future<void> _onQueueEmergency(int? queueId) async {
    if (queueId == null) {
      _snack('Queue ID not available', isError: true);
      return;
    }
    if (ref.read(appointmentViewModelProvider.notifier)
        .isEmergencyPaused(queueId)) {
      _snack('Already emergency paused');
      return;
    }
    final confirmed = await _showEmergencyDialog();
    if (confirmed != true) return;
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queuePauseEmergency(queueId);
      _snack(res.message ?? 'Queue paused (emergency)');
      // VM already refetched the list+queue — no extra call here.
    } catch (_) {
      _snack('Failed to pause queue', isError: true);
    }
  }

  Future<bool?> _showEmergencyDialog() {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                  color: kPurpleLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: kPurpleBorder)),
              child: const Icon(Icons.warning_amber_rounded,
                  color: kPurple, size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'Emergency Pause?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Queue is Emergency Pause. Do you want to pause immediately?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.5),
            ),
            const SizedBox(height: 4),
          ],
        ),
        actions: [
          Row(children: [
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, false),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.center,
                  child: const Text('No',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextSecondary)),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: GestureDetector(
                onTap: () => Navigator.pop(ctx, true),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: kPurpleLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kPurpleBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Yes, Pause',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kPurpleDark)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isWide      = MediaQuery.of(context).size.width >= _kWideBreak;
    final vmState     = ref.watch(appointmentViewModelProvider);
    final async       = vmState.patientAppointmentsList;
    final qs          = vmState.queueState;
    final allSessions = vmState.todayQueueResult?.value ?? [];

    return Scaffold(
      backgroundColor: Colors.white,
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
                  ? _buildDesktop(
                      today: today, upcoming: upcoming, completed: completed,
                      qs: qs, allSessions: allSessions, allAppointments: all)
                  : _buildMobile(
                      today: today, upcoming: upcoming, completed: completed,
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

  Widget _filterChip({
    required IconData icon,
    required String label,
    required VoidCallback onRemove,
    Color color = kPrimary,
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
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
          const SizedBox(width: 5),
          GestureDetector(
            onTap: onRemove,
            child: Icon(Icons.close_rounded, color: color, size: 12),
          ),
        ]),
      );

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
              child: Row(
                children: [
                  Expanded(
                    child: AppExpandableHeaderSearch(
                      controller: _searchCtrl,
                      leadingIcon: Icons.people_alt_outlined,
                      alwaysShowLeadingIcon: true,
                      title: 'Patients',
                      subtitle: 'Manage your patient queue',
                      hintText: 'Search by name, status or queue...',
                      accentColor: kPrimary,
                      leadingBackgroundColor: kPrimaryLight,
                      titleColor: kTextPrimary,
                      subtitleColor: kTextSecondary,
                      fieldColor: kBg,
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
                      width: 40, height: 40,
                      decoration: BoxDecoration(
                        color: _hasDateFilter ? kPrimary : const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _hasDateFilter ? kPrimary : kBorder),
                      ),
                      child: Icon(Icons.tune_rounded,
                          color: _hasDateFilter ? Colors.white : kPrimary, size: 18),
                    ),
                  ),
                ],
                ],
              ),
            ),
            if (_hasDateFilter)
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                child: Wrap(
                  spacing: 6, runSpacing: 6,
                  children: [
                    if (_dateFilter != _DateFilter.all)
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
          ],
        ),
      ),
    );
  }

  Widget _buildMobile({
    required List<AppointmentList> today,
    required List<AppointmentList> upcoming,
    required List<AppointmentList> completed,
    required QueueState qs,
    required List<dynamic> allSessions,
    required List<AppointmentList> allAppointments,
  }) {
    return Column(children: [
      _PillTabBar(
        controller: _tabCtrl,
        todayCount: today.length,
        upcomingCount: upcoming.length,
        completedCount: completed.length,
      ),
      Expanded(
        child: TabBarView(
          controller: _tabCtrl,
          children: [
            _SessionGroupedBody(
              allSessions: allSessions,
              allAppointments: allAppointments,
              todayPatients: today,
              qs: qs,
              onStart: _startSession,
              onSkip: _skipPatient,
              onPrescription: _viewPrescription,
              onCancel: _cancelConfirm,
              extraBottom: _kBottomClear,
              onQueueStart: _onQueueStart,
              onQueuePause: _onQueuePause,
              onQueueStop: _onQueueStop,
              onQueueEmergency: _onQueueEmergency,
              emergencyQueueIds:
                  ref.watch(appointmentViewModelProvider).emergencyQueueIds,
              onRefresh: () async {
                ref.read(appointmentViewModelProvider.notifier)
                    .fetchPatientAppointments(_doctorId);
                await Future.delayed(const Duration(milliseconds: 600));
              },
            ),
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
        ),
      ),
    ]);
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
        todayCount: today.length,
        upcomingCount: upcoming.length,
        completedCount: completed.length,
        total: today.length + upcoming.length + completed.length,
        searchCtrl: _searchCtrl,
        onTabChange: (t) => setState(() {
          _activeTab = t;
          _selected  = null;
          _tabCtrl.animateTo(_Tab.values.indexOf(t));
        }),
      ),
      Expanded(
        child: _activeTab == _Tab.today
            ? _SessionGroupedBody(
                allSessions: allSessions,
                allAppointments: allAppointments,
                todayPatients: today,
                qs: qs,
                onStart: _startSession,
                onSkip: _skipPatient,
                onPrescription: _viewPrescription,
                onCancel: _cancelConfirm,
                extraBottom: 0,
                selected: _selected,
                onSelect: (p) => setState(() => _selected = p),
                onQueueStart: _onQueueStart,
                onQueuePause: _onQueuePause,
                onQueueStop: _onQueueStop,
                onQueueEmergency: _onQueueEmergency,
                emergencyQueueIds:
                    ref.watch(appointmentViewModelProvider).emergencyQueueIds,
                onRefresh: () async {
                  ref.read(appointmentViewModelProvider.notifier)
                      .fetchPatientAppointments(_doctorId);
                  await Future.delayed(const Duration(milliseconds: 600));
                },
              )
            : _PatientListBody(
                patients: list, tab: _activeTab, qs: qs,
                onStart: _startSession, onSkip: _skipPatient,
                onPrescription: _viewPrescription, onCancel: _cancelConfirm,
                onView: _activeTab == _Tab.upcoming ? _viewPatientInfo : null,
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

// ════════════════════════════════════════════════════════════════════
//  SESSION-GROUPED BODY
// ════════════════════════════════════════════════════════════════════
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
  final Map<int, bool> _slotGroupExpanded = {};

  bool _shouldShow(dynamic session) {
    final qs      = session.queueStatus ?? 0;
    final hasSlot = _slotTimeLabel(
          session.startTime as String?,
          session.endTime as String?,
        ) !=
        null;
    if (qs == 3) return false;
    if (qs == 0 && !hasSlot) return false;
    return true;
  }

  // Build ordered list of items: slot groups (with their sessions inside)
  // then ungrouped sessions, then slot-booking patients section.
  //
  // A "slot group" = all sessions sharing the same non-null slotId.
  // Sessions whose session.slotId is null are rendered as standalone accordions.
  List<_ListItem> _buildItems(List<dynamic> visibleSessions) {
    final items = <_ListItem>[];
    final seenSlotIds = <int>{};

    for (int i = 0; i < visibleSessions.length; i++) {
      final session = visibleSessions[i];
      final slotId  = session.slotId as int?;

      if (slotId != null) {
        if (!seenSlotIds.contains(slotId)) {
          seenSlotIds.add(slotId);
          final groupSessions = visibleSessions
              .where((s) => (s.slotId as int?) == slotId)
              .toList();
          items.add(_SlotGroupItem(slotId: slotId, sessions: groupSessions));
        }
        // already added as part of a group — skip
      } else {
        items.add(_StandaloneSessionItem(session: session, globalIndex: i));
      }
    }

    return items;
  }

  // Group slot-booking patients by slotId, preserving insertion order of slotIds.
  // Patients with no slotId go into a single null-keyed group.
  List<({int? slotId, List<AppointmentList> patients})> _groupSlotPatients(
      List<AppointmentList> slotPatients) {
    final order = <int?>[];
    final map   = <int?, List<AppointmentList>>{};
    for (final p in slotPatients) {
      final key = p.slotId;
      if (!map.containsKey(key)) {
        order.add(key);
        map[key] = [];
      }
      map[key]!.add(p);
    }
    return order.map((k) => (slotId: k, patients: map[k]!)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final visibleSessions = widget.allSessions.where(_shouldShow).toList()
      ..sort((a, b) {
        final aTime = DateTime.tryParse(a.startTime as String? ?? '');
        final bTime = DateTime.tryParse(b.startTime as String? ?? '');
        if (aTime == null && bTime == null) return 0;
        if (aTime == null) return 1;
        if (bTime == null) return -1;
        return aTime.compareTo(bTime);
      });

    final slotPatients = widget.todayPatients
        .where((p) => p.bookingType == 2)
        .toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

    final slotGroups = _groupSlotPatients(slotPatients);

    if (visibleSessions.isEmpty && slotPatients.isEmpty) {
      return _PatientListBody(
        patients: widget.todayPatients,
        tab: _Tab.today,
        qs: widget.qs,
        onStart: widget.onStart,
        onSkip: widget.onSkip,
        onPrescription: widget.onPrescription,
        onCancel: widget.onCancel,
        extraBottom: widget.extraBottom,
        selected: widget.selected,
        onSelect: widget.onSelect,
      );
    }

    final queueItems = _buildItems(visibleSessions);

    // Merge queue items and slot-booking groups, then sort by earliest startTime
    // so cards render in chronological order regardless of source type.
    final unified = <Object>[...queueItems, ...slotGroups];

    DateTime? startTimeOf(Object obj) {
      if (obj is _StandaloneSessionItem) {
        return DateTime.tryParse(obj.session.startTime as String? ?? '');
      }
      if (obj is _SlotGroupItem) {
        DateTime? earliest;
        for (final s in obj.sessions) {
          final t = DateTime.tryParse(s.startTime as String? ?? '');
          if (t != null && (earliest == null || t.isBefore(earliest))) earliest = t;
        }
        return earliest;
      }
      final g = obj as ({int? slotId, List<AppointmentList> patients});
      if (g.patients.isEmpty) return null;
      return DateTime.tryParse(g.patients.first.startTime ?? '');
    }

    unified.sort((a, b) {
      final aT = startTimeOf(a);
      final bT = startTimeOf(b);
      if (aT == null && bT == null) return 0;
      if (aT == null) return 1;
      if (bT == null) return -1;
      return aT.compareTo(bT);
    });

    // Index of the first queue item (slot bookings don't participate in lock chain)
    final firstQueueIdx = unified.indexWhere((obj) => obj is _ListItem);

    return RefreshIndicator(
      color: kPrimary,
      strokeWidth: 2.5,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + widget.extraBottom),
        itemCount: unified.length,
        itemBuilder: (_, i) {
          final obj = unified[i];

          if (obj is _SlotGroupItem) {
            final isGroupExpanded = _slotGroupExpanded[obj.slotId] ?? true;
            return _QueueSlotSection(
              key: ValueKey('qslot_${obj.slotId}'),
              slotId: obj.slotId,
              sessions: obj.sessions,
              isExpanded: isGroupExpanded,
              onToggle: () => setState(
                () => _slotGroupExpanded[obj.slotId] = !isGroupExpanded,
              ),
              todayPatients: widget.todayPatients,
              selected: widget.selected,
              globalQs: widget.qs,
              onStart: widget.onStart,
              onSkip: widget.onSkip,
              onPrescription: widget.onPrescription,
              onCancel: widget.onCancel,
              onSelect: widget.onSelect,
              onQueueStart: widget.onQueueStart,
              onQueuePause: widget.onQueuePause,
              onQueueStop: widget.onQueueStop,
              onQueueEmergency: widget.onQueueEmergency,
              emergencyQueueIds: widget.emergencyQueueIds,
              controlsEnabled: i == firstQueueIdx,
            );
          }

          if (obj is _StandaloneSessionItem) {
            return _buildSessionAccordion(
              session: obj.session,
              sessionIndex: obj.globalIndex,
              visibleSessions: visibleSessions,
            );
          }

          // Slot bookings (bookingType == 2) — no queue controls
          final group     = obj as ({int? slotId, List<AppointmentList> patients});
          final groupKey  = group.slotId ?? -1;
          final isExpanded = _slotGroupExpanded[groupKey] ?? true;
          return _SlotBookingsSection(
            slotId: group.slotId,
            patients: group.patients,
            isExpanded: isExpanded,
            onToggle: () => setState(
              () => _slotGroupExpanded[groupKey] = !isExpanded,
            ),
            selected: widget.selected,
            onStart: widget.onStart,
            onSkip: widget.onSkip,
            onPrescription: widget.onPrescription,
            onCancel: widget.onCancel,
            onSelect: widget.onSelect,
            qs: widget.qs,
          );
        },
      ),
    );
  }

  Widget _buildSessionAccordion({
    required dynamic session,
    required int sessionIndex,
    required List<dynamic> visibleSessions,
  }) {
    final queueId    = session.queueId as int? ?? sessionIndex;
    // Use negative key space so standalone sessions don't collide with slot IDs
    final expandKey  = -(queueId + 1);
    final isExpanded = _slotGroupExpanded[expandKey] ?? true;
    final sessionPatients = _patientsForSession(session, sessionIndex, visibleSessions.length);
    final qs         = _sessionQueueState(session.queueStatus as int?);
    final slotLabel  = _slotTimeLabel(
      session.startTime as String?,
      session.endTime as String?,
    );
    final currentServingId = session.currentServing as int?;
    final currentPt = (currentServingId != null && currentServingId > 0)
        ? sessionPatients.where((p) => p.appointmentId == currentServingId).firstOrNull
        : sessionPatients
            .where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress')
            .firstOrNull;
    final waitingPts = sessionPatients
        .where((p) => p.appointmentId != currentPt?.appointmentId)
        .toList();
    final firstSessionStopped = visibleSessions.isEmpty
        ? true
        : (_sessionQueueState(visibleSessions[0].queueStatus as int?) == QueueState.stopped);
    final controlsEnabled = (sessionIndex == 0) || firstSessionStopped;

    return _SessionAccordion(
      key: ValueKey(queueId),
      session: session,
      sessionIndex: sessionIndex,
      slotLabel: slotLabel,
      queueState: qs,
      sessionPatients: sessionPatients,
      currentPatient: currentPt,
      waitingPatients: waitingPts,
      isExpanded: isExpanded,
      selected: widget.selected,
      controlsEnabled: controlsEnabled,
      onToggle: () => setState(() => _slotGroupExpanded[expandKey] = !isExpanded),
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
      isEmergency: widget.emergencyQueueIds.contains(queueId),
    );
  }

  List<AppointmentList> _patientsForSession(dynamic session, int index, int total) {
    final all = widget.todayPatients
        .where((p) => p.bookingType == null || p.bookingType == 1)
        .toList();
    final queueId = session.queueId as int?;
    if (queueId != null) {
      return all.where((p) => p.queueId == queueId).toList();
    }
    if (total <= 1) return all;
    return [];
  }
}

// ── List item types for _SessionGroupedBody ───────────────────────────────────
abstract class _ListItem {}

class _SlotGroupItem extends _ListItem {
  final int slotId;
  final List<dynamic> sessions;
  _SlotGroupItem({required this.slotId, required this.sessions});
}

class _StandaloneSessionItem extends _ListItem {
  final dynamic session;
  final int globalIndex;
  _StandaloneSessionItem({required this.session, required this.globalIndex});
}

// ════════════════════════════════════════════════════════════════════
//  QUEUE SLOT SECTION
//  One expandable card per slotId for queue bookings (bookingType == 1).
//  Header: Slot #id · state badge · chevron
//  Body  : queue controls (LiveQueueCard) + patient cards flat — no nesting
// ════════════════════════════════════════════════════════════════════
class _QueueSlotSection extends StatelessWidget {
  final int slotId;
  final List<dynamic> sessions;         // TodayQueueModel entries for this slot
  final bool isExpanded;
  final VoidCallback onToggle;
  final List<AppointmentList> todayPatients;
  final AppointmentList? selected;
  final QueueState globalQs;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final void Function(AppointmentList)? onSelect;
  final Future<void> Function(int? queueId) onQueueStart;
  final Future<void> Function(int? queueId) onQueuePause;
  final Future<void> Function(int? queueId) onQueueStop;
  final Future<void> Function(int? queueId) onQueueEmergency;
  final Set<int> emergencyQueueIds;
  final bool controlsEnabled;

  const _QueueSlotSection({
    super.key,
    required this.slotId,
    required this.sessions,
    required this.isExpanded,
    required this.onToggle,
    required this.todayPatients,
    required this.selected,
    required this.globalQs,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    required this.emergencyQueueIds,
    required this.controlsEnabled,
    this.onSelect,
  });

  // All queue patients belonging to any session in this slot
  List<AppointmentList> get _allPatients {
    final queueIds = sessions
        .map((s) => s.queueId as int?)
        .whereType<int>()
        .toSet();
    final pts = todayPatients
        .where((p) =>
            (p.bookingType == null || p.bookingType == 1) &&
            (queueIds.isEmpty || queueIds.contains(p.queueId)))
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    return pts;
  }

  // Use the first running/paused session; fall back to first session
  dynamic get _activeSession {
    for (final s in sessions) {
      final st = s.queueStatus as int? ?? 0;
      if (st == 1 || st == 2) return s;
    }
    return sessions.isNotEmpty ? sessions.first : null;
  }

  QueueState get _queueState {
    QueueState result = QueueState.idle;
    for (final s in sessions) {
      final st = _sessionQueueState(s.queueStatus as int?);
      if (st == QueueState.running) return QueueState.running;
      if (st == QueueState.paused && result != QueueState.running) result = QueueState.paused;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final qs      = _queueState;
    final active  = _activeSession;
    final queueId = active != null ? (active.queueId as int?) : null;
    final allPts  = _allPatients;

    // Defensive: never render a card for a closed/empty queue slot.
    if (sessions.isEmpty || qs == QueueState.stopped) {
      return const SizedBox.shrink();
    }

    final (Color hBg, Color hFg, Color hDot) = switch (qs) {
      QueueState.running => (kPrimaryLighter, kPrimaryDark, kPrimary),
      QueueState.paused  => (kAmberLight,     kAmberDark,   kWarning),
      QueueState.stopped => (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFF9CA3AF)),
      QueueState.idle    => (kRedLight,        kRedDark,     kError),
    };

    // Derive current/waiting from patients
    final currentServingId = active != null ? (active.currentServing as int?) : null;
    final currentPt = (currentServingId != null && currentServingId > 0)
        ? allPts.where((p) => p.appointmentId == currentServingId).firstOrNull
        : allPts.where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').firstOrNull;

    final queueActive   = qs == QueueState.running || qs == QueueState.paused;
    final hasIP         = allPts.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
    final nextBooked    = allPts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kPrimaryLight.withOpacity(0.9)),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.07),
              blurRadius: 12,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: isExpanded ? Radius.zero : const Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [_kGradFrom, _kGradTo],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(Icons.people_alt_outlined, size: 13, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Queue Booking',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                        ),
                        Text(
                          '${allPts.length} patient${allPts.length == 1 ? '' : 's'}',
                          style: const TextStyle(fontSize: 10, color: kTextSecondary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: hBg, borderRadius: BorderRadius.circular(20)),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Container(width: 6, height: 6, decoration: BoxDecoration(color: hDot, shape: BoxShape.circle)),
                      const SizedBox(width: 4),
                      Text(
                        switch (qs) {
                          QueueState.running => 'Running',
                          QueueState.paused  => 'Paused',
                          QueueState.stopped => 'Closed',
                          QueueState.idle    => 'Idle',
                        },
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: hFg),
                      ),
                    ]),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
                  ),
                ]),
              ),
            ),

            // ── Body ──────────────────────────────────────────────
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 10),

                    // Queue controls directly below divider
                    _LiveQueueCard(
                      patients: allPts,
                      qs: qs,
                      onStart: onStart,
                      onSkip: onSkip,
                      controlsEnabled: controlsEnabled,
                      onQueueStart: () => onQueueStart(queueId),
                      onQueuePause: () => onQueuePause(queueId),
                      onQueueStop:  () => onQueueStop(queueId),
                      onQueueEmergency: () => onQueueEmergency(queueId),
                      isEmergencyPaused:
                          queueId != null && emergencyQueueIds.contains(queueId),
                    ),

                    // Patient list
                    if (allPts.isEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        alignment: Alignment.center,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: kPrimaryLighter,
                                shape: BoxShape.circle,
                                border: Border.all(color: kPrimaryLight),
                              ),
                              child: const Icon(Icons.inbox_rounded, color: kPrimary, size: 18),
                            ),
                            const SizedBox(height: 8),
                            const Text('No patients waiting',
                                style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    else ...[
                      // "Waiting" section label
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8, top: 2),
                        child: Row(children: [
                          Container(
                            width: 3, height: 14,
                            decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(4)),
                          ),
                          const SizedBox(width: 8),
                          const Text('Waiting',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20)),
                            child: Text('${allPts.length}',
                                style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
                          ),
                        ]),
                      ),
                      ...allPts.map((p) {
                        final status   = p.status?.toLowerCase() ?? '';
                        final isIP     = status == 'in_progress';
                        final isNextUp = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                        final isCurrent = p.appointmentId == currentPt?.appointmentId || isIP || isNextUp;
                        final isHighlighted = isCurrent && queueActive;

                        bool accessible = false;
                        if (isIP) {
                          accessible = true;
                        } else if (status == 'skipped') {
                          accessible = true;
                        } else if (queueActive && status == 'booked') {
                          accessible = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                        }
                        final effectiveAccessible = status == 'skipped' ? accessible : queueActive && accessible;
                        final VoidCallback? effectiveSkip = queueActive && accessible && status == 'booked'
                            ? () => onSkip(p) : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PatientCard(
                            key: ValueKey(p.appointmentId),
                            patient: p,
                            tab: _Tab.today,
                            accessible: effectiveAccessible,
                            selected: selected?.appointmentId == p.appointmentId,
                            highlightBorder: isHighlighted,
                            onTap: onSelect != null ? () => onSelect!(p) : null,
                            onStart: () => onStart(p),
                            onSkip: effectiveSkip,
                            onPrescription: () => onPrescription(p),
                            onCancel: () => onCancel(p),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SESSION ACCORDION
// ════════════════════════════════════════════════════════════════════
class _SessionAccordion extends StatelessWidget {
  final dynamic session;
  final int sessionIndex;
  final String? slotLabel;
  final QueueState queueState;
  final QueueState globalQs;
  final List<AppointmentList> sessionPatients;
  final AppointmentList? currentPatient;
  final List<AppointmentList> waitingPatients;
  final bool isExpanded;
  final bool controlsEnabled;
  final AppointmentList? selected;
  final VoidCallback onToggle;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  final void Function(AppointmentList)? onSelect;
  final VoidCallback onQueueStart;
  final VoidCallback onQueuePause;
  final VoidCallback onQueueStop;
  final VoidCallback onQueueEmergency;
  final bool isEmergency;

  const _SessionAccordion({
    super.key,
    required this.session,
    required this.sessionIndex,
    required this.slotLabel,
    required this.queueState,
    required this.globalQs,
    required this.sessionPatients,
    required this.currentPatient,
    required this.waitingPatients,
    required this.isExpanded,
    required this.controlsEnabled,
    required this.onToggle,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    required this.isEmergency,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    // Defensive: a closed (stopped) session should not be visible.
    if (queueState == QueueState.stopped) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kPrimaryLight.withOpacity(0.8)),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SessionHeader(
              slotLabel: slotLabel,
              queueState: queueState,
              patientCount: sessionPatients.length,
              isExpanded: isExpanded,
              onTap: onToggle,
              sessionIndex: sessionIndex,
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(height: 1, color: kBorder),
                    const SizedBox(height: 10),

                    // Live Queue card with controls
                    _LiveQueueCard(
                      patients: sessionPatients,
                      qs: queueState,
                      onStart: onStart,
                      onSkip: onSkip,
                      controlsEnabled: controlsEnabled,
                      onQueueStart: onQueueStart,
                      onQueuePause: onQueuePause,
                      onQueueStop: onQueueStop,
                      onQueueEmergency: onQueueEmergency,
                      isEmergencyPaused: isEmergency,
                    ),

                    Builder(builder: (_) {
                        final allWaiting = [
                          if (currentPatient != null) currentPatient!,
                          ...waitingPatients,
                        ];
                        final queueStarted = queueState == QueueState.running || queueState == QueueState.paused;

                        if (allWaiting.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            alignment: Alignment.center,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 40, height: 40,
                                  decoration: BoxDecoration(
                                    color: kPrimaryLighter,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kPrimaryLight),
                                  ),
                                  child: const Icon(Icons.inbox_rounded, color: kPrimary, size: 18),
                                ),
                                const SizedBox(height: 8),
                                const Text('No patients waiting',
                                    style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                              ],
                            ),
                          );
                        }

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8, top: 2),
                              child: Row(children: [
                                Container(
                                  width: 3, height: 14,
                                  decoration: BoxDecoration(
                                    color: kPrimary,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                const Text('Waiting',
                                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: kPrimaryLight,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text('${allWaiting.length}',
                                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
                                ),
                              ]),
                            ),
                            ...allWaiting.map((p) {
                              final status     = p.status?.toLowerCase() ?? '';
                              final isIP       = status == 'in_progress';
                              final isQActive  = queueState == QueueState.running || queueState == QueueState.paused;
                              final hasIP      = sessionPatients.any(
                                  (x) => (x.status?.toLowerCase() ?? '') == 'in_progress');
                              final nextBooked = allWaiting
                                  .where((x) => (x.status?.toLowerCase() ?? '') == 'booked')
                                  .toList()
                                ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
                              final isNextUp   = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                              final isCurrent  = p.appointmentId == currentPatient?.appointmentId || isIP || isNextUp;
                              final isHighlighted = isCurrent && queueStarted;
                              bool accessible = false;
                              if (isIP) {
                                accessible = true;
                              } else if (isQActive && status == 'booked') {
                                accessible = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
                              } else if (status == 'skipped') {
                                accessible = true;
                              }
                              final bool queueActive = queueState == QueueState.running || queueState == QueueState.paused;
                              final bool effectiveAccessible =
                                  controlsEnabled && (status == 'skipped' ? accessible : queueActive && accessible);
                              final VoidCallback? effectiveSkip = controlsEnabled && queueActive && accessible && status == 'booked'
                                  ? () => onSkip(p) : null;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _PatientCard(
                                  key: ValueKey(p.appointmentId),
                                  patient: p,
                                  tab: _Tab.today,
                                  accessible: effectiveAccessible,
                                  selected: selected?.appointmentId == p.appointmentId,
                                  highlightBorder: isHighlighted,
                                  onTap: onSelect != null ? () => onSelect!(p) : null,
                                  onStart: () => onStart(p),
                                  onSkip: effectiveSkip,
                                  onPrescription: () => onPrescription(p),
                                  onCancel: () => onCancel(p),
                                ),
                              );
                            }),
                          ],
                        );
                      }),
                  ],
                ),
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SESSION HEADER  —  S1 badge + slot time + state badge + chevron
//  (patient count and controls  Live Queue card )
// ════════════════════════════════════════════════════════════════════
class _SessionHeader extends StatelessWidget {
  final String? slotLabel;
  final QueueState queueState;
  final int patientCount;
  final bool isExpanded;
  final VoidCallback onTap;
  final int sessionIndex;

  const _SessionHeader({
    required this.slotLabel,
    required this.queueState,
    required this.patientCount,
    required this.isExpanded,
    required this.onTap,
    required this.sessionIndex,
  });

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg, Color dot) = switch (queueState) {
      QueueState.running => (kPrimaryLighter, kPrimaryDark, kPrimary),
      QueueState.paused  => (kAmberLight,     kAmberDark,   kWarning),
      QueueState.stopped => (const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFF9CA3AF)),
      QueueState.idle    => (kRedLight,        kRedDark,     kError),
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.vertical(
        top: const Radius.circular(18),
        bottom: isExpanded ? Radius.zero : const Radius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
            Expanded(
              child: Row(
                children: [
                  const Icon(Icons.access_time_rounded, size: 14, color: kTextSecondary),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(slotLabel!,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis),
                  ),
                ],
              ),
            )
          else
            const Expanded(child: Text('Session',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary))),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              Text(
                switch (queueState) {
                  QueueState.running => 'Running',
                  QueueState.paused  => 'Paused',
                  QueueState.stopped => 'Closed',
                  QueueState.idle    => 'Idle',
                },
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: fg),
              ),
            ]),
          ),
          const SizedBox(width: 8),
          AnimatedRotation(
            turns: isExpanded ? 0.5 : 0.0,
            duration: const Duration(milliseconds: 260),
            child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LIVE QUEUE CARD
//  Top row: pulse + LIVE QUEUE + 👥 count + ▶/⏸ + ⏹ + state badge
// ════════════════════════════════════════════════════════════════════
class _LiveQueueCard extends StatelessWidget {
  final List<AppointmentList> patients;
  final QueueState qs;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final bool controlsEnabled;
  final VoidCallback onQueueStart;
  final VoidCallback onQueuePause;
  final VoidCallback onQueueStop;
  // Optional — emergency button only renders where this is wired.
  final VoidCallback? onQueueEmergency;
  // Hide the Close (stop) button while emergency-paused.
  final bool isEmergencyPaused;

  const _LiveQueueCard({
    required this.patients,
    required this.qs,
    required this.onStart,
    required this.onSkip,
    required this.controlsEnabled,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    this.onQueueEmergency,
    this.isEmergencyPaused = false,
  });

  @override
  Widget build(BuildContext context) {
    // A closed queue should not show its live card at all.
    if (qs == QueueState.stopped) {
      return const SizedBox.shrink();
    }
    final ip = patients.firstWhere(
      (p) => (p.status?.toLowerCase() ?? '') == 'in_progress',
      orElse: () => AppointmentList(),
    );
    final hasIP  = (ip.appointmentId ?? 0) != 0;
    final booked = patients
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current   = hasIP ? ip : booked.firstOrNull;
    final next      = hasIP ? booked.firstOrNull : (booked.length > 1 ? booked[1] : null);
    final isRunning = qs == QueueState.running;
    final isStopped = qs == QueueState.stopped;
    final isPaused  = qs == QueueState.paused;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kPrimaryLight),
        ),
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // ── Top row: pulse + label + count + controls + state ─────
          Row(children: [
            _PulseDot(),
            const SizedBox(width: 6),
            const Text('LIVE QUEUE',
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                    letterSpacing: 1.1, color: kPrimary)),
            const SizedBox(width: 6),

            // Patient count pill
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

            // Start / Pause / Resume + Stop + Emergency (hidden when stopped)
            if (!isStopped) ...[
              _QueueIconBtn(
                icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isRunning ? kAmberDark : kPrimaryDark,
                bg:    isRunning ? kAmberLight : kPrimaryLight,
                enabled: controlsEnabled,
                tooltip: isRunning
                    ? 'Pause'
                    : isPaused
                        ? 'Resume'
                        : 'Start',
                onTap: controlsEnabled
                    ? (isRunning ? onQueuePause : onQueueStart)
                    : null,
              ),
              // Close is hidden while emergency-paused.
              if (!isEmergencyPaused) ...[
                const SizedBox(width: 5),
                _QueueIconBtn(
                  icon: Icons.stop_rounded,
                  color: kRedDark,
                  bg: kRedLight,
                  enabled: controlsEnabled,
                  tooltip: 'Close queue',
                  onTap: controlsEnabled ? onQueueStop : null,
                ),
              ],
              // Emergency pause — only when wired (today queue sessions).
              if (onQueueEmergency != null) ...[
                const SizedBox(width: 5),
                _QueueIconBtn(
                  icon: Icons.warning_amber_rounded,
                  color: kPurpleDark,
                  bg: kPurpleLight,
                  enabled: controlsEnabled,
                  tooltip: 'Emergency pause',
                  onTap: controlsEnabled ? onQueueEmergency : null,
                ),
              ],
              const SizedBox(width: 8),
            ],

           // _QueueStateBadge(state: qs),
          ]),

          const SizedBox(height: 10),

          // Lock notice for sequential sessions
          if (!controlsEnabled) ...[
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: kAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAmberBorder),
              ),
              child: Row(children: [
                const Icon(Icons.lock_outline_rounded, size: 13, color: kAmberDark),
                const SizedBox(width: 6),
                const Expanded(
                  child: Text('Will start after the previous session is closed',
                      style: TextStyle(fontSize: 11, color: kAmberDark, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ],

          // Token boxes
          Row(children: [
            _TokBox(
                label: 'CURRENT',
                value: (current?.queueNumber ?? 0).toString().padLeft(2, '0'),
                isActive: true),
            const SizedBox(width: 6),
            _TokBox(
                label: 'UP NEXT',
                value: next != null ? (next.queueNumber ?? 0).toString().padLeft(2, '0') : '--'),
            const SizedBox(width: 6),
            _TokBox(label: 'REMAINING', value: patients.length.toString().padLeft(2, '0'), isGreen: true),
          ]),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  QUEUE ICON BUTTON  (Live Queue card top row )
// ════════════════════════════════════════════════════════════════════
class _QueueIconBtn extends StatelessWidget {
  final IconData icon;
  final Color color, bg;
  final bool enabled;
  final String tooltip;
  final VoidCallback? onTap;

  const _QueueIconBtn({
    required this.icon,
    required this.color,
    required this.bg,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Tooltip(
    message: enabled ? tooltip : 'Previous session close करा',
    preferBelow: false,
    child: Opacity(
      opacity: enabled ? 1.0 : 0.35,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.25)),
          ),
          alignment: Alignment.center,
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  SLOT BOOKINGS SECTION  (shown independently below queue sessions)
// ════════════════════════════════════════════════════════════════════
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
    required this.patients,
    required this.qs,
    required this.isExpanded,
    required this.onToggle,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    this.slotId,
    this.selected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: kInfoLight),
          boxShadow: [
            BoxShadow(
              color: kInfo.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onToggle,
              borderRadius: BorderRadius.vertical(
                top: const Radius.circular(18),
                bottom: isExpanded ? Radius.zero : const Radius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                child: Row(children: [
                  Container(
                    width: 26, height: 26,
                    decoration: BoxDecoration(color: kInfoLight, borderRadius: BorderRadius.circular(8)),
                    alignment: Alignment.center,
                    child: const Icon(Icons.calendar_month_rounded, size: 14, color: kInfoDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Slot Bookings',
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                        ),
                        
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: kInfoLight, borderRadius: BorderRadius.circular(20)),
                    child: Text('${patients.length}',
                        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kInfoDark)),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: isExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 260),
                    child: const Icon(Icons.keyboard_arrow_down_rounded, size: 18, color: kTextSecondary),
                  ),
                ]),
              ),
            ),
            AnimatedCrossFade(
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                children: [
                  const Divider(height: 1, color: kBorder),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                    child: Column(
                      children: patients.map((p) {
                        final status = p.status?.toLowerCase() ?? '';
                        // Slot bookings are always accessible (not queue-locked)
                        final accessible = status == 'booked' || status == 'in_progress' || status == 'skipped';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _PatientCard(
                            key: ValueKey(p.appointmentId),
                            patient: p,
                            tab: _Tab.today,
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
                ],
              ),
              crossFadeState: isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 260),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PATIENT LIST BODY  (Upcoming + Completed tabs)
// ════════════════════════════════════════════════════════════════════
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
    this.onView,
    this.selected, this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (patients.isEmpty) return _EmptyState(tab: tab);

    final hasIP = tab == _Tab.today &&
        patients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');

    final booked = tab == _Tab.today
        ? (patients.where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
              .toList()..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0)))
        : <AppointmentList>[];
    final firstBooked = booked.firstOrNull;

    final isQueueActive = qs == QueueState.running || qs == QueueState.paused;
    final isToday       = tab == _Tab.today;

    final currentAppointmentId = hasIP
        ? patients.firstWhere((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').appointmentId
        : firstBooked?.appointmentId;

    final displayPatients = isToday
        ? patients.where((p) => p.appointmentId != currentAppointmentId).toList()
        : patients;

    // Hide the live queue card when the queue is stopped — a closed queue
    // shouldn't keep showing its status header on the patient list.
    final showLiveCard = isToday && qs != QueueState.stopped;
    final hdrCount = isToday ? (showLiveCard ? 2 : 1) : 1;

    return RefreshIndicator(
      color: kPrimary,
      strokeWidth: 2.5,
      displacement: 40,
      onRefresh: () async {
        ref.read(appointmentViewModelProvider.notifier)
            .fetchPatientAppointments(ref.read(doctorLoginViewModelProvider).doctorId ?? 0);
        await Future.delayed(const Duration(milliseconds: 600));
      },
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(12, 8, 12, 10 + extraBottom),
        itemCount: displayPatients.length + hdrCount,
        itemBuilder: (ctx, i) {
          if (i == 0 && showLiveCard)
            return _LiveQueueCard(
              patients: patients, qs: qs,
              onStart: onStart, onSkip: onSkip,
              controlsEnabled: true,
              onQueueStart: () {},
              onQueuePause: () {},
              onQueueStop: () {},
            );

          if ((showLiveCard && i == 1) || (!showLiveCard && i == 0)) {
            final title = switch (tab) {
              _Tab.today     => 'Waiting',
              _Tab.upcoming  => 'Upcoming',
              _Tab.completed => 'Completed',
            };
            final badge = switch (tab) {
              _Tab.today     => '${displayPatients.length} left',
              _Tab.upcoming  => '${displayPatients.length} scheduled',
              _Tab.completed => '${displayPatients.length} done',
            };
            return _SectionHeader(title: title, badge: badge);
          }

          final p      = displayPatients[i - hdrCount];
          final status = p.status?.toLowerCase() ?? '';
          bool accessible = true;
          if (tab == _Tab.today) {
            if (status == 'in_progress') {
              accessible = true;
            } else if (status == 'skipped') {
              accessible = true;
            } else if (!isQueueActive) {
              accessible = false;
            } else if (status == 'booked') {
              final nextBooked = displayPatients
                  .where((x) => (x.status?.toLowerCase() ?? '') == 'booked')
                  .toList()
                ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
              accessible = !hasIP && p.queueNumber == nextBooked.firstOrNull?.queueNumber;
            }
          }

          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: _PatientCard(
              key: ValueKey(p.appointmentId),
              patient: p, tab: tab,
              accessible: accessible,
              selected: selected?.appointmentId == p.appointmentId,
              onTap: onSelect != null ? () => onSelect!(p) : null,
              onStart: () => onStart(p),
              onSkip: accessible && tab == _Tab.today && status == 'booked' ? () => onSkip(p) : null,
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

// ── Pill Tab Bar ───────────────────────────────────────────────────────────────
class _PillTabBar extends StatelessWidget {
  final TabController controller;
  final int todayCount, upcomingCount, completedCount;
  const _PillTabBar({
    required this.controller,
    required this.todayCount,
    required this.upcomingCount,
    required this.completedCount,
  });

  @override
  Widget build(BuildContext context) => Container(
        color: Colors.white,
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Container(
          height: 38,
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
            indicator: BoxDecoration(
              gradient: kPrimaryGradient,
              borderRadius: BorderRadius.circular(17),
            ),
            indicatorPadding: const EdgeInsets.all(3),
            labelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.1,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            tabs: [
              Tab(text: 'Current Today Queue ($todayCount)'),
              Tab(text: 'Upcoming ($upcomingCount)'),
              Tab(text: 'Current Complete Queue ($completedCount)'),
            ],
          ),
        ),
      );
}
// ── Desktop Sidebar ────────────────────────────────────────────────────────────
class _DesktopSidebar extends StatelessWidget {
  final _Tab activeTab;
  final int todayCount, upcomingCount, completedCount, total;
  final TextEditingController searchCtrl;
  final void Function(_Tab) onTabChange;

  const _DesktopSidebar({
    required this.activeTab,
    required this.todayCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.total,
    required this.searchCtrl,
    required this.onTabChange,
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
          const Text('Queue',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ]),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
        child: AppExpandableHeaderSearch(
          controller: searchCtrl,
          leadingIcon: Icons.people_alt_outlined,
          title: 'Search',
          subtitle: 'Patients',
          hintText: 'Search patients...',
          height: 36,
          accentColor: kPrimary,
          leadingBackgroundColor: kPrimaryLight,
          titleColor: kTextPrimary,
          subtitleColor: kTextMuted,
          fieldColor: kBg,
          borderColor: kBorder,
          iconColor: kTextMuted,
          textColor: kTextPrimary,
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(children: [
          _SideNavItem(icon: Icons.access_time_rounded, label: 'Current Today Queue',
              count: todayCount, selected: activeTab == _Tab.today,
              onTap: () => onTabChange(_Tab.today)),
          const SizedBox(height: 4),
          _SideNavItem(icon: Icons.calendar_today_rounded, label: 'Upcoming',
              count: upcomingCount, selected: activeTab == _Tab.upcoming,
              onTap: () => onTabChange(_Tab.upcoming)),
          const SizedBox(height: 4),
          _SideNavItem(icon: Icons.check_circle_outline_rounded,
              label: 'Current Complete Queue', count: completedCount,
              selected: activeTab == _Tab.completed,
              onTap: () => onTabChange(_Tab.completed)),
        ]),
      ),
      const SizedBox(height: 14),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14),
        child: Text('OVERVIEW',
            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: kTextMuted)),
      ),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: GridView.count(
          crossAxisCount: 2, shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8, mainAxisSpacing: 8,
          childAspectRatio: 1.4,
          children: [
            _MiniStat('Total',    total,          kPrimary),
            _MiniStat('Waiting',  todayCount,     kPrimary),
            _MiniStat('Done',     completedCount, kSuccess),
            _MiniStat('Upcoming', upcomingCount,  kWarning),
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
  const _SideNavItem({
    required this.icon, required this.label, required this.count,
    required this.selected, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? kPrimary.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        border: selected ? Border.all(color: kPrimary.withOpacity(0.20)) : null,
      ),
      child: Row(children: [
        Icon(icon, size: 16, color: selected ? kPrimary : kTextMuted),
        const SizedBox(width: 10),
        Expanded(child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? kPrimaryDark : kTextSecondary))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
          decoration: BoxDecoration(
            color: selected ? kPrimary : kPrimaryLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(count.toString(),
              style: TextStyle(
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
      color: kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder),
    ),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text(value.toString().padLeft(2, '0'),
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: color, height: 1)),
      const SizedBox(height: 3),
      Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w500, color: kTextSecondary)),
    ]),
  );
}

// ── Section Header ────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title, badge;
  const _SectionHeader({required this.title, required this.badge});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(children: [
          Container(width: 3, height: 16,
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(4))),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
        ]),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          decoration: BoxDecoration(
            color: kPrimaryLighter,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimaryLight),
          ),
          child: Text(badge,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kPrimaryDark)),
        ),
      ],
    ),
  );
}

// ── Patient Card ───────────────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final AppointmentList patient;
  final _Tab tab;
  final bool accessible, selected;
  final bool highlightBorder;
  final VoidCallback? onTap, onSkip, onView;
  final VoidCallback onStart, onPrescription, onCancel;

  const _PatientCard({
    super.key,
    required this.patient,
    required this.tab,
    required this.accessible,
    required this.selected,
    required this.onTap,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    this.highlightBorder = false,
    this.onView,
  });

  ({Color bg, Color fg}) get _av =>
      _avatarPalette[(patient.appointmentId ?? 0) % _avatarPalette.length];

  String get _inits => (patient.patientName ?? '?')
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0] : '')
      .join()
      .toUpperCase();

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
    return parts.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final av = _av;
    final st = patient.status ?? 'unknown';
    final status = st.toLowerCase();
    final isIP = status == 'in_progress';
    final isSlotBooking = _isSlotBooking(patient);
    final slotMetaLabel = isSlotBooking
        ? _slotAppointmentMetaLabel(patient.appointmentDate, patient.startTime)
        : null;
    final showBookedTag = !(isSlotBooking && status == 'booked');
    final (Color sBg, Color sFg, Color sDot) = switch (status) {
      'booked' => (kGreenLight, kGreenDark, kSuccess),
      'in_progress' => (kPrimaryLighter, kPrimaryDark, kPrimary),
      'skipped' => (kAmberLight, kAmberDark, kWarning),
      'completed' || 'done' || 'closed' => (kGreenLight, kGreenDark, kSuccess),
      _ => (kRedLight, kRedDark, kError),
    };

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: kCardGlassGradient,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? kPrimary
                : highlightBorder
                    ? const Color(0xFF0E9384)
                    : kHairline,
            width: selected ? 1.5 : highlightBorder ? 1.5 : 1,
          ),
        ),
        padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [av.bg, Colors.white],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: av.fg.withOpacity(0.18)),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    _inits,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: av.fg,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.patientName ?? 'Patient',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.1,
                          height: 1.15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _info,
                        style: const TextStyle(
                          fontSize: 9.5,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 4,
                        runSpacing: 3,
                        children: [
                          if (patient.specialization != null)
                            _Chip(label: patient.specialization!, bg: kPrimaryLighter, fg: kPrimaryDark),
                          if (showBookedTag)
                            _DotChip(
                              label: st[0].toUpperCase() + st.substring(1).replaceAll('_', ' '),
                              bg: sBg,
                              fg: sFg,
                              dot: sDot,
                            ),
                          if (!isSlotBooking || slotMetaLabel != null)
                            _Chip(
                              label: isSlotBooking
                                  ? slotMetaLabel!
                                  : _fmtDateLabel(patient.appointmentDate),
                              bg: kInfoLight,
                              fg: kInfoDark,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (!isSlotBooking) ...[
                  const SizedBox(width: 7),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [av.bg, Colors.white],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(color: av.fg.withOpacity(0.18)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const Text(
                          'TOKEN',
                          style: TextStyle(
                            fontSize: 7.5,
                            color: kTextMuted,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          (patient.queueNumber ?? 0).toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: av.fg,
                            height: 1,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (tab == _Tab.today) ...[
                  if (onSkip != null) ...[
                    Expanded(
                      child: _ActionBtn(
                        label: 'Skip',
                        bg: kRedLight,
                        fg: kRedDark,
                        border: kRedBorder,
                        onTap: onSkip,
                      ),
                    ),
                    const SizedBox(width: 7),
                  ],
                  Expanded(
                    flex: 2,
                    child: _ActionBtn(
                      label: isIP ? 'Continue' : 'Start Session',
                      isGrad: accessible,
                      bg: accessible ? null : kBorder,
                      fg: accessible ? Colors.white : kTextMuted,
                      onTap: accessible ? onStart : null,
                    ),
                  ),
                ] else if (tab == _Tab.upcoming) ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'View',
                      bg: kPrimaryLighter,
                      fg: kPrimaryDark,
                      border: kPrimaryLight,
                      onTap: onView,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Cancel',
                      bg: kRedLight,
                      fg: kRedDark,
                      border: kRedBorder,
                      onTap: onCancel,
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _ActionBtn(
                      label: 'Prescription',
                      bg: kPurpleLight,
                      fg: kPurpleDark,
                      border: kPurpleBorder,
                      onTap: onPrescription,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Done',
                      bg: const Color(0xFFF3F4F6),
                      fg: const Color(0xFF6B7280),
                      onTap: null,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Detail Panel (desktop)
class _DetailPanel extends StatelessWidget {
  final AppointmentList? patient;
  final _Tab tab;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;

  const _DetailPanel({
    required this.patient,
    required this.tab,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (patient == null) {
      return Container(
        decoration: const BoxDecoration(
          color: kBg,
          border: Border(left: BorderSide(color: kBorder)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 40, color: kTextMuted),
            SizedBox(height: 10),
            Text(
              'Select a patient',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: kTextSecondary),
            ),
            SizedBox(height: 3),
            Text('to view details', style: TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ),
      );
    }

    final p = patient!;
    final isSlotBooking = _isSlotBooking(p);
    final slotMetaLabel = isSlotBooking
        ? _slotAppointmentMetaLabel(
            p.appointmentDate,
            p.startTime,
            includeYear: true,
          )
        : null;
    final av = _avatarPalette[(p.appointmentId ?? 0) % _avatarPalette.length];
    final name = p.patientName ?? 'Patient';
    final inits = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    return Container(
      decoration: const BoxDecoration(
        color: kBg,
        border: Border(left: BorderSide(color: kBorder)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: av.bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                inits,
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: av.fg),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              name,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 2),
            if (p.gender != null)
              Text(p.gender!, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
            if (!isSlotBooking)
              Container(
                margin: const EdgeInsets.symmetric(vertical: 12),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: kPrimaryLighter,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPrimaryLight),
                ),
                width: double.infinity,
                child: Column(
                  children: [
                    Text(
                      (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: kPrimary,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 3),
                    const Text(
                      'Token',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kTextSecondary),
                    ),
                  ],
                ),
              ),
            const Divider(height: 1, color: kDivider),
            _DetailRow('Specialty', p.specialization ?? '--'),
            _DetailRow(
              'Status',
              (p.status ?? 'Unknown')[0].toUpperCase() + (p.status ?? 'unknown').substring(1),
            ),
            if (!isSlotBooking || slotMetaLabel != null)
              _DetailRow(
                'Date',
                isSlotBooking
                    ? slotMetaLabel!
                    : _fmtDateLabel(p.appointmentDate, includeYear: true),
              ),
            _DetailRow('Appt. ID', '${p.appointmentId ?? '--'}'),
            const SizedBox(height: 14),
            if (tab == _Tab.today) ...[
              _PanelBtn(label: 'Start Session', isGrad: true, onTap: () => onStart(p)),
              const SizedBox(height: 8),
              _PanelBtn(
                label: 'Skip',
                bg: kRedLight,
                fg: kRedDark,
                border: kRedBorder,
                onTap: () => onSkip(p),
              ),
            ] else if (tab == _Tab.upcoming)
              _PanelBtn(
                label: 'Cancel',
                bg: kRedLight,
                fg: kRedDark,
                border: kRedBorder,
                onTap: () => onCancel(p),
              )
            else
              _PanelBtn(
                label: 'Prescription',
                bg: kPurpleLight,
                fg: kPurpleDark,
                border: kPurpleBorder,
                onTap: () => onPrescription(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String k, v;
  const _DetailRow(this.k, this.v);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        Flexible(child: Text(v,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
            textAlign: TextAlign.end, overflow: TextOverflow.ellipsis)),
      ],
    ),
  );
}

class _PanelBtn extends StatelessWidget {
  final String label;
  final bool isGrad;
  final Color? bg, fg, border;
  final VoidCallback onTap;
  const _PanelBtn({
    required this.label, this.isGrad = false,
    this.bg, this.fg, this.border, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 11),
      decoration: BoxDecoration(
        gradient: isGrad
            ? const LinearGradient(colors: [_kGradFrom, _kGradTo],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isGrad ? null : bg,
        borderRadius: BorderRadius.circular(10),
        border: border != null ? Border.all(color: border!) : null,
      ),
      alignment: Alignment.center,
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
              color: isGrad ? Colors.white : fg)),
    ),
  );
}

// ── Small shared widgets ──────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _Chip({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: fg.withOpacity(0.15)),
    ),
    child: Text(
      label,
      style: TextStyle(
        fontSize: 8.5,
        fontWeight: FontWeight.w800,
        color: fg,
        letterSpacing: 0.2,
      ),
    ),
  );
}

class _DotChip extends StatelessWidget {
  final String label;
  final Color bg, fg, dot;
  const _DotChip({required this.label, required this.bg, required this.fg, required this.dot});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: dot.withOpacity(0.18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w800,
          color: fg,
          letterSpacing: 0.2,
        ),
      ),
    ]),
  );
}

class _ActionBtn extends StatelessWidget {
  final String label;
  final Color? bg, fg, border;
  final bool isGrad;
  final VoidCallback? onTap;
  const _ActionBtn({
    required this.label, this.bg, required this.fg,
    this.border, this.isGrad = false, required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap != null ? 1.0 : 0.42,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          gradient: isGrad ? kPrimaryGradient : null,
          color: isGrad ? null : bg,
          borderRadius: BorderRadius.circular(11),
          border: border != null ? Border.all(color: border!) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: FontWeight.w800,
            color: fg,
            letterSpacing: 0.2,
          ),
        ),
      ),
    ),
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
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(begin: .3, end: 1.0)
        .animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: Container(width: 7, height: 7,
        decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle)),
  );
}

class _TokBox extends StatelessWidget {
  final String label, value;
  final bool isActive, isGreen;
  const _TokBox({
    required this.label, required this.value,
    this.isActive = false, this.isGreen = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(colors: [_kGradFrom, _kGradTo],
                begin: Alignment.topLeft, end: Alignment.bottomRight)
            : null,
        color: isActive ? null : isGreen ? kGreenLight : kPrimaryLighter,
        borderRadius: BorderRadius.circular(10),
        border: isActive ? null : Border.all(color: isGreen ? kGreenBorder : kPrimaryLight),
      ),
      child: Column(children: [
        Text(label,
            style: TextStyle(
                fontSize: 8, fontWeight: FontWeight.w700, letterSpacing: .8,
                color: isActive ? Colors.white.withOpacity(0.78)
                    : isGreen ? kGreenDark : kTextSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: TextStyle(
                fontSize: 22, fontWeight: FontWeight.w800, height: 1,
                color: isActive ? Colors.white : isGreen ? kGreenDark : kTextPrimary)),
      ]),
    ),
  );
}

// ── Empty / Error States ───────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final _Tab tab;
  const _EmptyState({required this.tab});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 60, height: 60,
        decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
        child: const Icon(Icons.person_search_rounded, size: 28, color: kPrimary),
      ),
      const SizedBox(height: 12),
      Text(
        switch (tab) {
          _Tab.today     => 'No patients today',
          _Tab.upcoming  => 'No upcoming appointments',
          _Tab.completed => 'No completed appointments',
        },
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
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
        width: 60, height: 60,
        decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
        child: const Icon(Icons.wifi_off_rounded, color: kError, size: 26),
      ),
      const SizedBox(height: 12),
      const Text('Failed to load appointments',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary)),
      const SizedBox(height: 4),
      const Text('Check your connection and try again',
          style: TextStyle(fontSize: 12, color: kTextMuted)),
      const SizedBox(height: 16),
      ElevatedButton.icon(
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 16),
        label: const Text('Retry', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 11),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    ]),
  );
}

// ── Shimmer + Skeleton ─────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer({required this.width, required this.height, this.radius = 6});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: _anim,
    child: Container(
      width: widget.width, height: widget.height,
      decoration: BoxDecoration(
        color: const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(widget.radius),
      ),
    ),
  );
}

class _SkeletonPatientList extends StatelessWidget {
  const _SkeletonPatientList();

  @override
  Widget build(BuildContext context) => Column(
    children: [
      Container(
        color: Colors.white,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
            child: Container(
              height: 40,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              child: const _Shimmer(width: 140, height: 13),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F5F3),
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.all(4),
              child: const Row(children: [
                Expanded(child: _Shimmer(width: double.infinity, height: double.infinity, radius: 20)),
                SizedBox(width: 4),
                Expanded(child: _Shimmer(width: double.infinity, height: double.infinity, radius: 20)),
                SizedBox(width: 4),
                Expanded(child: _Shimmer(width: double.infinity, height: double.infinity, radius: 20)),
              ]),
            ),
          ),
        ]),
      ),
      Expanded(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 120),
          children: const [
            _Shimmer(width: double.infinity, height: 200, radius: 18),
            SizedBox(height: 14),
            _Shimmer(width: double.infinity, height: 180, radius: 18),
          ],
        ),
      ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════
//  DATE FILTER BOTTOM SHEET
// ════════════════════════════════════════════════════════════════════
class _PatientDateFilterSheet extends StatefulWidget {
  final _DateFilter current;
  final DateTime? customFrom, customTo;
  final bool sortNewest;
  final void Function(_DateFilter, DateTime?, DateTime?, bool) onApply;

  const _PatientDateFilterSheet({
    required this.current,
    required this.customFrom,
    required this.customTo,
    required this.sortNewest,
    required this.onApply,
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
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).padding.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10),
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
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
          Wrap(
            spacing: 7, runSpacing: 7,
            children: _DateFilter.values
                .where((f) => f != _DateFilter.custom)
                .map((f) {
              final sel = _sel == f;
              return GestureDetector(
                onTap: () => setState(() => _sel = f),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
                        color: _sel == _DateFilter.custom ? kPrimary : kTextMuted,
                        size: 15),
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
