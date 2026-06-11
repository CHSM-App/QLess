import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_patient_history.dart';
import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

const kPrimary        = Color(0xFF26C6B0);
const kPrimaryDark    = Color(0xFF2BB5A0);
const kPrimaryLight   = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary    = Color(0xFF2D3748);
const kTextSecondary  = Color(0xFF718096);
const kTextMuted      = Color(0xFFA0AEC0);

const kBorder         = Color(0xFFEDF2F7);

const kGreen          = Color(0xFF68D391);
const kGreenDark      = Color(0xFF276749);
const kGreenLight     = Color(0xFFF0FFF8);
const kGreenBorder    = Color(0xFFC6F6D5);

const kAmber          = Color(0xFFF6AD55);
const kAmberDark      = Color(0xFF975A16);
const kAmberLight     = Color(0xFFFFFBEB);
const kAmberBorder    = Color(0xFFFCEFC7);

const kRed            = Color(0xFFFC8181);
const kRedDark        = Color(0xFFC53030);
const kRedLight       = Color(0xFFFFF5F5);
const kRedBorder      = Color(0xFFFED7D7);

const kPurple         = Color(0xFF9F7AEA);
const kPurpleDark     = Color(0xFF6B46C1);
const kPurpleLight    = Color(0xFFFAF5FF);
const kPurpleBorder   = Color(0xFFE9D5FF);

// ── Premium medical surface tokens ──────────────────────────────────────────
const kSurface         = Colors.white;
const kSurfaceTinted   = Color(0xFFF7FDFC);
const kBackgroundTop   = Color(0xFFEAF8F5);
const kBackgroundBot   = Color(0xFFFBFDFC);
const kHairline        = Color(0xFFE8EEF1);

const List<BoxShadow> kSoftShadow  = <BoxShadow>[];
const List<BoxShadow> kFloatShadow = <BoxShadow>[];
const List<BoxShadow> kInsetShadow = <BoxShadow>[];

