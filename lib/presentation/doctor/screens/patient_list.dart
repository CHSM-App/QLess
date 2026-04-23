import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';

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

  List<AppointmentList> _upcomingList(List<AppointmentList> all) => all
      .where((a) =>
          (a.status?.toLowerCase().trim() ?? '') == 'booked' &&
          _isAfter(_pd(a.appointmentDate)) && _match(a))
      .toList();

  List<AppointmentList> _completedList(List<AppointmentList> all) => all
      .where((a) {
        final s = a.status?.toLowerCase().trim() ?? '';
        return (s == 'completed' || s == 'done' || s == 'closed') && _match(a);
      })
      .toList();

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

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = _doctorId;
    if (pid == 0 || did == 0) { _snack('Missing info', isError: true); return; }
    try {
      await ref.read(appointmentViewModelProvider.notifier).startSession(
        AppointmentRequestModel(
          doctorId: did, patientId: pid, appointmentId: p.appointmentId ?? 0,
        ),
      );
    } catch (_) {}
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
          patientStatus: 'booked',
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
      _hasFetched = false;
      _refresh(force: true);
      _snack(res.message ?? 'Patient skipped');
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
              onPressed: () { Navigator.pop(ctx); _snack('Appointment cancelled'); },
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
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue started');
      _hasFetched = false;
      _refresh(force: true);
    } catch (_) {
      _snack('Failed to start queue', isError: true);
    }
  }

  Future<void> _onQueuePause(int? queueId) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
      _hasFetched = false;
      _refresh(force: true);
    } catch (_) {
      _snack('Failed to pause queue', isError: true);
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
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
      _hasFetched = false;
      _refresh(force: true);
    } catch (_) {
      _snack('Failed to close queue', isError: true);
    }
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

  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary.withOpacity(0.2)),
              ),
              child: const Icon(Icons.people_alt_outlined, color: kPrimary, size: 17),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Patients',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
                  SizedBox(height: 1),
                  Text('Manage your patient queue',
                      style: TextStyle(fontSize: 11, color: kTextSecondary)),
                ],
              ),
            ),
          ]),
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
      _SearchBarWidget(controller: _searchCtrl),
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
    this.selected,
    this.onSelect,
  });

  @override
  State<_SessionGroupedBody> createState() => _SessionGroupedBodyState();
}

class _SessionGroupedBodyState extends State<_SessionGroupedBody> {
  final Map<int, bool> _expanded = {};
  bool _slotBookingsExpanded = true;

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

