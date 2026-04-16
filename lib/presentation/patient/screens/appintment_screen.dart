
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/queue_preview_model.dart';
import 'package:qless/domain/models/review_request_model.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/review_viewmodel.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Modern Teal Theme (Minimal & Compact) ──────────────────────────────────
class _C {
  _C._();

  static const teal = Color(0xFF26C6B0);
  static const tealDark = Color(0xFF2BB5A0);
  static const tealLight = Color(0xFFD9F5F1);
  static const tealLighter = Color(0xFFF2FCFA);

  static const textPrimary = Color(0xFF2D3748);
  static const textSlate = Color(0xFF718096);
  static const textMuted = Color(0xFFA0AEC0);

  static const border = Color(0xFFEDF2F7);
  static const bg = Colors.white;
  static const card = Colors.white;

  static const green = Color(0xFF68D391);
  static const amber = Color(0xFFF6AD55);
  static const red = Color(0xFFFC8181);

  static const purple = Color(0xFF9F7AEA);
  static const indigo = Color(0xFF7F9CF5);

  // Status accents (preserved for clarity)
  static const blue = Color(0xFF3B82F6);
  static const blueLight = Color(0xFFDBEAFE);
  static const greenLight = Color(0xFFDCFCE7);
  static const amberLight = Color(0xFFFEF3C7);
  static const purpleLight = Color(0xFFEDE9FE);
  static const redLight = Color(0xFFFEE2E2);
  static const divider = Color(0xFFE5E7EB);

  // Dark mode
  static const darkSurface = Color(0xFF1E2A28);
  static const darkBg = Color(0xFF0F1F1D);
}

// ── FILTER TABS (compact) ────────────────────────────────────────────────────
const _filters = [
  _FilterTab("all", "All", Icons.list_rounded, _C.teal, _C.tealLighter),
  _FilterTab("today", "Today", Icons.today_rounded, _C.teal, _C.blueLight),
  _FilterTab("upcoming", "Upcoming", Icons.schedule_rounded, _C.teal, _C.purpleLight),
  _FilterTab("completed", "Completed", Icons.check_circle_rounded, _C.teal, _C.greenLight),
  _FilterTab("cancelled", "Cancelled", Icons.cancel_rounded, _C.teal, _C.redLight),
];

class _FilterTab {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  final Color bg;
  const _FilterTab(this.key, this.label, this.icon, this.color, this.bg);
}

// ── HELPERS (updated colors) ─────────────────────────────────────────────────
Color statusColor(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return _C.blue;
    case "complete":
    case "completed":
      return _C.green;
    case "cancelled":
      return _C.red;
    default:
      return _C.amber;
  }
}

Color statusBgColor(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return _C.blueLight;
    case "complete":
    case "completed":
      return _C.greenLight;
    case "cancelled":
      return _C.redLight;
    default:
      return _C.amberLight;
  }
}

IconData statusIcon(String? s) {
  switch (s?.toLowerCase()) {
    case "upcoming":
    case "confirmed":
    case "booked":
      return Icons.schedule_rounded;
    case "complete":
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
    "https://www.google.com/maps/search/?api=1&query=$lat,$lng&query_place_id=$encoded",
  );
  if (await canLaunchUrl(uri)) await launchUrl(uri);
}

// ── FILTER LOGIC (unchanged) ────────────────────────────────────────────────
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
  final status = a.status?.toLowerCase();
  if (status == 'cancelled' || status == 'completed' || status == 'complete') {
    return false;
  }
  final now = DateTime.now();
  final apptDay = DateTime(p.year, p.month, p.day);
  final todayDay = DateTime(now.year, now.month, now.day);
  return apptDay.isAfter(todayDay);
}

bool _isCompleted(AppointmentList a) {
  final s = a.status?.toLowerCase();
  return s == "completed" || s == "complete";
}

bool _isCancelled(AppointmentList a) => a.status?.toLowerCase() == "cancelled";

