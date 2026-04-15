import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';

// ─── DESIGN TOKENS ───────────────────────────────────────────────────────────

class _C {
  _C._();
  static const teal = Color(0xFF26C6B0);
  static const tealDark = Color(0xFF2BB5A0);
  static const tealLight = Color(0xFFD9F5F1);
  static const tealLighter = Color(0xFFF2FCFA);
  static const gradFrom = Color(0xFF4DD9C8);
  static const gradTo = Color(0xFF2BB5A0);
  static const t1 = Color(0xFF2D3748);
  static const t2 = Color(0xFF718096);
  static const t3 = Color(0xFFA0AEC0);
  static const border = Color(0xFFEDF2F7);
  static const bg = Color(0xFFF7FFFE);
  static const green = Color(0xFF68D391);
  static const greenDark = Color(0xFF276749);
  static const greenLight = Color(0xFFF0FFF8);
  static const greenBorder = Color(0xFFC6F6D5);
  static const amber = Color(0xFFF6AD55);
  static const amberDark = Color(0xFF975A16);
  static const amberLight = Color(0xFFFFFBEB);
  static const amberBorder = Color(0xFFFCEFC7);
  static const red = Color(0xFFFC8181);
  static const redDark = Color(0xFFC53030);
  static const redLight = Color(0xFFFFF5F5);
  static const redBorder = Color(0xFFFED7D7);
  static const purpleDark = Color(0xFF6B46C1);
  static const purpleLight = Color(0xFFFAF5FF);
  static const purpleBorder = Color(0xFFE9D5FF);
  static const indigoDark = Color(0xFF2C5282);
  static const indigoLight = Color(0xFFEBF8FF);
  static const bottomNavClearance = 100.0;
  static const wideBreak = 800.0;
}

const _avatarColors = [
  (bg: Color(0xFFE0F5F1), fg: Color(0xFF2BB5A0)),
  (bg: Color(0xFFFAF5FF), fg: Color(0xFF6B46C1)),
  (bg: Color(0xFFFFFBEB), fg: Color(0xFF975A16)),
  (bg: Color(0xFFEBF8FF), fg: Color(0xFF2C5282)),
  (bg: Color(0xFFFFF5F5), fg: Color(0xFFC53030)),
  (bg: Color(0xFFF0FFF8), fg: Color(0xFF276749)),
];

enum _TabType { today, upcoming, completed }

