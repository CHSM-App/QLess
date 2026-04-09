import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/review_viewmodel.dart';

// ── THEME ──
const kPrimary = Color(0xFF0D9488);
const kPrimaryLight = Color(0xFFCCFBF1);
const kPrimaryDark = Color(0xFF115E59);
const kBg = Color(0xFFF8FAFB);
const kCardBg = Colors.white;
const kTextDark = Color(0xFF111827);
const kTextMid = Color(0xFF6B7280);
const kTextLight = Color(0xFF9CA3AF);
const kRed = Color(0xFFEF4444);
const kRedLight = Color(0xFFFEE2E2);
const kGreen = Color(0xFF22C55E);
const kGreenLight = Color(0xFFDCFCE7);
const kBlue = Color(0xFF3B82F6);
const kBlueLight = Color(0xFFDBEAFE);
const kAmber = Color(0xFFF59E0B);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple = Color(0xFF8B5CF6);
const kPurpleLight = Color(0xFFEDE9FE);
const kDivider = Color(0xFFE5E7EB);

// ── FILTER TABS ──
const _filters = [
  _FilterTab("all",       "All",       Icons.list_rounded,            kPrimary, kPrimaryLight),
  _FilterTab("today",     "Today",     Icons.today_rounded,            kPrimary,   kBlueLight),
  _FilterTab("upcoming",  "Upcoming",  Icons.schedule_rounded,         kPrimary, kPurpleLight),
  _FilterTab("completed", "Completed", Icons.check_circle_rounded,     kPrimary,  kGreenLight),
  _FilterTab("cancelled", "Cancelled", Icons.cancel_rounded,           kPrimary,    kRedLight),
];

class _FilterTab {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _FilterTab(this.key, this.label, this.icon, this.color, this.bg);
}

// ── HELPERS ──

Color statusColor(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return kBlue;
    case "completed":
      return kGreen;
    case "cancelled":
      return kRed;
    default:
      return kAmber;
  }
}

Color statusBgColor(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return kBlueLight;
    case "completed":
      return kGreenLight;
    case "cancelled":
      return kRedLight;
    default:
      return kAmberLight;
  }
}

IconData statusIcon(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return Icons.schedule_rounded;
    case "completed":
      return Icons.check_circle_rounded;
    case "cancelled":
      return Icons.cancel_rounded;
    default:
      return Icons.info_rounded;
  }
}

String formatDate(String? d) {
  if (d == null) return "—";
  final p = DateTime.tryParse(d);
  if (p == null) return d;
  return DateFormat('dd MMM yyyy').format(p);
}

String formatDateRelative(String? d) {
  if (d == null) return "—";
  final p = DateTime.tryParse(d);
  if (p == null) return d;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final date = DateTime(p.year, p.month, p.day);
  final diff = date.difference(today).inDays;
  if (diff == 0) return "Today";
  if (diff == 1) return "Tomorrow";
  if (diff == -1) return "Yesterday";
  if (diff > 0 && diff <= 7) return "In $diff days";
  return DateFormat('dd MMM yyyy').format(p);
}

String formatTime(String? t) {
  if (t == null) return "—";
  final p = DateTime.tryParse(t);
  if (p == null) return t;
  return DateFormat('hh:mm a').format(p);
}

String capitalise(String? s) {
  if (s == null || s.isEmpty) return "—";
  return s[0].toUpperCase() + s.substring(1);
}

