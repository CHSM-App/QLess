import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/screens/location_storage.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ── Colour Palette ─────────────────────────────────────────────────
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF1EA898);
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

// ── Specialty colour/icon helpers (hash-based, same logic as explore screen) ──
const _kAccentPalette = [
  Color(0xFFFC8181), Color(0xFFF6AD55), Color(0xFF68D391), Color(0xFF9F7AEA),
  Color(0xFF3B82F6), Color(0xFF26C6B0), Color(0xFFF687B3), Color(0xFF4FD1C5),
  Color(0xFFED8936), Color(0xFF667EEA),
];
const _kIconPalette = <IconData>[
  Icons.favorite_rounded, Icons.face_retouching_natural, Icons.child_care_rounded,
  Icons.accessibility_new_rounded, Icons.psychology_rounded, Icons.local_hospital_rounded,
  Icons.pregnant_woman_rounded, Icons.visibility_rounded, Icons.medical_services_rounded,
  Icons.hearing_rounded,
];

int _hashIndex(String? s, int length) {
  if (s == null || s.isEmpty) return 0;
  var h = 0;
  for (final c in s.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % length;
}

Color    _accentForSpec(String? s) => _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
IconData _iconForSpec(String? s)   => _kIconPalette[_hashIndex(s, _kIconPalette.length)];

List<Map<String, dynamic>> _buildSpecialtyList(List<DoctorDetails> doctors) {
  final seen   = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final d in doctors) {
    final s = d.specialization?.trim();
    if (s != null && s.isNotEmpty && seen.add(s.toLowerCase())) {
      result.add({
        'name' : s,
        'icon' : _iconForSpec(s),
        'color': _accentForSpec(s),
      });
    }
  }
  return result;
}

// ── Doctor avatar helper ───────────────────────────────────────────
Color _avatarBg(String? spec) {
  final c = _accentForSpec(spec);
  return c.withOpacity(0.15);
}

Widget _doctorAvatar(String? spec, {double size = 46}) {
  final color = _accentForSpec(spec);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _avatarBg(spec),
      borderRadius: BorderRadius.circular(size * 0.27),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
    ),
    child: Icon(_iconForSpec(spec), color: color, size: size * 0.44),
  );
}

// ── Shimmer ────────────────────────────────────────────────────────
DateTime? _timeTodayFromRaw(String? raw) {
  final value = raw?.trim();
  if (value == null ||
      value.isEmpty ||
      value == '--' ||
      value.toLowerCase() == 'null') {
    return null;
  }

  final now = DateTime.now();
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    final u = iso.toUtc();
    return DateTime(now.year, now.month, now.day, u.hour, u.minute);
  }

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([aApP][mM])?$',
  ).firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || minute > 59) return null;

  final meridiem = match.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    if (hour == 12) hour = 0;
    if (meridiem == 'pm') hour += 12;
  } else if (hour > 23) {
    return null;
  }

  return DateTime(now.year, now.month, now.day, hour, minute);
}