const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient kCardGlassGradient = LinearGradient(
  colors: [Colors.white, Color(0xFFFBFEFD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});

  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR TIPS  (auto-rotating carousel)
// ─────────────────────────────────────────────────────────────────────────────

class _Tip {
  final String emoji;
  final String title;
  final String body;
  const _Tip(this.emoji, this.title, this.body);
}

const List<_Tip> _kDoctorTips = [
  _Tip('⏸', 'Pause Queue',
      'Tap Pause anytime to take a quick break — patients see the live status update instantly.'),
  _Tip('⚠️', 'Emergency Pause',
      'Use the warning icon for urgent breaks — the queue order stays intact when you resume.'),
  _Tip('⏭', 'Skip a Patient',
      'No-show? Tap Skip to move on. Skipped patients can rejoin with a fresh token.'),
  _Tip('🗓', 'Set Your Schedule',
      'Use Edit Schedule to add weekly time slots, max queue length and slot duration.'),
  _Tip('💊', 'Build Medicine Library',
      'Add common medicines once in Edit Medicine — pick them faster while prescribing.'),
  _Tip('📋', 'Patient History',
      'Open Patient History to review past visits, prescriptions and notes in one place.'),
  _Tip('🔄', 'Pull to Refresh',
      'Swipe down on the home screen to fetch the latest queue and appointment status.'),
  _Tip('✕', 'Close the Queue',
      'Tap Close at the end of a session — frees the slot and updates today\'s stats.'),
];

class _QueueHomePageState extends ConsumerState<QueueHomePage> {
  bool _hasFetched = false;
  bool _showAllWaiting = false;
  late final ProviderSubscription<int?> _doctorIdSub;

  // ── Tips carousel state ────────────────────────────────────────────────
  final PageController _tipsController = PageController();
  int _currentTip = 0;
  Timer? _tipsTimer;

  @override
  void initState() {
    super.initState();
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) {
        if (next != null && next > 0) _loadData();
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
    _tipsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_tipsController.hasClients) return;
      final next = (_currentTip + 1) % _kDoctorTips.length;
      _tipsController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _tipsTimer?.cancel();
    _tipsController.dispose();
    _doctorIdSub.close();
    super.dispose();
  }

  int get _doctorId =>
      ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  String get _doctorName =>
      ref.read(doctorLoginViewModelProvider).name ?? 'Doctor';

  Future<void> _loadData({bool force = false}) async {
    if (_doctorId == 0) return;
    if (_hasFetched && !force) return;
    _hasFetched = true;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId);
    await Future.wait([
      ref
          .read(appointmentViewModelProvider.notifier)
          .fetchPatientAppointments(_doctorId),
      ref
          .read(doctorSettingsViewModelProvider.notifier)
          .getDoctorSchedule(_doctorId),
    ]);
  }

  Future<void> _refreshData() => _loadData(force: true);
  

  // ── Queue filters ─────────────────────────────────────────────────────────

  List<AppointmentList> _todayQueue(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'booked') return false;
      if (a.bookingType != 1) return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
  }

  List<AppointmentList> _waitingList(List<AppointmentList> queue) =>
      queue.length > 1 ? queue.skip(1).toList() : [];

  List<AppointmentList> _completedToday(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'completed') return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
  }

  List<AppointmentList> _skippedToday(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'skipped') return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).toList();
  }

  // All of today's appointments regardless of status (for "Total" stat).
  int _todayTotalCount(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year &&
          d.month == today.month &&
          d.day == today.day;
    }).length;
  }

  // Last 7 days completed-count series (oldest first, today last).
  List<({DateTime date, int count})> _lastSevenDaysCompleted(
      List<AppointmentList> all) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(const Duration(days: 6));
    final out = <({DateTime date, int count})>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final n = all.where((a) {
        if ((a.status?.toLowerCase() ?? '') != 'completed') return false;
        final ad = DateTime.tryParse(a.appointmentDate ?? '');
        if (ad == null) return false;
        return ad.year == d.year && ad.month == d.month && ad.day == d.day;
      }).length;
      out.add((date: d, count: n));
    }
    return out;
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: kPrimaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = kPrimaryDark,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(fontSize: 13.5, color: kTextSecondary, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Queue actions ─────────────────────────────────────────────────────────

  Future<void> _onQueueStart(int? queueId) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue started');
      await _refreshData();
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  // Resume a paused queue → start it again, then jump straight to the
  // Patient List tab so the doctor can continue seeing patients.
  Future<void> _onQueueResume(int? queueId) async {
    await _onQueueStart(queueId);
    if (!mounted) return;
    ref.read(doctorNavTabRequestProvider.notifier).state =
        kDoctorPatientListTab;
  }

  Future<void> _onQueuePause(int? queueId) async {
    final ok = await _confirm(
      title: 'Pause Queue?',
      message: 'Waiting patients will be notified that the queue is paused. '
               'You can resume any time.',
      confirmLabel: 'Pause',
      confirmColor: kAmberDark,
    );
    if (!ok) return;

    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
      await _refreshData();
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue closed');
      await _refreshData();
    } catch (_) {
      _snack('Failed to close queue');
    }
  }

  Future<void> _onQueueNext(AppointmentList current) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueNext(AppointmentRequestModel(
            doctorId: _doctorId,
            appointmentId: current.appointmentId ?? 0,
          ));
      _snack(res.message ?? 'Next patient');
    } catch (_) {
      _snack('Failed');
    }
  }

  Future<void> _onQueueSkip(AppointmentList current) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueSkip(AppointmentRequestModel(
            doctorId: _doctorId,
            appointmentId: current.appointmentId ?? 0,
          ));
      _snack(res.message ?? 'Patient skipped');
    } catch (_) {
      _snack('Failed to skip');
    }
  }

  // Confirmation happens in the custom dialog at the caller site
  // (see "Emergency Pause?" dialog below). No second confirm here.
  Future<void> _onQueuePauseEmergency(int? queueId) async {
    if (queueId == null) {
      _snack('Queue ID not available');
      return;
    }

    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePauseEmergency(queueId);
      _snack(res.message ?? 'Queue paused (emergency)');
      await _refreshData();
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    return d == null ? null : DateTime.now().year - d.year;
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0] : '')
      .join()
      .toUpperCase();

  QueueState _sessionQueueState(int? status) {
    switch (status) {
      case 1: return QueueState.running;
      case 2: return QueueState.paused;
      case 3: return QueueState.stopped;
      default: return QueueState.idle;
    }
  }

  AppointmentList? _findCurrentPatient(List<AppointmentList> all, int? appointmentId) {
    if (appointmentId == null || appointmentId == 0) return null;
    try {
      return all.firstWhere((a) => a.appointmentId == appointmentId);
    } catch (_) {
      return null;
    }
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toUtc();
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return raw;
    }
  }

  // Format "HH:MM:SS" time-of-day strings from the schedule API.
  String _fmtScheduleTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final parts = raw.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
    } catch (_) {
      return raw;
    }
  }

  String _bookingModeLabel(int? mode) {
    switch (mode) {
      case 2: return 'Slots';
      case 3: return 'Queue + Slots';
      default: return 'Queue';
    }
  }

  // Today's enabled slots from the doctor's weekly schedule.
  List<TimeSlotModel> _todayScheduledSlots() {
    final schedule = ref.read(doctorSettingsViewModelProvider).doctorSchedule;
    final days = schedule?.schedule;
    if (days == null || days.isEmpty) return [];
    final todayName = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
    for (final d in days) {
      if ((d.day ?? '').toLowerCase() == todayName) {
        if ((d.isEnabled ?? 0) != 1) return [];
        final slots = d.slots ?? [];
        return [...slots]..sort((a, b) =>
            (a.startTime ?? '').compareTo(b.startTime ?? ''));
      }
    }
    return [];
  }

  // ── FILTER: which sessions to show as cards ───────────────────────────────
  // Hide a session when:
  //   • queue_date is before today → a previous-day session the doctor never
  //     closed. The live API already drops these, but the OFFLINE cache keeps
  //     serving yesterday's session on a next-day refresh — guard it here so it
  //     never renders as if it were today's.
  //   • queue_status == 0 (idle) AND start_time == null  → no slot assigned yet, skip it
  //   • queue_status == 3 (stopped/closed)               → hide closed queues
  bool _shouldShowSession(dynamic session) {
    if (_isStaleQueueDate(session.queueDate as String?)) return false; // past day → hide
    final qs = session.queueStatus ?? 0;
    final hasSlot = session.startTime != null;
    if (qs == 3) return false;               // closed → hide
    if (qs == 0 && !hasSlot) return false;   // idle + no time slot → hide
    return true;
  }

  // True when a session's queue_date is before today (compared by calendar day).
  // Null/unparseable dates are treated as not-stale so live rows aren't dropped.
  bool _isStaleQueueDate(String? queueDate) {
    final d = DateTime.tryParse(queueDate ?? '');
    if (d == null) return false;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .isBefore(DateTime(now.year, now.month, now.day));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
            ? 'Good Afternoon 👋'
            : 'Good Evening 👋';

    final vmState           = ref.watch(appointmentViewModelProvider);
    final appointmentsAsync = vmState.patientAppointmentsList;

    // Watch settings so the page rebuilds when today's schedule loads.
    ref.watch(doctorSettingsViewModelProvider
        .select((s) => s.doctorSchedule));

    final doctorName = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'),
    );

    return Scaffold(
      backgroundColor: Colors.white,
      body: appointmentsAsync.when(
        loading: () => _buildLoadingBody(greeting, doctorName),
        error: (e, _) => _buildErrorBody(e, greeting, doctorName),
        data: (list) {
          final todayQueue = _todayQueue(list);
          final current    = todayQueue.isNotEmpty ? todayQueue.first : null;
          final waiting    = _waitingList(todayQueue);
          final completed  = _completedToday(list);
          final skipped    = _skippedToday(list);

          // All today's sessions from API
          final allSessions = vmState.todayQueueResult?.value ?? [];
          

          // Filter: only show sessions that should be visible
          final visibleSessions = allSessions.where(_shouldShowSession).toList();

          // Limit waiting list
          final visibleWaiting = _showAllWaiting
              ? waiting
              : waiting.take(3).toList();

          final totalToday = _todayTotalCount(list);

          return _buildRefreshableScrollView(
            slivers: [
              // ── HEADER ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(greeting, doctorName),
              ),

              // ── TODAY'S STATS STRIP ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _buildStatStrip(
                    total:   totalToday,
                    waiting: waiting.length + (current != null ? 1 : 0),
                    done:    completed.length,
                    skipped: skipped.length,
                  ),
                ),
              ),

              // ── TODAY'S SCHEDULE CARD  (always shown when slots exist)
              // if (_todayScheduledSlots().isNotEmpty)
              //   SliverToBoxAdapter(
              //     child: Padding(
              //       padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //       child:
              //           _buildTodayScheduleCard(_todayScheduledSlots()),
              //     ),
              //   ),

              // ── SESSION QUEUE CARDS / EMPTY STATE ───────────────────
              if (visibleSessions.isEmpty) ...[
                if (_todayScheduledSlots().isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildNoLiveSessions(),
                    ),
                  ),
              ] else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final session   = visibleSessions[i];
                        final qs        = _sessionQueueState(session.queueStatus);
                        final currentPt = _findCurrentPatient(list, session.currentServing);
                        final nextQNo   = session.currentQueueNo != null &&
                                session.currentQueueNo! < (session.totalQueue ?? 0)
                            ? session.currentQueueNo! + 1
                            : null;
                        final slotLbl = (session.startTime != null)
                            ? '${_fmtTime(session.startTime)} – ${_fmtTime(session.endTime)}'
                            : null;

                        // ── Per-session stat strip ───────────────────
                        // Skipped count not in TodayQueueModel — derive from
                        // today's appointments filtered by this session's queueId.
                        final sessionSkipped   = skipped
                            .where((a) => a.queueId == session.queueId)
                            .length;
                        final sessionTotal     = session.totalQueue ?? 0;
                        final sessionDone      = session.completedCount ?? 0;
                        final sessionServing   = (session.currentServing ?? 0) > 0 ? 1 : 0;
                        final sessionWaiting   = (sessionTotal - sessionDone - sessionServing - sessionSkipped)
                            .clamp(0, sessionTotal);

                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i < visibleSessions.length - 1 ? 8 : 0),
                          child: _buildQueueCard(
                            current:          currentPt,
                            nextQueueNo:      nextQNo,
                            total:            sessionTotal,
                            done:             sessionDone,
                            sessionWaiting:   sessionWaiting,
                            sessionSkipped:   sessionSkipped,
                            queueState:       qs,
                            queueId:          session.queueId,
                            slotLabel:        slotLbl,
                            isOnlySession:    i == 0, // first session always full card
                          ),
                        );
                      },
                      childCount: visibleSessions.length,
                    ),
                  ),
                ),

              // ── WEEKLY PERFORMANCE CHART ─────────────────────────────
              // SliverToBoxAdapter(
              //   child: Padding(
              //     padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
              //     child: _buildWeeklyPerformance(list),
              //   ),
              // ),

              // ── QUICK ACTIONS ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _buildHomeQuickActions(),
                ),
              ),

              // ── DOCTOR TIPS CAROUSEL ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _buildTipsCarousel(),
                ),
              ),

              // ── UPCOMING LIST HEADER ─────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                  child: _sectionHeader(
                    'Upcoming',
                    waiting.length,
                    kPrimary,
                    kPrimaryLight,
                    kPrimaryDark,
                  ),
                ),
              ),

              // ── WAITING PATIENT CARDS ────────────────────────────────
              waiting.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          decoration: BoxDecoration(
                            gradient: kCardGlassGradient,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: kHairline),
                            boxShadow: kSoftShadow,
                          ),
                          child: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 44,
                                  height: 44,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [kPrimaryLight, Colors.white],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kPrimaryLight),
                                  ),
                                  child: const Icon(Icons.inbox_rounded,
                                      color: kPrimary, size: 20),
                                ),
                                const SizedBox(height: 8),
                                const Text(
                                  'No Upcoming Patients',
                                  style: TextStyle(
                                    color: kTextSecondary,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.1,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                const Text(
                                  'New bookings will appear here',
                                  style: TextStyle(
                                    color: kTextMuted,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: _patientCard(visibleWaiting[i]),
                          ),
                          childCount: visibleWaiting.length,
                        ),
                      ),
                    ),

              // ── SHOW ALL / SHOW LESS ─────────────────────────────────
              if (waiting.length > 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showAllWaiting = !_showAllWaiting),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [kPrimaryLight, kPrimaryLighter],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kPrimary.withOpacity(0.2)),
                        ),
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _showAllWaiting
                                  ? 'Show Less'
                                  : 'Show All  (${waiting.length - 3} more)',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                                color: kPrimaryDark,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllWaiting
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: kPrimaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              // ── RECENTLY SEEN ────────────────────────────────────────
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: _sectionHeader(
                      'Recently Seen',
                      completed.length,
                      kGreen,
                      kGreenLight,
                      kGreenDark,
                    ),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _patientCard(completed.take(5).toList()[i]),
                      ),
                      childCount:
                          completed.length > 5 ? 5 : completed.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING / ERROR BODIES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRefreshableScrollView({
    required List<Widget> slivers,
  }) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  Widget _buildLoadingBody(String greeting, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          ),
        ],
      );

  Widget _buildErrorBody(Object e, String greeting, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),
          SliverFillRemaining(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: kRedLight,
                        shape: BoxShape.circle,
                        border: Border.all(color: kRedBorder)),
                    child:
                        const Icon(Icons.error_outline, color: kRed, size: 22),
                  ),
                  const SizedBox(height: 10),
                  Text('$e',
                      style:
                          const TextStyle(color: kTextMuted, fontSize: 12)),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: _refreshData,
                    style: TextButton.styleFrom(foregroundColor: kPrimary),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(String greeting, String doctorName) {
    final initials = _initials(doctorName);
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(1.5),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: kPrimaryGradient,
              ),
              child: Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: ShaderMask(
                  shaderCallback: (b) => kPrimaryGradient.createShader(b),
                  child: Text(
                    initials,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.4,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    greeting,
                    style: const TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.1,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    'Dr. $doctorName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                      letterSpacing: -0.3,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: kPrimary.withOpacity(0.18)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: const BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    DateFormat('d MMM').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryDark,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
            // const SizedBox(width: 6),
            // Container(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            //   decoration: BoxDecoration(
            //     gradient: kPrimaryGradient,
            //     borderRadius: BorderRadius.circular(20),
            //   ),
            //   child: Row(
            //     mainAxisSize: MainAxisSize.min,
            //     children: const [
            //       Icon(Icons.verified_rounded,
            //           color: Colors.white, size: 11),
            //       SizedBox(width: 3),
            //       Text(
            //         'Pro',
            //         style: TextStyle(
            //           fontSize: 10,
            //           fontWeight: FontWeight.w800,
            //           color: Colors.white,
            //           letterSpacing: 0.3,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }


//notification icon
  // Widget _headerBtn({
  //   required IconData icon,
  //   bool badge = false,
  //   required VoidCallback onTap,
  // }) {
  //   return GestureDetector(
  //     onTap: onTap,
  //     child: Stack(children: [
  //       Container(
  //         width: 36,
  //         height: 36,
  //         decoration: BoxDecoration(
  //           color: const Color(0xFFF7F8FA),
  //           borderRadius: BorderRadius.circular(10),
  //           border: Border.all(color: kBorder),
  //         ),
  //         child: Icon(icon, color: kTextPrimary, size: 17),
  //       ),
  //       if (badge)
  //         Positioned(
  //           right: 7,
  //           top: 7,
  //           child: Container(
  //             width: 7,
  //             height: 7,
  //             decoration:
  //                 const BoxDecoration(color: kAmber, shape: BoxShape.circle),
  //           ),
  //         ),
  //     ]),
  //   );
  // }

  // ─────────────────────────────────────────────────────────────────────────
  // STAT STRIP  (global across all sessions)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatStrip({
    required int total,
    required int waiting,
    required int done,
    required int skipped,
  }) {
    return Row(children: [
      _statCard(
          icon: Icons.groups_2_rounded,
          label: 'Total',
          value: total.toString().padLeft(2, '0'),
          accent: kPrimary,
          valueColor: kTextPrimary),
      const SizedBox(width: 7),
      _statCard(
          icon: Icons.hourglass_top_rounded,
          label: 'Waiting',
          value: waiting.toString().padLeft(2, '0'),
          accent: kPrimary,
          valueColor: kPrimaryDark),
      const SizedBox(width: 7),
      _statCard(
          icon: Icons.check_circle_rounded,
          label: 'Done',
          value: done.toString().padLeft(2, '0'),
          accent: kGreen,
          valueColor: kGreenDark),
      const SizedBox(width: 7),
      _statCard(
          icon: Icons.skip_next_rounded,
          label: 'Skipped',
          value: skipped.toString().padLeft(2, '0'),
          accent: kAmber,
          valueColor: kAmberDark),
    ]);
  }

  Widget _statCard({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          gradient: kCardGlassGradient,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: kHairline),
          boxShadow: kSoftShadow,
        ),
        padding: const EdgeInsets.fromLTRB(8, 7, 8, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: accent.withOpacity(0.18)),
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, size: 11, color: accent),
                ),
                const Spacer(),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                    letterSpacing: 0.1,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 19,
                fontWeight: FontWeight.w800,
                color: valueColor,
                height: 1,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE QUEUE CARD
  // When idle (queue_status == 0 but has a slot) → compact card (screenshot style)
  // When running/paused → full card with patient info, token row, actions
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQueueCard({
    required AppointmentList? current,
    required int? nextQueueNo,
    required int total,
    required int done,
    required int sessionWaiting,
    required int sessionSkipped,
    required QueueState queueState,
    int? queueId,
    String? slotLabel,
    bool isOnlySession = false,  // true when all other sessions are closed/hidden
  }) {
    final isIdle    = queueState == QueueState.idle;
    final isRunning = queueState == QueueState.running;
    final isStopped = queueState == QueueState.stopped;
    final isPaused  = queueState == QueueState.paused;
    // Emergency-paused reads as "paused" but hides Close — the queue must be
    // resumed (or normally paused) before it can be closed.
    final isEmergency = ref
        .read(appointmentViewModelProvider.notifier)
        .isEmergencyPaused(queueId);

    // Highlighted border so the live queue card stands out from
    // surrounding stat strips / sections — state-driven accent.
    final Color borderColor = isRunning
        ? kPrimary.withOpacity(0.55)
        : isPaused
            ? kAmber.withOpacity(0.65)
            : isStopped
                ? kHairline
                : kPrimary.withOpacity(0.25); // idle
    final double borderWidth = (isRunning || isPaused) ? 1.6 : 1.0;
    final List<BoxShadow> cardShadow = isRunning
        ? [
            BoxShadow(
              color: kPrimary.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ]
        : isPaused
            ? [
                BoxShadow(
                  color: kAmber.withOpacity(0.14),
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ]
            : kSoftShadow;

    // ── COMPACT CARD for Idle sessions with siblings present ──────────────
    if (isIdle && !isOnlySession) {
      return Container(
        decoration: BoxDecoration(
          gradient: kCardGlassGradient,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
          boxShadow: cardShadow,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _pulseDot(),
              const SizedBox(width: 5),
              _queueStateBadge(queueState),
              const Spacer(),
              if (slotLabel != null) _slotPill(slotLabel),
            ]),
            const SizedBox(height: 10),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              const Text('Daily progress',
                  style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.2)),
              Text('$done / $total seen',
                  style: const TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: kPrimaryDark)),
            ]),
            const SizedBox(height: 5),
            _gradientProgress(total == 0 ? 0 : (done / total).clamp(0.0, 1.0)),
          ],
        ),
      );
    }

    // ── FULL CARD for Running / Paused sessions ────────────────────────────
    return Container(
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: cardShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pulseDot(),
          const SizedBox(width: 5),
          _queueStateBadge(queueState),
          const Spacer(),
          if (slotLabel != null) _slotPill(slotLabel),
        ]),
        const SizedBox(height: 10),
        _buildSessionMiniStats(
          total:   total,
          waiting: sessionWaiting,
          done:    done,
          skipped: sessionSkipped,
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Daily progress',
              style: TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary,
                  letterSpacing: 0.2)),
          Text('$done / $total seen',
              style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                  color: kPrimaryDark)),
        ]),
        const SizedBox(height: 5),
        _gradientProgress(total == 0 ? 0 : (done / total).clamp(0.0, 1.0)),
        const SizedBox(height: 10),

        Row(children: [
          Expanded(
            child: _actionBtn(
              label: isRunning
                  ? 'Pause'
                  : isPaused
                      ? 'Resume'
                      : 'Start',
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onTap: isRunning
                  ? () => _onQueuePause(queueId)
                  : isPaused
                      ? () => _onQueueResume(queueId)
                      : () => _onQueueStart(queueId),
              isPrimary: !isRunning,
            ),
          ),
          // Close is hidden while emergency-paused.
          if (!isEmergency) ...[
          const SizedBox(width: 6),
          Expanded(
            child: Opacity(
              // Close is only valid once the queue is live (running/paused).
              // Before Start (idle) or after Stop it stays disabled.
              opacity: (isStopped || isIdle) ? 0.4 : 1.0,
              child: GestureDetector(
                onTap: (isStopped || isIdle)
                    ? null
                    : () => _showCloseDialog(queueId),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: kRedBorder),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.close_rounded, size: 13, color: kRedDark),
                      SizedBox(width: 4),
                      Text(
                        'Close',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: kRedDark,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showEmergencyDialog(queueId),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 11),
              decoration: BoxDecoration(
                color: kPurpleLight,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: kPurpleBorder),
              ),
              child: const Icon(Icons.warning_amber_rounded,
                  color: kPurpleDark, size: 16),
            ),
          ),
        ]),
      ]),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────────────────

  Future<void> _showCloseDialog(int? queueId) async {
    // Mirror the patient-list close flow: count every patient that closing
    // will cancel — this queue's pending (booked / in_progress), its skipped,
    // and earlier-time slot patients still pending — and warn only when > 0.
    final vmState     = ref.read(appointmentViewModelProvider);
    final appts       = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final sessions    = vmState.todayQueueResult?.value ?? [];

    final matchingSession = sessions.where((s) => s.queueId == queueId).toList();
    final queueStartTime  = matchingSession.isEmpty
        ? null
        : DateTime.tryParse(matchingSession.first.startTime ?? '');

    final queuePending = appts.where((p) {
      if (p.queueId != queueId) return false;
      final st = (p.status?.toLowerCase() ?? '');
      return st == 'booked' || st == 'in_progress';
    }).length;

    final queueSkipped = appts.where((p) {
      if (p.queueId != queueId) return false;
      return (p.status?.toLowerCase() ?? '') == 'skipped';
    }).length;

    final earlierSlotPending = queueStartTime == null
        ? 0
        : appts.where((p) {
            if (p.bookingType != 2) return false;
            final st = (p.status?.toLowerCase() ?? '');
            if (st != 'booked' && st != 'skipped') return false;
            final pTime = DateTime.tryParse(p.startTime ?? '');
            return pTime != null && pTime.isBefore(queueStartTime);
          }).length;

    final totalCancel = queuePending + queueSkipped + earlierSlotPending;
    final confirmed = await showDialog<bool>(
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
                  color: kRedLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: kRedBorder)),
              child: const Icon(Icons.close_rounded, color: kRed, size: 26),
            ),
            const SizedBox(height: 14),
            const Text(
              'Close Queue?',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
            ),
            const SizedBox(height: 8),
            const Text(
              'Are you sure you want to close this queue?',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12, color: kTextSecondary, height: 1.5),
            ),
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
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRedBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Text('Yes, Close',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kRedDark)),
                ),
              ),
            ),
          ]),
        ],
      ),
    );
    if (confirmed == true) await _onQueueStop(queueId);
  }

  Future<void> _showEmergencyDialog(int? queueId) async {
    if (ref.read(appointmentViewModelProvider.notifier)
        .isEmergencyPaused(queueId)) {
      _snack('Already emergency paused');
      return;
    }
    final confirmed = await showDialog<bool>(
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
    if (confirmed == true) await _onQueuePauseEmergency(queueId);
  }

  // ── Session mini stat strip (inside each card) ─────────────────────────

  Widget _buildSessionMiniStats({
    required int total,
    required int waiting,
    required int done,
    required int skipped,
  }) {
    return Row(children: [
      _miniStatChip(label: 'Total',   value: total,   accent: kPrimary,   textColor: kPrimaryDark),
      const SizedBox(width: 5),
      _miniStatChip(label: 'Waiting', value: waiting, accent: kPrimary,   textColor: kPrimaryDark),
      const SizedBox(width: 5),
      _miniStatChip(label: 'Done',    value: done,    accent: kGreen,     textColor: kGreenDark),
      const SizedBox(width: 5),
      _miniStatChip(label: 'Skipped', value: skipped, accent: kAmber,     textColor: kAmberDark),
    ]);
  }

  Widget _miniStatChip({
    required String label,
    required int value,
    required Color accent,
    required Color textColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 6, 8, 7),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent.withOpacity(0.10), accent.withOpacity(0.04)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 8,
                fontWeight: FontWeight.w700,
                color: textColor.withOpacity(0.75),
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value.toString().padLeft(2, '0'),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: textColor,
                height: 1,
                letterSpacing: -0.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionBtn({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          gradient: isPrimary ? kPrimaryGradient : null,
          color: isPrimary ? null : kAmberLight,
          borderRadius: BorderRadius.circular(11),
          border: isPrimary ? null : Border.all(color: kAmberBorder),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon,
                  size: 14,
                  color: isPrimary ? Colors.white : kAmberDark),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
                color: isPrimary ? Colors.white : kAmberDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTokenRow({
    required int currentNo,
    required int nextNo,
    required int total,
  }) {
    return Row(children: [
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.all(Radius.circular(13)),
          ),
          child: Column(children: [
            const Text('Current',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: Colors.white70)),
            const SizedBox(height: 3),
            Text(currentNo.toString().padLeft(2, '0'),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: kPrimaryLighter,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kPrimaryLight),
          ),
          child: Column(children: [
            const Text('Up Next',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: kTextSecondary)),
            const SizedBox(height: 3),
            Text(nextNo > 0 ? nextNo.toString().padLeft(2, '0') : '--',
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    height: 1)),
          ]),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: kGreenLight,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: kGreenBorder),
          ),
          child: Column(children: [
            const Text('Remaining',
                style: TextStyle(
                    fontSize: 8,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.7,
                    color: kGreenDark)),
            const SizedBox(height: 3),
            Text(total.toString().padLeft(2, '0'),
                style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: kGreenDark,
                    height: 1)),
          ]),
        ),
      ),
    ]);
  }

  Widget _buildCurrentPatientBand(AppointmentList? patient) {
    if (patient == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: kPrimaryLight),
        ),
        child: const Center(
            child: Text('No patients in queue today',
                style: TextStyle(color: kTextMuted, fontSize: 12))),
      );
    }

    final name     = patient.patientName ?? patient.bookingFor ?? 'Unknown';
    final age      = _calcAge(patient.dob);
    final initials = _initials(name);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kPrimaryLighter,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kPrimaryLight),
      ),
      child: Row(children: [
        Stack(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: Colors.white)),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: kGreen,
                shape: BoxShape.circle,
                border: Border.all(color: kPrimaryLighter, width: 2),
              ),
            ),
          ),
        ]),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 2),
                Text(
                  [
                    if (patient.gender != null) patient.gender!,
                    if (age != null) '$age yrs',
                    'Token ${(patient.queueNumber ?? 0).toString().padLeft(2, '0')}',
                  ].join(' · '),
                  style: const TextStyle(fontSize: 10, color: kTextSecondary),
                ),
                const SizedBox(height: 5),
                Row(children: [
                  Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: kPrimary, shape: BoxShape.circle)),
                  const SizedBox(width: 4),
                  const Text('In Consultation',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: kPrimaryDark)),
                ]),
              ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: kPrimary, borderRadius: BorderRadius.circular(8)),
          child: const Text('Now',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions(AppointmentList? current) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Quick Actions',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
                color: kPrimary)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: _quickBtn(
              label: '✓  Mark Complete',
              bg: kGreenLight,
              fg: kGreenDark,
              border: kGreenBorder,
              enabled: current != null,
              onTap: current != null ? () => _onQueueNext(current) : null,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _quickBtn(
              label: '⏭  Skip Patient',
              bg: kAmberLight,
              fg: kAmberDark,
              border: kAmberBorder,
              enabled: current != null,
              onTap: current != null ? () => _onQueueSkip(current) : null,
            ),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          _shortcutTile(
              icon: Icons.folder_open_rounded,
              label: 'Records',
              bg: kGreenLight,
              fg: kGreenDark,
              border: kGreenBorder),
          const SizedBox(width: 6),
          _shortcutTile(
              icon: Icons.medication_rounded,
              label: 'Prescribe',
              bg: kPurpleLight,
              fg: kPurpleDark,
              border: kPurpleBorder),
          const SizedBox(width: 6),
          _shortcutTile(
              icon: Icons.calendar_today_rounded,
              label: 'Schedule',
              bg: kAmberLight,
              fg: kAmberDark,
              border: kAmberBorder),
          const SizedBox(width: 6),
          _shortcutTile(
              icon: Icons.notifications_rounded,
              label: 'Notify',
              bg: kRedLight,
              fg: kRedDark,
              border: kRedBorder),
        ]),
      ]),
    );
  }

  Widget _quickBtn({
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
    required bool enabled,
    required VoidCallback? onTap,
  }) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.42,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 11),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(label,
              style: TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700, color: fg)),
        ),
      ),
    );
  }

  Widget _shortcutTile({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: border),
        ),
        child: Column(children: [
          Icon(icon, size: 18, color: fg),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOME QUICK ACTIONS  (Edit Medicine, Schedule, History)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHomeQuickActions() {
    return Container(
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHairline),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 3,
                height: 12,
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 7),
              const Text(
                'Quick Actions',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.3,
                  color: kTextPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(children: [
            _homeActionTile(
              icon: Icons.medication_rounded,
              label: 'Add\nMedicine',
              accent: kPurple,
              bg: kPurpleLight,
              fg: kPurpleDark,
              border: kPurpleBorder,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const AddMedicinePage()),
              ),
            ),
            const SizedBox(width: 7),
            _homeActionTile(
              icon: Icons.calendar_today_rounded,
              label: 'Edit\nSchedule',
              accent: kAmber,
              bg: kAmberLight,
              fg: kAmberDark,
              border: kAmberBorder,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DoctorAvailabilityPage()),
              ),
            ),
            const SizedBox(width: 7),
            _homeActionTile(
              icon: Icons.history_rounded,
              label: 'Patient\nHistory',
              accent: kGreen,
              bg: kGreenLight,
              fg: kGreenDark,
              border: kGreenBorder,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DoctorPatientHistoryScreen()),
              ),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _homeActionTile({
    required IconData icon,
    required String label,
    required Color accent,
    required Color bg,
    required Color fg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 9, 6, 9),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [bg, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 15, color: fg),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                height: 1.15,
                fontWeight: FontWeight.w800,
                color: fg,
                letterSpacing: 0.1,
              ),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // TODAY'S SCHEDULE CARD  (single unified card with day + slots + edit)
  // Shown when no live queue sessions exist for today.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTodayScheduleCard(List<TimeSlotModel> slots) {
    final dayLabel =
        DateFormat('EEEE, d MMMM').format(DateTime.now());

    return Container(
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHairline),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.circular(9),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.calendar_today_rounded,
                  size: 14, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dayLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                      letterSpacing: -0.1,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    "${slots.length} slot${slots.length == 1 ? '' : 's'} scheduled",
                    style: const TextStyle(
                      fontSize: 10,
                      color: kTextSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const DoctorAvailabilityPage()),
              ),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimaryLight, kPrimaryLighter],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: kPrimary.withOpacity(0.22)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.edit_calendar_rounded,
                        size: 11, color: kPrimaryDark),
                    SizedBox(width: 3),
                    Text(
                      'Edit',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: kPrimaryDark,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
          const SizedBox(height: 10),
          Container(
            height: 1,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  kHairline.withOpacity(0),
                  kHairline,
                  kHairline.withOpacity(0),
                ],
              ),
            ),
          ),
          const SizedBox(height: 9),
          ...List.generate(slots.length, (i) {
            final slot = slots[i];
            final isLast = i == slots.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 6),
              child: _scheduleSlotRow(slot),
            );
          }),
        ],
      ),
    );
  }

  Widget _scheduleSlotRow(TimeSlotModel slot) {
    final timeLabel = '${_fmtScheduleTime(slot.startTime)} – '
        '${_fmtScheduleTime(slot.endTime)}';
    final modeLbl = _bookingModeLabel(slot.bookingMode);
    final isQueueMode = slot.bookingMode == 1 || slot.bookingMode == 3;
    final detail = isQueueMode
        ? (slot.maxQueueLength != null ? 'Max ${slot.maxQueueLength}' : null)
        : (slot.slotDuration != null ? '${slot.slotDuration}m' : null);

    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [kPrimaryLighter, Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: kPrimaryLight.withOpacity(0.7)),
      ),
      child: Row(children: [
        Container(
          width: 3,
          height: 18,
          decoration: BoxDecoration(
            gradient: kPrimaryGradient,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            timeLabel,
            style: const TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              letterSpacing: -0.1,
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
          decoration: BoxDecoration(
            color: kPrimary.withOpacity(0.10),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: kPrimary.withOpacity(0.15)),
          ),
          child: Text(
            modeLbl,
            style: const TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              color: kPrimaryDark,
              letterSpacing: 0.2,
            ),
          ),
        ),
        if (detail != null) ...[
          const SizedBox(width: 5),
          Text(
            detail,
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
            ),
          ),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WEEKLY PERFORMANCE  (mini bar chart of last 7 days)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWeeklyPerformance(List<AppointmentList> all) {
    final series = _lastSevenDaysCompleted(all);
    final maxVal =
        series.fold<int>(0, (m, e) => e.count > m ? e.count : m);
    final total = series.fold<int>(0, (s, e) => s + e.count);
    final todayIdx = series.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Text('This Week',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: kPrimary)),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text('$total seen',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: kPrimaryDark)),
            ),
          ]),
          const SizedBox(height: 12),
          SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(series.length, (i) {
                final e = series[i];
                final ratio = maxVal == 0 ? 0.0 : e.count / maxVal;
                final isToday = i == todayIdx;
                final barH = (ratio * 60).clamp(4.0, 60.0);
                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                        horizontal: i == 0 || i == series.length - 1
                            ? 2
                            : 3),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          e.count == 0 ? '·' : '${e.count}',
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isToday ? kPrimaryDark : kTextMuted),
                        ),
                        const SizedBox(height: 3),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: barH,
                            decoration: BoxDecoration(
                              gradient: isToday
                                  ? const LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF4DD9C8),
                                        Color(0xFF2BB5A0),
                                      ],
                                    )
                                  : null,
                              color:
                                  isToday ? null : kPrimaryLight,
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          DateFormat('E').format(e.date)[0],
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w700,
                              color: isToday ? kPrimaryDark : kTextMuted),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DOCTOR TIPS  (auto-rotating carousel)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTipsCarousel() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFEAF8F5), Color(0xFFFAFEFD)],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kPrimary.withOpacity(0.15)),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.tips_and_updates_rounded,
                        size: 10, color: Colors.white),
                    SizedBox(width: 3),
                    Text(
                      'TIP',
                      style: TextStyle(
                        fontSize: 8.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                '${_currentTip + 1} / ${_kDoctorTips.length}',
                style: const TextStyle(
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  color: kTextSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 64,
            child: PageView.builder(
              controller: _tipsController,
              itemCount: _kDoctorTips.length,
              onPageChanged: (i) => setState(() => _currentTip = i),
              itemBuilder: (_, i) {
                final tip = _kDoctorTips[i];
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kPrimaryLight),
                      ),
                      alignment: Alignment.center,
                      child: Text(tip.emoji,
                          style: const TextStyle(fontSize: 18)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tip.title,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                              color: kPrimaryDark,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tip.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 10.5,
                              height: 1.35,
                              color: kTextPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_kDoctorTips.length, (i) {
              final active = i == _currentTip;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                width: active ? 18 : 5,
                height: 5,
                decoration: BoxDecoration(
                  gradient: active ? kPrimaryGradient : null,
                  color: active ? null : kPrimaryLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NO LIVE SESSIONS EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoLiveSessions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kHairline),
        boxShadow: kSoftShadow,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [kPrimaryLight, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              shape: BoxShape.circle,
              border: Border.all(color: kPrimaryLight),
            ),
            child: const Icon(Icons.event_busy_rounded,
                color: kPrimary, size: 22),
          ),
          const SizedBox(height: 10),
          const Text(
            'No Schedule for Today',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: kTextPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 3),
          const Text(
            'Set your weekly availability to start accepting patients.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 10.5,
              color: kTextSecondary,
              fontWeight: FontWeight.w500,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const DoctorAvailabilityPage()),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.circular(11),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.calendar_today_rounded,
                      color: Colors.white, size: 13),
                  SizedBox(width: 6),
                  Text(
                    'Set Schedule',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 0.2,
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

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _patientCard(AppointmentList p) {
    final name     = p.patientName ?? p.bookingFor ?? 'Unknown';
    final initials = _initials(name);
    final age      = _calcAge(p.dob);
    final status   = p.status ?? 'booked';

    final palettes = [
      (kPrimaryLighter, kPrimaryLight, kPrimary),
      (kPurpleLight,    kPurpleBorder, kPurple),
      (kAmberLight,     kAmberBorder,  kAmber),
      (kRedLight,       kRedBorder,    kRed),
    ];
    final (avBg, avBd, avFg) =
        palettes[(p.queueNumber ?? 0) % palettes.length];

    return Container(
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kHairline),
        boxShadow: kSoftShadow,
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [avBg, Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: avBd),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: avFg,
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
                name,
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
                [
                  if (p.gender != null) p.gender!,
                  if (age != null) '$age yrs'
                ].join(' · '),
                style: const TextStyle(
                  fontSize: 9.5,
                  color: kTextSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Row(children: [
                _statusChip(status),
                if (p.specialization != null) ...[
                  const SizedBox(width: 4),
                  _tagChip(p.specialization!,
                      bg: kPrimaryLighter, fg: kPrimaryDark),
                ],
              ]),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Container(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [avBg, Colors.white],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: avBd),
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
                (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: avFg,
                  height: 1,
                  letterSpacing: -0.4,
                ),
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGES & CHIPS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'skipped':
        bg = kAmberLight; fg = kAmberDark; dot = kAmber;
        break;
      case 'completed':
        bg = kPrimaryLighter; fg = kPrimaryDark; dot = kPrimary;
        break;
      default:
        bg = kRedLight; fg = kRedDark; dot = kRed;
    }
    return _badgeDot(
        status[0].toUpperCase() + status.substring(1), bg, fg, dot);
  }

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running'; bg = kPrimaryLighter; fg = kPrimaryDark; dot = kPrimary;
        break;
      case QueueState.paused:
        label = 'Paused'; bg = kAmberLight; fg = kAmberDark; dot = kAmber;
        break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        dot = const Color(0xFF9CA3AF);
        break;
      case QueueState.idle:
        label = 'Idle'; bg = kRedLight; fg = kRedDark; dot = kRed;
        break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: dot.withOpacity(0.18)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: dot,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
              color: fg,
            ),
          ),
        ]),
      );

  Widget _tagChip(String label, {required Color bg, required Color fg}) =>
      Container(
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

  // ── Premium helpers ─────────────────────────────────────────────────────

  Widget _slotPill(String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [kPrimaryLight, kPrimaryLighter],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: kPrimary.withOpacity(0.18)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.schedule_rounded, size: 9, color: kPrimaryDark),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: kPrimaryDark,
                letterSpacing: 0.2,
              ),
            ),
          ],
        ),
      );

  Widget _gradientProgress(double value) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Container(
          height: 6,
          decoration: BoxDecoration(
            color: kPrimaryLight.withOpacity(0.6),
            borderRadius: BorderRadius.circular(20),
          ),
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.0, 1.0),
            alignment: Alignment.centerLeft,
            child: Container(
              decoration: BoxDecoration(
                gradient: kPrimaryGradient,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
        ),
      );

  Widget _sectionHeader(String label, int count, Color accent, Color accentLight, Color accentDark) {
    return Row(children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accent, accent.withOpacity(0.5)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        label,
        style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
          color: kTextPrimary,
          letterSpacing: -0.1,
        ),
      ),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: accentLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.18)),
        ),
        child: Text(
          '$count',
          style: TextStyle(
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            color: accentDark,
          ),
        ),
      ),
    ]);
  }

  Widget _pulseDot() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        onEnd: () => setState(() {}),
        child: Container(
          width: 7,
          height: 7,
          decoration:
              const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
        ),
      );
}