  @override
  Widget build(BuildContext context) {
    final visibleSessions = widget.allSessions.where(_shouldShow).toList();

    final slotPatients = widget.todayPatients
        .where((p) => p.bookingType == 2)
        .toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));

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

    // Queue session accordions + optional slot section as one list
    final itemCount = visibleSessions.length + (slotPatients.isNotEmpty ? 1 : 0);

    return RefreshIndicator(
      color: kPrimary,
      strokeWidth: 2.5,
      onRefresh: widget.onRefresh,
      child: ListView.builder(
        padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + widget.extraBottom),
        itemCount: itemCount,
        itemBuilder: (_, i) {
          // Slot patients section renders after all queue sessions
          if (i == visibleSessions.length) {
            return _SlotBookingsSection(
              patients: slotPatients,
              isExpanded: _slotBookingsExpanded,
              onToggle: () => setState(
                () => _slotBookingsExpanded = !_slotBookingsExpanded,
              ),
              selected: widget.selected,
              onStart: widget.onStart,
              onSkip: widget.onSkip,
              onPrescription: widget.onPrescription,
              onCancel: widget.onCancel,
              onSelect: widget.onSelect,
              qs: widget.qs,
            );
          }

          final session    = visibleSessions[i];
          final queueId    = session.queueId as int? ?? i;
          final isExpanded = _expanded[queueId] ?? true;

          final sessionPatients = _patientsForSession(session, i, visibleSessions.length);
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

          // Sequential lock: first session not stopped → rest locked
          final firstSessionStopped = visibleSessions.isEmpty
              ? true
              : (_sessionQueueState(visibleSessions[0].queueStatus as int?) ==
                  QueueState.stopped);
          final controlsEnabled = (i == 0) || firstSessionStopped;

          return _SessionAccordion(
            key: ValueKey(queueId),
            session: session,
            sessionIndex: i,
            slotLabel: slotLabel,
            queueState: qs,
            sessionPatients: sessionPatients,
            currentPatient: currentPt,
            waitingPatients: waitingPts,
            isExpanded: isExpanded,
            selected: widget.selected,
            controlsEnabled: controlsEnabled,
            onToggle: () => setState(() => _expanded[queueId] = !isExpanded),
            onStart: widget.onStart,
            onSkip: widget.onSkip,
            onPrescription: widget.onPrescription,
            onCancel: widget.onCancel,
            onSelect: widget.onSelect,
            globalQs: widget.qs,
            onQueueStart: () => widget.onQueueStart(queueId),
            onQueuePause: () => widget.onQueuePause(queueId),
            onQueueStop:  () => widget.onQueueStop(queueId),
          );
        },
      ),
    );
  }

  List<AppointmentList> _patientsForSession(dynamic session, int index, int total) {
    // Only queue patients (bookingType == 1 or null treated as queue)
    final all = widget.todayPatients
        .where((p) => p.bookingType == null || p.bookingType == 1)
        .toList();
    // Match by queue_id: appointment.queueId must equal session.queueId
    final queueId = session.queueId as int?;
    if (queueId != null) {
      return all.where((p) => p.queueId == queueId).toList();
    }
    // Fallback: if no queueId on session, return all (single session case)
    if (total <= 1) return all;
    return [];
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
                              final isQActive  = globalQs == QueueState.running || globalQs == QueueState.paused;
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

  const _LiveQueueCard({
    required this.patients,
    required this.qs,
    required this.onStart,
    required this.onSkip,
    required this.controlsEnabled,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
  });

  @override
  Widget build(BuildContext context) {
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

            // Start / Pause + Stop buttons (hidden when stopped)
            if (!isStopped) ...[
              _QueueIconBtn(
                icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: isRunning ? kAmberDark : kPrimaryDark,
                bg:    isRunning ? kAmberLight : kPrimaryLight,
                enabled: controlsEnabled,
                tooltip: isRunning ? 'Pause' : 'Start',
                onTap: controlsEnabled
                    ? (isRunning ? onQueuePause : onQueueStart)
                    : null,
              ),
              const SizedBox(width: 5),
              _QueueIconBtn(
                icon: Icons.stop_rounded,
                color: kRedDark,
                bg: kRedLight,
                enabled: controlsEnabled,
                tooltip: 'Close queue',
                onTap: controlsEnabled ? onQueueStop : null,
              ),
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
                  const Expanded(
                    child: Text('Slot Bookings',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
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
  final double extraBottom;
  final AppointmentList? selected;
  final void Function(AppointmentList)? onSelect;

  const _PatientListBody({
    required this.patients, required this.tab, required this.qs,
    required this.onStart, required this.onSkip,
    required this.onPrescription, required this.onCancel,
    required this.extraBottom,
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

    final hdrCount = isToday ? 2 : 1;

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
        padding: EdgeInsets.fromLTRB(14, 10, 14, 12 + extraBottom),
        itemCount: displayPatients.length + hdrCount,
        itemBuilder: (ctx, i) {
          if (i == 0 && isToday)
            return _LiveQueueCard(
              patients: patients, qs: qs,
              onStart: onStart, onSkip: onSkip,
              controlsEnabled: true,
              onQueueStart: () {},
              onQueuePause: () {},
              onQueueStop: () {},
            );

          if ((isToday && i == 1) || (!isToday && i == 0)) {
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

          return _PatientCard(
            key: ValueKey(p.appointmentId),
            patient: p, tab: tab,
            accessible: accessible,
            selected: selected?.appointmentId == p.appointmentId,
            onTap: onSelect != null ? () => onSelect!(p) : null,
            onStart: () => onStart(p),
            onSkip: accessible && tab == _Tab.today && status == 'booked' ? () => onSkip(p) : null,
            onPrescription: () => onPrescription(p),
            onCancel: () => onCancel(p),
          );
        },
      ),
    );
  }
}

// ── Search Bar ────────────────────────────────────────────────────────────────
class _SearchBarWidget extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBarWidget({required this.controller});

  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    child: Container(
      height: 40,
      decoration: BoxDecoration(
        color: kBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 11),
          child: Icon(Icons.search_rounded, size: 17, color: kTextMuted),
        ),
        Expanded(
          child: TextField(
            controller: controller,
            style: const TextStyle(fontSize: 13, color: kTextPrimary),
            decoration: const InputDecoration(
              hintText: 'Search by name, status or queue…',
              hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        if (controller.text.isNotEmpty)
          GestureDetector(
            onTap: controller.clear,
            child: Container(
              margin: const EdgeInsets.only(right: 10),
              width: 18, height: 18,
              decoration: const BoxDecoration(color: kTextMuted, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, size: 11, color: Colors.white),
            ),
          ),
      ]),
    ),
  );
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
    padding: const EdgeInsets.fromLTRB(14, 4, 14, 10),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: controller,
        labelColor: kPrimaryDark,
        unselectedLabelColor: kTextSecondary,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.07), blurRadius: 6, offset: const Offset(0, 1)),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(3),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        dividerColor: Colors.transparent,
        tabs: [
          Tab(text: 'Today ($todayCount)'),
          Tab(text: 'Upcoming ($upcomingCount)'),
          Tab(text: 'Done ($completedCount)'),
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
        child: Container(
          height: 36,
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 9),
              child: Icon(Icons.search_rounded, size: 15, color: kTextMuted),
            ),
            Expanded(child: TextField(
              controller: searchCtrl,
              style: const TextStyle(fontSize: 12, color: kTextPrimary),
              decoration: const InputDecoration(
                hintText: 'Search patients…',
                hintStyle: TextStyle(fontSize: 12, color: kTextMuted),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            )),
          ]),
        ),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(children: [
          _SideNavItem(icon: Icons.access_time_rounded, label: 'Today',
              count: todayCount, selected: activeTab == _Tab.today,
              onTap: () => onTabChange(_Tab.today)),
          const SizedBox(height: 4),
          _SideNavItem(icon: Icons.calendar_today_rounded, label: 'Upcoming',
              count: upcomingCount, selected: activeTab == _Tab.upcoming,
              onTap: () => onTabChange(_Tab.upcoming)),
          const SizedBox(height: 4),
          _SideNavItem(icon: Icons.check_circle_outline_rounded,
              label: 'Completed', count: completedCount,
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
  final VoidCallback? onTap, onSkip;
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
          color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? kPrimary : highlightBorder ? const Color(0xFF0E9384) : kBorder,
            width: selected ? 1.5 : highlightBorder ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? kPrimary.withOpacity(0.10)
                  : highlightBorder
                      ? const Color(0xFF0E9384).withOpacity(0.14)
                      : Colors.black.withOpacity(0.03),
              blurRadius: selected || highlightBorder ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: av.bg, borderRadius: BorderRadius.circular(11)),
                  alignment: Alignment.center,
                  child: Text(
                    _inits,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: av.fg),
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        patient.patientName ?? 'Patient',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 1),
                      Text(_info, style: const TextStyle(fontSize: 10, color: kTextSecondary)),
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
                  const SizedBox(width: 6),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        (patient.queueNumber ?? 0).toString().padLeft(2, '0'),
                        style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: av.fg, height: 1),
                      ),
                      const Text('Token', style: TextStyle(fontSize: 9, color: kTextMuted)),
                    ],
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
                      onTap: () {},
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
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );
}

class _DotChip extends StatelessWidget {
  final String label;
  final Color bg, fg, dot;
  const _DotChip({required this.label, required this.bg, required this.fg, required this.dot});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
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
        padding: const EdgeInsets.symmetric(vertical: 9),
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
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      ),
    ),
  );
}

class _QueueStateBadge extends StatelessWidget {
  final QueueState state;
  const _QueueStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg, Color dot) = switch (state) {
      QueueState.running => ('Running', kPrimaryLighter, kPrimaryDark, kPrimary),
      QueueState.paused  => ('Paused',  kAmberLight,    kAmberDark,   kWarning),
      QueueState.stopped => ('Closed',
          const Color(0xFFF3F4F6), const Color(0xFF6B7280), const Color(0xFF9CA3AF)),
      QueueState.idle    => ('Idle', kRedLight, kRedDark, kError),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
      ]),
    );
  }
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
