import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/theme/patient_theme.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/screens/location_storage.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';

class Doctor {
  final String id, name, specialty, image, about, clinic, address;
  final double rating;
  final int experience, patientsAhead, reviewCount;
  final int waitMinutes;
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

// ─── SAMPLE DATA ─────────────────────────────────────────────────────────────

final List<Doctor> sampleDoctors = [
  Doctor(
    id: '1',
    name: 'Dr. Anika Sharma',
    specialty: 'Cardiologist',
    image: 'cardio',
    rating: 4.9,
    experience: 12,
    patientsAhead: 3,
    waitMinutes: 25,
    reviewCount: 248,
    about:
        'Dr. Anika Sharma is a leading Cardiologist with 12 years of experience. She specializes in preventive cardiology, heart failure management, and echocardiography.',
    clinic: 'Apollo Heart Center',
    address: '14 MG Road, Bangalore – 560001',
    isAvailable: true,
    availableSlots: ['9:00 AM', '9:30 AM', '10:00 AM', '11:30 AM', '2:00 PM', '3:00 PM'],
  ),
  Doctor(
    id: '2',
    name: 'Dr. Rajesh Kumar',
    specialty: 'Orthopedist',
    image: 'ortho',
    rating: 4.7,
    experience: 8,
    patientsAhead: 1,
    waitMinutes: 10,
    reviewCount: 183,
    about:
        'Dr. Rajesh Kumar specializes in joint replacement, sports injuries, and spine surgery with 8 years of clinical practice.',
    clinic: 'Fortis Bone & Joint Clinic',
    address: '22 Nehru Place, New Delhi – 110019',
    isAvailable: true,
    availableSlots: ['10:00 AM', '10:30 AM', '11:00 AM', '4:00 PM', '4:30 PM'],
  ),
  Doctor(
    id: '3',
    name: 'Dr. Priya Nair',
    specialty: 'Dermatologist',
    image: 'derm',
    rating: 4.8,
    experience: 6,
    patientsAhead: 5,
    waitMinutes: 40,
    reviewCount: 312,
    about:
        'Dr. Priya Nair is a board-certified Dermatologist focusing on cosmetic dermatology, acne treatment, and skin cancer screening.',
    clinic: 'Skin Studio Clinic',
    address: 'Plot 7, Jubilee Hills, Hyderabad – 500033',
    isAvailable: true,
    availableSlots: ['11:00 AM', '11:30 AM', '12:00 PM', '5:00 PM', '5:30 PM'],
  ),
  Doctor(
    id: '4',
    name: 'Dr. Mohan Verma',
    specialty: 'Neurologist',
    image: 'neuro',
    rating: 4.6,
    experience: 15,
    patientsAhead: 0,
    waitMinutes: 5,
    reviewCount: 97,
    about:
        'Dr. Mohan Verma is a senior Neurologist specializing in epilepsy, stroke, and neurodegenerative disorders with 15 years of expertise.',
    clinic: 'NeuroLife Institute',
    address: '3 Park Street, Kolkata – 700016',
    isAvailable: true,
    availableSlots: ['9:00 AM', '9:30 AM', '3:00 PM', '3:30 PM', '4:00 PM'],
  ),
];

// ─── SPECIALTY DATA ───────────────────────────────────────────────────────────

final List<Map<String, dynamic>> specialties = [
  {'name': 'Cardiology',    'icon': Icons.favorite_rounded,        'color': 0xFFEF4444},
  {'name': 'Orthopedics',   'icon': Icons.accessibility_new,       'color': 0xFF3B82F6},
  {'name': 'Dermatology',   'icon': Icons.face_retouching_natural, 'color': 0xFFF59E0B},
  {'name': 'Neurology',     'icon': Icons.psychology,              'color': 0xFF8B5CF6},
  {'name': 'Pediatrics',    'icon': Icons.child_care,              'color': 0xFF10B981},
  {'name': 'Dentistry',     'icon': Icons.medical_services,        'color': 0xFF06B6D4},
  {'name': 'Ophthalmology', 'icon': Icons.visibility,              'color': 0xFFEC4899},
  {'name': 'Gynecology',    'icon': Icons.pregnant_woman,          'color': 0xFF14B8A6},
];

// ─── CITY SEARCH DATA ─────────────────────────────────────────────────────────

const List<String> _allCities = [
  'Bengaluru, IN', 'Mumbai, IN',       'Delhi, IN',       'Hyderabad, IN',
  'Pune, IN',      'Chennai, IN',      'Kolkata, IN',     'Ahmedabad, IN',
  'Jaipur, IN',    'Surat, IN',        'Lucknow, IN',     'Kanpur, IN',
  'Nagpur, IN',    'Indore, IN',       'Thane, IN',       'Bhopal, IN',
  'Visakhapatnam, IN', 'Patna, IN',   'Vadodara, IN',    'Ghaziabad, IN',
  'Ludhiana, IN',  'Agra, IN',        'Nashik, IN',      'Faridabad, IN',
  'Meerut, IN',    'Rajkot, IN',      'Varanasi, IN',    'Srinagar, IN',
  'Aurangabad, IN','Dhanbad, IN',     'Amritsar, IN',    'Navi Mumbai, IN',
  'Coimbatore, IN','Madurai, IN',     'Vijayawada, IN',  'Guwahati, IN',
  'Chandigarh, IN','Hubli, IN',       'Mysuru, IN',      'Tiruchirappalli, IN',
];

// ─── HELPERS ─────────────────────────────────────────────────────────────────

Color _doctorColor(String image) {
  switch (image) {
    case 'cardio': return const Color(0xFFEF4444);
    case 'ortho':  return const Color(0xFF3B82F6);
    case 'derm':   return const Color(0xFFF59E0B);
    case 'neuro':  return const Color(0xFF8B5CF6);
    default:       return const Color(0xFF00BFA5);
  }
}

IconData _doctorIcon(String image) {
  switch (image) {
    case 'cardio': return Icons.favorite_rounded;
    case 'ortho':  return Icons.accessibility_new;
    case 'derm':   return Icons.face_retouching_natural;
    case 'neuro':  return Icons.psychology;
    default:       return Icons.local_hospital;
  }
}

Widget _doctorAvatar(String image, {double size = 48}) {
  final color = _doctorColor(image);
  final icon  = _doctorIcon(image);
  return Container(
    width: size, height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.8), color],
        begin: Alignment.topLeft, end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.48),
  );
}