String _fmtClockTime(String? raw) {
  final parsed = _timeTodayFromRaw(raw);
  if (parsed != null) return DateFormat('h:mm a').format(parsed);
  final value = raw?.trim();
  return value == null || value.isEmpty ? '--' : value;
}

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

  String _location      = '';
  bool   _locationLoaded = false;
  bool   _didFetch      = false;
  bool   _isFetching    = false;

  // Cache specialty list so we don't rebuild on every frame
  List<Map<String, dynamic>> _cachedSpecialties = [];
  bool _popupShown = false;

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

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  // ── Data fetch ─────────────────────────────────────────────────
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
      // Fetch both appointments AND doctors in parallel
      await Future.wait([
        ref.read(appointmentViewModelProvider.notifier).getPatientAppointments(pid),
        ref.read(doctorsViewModelProvider.notifier).fetchDoctors(pid),
      ]);
    } finally {
      _isFetching = false;
    }
  }

  // ── Location ───────────────────────────────────────────────────
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
    final isWindows = !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isWindows
          ? 'Enable Windows location services'
          : 'Enable phone location services'),
      action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () => Geolocator.openLocationSettings()),
    ));
  }

  // ── Appointment helpers ────────────────────────────────────────
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

  // ── Fade animation helper ──────────────────────────────────────
  Widget _fade(int i, Widget child) => AnimatedBuilder(
    animation: _anims[i],
    builder: (_, w) => Opacity(
      opacity: _anims[i].value,
      child: Transform.translate(
          offset: Offset(0, 14 * (1 - _anims[i].value)), child: w),
    ),
    child: child,
  );

  // ── Navigate to search with specialty ─────────────────────────
  void _goToSearch({String? specialty}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSearchScreen(initialSpecialty: specialty),
      ),
    );
  }

  // ── Appointments section ───────────────────────────────────────
  Widget _buildAppointmentsSection() {
    final async = ref
        .watch(appointmentViewModelProvider)
        .patientAppointmentsList;
    if (async == null || async is AsyncLoading)
      return _apptShell(loading: true);
    return async.when(
      loading: () => _apptShell(loading: true),
      error:   (_, __) => const SizedBox.shrink(),
      data: (list) {
        final today = list.where(_isToday).toList();
        final upcoming = list.where(_isUpcoming).toList();
        final combined = [...today, ...upcoming];
        final shown = combined.take(3).toList();
        final hasMore = combined.length > 3;

        if (!_popupShown) {
          final todayActive = today.where((a) {
            final s = a.status?.toLowerCase().trim() ?? '';
            return s != 'cancelled' &&
                s != 'cancled' &&
                s != 'completed' &&
                s != 'complete';
          }).toList();
          if (todayActive.isNotEmpty) {
            final now = DateTime.now();
            DateTime? resolveTime(AppointmentList a) =>
                _timeTodayFromRaw(a.startTime) ??
                _timeTodayFromRaw(a.estimatedArrivalTime);

            todayActive.sort((a, b) {
              final ta = resolveTime(a)?.millisecondsSinceEpoch;
              final tb = resolveTime(b)?.millisecondsSinceEpoch;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return ta.compareTo(tb);
            });

            final nowMinutes = now.hour * 60 + now.minute;
            AppointmentList? next;
            for (final a in todayActive) {
              final t = resolveTime(a);
              if (t == null) continue;
              final apptMinutes = t.hour * 60 + t.minute;
              if (apptMinutes >= nowMinutes) {
                next = a;
                break;
              }
            }
            if (next == null) {
              for (final a in todayActive.reversed) {
                if (resolveTime(a) != null) {
                  next = a;
                  break;
                }
              }
            }
            final popupAppointment = next ?? todayActive.first;
            _popupShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTodayAppointmentPopup(popupAppointment);
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle('Upcoming Appointments',
                action:   hasMore ? 'See All' : null,
                onAction: () => widget.onTabChange(2)),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              _EmptyNote('No upcoming appointments')
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

  void _showTodayAppointmentPopup(AppointmentList appt) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TodayAppointmentPopup(appointment: appt),
    );
  }

  Widget _apptShell({required bool loading}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle('Upcoming Appointments',
          action: 'See All', onAction: () => widget.onTabChange(2)),
      const SizedBox(height: 10),
      if (loading) ...[
        const _ApptSkeletonCard(),
        const SizedBox(height: 8),
        const _ApptSkeletonCard(),
      ],
    ],
  );

  // ── Specialties section ────────────────────────────────────────
  Widget _buildSpecialtiesSection(List<DoctorDetails> doctors, bool isLoading) {
    // Update cache when doctors change
    if (doctors.isNotEmpty) {
      _cachedSpecialties = _buildSpecialtyList(doctors);
    }
    final specList = _cachedSpecialties;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle('Most Searched Specialties'),
        const SizedBox(height: 10),
        if (isLoading && specList.isEmpty)
          // Shimmer skeleton while loading
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: 6,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, __) => _SpecialtyChipSkeleton(),
            ),
          )
        else if (specList.isEmpty)
          const SizedBox.shrink()
        else
          SizedBox(
            height: 96,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: specList.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final s = specList[i];
                return _SpecialtyChip(
                  icon:  s['icon']  as IconData,
                  label: s['name']  as String,
                  color: s['color'] as Color,
                  onTap: () => _goToSearch(specialty: s['name'] as String),
                );
              },
            ),
          ),
      ],
    );
  }

  // ════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final loginState    = ref.watch(patientLoginViewModelProvider);
    final doctorsState  = ref.watch(doctorsViewModelProvider);
    final name          = loginState.name ?? 'there';
    final hour          = DateTime.now().hour;
    final greeting      = hour < 12
        ? 'Good Morning 👋'
        : hour < 17 ? 'Good Afternoon 👋' : 'Good Evening 👋';

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

            // ── HEADER ────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(
                      bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
                ),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fade(0, Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(greeting,
                                      style: const TextStyle(
                                          color: kTextSecondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500)),
                                  const SizedBox(height: 1),
                                  Text(name,
                                      style: const TextStyle(
                                          color: kTextPrimary,
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 5),
                                  GestureDetector(
                                    onTap: _openLocationPicker,
                                    child: Container(
                                      constraints:
                                          const BoxConstraints(maxWidth: 140),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: kPrimaryLight,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                            color: kPrimary.withOpacity(0.2)),
                                      ),
                                      child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                                Icons.location_on_rounded,
                                                color: kPrimary,
                                                size: 10),
                                            const SizedBox(width: 3),
                                            if (!_locationLoaded)
                                              _Shimmer(width: 60, height: 8)
                                            else
                                              Flexible(
                                                child: Text(_location,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    maxLines: 1,
                                                    style: const TextStyle(
                                                        color: kPrimary,
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.w600)),
                                              ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                                Icons.keyboard_arrow_down,
                                                color: kPrimary,
                                                size: 12),
                                          ]),
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
                                      builder: (_) =>
                                          const NotificationsScreen())),
                            ),
                          ],
                        )),
                        const SizedBox(height: 14),
                        _fade(1, GestureDetector(
                          onTap: () => widget.onTabChange(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorder),
                            ),
                            child: const Row(children: [
                              Icon(Icons.search_rounded,
                                  color: kTextMuted, size: 17),
                              SizedBox(width: 8),
                              Text('Search doctors or specialties…',
                                  style: TextStyle(
                                      color: kTextMuted, fontSize: 13)),
                            ]),
                          ),
                        ),)
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── BODY ──────────────────────────────────────────────
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([

                  // ── Quick Actions 2×2 grid ──────────────────────
                  _fade(2, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Quick Actions'),
                      const SizedBox(height: 10),
                      Row(children: [
                        _QuickAction(
                          icon: Icons.calendar_month_rounded,
                          label: 'Book Appointment',
                          subtitle: 'Find & reserve',
                          color: kPrimary,
                          highlighted: true,
                          onTap: () => widget.onTabChange(1),
                        ),
                        const SizedBox(width: 8),
                        _QuickAction(
                          icon: Icons.history_rounded,
                          label: 'My Appointments',
                          subtitle: 'History & upcoming',
                          color: kPrimary,
                          onTap: () => widget.onTabChange(2),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      Row(children: [
                        _QuickAction(
                          icon: Icons.group_add_rounded,
                          label: 'Family',
                          subtitle: 'Manage members',
                          color: kPurple,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const FamilyMembersScreen())),
                        ),
                        const SizedBox(width: 8),
                        _QuickAction(
                          icon: Icons.medical_information_rounded,
                          label: 'Records',
                          subtitle: 'Prescriptions',
                          color: kWarning,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const PatientPrescriptionListScreen())),
                        ),
                      ]),
                    ],
                  )),
                  const SizedBox(height: 22),

                  // ── Upcoming Appointments ───────────────────────
                  _fade(3, _buildAppointmentsSection()),
                  const SizedBox(height: 22),

                  // ── Specialties — dynamic from API ──────────────
                  _fade(4, _buildSpecialtiesSection(
                      doctorsState.doctors, doctorsState.isLoading)),
                  const SizedBox(height: 22),

                  // ── Top Rated Doctors header ────────────────────
                  _fade(5, Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Top Rated Doctors',
                          action: 'View All',
                          onAction: () => widget.onTabChange(1)),
                      const SizedBox(height: 10),
                    ],
                  )),

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
const List<String> _allCities = [
  'Bengaluru, IN','Mumbai, IN','Delhi, IN','Hyderabad, IN','Pune, IN',
  'Chennai, IN','Kolkata, IN','Ahmedabad, IN','Jaipur, IN','Surat, IN',
  'Lucknow, IN','Kanpur, IN','Nagpur, IN','Indore, IN','Thane, IN',
  'Bhopal, IN','Visakhapatnam, IN','Patna, IN','Vadodara, IN','Ghaziabad, IN',
  'Ludhiana, IN','Agra, IN','Nashik, IN','Faridabad, IN','Meerut, IN',
  'Rajkot, IN','Varanasi, IN','Srinagar, IN','Aurangabad, IN','Dhanbad, IN',
  'Amritsar, IN','Navi Mumbai, IN','Coimbatore, IN','Madurai, IN',
  'Vijayawada, IN','Guwahati, IN','Chandigarh, IN','Hubli, IN',
  'Mysuru, IN','Tiruchirappalli, IN',
];