Future<void> openMap(double lat, double lng, String? label) async {
  final encoded = Uri.encodeComponent(label ?? "Clinic");
  final uri = Uri.parse(
      "https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encoded");
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// ── FILTER LOGIC ──

bool _isToday(AppointmentList a) {
  if (a.appointmentDate == null) return false;
  final p = DateTime.tryParse(a.appointmentDate!);
  if (p == null) return false;
  final now = DateTime.now();
  return p.year == now.year && p.month == now.month && p.day == now.day;
}

bool _isUpcoming(AppointmentList a) {
  if (a.appointmentDate == null) return false;
  final p = DateTime.tryParse(a.appointmentDate!);
  if (p == null) return false;
  final now = DateTime.now();
  final apptDay = DateTime(p.year, p.month, p.day);
  final todayDay = DateTime(now.year, now.month, now.day);
  return apptDay.isAfter(todayDay);
}

bool _isCompleted(AppointmentList a) =>
    a.status?.toLowerCase() == "completed";

bool _isCancelled(AppointmentList a) =>
    a.status?.toLowerCase() == "cancelled";

List<AppointmentList> applyFilter(
    List<AppointmentList> list, String filter, String search) {
  return list.where((a) {
    // search
    final matchSearch = search.isEmpty ||
        (a.patientName?.toLowerCase().contains(search.toLowerCase()) ?? false);

    // tab filter
    final bool matchFilter;
    switch (filter) {
      case "today":
        matchFilter = _isToday(a);
        break;
      case "upcoming":
        matchFilter = _isUpcoming(a);
        break;
      case "completed":
        matchFilter = _isCompleted(a);
        break;
      case "cancelled":
        matchFilter = _isCancelled(a);
        break;
      default: // "all"
        matchFilter = true;
    }

    return matchSearch && matchFilter;
  }).toList();
}

// ════════════════════════════════════════════════════════
//  SCREEN
// ════════════════════════════════════════════════════════

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key});

  @override
  ConsumerState<AppointmentScreen> createState() => AppointmentScreenState();
}