// ─── SHIMMER BOX ─────────────────────────────────────────────────────────────

class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  const _ShimmerBox({required this.width, required this.height});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.2, end: 0.6).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: widget.width, height: widget.height,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(_anim.value),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      );
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

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
  late List<Animation<double>> _itemAnims;

  String _location = '';
  bool   _locationLoaded = false;
  bool   _didFetch       = false;
  bool   _isFetching     = false;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 900));
    _itemAnims = List.generate(6, (i) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(i * 0.1, 0.6 + i * 0.07, curve: Curves.easeOut),
      ),
    ));
    _animCtrl.forward();
    _ensureLocationPermission();
    Future.microtask(_ensurePatientIdAndFetch);
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_isFetching || _didFetch) return;
    _isFetching = true;
    try {
      final loginNotifier = ref.read(patientLoginViewModelProvider.notifier);
      var patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (patientId == 0) {
        await loginNotifier.loadFromStoragePatient();
        patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      }
      if (patientId == 0) return;
      _didFetch = true;
      await ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(patientId);
    } finally {
      _isFetching = false;
    }
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _ensureLocationPermission() async {
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showLocationSettingsSnack();
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
        if (mounted) setState(() { _location = saved; _locationLoaded = true; });
        return;
      }
    }
    final saved = await LocationStorage.getLocation();
    if (saved != null && saved.isNotEmpty && !_isGenericLocation(saved)) {
      if (mounted) setState(() { _location = saved; _locationLoaded = true; });
      return;
    }
    final current = await LocationService.getCurrentAddress();
    if (mounted) {
      setState(() { _location = current; _locationLoaded = true; });
      await LocationStorage.saveLocation(current, isManual: false);
      if (_isPermissionIssue(current)) {
        _showLocationSettingsSnack();
      }
    }
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationPickerSheet(
        isDark: Theme.of(context).brightness == Brightness.dark,
        currentLocation: _location,
        onLocationSelected: (loc) async {
          setState(() { _location = loc; _locationLoaded = true; });
          await LocationStorage.saveLocation(loc, isManual: true);
          if (_isPermissionIssue(loc)) {
            _showLocationSettingsSnack();
          }
        },
      ),
    );
  }

  bool _isPermissionIssue(String value) {
    final v = value.toLowerCase();
    return v.contains('location disabled') ||
        v.contains('permission denied') ||
        v.contains('permission permanently denied') ||
        v.contains('permission unavailable');
  }

  void _showLocationSettingsSnack() {
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final message = isWindows
        ? 'Enable Windows location services to detect location'
        : 'Enable phone location services to detect location';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () {
            Geolocator.openLocationSettings();
          },
        ),
      ),
    );
  }

  bool _isGenericLocation(String value) {
    final v = value.trim().toLowerCase();
    if (v.contains('location ') ||
        v.contains('permission') ||
        v.contains('unknown')) {
      return true;
    }
    final coordRegex = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');
    return coordRegex.hasMatch(v);
  }

  bool _isToday(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final now = DateTime.now();
    return p.year == now.year && p.month == now.month && p.day == now.day;
  }

  bool _isUpcoming(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return DateTime(p.year, p.month, p.day).isAfter(today);
  }

  Widget _buildAppointmentsSection() {
    final asyncAppts = ref.watch(appointmentViewModelProvider).patientAppointmentsList;

    return asyncAppts == null || asyncAppts is AsyncLoading
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionTitle('Today\'s Appointments',
                  action: 'See All', onAction: () => widget.onTabChange(2)),
              const SizedBox(height: 12),
              const Center(child: CircularProgressIndicator()),
            ],
          )
        : asyncAppts.when(
            loading: () => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SectionTitle('Today\'s Appointments',
                    action: 'See All', onAction: () => widget.onTabChange(2)),
                const SizedBox(height: 12),
                const Center(child: CircularProgressIndicator()),
              ],
            ),
            error: (_, __) => const SizedBox.shrink(),
            data: (list) {
              final todayList    = list.where(_isToday).toList();
              final upcomingList = list.where(_isUpcoming).toList();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Today\'s Appointments',
                      action: 'See All', onAction: () => widget.onTabChange(2)),
                  const SizedBox(height: 12),
                  if (todayList.isEmpty)
                    _EmptyAppointmentNote('No appointments today')
                  else
                    ...todayList.map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ApiAppointmentCard(appointment: a),
                        )),
                  const SizedBox(height: 18),
                  _SectionTitle('Upcoming Appointments',
                      action: 'See All', onAction: () => widget.onTabChange(2)),
                  const SizedBox(height: 12),
                  if (upcomingList.isEmpty)
                    _EmptyAppointmentNote('No upcoming appointments')
                  else
                    ...upcomingList.take(3).map((a) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _ApiAppointmentCard(appointment: a),
                        )),
                ],
              );
            },
          );
  }

  Widget _anim(int idx, Widget child) => AnimatedBuilder(
        animation: _itemAnims[idx],
        builder: (_, w) => Opacity(
          opacity: _itemAnims[idx].value,
          child: Transform.translate(
              offset: Offset(0, 16 * (1 - _itemAnims[idx].value)), child: w),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.white,
      body: CustomScrollView(
        slivers: [
          // ── HEADER ────────────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  // ── Q UP teal gradient (was blue)
                  colors: isDark
                      ? [const Color(0xFF0D2B27), const Color(0xFF071A17)]
                      : [const Color(0xFF00BFA5), const Color(0xFF008C7A)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft:  Radius.circular(28),
                  bottomRight: Radius.circular(28),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _anim(0, Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good Morning 👋',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    )),
                                const SizedBox(height: 2),
                                const Text('Arjun Mehta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                    )),
                                const SizedBox(height: 4),
                                // Location pill
                                GestureDetector(
                                  onTap: _openLocationPicker,
                                  child: Container(
                                    constraints: const BoxConstraints(maxWidth: 140),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.18),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                          color: Colors.white.withOpacity(0.3)),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(Icons.location_on_rounded,
                                            color: Colors.white, size: 11),
                                        const SizedBox(width: 3),
                                        if (!_locationLoaded)
                                          _ShimmerBox(width: 64, height: 9)
                                        else
                                          Flexible(
                                            child: Text(_location,
                                                overflow: TextOverflow.ellipsis,
                                                maxLines: 1,
                                                style: TextStyle(
                                                  color: Colors.white.withOpacity(0.95),
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w600,
                                                )),
                                          ),
                                        const SizedBox(width: 2),
                                        const Icon(Icons.keyboard_arrow_down,
                                            color: Colors.white, size: 13),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          _HeaderBtn(
                            icon: widget.themeMode == ThemeMode.dark
                                ? Icons.light_mode_rounded
                                : Icons.dark_mode_rounded,
                            onTap: widget.onToggleTheme,
                          ),
                          const SizedBox(width: 8),
                          _HeaderBtn(
                            icon: Icons.notifications_outlined,
                            badge: true,
                            onTap: () => Navigator.push(context,
                                MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen())),
                          ),
                        ],
                      )),

                      const SizedBox(height: 16),

                      // Search bar
                      _anim(1, GestureDetector(
                        onTap: () => widget.onTabChange(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 11),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Row(children: [
                            Icon(Icons.search_rounded,
                                color: Colors.white.withOpacity(0.8), size: 18),
                            const SizedBox(width: 8),
                            Text('Search doctors or specialties…',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 13)),
                          ]),
                        ),
                      )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BODY ──────────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Quick Actions
                _anim(2, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Quick Actions'),
                    const SizedBox(height: 12),
                    Row(children: [
                      // ── Q UP teal for the first two quick actions (was blue / teal)
                      _QuickAction(icon: Icons.calendar_month_rounded, label: 'Book\nAppt.',  color: const Color(0xFF00BFA5), onTap: () => widget.onTabChange(1)),
                      const SizedBox(width: 8),
                      _QuickAction(icon: Icons.history_rounded,         label: 'My\nAppts.', color: const Color(0xFF00BFA5), onTap: () => widget.onTabChange(2)),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.group_add_rounded,
                        label: 'Add\nFamily',
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const FamilyMembersScreen()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _QuickAction(
                        icon: Icons.medical_information_rounded,
                        label: 'My\nRecords',
                        color: const Color(0xFFF59E0B),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const PatientPrescriptionListScreen()),
                        ),
                      ),
                    ]),
                  ],
                )),
                const SizedBox(height: 24),

                // Today & Upcoming Appointments
                _anim(3, _buildAppointmentsSection()),
                const SizedBox(height: 24),

                // Specialties
                _anim(4, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Most Searched Specialties'),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 100,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: specialties.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (_, i) {
                          final s = specialties[i];
                          return _SpecialtyChip(
                            icon: s['icon'], label: s['name'],
                            color: Color(s['color']), onTap: () {},
                          );
                        },
                      ),
                    ),
                  ],
                )),
                const SizedBox(height: 24),

                // Top Doctors
                _anim(5, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Top Rated Doctors',
                        action: 'View All', onAction: () => widget.onTabChange(1)),
                    const SizedBox(height: 12),
                    ...sampleDoctors.take(2).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _DoctorCard(doctor: d, onTap: () {}),
                        )),
                  ],
                )),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── LOCATION PICKER SHEET ───────────────────────────────────────────────────

