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
const kPrimary = Color(0xFF0D9488); // teal-600
const kPrimaryLight = Color(0xFFCCFBF1); // teal-100
const kPrimaryDark = Color(0xFF115E59); // teal-800
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
const kDivider = Color(0xFFE5E7EB);

class AppointmentScreen extends ConsumerStatefulWidget {
  const AppointmentScreen({super.key});

  @override
  ConsumerState<AppointmentScreen> createState() => _AppointmentScreenState();
}

class _AppointmentScreenState extends ConsumerState<AppointmentScreen> {
  String searchQuery = "";
  String filterStatus = "all";
  bool _didFetch = false;
  bool _isWaitingForId = false;
  bool _idMissing = false;

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensurePatientIdAndFetch);
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_didFetch) return;
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
    ref
        .read(appointmentViewModelProvider.notifier)
        .getPatientAppointments(patientId);
  }

  // ── STATUS HELPERS ──

  Color getStatusColor(String? status) {
    switch (status?.toLowerCase()) {
      case "upcoming":
      case "confirmed":
        return kBlue;
      case "completed":
        return kGreen;
      case "cancelled":
        return kRed;
      default:
        return kAmber;
    }
  }

  Color getStatusBgColor(String? status) {
    switch (status?.toLowerCase()) {
      case "upcoming":
      case "confirmed":
        return kBlueLight;
      case "completed":
        return kGreenLight;
      case "cancelled":
        return kRedLight;
      default:
        return kAmberLight;
    }
  }

  IconData getStatusIcon(String? status) {
    switch (status?.toLowerCase()) {
      case "upcoming":
      case "confirmed":
        return Icons.schedule_rounded;
      case "completed":
        return Icons.check_circle_rounded;
      case "cancelled":
        return Icons.cancel_rounded;
      default:
        return Icons.info_rounded;
    }
  }

  bool _isUpcoming(AppointmentList a) {
    if (a.appointmentDate != null) {
      final parsed = DateTime.tryParse(a.appointmentDate!);
      if (parsed != null) {
        final today = DateTime.now();
        final appointmentDay =
            DateTime(parsed.year, parsed.month, parsed.day);
        final todayDay = DateTime(today.year, today.month, today.day);
        if (appointmentDay.isAfter(todayDay) ||
            appointmentDay.isAtSameMomentAs(todayDay)) {
          return true;
        }
      }
    }
    return a.status?.toLowerCase() == "upcoming" ||
        a.status?.toLowerCase() == "confirmed";
  }

  List<AppointmentList> _applyFilters(List<AppointmentList> appointments) {
    return appointments.where((a) {
      final matchSearch = searchQuery.isEmpty ||
          (a.patientName?.toLowerCase().contains(searchQuery.toLowerCase()) ?? false);

      final bool matchFilter;
      if (filterStatus == "all") {
        matchFilter = true;
      } else if (filterStatus == "upcoming") {
        matchFilter = _isUpcoming(a);
      } else {
        matchFilter = a.status?.toLowerCase() == filterStatus;
      }

      return matchSearch && matchFilter;
    }).toList();
  }

  String _formatDate(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    return DateFormat('dd MMM yyyy').format(parsed);
  }

  String _formatDateRelative(String dateStr) {
    final parsed = DateTime.tryParse(dateStr);
    if (parsed == null) return dateStr;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(parsed.year, parsed.month, parsed.day);
    final diff = date.difference(today).inDays;

    if (diff == 0) return "Today";
    if (diff == 1) return "Tomorrow";
    if (diff == -1) return "Yesterday";
    if (diff > 0 && diff <= 7) return "In $diff days";
    return DateFormat('dd MMM yyyy').format(parsed);
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
        onPressed: () {
          Navigator.push(context, MaterialPageRoute(builder: (_) => PatientBottomNav(onToggleTheme: () {  }, themeMode: ThemeMode.system,)));
        },
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
            // ── HEADER ──
            _buildHeader(),

            // ── CONTENT ──
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
                              error: (error, _) => _buildError(),
                              data: (appointments) =>
                                  _buildAppointmentList(appointments),
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
      padding: EdgeInsets.fromLTRB(
          20, MediaQuery.of(context).padding.top + 16, 20, 24),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.calendar_month_rounded,
                    color: kPrimary, size: 24),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Appointments",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                        letterSpacing: -0.5,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      "Manage your schedule",
                      style: TextStyle(
                        fontSize: 13,
                        color: kTextMid,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Search bar
          Container(
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDivider),
            ),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              style: const TextStyle(fontSize: 14, color: kTextDark),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kTextLight, size: 20),
                hintText: "Search appointments...",
                hintStyle: const TextStyle(color: kTextLight, fontSize: 14),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: searchQuery.isNotEmpty
                    ? GestureDetector(
                        onTap: () => setState(() => searchQuery = ""),
                        child: const Icon(Icons.close_rounded,
                            color: kTextLight, size: 18),
                      )
                    : null,
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ["all", "upcoming", "completed", "cancelled"].map(
                (status) {
                  final isSelected = filterStatus == status;
                  final label = status == "all" ? "All" : status[0].toUpperCase() + status.substring(1);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => setState(() => filterStatus = status),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected ? kPrimary : kBg,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isSelected ? kPrimary : kDivider,
                          ),
                        ),
                        child: Text(
                          label,
                          style: TextStyle(
                            color: isSelected ? Colors.white : kTextMid,
                            fontSize: 13,
                            fontWeight:
                                isSelected ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }

  // ── APPOINTMENT LIST ──

  Widget _buildAppointmentList(List<AppointmentList> appointments) {
    final filtered = _applyFilters(appointments);

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: kPrimaryLight,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.event_busy_rounded,
                  size: 40, color: kPrimary),
            ),
            const SizedBox(height: 16),
            const Text("No appointments found",
                style: TextStyle(
                    color: kTextDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text("Try adjusting your filters",
                style: TextStyle(color: kTextMid, fontSize: 13)),
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

  Widget _buildLoading(String message) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: CircularProgressIndicator(
              color: kPrimary,
              strokeWidth: 3,
              strokeCap: StrokeCap.round,
            ),
          ),
          const SizedBox(height: 16),
          Text(message,
              style: const TextStyle(color: kTextMid, fontSize: 14)),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: const BoxDecoration(
                color: kRedLight,
                shape: BoxShape.circle,
              ),
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
            const Text("Couldn't load your appointments.\nPlease try again.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMid, fontSize: 13, height: 1.5)),
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
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMissingLogin() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kAmberLight,
                shape: BoxShape.circle,
              ),
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
            const Text("Please login again to\nview your appointments.",
                textAlign: TextAlign.center,
                style: TextStyle(color: kTextMid, fontSize: 13, height: 1.5)),
          ],
        ),
      ),
    );
  }
}