// ─── MAIN SCREEN ─────────────────────────────────────────────────────────────

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});
  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  String _searchQuery = '';
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _doctorIdSub;
  AppointmentList? _selectedPatient;
  _TabType _selectedTab = _TabType.today;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) return;
      setState(() {
        _selectedTab = _TabType.values[_tabController.index];
        _selectedPatient = null;
      });
    });
    _searchCtrl.addListener(
      () => setState(() => _searchQuery = _searchCtrl.text.toLowerCase()),
    );
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) {
        if (next != null && next > 0) _refresh(force: false);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh(force: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _doctorIdSub.close();
    super.dispose();
  }

  void _refresh({required bool force}) {
    if (_hasFetched && !force) return;
    final id = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (id == 0) return;
    _hasFetched = true;
    ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(id);
  }

  DateTime? _parseDate(String? raw) =>
      raw == null ? null : DateTime.tryParse(raw.trim());
  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  bool _isAfterToday(DateTime? d) {
    if (d == null) return false;
    final t = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return DateTime(d.year, d.month, d.day).isAfter(t);
  }

  bool _matches(AppointmentList a) {
    if (_searchQuery.isEmpty) return true;
    return (a.patientName?.toLowerCase().contains(_searchQuery) ?? false) ||
        (a.status?.toLowerCase().contains(_searchQuery) ?? false) ||
        (a.queueNumber?.toString().contains(_searchQuery) ?? false);
  }

  List<AppointmentList> _todayList(List<AppointmentList> all) =>
      all.where((a) {
        final s = a.status?.toLowerCase().trim() ?? '';
        if (s != 'booked' && s != 'skipped' && s != 'in_progress') return false;
        return _isToday(_parseDate(a.appointmentDate)) && _matches(a);
      }).toList()..sort(
        (a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0),
      );
  List<AppointmentList> _upcomingList(List<AppointmentList> all) =>
      all.where((a) {
        final s = a.status?.toLowerCase().trim() ?? '';
        if (s != 'booked') return false;
        return _isAfterToday(_parseDate(a.appointmentDate)) && _matches(a);
      }).toList();
  List<AppointmentList> _completedList(List<AppointmentList> all) => all.where((
    a,
  ) {
    final s = a.status?.toLowerCase().trim() ?? '';
    return (s == 'completed' || s == 'done' || s == 'closed') && _matches(a);
  }).toList();

  void _snack(String msg, {bool isError = false}) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? _C.redDark : _C.tealDark,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 2),
        ),
      );

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (pid == 0 || did == 0) {
      _snack('Patient or doctor info missing', isError: true);
      return;
    }
    try {
      await ref
          .read(appointmentViewModelProvider.notifier)
          .startSession(
            AppointmentRequestModel(
              doctorId: did,
              patientId: pid,
              appointmentId: p.appointmentId ?? 0,
            ),
          );
    } catch (_) {}
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionScreen(
          patientId: pid,
          doctorId: did,
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
    final did = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (did == 0) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueSkip(
            AppointmentRequestModel(
              doctorId: did,
              appointmentId: p.appointmentId ?? 0,
              patientId: p.patientId ?? 0,
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
    if ((p.patientId ?? 0) == 0) {
      _snack('Patient info missing', isError: true);
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPrescriptionDetailScreen(
          appointmentId: p.appointmentId ?? 0,
          patientId: p.patientId ?? 0,
          patientName: p.patientName ?? 'Patient',
          patientAge: _ageStr(p.dob),
          patientGender: p.gender,
          queueNumber: p.queueNumber,
        ),
      ),
    );
  }

  void _cancelConfirm(AppointmentList p) => showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text(
        'Cancel Appointment',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
      content: Text(
        'Cancel appointment for ${p.patientName ?? 'this patient'}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          style: TextButton.styleFrom(foregroundColor: _C.t2),
          child: const Text('No'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(ctx);
            _snack('Appointment cancelled');
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.redDark,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            elevation: 0,
          ),
          child: const Text('Yes, Cancel'),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= _C.wideBreak;
    final vmState = ref.watch(appointmentViewModelProvider);
    final apptAsync = vmState.patientAppointmentsList;
    final queueState = vmState.queueState;
    final all = apptAsync.maybeWhen(
      data: (l) => l,
      orElse: () => const <AppointmentList>[],
    );
    final todayList = _todayList(all);
    final upcomingList = _upcomingList(all);
    final completedList = _completedList(all);

    return Scaffold(
      backgroundColor: _C.bg,
      body: apptAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(color: _C.teal)),
        error: (e, _) => _ErrorView(onRetry: () => _refresh(force: true)),
        data: (_) => isWide
            ? _buildDesktop(
                today: todayList,
                upcoming: upcomingList,
                completed: completedList,
                queueState: queueState,
              )
            : _buildMobile(
                today: todayList,
                upcoming: upcomingList,
                completed: completedList,
                queueState: queueState,
              ),
      ),
    );
  }

  // ── MOBILE ────────────────────────────────────────────────────────────────

  Widget _buildMobile({
    required List<AppointmentList> today,
    required List<AppointmentList> upcoming,
    required List<AppointmentList> completed,
    required QueueState queueState,
  }) {
    return Column(
      children: [
        //  _MobileHeader(todayCount: today.length, upcomingCount: upcoming.length, completedCount: completed.length, totalCount: today.length + upcoming.length + completed.length, onTabJump: (i) => _tabController.animateTo(i)),
        // _StatStrip(total: today.length + upcoming.length + completed.length, waiting: today.length, done: completed.length, upcoming: upcoming.length),
        _SearchBar(controller: _searchCtrl),
        _PillTabBar(
          controller: _tabController,
          todayCount: today.length,
          upcomingCount: upcoming.length,
          completedCount: completed.length,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // ★ extraBottomPadding pushes content above the floating pill nav
              _PatientListBody(
                patients: today,
                tabType: _TabType.today,
                queueState: queueState,
                onStart: _startSession,
                onSkip: _skipPatient,
                onPrescription: _viewPrescription,
                onCancel: _cancelConfirm,
                extraBottomPadding: _C.bottomNavClearance,
              ),
              _PatientListBody(
                patients: upcoming,
                tabType: _TabType.upcoming,
                queueState: queueState,
                onStart: _startSession,
                onSkip: _skipPatient,
                onPrescription: _viewPrescription,
                onCancel: _cancelConfirm,
                extraBottomPadding: _C.bottomNavClearance,
              ),
              _PatientListBody(
                patients: completed,
                tabType: _TabType.completed,
                queueState: queueState,
                onStart: _startSession,
                onSkip: _skipPatient,
                onPrescription: _viewPrescription,
                onCancel: _cancelConfirm,
                extraBottomPadding: _C.bottomNavClearance,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── DESKTOP ───────────────────────────────────────────────────────────────

  Widget _buildDesktop({
    required List<AppointmentList> today,
    required List<AppointmentList> upcoming,
    required List<AppointmentList> completed,
    required QueueState queueState,
  }) {
    final currentList = switch (_selectedTab) {
      _TabType.today => today,
      _TabType.upcoming => upcoming,
      _TabType.completed => completed,
    };
    return Row(
      children: [
        _DesktopSidebar(
          selectedTab: _selectedTab,
          todayCount: today.length,
          upcomingCount: upcoming.length,
          completedCount: completed.length,
          total: today.length + upcoming.length + completed.length,
          searchCtrl: _searchCtrl,
          onTabChange: (t) => setState(() {
            _selectedTab = t;
            _selectedPatient = null;
            _tabController.animateTo(_TabType.values.indexOf(t));
          }),
        ),
        Expanded(
          child: _PatientListBody(
            patients: currentList,
            tabType: _selectedTab,
            queueState: queueState,
            onStart: _startSession,
            onSkip: _skipPatient,
            onPrescription: _viewPrescription,
            onCancel: _cancelConfirm,
            selectedPatient: _selectedPatient,
            extraBottomPadding: 0,
            onSelect: (p) => setState(() => _selectedPatient = p),
          ),
        ),
        SizedBox(
          width: 280,
          child: _DetailPanel(
            patient: _selectedPatient,
            tabType: _selectedTab,
            onStart: _startSession,
            onSkip: _skipPatient,
            onPrescription: _viewPrescription,
            onCancel: _cancelConfirm,
          ),
        ),
      ],
    );
  }
}

// ─── MOBILE HEADER ───────────────────────────────────────────────────────────

class _MobileHeader extends StatelessWidget {
  final int todayCount, upcomingCount, completedCount, totalCount;
  final void Function(int) onTabJump;
  const _MobileHeader({
    required this.todayCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.totalCount,
    required this.onTabJump,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final date =
        '${_wd(now.weekday)}, ${now.day.toString().padLeft(2, '0')} ${_mo(now.month)} ${now.year}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_C.gradFrom, _C.gradTo, Color(0xFF1A9D8E)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 14,
        left: 18,
        right: 18,
        bottom: 16,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -45,
            top: -45,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Patient Queue',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _HBtn(icon: Icons.search_rounded, onTap: () {}),
                  const SizedBox(width: 8),
                  Stack(
                    children: [
                      _HBtn(icon: Icons.notifications_outlined, onTap: () {}),
                      Positioned(
                        top: 7,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBD38D),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 7,
                runSpacing: 6,
                children: [
                  _HBadge('$todayCount Today', onTap: () => onTabJump(0)),
                  _HBadge('$upcomingCount Upcoming', onTap: () => onTabJump(1)),
                  _HBadge(
                    '$completedCount Completed',
                    onTap: () => onTabJump(2),
                  ),
                  _HBadge('$totalCount Total'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _wd(int d) => const [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ][d - 1];
  String _mo(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];
}

class _HBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _HBtn({required this.icon, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
  );
}

class _HBadge extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _HBadge(this.text, {this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.25)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    ),
  );
}

// ─── STAT STRIP ──────────────────────────────────────────────────────────────

class _StatStrip extends StatelessWidget {
  final int total, waiting, done, upcoming;
  const _StatStrip({
    required this.total,
    required this.waiting,
    required this.done,
    required this.upcoming,
  });
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
    child: Row(
      children: [
        _SC('Total', total, _C.teal),
        const SizedBox(width: 9),
        _SC('Waiting', waiting, _C.teal),
        const SizedBox(width: 9),
        _SC('Done', done, _C.green),
        const SizedBox(width: 9),
        _SC('Upcoming', upcoming, _C.amber),
      ],
    ),
  );
}

class _SC extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _SC(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Expanded(
    child: ClipRRect(
      borderRadius: BorderRadius.circular(13),
      child: Container(
        color: Colors.white,
        child: Column(
          children: [
            Container(height: 3, color: color),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: _C.t2,
                      letterSpacing: .3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    value.toString().padLeft(2, '0'),
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: color,
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

// ─── SEARCH BAR ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  const _SearchBar({required this.controller});
  @override
  Widget build(BuildContext context) => Container(
    color: Colors.white,
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
    child: Container(
      height: 42,
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.border),
      ),
      child: Row(
        children: [
          const SizedBox(width: 12),
          const Icon(Icons.search_rounded, size: 17, color: _C.t3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(fontSize: 13, color: _C.t1),
              decoration: const InputDecoration(
                hintText: 'Search by name, status or queue...',
                hintStyle: TextStyle(fontSize: 13, color: _C.t3),
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              onTap: controller.clear,
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(Icons.clear_rounded, size: 16, color: _C.t3),
              ),
            ),
        ],
      ),
    ),
  );
}

// ─── PILL TAB BAR ────────────────────────────────────────────────────────────

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
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
    child: Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF0F5F3),
        borderRadius: BorderRadius.circular(24),
      ),
      child: TabBar(
        controller: controller,
        labelColor: _C.tealDark,
        unselectedLabelColor: _C.t2,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 6,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        indicatorPadding: const EdgeInsets.all(3),
        labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
        unselectedLabelStyle: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
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

// ─── DESKTOP SIDEBAR ─────────────────────────────────────────────────────────

class _DesktopSidebar extends StatelessWidget {
  final _TabType selectedTab;
  final int todayCount, upcomingCount, completedCount, total;
  final TextEditingController searchCtrl;
  final void Function(_TabType) onTabChange;
  const _DesktopSidebar({
    required this.selectedTab,
    required this.todayCount,
    required this.upcomingCount,
    required this.completedCount,
    required this.total,
    required this.searchCtrl,
    required this.onTabChange,
  });
  @override
  Widget build(BuildContext context) => Container(
    width: 260,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(right: BorderSide(color: _C.border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 14,
            left: 16,
            right: 16,
            bottom: 14,
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [_C.gradFrom, _C.gradTo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Patient Queue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                '${DateTime.now().day} ${const ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'][DateTime.now().month - 1]} ${DateTime.now().year}',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.72),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: _C.bg,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: _C.border),
            ),
            child: Row(
              children: [
                const SizedBox(width: 10),
                const Icon(Icons.search_rounded, size: 15, color: _C.t3),
                const SizedBox(width: 7),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    style: const TextStyle(fontSize: 12, color: _C.t1),
                    decoration: const InputDecoration(
                      hintText: 'Search patients...',
                      hintStyle: TextStyle(fontSize: 12, color: _C.t3),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Column(
            children: [
              _SNI(
                icon: Icons.access_time_rounded,
                label: 'Today',
                count: todayCount,
                selected: selectedTab == _TabType.today,
                onTap: () => onTabChange(_TabType.today),
              ),
              const SizedBox(height: 4),
              _SNI(
                icon: Icons.calendar_today_rounded,
                label: 'Upcoming',
                count: upcomingCount,
                selected: selectedTab == _TabType.upcoming,
                onTap: () => onTabChange(_TabType.upcoming),
              ),
              const SizedBox(height: 4),
              _SNI(
                icon: Icons.check_circle_outline_rounded,
                label: 'Completed',
                count: completedCount,
                selected: selectedTab == _TabType.completed,
                onTap: () => onTabChange(_TabType.completed),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 14),
          child: Text(
            'OVERVIEW',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: _C.t3,
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1.4,
            children: [
              _MS('Total', total, _C.teal),
              _MS('Waiting', todayCount, _C.teal),
              _MS('Done', completedCount, _C.green),
              _MS('Upcoming', upcomingCount, _C.amber),
            ],
          ),
        ),
      ],
    ),
  );
}

class _SNI extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  const _SNI({
    required this.icon,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    behavior: HitTestBehavior.opaque,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? _C.teal.withOpacity(0.10) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: _C.teal.withOpacity(0.22)) : null,
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: selected ? _C.teal : _C.t3),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? _C.tealDark : _C.t2,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: selected ? _C.teal : _C.tealLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: selected ? Colors.white : _C.tealDark,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _MS extends StatelessWidget {
  final String label;
  final int value;
  final Color color;
  const _MS(this.label, this.value, this.color);
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: _C.bg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: _C.border),
    ),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          value.toString().padLeft(2, '0'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w500,
            color: _C.t2,
          ),
        ),
      ],
    ),
  );
}

// ─── PATIENT LIST BODY ────────────────────────────────────────────────────────
// ★ THE CORE FIX IS HERE: extraBottomPadding is added to ListView padding

class _PatientListBody extends ConsumerWidget {
  final List<AppointmentList> patients;
  final _TabType tabType;
  final QueueState queueState;
  final Future<void> Function(AppointmentList) onStart;
  final Future<void> Function(AppointmentList) onSkip;
  final void Function(AppointmentList) onPrescription;
  final void Function(AppointmentList) onCancel;
  final AppointmentList? selectedPatient;
  final void Function(AppointmentList)? onSelect;
  final double extraBottomPadding;

  const _PatientListBody({
    required this.patients,
    required this.tabType,
    required this.queueState,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
    required this.extraBottomPadding,
    this.selectedPatient,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (patients.isEmpty) return _EmptyState(tabType: tabType);

    final hasInProgress =
        tabType == _TabType.today &&
        patients.any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
    final firstBooked = (tabType == _TabType.today && !hasInProgress)
        ? (patients
                  .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
                  .toList()
                ..sort(
                  (a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0),
                ))
              .firstOrNull
        : null;
    final isQueueActive =
        queueState == QueueState.running || queueState == QueueState.paused;
    final isToday = tabType == _TabType.today;
    final headerCount = isToday ? 2 : 1;

    return RefreshIndicator(
      color: _C.teal,
      onRefresh: () async => ref
          .read(appointmentViewModelProvider.notifier)
          .fetchPatientAppointments(
            ref.read(doctorLoginViewModelProvider).doctorId ?? 0,
          ),
      child: ListView.builder(
        // ★ CRITICAL: bottom = 12 (breathing room) + extraBottomPadding
        // On mobile this is 12 + 100 = 112px → last card clears pill nav.
        // On desktop this is 12 + 0  = 12px  → normal.
        padding: EdgeInsets.fromLTRB(14, 12, 14, 12 + extraBottomPadding),
        itemCount: patients.length + headerCount,
        itemBuilder: (ctx, i) {
          if (i == 0 && isToday)
            return _LiveQueueCard(
              patients: patients,
              queueState: queueState,
              onStart: onStart,
              onSkip: onSkip,
            );
          if ((isToday && i == 1) || (!isToday && i == 0)) {
            final title = switch (tabType) {
              _TabType.today => 'Waiting',
              _TabType.upcoming => 'Upcoming',
              _TabType.completed => 'Completed',
            };
            final badge = switch (tabType) {
              _TabType.today => '${patients.length} left',
              _TabType.upcoming => '${patients.length} scheduled',
              _TabType.completed => '${patients.length} done',
            };
            return _SectionHeader(title: title, badge: badge);
          }
          final p = patients[i - headerCount];
          final status = p.status?.toLowerCase() ?? '';
          bool accessible = true;
          if (tabType == _TabType.today) {
            if (status == 'in_progress') {
              accessible = true;
            } else if (!isQueueActive) {
              accessible = false;
            } else if (status == 'booked') {
              accessible =
                  !hasInProgress && p.queueNumber == firstBooked?.queueNumber;
            } else if (status == 'skipped') {
              accessible = !hasInProgress;
            }
          }
          return _PatientCard(
            key: ValueKey(p.appointmentId),
            patient: p,
            tabType: tabType,
            accessible: accessible,
            selected: selectedPatient?.appointmentId == p.appointmentId,
            onTap: onSelect != null ? () => onSelect!(p) : null,
            onStart: () => onStart(p),
            onSkip:
                accessible && tabType == _TabType.today && status == 'booked'
                ? () => onSkip(p)
                : null,
            onPrescription: () => onPrescription(p),
            onCancel: () => onCancel(p),
          );
        },
      ),
    );
  }
}

// ─── LIVE QUEUE CARD ─────────────────────────────────────────────────────────

class _LiveQueueCard extends StatelessWidget {
  final List<AppointmentList> patients;
  final QueueState queueState;
  final Future<void> Function(AppointmentList) onStart;
  final Future<void> Function(AppointmentList) onSkip;
  const _LiveQueueCard({
    required this.patients,
    required this.queueState,
    required this.onStart,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final ip = patients.firstWhere(
      (p) => (p.status?.toLowerCase() ?? '') == 'in_progress',
      orElse: () => AppointmentList(),
    );
    final hasIP = (ip.appointmentId ?? 0) != 0;
    final booked =
        patients
            .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
            .toList()
          ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current = hasIP ? ip : booked.firstOrNull;
    final next = hasIP
        ? booked.firstOrNull
        : (booked.length > 1 ? booked[1] : null);
    final isRunning = queueState == QueueState.running;
    final name = current?.patientName ?? current?.bookingFor ?? '—';
    final inits = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();

    String info = '';
    if (current != null) {
      final parts = <String>[];
      if (current.gender != null) parts.add(current.gender!);
      final d = current.dob == null ? null : DateTime.tryParse(current.dob!);
      if (d != null) {
        final now = DateTime.now();
        var y = now.year - d.year;
        if (now.month < d.month || (now.month == d.month && now.day < d.day))
          y--;
        if (y >= 0) parts.add('$y yrs');
      }
      info = parts.join(' · ');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _C.tealLight.withOpacity(0.6)),
          boxShadow: [
            BoxShadow(
              color: _C.teal.withOpacity(0.10),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _PulseDot(),
                const SizedBox(width: 7),
                const Text(
                  'LIVE QUEUE',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: _C.teal,
                  ),
                ),
                const Spacer(),
                _QSBadge(state: queueState),
                const SizedBox(width: 8),
                _CtrlBtn(
                  icon: Icons.pause_rounded,
                  enabled: isRunning,
                  onTap: () {},
                ),
                const SizedBox(width: 4),
                _CtrlBtn(
                  icon: Icons.stop_rounded,
                  enabled: true,
                  isRed: true,
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _TokBox(
                  label: 'CURRENT',
                  value: (current?.queueNumber ?? 0).toString().padLeft(2, '0'),
                  isActive: true,
                ),
                const SizedBox(width: 9),
                _TokBox(
                  label: 'UP NEXT',
                  value: next != null
                      ? (next.queueNumber ?? 0).toString().padLeft(2, '0')
                      : '--',
                ),
                const SizedBox(width: 9),
                _TokBox(
                  label: 'REMAINING',
                  value: patients.length.toString().padLeft(2, '0'),
                  isGreen: true,
                ),
              ],
            ),
            const SizedBox(height: 13),
            if (current == null)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _C.tealLighter,
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(color: _C.tealLight),
                ),
                child: const Center(
                  child: Text(
                    'No active patient',
                    style: TextStyle(color: _C.t2, fontSize: 13),
                  ),
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(13),
                decoration: BoxDecoration(
                  color: _C.tealLighter,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _C.tealLight),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
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
                            inits,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 1,
                          right: 1,
                          child: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _C.green,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: _C.tealLighter,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _C.t1,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (info.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              info,
                              style: const TextStyle(
                                fontSize: 11,
                                color: _C.t2,
                              ),
                            ),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 7,
                                height: 7,
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
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
              ),
            const SizedBox(height: 13),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: const [
                Text(
                  'Daily progress',
                  style: TextStyle(fontSize: 11, color: _C.t2),
                ),
                Text(
                  '— / — seen',
                  style: TextStyle(
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
              child: const LinearProgressIndicator(
                value: 0.5,
                minHeight: 7,
                backgroundColor: _C.tealLight,
                valueColor: AlwaysStoppedAnimation<Color>(_C.teal),
              ),
            ),
            const SizedBox(height: 13),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: current != null ? () => onSkip(current) : null,
                    child: Opacity(
                      opacity: current != null ? 1.0 : 0.4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: _C.redLight,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _C.redBorder),
                        ),
                        alignment: Alignment.center,
                        child: const Text(
                          '⏭  Skip',
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
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: GestureDetector(
                    onTap: current != null ? () => onStart(current) : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      decoration: BoxDecoration(
                        gradient: current != null
                            ? const LinearGradient(
                                colors: [_C.gradFrom, _C.gradTo],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : null,
                        color: current == null ? _C.border : null,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        (current?.status?.toLowerCase() ?? '') == 'in_progress'
                            ? '▶  Continue'
                            : '▶  Start Session',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: current != null ? Colors.white : _C.t3,
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
    );
  }
}

class _PulseDot extends StatefulWidget {
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: Tween<double>(
      begin: .35,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
    child: Container(
      width: 8,
      height: 8,
      decoration: const BoxDecoration(color: _C.teal, shape: BoxShape.circle),
    ),
  );
}

class _CtrlBtn extends StatelessWidget {
  final IconData icon;
  final bool enabled, isRed;
  final VoidCallback onTap;
  const _CtrlBtn({
    required this.icon,
    required this.enabled,
    required this.onTap,
    this.isRed = false,
  });
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: enabled ? 1.0 : 0.3,
    child: GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          color: isRed ? _C.redLight : _C.tealLighter,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(color: isRed ? _C.redBorder : _C.tealLight),
        ),
        child: Icon(icon, size: 15, color: isRed ? _C.redDark : _C.teal),
      ),
    ),
  );
}

class _TokBox extends StatelessWidget {
  final String label, value;
  final bool isActive, isGreen;
  const _TokBox({
    required this.label,
    required this.value,
    this.isActive = false,
    this.isGreen = false,
  });
  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        gradient: isActive
            ? const LinearGradient(
                colors: [_C.gradFrom, _C.gradTo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isActive
            ? null
            : isGreen
            ? _C.greenLight
            : _C.tealLighter,
        borderRadius: BorderRadius.circular(13),
        border: isActive
            ? null
            : Border.all(color: isGreen ? _C.greenBorder : _C.tealLight),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: .8,
              color: isActive
                  ? Colors.white.withOpacity(0.78)
                  : isGreen
                  ? _C.greenDark
                  : _C.t2,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: isActive
                  ? Colors.white
                  : isGreen
                  ? _C.greenDark
                  : _C.t1,
              height: 1,
            ),
          ),
        ],
      ),
    ),
  );
}

class _QSBadge extends StatelessWidget {
  final QueueState state;
  const _QSBadge({required this.state});
  @override
  Widget build(BuildContext context) {
    final (String label, Color bg, Color fg, Color dot) = switch (state) {
      QueueState.running => ('Running', _C.tealLighter, _C.tealDark, _C.teal),
      QueueState.paused => ('Paused', _C.amberLight, _C.amberDark, _C.amber),
      QueueState.stopped => (
        'Closed',
        const Color(0xFFF3F4F6),
        const Color(0xFF6B7280),
        const Color(0xFF9CA3AF),
      ),
      QueueState.idle => ('Idle', _C.redLight, _C.redDark, _C.red),
    };
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
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── SECTION HEADER ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title, badge;
  const _SectionHeader({required this.title, required this.badge});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _C.t1,
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
            badge,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: _C.tealDark,
            ),
          ),
        ),
      ],
    ),
  );
}

