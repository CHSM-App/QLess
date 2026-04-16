import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS  (matches DoctorNavTheme from doctor_bottom_nav.dart)
// ─────────────────────────────────────────────────────────────────────────────

class _C {
  _C._();
  static const teal        = Color(0xFF26C6B0);
  static const tealDark    = Color(0xFF2BB5A0);
  static const tealDeep    = Color(0xFF007060);
  static const tealLight   = Color(0xFFD9F5F1);
  static const tealLighter = Color(0xFFF2FCFA);
  static const gradFrom    = Color(0xFF4DD9C8);
  static const gradTo      = Color(0xFF2BB5A0);

  static const textPrimary = Color(0xFF2D3748);
  static const textSlate   = Color(0xFF718096);
  static const textMuted   = Color(0xFFA0AEC0);

  static const border      = Color(0xFFEDF2F7);
  static const bg          = Color(0xFFF8FFFE);
  static const card        = Colors.white;

  static const green       = Color(0xFF68D391);
  static const greenDark   = Color(0xFF276749);
  static const greenLight  = Color(0xFFF0FFF8);
  static const greenBorder = Color(0xFFC6F6D5);

  static const amber       = Color(0xFFF6AD55);
  static const amberDark   = Color(0xFF975A16);
  static const amberLight  = Color(0xFFFFFBEB);
  static const amberBorder = Color(0xFFFCEFC7);

  static const red         = Color(0xFFFC8181);
  static const redDark     = Color(0xFFC53030);
  static const redLight    = Color(0xFFFFF5F5);
  static const redBorder   = Color(0xFFFED7D7);

  static const purple      = Color(0xFF9F7AEA);
  static const purpleDark  = Color(0xFF6B46C1);
  static const purpleLight = Color(0xFFFAF5FF);
  static const purpleBorder= Color(0xFFE9D5FF);

  static const indigo      = Color(0xFF7F9CF5);
  static const indigoDark  = Color(0xFF2C5282);
  static const indigoLight = Color(0xFFEBF8FF);
  static const indigoBorder = Color(0xFFC7D2FE);
}