class _LocationPickerSheet extends StatefulWidget {
  final bool isDark;
  final String currentLocation;
  final ValueChanged<String> onLocationSelected;

  const _LocationPickerSheet({
    required this.isDark,
    required this.currentLocation,
    required this.onLocationSelected,
  });

  @override
  State<_LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<_LocationPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<String> _suggestions = _allCities;
  bool _isLoadingGPS = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_onType);
  }

  @override
  void dispose() {
    _searchCtrl.removeListener(_onType);
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onType() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _suggestions = q.isEmpty
          ? _allCities
          : _allCities.where((c) => c.toLowerCase().contains(q)).toList();
    });
  }

  void _pick(String loc) {
    widget.onLocationSelected(loc);
    Navigator.pop(context);
  }

  Future<void> _useGPS() async {
    setState(() => _isLoadingGPS = true);
    try {
      final current = await LocationService.getCurrentAddress();
      if (mounted) {
        widget.onLocationSelected(current);
        final lower = current.toLowerCase();
        final permissionIssue = lower.contains('location disabled') ||
            lower.contains('permission denied') ||
            lower.contains('permission permanently denied') ||
            lower.contains('permission unavailable');
        if (!permissionIssue) {
          await LocationStorage.saveLocation(current, isManual: false);
          Navigator.pop(context);
        } else {
          setState(() => _isLoadingGPS = false);
          _showLocationSettingsSnack();
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingGPS = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect location')),
      );
    }
  }

  void _showLocationSettingsSnack() {
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    final message = isWindows
        ? 'Enable Windows location services to detect location'
        : 'Enable phone location services to detect location';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = widget.isDark;
    // ── Q UP teal-tinted surfaces (was slate/navy)
    final bg        = isDark ? const Color(0xFF0A1F1C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF1A2B4A);
    final sub       = isDark ? Colors.white38 : Colors.grey.shade400;
    final tileBg    = isDark ? const Color(0xFF142E29) : const Color(0xFFF0FAF8);
    final divColor  = isDark ? Colors.white10 : const Color(0xFFE0F5F2);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 24, offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [

            const SizedBox(height: 10),
            Container(
              width: 32, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      // ── Q UP teal gradient (was blue)
                      gradient: const LinearGradient(
                          colors: [Color(0xFF00BFA5), Color(0xFF008C7A)]),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose Location',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w700,
                                color: textColor)),
                        if (widget.currentLocation.isNotEmpty)
                          Text('Current: ${widget.currentLocation}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11, color: sub)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28, height: 28,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : const Color(0xFFF0FAF8),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.close_rounded, size: 16, color: sub),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFD0EDE9)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                      color: textColor,
                      fontSize: 13, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search city…',
                    hintStyle: TextStyle(
                        color: sub,
                        fontSize: 13, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search_rounded, color: sub, size: 18),
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _focusNode.requestFocus();
                            },
                            child: Icon(Icons.clear_rounded, color: sub, size: 16),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 11),
                  ),
                  onSubmitted: (val) {
                    final v = val.trim();
                    if (v.isEmpty) return;
                    if (_suggestions.isNotEmpty) {
                      _pick(_suggestions.first);
                    } else {
                      _pick(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 10),

            // GPS button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isLoadingGPS ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      // ── Q UP teal gradient (was blue/teal)
                      colors: isDark
                          ? [const Color(0xFF00BFA5).withOpacity(0.18),
                             const Color(0xFF008C7A).withOpacity(0.18)]
                          : [const Color(0xFF00BFA5).withOpacity(0.08),
                             const Color(0xFF008C7A).withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: const Color(0xFF00BFA5).withOpacity(0.3),
                        width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        // ── Q UP teal gradient (was blue/teal)
                        gradient: const LinearGradient(
                            colors: [Color(0xFF00BFA5), Color(0xFF008C7A)]),
                        borderRadius: BorderRadius.circular(9),
                      ),
                      child: _isLoadingGPS
                          ? const Padding(
                              padding: EdgeInsets.all(7),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location_rounded,
                              color: Colors.white, size: 16),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoadingGPS ? 'Detecting…' : 'Use Current Location',
                            style: TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: textColor),
                          ),
                          Text('Auto-detect via GPS',
                              style: TextStyle(
                                  fontSize: 10, color: sub)),
                        ],
                      ),
                    ),
                    if (!_isLoadingGPS)
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF00BFA5), size: 18), // Q UP teal
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Clear saved location
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await LocationStorage.clearLocation();
                  if (!mounted) return;
                  widget.onLocationSelected('');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location cache cleared')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF0FAF8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: divColor),
                  ),
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded, size: 16, color: sub),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Clear Saved Location',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Divider label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                Expanded(child: Divider(color: divColor, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    _searchCtrl.text.isEmpty ? 'POPULAR CITIES' : 'RESULTS',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1.1, color: sub),
                  ),
                ),
                Expanded(child: Divider(color: divColor, thickness: 1)),
              ]),
            ),
            const SizedBox(height: 4),

            // City list
            Flexible(
              child: _suggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 30, color: sub),
                        const SizedBox(height: 6),
                        Text('No cities found',
                            style: TextStyle(
                                color: sub, fontSize: 12)),
                      ]),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: divColor, height: 1),
                      itemBuilder: (_, i) {
                        final loc      = _suggestions[i];
                        final isActive = loc == widget.currentLocation;
                        return GestureDetector(
                          onTap: () => _pick(loc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF00BFA5) // Q UP teal
                                      : tileBg,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.location_on_rounded
                                      : Icons.location_city_rounded,
                                  color: isActive ? Colors.white : sub,
                                  size: 15,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(loc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive
                                          ? const Color(0xFF00BFA5) // Q UP teal
                                          : textColor,
                                    )),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF00BFA5).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: const Text('Active',
                                      style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF00BFA5))), // Q UP teal
                                )
                              else
                                Icon(Icons.chevron_right_rounded,
                                    color: divColor, size: 16),
                            ]),
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