class _LocationSheet extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<String> onSelected;
  const _LocationSheet(
      {required this.currentLocation, required this.onSelected});
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
      final hasIssue = current.toLowerCase().contains('location disabled') ||
          current.toLowerCase().contains('permission');
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
          const SnackBar(content: Text('Unable to detect location')));
    }
  }

  void _snack() {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(isWindows
          ? 'Enable Windows location services'
          : 'Enable phone location services'),
      action: SnackBarAction(
          label: 'Settings',
          onPressed: () => Geolocator.openLocationSettings()),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SizedBox(height: 10),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: kBorder, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.location_on_rounded,
                      color: kPrimary, size: 17)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Choose Location',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      if (widget.currentLocation.isNotEmpty)
                        Text('Current: ${widget.currentLocation}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: kTextMuted)),
                    ]),
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
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: kTextMuted)),
              ),
            ]),
          ),
          const SizedBox(height: 10),
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
                    fontWeight: FontWeight.w500),
                decoration: InputDecoration(
                  hintText: 'Search city…',
                  hintStyle:
                      const TextStyle(color: kTextMuted, fontSize: 13),
                  prefixIcon: const Icon(Icons.search_rounded,
                      color: kTextMuted, size: 17),
                  suffixIcon: _ctrl.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _ctrl.clear();
                            _focus.requestFocus();
                          },
                          child: const Icon(Icons.clear_rounded,
                              color: kTextMuted, size: 15))
                      : null,
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 11),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: _isLoadingGPS ? null : _useGPS,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: kPrimaryLight.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withOpacity(0.3)),
                ),
                child: Row(children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(8)),
                    child: _isLoadingGPS
                        ? const Padding(
                            padding: EdgeInsets.all(7),
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.my_location_rounded,
                            color: Colors.white, size: 15),
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
                                  color: kTextPrimary)),
                          const Text('Auto-detect via GPS',
                              style: TextStyle(
                                  fontSize: 10, color: kTextMuted)),
                        ]),
                  ),
                  if (!_isLoadingGPS)
                    const Icon(Icons.chevron_right_rounded,
                        color: kPrimary, size: 17),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: GestureDetector(
              onTap: () async {
                await LocationStorage.clearLocation();
                if (!mounted) return;
                widget.onSelected('');
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('Location cache cleared')));
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: const Row(children: [
                  Icon(Icons.delete_outline_rounded,
                      size: 15, color: kTextMuted),
                  SizedBox(width: 8),
                  Text('Clear Saved Location',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              const Expanded(child: Divider(color: kBorder, height: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Text(
                    _ctrl.text.isEmpty ? 'POPULAR CITIES' : 'RESULTS',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: kTextMuted)),
              ),
              const Expanded(child: Divider(color: kBorder, height: 1)),
            ]),
          ),
          const SizedBox(height: 4),
          Flexible(
            child: _suggestions.isEmpty
                ? const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.search_off_rounded,
                          size: 28, color: kTextMuted),
                      SizedBox(height: 6),
                      Text('No cities found',
                          style: TextStyle(color: kTextMuted, fontSize: 12)),
                    ]),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: kBorder, height: 1),
                    itemBuilder: (_, i) {
                      final loc      = _suggestions[i];
                      final isActive = loc == widget.currentLocation;
                      return GestureDetector(
                        onTap: () => _pick(loc),
                        child: Container(
                          color: Colors.transparent,
                          padding:
                              const EdgeInsets.symmetric(vertical: 9),
                          child: Row(children: [
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
                                  color: isActive
                                      ? Colors.white
                                      : kTextMuted,
                                  size: 14),
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
                                          ? kPrimary
                                          : kTextPrimary,
                                    ))),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                    color: kPrimaryLight,
                                    borderRadius:
                                        BorderRadius.circular(6)),
                                child: const Text('Active',
                                    style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary)),
                              )
                            else
                              const Icon(Icons.chevron_right_rounded,
                                  color: kBorder, size: 15),
                          ]),
                        ),
                      );
                    },
                  ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HEADER BUTTON
