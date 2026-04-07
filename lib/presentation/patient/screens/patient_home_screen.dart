import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:qless/core/theme/patient_theme.dart';
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

class Appointment {
  final String id, doctorName, specialty, date, time, status;
  final String doctorImage;
  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.status,
    required this.doctorImage,
  });
}

class FamilyMember {
  String name, relation, bloodGroup, gender;
  int age;
  FamilyMember({
    required this.name,
    required this.relation,
    required this.age,
    required this.gender,
    required this.bloodGroup,
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

final List<Appointment> sampleAppointments = [
  Appointment(
    id: '1',
    doctorName: 'Dr. Anika Sharma',
    specialty: 'Cardiologist',
    date: 'Tomorrow, 28 Mar',
    time: '10:00 AM',
    status: 'Upcoming',
    doctorImage: 'cardio',
  ),
  Appointment(
    id: '2',
    doctorName: 'Dr. Priya Nair',
    specialty: 'Dermatologist',
    date: '2 Apr 2025',
    time: '11:30 AM',
    status: 'Upcoming',
    doctorImage: 'derm',
  ),
  Appointment(
    id: '3',
    doctorName: 'Dr. Rajesh Kumar',
    specialty: 'Orthopedist',
    date: '15 Mar 2025',
    time: '9:00 AM',
    status: 'Completed',
    doctorImage: 'ortho',
  ),
  Appointment(
    id: '4',
    doctorName: 'Dr. Mohan Verma',
    specialty: 'Neurologist',
    date: '5 Mar 2025',
    time: '4:00 PM',
    status: 'Cancelled',
    doctorImage: 'neuro',
  ),
];

final List<FamilyMember> sampleFamily = [
  FamilyMember(name: 'Ravi Mehta', relation: 'Father', age: 62, gender: 'Male', bloodGroup: 'B+'),
  FamilyMember(name: 'Sunita Mehta', relation: 'Mother', age: 58, gender: 'Female', bloodGroup: 'O+'),
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
    default:       return AppTheme.primary;
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

Widget _doctorAvatar(String image, {double size = 56}) {
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
    child: Icon(icon, color: Colors.white, size: size * 0.5),
  );
}

// ─── SHIMMER BOX ─────────────────────────────────────────────────────────────
// Shown in the location pill while GPS is resolving on first launch.

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
            borderRadius: BorderRadius.circular(5),
          ),
        ),
      );
}