// ─── HEADER BUTTON ───────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn({required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          if (badge)
            Positioned(
              right: 7, top: 7,
              child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: Color(0xFFF59E0B), shape: BoxShape.circle),
              ),
            ),
        ]),
      );
}

// ─── SECTION TITLE ───────────────────────────────────────────────────────────

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: TextStyle(
              fontSize: 15, fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            )),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Color(0xFF00BFA5))), // Q UP teal
          ),
      ],
    );
  }
}

// ─── QUICK ACTION ────────────────────────────────────────────────────────────

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon, required this.label,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(10)),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700, height: 1.3,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─── EMPTY NOTE ──────────────────────────────────────────────────────────────

class _EmptyAppointmentNote extends StatelessWidget {
  final String message;
  const _EmptyAppointmentNote(this.message);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
      decoration: BoxDecoration(
        // ── Q UP teal-tinted empty state (was slate)
        color: isDark ? const Color(0xFF142E29) : const Color(0xFFF0FAF8),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_rounded,
              size: 14,
              color: isDark ? Colors.white38 : Colors.grey.shade400),
          const SizedBox(width: 6),
          Text(message,
              style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white38 : Colors.grey.shade500)),
        ],
      ),
    );
  }
}

// ─── API APPOINTMENT CARD ────────────────────────────────────────────────────