// ════════════════════════════════════════════════════════════════════
class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn(
      {required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Stack(children: [
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
                      color: kWarning, shape: BoxShape.circle)),
            ),
        ]),
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
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kPrimary)),
            ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════
//  QUICK ACTION — 2×2 layout, Book Appt animated
// ════════════════════════════════════════════════════════════════════
class _QuickAction extends StatefulWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
  final bool highlighted;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
    this.highlighted = false,
  });

  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _ripple;
  late Animation<double> _shimmer;
  late Animation<double> _bounce;

  @override
  void initState() {
    super.initState();
    if (!widget.highlighted) return;
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat();
    _ripple  = Tween<double>(begin: 0, end: 1)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _shimmer = Tween<double>(begin: -1.5, end: 2.0).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.1, 0.7, curve: Curves.easeInOut)));
    _bounce  = Tween<double>(begin: 0, end: 1).animate(CurvedAnimation(
        parent: _ctrl,
        curve:
            const Interval(0.0, 0.5, curve: Curves.elasticOut)));
  }

  @override
  void dispose() {
    if (widget.highlighted) _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: widget.onTap,
        child: widget.highlighted ? _buildHighlighted() : _buildPlain(),
      ),
    );
  }

  Widget _buildHighlighted() {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: kPrimaryDark),
            boxShadow: [
              BoxShadow(
                  color: kPrimary.withOpacity(0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4))
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: Stack(children: [
              Positioned.fill(child: _buildRipple(0.0)),
              Positioned.fill(child: _buildRipple(0.33)),
              Positioned.fill(child: _buildRipple(0.66)),
              Positioned.fill(
                child: Transform.translate(
                  offset: Offset(_shimmer.value * 120, 0),
                  child: Container(
                    width: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.transparent,
                          Colors.white.withOpacity(0.15),
                          Colors.transparent
                        ],
                        stops: const [0.0, 0.5, 1.0],
                      ),
                    ),
                  ),
                ),
              ),
              Row(children: [
                Transform.translate(
                  offset: Offset(
                      0, -3 * (0.5 - (_bounce.value - 0.5).abs()) * 2),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.22),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Icon(widget.icon, color: Colors.white, size: 15),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.label,
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Colors.white),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                        const SizedBox(height: 2),
                        Text(widget.subtitle,
                            style: TextStyle(
                                fontSize: 9,
                                color: Colors.white.withOpacity(0.85)),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1),
                      ]),
                ),
              ]),
            ]),
          ),
        );
      },
    );
  }

  Widget _buildRipple(double phaseOffset) {
    final phase   = (_ctrl.value + phaseOffset) % 1.0;
    final size    = 52.0 + phase * 60.0;
    final opacity = (1.0 - phase) * 0.35;
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(left: 7),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: Colors.white.withOpacity(opacity), width: 1.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlain() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: widget.color.withOpacity(0.2)),
      ),
      child: Row(children: [
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
              color: widget.color,
              borderRadius: BorderRadius.circular(10)),
          child: Icon(widget.icon, color: Colors.white, size: 15),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.label,
                    style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
                const SizedBox(height: 2),
                Text(widget.subtitle,
                    style: const TextStyle(
                        fontSize: 9, color: kTextSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1),
              ]),
        ),
      ]),
    );
  }
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
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_today_rounded, size: 13, color: kPrimary),
          const SizedBox(width: 6),
          Text(message,
              style: const TextStyle(fontSize: 12, color: kTextSecondary)),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD
