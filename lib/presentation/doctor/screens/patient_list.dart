
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/patient/screens/appintment_screen.dart';

// ------------------------- Main Screen -------------------------

class PatientListScreen extends ConsumerStatefulWidget {
  const PatientListScreen({super.key});

  @override
  ConsumerState<PatientListScreen> createState() => _PatientListScreenState();
}

class _PatientListScreenState extends ConsumerState<PatientListScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _doctorIdSub;

  static const Color primary = Color(0xFF00450D);
  static const Color primaryContainer = Color(0xFF1B5E20);
  static const Color surface = Color(0xFFF9F9F9);
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color surfaceLow = Color(0xFFF3F3F3);
  static const Color surfaceHigh = Color(0xFFE8E8E8);
  static const Color outlineVariant = Color(0xFFC0C9BB);
  static const Color secondaryContainer = Color(0xFFC9E7CA);
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF41493E);
  static const Color error = Color(0xFFBA1A1A);

  @override
  void initState() {
    super.initState();
    // 3 tabs: Today, Upcoming, Completed
    _tabController = TabController(length: 3, vsync: this);
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (prev, next) {
        if (next != null && next > 0) {
          _refreshAppointments(force: false);
        }
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _refreshAppointments(force: false);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _doctorIdSub.close();
    super.dispose();
  }

  void _refreshAppointments({required bool force}) {
    if (_hasFetched && !force) return;
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (doctorId == 0) return;
    _hasFetched = true;
    ref
        .read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(doctorId);
  }

  /// Normalises an appointment date string to a DateTime (date-only, no time).
  DateTime? _parseAppointmentDate(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    return DateTime.tryParse(raw.trim());
  }

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool _isAfterToday(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final apptDay = DateTime(d.year, d.month, d.day);
    return apptDay.isAfter(today);
  }

  // ---- Tab-specific filters ----

  List<AppointmentList> _todayList(List<AppointmentList> list) {
    return list.where((a) {
      final status = a.status?.toLowerCase().trim() ?? '';
      if (status != 'booked' && status != 'skipped' && status!='in_progress') return false;
      final d = _parseAppointmentDate(a.appointmentDate);
      if (!_isToday(d)) return false;
      return _matchesSearch(a);
    }).toList();
  }

  List<AppointmentList> _upcomingList(List<AppointmentList> list) {
    return list.where((a) {
      final status = a.status?.toLowerCase().trim() ?? '';
      if (status != 'booked') return false;
      final d = _parseAppointmentDate(a.appointmentDate);
      if (!_isAfterToday(d)) return false;
      return _matchesSearch(a);
    }).toList();
  }

  List<AppointmentList> _completedList(List<AppointmentList> list) {
    return list.where((a) {
      final status = a.status?.toLowerCase().trim() ?? '';
      if (status != 'completed' && status != 'done' && status != 'closed') {
        return false;
      }
      return _matchesSearch(a);
    }).toList();
  }

  bool _matchesSearch(AppointmentList a) {
    if (_searchQuery.isEmpty) return true;
    final name = a.patientName?.toLowerCase() ?? '';
    final status = a.status?.toLowerCase() ?? '';
    final queue = a.queueNumber?.toString() ?? '';
    return name.contains(_searchQuery) ||
        status.contains(_searchQuery) ||
        queue.contains(_searchQuery);
  }

  @override
  Widget build(BuildContext context) {
    final vmState = ref.watch(appointmentViewModelProvider);
    final appointmentsAsync = vmState.patientAppointmentsList;
    final queueState = vmState.queueState;
    final allAppointments = appointmentsAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <AppointmentList>[],
    );

    final todayAppointments = _todayList(allAppointments);
    final upcomingAppointments = _upcomingList(allAppointments);
    final completedAppointments = _completedList(allAppointments);

    return Scaffold(
      backgroundColor: surface,
      body: Column(children: [
        _buildHeader(
          totalCount: allAppointments.length,
          todayCount: todayAppointments.length,
          upcomingCount: upcomingAppointments.length,
          completedCount: completedAppointments.length,
        ),
        _buildSearchBar(),
        _buildTabBar(
          todayCount: todayAppointments.length,
          upcomingCount: upcomingAppointments.length,
          completedCount: completedAppointments.length,
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              // Today tab — View + Start Session
              _buildPatientListAsync(
                appointmentsAsync,
                tabType: _TabType.today,
                queueState: queueState,
              ),
              // Upcoming tab — View + Cancel
              _buildPatientListAsync(
                appointmentsAsync,
                tabType: _TabType.upcoming,
                queueState: queueState,
              ),
              // Completed tab — View + Prescription
              _buildPatientListAsync(
                appointmentsAsync,
                tabType: _TabType.completed,
                queueState: queueState,
              ),
            ],
          ),
        ),
      ]),
    );
  }

  // ------------------------- Header -------------------------

  Widget _buildHeader({
    required int totalCount,
    required int todayCount,
    required int upcomingCount,
    required int completedCount,
  }) {
    final now = DateTime.now();
    final dateLabel =
        '${_weekdayLabel(now.weekday)}, ${now.day.toString().padLeft(2, '0')} ${_monthLabel(now.month)} ${now.year}';
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [primary, primaryContainer],
        ),
      ),
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 16,
        left: 20,
        right: 20,
        bottom: 18,
      ),
      child: Stack(
        children: [
          Positioned(
            right: -40,
            top: -40,
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Text(
                      'Queue Management',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.search, color: Colors.white),
                        splashRadius: 20,
                      ),
                      IconButton(
                        onPressed: () {},
                        icon:
                            const Icon(Icons.notifications_none, color: Colors.white),
                        splashRadius: 20,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                dateLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.7),
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  _headerBadge('$todayCount Today'),
                  _headerBadge('$upcomingCount Upcoming'),
                  _headerBadge('$completedCount Completed'),
                  _headerBadge('$totalCount Total'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _headerBadge(String text) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 10,
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
      );

  // ------------------------- Search Bar -------------------------

  Widget _buildSearchBar() {
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceLowest,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 14,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          decoration: InputDecoration(
            hintText: 'Search by name, status, or queue...',
            hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
            prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
            suffixIcon: _searchQuery.isNotEmpty
                ? IconButton(
                    icon: const Icon(Icons.clear, size: 16),
                    onPressed: () => _searchController.clear(),
                  )
                : null,
            border: InputBorder.none,
            contentPadding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 4),
          ),
        ),
      ),
    );
  }

  // ------------------------- Tab Bar -------------------------

  Widget _buildTabBar({
    required int todayCount,
    required int upcomingCount,
    required int completedCount,
  }) {
    return Container(
      color: surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Container(
        decoration: BoxDecoration(
          color: surfaceLow,
          borderRadius: BorderRadius.circular(30),
        ),
        child: TabBar(
          controller: _tabController,
          labelColor: primary,
          unselectedLabelColor: onSurfaceVariant,
          indicator: BoxDecoration(
            color: secondaryContainer,
            borderRadius: BorderRadius.circular(24),
          ),
          indicatorPadding: const EdgeInsets.all(4),
          labelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
          unselectedLabelStyle:
              const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
          tabs: [
            Tab(text: 'Today ($todayCount)'),
            Tab(text: 'Upcoming ($upcomingCount)'),
            Tab(text: 'Completed ($completedCount)'),
          ],
        ),
      ),
    );
  }

  // ------------------------- Patient List -------------------------

  Widget _buildPatientListAsync(
    AsyncValue<List<AppointmentList>> appointmentsAsync, {
    required _TabType tabType,
    required QueueState queueState,
  }) {
    return appointmentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: primary),
      ),
      error: (e, _) => _ErrorState(
        onRetry: () => _refreshAppointments(force: true),
      ),
      data: (list) {
        final filtered = switch (tabType) {
          _TabType.today => _todayList(list),
          _TabType.upcoming => _upcomingList(list),
          _TabType.completed => _completedList(list),
        };
        return _buildPatientList(filtered, tabType: tabType, queueState: queueState);
      },
    );
  }

  Widget _buildPatientList(
    List<AppointmentList> patients, {
    required _TabType tabType,
    required QueueState queueState,
  }) {
    if (patients.isEmpty) {
      return Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_search, size: 48, color: Colors.grey.shade300),
              const SizedBox(height: 12),
              Text('No patients found',
                  style:
                      TextStyle(color: Colors.grey.shade400, fontSize: 14)),
            ]),
      );
    }

    // ── Today tab: accessibility logic ──────────────────────────────────────
    // If any patient is in_progress → they are the active session, all others wait.
    // If no in_progress → first booked patient (lowest queue_number) is accessible.
    // Skipped patients become accessible only when no active session exists.
    int? currentQueueNo;
    bool hasInProgress = false;
    if (tabType == _TabType.today) {
      hasInProgress = patients
          .any((p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
      if (!hasInProgress) {
        final bookedSorted = patients
            .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
            .toList()
          ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
        currentQueueNo = bookedSorted.isNotEmpty
            ? bookedSorted.first.queueNumber
            : null;
      }
    }

    final sectionTitle = switch (tabType) {
      _TabType.today => 'Waiting',
      _TabType.upcoming => 'Upcoming',
      _TabType.completed => 'Completed',
    };
    final badgeText = switch (tabType) {
      _TabType.today => '${patients.length} Left',
      _TabType.upcoming => '${patients.length} Scheduled',
      _TabType.completed => '${patients.length} Done',
    };

    return RefreshIndicator(
      color: primary,
      onRefresh: () async => _refreshAppointments(force: true),
      child: ListView.builder(
        padding: const EdgeInsets.only(bottom: 0),
        itemCount: patients.length + (tabType == _TabType.today ? 2 : 1),
        itemBuilder: (context, index) {
          final hasLiveQueue = tabType == _TabType.today;
          final headerCount = hasLiveQueue ? 2 : 1;
          if (index == 0) {
            return hasLiveQueue
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: _buildLiveQueueCard(
                      patients: patients,
                      queueState: queueState,
                      onStart: _onStartSession,
                      onSkip: _onSkipPatient,
                    ),
                  )
                : _sectionHeader(sectionTitle, badgeText);
          }
          if (hasLiveQueue && index == 1) {
            return _sectionHeader(sectionTitle, badgeText);
          }

          final patientIndex = index - headerCount;
          final p = patients[patientIndex];

          bool isAccessible = true;
          if (tabType == _TabType.today) {
            final status = p.status?.toLowerCase() ?? '';
            final queueActive = queueState == QueueState.running ||
                queueState == QueueState.paused;
            if (status == 'in_progress') {
              // in_progress patient is always accessible — their session is running
              isAccessible = true;
            } else if (!queueActive) {
              isAccessible = false;
            } else if (status == 'booked') {
              // Locked if someone else is already in_progress, or not the first in queue
              isAccessible = !hasInProgress && p.queueNumber == currentQueueNo;
            } else if (status == 'skipped') {
              // Skipped patients locked while someone is in_progress
              isAccessible = !hasInProgress;
            }
          }

          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: PatientCard(
              patient: p,
              tabType: tabType,
              isAccessible: isAccessible,
              onStart: () => _onStartSession(p),
              onSkip: isAccessible &&
                      tabType == _TabType.today &&
                      (p.status?.toLowerCase() ?? '') == 'booked'
                  ? () => _onSkipPatient(p)
                  : null,
              onView: () => _onViewPatient(p),
              onPrescription: () => _onPrescription(p),
              onCancel: () => _onCancelAppointment(p),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionHeader(String title, String badgeText) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: secondaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              badgeText,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF334D37),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLiveQueueCard({
    required List<AppointmentList> patients,
    required QueueState queueState,
    required void Function(AppointmentList) onStart,
    required void Function(AppointmentList) onSkip,
  }) {
    AppointmentList? inProgress;
    for (final p in patients) {
      if ((p.status?.toLowerCase() ?? '') == 'in_progress') {
        inProgress = p;
        break;
      }
    }

    final bookedSorted = patients
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

    final current = inProgress ?? (bookedSorted.isNotEmpty ? bookedSorted.first : null);
    AppointmentList? next;
    if (inProgress != null) {
      next = bookedSorted.isNotEmpty ? bookedSorted.first : null;
    } else if (bookedSorted.length > 1) {
      next = bookedSorted[1];
    }

    final currentToken = current?.queueNumber?.toString() ?? '-';
    final nextToken = next?.queueNumber?.toString() ?? '-';
    final totalCount = patients.length.toString();

    final isRunning = queueState == QueueState.running;
    final statusLabel = current == null
        ? 'NO ACTIVE'
        : (current.status ?? '').toUpperCase().replaceAll('_', ' ');
    final statusBg = current == null
        ? surfaceHigh
        : (current.status?.toLowerCase() ?? '') == 'in_progress'
            ? const Color(0xFFE8F5E9)
            : secondaryContainer;
    final statusText = current == null
        ? onSurfaceVariant
        : (current.status?.toLowerCase() ?? '') == 'in_progress'
            ? const Color(0xFF2E7D32)
            : const Color(0xFF334D37);

    return Container(
      decoration: BoxDecoration(
        color: surfaceLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: secondaryContainer.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: secondaryContainer.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'LIVE QUEUE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                      color: primary,
                    ),
                  ),
                ),
                const Spacer(),
                _queueIconButton(
                  icon: Icons.play_arrow_rounded,
                  enabled: !isRunning,
                ),
                _queueIconButton(
                  icon: Icons.pause_rounded,
                  enabled: isRunning,
                ),
                _queueIconButton(
                  icon: Icons.close_rounded,
                  enabled: true,
                  color: error,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _tokenTile('CURRENT', currentToken),
                const SizedBox(width: 10),
                _tokenTile('NEXT', nextToken),
                const SizedBox(width: 10),
                _tokenTile('TOTAL', totalCount),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: outlineVariant.withOpacity(0.4)),
              ),
              child: current == null
                  ? Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: surfaceHigh,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_outline,
                              color: onSurfaceVariant),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'No active patient right now',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: secondaryContainer,
                          child: Text(
                            _initials(current.patientName),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                current.patientName ?? 'Patient',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                  color: onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _ageGenderFor(current),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: statusBg,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  statusLabel.isEmpty ? 'STATUS' : statusLabel,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w700,
                                    color: statusText,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: (current != null &&
                            (current.status?.toLowerCase() ?? '') == 'booked')
                        ? () => onSkip(current)
                        : null,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: error,
                      side: BorderSide(
                        color: error.withOpacity(0.4),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Skip',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: current != null ? () => onStart(current) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      (current?.status?.toLowerCase() ?? '') == 'in_progress'
                          ? 'Continue'
                          : 'Start Session',
                      style: const TextStyle(fontWeight: FontWeight.w700),
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

  Widget _tokenTile(String label, String value) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: surfaceLow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value == '-' ? '-' : '#$value',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: primary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _queueIconButton({
    required IconData icon,
    required bool enabled,
    Color color = primary,
  }) {
    return IconButton(
      onPressed: enabled ? () {} : null,
      icon: Icon(icon, size: 20, color: enabled ? color : color.withOpacity(0.3)),
      splashRadius: 18,
    );
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _ageGenderFor(AppointmentList patient) {
    final gender = patient.gender ?? '-';
    final age = _ageString(patient.dob);
    if (age == null || age.isEmpty) return gender;
    return '$age - $gender';
  }

  // ------------------------- Actions -------------------------

  Future<void> _onStartSession(AppointmentList p) async {
    final patientId = p.patientId ?? 0;
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (patientId == 0 || doctorId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient or doctor info missing')),
      );
      return;
    }

    // Call START_SESSION API before navigating
    try {
      await ref.read(appointmentViewModelProvider.notifier).startSession(
        AppointmentRequestModel(
          doctorId: doctorId,
          patientId: patientId,
          appointmentId: p.appointmentId ?? 0,
        ),
      );
    } catch (_) {
      // Non-blocking — navigate even if API fails
    }

    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PrescriptionScreen(
          patientId: patientId,
          doctorId: doctorId,
          userTypeId: p.userType ?? 1,
          appointmentId: p.appointmentId ?? 0,
          patientName: p.patientName ?? 'Patient',
          patientAge: _ageString(p.dob),
          patientGender: p.gender,
          queueNumber: p.queueNumber,
          patientStatus: 'booked', // START_SESSION already called; patient is in_progress → use NEXT_SESSION flow
        ),
      ),
    );
    if (!mounted) return;
    _hasFetched = false;
    _refreshAppointments(force: true);
  }

  void _onViewPatient(AppointmentList p) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => PatientDetailSheet(patient: p),
    );
  }

  void _onPrescription(AppointmentList p) {
    final patientId = p.patientId ?? 0;
    if (patientId == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient info missing')),
      );
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorPrescriptionDetailScreen(
          appointmentId: p.appointmentId ?? 0,
          patientId: patientId,
          patientName: p.patientName ?? 'Patient',
          patientAge: _ageString(p.dob),
          patientGender: p.gender,
          queueNumber: p.queueNumber,
        ),
      ),
    );
  }

  Future<void> _onSkipPatient(AppointmentList p) async {
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (doctorId == 0) return;
    try {
      final result = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueSkip(AppointmentRequestModel(
            doctorId: doctorId,
            appointmentId: p.appointmentId ?? 0,
            patientId: p.patientId ?? 0,
          ));
      if (!mounted) return;
      _hasFetched = false;
      _refreshAppointments(force: true);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.message ?? 'Patient skipped'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Failed to skip: $e'),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  void _onCancelAppointment(AppointmentList p) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Cancel Appointment',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(
            'Are you sure you want to cancel the appointment for ${p.patientName ?? 'this patient'}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              // TODO: wire up your cancel API call here
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Appointment for ${p.patientName ?? 'patient'} cancelled')),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }

  String? _ageString(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return null;
    final now = DateTime.now();
    var years = now.year - parsed.year;
    final hadBirthday = (now.month > parsed.month) ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : '$years yrs';
  }

  String _monthLabel(int month) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    if (month < 1 || month > 12) return '';
    return months[month - 1];
  }

  String _weekdayLabel(int weekday) {
    const weekdays = [
      'Monday', 'Tuesday', 'Wednesday',
      'Thursday', 'Friday', 'Saturday', 'Sunday',
    ];
    if (weekday < 1 || weekday > 7) return '';
    return weekdays[weekday - 1];
  }
}

// ------------------------- Tab Type Enum -------------------------

enum _TabType { today, upcoming, completed }

// ------------------------- Patient Card Widget -------------------------

class PatientCard extends StatelessWidget {
  final AppointmentList patient;
  final _TabType tabType;
  final bool isAccessible;
  final VoidCallback onStart;
  final VoidCallback onView;
  final VoidCallback onPrescription;
  final VoidCallback onCancel;
  final VoidCallback? onSkip;

  const PatientCard({
    super.key,
    required this.patient,
    required this.tabType,
    this.isAccessible = true,
    required this.onStart,
    required this.onView,
    required this.onPrescription,
    required this.onCancel,
    this.onSkip,
  });

  static const Color primary = Color(0xFF00450D);
  static const Color secondaryContainer = Color(0xFFC9E7CA);
  static const Color surfaceLow = Color(0xFFF3F3F3);
  static const Color outlineVariant = Color(0xFFC0C9BB);
  static const Color onSurface = Color(0xFF1A1C1C);
  static const Color onSurfaceVariant = Color(0xFF41493E);
  static const Color error = Color(0xFFBA1A1A);

  Color get avatarBg {
    const colors = [
      Color(0xFFDDEEFF), Color(0xFFD4F4EC), Color(0xFFFAEEDA),
      Color(0xFFFBEAF0), Color(0xFFEEEDFE), Color(0xFFEAF3DE),
    ];
    return colors[(patient.appointmentId ?? 0) % colors.length];
  }

  Color get avatarText {
    const colors = [
      Color(0xFF1A56A0), Color(0xFF0F6E56), Color(0xFF854F0B),
      Color(0xFF993556), Color(0xFF534AB7), Color(0xFF3B6D11),
    ];
    return colors[(patient.appointmentId ?? 0) % colors.length];
  }

  ({Color bg, Color text}) get statusStyle {
    switch ((patient.status ?? '').toLowerCase().trim()) {
      case 'booked':
        return (bg: const Color(0xFFE6F4E7), text: const Color(0xFF334D37));
      case 'confirmed':
        return (bg: const Color(0xFFD4F4EC), text: const Color(0xFF0F6E56));
      case 'pending':
        return (bg: const Color(0xFFFAEEDA), text: const Color(0xFF854F0B));
      case 'in_progress':
        return (bg: const Color(0xFFE8F5E9), text: const Color(0xFF2E7D32));
      case 'completed':
      case 'done':
      case 'closed':
        return (bg: surfaceLow, text: onSurfaceVariant);
      default:
        return (bg: surfaceLow, text: onSurfaceVariant);
    }
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _ageGender() {
    final gender = patient.gender ?? '-';
    final age = _ageFromDob(patient.dob);
    if (age == null) return gender;
    return '$age yrs - $gender';
  }

  int? _ageFromDob(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return null;
    final now = DateTime.now();
    var years = now.year - parsed.year;
    final hadBirthday = (now.month > parsed.month) ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : years;
  }

  ({IconData icon, String label}) _bookingInfo() {
    final type = patient.bookingType ?? 1;
    if (type == 1) {
      return (
        icon: Icons.confirmation_number_outlined,
        label: 'Queue ${patient.queueNumber ?? '-'}',
      );
    }
    final range = _timeRange();
    return (
      icon: Icons.schedule,
      label: range == null ? 'Slot -' : 'Slot $range',
    );
  }

  String? _timeRange() {
    final start = _fmtTime24(patient.startTime);
    final end = _fmtTime24(patient.endTime);
    if (start == null && end == null) return null;
    if (start == null) return end;
    if (end == null) return start;
    return '$start - $end';
  }

  String? _fmtTime24(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final ss = statusStyle;
    final name = patient.patientName ?? 'Patient';
    final status = patient.status ?? 'Unknown';
    final bookingInfo = _bookingInfo();
    final tokenLabel = patient.queueNumber?.toString() ?? '-';

    return InkWell(
      onTap: onView,
      borderRadius: BorderRadius.circular(18),
      child: Card(
        elevation: 0,
        shadowColor: Colors.black.withOpacity(0.05),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: outlineVariant.withOpacity(0.4), width: 1),
        ),
        color: Colors.white,
        child: Padding(
        padding: const EdgeInsets.all(14),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Top Row
          Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: avatarBg,
              child: Text(
                _initials(name),
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: avatarText),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w600)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: ss.bg,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(status,
                              style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: ss.text)),
                        ),
                      ]),
                  const SizedBox(height: 5),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    _infoChip(Icons.person_outline, _ageGender()),
                    _infoChip(Icons.calendar_today, formatDate(patient.appointmentDate)),
                    _infoChip(bookingInfo.icon, bookingInfo.label),
                  ]),
                ])),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text(
                  'TOKEN',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: onSurfaceVariant,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  tokenLabel == '-' ? '-' : '#$tokenLabel',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: primary,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: outlineVariant),
          ]),

          const SizedBox(height: 10),

          // // Appointment ID Box
          // Container(
          //   width: double.infinity,
          //   padding:
          //       const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          //   decoration: BoxDecoration(
          //     color: const Color(0xFFF4F6FA),
          //     borderRadius: BorderRadius.circular(8),
          //   ),
          //   child: Row(children: [
          //     const Icon(Icons.info_outline, size: 13, color: primary),
          //     const SizedBox(width: 6),
          //     Text('Appointment ID: ',
          //         style:
          //             TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          //     Expanded(
          //       child: Text('${formatDate(patient.appointmentDate)}',
          //           style: const TextStyle(
          //               fontSize: 11, fontWeight: FontWeight.w600),
          //           overflow: TextOverflow.ellipsis),
          //     ),
          //   ]),
          // ),

          // const Padding(
          //   padding: EdgeInsets.symmetric(vertical: 10),
          //   child: Divider(height: 1, thickness: 0.5),
          // ),

          // Action Buttons — differ per tab
          Row(children: [
            // _outlineBtn('View', Icons.visibility_outlined, onView),
            if (tabType == _TabType.today) ...[
              // Show Skip only for the current accessible booked patient
              if (isAccessible &&
                  (patient.status?.toLowerCase() ?? '') == 'booked' &&
                  onSkip != null) ...[
                Expanded(child: _skipBtn()),
                const SizedBox(width: 8),
              ],
              Expanded(flex: 2, child: _startBtn()),
            ] else if (tabType == _TabType.upcoming) ...[
              Expanded(flex: 2, child: _cancelBtn()),
            ] else ...[
              // completed
              _outlineBtn(
                  'Prescription', Icons.receipt_outlined, onPrescription),
              const SizedBox(width: 8),
              Expanded(flex: 2, child: _completedBtn()),
            ],
          ]),
        ]),
      ),),
    );
  }

  Widget _infoChip(IconData icon, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: onSurfaceVariant),
          const SizedBox(width: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: onSurfaceVariant,
            ),
          ),
        ],
      );

  Widget _outlineBtn(String label, IconData icon, VoidCallback onTap) =>
      Expanded(
        child: OutlinedButton.icon(
          onPressed: onTap,
          icon: Icon(icon, size: 12),
          label: Text(label),
          style: OutlinedButton.styleFrom(
            foregroundColor: primary,
            padding: const EdgeInsets.symmetric(vertical: 8),
            textStyle: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500),
            side: const BorderSide(color: outlineVariant, width: 1),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(9)),
          ),
        ),
      );

  Widget _skipBtn() => OutlinedButton.icon(
        onPressed: onSkip,
        icon: const Icon(Icons.skip_next_rounded, size: 14, color: error),
        label: const Text('Skip',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: error)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 9),
          side: BorderSide(color: error.withOpacity(0.4), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        ),
      );

  Widget _startBtn() {
    final status = patient.status?.toLowerCase() ?? '';
    final isInProgress = status == 'in_progress';

    if (isInProgress) {
      return ElevatedButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.play_arrow_rounded, size: 15, color: Colors.white),
        label: const Text(
          'Start Session',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF2E7D32),
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
        ),
      );
    }

    return ElevatedButton.icon(
      onPressed: isAccessible ? onStart : null,
      icon: Icon(
        isAccessible ? Icons.play_arrow_rounded : Icons.lock_outline,
        size: 15,
        color: Colors.white,
      ),
      label: Text(
        isAccessible ? 'Start Session' : 'Waiting',
        style: const TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: isAccessible ? primary : surfaceLow,
        disabledBackgroundColor: surfaceLow,
        disabledForegroundColor: onSurfaceVariant,
        padding: const EdgeInsets.symmetric(vertical: 9),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
        elevation: 0,
      ),
    );
  }

  Widget _cancelBtn() => ElevatedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.cancel_outlined, size: 14, color: Colors.white),
        label: const Text('Cancel',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: error,
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
        ),
      );

  Widget _completedBtn() => ElevatedButton.icon(
        onPressed: null,
        icon: const Icon(Icons.check_circle_outline, size: 14),
        label: const Text('Completed',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: surfaceLow,
          disabledBackgroundColor: surfaceLow,
          disabledForegroundColor: onSurfaceVariant,
          padding: const EdgeInsets.symmetric(vertical: 9),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
          elevation: 0,
        ),
      );
}