// ─────────────────────────────────────────────────────────────────────────────
// HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});

  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends ConsumerState<QueueHomePage>
    with SingleTickerProviderStateMixin {
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _doctorIdSub;

  // Pause toggle state (local UI — reflects queueState from VM on real data)
  bool _isPaused = false;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

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
  }

  @override
  void dispose() {
    _doctorIdSub.close();
    super.dispose();
  }

  // ── Data ───────────────────────────────────────────────────────────────────

  int get _doctorId => ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  void _loadData() {
    if (_hasFetched) return;
    if (_doctorId == 0) return;
    _hasFetched = true;
    ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(_doctorId);
  }

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

  // ── Actions ────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      backgroundColor: _C.tealDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _onQueueStart() async {
    if (_doctorId == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId));
      setState(() => _isPaused = false);
      _snack(res.message ?? 'Queue started');
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  Future<void> _onQueuePause() async {
    if (_doctorId == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId));
      setState(() => _isPaused = true);
      _snack(res.message ?? 'Queue paused');
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  Future<void> _onQueueStop() async {
    if (_doctorId == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId));
      _snack(res.message ?? 'Queue closed');
    } catch (_) {
      _snack('Failed to close queue');
    }
  }

  Future<void> _onQueueNext(AppointmentList current) async {
    if (_doctorId == 0) return;
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
    if (_doctorId == 0) return;
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

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vmState           = ref.watch(appointmentViewModelProvider);
    final queueState        = vmState.queueState;
    final appointmentsAsync = vmState.patientAppointmentsList;

    return Scaffold(
      backgroundColor: _C.bg,
      body: appointmentsAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: _C.teal),
        ),
        error: (e, _) => _buildError(e),
        data: (list) {
          final todayQueue = _todayQueue(list);
          final current    = todayQueue.isNotEmpty ? todayQueue.first : null;
          final waiting    = todayQueue.length > 1
              ? todayQueue.skip(1).toList()
              : <AppointmentList>[];
          final nextNo     = waiting.isNotEmpty ? waiting.first.queueNumber : null;
          final doneCount  = list
              .where((a) => (a.status?.toLowerCase() ?? '') == 'completed')
              .length;

      return MediaQuery.removePadding(
  context: context,
  removeTop: true,
    child:  
       CustomScrollView(
            slivers: [
              // ── Sticky teal header ────────────────────────────────────────
              // SliverPersistentHeader(
              //   pinned: true,
              //   delegate: _TealHeaderDelegate(
              //     today: DateFormat('EEEE, d MMMM').format(DateTime.now()),
              //   ),
              // ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                       const SizedBox(height: 8),
                    // ── Stat strip ──────────────────────────────────────────
                    _buildStatStrip(
                      total:   todayQueue.length,
                      waiting: waiting.length,
                      done:    doneCount,
                    ),
                    const SizedBox(height: 14),

                    // ── Live queue card ─────────────────────────────────────
                    _buildQueueCard(
                      current:     current,
                      nextQueueNo: nextNo,
                      total:       todayQueue.length,
                      queueState:  queueState,
                    ),
                    const SizedBox(height: 14),

                    // ── Quick actions ───────────────────────────────────────
                    _buildQuickActions(current),
                    const SizedBox(height: 18),

                    // ── Waiting patients header ─────────────────────────────
                    _buildWaitingHeader(waiting.length),
                    const SizedBox(height: 10),

                    // ── Patient cards ───────────────────────────────────────
                    if (waiting.isEmpty)
                      _buildEmptyWaiting()
                    else
                      ...waiting.map(_patientCard),
                 ]),
        ),
      ),
    ],
  ),
);
        },
      ),
    );
  }

  // ── Error state ────────────────────────────────────────────────────────────

  Widget _buildError(Object e) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: _C.redLight,
              shape: BoxShape.circle,
              border: Border.all(color: _C.redBorder),
            ),
            child: const Icon(Icons.error_outline, color: _C.red, size: 28),
          ),
          const SizedBox(height: 12),
          Text('$e',
              style: const TextStyle(color: _C.textMuted, fontSize: 13)),
          const SizedBox(height: 14),
          TextButton(
            onPressed: () {
              _hasFetched = false;
              _loadData();
            },
            style: TextButton.styleFrom(foregroundColor: _C.teal),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAT STRIP  (Total · Waiting · Done)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatStrip({
    required int total,
    required int waiting,
    required int done,
  }) {
    return Row(
      children: [
        _statCard(
          label: 'Total Today',
          value: total.toString().padLeft(2, '0'),
          valueColor: _C.textPrimary,
          accentColor: _C.teal,
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'Waiting',
          value: waiting.toString().padLeft(2, '0'),
          valueColor: _C.teal,
          accentColor: _C.teal,
        ),
        const SizedBox(width: 10),
        _statCard(
          label: 'Done',
          value: done.toString().padLeft(2, '0'),
          valueColor: _C.greenDark,
          accentColor: _C.green,
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color valueColor,
    required Color accentColor,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: _C.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _C.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Column(
            children: [
              // Coloured top strip
              Container(height: 3, color: accentColor),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _C.textSlate,
                        letterSpacing: 0.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: valueColor,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE QUEUE CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQueueCard({
    required AppointmentList? current,
    required int? nextQueueNo,
    required int total,
    required QueueState queueState,
  }) {
    final isRunning = queueState == QueueState.running;
    final isStopped = queueState == QueueState.stopped;

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.tealLight.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: _C.teal.withOpacity(0.09),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ─────────────────────────────────────────────────
          Row(
            children: [
              _pulseDot(),
              const SizedBox(width: 7),
              const Text(
                'LIVE QUEUE STATUS',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                  color: _C.teal,
                ),
              ),
              const Spacer(),
              _queueStateBadge(queueState),
            ],
          ),
          const SizedBox(height: 14),

          // ── Token boxes ────────────────────────────────────────────────
          _buildTokenRow(
            currentNo: current?.queueNumber ?? 0,
            nextNo:    nextQueueNo ?? 0,
            total:     total,
          ),
          const SizedBox(height: 14),

          // ── Current patient ────────────────────────────────────────────
          _buildCurrentPatientBand(current),
          const SizedBox(height: 14),

          // ── Progress bar ───────────────────────────────────────────────
          _buildProgressBar(done: total - (nextQueueNo != null ? total - 1 : 0), total: total),
          const SizedBox(height: 14),

          // ── Action buttons ─────────────────────────────────────────────
          Row(
            children: [
              // Pause / Resume toggle
              Expanded(
                child: _tealButton(
                  label: isRunning ? '⏸  Pause' : '▶  Resume',
                  onTap: isRunning ? _onQueuePause : _onQueueStart,
                  isPaused: isRunning,
                ),
              ),
              const SizedBox(width: 10),
              // Close queue
              Expanded(
                child: Opacity(
                  opacity: isStopped ? 0.4 : 1.0,
                  child: GestureDetector(
                    onTap: isStopped ? null : _onQueueStop,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _C.redLight,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(color: _C.redBorder),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        '✕  Close Queue',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _C.redDark,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTokenRow({
    required int currentNo,
    required int nextNo,
    required int total,
  }) {
    return Row(
      children: [
        // Current — teal gradient
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [_C.gradFrom, _C.gradTo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.all(Radius.circular(15)),
            ),
            child: Column(
              children: [
                const Text(
                  'CURRENT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Colors.white70,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  currentNo.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Up Next — light teal
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: _C.tealLighter,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _C.tealLight),
            ),
            child: Column(
              children: [
                const Text(
                  'UP NEXT',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _C.textSlate,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  nextNo > 0 ? nextNo.toString().padLeft(2, '0') : '--',
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _C.textPrimary,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 10),

        // Remaining — mint green
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
            decoration: BoxDecoration(
              color: _C.greenLight,
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: _C.greenBorder),
            ),
            child: Column(
              children: [
                const Text(
                  'REMAINING',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: _C.greenDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  total.toString().padLeft(2, '0'),
                  style: const TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.w800,
                    color: _C.greenDark,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCurrentPatientBand(AppointmentList? patient) {
    if (patient == null) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: _C.tealLighter,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _C.tealLight),
        ),
        child: const Center(
          child: Text(
            'No patients in queue today',
            style: TextStyle(color: _C.textMuted, fontSize: 13),
          ),
        ),
      );
    }

    final name     = patient.patientName ?? patient.bookingFor ?? 'Unknown';
    final age      = _calcAge(patient.dob);
    final initials = _initials(name);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _C.tealLighter,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _C.tealLight),
      ),
      child: Row(
        children: [
          // Avatar
          Stack(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_C.gradFrom, _C.gradTo],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
              // Online dot
              Positioned(
                bottom: 1,
                right: 1,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: _C.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: _C.tealLighter, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 13),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (patient.gender != null) patient.gender!,
                    if (age != null) '$age yrs',
                    'Token ${(patient.queueNumber ?? 0).toString().padLeft(2, '0')}',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.textSlate,
                  ),
                ),
                const SizedBox(height: 7),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _C.teal,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    const Text(
                      'In Consultation',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _C.tealDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Now badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
            decoration: BoxDecoration(
              color: _C.teal,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Text(
              'Now',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar({required int done, required int total}) {
    final pct = total == 0 ? 0.0 : (done / total).clamp(0.0, 1.0);
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Daily progress',
              style: TextStyle(fontSize: 11, color: _C.textSlate),
            ),
            Text(
              '$done / $total seen',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _C.teal,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: pct,
            minHeight: 8,
            backgroundColor: _C.tealLight,
            valueColor:
                const AlwaysStoppedAnimation<Color>(_C.teal),
          ),
        ),
      ],
    );
  }

  Widget _tealButton({
    required String label,
    required VoidCallback onTap,
    required bool isPaused,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          gradient: isPaused
              ? null
              : const LinearGradient(
                  colors: [_C.gradFrom, _C.gradTo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
          color: isPaused ? _C.amberLight : null,
          borderRadius: BorderRadius.circular(13),
          border: isPaused
              ? Border.all(color: _C.amberBorder)
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: isPaused ? _C.amberDark : Colors.white,
          ),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUICK ACTIONS CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQuickActions(AppointmentList? current) {
    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _C.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Section label ───────────────────────────────────────────────
          const Text(
            'QUICK ACTIONS',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
              color: _C.teal,
            ),
          ),
          const SizedBox(height: 11),

          // ── Mark complete / Skip ────────────────────────────────────────
          Row(
            children: [
              Expanded(
                child: _quickBtn(
                  label: '✓  Mark Complete',
                  bg: _C.greenLight,
                  fg: _C.greenDark,
                  border: _C.greenBorder,
                  enabled: current != null,
                  onTap: current != null ? () => _onQueueNext(current) : null,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _quickBtn(
                  label: '⏭  Skip Patient',
                  bg: _C.amberLight,
                  fg: _C.amberDark,
                  border: _C.amberBorder,
                  enabled: current != null,
                  onTap: current != null ? () => _onQueueSkip(current) : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),

          // ── Shortcut tiles ──────────────────────────────────────────────
          Row(
            children: [
              _shortcutTile(
                icon: Icons.folder_open_rounded,
                label: 'Records',
                bg: _C.greenLight,
                fg: _C.greenDark,
                borderColor: _C.greenBorder,
              ),
              const SizedBox(width: 8),
              _shortcutTile(
                icon: Icons.medication_rounded,
                label: 'Prescribe',
                bg: _C.purpleLight,
                fg: _C.purpleDark,
                borderColor: _C.purpleBorder,
              ),
              const SizedBox(width: 8),
              _shortcutTile(
                icon: Icons.calendar_today_rounded,
                label: 'Schedule',
                bg: _C.amberLight,
                fg: _C.amberDark,
                borderColor: _C.amberBorder,
              ),
              const SizedBox(width: 8),
              _shortcutTile(
                icon: Icons.notifications_rounded,
                label: 'Notify',
                bg: _C.redLight,
                fg: _C.redDark,
                borderColor: _C.redBorder,
              ),
            ],
          ),
        ],
      ),
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
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ),
      ),
    );
  }

  Widget _shortcutTile({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color borderColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: fg),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WAITING PATIENTS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWaitingHeader(int count) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Text(
          'Waiting Patients',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _C.textPrimary,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: _C.tealLighter,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _C.tealLight),
          ),
          child: Text(
            '$count remaining',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _C.tealDark,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWaiting() {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      padding: const EdgeInsets.symmetric(vertical: 32),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
      ),
      child: const Center(
        child: Text(
          'No patients waiting',
          style: TextStyle(color: _C.textMuted, fontSize: 13),
        ),
      ),
    );
  }

  Widget _patientCard(AppointmentList p) {
    final name     = p.patientName ?? p.bookingFor ?? 'Unknown';
    final initials = _initials(name);
    final age      = _calcAge(p.dob);
    final status   = p.status ?? 'booked';

    // Colour scheme per patient index (cycles through teal/purple/amber/indigo)
    final colors = [
      (_C.tealLighter, _C.tealLight,  _C.teal),
      (_C.purpleLight,  _C.purpleBorder, _C.purple),
      (_C.amberLight,  _C.amberBorder, _C.amber),
      (_C.indigoLight, _C.indigoBorder, _C.indigo),
    ];
    final idx    = (p.queueNumber ?? 0) % colors.length;
    final avBg   = colors[idx].$1;
    final avBord = colors[idx].$2;
    final avFg   = colors[idx].$3;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: avBord.withOpacity(0.6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        children: [
          // Avatar
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: avBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: avBord),
            ),
            alignment: Alignment.center,
            child: Text(
              initials,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: avFg,
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _C.textPrimary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    if (p.gender != null) p.gender!,
                    if (age != null) '$age yrs',
                  ].join(' · '),
                  style: const TextStyle(
                    fontSize: 11,
                    color: _C.textSlate,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    _statusChip(status),
                    const SizedBox(width: 6),
                    if (p.specialization != null)
                      _tagChip(
                        p.specialization!,
                        bg: _C.tealLighter,
                        fg: _C.tealDark,
                      ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),

          // Token
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                style: TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  color: avFg,
                  height: 1,
                ),
              ),
              const Text(
                'Token',
                style: TextStyle(fontSize: 10, color: _C.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGES & CHIPS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'skipped':
        bg = _C.amberLight; fg = _C.amberDark; dot = _C.amber;
        break;
      case 'completed':
        bg = _C.tealLighter; fg = _C.tealDark; dot = _C.teal;
        break;
      default:
        bg = _C.redLight; fg = _C.redDark; dot = _C.red;
    }
    final label = status[0].toUpperCase() + status.substring(1);
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running'; bg = _C.tealLighter; fg = _C.tealDark; dot = _C.teal;
        break;
      case QueueState.paused:
        label = 'Paused'; bg = _C.amberLight; fg = _C.amberDark; dot = _C.amber;
        break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF3F4F6);
        fg = const Color(0xFF6B7280);
        dot = const Color(0xFF9CA3AF);
        break;
      case QueueState.idle:
        label = 'Waiting'; bg = _C.redLight; fg = _C.redDark; dot = _C.red;
        break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label, {required Color bg, required Color fg}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(7),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
      ),
    );
  }

  // ── Pulsing live dot ────────────────────────────────────────────────────

  Widget _pulseDot() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.5, end: 1.0),
      duration: const Duration(milliseconds: 900),
      builder: (_, v, child) => Opacity(opacity: v, child: child),
      onEnd: () => setState(() {}),
      child: Container(
        width: 8,
        height: 8,
        decoration: const BoxDecoration(
          color: _C.teal,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    return DateTime.now().year - d.year;
  }

  String _initials(String name) {
    return name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STICKY TEAL HEADER  (SliverPersistentHeader delegate)
// ─────────────────────────────────────────────────────────────────────────────

class _TealHeaderDelegate extends SliverPersistentHeaderDelegate {
  _TealHeaderDelegate({required this.today});
  final String today;

  static const _expandedH  = 110.0;
  static const _collapsedH = 64.0;

  @override double get minExtent => _collapsedH;
  @override double get maxExtent => _expandedH;

  @override
  bool shouldRebuild(_TealHeaderDelegate old) => old.today != today;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final pct      = (shrinkOffset / (_expandedH - _collapsedH)).clamp(0.0, 1.0);
    final titleSz  = lerpDouble(20, 16, pct)!;
    final subOp    = lerpDouble(1.0, 0.0, pct)!;
    final padTop   = lerpDouble(20.0, 14.0, pct)!;
    final padBot   = lerpDouble(16.0, 12.0, pct)!;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.gradFrom, _C.gradTo],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.fromLTRB(20, padTop, 20, padBot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            'Queue Management',
            style: TextStyle(
              fontSize: titleSz,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: -0.3,
            ),
          ),
          if (subOp > 0.01) ...[
            const SizedBox(height: 3),
            Opacity(
              opacity: subOp,
              child: Text(
                today,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// needed for lerpDouble
double? lerpDouble(num? a, num? b, double t) {
  if (a == null && b == null) return null;
  a ??= 0.0;
  b ??= 0.0;
  return a + (b - a) * t;
}