class AppointmentScreenState extends ConsumerState<AppointmentScreen>
    with SingleTickerProviderStateMixin {
  String searchQuery = "";
  String filterStatus = "all";
  bool _didFetch = false;
  bool _isFetching = false;
  bool _isWaitingForId = false;
  bool _idMissing = false;
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _filters.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() => filterStatus = _filters[_tabController.index].key);
      }
    });
    Future.microtask(_ensurePatientIdAndFetch);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> refreshOnVisible() async {
    _didFetch = false;
    await _ensurePatientIdAndFetch(force: true);
  }

  Future<void> _ensurePatientIdAndFetch({bool force = false}) async {
    if (_isFetching) return;
    if (_didFetch && !force) return;
    _isFetching = true;
    try {
      final loginNotifier = ref.read(patientLoginViewModelProvider.notifier);
      var patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;

      if (patientId == 0) {
        if (!_isWaitingForId) {
          setState(() {
            _isWaitingForId = true;
            _idMissing = false;
          });
        }
        await loginNotifier.loadFromStoragePatient();
        patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
        if (mounted) setState(() => _isWaitingForId = false);
        if (patientId == 0) {
          if (mounted) setState(() => _idMissing = true);
          return;
        }
      }

      _didFetch = true;
      await ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(patientId);
    } finally {
      _isFetching = false;
    }
  }

  void _openDetail(AppointmentList a) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AppointmentDetailSheet(appointment: a),
    );
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      final prevId = prev?.patientId ?? 0;
      final nextId = next.patientId ?? 0;
      if (nextId != 0 && prevId != nextId) {
        _didFetch = false;
        _ensurePatientIdAndFetch();
      }
      if (_idMissing && nextId != 0) {
        setState(() => _idMissing = false);
      }
    });

    ref.listen<ReviewState>(reviewViewModelProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: kRed),
        );
      }
      if (next.isSuccess && next.isSuccess != prev?.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your review!'),
            backgroundColor: kGreen,
          ),
        );
      }
    });

    final vmState = ref.watch(appointmentViewModelProvider);
    final asyncAppointments = vmState.patientAppointmentsList;
    final loginState = ref.watch(patientLoginViewModelProvider);

    return Scaffold(
      backgroundColor: kBg,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        elevation: 4,
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => PatientBottomNav(
              onToggleTheme: () {},
              themeMode: ThemeMode.system,
            ),
          ),
        ),
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text("Book",
            style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5)),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _isWaitingForId
                  ? _buildLoading("Loading your account...")
                  : _idMissing && (loginState.patientId ?? 0) == 0
                      ? _buildMissingLogin()
                      : asyncAppointments == null
                          ? _buildLoading("Fetching appointments...")
                          : asyncAppointments.when(
                              loading: () =>
                                  _buildLoading("Fetching appointments..."),
                              error: (_, __) => _buildError(),
                              data: _buildTabContent,
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER ──

  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          // Title row
          Padding(
            padding: EdgeInsets.fromLTRB(
                20, MediaQuery.of(context).padding.top + 16, 20, 0),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(12)),
                  child: const Icon(Icons.calendar_month_rounded,
                      color: kPrimary, size: 24),
                ),
                const SizedBox(width: 14),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Appointments",
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                              letterSpacing: -0.5)),
                      SizedBox(height: 2),
                      Text("Manage your schedule",
                          style: TextStyle(fontSize: 13, color: kTextMid)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: kDivider)),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                style: const TextStyle(fontSize: 14, color: kTextDark),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: kTextLight, size: 20),
                  hintText: "Search by patient name...",
                  hintStyle:
                      const TextStyle(color: kTextLight, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  suffixIcon: searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => searchQuery = ""),
                          child: const Icon(Icons.close_rounded,
                              color: kTextLight, size: 18))
                      : null,
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Tab bar
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            indicatorPadding: EdgeInsets.zero,
            indicator: BoxDecoration(
              color: _filters[_tabController.index].color,
              borderRadius: BorderRadius.circular(10),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            labelPadding:
                const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            tabs: _filters.map((f) {
              final isSelected =
                  _filters[_tabController.index].key == f.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? f.color : kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: isSelected ? f.color : kDivider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(f.icon,
                        size: 13,
                        color: isSelected ? Colors.white : f.color),
                    const SizedBox(width: 6),
                    Text(f.label,
                        style: TextStyle(
                            color:
                                isSelected ? Colors.white : kTextMid,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500)),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── TAB CONTENT ──

  Widget _buildTabContent(List<AppointmentList> appointments) {
    return TabBarView(
      controller: _tabController,
      children: _filters.map((f) {
        final filtered = applyFilter(appointments, f.key, searchQuery);
        return _buildList(filtered, f);
      }).toList(),
    );
  }

  Widget _buildList(List<AppointmentList> filtered, _FilterTab tab) {
    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: tab.bg, shape: BoxShape.circle),
              child: Icon(tab.icon, size: 36, color: tab.color),
            ),
            const SizedBox(height: 16),
            Text(
              "No ${tab.label.toLowerCase()} appointments",
              style: const TextStyle(
                  color: kTextDark,
                  fontSize: 16,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              tab.key == "all"
                  ? "Try adjusting your search"
                  : "Nothing to show here yet",
              style: const TextStyle(color: kTextMid, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: () async {
        final id = ref.read(patientLoginViewModelProvider).patientId;
        if (id != null && id != 0) {
          await ref
              .read(appointmentViewModelProvider.notifier)
              .getPatientAppointments(id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final a = filtered[index];
          return _AppointmentCard(
            appointment: a,
            statusColor: getStatusColor(a.status),
            statusBgColor: getStatusBgColor(a.status),
            statusIcon: getStatusIcon(a.status),
            formattedDate: a.appointmentDate != null
                ? _formatDate(a.appointmentDate!)
                : null,
            relativeDate: a.appointmentDate != null
                ? _formatDateRelative(a.appointmentDate!)
                : null,
            formattedDob:
                a.dob != null ? _formatDate(a.dob!) : null,
            onReview: _canReview(a)
                ? () => _handleReview(context, a)
                : null,
          );
        },
      ),
    );
  }

  bool _canReview(AppointmentList a) {
    return a.status?.toLowerCase() == 'completed' &&
        a.appointmentId != null &&
        a.doctorId != null &&
        a.patientId != null;
  }

  Future<void> _handleReview(BuildContext context, AppointmentList a) async {
    final input = await showAppointmentReviewDialog(
      context,
      doctorName: a.doctorName ?? 'Doctor',
    );
    if (input == null) return;
    await ref.read(reviewViewModelProvider.notifier).submitReview(
      ReviewRequestModel(
        appointmentId: a.appointmentId!,
        doctorId: a.doctorId!,
        patientId: a.patientId!,
        rating: input.rating,
        comment: input.comment,
      )
    );
  }

  // ── STATES ──

  Widget _buildLoading(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                  color: kPrimary,
                  strokeWidth: 3,
                  strokeCap: StrokeCap.round),
            ),
            const SizedBox(height: 16),
            Text(msg,
                style: const TextStyle(color: kTextMid, fontSize: 14)),
          ],
        ),
      );

  Widget _buildError() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: kRedLight, shape: BoxShape.circle),
                child: const Icon(Icons.wifi_off_rounded,
                    size: 32, color: kRed),
              ),
              const SizedBox(height: 16),
              const Text("Something went wrong",
                  style: TextStyle(
                      color: kTextDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                  "Couldn't load your appointments.\nPlease try again.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: kTextMid, fontSize: 13, height: 1.5)),
              const SizedBox(height: 20),
              SizedBox(
                width: 140,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kPrimary,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    final id =
                        ref.read(patientLoginViewModelProvider).patientId;
                    if (id != null && id != 0) {
                      ref
                          .read(appointmentViewModelProvider.notifier)
                          .getPatientAppointments(id);
                    }
                  },
                  child: const Text("Retry",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      );

  Widget _buildMissingLogin() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                    color: kAmberLight, shape: BoxShape.circle),
                child: const Icon(Icons.lock_outline_rounded,
                    size: 32, color: kAmber),
              ),
              const SizedBox(height: 16),
              const Text("Session Expired",
                  style: TextStyle(
                      color: kTextDark,
                      fontSize: 16,
                      fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              const Text(
                  "Please login again to\nview your appointments.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: kTextMid, fontSize: 13, height: 1.5)),
            ],
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════
//  COMPACT CARD  — 3 rows
// ════════════════════════════════════════════════════════

class _AppointmentCard extends StatelessWidget {
  final AppointmentList appointment;
  final VoidCallback onViewDetails;
  final VoidCallback? onReview;

  const _AppointmentCard({
    required this.appointment,
    required this.statusColor,
    required this.statusBgColor,
    required this.statusIcon,
    this.formattedDate,
    this.relativeDate,
    this.formattedDob,
    this.onReview,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final sColor = statusColor(a.status);
    final sBg = statusBgColor(a.status);
    final sIcon = statusIcon(a.status);
    final hasMap = a.latitude != null && a.longitude != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onViewDetails,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              children: [
                // ── ROW 1: Avatar | Name + Doctor | Status ──
                Row(
                  children: [
                    Container(
                      width: 46,
                      height: 46,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kPrimary.withValues(alpha: 0.18),
                            kPrimary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Center(
                        child: Text(
                          (appointment.patientName ?? "?")[0].toUpperCase(),
                          style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w700,
                              color: kPrimary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            appointment.patientName ?? "Unknown",
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: kTextDark,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              const Icon(Icons.person_rounded,
                                  size: 11, color: kTextLight),
                              const SizedBox(width: 3),
                              Expanded(
                                child: Text(
                                  a.doctorName ?? "—",
                                  style: const TextStyle(
                                      color: kTextMid, fontSize: 11),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: sBg,
                          borderRadius: BorderRadius.circular(8)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(sIcon, size: 11, color: sColor),
                          const SizedBox(width: 4),
                          Text(capitalise(a.status),
                              style: TextStyle(
                                  color: sColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),

                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 10),
                  child: Divider(height: 1, color: kDivider),
                ),

                // ── ROW 2: Date | Time ──
                Row(
                  children: [
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.calendar_today_rounded,
                        iconBg: kBlueLight,
                        iconColor: kBlue,
                        top: formatDateRelative(a.appointmentDate),
                        bottom: formatDate(a.appointmentDate),
                      ),
                    ),
                    Expanded(
                      child: _miniInfo(
                        icon: Icons.access_time_rounded,
                        iconBg: kGreenLight,
                        iconColor: kGreen,
                        top: formatTime(a.startTime),
                        bottom: a.endTime != null
                            ? "– ${formatTime(a.endTime)}"
                            : "",
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 10),

                // ── ROW 3: View Details | Map | Call ──
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 38,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          onPressed: onViewDetails,
                          child: const Text("View Details",
                              style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (hasMap) ...[
                      _iconBtn(
                        icon: Icons.map_rounded,
                        bg: kBlueLight,
                        iconColor: kBlue,
                        onTap: () => openMap(
                            a.latitude!, a.longitude!, a.clinicName),
                      ),
                      const SizedBox(width: 8),
                    ],
                    _iconBtn(
                      icon: Icons.call_rounded,
                      bg: kPrimaryLight,
                      iconColor: kPrimary,
                      onTap: () {
                        // call action
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _miniInfo({
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String top,
    required String bottom,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
              color: iconBg, borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 7),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(top,
                style: const TextStyle(
                    color: kTextDark,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            if (bottom.isNotEmpty)
              Text(bottom,
                  style: const TextStyle(color: kTextMid, fontSize: 11)),
          ],
        ),
      ],
    );
  }

  Widget _iconBtn({
    required IconData icon,
    required Color bg,
    required Color iconColor,
    required VoidCallback onTap,
  }) {
    return SizedBox(
      height: 38,
      width: 38,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Icon(icon, color: iconColor, size: 17),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════
//  DETAIL BOTTOM SHEET
// ════════════════════════════════════════════════════════

class _AppointmentDetailSheet extends StatelessWidget {
  final AppointmentList appointment;

  const _AppointmentDetailSheet({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final sColor = statusColor(a.status);
    final sBg = statusBgColor(a.status);
    final sIcon = statusIcon(a.status);
    final hasMap = a.latitude != null && a.longitude != null;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (_, controller) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: kDivider,
                  borderRadius: BorderRadius.circular(2)),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: ListView(
                controller: controller,
                padding: EdgeInsets.zero,
                children: [
                  // ── HERO BANNER ──
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 20),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          kPrimary.withValues(alpha: 0.9),
                          kPrimaryDark,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 62,
                          height: 62,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Center(
                            child: Text(
                              (a.name ?? "?")[0].toUpperCase(),
                              style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w800,
                                  color: Colors.white),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(a.name ?? "Unknown",
                                  style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: Colors.white)),
                              const SizedBox(height: 4),
                              Text(
                                "${a.gender ?? "—"}  ·  DOB: ${formatDate(a.dob)}",
                                style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.white
                                        .withValues(alpha: 0.8)),
                              ),
                              const SizedBox(height: 10),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: Colors.white
                                      .withValues(alpha: 0.18),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                  border: Border.all(
                                      color: Colors.white
                                          .withValues(alpha: 0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(sIcon,
                                        size: 12, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(capitalise(a.status),
                                        style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 12,
                                            fontWeight:
                                                FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 14),

                // ── ACTIONS ──
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 42,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11)),
                          ),
                          onPressed: () {
                            // navigate to detail
                          },
                          child: const Text(
                            "View Details",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (onReview != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: SizedBox(
                          height: 42,
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: kPrimary,
                              side: const BorderSide(color: kPrimary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(11),
                              ),
                            ),
                            onPressed: onReview,
                            child: const Text(
                              "Review",
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(width: 8),
                    Container(
                      height: 42,
                      width: 42,
                      decoration: BoxDecoration(
                        color: kBg,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: kDivider),
                      ),
                      child: Column(
                        children: [
                          _detailRow(Icons.badge_rounded, kBlueLight,
                              kBlue, "Patient Name", a.name ?? "—"),
                          _dividerLine(),
                          _detailRow(Icons.wc_rounded, kPurpleLight,
                              kPurple, "Gender", a.gender ?? "—"),
                          _dividerLine(),
                          _detailRow(Icons.cake_rounded, kAmberLight,
                              kAmber, "Date of Birth", formatDate(a.dob)),
                          if (a.queueNumber != null) ...[
                            _dividerLine(),
                            _detailRow(
                                Icons.queue_rounded,
                                kGreenLight,
                                kGreen,
                                "Queue Number",
                                "Q #${a.queueNumber}"),
                          ],
                          if (a.bookingFor != null) ...[
                            _dividerLine(),
                            _detailRow(Icons.people_rounded, kPurpleLight,
                                kPurple, "Booking For", a.bookingFor!),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SizedBox(
                      height: 50,
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                        onPressed: () => Navigator.pop(context),
                        child: const Text("Close",
                            style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 15)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSection(String title) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: kTextLight,
                letterSpacing: 1.2)),
      );

  Widget _scheduleChip({
    required IconData icon,
    required Color color,
    required Color bg,
    required String label,
    required String value,
    required String sub,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kDivider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
                color: bg, borderRadius: BorderRadius.circular(9)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(height: 10),
          Text(label,
              style: const TextStyle(
                  color: kTextMid,
                  fontSize: 11,
                  fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value,
              style: const TextStyle(
                  color: kTextDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          if (sub.isNotEmpty)
            Text(sub,
                style: const TextStyle(color: kTextMid, fontSize: 11)),
        ],
      ),
    );
  }
}