List<AppointmentList> applyFilter(
  List<AppointmentList> list,
  String filter,
  String search,
) {
  return list.where((a) {
    final matchSearch = search.isEmpty ||
        (a.patientName?.toLowerCase().contains(search.toLowerCase()) ?? false);
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
      default:
        matchFilter = true;
    }
    return matchSearch && matchFilter;
  }).toList();
}

// ════════════════════════════════════════════════════════
// SCREEN (compact modern version)
// ════════════════════════════════════════════════════════
class AppointmentScreen extends ConsumerStatefulWidget {
  final ValueChanged<int>? onTabChange;
  const AppointmentScreen({super.key, this.onTabChange});

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
  Timer? _refreshTimer;

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
    _refreshTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  bool _isLiveQueueToday(AppointmentList a) {
    if ((a.status?.toLowerCase() ?? '') != 'booked') return false;
    if (a.bookingType != 1) return false;
    final d = DateTime.tryParse(a.appointmentDate ?? '');
    if (d == null) return false;
    final now = DateTime.now();
    final isToday = d.year == now.year && d.month == now.month && d.day == now.day;
    return isToday && (a.queueStarted == true);
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
      builder: (_) => _AppointmentDetailSheet(
        appointment: a,
        onCancel: _canCancel(a) ? () { Navigator.pop(context); _handleCancel(a); } : null,
        onReschedule: _canReschedule(a) ? () { Navigator.pop(context); _handleReschedule(a); } : null,
      ),
    );
  }

  bool _canReview(AppointmentList a) {
    final s = a.status?.toLowerCase();
    return (s == 'completed' || s == 'complete') &&
        a.appointmentId != null &&
        a.doctorId != null &&
        a.patientId != null;
  }

  bool _canCancel(AppointmentList a) {
    final s = a.status?.toLowerCase();
    return (s == 'upcoming' || s == 'booked' || s == 'confirmed') &&
        a.appointmentId != null;
  }

  bool _canReschedule(AppointmentList a) {
    final s = a.status?.toLowerCase();
    return (s == 'upcoming' || s == 'booked' || s == 'confirmed') &&
        a.appointmentId != null &&
        a.doctorId != null;
  }

  Future<void> _handleCancel(AppointmentList a) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Cancel Appointment',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
        ),
        content: const Text(
          'Are you sure you want to cancel this appointment?',
          style: TextStyle(color: _C.textSlate, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No', style: TextStyle(color: _C.textSlate)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: _C.red,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Yes, Cancel',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    await ref
        .read(appointmentViewModelProvider.notifier)
        .cancelAppointment(a.appointmentId!);
    if (!mounted) return;
    final id = ref.read(patientLoginViewModelProvider).patientId;
    if (id != null && id != 0) {
      ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(id);
    }
  }

  Future<void> _handleReschedule(AppointmentList a) async {
    final doctor = DoctorDetails(
      doctorId: a.doctorId,
      name: a.doctorName,
      specialization: a.specialization,
      experience: a.experience,
      clinicName: a.clinicName,
      clinicAddress: a.clinicAddress,
      latitude: a.latitude,
      longitude: a.longitude,
      clinicContact: a.clinicContact,
    );
    final rescheduled = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => BookAppointmentScreen(
          doctor: doctor,
          isReschedule: true,
          appointmentId: a.appointmentId,
        ),
      ),
    );
    if (rescheduled == true && mounted) {
      final id = ref.read(patientLoginViewModelProvider).patientId;
      if (id != null && id != 0) {
        ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(id);
      }
    }
  }

  Future<void> _handleReview(BuildContext context, AppointmentList a) async {
    final input = await showAppointmentReviewDialog(
      context,
      doctorName: a.doctorName ?? 'Doctor',
    );
    if (input == null) return;
    await ref
        .read(reviewViewModelProvider.notifier)
        .submitReview(
          ReviewRequestModel(
            appointmentId: a.appointmentId!,
            doctorId: a.doctorId!,
            patientId: a.patientId!,
            rating: input.rating,
            comment: input.comment,
          ),
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
      if (_idMissing && nextId != 0) setState(() => _idMissing = false);
    });

    ref.listen<ReviewState>(reviewViewModelProvider, (prev, next) {
      if (next.error != null && next.error != prev?.error) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: _C.red),
        );
      }
      if (next.isSuccess && next.isSuccess != prev?.isSuccess) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thanks for your review!'),
            backgroundColor: _C.green,
          ),
        );
      }
    });

    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      final prevError = prev?.error;
      if (next.error != null && next.error != prevError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error!), backgroundColor: _C.red),
        );
      }
      if (next.isSuccess &&
          next.rescheduleResponse != null &&
          next.rescheduleResponse != prev?.rescheduleResponse) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.rescheduleResponse?.message ?? 'Appointment rescheduled',
            ),
            backgroundColor: _C.green,
          ),
        );
      }
      if (next.isSuccess &&
          next.cancelResponse != null &&
          next.cancelResponse != prev?.cancelResponse) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              next.cancelResponse?.message ?? 'Appointment cancelled',
            ),
            backgroundColor: _C.green,
          ),
        );
      }
    });

    final vmState = ref.watch(appointmentViewModelProvider);
    final asyncAppointments = vmState.patientAppointmentsList;
    final loginState = ref.watch(patientLoginViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _C.darkBg : _C.bg,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 88.0),
        child: FloatingActionButton.extended(
          backgroundColor: _C.teal,
          elevation: 4,
          onPressed: () {
            final onTabChange = widget.onTabChange;
            if (onTabChange != null) {
              onTabChange(1);
              return;
            }
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => PatientBottomNav(
                  onToggleTheme: () {},
                  themeMode: ThemeMode.system,
                  initialTab: 1,
                ),
              ),
            );
          },
          icon: const Icon(Icons.add_rounded, color: Colors.white),
          label: const Text(
            "Book",
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            _buildHeader(isDark: isDark),
            Expanded(
              child: _isWaitingForId
                  ? _buildLoading("Loading your account...")
                  : _idMissing && (loginState.patientId ?? 0) == 0
                      ? _buildMissingLogin()
                      : asyncAppointments == null
                          ? _buildLoading("Fetching appointments...")
                          : asyncAppointments.when(
                              loading: () => _buildLoading("Fetching appointments..."),
                              error: (_, __) => _buildError(),
                              data: (list) => _buildTabContent(list, isDark: isDark),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  // ── HEADER (ultra-compact) ─────────────────────────────────────────────────
  Widget _buildHeader({required bool isDark}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? _C.darkSurface : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              MediaQuery.of(context).padding.top + 10,
              16,
              0,
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: _C.tealLighter,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.calendar_month_rounded,
                    color: _C.teal,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Appointments",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: _C.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      SizedBox(height: 1),
                      Text(
                        "Manage your schedule",
                        style: TextStyle(fontSize: 13, color: _C.textMuted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              height: 42,
              decoration: BoxDecoration(
                color: isDark ? _C.darkSurface : _C.card,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _C.border),
              ),
              child: TextField(
                onChanged: (v) => setState(() => searchQuery = v),
                style: TextStyle(fontSize: 14, color: isDark ? Colors.white : _C.textPrimary),
                decoration: InputDecoration(
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: _C.textMuted,
                    size: 20,
                  ),
                  hintText: "Search by patient name...",
                  hintStyle: TextStyle(color: _C.textMuted, fontSize: 14),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(vertical: 11),
                  suffixIcon: searchQuery.isNotEmpty
                      ? GestureDetector(
                          onTap: () => setState(() => searchQuery = ""),
                          child: const Icon(
                            Icons.close_rounded,
                            color: _C.textMuted,
                            size: 18,
                          ),
                        )
                      : null,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            indicatorPadding: EdgeInsets.zero,
            indicator: BoxDecoration(
              color: _filters[_tabController.index].color,
              borderRadius: BorderRadius.circular(8),
            ),
            indicatorSize: TabBarIndicatorSize.tab,
            dividerColor: Colors.transparent,
            splashFactory: NoSplash.splashFactory,
            overlayColor: WidgetStateProperty.all(Colors.transparent),
            labelPadding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            tabs: _filters.map((f) {
              final isSelected = _filters[_tabController.index].key == f.key;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? f.color : _C.bg,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: isSelected ? f.color : _C.divider),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      f.icon,
                      size: 13,
                      color: isSelected ? Colors.white : f.color,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      f.label,
                      style: TextStyle(
                        color: isSelected ? Colors.white : _C.textSlate,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 2),
        ],
      ),
    );
  }

  // ── TAB CONTENT ────────────────────────────────────────────────────────────
  Widget _buildTabContent(List<AppointmentList> appointments, {required bool isDark}) {
    return TabBarView(
      controller: _tabController,
      children: _filters.map((f) {
        final filtered = applyFilter(appointments, f.key, searchQuery);
        return _buildList(filtered, f, isDark: isDark);
      }).toList(),
    );
  }

  Widget _buildList(List<AppointmentList> filtered, _FilterTab tab, {required bool isDark}) {
    return RefreshIndicator(
      color: _C.teal,
      onRefresh: () async {
        final id = ref.read(patientLoginViewModelProvider).patientId;
        if (id != null && id != 0) {
          await ref
              .read(appointmentViewModelProvider.notifier)
              .getPatientAppointments(id);
        }
      },
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 80), // tighter padding
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final a = filtered[index];
          final live = _isLiveQueueToday(a);
          return _AppointmentCard(
            appointment: a,
            onViewDetails: () => _openDetail(a),
            onReview: _canReview(a) ? () => _handleReview(context, a) : null,
            onCancel: _canCancel(a) ? () => _handleCancel(a) : null,
            onReschedule: _canReschedule(a) ? () => _handleReschedule(a) : null,
            queueNumber: live ? a.myQueueNumber : null,
            isLiveQueue: live,
            estimatedMinutes: null,
            patientsAhead: live ? a.patientsAhead : null,
            estimatedArrivalTime: live ? a.estimatedArrivalTime : null,
            isDark: isDark,
          );
        },
      ),
    );
  }

  // ── STATES ─────────────────────────────────────────────────────────────────
  Widget _buildLoading(String msg) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                color: _C.teal,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
              ),
            ),
            const SizedBox(height: 16),
            Text(msg, style: const TextStyle(color: _C.textSlate, fontSize: 14)),
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
                  color: _C.redLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.wifi_off_rounded, size: 32, color: _C.red),
              ),
              const SizedBox(height: 16),
              const Text(
                "Something went wrong",
                style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Couldn't load your appointments.\nPlease try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.textSlate, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 140,
                height: 44,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _C.teal,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () {
                    final id = ref.read(patientLoginViewModelProvider).patientId;
                    if (id != null && id != 0) {
                      ref
                          .read(appointmentViewModelProvider.notifier)
                          .getPatientAppointments(id);
                    }
                  },
                  child: const Text(
                    "Retry",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
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
                  color: _C.amberLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.lock_outline_rounded,
                  size: 32,
                  color: _C.amber,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                "Session Expired",
                style: TextStyle(
                  color: _C.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                "Please login again to\nview your appointments.",
                textAlign: TextAlign.center,
                style: TextStyle(color: _C.textSlate, fontSize: 13, height: 1.5),
              ),
            ],
          ),
        ),
      );
}