class _ApiAppointmentCard extends StatelessWidget {
  final AppointmentList appointment;
  const _ApiAppointmentCard({required this.appointment});

  String _formatDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    if (dt == null) return raw;
    return DateFormat('d MMM yyyy').format(dt);
  }

  String _formatTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final h = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    final dt = DateTime(2000, 1, 1, h, m);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final doctorName = appointment.doctorName ?? 'Doctor';
    final specialty  = appointment.specialization ?? '';
    final dateStr    = _formatDate(appointment.appointmentDate);
    final timeStr    = _formatTime(appointment.startTime);
    final isToday = () {
      final p = DateTime.tryParse(appointment.appointmentDate ?? '');
      if (p == null) return false;
      final now = DateTime.now();
      return p.year == now.year && p.month == now.month && p.day == now.day;
    }();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          // ── Q UP teal gradient (was blue)
          const Color(0xFF00BFA5).withOpacity(isDark ? 0.22 : 0.07),
          const Color(0xFF008C7A).withOpacity(isDark ? 0.22 : 0.07),
        ]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
            color: const Color(0xFF00BFA5).withOpacity(0.2), width: 1.2),
      ),
      child: Row(children: [
        _doctorAvatar('cardio', size: 44),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doctorName,
                  style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(specialty,
                  style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white54 : AppTheme.textSecondary)),
              const SizedBox(height: 6),
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 11, color: Color(0xFF00BFA5)), // Q UP teal
                const SizedBox(width: 3),
                Flexible(
                  child: Text(dateStr,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, fontWeight: FontWeight.w600,
                          color: Color(0xFF00BFA5))), // Q UP teal
                ),
                const SizedBox(width: 8),
                const Icon(Icons.access_time_rounded,
                    size: 11, color: Color(0xFF008C7A)), // Q UP teal dark
                const SizedBox(width: 3),
                Text(timeStr,
                    style: const TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w600,
                        color: Color(0xFF008C7A))), // Q UP teal dark
              ]),
            ],
          ),
        ),
        const SizedBox(width: 6),
        if (isToday)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
            decoration: BoxDecoration(
                color: const Color(0xFF00BFA5), // Q UP teal
                borderRadius: BorderRadius.circular(8)),
            child: const Text('Today',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700)),
          ),
      ]),
    );
  }
}