// ------------------------- Patient Detail Bottom Sheet -------------------------

class PatientDetailSheet extends StatelessWidget {
  final AppointmentList patient;
  const PatientDetailSheet({super.key, required this.patient});

  static const Color primary = Color(0xFF00450D);

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String _ageGender() {
    final gender = patient.gender ?? '-';
    final age = _ageFromDob(patient.dob);
    if (age == null) return gender;
    return '$age yrs - $gender';
  }

  int? _ageFromDob(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    final parsed = DateTime.tryParse(dob);
    if (parsed == null) return null;
    final now = DateTime.now();
    var years = now.year - parsed.year;
    final hadBirthday = (now.month > parsed.month) ||
        (now.month == parsed.month && now.day >= parsed.day);
    if (!hadBirthday) years -= 1;
    return years < 0 ? null : years;
  }

  String _bookingInfoLabel() {
    final type = patient.bookingType ?? 1;
    return type == 1 ? 'Queue Number' : 'Slot Time';
  }

  String _bookingInfoValue() {
    final type = patient.bookingType ?? 1;
    if (type == 1) return '${patient.queueNumber ?? '-'}';
    final range = _timeRange();
    return range ?? '-';
  }

  String? _timeRange() {
    final start = _fmtTime24(patient.startTime);
    final end = _fmtTime24(patient.endTime);
    if (start == null && end == null) return null;
    if (start == null) return end;
    if (end == null) return start;
    return '$start - $end';
  }