// ── APPOINTMENT CARD ──

class _AppointmentCard extends StatelessWidget {
  final AppointmentList appointment;
  final Color statusColor;
  final Color statusBgColor;
  final IconData statusIcon;
  final String? formattedDate;
  final String? relativeDate;
  final String? formattedDob;
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
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            // navigate to detail screen
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // ── TOP: Avatar + Name + Status ──
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            kPrimary.withValues(alpha: 0.15),
                            kPrimary.withValues(alpha: 0.05),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: Text(
                          (appointment.patientName ?? "?")[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: kPrimary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Name + Gender
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
                              if (appointment.gender != null) ...[
                                Text(appointment.gender!,
                                    style: const TextStyle(
                                        color: kTextMid, fontSize: 12)),
                              ],
                              if (appointment.gender != null &&
                                  appointment.queueNumber != null)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6),
                                  child: Text("·",
                                      style: TextStyle(
                                          color: kTextLight, fontSize: 12)),
                                ),
                              if (appointment.queueNumber != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: kPrimaryLight,
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    "Q #${appointment.queueNumber}",
                                    style: const TextStyle(
                                      color: kPrimaryDark,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Status badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusBgColor,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, size: 12, color: statusColor),
                          const SizedBox(width: 4),
                          Text(
                            appointment.status ?? "—",
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // ── DIVIDER ──
                if (formattedDate != null || formattedDob != null) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12),
                    child: Divider(height: 1, color: kDivider),
                  ),

                  // ── DATE INFO ──
                  Row(
                    children: [
                      if (formattedDate != null)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: kBlueLight,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.calendar_today_rounded,
                                    size: 13, color: kBlue),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (relativeDate != null)
                                    Text(relativeDate!,
                                        style: const TextStyle(
                                          color: kTextDark,
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        )),
                                  Text(formattedDate!,
                                      style: const TextStyle(
                                          color: kTextMid, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      if (formattedDob != null)
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: kAmberLight,
                                  borderRadius: BorderRadius.circular(7),
                                ),
                                child: const Icon(Icons.cake_rounded,
                                    size: 13, color: kAmber),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text("DOB",
                                      style: TextStyle(
                                        color: kTextDark,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      )),
                                  Text(formattedDob!,
                                      style: const TextStyle(
                                          color: kTextMid, fontSize: 11)),
                                ],
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],

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
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(11),
                      ),
                      child: IconButton(
                        onPressed: () {
                          // call action
                        },
                        icon: const Icon(Icons.call_rounded,
                            color: kPrimary, size: 18),
                        padding: EdgeInsets.zero,
                      ),
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
}