// ─── SPECIALTY CHIP ──────────────────────────────────────────────────────────

class _SpecialtyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyChip(
      {required this.icon, required this.label,
       required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 80,
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 8, fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white70 : AppTheme.textPrimary,
                  )),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DOCTOR CARD ─────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          // ── Q UP teal-tinted dark card (was slate)
          color: isDark ? const Color(0xFF142E29) : Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.18 : 0.05),
              blurRadius: 10, offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _doctorAvatar(doctor.image, size: 54),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(doctor.name,
                          style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          )),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 13),
                      const SizedBox(width: 2),
                      Text(doctor.rating.toString(),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B))),
                    ]),
                  ]),
                  const SizedBox(height: 2),
                  Text(doctor.specialty,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF00BFA5), // Q UP teal
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 5),
                  Wrap(spacing: 4, runSpacing: 3, children: [
                    _InfoTag(icon: Icons.work_history_rounded,
                        label: '${doctor.experience}yr',
                        color: const Color(0xFF10B981)),
                    _InfoTag(icon: Icons.people_rounded,
                        label: '${doctor.patientsAhead} ahead',
                        color: const Color(0xFFF59E0B)),
                    _InfoTag(icon: Icons.timer_rounded,
                        label: '~${doctor.waitMinutes}min',
                        color: const Color(0xFF6366F1)),
                  ]),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          side: const BorderSide(color: Color(0xFF00BFA5)), // Q UP teal
                          foregroundColor: const Color(0xFF00BFA5),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: const Text('View Profile',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          backgroundColor: const Color(0xFF00BFA5), // Q UP teal
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(9)),
                        ),
                        child: const Text('Book Now',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── INFO TAG ────────────────────────────────────────────────────────────────

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoTag({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10, color: color),
        const SizedBox(width: 2),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