// ─── PATIENT CARD ─────────────────────────────────────────────────────────────

class _PatientCard extends StatelessWidget {
  final AppointmentList patient;
  final _TabType tabType;
  final bool accessible, selected;
  final VoidCallback? onTap, onSkip;
  final VoidCallback onStart, onPrescription, onCancel;
  const _PatientCard({
    super.key,
    required this.patient,
    required this.tabType,
    required this.accessible,
    required this.selected,
    required this.onTap,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
  });

  ({Color bg, Color fg}) get _av =>
      _avatarColors[(patient.appointmentId ?? 0) % _avatarColors.length];
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
    return parts.join(' · ');
  }

  String _fd(String? raw) {
    if (raw == null) return '—';
    final d = DateTime.tryParse(raw);
    if (d == null) return raw;
    const m = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${d.day} ${m[d.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    final av = _av;
    final st = patient.status ?? 'unknown';
    final isIP = st.toLowerCase() == 'in_progress';
    final (Color sBg, Color sFg, Color sDot) = switch (st.toLowerCase()) {
      'booked' => (_C.greenLight, _C.greenDark, _C.green),
      'in_progress' => (_C.tealLighter, _C.tealDark, _C.teal),
      'skipped' => (_C.amberLight, _C.amberDark, _C.amber),
      'completed' ||
      'done' ||
      'closed' => (_C.greenLight, _C.greenDark, _C.green),
      _ => (_C.redLight, _C.redDark, _C.red),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? _C.teal : _C.border,
              width: selected ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: selected
                    ? _C.teal.withOpacity(0.12)
                    : Colors.black.withOpacity(0.04),
                blurRadius: selected ? 12 : 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(13),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: av.bg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      _inits,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: av.fg,
                      ),
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          patient.patientName ?? 'Patient',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _C.t1,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _info,
                          style: const TextStyle(fontSize: 11, color: _C.t2),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 5,
                          runSpacing: 4,
                          children: [
                            if (patient.specialization != null)
                              _TC(
                                label: patient.specialization!,
                                bg: _C.tealLighter,
                                fg: _C.tealDark,
                              ),
                            _DB(
                              label:
                                  st[0].toUpperCase() +
                                  st.substring(1).replaceAll('_', ' '),
                              bg: sBg,
                              fg: sFg,
                              dot: sDot,
                            ),
                            _TC(
                              label: _fd(patient.appointmentDate),
                              bg: _C.indigoLight,
                              fg: _C.indigoDark,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        (patient.queueNumber ?? 0).toString().padLeft(2, '0'),
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: av.fg,
                          height: 1,
                        ),
                      ),
                      const Text(
                        'Token',
                        style: TextStyle(fontSize: 10, color: _C.t3),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (tabType == _TabType.today) ...[
                    if (onSkip != null) ...[
                      Expanded(
                        child: _AB(
                          label: '⏭  Skip',
                          bg: _C.redLight,
                          fg: _C.redDark,
                          border: _C.redBorder,
                          onTap: onSkip,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      flex: 2,
                      child: _AB(
                        label: isIP ? '▶  Continue' : '▶  Start Session',
                        isGrad: accessible,
                        bg: accessible ? null : _C.border,
                        fg: accessible ? Colors.white : _C.t3,
                        onTap: accessible ? onStart : null,
                      ),
                    ),
                  ] else if (tabType == _TabType.upcoming) ...[
                    Expanded(
                      child: _AB(
                        label: 'View',
                        bg: _C.tealLighter,
                        fg: _C.tealDark,
                        border: _C.tealLight,
                        onTap: () {},
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AB(
                        label: '✕  Cancel',
                        bg: _C.redLight,
                        fg: _C.redDark,
                        border: _C.redBorder,
                        onTap: onCancel,
                      ),
                    ),
                  ] else ...[
                    Expanded(
                      child: _AB(
                        label: '📋  Prescription',
                        bg: _C.purpleLight,
                        fg: _C.purpleDark,
                        border: _C.purpleBorder,
                        onTap: onPrescription,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _AB(
                        label: '✓  Done',
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
      ),
    );
  }
}

class _TC extends StatelessWidget {
  final String label;
  final Color bg, fg;
  const _TC({required this.label, required this.bg, required this.fg});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
    ),
  );
}

class _DB extends StatelessWidget {
  final String label;
  final Color bg, fg, dot;
  const _DB({
    required this.label,
    required this.bg,
    required this.fg,
    required this.dot,
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(7),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
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
  );
}

class _AB extends StatelessWidget {
  final String label;
  final Color? bg, fg, border;
  final bool isGrad;
  final VoidCallback? onTap;
  const _AB({
    required this.label,
    this.bg,
    required this.fg,
    this.border,
    this.isGrad = false,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => Opacity(
    opacity: onTap != null ? 1.0 : 0.42,
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: isGrad
              ? const LinearGradient(
                  colors: [_C.gradFrom, _C.gradTo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isGrad ? null : bg,
          borderRadius: BorderRadius.circular(10),
          border: border != null ? Border.all(color: border!) : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: fg,
          ),
        ),
      ),
    ),
  );
}

// ─── DETAIL PANEL ────────────────────────────────────────────────────────────

class _DetailPanel extends StatelessWidget {
  final AppointmentList? patient;
  final _TabType tabType;
  final Future<void> Function(AppointmentList) onStart, onSkip;
  final void Function(AppointmentList) onPrescription, onCancel;
  const _DetailPanel({
    required this.patient,
    required this.tabType,
    required this.onStart,
    required this.onSkip,
    required this.onPrescription,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    if (patient == null)
      return Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(left: BorderSide(color: _C.border)),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_search_rounded, size: 44, color: _C.t3),
            SizedBox(height: 12),
            Text(
              'Select a patient',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _C.t2,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'to view details',
              style: TextStyle(fontSize: 12, color: _C.t3),
            ),
          ],
        ),
      );
    final p = patient!;
    final av = _avatarColors[(p.appointmentId ?? 0) % _avatarColors.length];
    final name = p.patientName ?? 'Patient';
    final inits = name
        .trim()
        .split(' ')
        .take(2)
        .map((w) => w.isNotEmpty ? w[0] : '')
        .join()
        .toUpperCase();
    String _fd(String? raw) {
      if (raw == null) return '—';
      final d = DateTime.tryParse(raw);
      if (d == null) return raw;
      const m = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${d.day} ${m[d.month - 1]} ${d.year}';
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: _C.border)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(color: av.bg, shape: BoxShape.circle),
              alignment: Alignment.center,
              child: Text(
                inits,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: av.fg,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              name,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _C.t1,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 3),
            Text(
              [if (p.gender != null) p.gender!].join(' · '),
              style: const TextStyle(fontSize: 12, color: _C.t2),
              textAlign: TextAlign.center,
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 14),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: _C.tealLighter,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: _C.tealLight),
              ),
              width: double.infinity,
              child: Column(
                children: [
                  Text(
                    (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      color: _C.teal,
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Token',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: _C.t2,
                    ),
                  ),
                ],
              ),
            ),
            _DR('Specialty', p.specialization ?? '—'),
            _DR(
              'Status',
              (p.status ?? 'Unknown')[0].toUpperCase() +
                  (p.status ?? 'unknown').substring(1),
            ),
            _DR('Date', _fd(p.appointmentDate)),
            _DR('Appt. ID', '${p.appointmentId ?? '—'}'),
            const SizedBox(height: 16),
            if (tabType == _TabType.today) ...[
              _DPB(
                label: '▶  Start Session',
                isGrad: true,
                onTap: () => onStart(p),
              ),
              const SizedBox(height: 8),
              _DPB(
                label: '⏭  Skip',
                bg: _C.redLight,
                fg: _C.redDark,
                border: _C.redBorder,
                onTap: () => onSkip(p),
              ),
            ] else if (tabType == _TabType.upcoming)
              _DPB(
                label: '✕  Cancel',
                bg: _C.redLight,
                fg: _C.redDark,
                border: _C.redBorder,
                onTap: () => onCancel(p),
              )
            else
              _DPB(
                label: '📋  Prescription',
                bg: _C.purpleLight,
                fg: _C.purpleDark,
                border: _C.purpleBorder,
                onTap: () => onPrescription(p),
              ),
          ],
        ),
      ),
    );
  }
}

