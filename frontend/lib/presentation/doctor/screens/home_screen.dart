
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/core/utils/name_utils.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/available_slots.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_repository_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';
import 'package:qless/presentation/shared/widgets/skeleton.dart';

part 'home_screen/overview_sidebar.dart';
part 'home_screen/live_queue_bar.dart';
part 'home_screen/shared.dart';
part 'home_screen/walk_in_inline_panel.dart';
part 'home_screen/home_session_fullscreen_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});

  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends ConsumerState<QueueHomePage> with WidgetsBindingObserver {
  bool _hasFetched = false;
  bool _showWalkInForm = false;
  final Map<int, bool> _patientsExpanded = {};
  late final ProviderSubscription<int?> _doctorIdSub;
  ProviderSubscription<String?>? _clinicIdSub;
  ProviderSubscription<ConnectivityStatus>? _connectivitySub;
  final ScrollController _scrollController = ScrollController();

  final PageController _tipsController = PageController();
  final int _currentTip = 0;
  Timer? _tipsTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) {
        if (next != null && next > 0) _loadData();
      },
    );
    // Clinic switch (doctor multi-clinic / receptionist) madhe queue refresh
    _clinicIdSub = ref.listenManual<String?>(
      doctorLoginViewModelProvider.select((s) => s.clinicId),
      (prev, next) {
        if (next != null && next != prev) _loadData(force: true);
      },
    );
    // _loadData relies on fetchPatientAppointments's network-error catch to
    // fall back to cache, which works but can sit waiting on a slow/failing
    // request first. React to connectivity transitions directly so going
    // offline snaps straight to cache, and coming back online forces a fresh
    // fetch instead of leaving stale cached data on screen.
    _connectivitySub = ref.listenManual<ConnectivityStatus>(
      connectivityNotifierProvider.select((s) => s.status),
      (prev, next) {
        if (prev == next) return;
        final wasOnline = prev == ConnectivityStatus.online || prev == ConnectivityStatus.backOnline;
        final isOnlineNow = next == ConnectivityStatus.online || next == ConnectivityStatus.backOnline;
        if (next == ConnectivityStatus.offline || (wasOnline == false && isOnlineNow)) {
          _loadData(force: true);
        }
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
    WidgetsBinding.instance.removeObserver(this);
    _tipsTimer?.cancel();
    _tipsController.dispose();
    _scrollController.dispose();
    _doctorIdSub.close();
    _clinicIdSub?.close();
    _connectivitySub?.close();
    super.dispose();
  }

  // Backgrounding/closing the app isn't a network problem — tell the server
  // so patients see a plain offline status instead of a scary connectivity
  // banner. On resume, rejoin so presence flips back to online.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_doctorId == 0) return;
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      ref.read(appointmentViewModelProvider.notifier).notifyAppBackgrounded();
    } else if (state == AppLifecycleState.resumed) {
      _refreshQueueStatus();
    }
  }

  int get _doctorId => ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
  String? get _clinicId => ref.read(doctorLoginViewModelProvider).clinicId;
  bool get _isOnline => ref.read(connectivityNotifierProvider).isOnline;

  bool get _isDoctorOnLeaveToday {
    final leaves = ref.read(doctorSettingsViewModelProvider).leaves;
    if (leaves.isEmpty) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return leaves.any((l) {
      try {
        final from = DateTime.parse(l.fromDate);
        final to = DateTime.parse(l.toDate);
        return !todayOnly.isBefore(DateTime(from.year, from.month, from.day)) &&
            !todayOnly.isAfter(DateTime(to.year, to.month, to.day));
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _loadData({bool force = false}) async {
    if (_doctorId == 0) return;
    if (_hasFetched && !force) return;
    _hasFetched = true;
    final isOnline = ref.read(connectivityNotifierProvider).isOnline;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId, clinicId: _clinicId);
    await Future.wait([
      ref.read(appointmentViewModelProvider.notifier)
          .fetchPatientAppointments(_doctorId, isOnline: isOnline, clinicId: _clinicId),
      ref.read(doctorSettingsViewModelProvider.notifier).getDoctorSchedule(_doctorId, clinicId: _clinicId),
      ref.read(doctorSettingsViewModelProvider.notifier).getDoctorLeaves(_doctorId),
    ]);
  }

  Future<void> _refreshData() => _loadData(force: true);

  // Silent queue-status update — no loading spinner
  void _refreshQueueStatus() {
    if (_doctorId == 0) return;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId, clinicId: _clinicId);
  }

  List<AppointmentList> _todayActivePatients(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress' || s == 'skipped') &&
          d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
  }

  List<AppointmentList> _todaySlotPatients(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if (a.bookingType != 2) return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress' || s == 'skipped') &&
          d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
  }

  int _todayTotalCount(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Queue actions ─────────────────────────────────────────────────────────

  Future<void> _onQueueStart(int? queueId) async {
    final ok = await _confirm(
      title: 'Start Queue?',
      message: 'Patients will be notified that the queue is now live.',
      confirmLabel: 'Start',
      confirmColor: kPrimaryDark,
    );
    if (!ok) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId), isOnline: _isOnline, offlineClinicId: _clinicId);
      _snack(res.message ?? 'Queue started');
      _refreshQueueStatus();
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  Future<void> _onQueuePause(int? queueId, {bool confirmFirst = true}) async {
    if (confirmFirst) {
      final ok = await _confirm(
        title: 'Pause Queue?',
        message: 'Waiting patients will be notified that the queue is paused. You can resume any time.',
        confirmLabel: 'Pause',
        confirmColor: kAmberDark,
      );
      if (!ok) return;
    }
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId), isOnline: _isOnline, offlineClinicId: _clinicId);
      _snack(res.message ?? 'Queue paused');
      _refreshQueueStatus();
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId), isOnline: _isOnline, offlineClinicId: _clinicId);
      _snack(res.message ?? 'Queue closed');
      _refreshQueueStatus();
    } catch (_) {
      _snack('Failed to close queue');
    }
  }

  Future<void> _onToggleBookingClosed(int? queueId, bool closed) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).stopBooking(
            AppointmentRequestModel(
              doctorId: _doctorId,
              queueId: queueId,
              bookingClosed: closed,
            ),
          );
      _snack(res.message ?? (closed ? 'New bookings stopped' : 'New bookings resumed'));
    } catch (_) {
      _snack('Failed to update booking status');
    }
  }

  Future<void> _onQueuePauseEmergency(int? queueId) async {
    if (queueId == null) { _snack('Queue ID not available'); return; }
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePauseEmergency(queueId, isOnline: _isOnline, doctorId: _doctorId, clinicId: _clinicId);
      _snack(res.message ?? 'Queue paused (emergency)');
      _refreshQueueStatus();
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

  String? _ageStr(String? dob) {
    final age = _calcAge(dob);
    return age == null ? null : '$age yrs';
  }

  DateTime? _instantOf(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
    try { return DateTime.parse(v).toUtc(); } catch (_) { return null; }
  }

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = _doctorId;
    // A walk-in booked offline (negative placeholder appointment id) gets its
    // patient id only when it syncs; the queued actions are filled in then.
    final offlineWalkIn = (p.appointmentId ?? 0) < 0;
    if ((pid == 0 && !offlineWalkIn) || did == 0) { _snack('Missing info'); return; }
    final status = p.status?.toLowerCase() ?? '';
    if (status != 'in_progress') {
      if (status == 'booked') {
        final slotStart = _instantOf(p.startTime);
        if (slotStart != null && DateTime.now().toUtc().isBefore(slotStart)) {
          _snack('Scheduled for ${_fmtTime(p.startTime)} — start once the slot begins.');
          return;
        }
      }
      try {
        final res = await ref.read(appointmentViewModelProvider.notifier).startSession(
          AppointmentRequestModel(doctorId: did, patientId: pid, appointmentId: p.appointmentId ?? 0),
          isOnline: _isOnline,
          offlineClinicId: _clinicId,
        );
        if (!mounted) return;
        if (res.success != true) { _snack(res.message ?? 'Could not start session'); return; }
      } catch (e) {
        if (mounted) _snack('Failed to start session');
        return;
      }
    }
    if (!mounted) return;
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
        clinicId: _clinicId,
        queueId: p.queueId,
      ),
    ));
    if (!mounted) return;
    _hasFetched = false;
    await _refreshData();
  }

  // Walk-in the server already started (queue was idle) — load it and go
  // straight to its prescription. _startSession skips the API for in_progress.
  Future<void> _openStartedWalkIn(int appointmentId) async {
    await _refreshData();
    if (!mounted) return;
    final all = ref.read(appointmentViewModelProvider).patientAppointmentsList.value ?? const [];
    final p = all.where((a) => a.appointmentId == appointmentId).firstOrNull;
    if (p != null) await _startSession(p);
  }

  Future<void> _skipPatient(AppointmentList p) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).queueSkip(
        AppointmentRequestModel(
          doctorId: _doctorId, appointmentId: p.appointmentId ?? 0,
          patientId: p.patientId ?? 0, isNext: 0, queueId: p.queueId,
        ),
        isOnline: _isOnline,
        offlineClinicId: _clinicId,
      );
      if (!mounted) return;
      _snack(res.message ?? (res.success == true ? 'Patient skipped' : 'Skip failed'));
    } catch (_) {
      if (mounted) _snack('Failed to skip');
    }
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

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toUtc();
      return DateFormat('h:mm a').format(dt);
    } catch (_) { return raw; }
  }

  String _fmtScheduleTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final parts = raw.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
    } catch (_) { return raw; }
  }

  List<TimeSlotModel> _todayScheduledSlots() {
    final schedule = ref.read(doctorSettingsViewModelProvider).doctorSchedule;
    final days = schedule?.schedule;
    if (days == null || days.isEmpty) return [];
    final todayName = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
    for (final d in days) {
      if ((d.day ?? '').toLowerCase() == todayName) {
        if ((d.isEnabled ?? 0) != 1) return [];
        final slots = d.slots ?? [];
        return [...slots]..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
      }
    }
    return [];
  }

  // Online, session order comes pre-sorted from the server. Offline, the
  // local cache read has no such guarantee (its own ORDER BY is by queue_id,
  // not chronological), so the displayed order could differ between the two.
  // Sorting explicitly here — applied identically regardless of source —
  // guarantees the same order online and offline, chronological by start
  // time with undated (walk-in queue-type, no fixed slot) sessions last.
  int _bySessionStartTime(dynamic a, dynamic b) {
    final at = _instantOf(a.startTime as String?);
    final bt = _instantOf(b.startTime as String?);
    if (at == null && bt == null) return 0;
    if (at == null) return 1;
    if (bt == null) return -1;
    return at.compareTo(bt);
  }

  bool _shouldShowSession(dynamic session, {required bool hasBooking}) {
    if (_isStaleQueueDate(session.queueDate as String?)) return false;
    final qs = session.queueStatus ?? 0;
    final hasSlot = session.startTime != null;
    if (qs == 3) return false;
    if (qs == 0 && !hasSlot && !hasBooking) return false;
    return true;
  }

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
    final vmState           = ref.watch(appointmentViewModelProvider);
    final appointmentsAsync = vmState.patientAppointmentsList;

    ref.watch(doctorSettingsViewModelProvider.select((s) => s.doctorSchedule));

    final isReceptionist = ref.watch(tokenProvider).roleId == 3;
    final doctorName = isReceptionist
        ? (ref.watch(receptionistLoginViewModelProvider).name ?? 'Receptionist')
        : ref.watch(doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'));

    // Pill nav sits below this page (Column layout, not overlaid), so the
    // page's own bottom edge already borders the nav bar — only a small
    // clearance is needed here.
    final fabBottom  = 16.0;
    // List bottom padding: above FAB (56) + gap
    final listBottom = 16.0 + 56.0 + 16.0;
    final isWide = MediaQuery.of(context).size.width >= _kHomeWideBreak;
    final isFullWide = MediaQuery.of(context).size.width >= _kHomeFullBreak;

    final bodyStack = Stack(
        children: [
          appointmentsAsync.when(
        loading: () => _buildLoadingBody(doctorName),
        error: (e, _) => _buildErrorBody(e, doctorName),
        data: (list) {
          final currentClinicId = _clinicId;
          final filteredList = currentClinicId == null
              ? list
              : list.where((a) => a.clinicId == currentClinicId).toList();
          final allSessions    = vmState.todayQueueResult?.value ?? [];
          final activeQueueIds = filteredList.map((a) => a.queueId).whereType<int>().toSet();
          final todaySlotPts   = _todaySlotPatients(filteredList);
          final visibleSessions = allSessions
              .where((s) => _shouldShowSession(s, hasBooking: activeQueueIds.contains(s.queueId)) &&
                  (currentClinicId == null ||
                   activeQueueIds.contains(s.queueId) ||
                   // A queue the doctor has explicitly started/paused/stopped
                   // already belongs to this clinic context by construction —
                   // don't hide it just because its patient list happens to be
                   // empty in the (possibly stale, offline) appointments cache.
                   // Without this, a live/paused second queue with no cached
                   // bookings at that instant vanishes from the list entirely.
                   (s.queueStatus ?? 0) != 0 ||
                   // A session with a defined slot start time came straight from
                   // getTodayQueue(doctorId, clinicId: ...) — already clinic-scoped
                   // server-side — so it's a legitimate session for this clinic
                   // even before it starts and even if its (queue-type) patient
                   // hasn't landed in the appointments cache yet. Without this, a
                   // second, not-yet-started session with a real booking vanishes
                   // on refresh because queue-type patients never populate
                   // todaySlotPts (that's slot-booking only).
                   s.startTime != null ||
                   todaySlotPts.any((p) {
                     final sessStart = _instantOf(s.startTime);
                     final sessEnd   = _instantOf(s.endTime);
                     final pt = _instantOf(p.startTime);
                     if (pt == null) return true;
                     if (sessStart != null && pt.isBefore(sessStart)) return false;
                     if (sessEnd   != null && !pt.isBefore(sessEnd))  return false;
                     return true;
                   })))
              .toList()
            ..sort(_bySessionStartTime);
          final todayActivePts = _todayActivePatients(filteredList);

          // slot patients not matched to any visible session
          final matchedSlotIds = <int?>{};
          for (final s in visibleSessions) {
            final ss = _instantOf(s.startTime);
            final se = _instantOf(s.endTime);
            for (final p in todaySlotPts) {
              final pt = _instantOf(p.startTime);
              final inRange = pt == null ||
                  ((ss == null || !pt.isBefore(ss)) &&
                   (se == null || pt.isBefore(se)));
              if (inRange) matchedSlotIds.add(p.appointmentId);
            }
          }
          final unmatchedSlotPts = todaySlotPts
              .where((p) => !matchedSlotIds.contains(p.appointmentId))
              .toList();

          return _buildRefreshableScrollView(
            slivers: [
              // // ── SESSION QUEUE CARDS / EMPTY STATE ──────────────────
              // if (visibleSessions.isEmpty) ...[
              //   if (todaySlotPts.isNotEmpty)
              //     SliverToBoxAdapter(
              //       child: Padding(
              //         padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //         child: _buildStandaloneSlotSection(todaySlotPts),
              //       ),
              //     )
              //   else if (_todayScheduledSlots().isEmpty)
              //     SliverToBoxAdapter(
              //       child: Padding(
              //         padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //         child: _buildNoLiveSessions(),
              //       ),
              //     ),
              // ] else ...[
              // ── SESSION QUEUE CARDS / EMPTY STATE ──────────────────
              if (visibleSessions.isEmpty) ...[
                if (todaySlotPts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildStandaloneSlotSection(todaySlotPts),
                    ),
                  )
                // Offline and today's sessions were never downloaded (first
                // open of the day without internet) — say so, instead of a
                // misleading "No Schedule for Today".
                else if (ref.watch(connectivityNotifierProvider).isOffline &&
                    !allSessions.any((s) => _isTodayStr(s.queueDate)))
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildOfflineNoTodayData(),
                    ),
                  )
                else if (_todayScheduledSlots().isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildNoLiveSessions(),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildAwaitingBookingsState(),
                    ),
                  ),
              ] else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final session   = visibleSessions[i];
                        final sessionQs = _sessionQueueState(session.queueStatus);
                        final slotLbl = (session.startTime != null)
                            ? '${_fmtTime(session.startTime)} – ${_fmtTime(session.endTime)}'
                            : null;
                        final sessionPts = todayActivePts
                            .where((p) => p.queueId == session.queueId)
                            .toList();
                        final sessionHasIP = sessionPts.any(
                            (p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
                        final sessionBooked = sessionPts
                            .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
                            .toList()
                          ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
                        final sessionNextQNo = sessionBooked.isNotEmpty
                            ? sessionBooked.first.queueNumber
                            : null;

                        // slot patients — match by session time range
                        final sessStart = _instantOf(session.startTime);
                        final sessEnd   = _instantOf(session.endTime);
                        final sessionSlotPts = todaySlotPts.where((p) {
                          final pt = _instantOf(p.startTime);
                          if (pt == null) return true;
                          if (sessStart != null && pt.isBefore(sessStart)) return false;
                          if (sessEnd   != null && !pt.isBefore(sessEnd))  return false;
                          return true;
                        }).toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildSessionAccordion(
                            sessionIndex:    i,
                            queueId:         session.queueId,
                            slotLabel:       slotLbl,
                            queueState:      sessionQs,
                            sessionPts:      sessionPts,
                            sessionHasIP:    sessionHasIP,
                            sessionNextQNo:  sessionNextQNo,
                            sessionSlotPts:  sessionSlotPts,
                            bookingClosed:   session.bookingClosed == true,
                          ),
                        );
                      },
                      childCount: visibleSessions.length,
                    ),
                  ),
                ),
                if (unmatchedSlotPts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: _buildStandaloneSlotSection(unmatchedSlotPts),
                    ),
                  ),
              ],

              // ── QUICK ACTIONS ───────────────────────────────────────
              // SliverToBoxAdapter(
              //   child: Padding(
              //     padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //     child: _buildHomeQuickActions(),
              //   ),
              // ),

              SliverToBoxAdapter(child: SizedBox(height: listBottom)),
            ],
          );
        },
      ),
          if (!_isDoctorOnLeaveToday && (!isWide || (!isFullWide && !_showWalkInForm)))
            Positioned(
              right: 16,
              bottom: fabBottom,
              child: FloatingActionButton(
                onPressed: () {
                  if (isWide) {
                    setState(() => _showWalkInForm = true);
                  } else {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => _WalkInDialog(
                        onBooked: () => Navigator.of(context).pop(),
                        onAutoStarted: _openStartedWalkIn,
                      ),
                    );
                  }
                },
                backgroundColor: kPrimaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tooltip: 'Add Walk-in Patient',
                child: const Icon(Icons.person_add_rounded),
              ),
            ),
        ],
      );

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(children: [
        _buildHeader(doctorName),
        Expanded(
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isFullWide || !_showWalkInForm) _buildOverviewSidebar(),
                    Expanded(child: bodyStack),
                    if (isFullWide || _showWalkInForm)
                      SizedBox(width: 400, child: _buildWalkInFormPane(closable: !isFullWide)),
                  ],
                )
              : bodyStack,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP WALK-IN FORM PANE (right column, queue stays visible alongside)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWalkInFormPane({required bool closable}) {
    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        border: Border(left: BorderSide(color: kBorder)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: const BoxDecoration(
            color: kCardBg,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded, size: 16, color: kPrimaryDark),
            ),
            const SizedBox(width: 10),
            const Text('Add Walk-in Patient',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            if (closable) ...[
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showWalkInForm = false),
                icon: const Icon(Icons.close_rounded, size: 20, color: kTextSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _WalkInInlinePanel(
              onBooked: () => setState(() => _showWalkInForm = false),
              onAutoStarted: _openStartedWalkIn,
            ),
          ),
        ),
      ]),
    );
  }

  bool _isTodayAppt(AppointmentList a) {
    final d = DateTime.tryParse(a.appointmentDate ?? '');
    if (d == null) return false;
    final today = DateTime.now();
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  Future<void> _showClinicPicker(
      BuildContext context, List<DoctorDetails> clinics) async {
    final selected = await showModalBottomSheet<DoctorDetails>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final current = ref.read(doctorLoginViewModelProvider).clinicId;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Select Clinic',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    )),
              ),
              const SizedBox(height: 8),
              ...clinics.map((c) {
                final isActive = c.clinicId == current;
                return ListTile(
                  leading: Icon(
                    Icons.local_hospital_outlined,
                    color: isActive ? kPrimary : kTextSecondary,
                    size: 20,
                  ),
                  title: Text(
                    c.clinicName ?? 'Clinic',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: isActive ? kPrimary : kTextPrimary,
                    ),
                  ),
                  subtitle: c.clinicAddress != null
                      ? Text(c.clinicAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: kTextSecondary))
                      : null,
                  trailing: isActive
                      ? const Icon(Icons.check_circle,
                          color: kPrimary, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    if (selected.clinicId == ref.read(doctorLoginViewModelProvider).clinicId) {
      return;
    }
    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .selectClinic(selected);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSessionAccordion({
    required int sessionIndex,
    required int? queueId,
    required String? slotLabel,
    required QueueState queueState,
    required List<AppointmentList> sessionPts,
    required bool sessionHasIP,
    required int? sessionNextQNo,
    required List<AppointmentList> sessionSlotPts,
    required bool bookingClosed,
  }) {
    if (queueState == QueueState.stopped) return const SizedBox.shrink();

    final isRunning   = queueState == QueueState.running;
    final isPaused    = queueState == QueueState.paused;
    final queueActive = isRunning || isPaused;
    final isEmergency = ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId);

    // Current patient: in_progress first, then first booked by queue number
    // (only surfaced once the queue has actually been started — before that,
    // patients are shown as a plain waiting list, no "Now Serving" card)
    final ipPt = sessionPts.where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').firstOrNull;
    final bookedSorted = sessionPts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final currentPt = queueActive ? (ipPt ?? bookedSorted.firstOrNull) : null;

    // Up next = all except current, sorted by queue number
    final upNextPts = sessionPts
        .where((p) => p.appointmentId != currentPt?.appointmentId)
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

    // Skipped patients waiting to return — pulled out of "Up next" and shown
    // first. Patients who tapped "I've Arrived" jump to the very front (they're
    // physically at the clinic right now); within each group, oldest-skipped
    // first (queue number order == skip order since skips happen in queue
    // sequence), so the doctor recalls in the right order.
    final skippedWaitingPts = upNextPts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'skipped')
        .toList()
      ..sort((a, b) {
        final arrivedCmp = (b.isArrived == true ? 1 : 0).compareTo(a.isArrived == true ? 1 : 0);
        if (arrivedCmp != 0) return arrivedCmp;
        return (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0);
      });
    final bookedUpNextPts = upNextPts
        .where((p) => (p.status?.toLowerCase() ?? '') != 'skipped')
        .toList();

    final cardBorderColor = isRunning ? kCardBorder : isPaused ? kCardBorder : kCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: kPageBg,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cardBorderColor)),
        boxShadow: const [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-7, -7), blurRadius: 16, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(7, 7),  blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Session header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: const BoxDecoration(
                color: kPageBg,
                borderRadius: BorderRadius.all(Radius.circular(9)),
                boxShadow: [
                  BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
                  BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(2, 2),  blurRadius: 5),
                ],
              ),
              child: Text('S${sessionIndex + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryDark)),
            ),
            const SizedBox(width: 10),
            if (slotLabel != null)
              Expanded(child: Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(slotLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                    overflow: TextOverflow.ellipsis)),
              ]))
            else
              const Expanded(child: Text('Session',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary))),
            const SizedBox(width: 8),
            isEmergency
                ? _badgeDot('Emergency', kPurpleLight, kPurpleDark, kPurple)
                : _queueStateBadge(queueState),
            const SizedBox(width: 8),
            _neuIconBtn(
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning
                  ? () => _showPauseOptionsDialog(queueId)
                  : () => _onQueueStart(queueId),
            ),
            if (!isEmergency) ...[
              const SizedBox(width: 6),
              _neuIconBtn(
                icon: Icons.stop_rounded,
                color: kRedDark,
                tooltip: 'Close queue',
                onTap: () => _showCloseDialog(queueId),
              ),
            ],
            // emergency pause button — available via pause dialog
            // const SizedBox(width: 6),
            // _neuIconBtn(
            //   icon: Icons.warning_amber_rounded,
            //   color: kPurpleDark,
            //   tooltip: 'Emergency pause',
            //   onTap: () => _showEmergencyDialog(queueId),
            // ),
          ]),
        ),

        // ── Accepting new bookings toggle (below the queue time) ────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _bookingToggleSwitch(
              value: !bookingClosed,
              tooltip: bookingClosed
                  ? 'New bookings stopped — tap to resume. Patients already in the queue are not affected.'
                  : 'Stop new bookings for today — patients already in the queue keep being served as usual.',
              onTap: () => _onToggleBookingClosed(queueId, !bookingClosed),
            ),
            const SizedBox(width: 6),
            Text(bookingClosed ? 'New bookings stopped' : 'Accepting new bookings',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: bookingClosed ? kRedDark : kTextSecondary)),
          ]),
        ),

        // ── NOW SERVING ───────────────────────────────────────────────
        if (currentPt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _buildNowServingCard(currentPt, queueState, sessionPts.length - 1, sessionHasIP, sessionNextQNo),
          )
        else if (queueActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(
                      color: kPageBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 7),
                        BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3),  blurRadius: 7),
                      ],
                    ),
                    child: const Icon(Icons.inbox_rounded, color: kTextMuted, size: 20),
                  ),
                  const SizedBox(height: 10),
                  const Text('No patients waiting',
                      style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),

        // ── Skipped — waiting to return ─────────────────────────────────
        // Collapsed by default (only the highest-priority — first skipped —
        // patient shown) so a long skipped list doesn't push "Up next" down.
        if (skippedWaitingPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Skipped — waiting to return',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kAmberDark, letterSpacing: 0.2)),
              const Spacer(),
              Text('${skippedWaitingPts.length} waiting',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Builder(builder: (_) {
            final key = queueId ?? sessionIndex;
            final expanded = _patientsExpanded[key] ?? false;
            final visiblePts = expanded ? skippedWaitingPts : skippedWaitingPts.take(2).toList();
            final hiddenCount = skippedWaitingPts.length - visiblePts.length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Column(children: [
                ...visiblePts.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUpNextCard(p, queueState),
                    )),
                if (hiddenCount > 0 || expanded)
                  GestureDetector(
                    onTap: () => setState(() => _patientsExpanded[key] = !expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        expanded ? 'Show less' : '+$hiddenCount more skipped',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: kAmberDark),
                      ),
                    ),
                  ),
              ]),
            );
          }),
        ],

        // ── Up next ───────────────────────────────────────────────────
        if (bookedUpNextPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Row(children: [
              const Text('Up next',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kTextSecondary, letterSpacing: 0.2)),
              const Spacer(),
              Text('${bookedUpNextPts.length} waiting',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: bookedUpNextPts
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUpNextCard(p, queueState),
                    ))
                .toList()),
          ),
        ] else if (skippedWaitingPts.isEmpty)
          const SizedBox(height: 14),

        // ── SLOT PATIENTS ─────────────────────────────────────────────
        if (sessionSlotPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 13, color: kTextSecondary),
              const SizedBox(width: 6),
              const Text('Scheduled Slots',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kTextSecondary, letterSpacing: 0.2)),
              const Spacer(),
              Text('${sessionSlotPts.length} booked',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: sessionSlotPts
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSlotPatientCard(p, queueState),
                    ))
                .toList()),
          ),
        ] else
          const SizedBox(height: 0),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showPauseOptionsDialog(int? queueId) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: kAmberLight, shape: BoxShape.circle),
              child: const Icon(Icons.pause_rounded, color: kAmberDark, size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Pause Queue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text('Choose how you want to pause the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4)),
            const SizedBox(height: 20),
            // Pause
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                await _onQueuePause(queueId, confirmFirst: false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kAmberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAmberBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Pause',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kAmberDark)),
              ),
            ),
            const SizedBox(height: 10),
            // Emergency Pause
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                if (ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId)) {
                  _snack('Already emergency paused');
                  return;
                }
                await _onQueuePauseEmergency(queueId);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kPurpleLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPurpleBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Emergency Pause',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPurpleDark)),
              ),
            ),
            const SizedBox(height: 10),
            // Cancel
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _showCloseDialog(int? queueId) async {
    final vmState     = ref.read(appointmentViewModelProvider);
    final appts       = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final sessions    = vmState.todayQueueResult?.value ?? [];

    final matchingSession = sessions.where((s) => s.queueId == queueId).toList();
    final queueStartTime  = matchingSession.isEmpty
        ? null : DateTime.tryParse(matchingSession.first.startTime ?? '');

    final queuePending = appts.where((p) {
      if (p.queueId != queueId) return false;
      final st = (p.status?.toLowerCase() ?? '');
      return st == 'booked' || st == 'in_progress';
    }).length;
    final queueSkipped = appts.where((p) {
      if (p.queueId != queueId) return false;
      return (p.status?.toLowerCase() ?? '') == 'skipped';
    }).length;
    final earlierSlotPending = queueStartTime == null ? 0
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
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: kRedLight, shape: BoxShape.circle,
              border: Border.all(color: kRedBorder),
            ),
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
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kAmberDark, height: 1.3),
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
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('No',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
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
                child: const Text('Yes, Close',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRedDark)),
              ),
            )),
          ]),
        ],
      ),
    );
    if (confirmed == true) await _onQueueStop(queueId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NO LIVE SESSIONS EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  bool _isTodayStr(String? s) {
    final d = DateTime.tryParse(s ?? '');
    final n = DateTime.now();
    return d != null && d.year == n.year && d.month == n.month && d.day == n.day;
  }
  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT CARDS
  // ─────────────────────────────────────────────────────────────────────────
}