// ════════════════════════════════════════════════════════════════════
class _ApptCard extends StatefulWidget {
  final AppointmentList appointment;
  final bool isToday;
  const _ApptCard({required this.appointment, this.isToday = false});
  @override
  State<_ApptCard> createState() => _ApptCardState();
}

class _ApptCardState extends State<_ApptCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _badgePulse;
  late Animation<double> _dotBlink;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
    _badgePulse = Tween<double>(begin: 0.0, end: 6.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
    _dotBlink = Tween<double>(begin: 1.0, end: 0.25).animate(CurvedAnimation(
        parent: _ctrl,
        curve: const Interval(0.0, 0.5, curve: Curves.easeInOut)));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : DateFormat('d MMM yyyy').format(dt);
  }

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final dt = DateTime(2000, 1, 1, int.tryParse(parts[0]) ?? 0, int.tryParse(parts[1]) ?? 0);
    return DateFormat('h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final appt      = widget.appointment;
    final name      = appt.doctorName ?? 'Doctor';
    final spec      = appt.specialization ?? '';
    final dateStr   = _fmtDate(appt.appointmentDate);
    final timeStr   = _fmtTime(appt.startTime);
    final myToken   = appt.myQueueNumber ?? appt.queueNumber;
    final totalQ    = appt.totalQueue;
    final serving   = appt.currentServing;
    final isMyTurn  = appt.isMyTurn ?? false;
    final showQueue = widget.isToday && myToken != null;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isMyTurn
                  ? kPrimary
                  : (widget.isToday
                      ? kPrimary.withOpacity(0.2)
                      : kBorder),
              width: isMyTurn ? 1.5 : 1,
            ),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 11, 12, 9),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _doctorAvatar(spec, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary),
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 2),
                          Text(spec,
                              style: const TextStyle(
                                  fontSize: 11, color: kTextSecondary)),
                          const SizedBox(height: 2),
                          if ((appt.patientName ?? '').isNotEmpty)
                            Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.person_outline_rounded,
                                  size: 10, color: kTextMuted),
                              const SizedBox(width: 3),
                              Flexible(
                                child: Text(appt.patientName ?? '',
                                    style: const TextStyle(
                                        fontSize: 10,
                                        color: kTextMuted,
                                        fontWeight: FontWeight.w500),
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ]),
                          Row(children: [
                            const Icon(Icons.calendar_today_rounded,
                                size: 10, color: kPrimary),
                            const SizedBox(width: 3),
                            Text(dateStr,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimary)),
                            const SizedBox(width: 8),
                            const Icon(Icons.access_time_rounded,
                                size: 10, color: kPrimaryDark),
                            const SizedBox(width: 3),
                            Text(timeStr,
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: kPrimaryDark)),
                          ]),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (showQueue)
                      Column(children: [
                        SizedBox(
                          width: 42,
                          height: 42,
                          child: Stack(
                              alignment: Alignment.center,
                              children: [
                                ...[0.0, 0.4, 0.8].map((phase) {
                                  final p = (_ctrl.value + phase) % 1.0;
                                  final sz = 28.0 + p * 20.0;
                                  final op = (1.0 - p) * 0.4;
                                  return Container(
                                    width: sz,
                                    height: sz,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color:
                                              kPrimary.withOpacity(op),
                                          width: 1.5),
                                    ),
                                  );
                                }),
                                Container(
                                  width: 38,
                                  height: 38,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: LinearGradient(
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                      colors: [kPrimary, kPrimaryDark],
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment.center,
                                    children: [
                                      Text('NOW',
                                          style: TextStyle(
                                              fontSize: 6,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.white
                                                  .withOpacity(0.85),
                                              letterSpacing: 0.4)),
                                      Text(
                                          (serving != null && serving > 0)
                                              ? serving
                                                  .toString()
                                                  .padLeft(2, '0')
                                              : '--',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w800,
                                              color: Colors.white,
                                              height: 1)),
                                    ],
                                  ),
                                ),
                              ]),
                        ),
                        const SizedBox(height: 3),
                        Row(mainAxisSize: MainAxisSize.min, children: [
                          Opacity(
                            opacity: _dotBlink.value,
                            child: Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                    color: kPrimary,
                                    shape: BoxShape.circle)),
                          ),
                          const SizedBox(width: 3),
                          const Text('live',
                              style: TextStyle(
                                  fontSize: 8,
                                  color: kTextMuted,
                                  fontWeight: FontWeight.w500)),
                        ]),
                      ]),
                  ],
                ),
              ),
              if (showQueue) ...[
                Divider(color: kBorder, height: 1, indent: 12, endIndent: 12),
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 7, 12, 9),
                  child: Row(children: [
                    Text(myToken.toString().padLeft(2, '0'),
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF9F7AEA))),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6),
                      child: Text('·',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: kTextMuted)),
                    ),
                    const Text('Total :',
                        style: TextStyle(
                            fontSize: 10,
                            color: kTextSecondary,
                            fontWeight: FontWeight.w500)),
                    const SizedBox(width: 3),
                    Text(
                        totalQ != null
                            ? totalQ.toString().padLeft(2, '0')
                            : '--',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF3B82F6))),
                    const Spacer(),
                    if (isMyTurn)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                            color: kPrimary,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Your Turn!',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: kPrimaryLight,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                              color: kPrimary.withOpacity(0.25)),
                        ),
                        child: const Text('Today',
                            style: TextStyle(
                                color: kPrimaryDark,
                                fontSize: 9,
                                fontWeight: FontWeight.w700)),
                      ),
                  ]),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Small dot widget ───────────────────────────────────────────────
