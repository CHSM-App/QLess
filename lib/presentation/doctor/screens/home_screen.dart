import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';

// ─── Home Page ────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});
  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

class _QueueHomePageState extends ConsumerState<QueueHomePage> {
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _doctorIdSub;

  // ─── Lifecycle ─────────────────────────────────────────────────────────────

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

  // ─── Data ──────────────────────────────────────────────────────────────────

  int get _doctorId =>
      ref.read(doctorLoginViewModelProvider).doctorId ?? 0;

  void _loadData() {
    if (_hasFetched) return;
    if (_doctorId == 0) return;
    _hasFetched = true;
    ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(_doctorId);
  }

  /// Returns today's queue appointments sorted by queue_number ascending.
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
      ..sort((a, b) =>
          (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
  }

  // ─── Actions ───────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
    ));
  }

  Future<void> _onQueueStart() async {
    if (_doctorId == 0) return;
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
    if (_doctorId == 0) return;
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
    if (_doctorId == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId));
      _snack(res.message ?? 'Queue stopped');
    } catch (_) {
      _snack('Failed to stop queue');
    }
  }

  Future<void> _onQueueNext(AppointmentList current) async {
    if (_doctorId == 0) return;
    try {
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueNext(AppointmentRequestModel(
            doctorId: _doctorId,
            appointmentDate: today,
          ));
      _snack(res.message ?? 'Next patient');
    } catch (_) {
      _snack('Failed');
    }
  }

  Future<void> _onQueueSkip() async {
    if (_doctorId == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueSkip(AppointmentRequestModel(doctorId: _doctorId));
      _snack(res.message ?? 'Patient skipped');
    } catch (_) {
      _snack('Failed to skip');
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(appointmentViewModelProvider);
    final queueState = vmState.queueState;
    final appointmentsAsync = vmState.patientAppointmentsList;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1565C0), Color.fromARGB(255, 208, 234, 253)],
            stops: [0.0, 0.35],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(28),
                    topRight: Radius.circular(28),
                  ),
                  child: Container(
                    color: const Color(0xFFF0F4F8),
                    child: appointmentsAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                      ),
                      error: (e, _) => Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.error_outline, color: Color(0xFFC62828), size: 40),
                            const SizedBox(height: 8),
                            Text('$e', style: const TextStyle(color: Color(0xFF90A4AE))),
                            const SizedBox(height: 12),
                            TextButton(
                              onPressed: () {
                                _hasFetched = false;
                                _loadData();
                              },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (list) {
                        final todayQueue = _todayQueue(list);
                        final current =
                            todayQueue.isNotEmpty ? todayQueue.first : null;
                        final waiting = todayQueue.length > 1
                            ? todayQueue.skip(1).toList()
                            : <AppointmentList>[];
                        final nextNo = waiting.isNotEmpty
                            ? waiting.first.queueNumber
                            : null;

                        return SingleChildScrollView(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 20),
                              _buildQueueCard(
                                current: current,
                                nextQueueNo: nextNo,
                                total: todayQueue.length,
                                queueState: queueState,
                              ),
                              const SizedBox(height: 14),
                              _buildQuickActions(current),
                              const SizedBox(height: 6),
                              _buildWaitingHeader(waiting.length),
                              _buildPatientList(waiting),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    final today = DateFormat('EEEE, d MMMM').format(DateTime.now());
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Queue Management',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                today,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.75),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Queue Card ────────────────────────────────────────────────────────────

  Widget _buildQueueCard({
    required AppointmentList? current,
    required int? nextQueueNo,
    required int total,
    required QueueState queueState,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.12),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'LIVE QUEUE STATUS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 12),
            _buildTokenRow(
              currentNo: current?.queueNumber ?? 0,
              nextNo: nextQueueNo ?? 0,
              total: total,
            ),
            const SizedBox(height: 14),
            _buildCurrentPatientRow(current, queueState),
            const SizedBox(height: 14),
            _buildActionButtons(queueState),
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
    return Row(
      children: [
        _tokenBox(
          label: 'Current',
          value: currentNo.toString().padLeft(2, '0'),
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          labelColor: Colors.white70,
          valueColor: Colors.white,
        ),
        const SizedBox(width: 10),
        _tokenBox(
          label: 'Up Next',
          value: nextNo > 0 ? nextNo.toString().padLeft(2, '0') : '--',
          color: const Color(0xFFF0F4F8),
          labelColor: const Color(0xFF90A4AE),
          valueColor: const Color(0xFF37474F),
        ),
        const SizedBox(width: 10),
        _tokenBox(
          label: 'Total',
          value: total.toString().padLeft(2, '0'),
          color: const Color(0xFFE8F5E9),
          labelColor: const Color(0xFF81C784),
          valueColor: const Color(0xFF2E7D32),
        ),
      ],
    );
  }

  Widget _tokenBox({
    required String label,
    required String value,
    Gradient? gradient,
    Color? color,
    required Color labelColor,
    required Color valueColor,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(
          gradient: gradient,
          color: color,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: labelColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.w700,
                color: valueColor,
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentPatientRow(
      AppointmentList? patient, QueueState queueState) {
    if (patient == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text(
          'No patients in queue today',
          style: TextStyle(color: Color(0xFF90A4AE)),
        ),
      );
    }

    final age = _calcAge(patient.dob);
    final name =
        patient.patientName ?? patient.bookingFor ?? 'Unknown';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border.symmetric(
          horizontal: BorderSide(color: Color(0xFFF0F4F8), width: 1),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (patient.gender != null) patient.gender!,
                    if (age != null) '$age yrs',
                  ].join(' · '),
                  style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
          _queueStateBadge(queueState),
        ],
      ),
    );
  }

  Widget _buildActionButtons(QueueState queueState) {
    final isRunning = queueState == QueueState.running;
    final isStopped = queueState == QueueState.stopped;

    return Row(
      children: [
        _actionBtn(
          label: '▶  Start',
          gradient: const LinearGradient(
            colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
          ),
          textColor: Colors.white,
          onTap: _onQueueStart,
          enabled: !isRunning && !isStopped,
        ),
        const SizedBox(width: 8),
        _actionBtn(
          label: '⏸  Pause',
          color: const Color(0xFFFFF8E1),
          textColor: const Color(0xFFF57F17),
          border: Border.all(color: const Color(0xFFFFE082), width: 1.5),
          onTap: _onQueuePause,
          enabled: isRunning,
        ),
        const SizedBox(width: 8),
        _actionBtn(
          label: '✕  Close',
          color: const Color(0xFFFFEBEE),
          textColor: const Color(0xFFC62828),
          border: Border.all(color: const Color(0xFFFFCDD2), width: 1.5),
          onTap: _onQueueStop,
          enabled: !isStopped,
        ),
      ],
    );
  }

  Widget _actionBtn({
    required String label,
    required VoidCallback onTap,
    Gradient? gradient,
    Color? color,
    required Color textColor,
    Border? border,
    bool enabled = true,
  }) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 11),
            decoration: BoxDecoration(
              gradient: gradient,
              color: color,
              borderRadius: BorderRadius.circular(12),
              border: border,
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Quick Actions ─────────────────────────────────────────────────────────

  Widget _buildQuickActions(AppointmentList? current) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1565C0).withOpacity(0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'QUICK ACTIONS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
                color: Color(0xFF1E88E5),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _quickBtn(
                  label: '✓  Mark Complete',
                  color: const Color(0xFFE8F5E9),
                  textColor: const Color(0xFF2E7D32),
                  onTap:
                      current != null ? () => _onQueueNext(current) : null,
                ),
                const SizedBox(width: 10),
                _quickBtn(
                  label: '⏭  Skip Patient',
                  color: const Color(0xFFFBE9E7),
                  textColor: const Color(0xFFBF360C),
                  onTap: current != null ? _onQueueSkip : null,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _quickBtn({
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback? onTap,
  }) {
    return Expanded(
      child: Opacity(
        opacity: onTap != null ? 1.0 : 0.4,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(12),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Waiting List ──────────────────────────────────────────────────────────

  Widget _buildWaitingHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Waiting Patients',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1A237E),
            ),
          ),
          Text(
            '$count remaining',
            style: const TextStyle(fontSize: 12, color: Color(0xFF90A4AE)),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientList(List<AppointmentList> patients) {
    if (patients.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(
          child: Text(
            'No patients waiting',
            style: TextStyle(color: Color(0xFF90A4AE)),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: patients.map(_patientCard).toList(),
      ),
    );
  }

  Widget _patientCard(AppointmentList p) {
    final name = p.patientName ?? p.bookingFor ?? 'Unknown';
    final initials = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    final age = _calcAge(p.dob);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1565C0).withOpacity(0.07),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _avatarCircle(initials),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1A237E),
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
                      fontSize: 12, color: Color(0xFF90A4AE)),
                ),
                const SizedBox(height: 6),
                _statusChip(p.status ?? 'booked'),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E88E5),
                  height: 1,
                ),
              ),
              const Text(
                'Token',
                style: TextStyle(fontSize: 10, color: Color(0xFFB0BEC5)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    if (d == null) return null;
    return DateTime.now().year - d.year;
  }

  Widget _avatarCircle(String initials) {
    return Container(
      width: 44,
      height: 44,
      decoration: const BoxDecoration(
        color: Color(0xFFE3F2FD),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: Color(0xFF1565C0),
        ),
      ),
    );
  }

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'skipped':
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        dot = const Color(0xFFFFB300);
        break;
      case 'completed':
        bg = const Color(0xFFE3F2FD);
        fg = const Color(0xFF1565C0);
        dot = const Color(0xFF1E88E5);
        break;
      default: // booked / waiting
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        dot = const Color(0xFFE53935);
    }
    final label = status[0].toUpperCase() + status.substring(1);
    return _badge(label, bg, fg, dot);
  }

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running';
        bg = const Color(0xFFE8F5E9);
        fg = const Color(0xFF2E7D32);
        dot = const Color(0xFF43A047);
        break;
      case QueueState.paused:
        label = 'Paused';
        bg = const Color(0xFFFFF8E1);
        fg = const Color(0xFFF57F17);
        dot = const Color(0xFFFFB300);
        break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFEFEFEF);
        fg = const Color(0xFF616161);
        dot = const Color(0xFF9E9E9E);
        break;
      case QueueState.idle:
        label = 'Waiting';
        bg = const Color(0xFFFFEBEE);
        fg = const Color(0xFFC62828);
        dot = const Color(0xFFE53935);
        break;
    }
    return _badge(label, bg, fg, dot);
  }

  Widget _badge(String label, Color bg, Color fg, Color dot) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
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
              letterSpacing: 0.4,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