class _DR extends StatelessWidget {
  final String k, v;
  const _DR(this.k, this.v);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 9),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(fontSize: 12, color: _C.t2)),
        Text(
          v,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _C.t1,
          ),
        ),
      ],
    ),
  );
}

class _DPB extends StatelessWidget {
  final String label;
  final bool isGrad;
  final Color? bg, fg, border;
  final VoidCallback onTap;
  const _DPB({
    required this.label,
    this.isGrad = false,
    this.bg,
    this.fg,
    this.border,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        gradient: isGrad
            ? const LinearGradient(
                colors: [_C.gradFrom, _C.gradTo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : null,
        color: isGrad ? null : bg,
        borderRadius: BorderRadius.circular(12),
        border: border != null ? Border.all(color: border!) : null,
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
          color: isGrad ? Colors.white : fg,
        ),
      ),
    ),
  );
}

// ─── EMPTY & ERROR ────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final _TabType tabType;
  const _EmptyState({required this.tabType});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.person_search_rounded, size: 48, color: _C.t3),
        const SizedBox(height: 12),
        Text(
          switch (tabType) {
            _TabType.today => 'No patients today',
            _TabType.upcoming => 'No upcoming appointments',
            _TabType.completed => 'No completed appointments',
          },
          style: const TextStyle(
            color: _C.t2,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    ),
  );
}

class _ErrorView extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorView({required this.onRetry});
  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: const BoxDecoration(
            color: _C.redLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.error_outline_rounded,
            color: _C.redDark,
            size: 28,
          ),
        ),
        const SizedBox(height: 14),
        const Text(
          'Failed to load appointments',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: _C.t1,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          'Check your connection and try again.',
          style: TextStyle(fontSize: 13, color: _C.t2),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, size: 18),
          label: const Text(
            'Retry',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: _C.teal,
            foregroundColor: Colors.white,
            elevation: 0,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
      ],
    ),
  );
}
