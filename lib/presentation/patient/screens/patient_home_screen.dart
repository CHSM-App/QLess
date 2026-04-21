import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/screens/location_storage.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);

const kBorder = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

// ─── Sample Doctor model ──────────────────────────────────────────────────────
class Doctor {
  final String id, name, specialty, image, about, clinic, address;
  final double rating;
  final int experience, patientsAhead, reviewCount, waitMinutes;
  final bool isAvailable;
  final List<String> availableSlots;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.image,
    required this.rating,
    required this.experience,
    required this.patientsAhead,
    required this.waitMinutes,
    required this.reviewCount,
    required this.about,
    required this.clinic,
    required this.address,
    required this.isAvailable,
    required this.availableSlots,
  });
}

final List<Map<String, dynamic>> specialties = [
  {'name': 'Cardiology', 'icon': Icons.favorite_rounded, 'color': kError},
  {'name': 'Orthopedics', 'icon': Icons.accessibility_new, 'color': kInfo},
  {
    'name': 'Dermatology',
    'icon': Icons.face_retouching_natural,
    'color': kWarning,
  },
  {'name': 'Neurology', 'icon': Icons.psychology, 'color': kPurple},
  {'name': 'Pediatrics', 'icon': Icons.child_care, 'color': kSuccess},
  {'name': 'Dentistry', 'icon': Icons.medical_services, 'color': kPrimary},
  {
    'name': 'Ophthalmology',
    'icon': Icons.visibility,
    'color': Color(0xFFEC4899),
  },
  {'name': 'Gynecology', 'icon': Icons.pregnant_woman, 'color': kPrimary},
];

const List<String> _allCities = [
  'Bengaluru, IN',
  'Mumbai, IN',
  'Delhi, IN',
  'Hyderabad, IN',
  'Pune, IN',
  'Chennai, IN',
  'Kolkata, IN',
  'Ahmedabad, IN',
  'Jaipur, IN',
  'Surat, IN',
  'Lucknow, IN',
  'Kanpur, IN',
  'Nagpur, IN',
  'Indore, IN',
  'Thane, IN',
  'Bhopal, IN',
  'Visakhapatnam, IN',
  'Patna, IN',
  'Vadodara, IN',
  'Ghaziabad, IN',
  'Ludhiana, IN',
  'Agra, IN',
  'Nashik, IN',
  'Faridabad, IN',
  'Meerut, IN',
  'Rajkot, IN',
  'Varanasi, IN',
  'Srinagar, IN',
  'Aurangabad, IN',
  'Dhanbad, IN',
  'Amritsar, IN',
  'Navi Mumbai, IN',
  'Coimbatore, IN',
  'Madurai, IN',
  'Vijayawada, IN',
  'Guwahati, IN',
  'Chandigarh, IN',
  'Hubli, IN',
  'Mysuru, IN',
  'Tiruchirappalli, IN',
];

// ── Specialty → accent mapping ────────────────────────────────────────────────
Color _accentFor(String image) => switch (image) {
  'cardio' => kError,
  'ortho' => kInfo,
  'derm' => kWarning,
  'neuro' => kPurple,
  _ => kPrimary,
};

IconData _iconFor(String image) => switch (image) {
  'cardio' => Icons.favorite_rounded,
  'ortho' => Icons.accessibility_new,
  'derm' => Icons.face_retouching_natural,
  'neuro' => Icons.psychology,
  _ => Icons.local_hospital,
};

Color _bgFor(String image) => switch (image) {
  'cardio' => kRedLight,
  'ortho' => kInfoLight,
  'derm' => kAmberLight,
  'neuro' => kPurpleLight,
  _ => kPrimaryLight,
};

Widget _doctorAvatar(String image, {double size = 46}) {
  final color = _accentFor(image);
  final bg = _bgFor(image);
  final icon = _iconFor(image);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(size * 0.27),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
    ),
    child: Icon(icon, color: color, size: size * 0.44),
  );
}