// ─── HOME SCREEN ─────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _itemAnims;

  String _location = '';
  bool   _locationLoaded = false; // drives shimmer vs real text

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
    _ensureLocationPermission(); // ask permission on first run, then fetch
  }

  @override
  void dispose() { _animCtrl.dispose(); super.dispose(); }

  Future<void> _ensureLocationPermission() async {
    // Always request permission on first run so mobile shows the dialog.
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      if (mounted) _showLocationSettingsSnack();
      // Still show cached/manual if any.
      await _loadLocation();
      return;
    }
    await _loadLocation();
  }

  // ── FIX 1: non-blocking location load with shimmer fallback ───────────────
  Future<void> _loadLocation() async {
    // If user set a manual location, always prefer it.
    final isManual = await LocationStorage.isManual();
    if (isManual) {
      final saved = await LocationStorage.getLocation();
      if (saved != null && saved.isNotEmpty) {
        if (mounted) setState(() { _location = saved; _locationLoaded = true; });
        return;
      }
    }

    // 1) Try cached value first — instant if previously saved
    final saved = await LocationStorage.getLocation();
    if (saved != null && saved.isNotEmpty && !_isGenericLocation(saved)) {
      if (mounted) setState(() { _location = saved; _locationLoaded = true; });
      return;
    }
    // 2) No cache → fetch GPS in background; shimmer stays until done
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
    // Generic messages or coordinates should be refreshed to get a better name.
    if (v.contains('location ') ||
        v.contains('permission') ||
        v.contains('unknown')) {
      return true;
    }
    final coordRegex = RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$');
    return coordRegex.hasMatch(v);
  }

  // ── Helper: wrap any child in the stagger animation ───────────────────────
  Widget _anim(int idx, Widget child) => AnimatedBuilder(
        animation: _itemAnims[idx],
        builder: (_, w) => Opacity(
          opacity: _itemAnims[idx].value,
          child: Transform.translate(
              offset: Offset(0, 20 * (1 - _itemAnims[idx].value)), child: w),
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
                  colors: isDark
                      ? [const Color(0xFF1E293B), const Color(0xFF0F172A)]
                      : [const Color(0xFF1A73E8), const Color(0xFF0D5DBF)],
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft:  Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _anim(0, Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Greeting
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Good Morning 👋',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.75),
                                      fontSize: 13, fontWeight: FontWeight.w500,
                                    )),
                                const SizedBox(height: 3),
                                const Text('Arjun Mehta',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 20, fontWeight: FontWeight.w800,
                                    )),

                                    
                          // ── FIX 1: Location pill – shimmer while GPS loads ──
                          GestureDetector(
                            onTap: _openLocationPicker,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 145),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
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
                                      color: Colors.white, size: 13),
                                  const SizedBox(width: 4),
                                  // Show shimmer until loaded
                                  if (!_locationLoaded)
                                    _ShimmerBox(width: 72, height: 10)
                                  else
                                    Flexible(
                                      child: Text(_location,
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 1,
                                          style: TextStyle(
                                            color: Colors.white.withOpacity(0.95),
                                            fontSize: 11, fontWeight: FontWeight.w600,
                                          )),
                                    ),
                                  const SizedBox(width: 2),
                                  const Icon(Icons.keyboard_arrow_down,
                                      color: Colors.white, size: 15),
                                ],
                              ),
                            ),
                          ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 2),

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

                      const SizedBox(height: 20),

                      // Search bar (navigates to search tab)
                      _anim(1, GestureDetector(
                        onTap: () => widget.onTabChange(1),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.3), width: 1),
                          ),
                          child: Row(children: [
                            Icon(Icons.search_rounded,
                                color: Colors.white.withOpacity(0.8), size: 22),
                            const SizedBox(width: 10),
                            Text('Search doctors or specialties…',
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14)),
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
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Quick Actions
                _anim(2, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Quick Actions'),
                    const SizedBox(height: 14),
                    Row(children: [
                      _QuickAction(icon: Icons.calendar_month_rounded,     label: 'Book\nAppt.',   color: const Color(0xFF1A73E8), onTap: () => widget.onTabChange(1)),
                      const SizedBox(width: 10),
                      _QuickAction(icon: Icons.history_rounded,            label: 'My\nAppts.',    color: const Color(0xFF00BFA5), onTap: () => widget.onTabChange(2)),
                      const SizedBox(width: 10),
                      _QuickAction(
                        icon: Icons.group_add_rounded,
                        label: 'Add\nFamily',
                        color: const Color(0xFF7C3AED),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const FamilyMembersScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      _QuickAction(icon: Icons.medical_information_rounded, 
                      label: 'My\nRecords', 
                       color: const Color(0xFFF59E0B), 
                       onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PatientPrescriptionListScreen(),
                          ),
                        ),),
                    ]),
                  ],
                )),
                const SizedBox(height: 28),

                // Upcoming Appointments
                _anim(3, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Upcoming Appointments',
                        action: 'See All', onAction: () => widget.onTabChange(2)),
                    const SizedBox(height: 14),
                    ...sampleAppointments
                        .where((a) => a.status == 'Upcoming')
                        .map((a) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _UpcomingCard(appointment: a),
                            )),
                  ],
                )),
                const SizedBox(height: 28),

                // Specialties
                _anim(4, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Most Searched Specialties'),
                    const SizedBox(height: 14),
                    SizedBox(
                      height: 108,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: specialties.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 10),
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
                const SizedBox(height: 28),

                // Top Doctors
                _anim(5, Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionTitle('Top Rated Doctors',
                        action: 'View All', onAction: () => widget.onTabChange(1)),
                    const SizedBox(height: 14),
                    ...sampleDoctors.take(2).map((d) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _DoctorCard(doctor: d, onTap: () {}),
                        )),
                  ],
                )),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

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

  // ── FIX 2: live filtering as user types ───────────────────────────────────
  void _onType() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _suggestions = q.isEmpty
          ? _allCities
          : _allCities.where((c) => c.toLowerCase().contains(q)).toList();
    });
  }

  // ── FIX 2: tap a row → set location and close sheet ───────────────────────
  void _pick(String loc) {
    widget.onLocationSelected(loc);
    Navigator.pop(context);
  }

  // ── GPS button ────────────────────────────────────────────────────────────
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
    final isDark      = widget.isDark;
    final bg          = isDark ? const Color(0xFF0F172A) : Colors.white;
    final textColor   = isDark ? Colors.white : const Color(0xFF0F172A);
    final sub         = isDark ? Colors.white38 : Colors.grey.shade400;
    final tileBg      = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final divColor    = isDark ? Colors.white10 : const Color(0xFFF1F5F9);

    return Padding(
      // ── FIX 3: slide up when keyboard appears ────────────────────────────
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        // ── FIX 3: cap height so sheet never overflows on small screens ────
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.18),
              blurRadius: 28, offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,   // shrinks when list is short
          children: [

            // Drag handle
            const SizedBox(height: 12),
            Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: isDark ? Colors.white24 : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Title row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [Color(0xFF1A73E8), Color(0xFF0D5DBF)]),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Choose Location',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w800,
                                color: textColor)),
                        if (widget.currentLocation.isNotEmpty)
                          Text('Current: ${widget.currentLocation}',
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: sub)),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 32, height: 32,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.close_rounded, size: 18, color: sub),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── FIX 2: Search field ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: tileBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _searchCtrl,
                  focusNode: _focusNode,
                  textInputAction: TextInputAction.done,
                  style: TextStyle(
                      color: textColor, fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Search city…',
                    hintStyle: TextStyle(
                        color: sub, fontSize: 14, fontWeight: FontWeight.w400),
                    prefixIcon: Icon(Icons.search_rounded, color: sub, size: 20),
                    // Clear button when text is present
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _searchCtrl.clear();
                              _focusNode.requestFocus();
                            },
                            child: Icon(Icons.clear_rounded, color: sub, size: 18),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 13),
                  ),
                  // Pressing "Done" on keyboard picks the top suggestion
                  onSubmitted: (val) {
                    final v = val.trim();
                    if (v.isEmpty) return;
                    if (_suggestions.isNotEmpty) {
                      _pick(_suggestions.first);
                    } else {
                      _pick(v); // allow custom city entry
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 12),

            // GPS button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: GestureDetector(
                onTap: _isLoadingGPS ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDark
                          ? [const Color(0xFF1A73E8).withOpacity(0.18),
                             const Color(0xFF00BFA5).withOpacity(0.18)]
                          : [const Color(0xFF1A73E8).withOpacity(0.08),
                             const Color(0xFF00BFA5).withOpacity(0.08)],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: const Color(0xFF1A73E8).withOpacity(0.3),
                        width: 1.5),
                  ),
                  child: Row(children: [
                    Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [Color(0xFF1A73E8), Color(0xFF00BFA5)]),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _isLoadingGPS
                          ? const Padding(
                              padding: EdgeInsets.all(8),
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.my_location_rounded,
                              color: Colors.white, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _isLoadingGPS ? 'Detecting…' : 'Use Current Location',
                            style: TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w700,
                                color: textColor),
                          ),
                          Text('Auto-detect via GPS',
                              style: TextStyle(fontSize: 11, color: sub)),
                        ],
                      ),
                    ),
                    if (!_isLoadingGPS)
                      const Icon(Icons.chevron_right_rounded,
                          color: Color(0xFF1A73E8), size: 20),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Clear saved location
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
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
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white10 : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: divColor),
                  ),
                  child: Row(children: [
                    Icon(Icons.delete_outline_rounded, size: 18, color: sub),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Clear Saved Location',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: textColor),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Divider label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(children: [
                Expanded(child: Divider(color: divColor, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Text(
                    _searchCtrl.text.isEmpty ? 'POPULAR CITIES' : 'RESULTS',
                    style: TextStyle(
                        fontSize: 9, fontWeight: FontWeight.w800,
                        letterSpacing: 1.2, color: sub),
                  ),
                ),
                Expanded(child: Divider(color: divColor, thickness: 1)),
              ]),
            ),
            const SizedBox(height: 4),

            // ── FIX 2 + 3: Flexible list — scrollable, never overflows ────
            Flexible(
              child: _suggestions.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.search_off_rounded, size: 34, color: sub),
                        const SizedBox(height: 8),
                        Text('No cities found',
                            style: TextStyle(color: sub, fontSize: 13)),
                      ]),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(20, 2, 20, 0),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          Divider(color: divColor, height: 1),
                      itemBuilder: (_, i) {
                        final loc      = _suggestions[i];
                        final isActive = loc == widget.currentLocation;
                        return GestureDetector(
                          // ── FIX 2: tap → set & close ─────────────────────
                          onTap: () => _pick(loc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 11),
                            child: Row(children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                width: 34, height: 34,
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? const Color(0xFF1A73E8)
                                      : tileBg,
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  isActive
                                      ? Icons.location_on_rounded
                                      : Icons.location_city_rounded,
                                  color: isActive ? Colors.white : sub,
                                  size: 17,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(loc,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive
                                          ? const Color(0xFF1A73E8)
                                          : textColor,
                                    )),
                              ),
                              if (isActive)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1A73E8)
                                        .withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: const Text('Active',
                                      style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF1A73E8))),
                                )
                              else
                                Icon(Icons.chevron_right_rounded,
                                    color: divColor, size: 18),
                            ]),
                          ),
                        );
                      },
                    ),
            ),

            // Safe-area bottom padding
            SizedBox(height: MediaQuery.of(context).padding.bottom + 14),
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
            width: 40, height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          ),
          if (badge)
            Positioned(
              right: 8, top: 8,
              child: Container(
                width: 8, height: 8,
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
              fontSize: 17, fontWeight: FontWeight.w800,
              color: isDark ? Colors.white : AppTheme.textPrimary,
            )),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(action!,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w700,
                    color: AppTheme.primary)),
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
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                  color: color, borderRadius: BorderRadius.circular(12)),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 7),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w700, height: 1.3,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
                )),
          ]),
        ),
      ),
    );
  }
}

