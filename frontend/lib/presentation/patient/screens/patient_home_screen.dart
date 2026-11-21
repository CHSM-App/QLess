import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qless/core/utils/name_utils.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_usecase_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/screens/location_storage.dart';
import 'package:qless/presentation/patient/providers/notification_provider.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

part 'patient_home_screen/fade.dart';
part 'patient_home_screen/shared.dart';
part 'patient_home_screen/location_sheet.dart';
part 'patient_home_screen/section_title.dart';
part 'patient_home_screen/appt_card.dart';
part 'patient_home_screen/specialty_chip.dart';

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final Function(int) onTabChange;
  final VoidCallback? onSeeAllAppointments;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onTabChange,
    this.onSeeAllAppointments,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  // Read once here: ref cannot be used in dispose() (the element is already
  // unmounted there, so it threw and skipped the rest of dispose).
  late final AppointmentViewmodel _apptVm;
  late List<Animation<double>> _anims;

  String _location = '';
  bool _locationLoaded = false;
  bool _didFetch = false;
  bool _isFetching = false;

  List<Map<String, dynamic>> _cachedSpecialties = [];
  bool _popupShown = false;
  final Map<int, double> _clinicRatings = {};

  @override
  void initState() {
    super.initState();
    _apptVm = ref.read(appointmentViewModelProvider.notifier);
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anims = List.generate(
      6,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(i * 0.08, 0.55 + i * 0.07, curve: Curves.easeOut),
        ),
      ),
    );

    _animCtrl.forward();
    _initLocation();
    Future.microtask(_ensurePatientIdAndFetch);
  }

  @override
  void dispose() {
    _apptVm.unwatchClinics();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_isFetching || _didFetch) return;
    _isFetching = true;
    try {
      final notifier = ref.read(patientLoginViewModelProvider.notifier);
      var pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid == 0) {
        await notifier.loadFromStoragePatient();
        pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      }
      if (pid == 0) return;
      _didFetch = true;
      // Refresh the notification inbox in parallel so the header bell's unread
      // count is accurate on cold start — without this, the badge stays empty
      // until an FCM arrives or the user opens the Notifications screen.
      ref.read(notificationProvider.notifier).loadFromServer();
      await Future.wait([
        ref
            .read(appointmentViewModelProvider.notifier)
            .getPatientAppointments(pid),
        ref.read(doctorsViewModelProvider.notifier).fetchDoctors(pid),
      ]);
      if (!mounted) return;
      _loadTopRatings(ref.read(doctorsViewModelProvider).doctors);
      final appts =
          ref
              .read(appointmentViewModelProvider)
              .patientAppointmentsList
              ?.value ??
          [];
      final now = DateTime.now();
      final liveDocIds = appts
          .where((a) {
            final s = a.status?.toLowerCase() ?? '';
            if (s != 'booked' && s != 'in_progress' && s != 'skipped') {
              return false;
            }
            if (a.bookingType != 1) return false;
            final d = DateTime.tryParse(a.appointmentDate ?? '');
            return d != null &&
                d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;
          })
          .map((a) => a.doctorId)
          .whereType<int>()
          .toSet()
          .toList();
      if (liveDocIds.isNotEmpty) {
        ref
            .read(appointmentViewModelProvider.notifier)
            .watchClinics(liveDocIds, pid);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadTopRatings(List<DoctorDetails> doctors) async {
    final rated =
        doctors
            .where(
              (d) =>
                  d.doctorId != null &&
                  (d.rating ?? 0) >= 3.5 &&
                  (d.reviewCount ?? 0) >= 3,
            )
            .toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final toFetch = rated
        .take(3)
        .where((d) => !_clinicRatings.containsKey(d.doctorId))
        .toList();
    if (toFetch.isEmpty) return;
    final reviewUsecase = ref.read(reviewUsecaseProvider);
    final apptUsecase = ref.read(appointmentUsecaseProvider);
    final results = await Future.wait(
      toFetch.map((d) async {
        final id = d.doctorId!;
        final clinicId = d.clinicId;
        try {
          final allReviews = await reviewUsecase.getDoctorReviews(
            id,
            clinicId ?? '',
          );
          if (allReviews.isEmpty) return MapEntry(id, d.rating ?? 0.0);
          var reviews = allReviews;
          if (clinicId != null && clinicId.isNotEmpty) {
            try {
              final appts = await apptUsecase.fetchPatientAppointments(
                id,
                clinicId: clinicId,
              );
              final apptIds = appts
                  .map((a) => a.appointmentId)
                  .whereType<int>()
                  .toSet();
              if (apptIds.isNotEmpty) {
                final filtered = allReviews
                    .where(
                      (r) =>
                          r.appointmentId != null &&
                          apptIds.contains(r.appointmentId),
                    )
                    .toList();
                if (filtered.isNotEmpty) reviews = filtered;
              }
            } catch (_) {
              // appointment fetch failed — keep all reviews
            }
          }
          final avg =
              reviews.fold<double>(
                0,
                (a, r) => a + (r.rating?.toDouble() ?? 0),
              ) /
              reviews.length;
          return MapEntry(id, avg);
        } catch (_) {
          return MapEntry(id, d.rating ?? 0.0);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final e in results) {
        _clinicRatings[e.key] = e.value;
      }
    });
  }

  /// Runs once per cold start. A previously saved location — whether picked
  /// manually or auto-detected on the very first run — is the source of truth
  /// on every reopen / logout-reopen: it is shown instantly and the device is
  /// NOT re-located. GPS detection happens only when nothing usable has ever
  /// been saved (true first launch), so the first-set location persists.
  Future<void> _initLocation() async {
    final isManual = await LocationStorage.isManual();
    final saved = await LocationStorage.getLocation();
    if (saved != null &&
        saved.isNotEmpty &&
        (isManual || !_isGenericLocation(saved))) {
      if (mounted) {
        setState(() {
          _location = saved;
          _locationLoaded = true;
        });
      }
      _geocodeAndStore(saved);
      return;
    }
    // First launch (or only a generic/failed value saved) → detect via GPS.
    await _ensureLocationPermission();
  }

  Future<void> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await LocationService.requestPermissionOnce();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) _showLocationSnack();
      await _detectLocation();
      return;
    }
    await _detectLocation();
  }

  /// GPS detection + auto-save. Only reached on first launch (see
  /// [_initLocation]); manual changes go through [_openLocationPicker] /
  /// "Use Current Location" instead.
  Future<void> _detectLocation() async {
    final pos = await LocationService.getCurrentPosition();
    // Reuse the fix we already have instead of asking Geolocator for a second,
    // independent GPS fix — on a first-time cold start the extra fix often
    // pushes the total wait past the timeout and the header falls back to an
    // error string instead of the real location.
    final current = pos != null
        ? await LocationService.addressFromPosition(pos)
        : await LocationService.getCurrentAddress();
    if (mounted) {
      setState(() {
        _location = current;
        _locationLoaded = true;
      });
      await LocationStorage.saveLocation(current, isManual: false);
      if (_isPermIssue(current)) _showLocationSnack();
      if (pos != null) {
        ref.read(selectedPositionProvider.notifier).state = pos;
      }
    }
  }

  /// Geocodes a city/address string to coordinates and stores in shared provider.
  Future<void> _geocodeAndStore(String address) async {
    try {
      final locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        ref.read(selectedPositionProvider.notifier).state = Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (_) {
      // Geocoding failed — nearby filter will stay at last known position
    }
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSheet(
        currentLocation: _location,
        onSelected: (loc) async {
          setState(() {
            _location = loc;
            _locationLoaded = true;
          });
          await LocationStorage.saveLocation(loc, isManual: true);
          if (_isPermIssue(loc)) _showLocationSnack();
          _geocodeAndStore(loc);
        },
      ),
    );
  }

  bool _isPermIssue(String v) {
    final s = v.toLowerCase();
    return s.contains('location disabled') || s.contains('permission');
  }

  bool _isGenericLocation(String v) {
    final s = v.trim().toLowerCase();
    if (s.contains('location ') ||
        s.contains('permission') ||
        s.contains('unknown')) {
      return true;
    }
    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(s);
  }

  void _showLocationSnack() {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWindows
              ? 'Enable Windows location services'
              : 'Enable phone location services',
        ),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  bool _isToday(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final n = DateTime.now();
    return p.year == n.year && p.month == n.month && p.day == n.day;
  }

  bool _isUpcoming(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return DateTime(p.year, p.month, p.day).isAfter(today);
  }

  // Completed / cancelled appointments must not appear in the home
  // "Upcoming Appointments" list. 'reschedule' stays (it's actionable).
  bool _isActiveAppt(AppointmentList a) {
    final s = a.status?.toLowerCase().trim() ?? '';
    return s != 'cancelled' &&
        s != 'cancled' &&
        s != 'completed' &&
        s != 'complete';
  }

  void _goToSearch({String? specialty}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSearchScreen(initialSpecialty: specialty),
      ),
    );
  }

  // Top rated doctor tap → straight to the booking screen for that doctor
  // (same as other apps; no detour through the search list).
  Future<void> _goToBook(DoctorDetails doctor) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookAppointmentScreen(doctor: doctor)),
    );
    if (ok == true && mounted) {
      _didFetch = false;
      _ensurePatientIdAndFetch();
    }
  }

  /// Confirms and cancels, then refreshes the list. Mirrors _handleCancel in
  /// the appointments screen so both surfaces behave identically.
  Future<void> _handleCancel(AppointmentList a) async {
    if (ref.read(connectivityNotifierProvider).isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No internet connection. Connect to cancel the appointment.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: kRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  size: 24,
                  color: kError,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cancel Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Are you sure you want to cancel this appointment?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        foregroundColor: kTextSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'No',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(appointmentViewModelProvider.notifier)
        .cancelAppointment(a.appointmentId!);
    if (!mounted) return;
    final id = ref.read(patientLoginViewModelProvider).patientId;
    if (id != null && id != 0) {
      ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(id);
    }
  }

  void _showTodayAppointmentPopup(AppointmentList appt) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TodayAppointmentPopup(appointment: appt),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(patientLoginViewModelProvider);
    final doctorsState = ref.watch(doctorsViewModelProvider);
    final name = loginState.name ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
        ? 'Good Afternoon 👋'
        : 'Good Evening 👋';

    // Any new booking from any screen → refresh so upcoming section is current
    // and watchClinics starts for the new clinic if it's a walk-in today.
    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      if (next.isSuccess &&
          next.bookingResponse != null &&
          next.bookingResponse != prev?.bookingResponse) {
        _didFetch = false;
        _ensurePatientIdAndFetch();
      }
    });

    return Scaffold(
      backgroundColor: kPageBg,
      body: RefreshIndicator(
        color: kPrimary,
        strokeWidth: 2,
        onRefresh: () async {
          _didFetch = false;
          await _ensurePatientIdAndFetch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(color: kPageBg),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fade(
                          0,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      style: const TextStyle(
                                        color: kTextSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: kTextPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    GestureDetector(
                                      onTap: _openLocationPicker,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: _neoBox(
                                          radius: 20,
                                          pressed: true,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              color: kPrimary,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 3),
                                            if (!_locationLoaded)
                                              _Shimmer(width: 60, height: 8)
                                            else
                                              Flexible(
                                                child: Text(
                                                  _location,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    color: kPrimary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: kPrimary,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeaderBtn(
                                icon: Icons.notifications_outlined,
                                badge: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Hero booking card ─────────────────────────────
                  _fade(1, _HeroBookCard(onTap: () => widget.onTabChange(1))),
                  const SizedBox(height: 18),

                  _fade(
                    2,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Quick Actions'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.calendar_month_rounded,
                                label: 'Appointments',
                                color: kPrimary,
                                onTap: () => widget.onTabChange(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.group_add_rounded,
                                label: 'Family',
                                color: kPurple,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FamilyMembersScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.medical_information_rounded,
                                label: 'Records',
                                color: kWarning,
                                onTap: () => widget.onTabChange(3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  _fade(3, _buildAppointmentsSection()),
                  const SizedBox(height: 10),

                  _fade(
                    4,
                    _buildSpecialtiesSection(
                      doctorsState.doctors,
                      doctorsState.isLoading,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _fade(
                    5,
                    _buildTopRatedDoctorsSection(
                      doctorsState.doctors,
                      doctorsState.isLoading,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