// ── Shimmer ───────────────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.15,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_anim.value),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final Function(int) onTabChange;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onTabChange,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _anims;

  String _location = '';
  bool _locationLoaded = false;
  bool _didFetch = false;
  bool _isFetching = false;

  @override
  void initState() {
    super.initState();
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
    _ensureLocationPermission();
    Future.microtask(_ensurePatientIdAndFetch);
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
      await ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(pid);
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) _showLocationSnack();
      await _loadLocation();
      return;
    }
    await _loadLocation();
  }

  Future<void> _loadLocation() async {
    final isManual = await LocationStorage.isManual();
    if (isManual) {
      final saved = await LocationStorage.getLocation();
      if (saved != null && saved.isNotEmpty) {
        if (mounted)
          setState(() {
            _location = saved;
            _locationLoaded = true;
          });
        return;
      }
    }
    final saved = await LocationStorage.getLocation();
    if (saved != null && saved.isNotEmpty && !_isGenericLocation(saved)) {
      if (mounted)
        setState(() {
          _location = saved;
          _locationLoaded = true;
        });
      return;
    }
    final current = await LocationService.getCurrentAddress();
    if (mounted) {
      setState(() {
        _location = current;
        _locationLoaded = true;
      });
      await LocationStorage.saveLocation(current, isManual: false);
      if (_isPermIssue(current)) _showLocationSnack();
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
        s.contains('unknown'))
      return true;
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

  Widget _fade(int i, Widget child) => AnimatedBuilder(
    animation: _anims[i],
    builder: (_, w) => Opacity(
      opacity: _anims[i].value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _anims[i].value)),
        child: w,
      ),
    ),
    child: child,
  );

  // ---------------------------------------------------------------------------
  // Appointments section
  // ---------------------------------------------------------------------------

  Widget _buildAppointmentsSection() {
    final async = ref
        .watch(appointmentViewModelProvider)
        .patientAppointmentsList;

    if (async == null || async is AsyncLoading) {
      return _apptShell(loading: true);
    }

    return async.when(
      loading: () => _apptShell(loading: true),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        final today = list.where(_isToday).toList();
        final upcoming = list.where(_isUpcoming).toList();
        // Merge: today first, then upcoming; cap at 3
        final combined = [...today, ...upcoming];
        final shown = combined.take(3).toList();
        final hasMore = combined.length > 3;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              'Upcoming Appointments',
              action: hasMore ? 'See All' : null,
              onAction: () => widget.onTabChange(2),
            ),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              _EmptyNote("No upcoming appointments")
            else
              ...shown.map(
                (a) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApptCard(appointment: a, isToday: _isToday(a)),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _apptShell({required bool loading}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        'Upcoming Appointments',
        action: 'See All',
        onAction: () => widget.onTabChange(2),
      ),
      const SizedBox(height: 10),
      if (loading) ...[
        _ApptSkeletonCard(),
        const SizedBox(height: 8),
        _ApptSkeletonCard(),
      ],
    ],
  );
  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(patientLoginViewModelProvider);
    final name = loginState.name ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
        ? 'Good Afternoon 👋'
        : 'Good Evening 👋';

    return Scaffold(
      backgroundColor: Colors.white,
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
            // ── HEADER ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1),
                  ),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
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
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    // Location pill
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
                                        decoration: BoxDecoration(
                                          color: kPrimaryLight,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          border: Border.all(
                                            color: kPrimary.withOpacity(0.2),
                                          ),
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
                        const SizedBox(height: 14),
                        // Search bar
                        _fade(
                          1,
                          GestureDetector(
                            onTap: () => widget.onTabChange(1),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF7F8FA),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: kBorder),
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.search_rounded,
                                    color: kTextMuted,
                                    size: 17,
                                  ),
                                  SizedBox(width: 8),
                                  Text(
                                    'Search doctors or specialties…',
                                    style: TextStyle(
                                      color: kTextMuted,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── BODY ──────────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Quick Actions ──────────────────────────────────
                  _fade(
                    2,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Quick Actions'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            _QuickAction(
                              icon: Icons.calendar_month_rounded,
                              label: 'Book Appt.',
                              color: kPrimary,
                              highlighted: true,
                              onTap: () => widget.onTabChange(1),
                            ),
                            const SizedBox(width: 8),
                            _QuickAction(
                              icon: Icons.history_rounded,
                              label: 'My Appts.',
                              color: kPrimary,
                              onTap: () => widget.onTabChange(2),
                            ),
                            const SizedBox(width: 8),
                            _QuickAction(
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
                            const SizedBox(width: 8),
                            _QuickAction(
                              icon: Icons.medical_information_rounded,
                              label: 'Records',
                              color: kWarning,
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      const PatientPrescriptionListScreen(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Appointments ───────────────────────────────────
                  _fade(3, _buildAppointmentsSection()),
                  const SizedBox(height: 22),

                  // ── Specialties ────────────────────────────────────
                  _fade(
                    4,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Most Searched Specialties'),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 96,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const BouncingScrollPhysics(),
                            itemCount: specialties.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (_, i) {
                              final s = specialties[i];
                              return _SpecialtyChip(
                                icon: s['icon'],
                                label: s['name'],
                                color: s['color'] as Color,
                                onTap: () {},
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // ── Top Doctors ────────────────────────────────────
                  _fade(
                    5,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle(
                          'Top Rated Doctors',
                          action: 'View All',
                          onAction: () => widget.onTabChange(1),
                        ),
                        const SizedBox(height: 10),
                      ],
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

// ════════════════════════════════════════════════════════════════════
//  LOCATION SHEET
// ════════════════════════════════════════════════════════════════════
class _LocationSheet extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<String> onSelected;
  const _LocationSheet({
    required this.currentLocation,
    required this.onSelected,
  });

  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  List<String> _suggestions = _allCities;
  bool _isLoadingGPS = false;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onType);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onType);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onType() {
    final q = _ctrl.text.trim().toLowerCase();
    setState(() {
      _suggestions = q.isEmpty
          ? _allCities
          : _allCities.where((c) => c.toLowerCase().contains(q)).toList();
    });
  }

  void _pick(String loc) {
    widget.onSelected(loc);
    Navigator.pop(context);
  }

  Future<void> _useGPS() async {
    setState(() => _isLoadingGPS = true);
    try {
      final current = await LocationService.getCurrentAddress();
      if (!mounted) return;
      final lower = current.toLowerCase();
      final hasIssue =
          lower.contains('location disabled') || lower.contains('permission');
      widget.onSelected(current);
      if (!hasIssue) {
        await LocationStorage.saveLocation(current, isManual: false);
        Navigator.pop(context);
      } else {
        setState(() => _isLoadingGPS = false);
        _snack();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingGPS = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect location')),
      );
    }
  }

  void _snack() {
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
          label: 'Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: kPrimary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                        if (widget.currentLocation.isNotEmpty)
                          Text(
                            'Current: ${widget.currentLocation}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Search
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: kTextPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search city…',
                    hintStyle: const TextStyle(
                      // hint text:
                      color: kTextMuted,
                      fontSize: 13,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: kTextMuted,
                      size: 17,
                    ),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              _focus.requestFocus();
                            },
                            child: const Icon(
                              Icons.clear_rounded,
                              color: kTextMuted,
                              size: 15,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                  onSubmitted: (val) {
                    final v = val.trim();
                    if (v.isEmpty) return;
                    _pick(_suggestions.isNotEmpty ? _suggestions.first : v);
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // GPS button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isLoadingGPS ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoadingGPS
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingGPS
                                  ? 'Detecting…'
                                  : 'Use Current Location',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                            const Text(
                              'Auto-detect via GPS',
                              style: TextStyle(fontSize: 10, color: kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoadingGPS)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kPrimary,
                          size: 17,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Clear saved
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await LocationStorage.clearLocation();
                  if (!mounted) return;
                  widget.onSelected('');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location cache cleared')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Clear Saved Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Divider label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      _ctrl.text.isEmpty ? 'POPULAR CITIES' : 'RESULTS',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // City list
            Flexible(
              child: _suggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(
                            Icons.search_off_rounded,
                            size: 28,
                            color: kTextMuted,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No cities found',
                            style: TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final loc = _suggestions[i];
                        final isActive = loc == widget.currentLocation;
                        return GestureDetector(
                          onTap: () => _pick(loc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? kPrimary
                                        : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.location_on_rounded
                                        : Icons.location_city_rounded,
                                    color: isActive ? Colors.white : kTextMuted,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive ? kPrimary : kTextPrimary,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: kBorder,
                                    size: 15,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// // ════════════════════════════════════════════════════════════════════
// //  HEADER BUTTON
// // ════════════════════════════════════════════════════════════════════
// class _HeaderBtn extends StatelessWidget {
//   final IconData icon;
//   final VoidCallback onTap;
//   final bool badge;
//   const _HeaderBtn(
//       {required this.icon, required this.onTap, this.badge = false});

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//         onTap: onTap,
//         child: Stack(children: [
//           Container(
//             width: 36, height: 36,
//             decoration: BoxDecoration(
//               color: Colors.white.withOpacity(0.18),
//               borderRadius: BorderRadius.circular(10),
//             ),
//             child: Icon(icon, color: Colors.white, size: 17),
//           ),
//           if (badge)
//             Positioned(
//               right: 7, top: 7,
//               child: Container(
//                 width: 7, height: 7,
//                 decoration: const BoxDecoration(
//                     color: kWarning, shape: BoxShape.circle),
//               ),
//             ),
//         ]),
//       );
// }
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Stack(
      children: [
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
              decoration: const BoxDecoration(
                color: kWarning,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  SECTION TITLE
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
          color: kTextPrimary,
        ),
      ),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
        ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════
//  QUICK ACTION
// ════════════════════════════════════════════════════════════════════
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool highlighted;
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          gradient: highlighted
              ? const LinearGradient(
                  colors: [kPrimary, kPrimaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: highlighted ? null : color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: highlighted ? kPrimaryDark : color.withOpacity(0.15),
          ),
          boxShadow: highlighted
              ? [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: highlighted
                    ? Colors.white.withOpacity(0.2)
                    : color,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon,
                  color: highlighted ? Colors.white : Colors.white, size: 17),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.3,
                color: highlighted ? Colors.white : kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY NOTE
// ════════════════════════════════════════════════════════════════════
class _EmptyNote extends StatelessWidget {
  final String message;
  const _EmptyNote(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: kPrimaryLight.withOpacity(0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kPrimary.withOpacity(0.15)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_today_rounded, size: 13, color: kPrimary),
        const SizedBox(width: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: kTextSecondary),
        ),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD
// ════════════════════════════════════════════════════════════════════
class _ApptCard extends StatelessWidget {
  final AppointmentList appointment;
  final bool isToday;
  const _ApptCard({required this.appointment, this.isToday = false});

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : DateFormat('d MMM yyyy').format(dt);
  }

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final dt = DateTime(
      2000,
      1,
      1,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final name = appointment.doctorName ?? 'Doctor';
    final spec = appointment.specialization ?? '';
    final dateStr = _fmtDate(appointment.appointmentDate);
    final timeStr = _fmtTime(appointment.startTime);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          _doctorAvatar('cardio', size: 42),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  spec,
                  style: const TextStyle(fontSize: 11, color: kTextSecondary),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today_rounded,
                      size: 10,
                      color: kPrimary,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      dateStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.access_time_rounded,
                      size: 10,
                      color: kPrimaryDark,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      timeStr,
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kPrimaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isToday)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Text(
                'Today',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 76,
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  DOCTOR CARD
// ════════════════════════════════════════════════════════════════════
class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = _accentFor(doctor.image);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _doctorAvatar(doctor.image, size: 50),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        doctor.name,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                        ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.star_rounded,
                          color: kWarning,
                          size: 12,
                        ),
                        const SizedBox(width: 2),
                        Text(
                          doctor.rating.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: kWarning,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  doctor.specialty,
                  style: TextStyle(
                    fontSize: 11,
                    color: ac,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Wrap(
                  spacing: 4,
                  runSpacing: 3,
                  children: [
                    _InfoTag(
                      icon: Icons.work_history_rounded,
                      label: '${doctor.experience}yr',
                      color: kSuccess,
                    ),
                    _InfoTag(
                      icon: Icons.people_rounded,
                      label: '${doctor.patientsAhead} ahead',
                      color: kWarning,
                    ),
                    _InfoTag(
                      icon: Icons.timer_rounded,
                      label: '~${doctor.waitMinutes}min',
                      color: kPurple,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: const BorderSide(color: kPrimary),
                          foregroundColor: kPrimary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Profile',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text(
                          'Book Now',
                          style: TextStyle(
                            fontSize: 11,
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
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  INFO TAG
// ════════════════════════════════════════════════════════════════════
class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoTag({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(6),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _ApptSkeletonCard extends StatefulWidget {
  const _ApptSkeletonCard();
  @override
  State<_ApptSkeletonCard> createState() => _ApptSkeletonCardState();
}

class _ApptSkeletonCardState extends State<_ApptSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar({double? width, required double height}) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFFEDF2F7),
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E0),
            Color(0xFFE2E8F0),
            Color(0xFFEDF2F7),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            // Avatar skeleton
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(11),
                gradient: LinearGradient(
                  begin: Alignment(_anim.value - 1, 0),
                  end: Alignment(_anim.value + 1, 0),
                  colors: const [
                    Color(0xFFEDF2F7),
                    Color(0xFFCBD5E0),
                    Color(0xFFEDF2F7),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Text skeleton
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bar(width: 130, height: 13), // doctor name
                  _bar(width: 90, height: 10), // specialty
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      _bar(width: 70, height: 10), // date
                      const SizedBox(width: 8),
                      _bar(width: 55, height: 10), // time
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