// ─── UPCOMING CARD ───────────────────────────────────────────────────────────

class _UpcomingCard extends StatelessWidget {
  final Appointment appointment;
  const _UpcomingCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [
          const Color(0xFF1A73E8).withOpacity(isDark ? 0.25 : 0.08),
          const Color(0xFF00BFA5).withOpacity(isDark ? 0.25 : 0.08),
        ]),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: const Color(0xFF1A73E8).withOpacity(0.2), width: 1.5),
      ),
      child: Row(children: [
        _doctorAvatar(appointment.doctorImage, size: 50),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(appointment.doctorName,
                  style: TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  )),
              const SizedBox(height: 2),
              Text(appointment.specialty,
                  style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : AppTheme.textSecondary)),
              const SizedBox(height: 7),
              Row(children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 12, color: AppTheme.primary),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(appointment.date,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: AppTheme.primary)),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.access_time_rounded,
                    size: 12, color: AppTheme.secondary),
                const SizedBox(width: 4),
                Text(appointment.time,
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: AppTheme.secondary)),
              ]),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10)),
          child: const Icon(Icons.videocam_rounded,
              color: Colors.white, size: 18),
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
        width: 86,
        decoration: BoxDecoration(
          color: isDark ? color.withOpacity(0.15) : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 46, height: 46,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(height: 7),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 9, fontWeight: FontWeight.w700,
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
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12, offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _doctorAvatar(doctor.image, size: 62),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(doctor.name,
                          style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          )),
                    ),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.star_rounded,
                          color: Color(0xFFF59E0B), size: 15),
                      const SizedBox(width: 2),
                      Text(doctor.rating.toString(),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B))),
                    ]),
                  ]),
                  const SizedBox(height: 3),
                  Text(doctor.specialty,
                      style: const TextStyle(
                          fontSize: 12, color: AppTheme.primary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(spacing: 5, runSpacing: 4, children: [
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
                  const SizedBox(height: 10),
                  Row(children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onTap,
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          side: const BorderSide(color: AppTheme.primary),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('View Profile',
                            style: TextStyle(fontSize: 11)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 3),
        Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      ]),
    );
  }
}