class _Dot extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
    Container(width: 3, height: 3, decoration: const BoxDecoration(color: kBorder, shape: BoxShape.circle));
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP  — dynamic, tappable
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

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
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
            ),
          ]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP SKELETON  — shown while loading
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChipSkeleton extends StatefulWidget {
  @override
  State<_SpecialtyChipSkeleton> createState() => _SpecialtyChipSkeletonState();
}

class _SpecialtyChipSkeletonState extends State<_SpecialtyChipSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
          width: 76,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT SKELETON CARD
// ════════════════════════════════════════════════════════════════════
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
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
                Color(0xFFEDF2F7)
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 3))
            ],
          ),
          child: Row(children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment(_anim.value - 1, 0),
                  end: Alignment(_anim.value + 1, 0),
                  colors: const [
                    Color(0xFFEDF2F7),
                    Color(0xFFCBD5E0),
                    Color(0xFFEDF2F7)
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _bar(width: 130, height: 13),
                    _bar(width: 90, height: 10),
                    const SizedBox(height: 3),
                    Row(children: [
                      _bar(width: 70, height: 10),
                      const SizedBox(width: 8),
                      _bar(width: 55, height: 10),
                    ]),
                  ]),
            ),
          ]),
        ),
      );
}



// ════════════════════════════════════════════════════════════════════
//  TODAY APPOINTMENT POPUP
// ════════════════════════════════════════════════════════════════════
class _TodayAppointmentPopup extends StatelessWidget {
  final AppointmentList appointment;
  const _TodayAppointmentPopup({required this.appointment});

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    // ISO 8601 with dummy date (e.g. "1970-01-01T10:40:00.000Z") — read UTC hours/minutes directly
    final parsed = _timeTodayFromRaw(raw);
    if (parsed != null) return DateFormat('h:mm a').format(parsed);
    // Fallback: plain HH:mm
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