// ── COMPACT APPOINTMENT CARD ────────────────────────────────────────────────
class _AppointmentCard extends StatelessWidget {
  final AppointmentList appointment;
  final VoidCallback onViewDetails;
  final VoidCallback? onReview;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;
  final int? queueNumber;
  final bool isLiveQueue;
  final int? estimatedMinutes;
  final int? patientsAhead;
  final String? estimatedArrivalTime;
  final bool isDark;

  const _AppointmentCard({
    required this.appointment,
    required this.onViewDetails,
    this.onReview,
    this.onCancel,
    this.onReschedule,
    this.queueNumber,
    this.isLiveQueue = false,
    this.estimatedMinutes,
    this.patientsAhead,
    this.estimatedArrivalTime,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final a = appointment;
    final sColor = statusColor(a.status);
    final sBg = statusBgColor(a.status);
    final sIcon = statusIcon(a.status);
    final hasMap = a.latitude != null && a.longitude != null;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: isDark ? _C.darkSurface : _C.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _C.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.15 : 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: onViewDetails,
              child: Padding(
                padding: const EdgeInsets.all(12), // tighter
                child: Column(
                  children: [
                    // Row 1: Avatar + Name + Status
                    Row(
                      children: [
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                _C.teal.withOpacity(0.15),
                                _C.teal.withOpacity(0.05),
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(11),
                          ),
                          child: Center(
                            child: Text(
                              (a.patientName ?? "?")[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: _C.teal,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.patientName ?? "Unknown",
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? Colors.white : _C.textPrimary,
                                  fontSize: 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.person_rounded, size: 11, color: _C.textMuted),
                                  const SizedBox(width: 3),
                                  Expanded(
                                    child: Text(
                                      a.doctorName ?? "—",
                                      style: TextStyle(color: _C.textSlate, fontSize: 11),
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
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: sBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(sIcon, size: 11, color: sColor),
                              const SizedBox(width: 4),
                              Text(
                                capitalise(a.status),
                                style: TextStyle(
                                  color: sColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: Divider(height: 1, color: _C.divider),
                    ),

                    // Row 2: Date | Time (compact)
                    Row(
                      children: [
                        Expanded(
                          child: _miniInfo(
                            icon: Icons.calendar_today_rounded,
                            iconBg: _C.blueLight,
                            iconColor: _C.blue,
                            top: formatDateRelative(a.appointmentDate),
                            bottom: formatDate(a.appointmentDate),
                          ),
                        ),
                        Expanded(
                          child: _miniInfo(
                            icon: Icons.access_time_rounded,
                            iconBg: _C.greenLight,
                            iconColor: _C.green,
                            top: formatTime(a.startTime),
                            bottom: a.endTime != null ? "– ${formatTime(a.endTime)}" : "",
                          ),
                        ),
                      ],
                    ),

                    // Live queue banner
                    if (isLiveQueue) ...[
                      const SizedBox(height: 8),
                      _LiveQueueBanner(
                        queueNumber: queueNumber,
                        estimatedMinutes: estimatedMinutes,
                        estimatedArrivalTime: estimatedArrivalTime,
                        patientsAhead: patientsAhead,
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Action buttons (compact)
                    Row(
                      children: [
                        Expanded(
                          child: SizedBox(
                            height: 36,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _C.teal,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: onViewDetails,
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
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 36,
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: _C.teal,
                                side: const BorderSide(color: _C.teal),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: onReview,
                              child: const Text(
                                "Review",
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                        if (onReschedule != null) ...[
                          const SizedBox(width: 6),
                          _iconBtn(
                            icon: Icons.edit_calendar_rounded,
                            bg: _C.amberLight,
                            iconColor: _C.amber,
                            onTap: onReschedule!,
                          ),
                        ],
                        if (onCancel != null) ...[
                          const SizedBox(width: 6),
                          _iconBtn(
                            icon: Icons.cancel_rounded,
                            bg: _C.redLight,
                            iconColor: _C.red,
                            onTap: onCancel!,
                          ),
                        ],
                        const SizedBox(width: 6),
                        if (hasMap) ...[
                          _iconBtn(
                            icon: Icons.map_rounded,
                            bg: _C.blueLight,
                            iconColor: _C.blue,
                            onTap: () => openMap(
                              a.latitude!,
                              a.longitude!,
                              a.clinicName,
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        _iconBtn(
                          icon: Icons.call_rounded,
                          bg: _C.tealLighter,
                          iconColor: _C.teal,
                          onTap: () {},
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Queue badge
        if (queueNumber != null)
          Positioned(
            top: -7,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
              decoration: BoxDecoration(
                color: _C.teal,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _C.teal.withOpacity(0.35),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                "Q$queueNumber",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
      ],
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
            color: iconBg,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, size: 12, color: iconColor),
        ),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              top,
              style: TextStyle(
                color: isDark ? Colors.white : _C.textPrimary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (bottom.isNotEmpty)
              Text(bottom, style: TextStyle(color: _C.textSlate, fontSize: 11)),
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
      height: 36,
      width: 36,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          elevation: 0,
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: onTap,
        child: Icon(icon, color: iconColor, size: 16),
      ),
    );
  }
}

// ── LIVE QUEUE BANNER (compact) ─────────────────────────────────────────────
class _LiveQueueBanner extends StatefulWidget {
  final int? queueNumber;
  final int? estimatedMinutes;
  final String? estimatedArrivalTime;
  final int? patientsAhead;
  const _LiveQueueBanner({
    this.queueNumber,
    this.estimatedMinutes,
    this.estimatedArrivalTime,
    this.patientsAhead,
  });

  @override
  State<_LiveQueueBanner> createState() => _LiveQueueBannerState();
}

class _LiveQueueBannerState extends State<_LiveQueueBanner> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);
    _pulse = Tween<double>(begin: 0.35, end: 1.0).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  bool get _hasEstimate =>
      widget.estimatedMinutes != null ||
      widget.estimatedArrivalTime != null ||
      widget.patientsAhead != null;

  @override
  Widget build(BuildContext context) {
    final q = widget.queueNumber;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: _C.green.withOpacity(0.07),
            borderRadius: _hasEstimate
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            border: Border.all(color: _C.green.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              AnimatedBuilder(
                animation: _pulse,
                builder: (_, __) => Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _C.green.withOpacity(_pulse.value),
                  ),
                ),
              ),
              const SizedBox(width: 9),
              Expanded(
                child: RichText(
                  text: TextSpan(
                    style: const TextStyle(fontSize: 13, color: _C.textPrimary),
                    children: [
                      const TextSpan(
                        text: 'Your queue position ',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _C.textSlate),
                      ),
                      TextSpan(
                        text: q != null ? '#$q' : '—',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: q != null ? _C.green : _C.textSlate,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: _C.green,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.circle, size: 6, color: Colors.white),
                    SizedBox(width: 4),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (_hasEstimate)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _C.amber.withOpacity(0.07),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
              border: Border(
                left: BorderSide(color: _C.green.withOpacity(0.28), width: 1),
                right: BorderSide(color: _C.green.withOpacity(0.28), width: 1),
                bottom: BorderSide(color: _C.green.withOpacity(0.28), width: 1),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.hourglass_top_rounded, size: 13, color: _C.amber),
                const SizedBox(width: 6),
                if (widget.patientsAhead == 0)
                  const Text(
                    'Your turn now',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.amber),
                  )
                else if (widget.estimatedMinutes != null)
                  Text(
                    '~${widget.estimatedMinutes} min wait',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _C.amber),
                  ),
                if (widget.estimatedArrivalTime != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    '(~${widget.estimatedArrivalTime})',
                    style: const TextStyle(fontSize: 12, color: _C.textSlate),
                  ),
                ],
                if (widget.patientsAhead != null) ...[
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: _C.amber.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      widget.patientsAhead == 0 ? 'Next' : '${widget.patientsAhead} ahead',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _C.amber,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

// ── DETAIL BOTTOM SHEET (compact) ───────────────────────────────────────────
class _AppointmentDetailSheet extends StatelessWidget {
  final AppointmentList appointment;
  final VoidCallback? onCancel;
  final VoidCallback? onReschedule;
  const _AppointmentDetailSheet({
    required this.appointment,
    this.onCancel,
    this.onReschedule,
  });

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
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: _C.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView(
                controller: controller,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  // Hero banner (compact)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_C.teal.withOpacity(0.9), _C.tealDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              (a.patientName ?? "?")[0].toUpperCase(),
                              style: const TextStyle(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.patientName ?? "Unknown",
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                "${a.gender ?? "—"} · DOB: ${formatDate(a.dob)}",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.white.withOpacity(0.85),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.white.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(sIcon, size: 12, color: Colors.white),
                                    const SizedBox(width: 5),
                                    Text(
                                      capitalise(a.status),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sheetSection("Schedule"),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _scheduleChip(
                          icon: Icons.calendar_today_rounded,
                          color: _C.blue,
                          bg: _C.blueLight,
                          label: "Date",
                          value: formatDate(a.appointmentDate),
                          sub: formatDateRelative(a.appointmentDate),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _scheduleChip(
                          icon: Icons.access_time_filled_rounded,
                          color: _C.green,
                          bg: _C.greenLight,
                          label: "Time",
                          value: formatTime(a.startTime),
                          sub: a.endTime != null ? "Ends ${formatTime(a.endTime)}" : "",
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  _sheetSection("Doctor"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.divider),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: [_C.teal.withOpacity(0.15), _C.teal.withOpacity(0.04)]),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.person_rounded, color: _C.teal, size: 24),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                a.doctorName ?? "—",
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w700,
                                  color: _C.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                a.specialization ?? "—",
                                style: TextStyle(color: _C.teal, fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                              if (a.experience != null) ...[
                                const SizedBox(height: 2),
                                Text("${a.experience} yrs experience", style: TextStyle(color: _C.textSlate, fontSize: 11)),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sheetSection("Clinic"),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.divider),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 40,
                              decoration: BoxDecoration(color: _C.amberLight, borderRadius: BorderRadius.circular(10)),
                              child: const Icon(Icons.local_hospital_rounded, color: _C.amber, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(a.clinicName ?? "—", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: _C.textPrimary)),
                                  if (a.clinicAddress != null) ...[
                                    const SizedBox(height: 2),
                                    Text(a.clinicAddress!, style: TextStyle(color: _C.textSlate, fontSize: 12)),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                        if (hasMap) ...[
                          const SizedBox(height: 12),
                          const Divider(height: 1, color: _C.divider),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 40,
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _C.blueLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: () => openMap(a.latitude!, a.longitude!, a.clinicName),
                              icon: const Icon(Icons.map_rounded, color: _C.blue, size: 17),
                              label: const Text(
                                "Open in Google Maps",
                                style: TextStyle(color: _C.blue, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  _sheetSection("Details"),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _C.bg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _C.divider),
                    ),
                    child: Column(
                      children: [
                        _detailRow(Icons.badge_rounded, _C.blueLight, _C.blue, "Patient Name", a.patientName ?? "—"),
                        _dividerLine(),
                        _detailRow(Icons.wc_rounded, _C.purpleLight, _C.purple, "Gender", a.gender ?? "—"),
                        _dividerLine(),
                        _detailRow(Icons.cake_rounded, _C.amberLight, _C.amber, "Date of Birth", formatDate(a.dob)),
                        if (a.queueNumber != null) ...[
                          _dividerLine(),
                          _detailRow(Icons.queue_rounded, _C.greenLight, _C.green, "Queue Number", "Q #${a.queueNumber}"),
                        ],
                        if (a.bookingFor != null) ...[
                          _dividerLine(),
                          _detailRow(Icons.people_rounded, _C.purpleLight, _C.purple, "Booking For", a.bookingFor!),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  if (onReschedule != null || onCancel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          if (onReschedule != null)
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.amberLight,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: onReschedule,
                                  icon: const Icon(Icons.edit_calendar_rounded, color: _C.amber, size: 18),
                                  label: const Text("Reschedule", style: TextStyle(color: _C.amber, fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ),
                            ),
                          if (onReschedule != null && onCancel != null) const SizedBox(width: 10),
                          if (onCancel != null)
                            Expanded(
                              child: SizedBox(
                                height: 46,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: _C.redLight,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                  ),
                                  onPressed: onCancel,
                                  icon: const Icon(Icons.cancel_rounded, color: _C.red, size: 18),
                                  label: const Text("Cancel", style: TextStyle(color: _C.red, fontWeight: FontWeight.w700, fontSize: 14)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                  SizedBox(
                    height: 48,
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _C.teal,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "Close",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sheetSection(String title) => Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w800,
          color: _C.textMuted,
          letterSpacing: 1.2,
        ),
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
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _C.bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _C.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 15, color: color),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: _C.textSlate, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(color: _C.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          if (sub.isNotEmpty) Text(sub, style: TextStyle(color: _C.textSlate, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, Color bg, Color color, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 14, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: TextStyle(color: _C.textSlate, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
          Text(value, style: TextStyle(color: _C.textPrimary, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  Widget _dividerLine() => const Divider(height: 1, color: _C.divider, indent: 12, endIndent: 12);
}

// Review dialog remains unchanged (font sizes & theme already match)
class AppointmentReviewInput {
  final int rating;
  final String comment;
  const AppointmentReviewInput({required this.rating, required this.comment});
}

Future<AppointmentReviewInput?> showAppointmentReviewDialog(
  BuildContext context, {
  required String doctorName,
  String? doctorSpecialty,
  String? doctorInitials,
}) {
  final commentCtrl = TextEditingController();
  int rating = 0;
  int hoveredRating = 0;
  const starColors = [
    Colors.transparent,
    Color(0xFFE24B4A),
    Color(0xFFEF9F27),
    Color(0xFF639922),
    Color(0xFF1D9E75),
    Color(0xFF378ADD),
  ];
  const starLabels = ['', 'Poor', 'Fair', 'Good', 'Very good', 'Excellent'];

  return showDialog<AppointmentReviewInput>(
    context: context,
    barrierColor: Colors.black54,
    barrierDismissible: false,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) {
        final activeRating = hoveredRating > 0 ? hoveredRating : rating;
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          title: Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE6F1FB),
                child: Text(
                  doctorInitials ?? doctorName.substring(0, 2).toUpperCase(),
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF185FA5)),
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Rate your visit', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                  Text(
                    'Dr. $doctorName${doctorSpecialty != null ? ' · $doctorSpecialty' : ''}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w400),
                  ),
                ],
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Divider(height: 28),
              const Text('How was your appointment experience?', style: TextStyle(fontSize: 13, color: Colors.grey)),
              const SizedBox(height: 12),
              Row(
                children: List.generate(5, (i) {
                  final idx = i + 1;
                  final filled = idx <= activeRating;
                  final color = activeRating > 0 ? starColors[activeRating] : Colors.grey.shade300;
                  return GestureDetector(
                    onTap: () => setState(() {
                      rating = idx;
                      hoveredRating = 0;
                    }),
                    child: MouseRegion(
                      onEnter: (_) => setState(() => hoveredRating = idx),
                      onExit: (_) => setState(() => hoveredRating = 0),
                      child: Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(
                          filled ? Icons.star_rounded : Icons.star_outline_rounded,
                          size: 32,
                          color: filled ? color : Colors.grey.shade300,
                        ),
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 4),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: activeRating > 0
                    ? Text(
                        starLabels[activeRating],
                        key: ValueKey(activeRating),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: starColors[activeRating]),
                      )
                    : const SizedBox(height: 16),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: commentCtrl,
                maxLines: 3,
                style: const TextStyle(fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Write a short review (optional)',
                  hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  contentPadding: const EdgeInsets.all(12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: Colors.grey.shade200),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF378ADD), width: 1.2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      side: BorderSide(color: Colors.grey.shade300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF378ADD),
                      disabledBackgroundColor: const Color(0xFF378ADD).withOpacity(0.4),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    onPressed: rating <= 0 ? null : () => Navigator.pop(ctx, AppointmentReviewInput(rating: rating, comment: commentCtrl.text.trim())),
                    child: const Text('Submit review'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
        );
      },
    ),
  );
}


