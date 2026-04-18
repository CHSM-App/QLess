import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
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

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});

  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends ConsumerState<QueueHomePage> {
  bool _hasFetched = false;
  bool _showAllWaiting = false;
  late final ProviderSubscription<int?> _doctorIdSub;

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

  int get _doctorId =>
      ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  // ── Grab doctor's name from the login state ────────────────────────────
  String get _doctorName =>
      ref.read(doctorLoginViewModelProvider).name ?? 'Doctor';

  void _loadData() {
    if (_hasFetched || _doctorId == 0) return;
    _hasFetched = true;
    ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(_doctorId);
  }

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

  // ── Queue actions ─────────────────────────────────────────────────────────

  Future<void> _onQueueStart() async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId));
      _snack(res.message ?? 'Queue started');
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  Future<void> _onQueuePause() async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId));
      _snack(res.message ?? 'Queue paused');
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  Future<void> _onQueueStop() async {
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

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
            ? 'Good Afternoon 👋'
            : 'Good Evening 👋';

    final vmState           = ref.watch(appointmentViewModelProvider);
    final queueState        = vmState.queueState;
    final appointmentsAsync = vmState.patientAppointmentsList;

    // Read doctor name reactively
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
          final nextNo     = waiting.isNotEmpty ? waiting.first.queueNumber : null;

          // Limit waiting list to 3 unless "Show All" is toggled
          final visibleWaiting = _showAllWaiting
              ? waiting
              : waiting.take(3).toList();
          final hasMore = !_showAllWaiting && waiting.length > 3;

          return CustomScrollView(
            slivers: [
              // ── HEADER ──────────────────────────────────────────────
              SliverToBoxAdapter(
                child: _buildHeader(greeting, doctorName),
              ),
              // ── STAT STRIP ───────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                  child: _buildStatStrip(
                    total:   todayQueue.length,
                    waiting: waiting.length,
                    done:    completed.length,
                  ),
                ),
              ),
              // ── LIVE QUEUE CARD ──────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildQueueCard(
                    current:     current,
                    nextQueueNo: nextNo,
                    total:       todayQueue.length,
                    done:        completed.length,
                    queueState:  queueState,
                  ),
                ),
              ),
              // ── QUICK ACTIONS ────────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _buildQuickActions(current),
                ),
              ),
              // ── WAITING LIST HEADER ──────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
                  child: Row(
                    children: [
                      Container(
                        width: 3,
                        height: 16,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Waiting',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${waiting.length}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: kPrimaryDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // ── WAITING PATIENT CARDS ────────────────────────────────
              waiting.isEmpty
                  ? SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 16),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                    color: kPrimaryLighter,
                                    shape: BoxShape.circle,
                                    border: Border.all(color: kPrimaryLight)),
                                child: const Icon(Icons.inbox_rounded,
                                    color: kPrimary, size: 24),
                              ),
                              const SizedBox(height: 10),
                              const Text('No patients waiting',
                                  style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500)),
                            ],
                          ),
                        ),
                      ),
                    )
                  : SliverPadding(
                      padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (_, i) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
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
                    padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _showAllWaiting = !_showAllWaiting),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: kPrimaryLighter,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kPrimaryLight),
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
                                fontWeight: FontWeight.w700,
                                color: kPrimaryDark,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAllWaiting
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 16,
                              color: kPrimaryDark,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
         const SliverToBoxAdapter(child: SizedBox(height: 100)),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LOADING / ERROR BODIES
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildLoadingBody(String greeting, String doctorName) =>
      CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),
          const SliverFillRemaining(
            child:
                Center(child: CircularProgressIndicator(color: kPrimary)),
          ),
        ],
      );

  Widget _buildErrorBody(Object e, String greeting, String doctorName) =>
      CustomScrollView(
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
                    onPressed: () {
                      _hasFetched = false;
                      _loadData();
                    },
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
  // HEADER  — greeting + doctor name, no "Queue Management" label
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(String greeting, String doctorName) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border:
            Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Greeting (was label, now the primary line) ───────
                    Text(
                      greeting,
                      style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary),
                    ),
                    const SizedBox(height: 2),
                    // ── Doctor name ──────────────────────────────────────
                    Text(
                      'Dr. $doctorName',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary),
                    ),
                    const SizedBox(height: 6),
                    // ── Date pill ────────────────────────────────────────
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(20),
                        border:
                            Border.all(color: kPrimary.withOpacity(0.2)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.access_time_rounded,
                              color: kPrimary, size: 10),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('EEEE, d MMMM yyyy')
                                .format(DateTime.now()),
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: kPrimaryDark),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              _headerBtn(
                icon: Icons.notifications_outlined,
                badge: true,
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _headerBtn({
    required IconData icon,
    bool badge = false,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Icon(icon, color: kTextPrimary, size: 17),
        ),
        if (badge)
          Positioned(
            right: 7,
            top: 7,
            child: Container(
              width: 7,
              height: 7,
              decoration:
                  const BoxDecoration(color: kAmber, shape: BoxShape.circle),
            ),
          ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // STAT STRIP
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildStatStrip({
    required int total,
    required int waiting,
    required int done,
  }) {
    return Row(children: [
      _statCard(
          label: 'Total Today',
          value: total.toString().padLeft(2, '0'),
          valueColor: kTextPrimary,
          accent: kPrimary),
      const SizedBox(width: 8),
      _statCard(
          label: 'Waiting',
          value: waiting.toString().padLeft(2, '0'),
          valueColor: kPrimary,
          accent: kPrimary),
      const SizedBox(width: 8),
      _statCard(
          label: 'Done',
          value: done.toString().padLeft(2, '0'),
          valueColor: kGreenDark,
          accent: kGreen),
    ]);
  }

  Widget _statCard({
    required String label,
    required String value,
    required Color valueColor,
    required Color accent,
  }) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Column(children: [
            Container(height: 3, color: accent),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kTextSecondary)),
                    const SizedBox(height: 4),
                    Text(value,
                        style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: valueColor,
                            height: 1)),
                  ]),
            ),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE QUEUE CARD  (unchanged)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQueueCard({
    required AppointmentList? current,
    required int? nextQueueNo,
    required int total,
    required int done,
    required QueueState queueState,
  }) {
    final isRunning = queueState == QueueState.running;
    final isStopped = queueState == QueueState.stopped;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kPrimaryLight.withOpacity(0.8)),
      ),
      padding: const EdgeInsets.all(16),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pulseDot(),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Live Queue Status',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: kPrimary)),
          ),
          _queueStateBadge(queueState),
        ]),
        const SizedBox(height: 12),
        _buildTokenRow(
          currentNo: current?.queueNumber ?? 0,
          nextNo:    nextQueueNo ?? 0,
          total:     total,
        ),
        const SizedBox(height: 12),
        _buildCurrentPatientBand(current),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Daily progress',
              style: TextStyle(fontSize: 10, color: kTextSecondary)),
          Text('$done / $total seen',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kPrimary)),
        ]),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
            minHeight: 7,
            backgroundColor: kPrimaryLight,
            valueColor: const AlwaysStoppedAnimation<Color>(kPrimary),
          ),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: _actionBtn(
              label: isRunning ? '⏸  Pause' : '▶  Resume',
              onTap: isRunning ? _onQueuePause : _onQueueStart,
              isPrimary: isRunning,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Opacity(
              opacity: isStopped ? 0.4 : 1.0,
              child: GestureDetector(
                onTap: isStopped ? null : _onQueueStop,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  decoration: BoxDecoration(
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kRedBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Text('✕  Close Queue',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kRedDark)),
                ),
              ),
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _actionBtn({
    required String label,
    required VoidCallback onTap,
    required bool isPrimary,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          gradient: isPrimary
              ? const LinearGradient(
                  colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight)
              : null,
          color: isPrimary ? null : kAmberLight,
          borderRadius: BorderRadius.circular(12),
          border: isPrimary ? null : Border.all(color: kAmberBorder),
        ),
        alignment: Alignment.center,
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : kAmberDark)),
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
  // QUICK ACTIONS  (unchanged)
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: avBd.withOpacity(0.6)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: avBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: avBd),
          ),
          alignment: Alignment.center,
          child: Text(initials,
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w800, color: avFg)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                  [
                    if (p.gender != null) p.gender!,
                    if (age != null) '$age yrs'
                  ].join(' · '),
                  style:
                      const TextStyle(fontSize: 10, color: kTextSecondary),
                ),
                const SizedBox(height: 5),
                Row(children: [
                  _statusChip(status),
                  if (p.specialization != null) ...[
                    const SizedBox(width: 5),
                    _tagChip(p.specialization!,
                        bg: kPrimaryLighter, fg: kPrimaryDark),
                  ],
                ]),
              ]),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text((p.queueNumber ?? 0).toString().padLeft(2, '0'),
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: avFg,
                  height: 1)),
          const Text('Token',
              style: TextStyle(fontSize: 9, color: kTextMuted)),
        ]),
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
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: fg)),
        ]),
      );

  Widget _tagChip(String label, {required Color bg, required Color fg}) =>
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 9, fontWeight: FontWeight.w700, color: fg)),
      );

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