  String? _fmtTime24(String? iso) {
    if (iso == null || iso.trim().isEmpty) return null;
    final dt = DateTime.tryParse(iso);
    if (dt == null) return null;
    return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final name = patient.patientName ?? 'Patient';
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (_, controller) => Column(children: [
        Container(
          margin: const EdgeInsets.symmetric(vertical: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.grey.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: const Color(0xFFDDEEFF),
                      child: Text(
                        _initials(name),
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                            color: primary),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Center(
                    child: Text(name,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w600)),
                  ),
                  Center(
                    child: Text(patient.status ?? 'Unknown',
                        style: TextStyle(
                            fontSize: 13, color: Colors.grey.shade500)),
                  ),
                  const SizedBox(height: 20),
                  _detailTile(
                      Icons.person_outline, 'Age & Gender', _ageGender()),
                  _detailTile(Icons.calendar_today, 'Appointment Date',
                      patient.appointmentDate ?? '-'),
                  _detailTile(Icons.confirmation_number_outlined,
                      _bookingInfoLabel(), _bookingInfoValue()),
                  _detailTile(Icons.info_outline, 'Appointment ID',
                      '${patient.appointmentId ?? '-'}'),
                  _detailTile(Icons.fiber_manual_record, 'Status',
                      patient.status ?? 'Unknown'),
                ]),
          ),
        ),
      ]),
    );
  }

String formatDate(String? rawDate) {
  if (rawDate == null || rawDate.isEmpty) return '-';

  final date = DateTime.tryParse(rawDate);
  if (date == null) return rawDate;

  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  return '${date.day} ${months[date.month - 1]} ${date.year}';
}
  Widget _detailTile(IconData icon, String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFE6F4E7),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: primary),
          ),
          const SizedBox(width: 12),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style:
                    TextStyle(fontSize: 11, color: Colors.grey.shade500)),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ]),
        ]),
      );
}

// ------------------------- Error State -------------------------

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              color: Colors.red,
              size: 32,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load appointments',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Color(0xFF1F2937),
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(fontSize: 13.5, color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text(
              'Retry',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00450D),
              foregroundColor: Colors.white,
              elevation: 0,
              padding:
                  const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