  String _bookingLabel(int? type) {
    if (type == 2) return 'Slot';
    if (type == 1) return 'Queue';
    return 'Appointment';
  }

  Color _bookingColor(int? type) => type == 2 ? kInfo : kPrimary;

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    final doctorName = appt.doctorName ?? 'Doctor';
    final spec = appt.specialization ?? '';
    final clinic = appt.clinicName ?? '';
    final isQueue =
        appt.bookingType == 1 ||
        (appt.startTime == null || appt.startTime!.isEmpty);
    final timeStr = isQueue
        ? _fmtTime(appt.estimatedArrivalTime)
        : _fmtTime(appt.startTime);
    final endStr = isQueue ? null : _fmtTime(appt.endTime);
    final myToken = appt.myQueueNumber ?? appt.queueNumber;
    final serving = appt.currentServing;
    final isMyTurn = appt.isMyTurn ?? false;
    final typeLabel = _bookingLabel(appt.bookingType);
    final typeColor = _bookingColor(appt.bookingType);
    final doctorID = appt.appointmentId ?? 'general';

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── Main content ──────────────────────────────────────
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header gradient banner
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 48, 16),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    colors: [kPrimary, kPrimaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Appointment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You have an appointment today',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Body
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Doctor row
                    Row(
                      children: [
                        _doctorAvatar('cardio', size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '$doctorName ($doctorID)',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (spec.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  spec,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                              if (clinic.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_hospital_outlined,
                                      size: 10,
                                      color: kTextMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        clinic,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kTextMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        // Booking type badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: typeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),
                    Divider(color: kBorder, height: 1),
                    const SizedBox(height: 14),

                    // Time row
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.access_time_rounded,
                          label: isQueue ? 'Est. Arrival' : 'Time',
                          value:
                              (endStr != null &&
                                  endStr.isNotEmpty &&
                                  endStr != '—')
                              ? '$timeStr – $endStr'
                              : timeStr,
                          color: kPrimary,
                        ),
                        if (myToken != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Your Token',
                            value: myToken.toString().padLeft(2, '0'),
                            color: kPurple,
                          ),
                        ],
                        if (serving != null && serving > 0) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.people_alt_outlined,
                            label: 'Now Serving',
                            value: serving.toString().padLeft(2, '0'),
                            color: kInfo,
                          ),
                        ],
                      ],
                    ),

                    if (isMyTurn) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'It\'s Your Turn!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if ((appt.patientName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 12,
                            color: kTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For: ${appt.patientName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),

          // ── Close (X) button — top-right ──────────────────────
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}


// ── Info chip used inside today popup ─────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

