import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';

// ── Colour palette (mirrors home_screen.dart) ─────────────────────────────────
const _kPrimary      = Color(0xFF26C6B0);
const _kPrimaryDark  = Color(0xFF2BB5A0);
const _kPrimaryLight = Color(0xFFD9F5F1);

const _kTextPrimary   = Color(0xFF2D3748);
const _kTextSecondary = Color(0xFF718096);
const _kTextMuted     = Color(0xFFA0AEC0);

const _kBorder  = Color(0xFFEDF2F7);
const _kDivider = Color(0xFFE5E7EB);

const _kError      = Color(0xFFFC8181);
const _kRedLight   = Color(0xFFFEE2E2);
const _kSuccess    = Color(0xFF68D391);
const _kGreenLight = Color(0xFFDCFCE7);
const _kWarning    = Color(0xFFF6AD55);
const _kAmberLight = Color(0xFFFEF3C7);
const _kPurple     = Color(0xFF9F7AEA);
const _kPurpleLight = Color(0xFFEDE9FE);
const _kInfo       = Color(0xFF3B82F6);
const _kInfoLight  = Color(0xFFDBEAFE);

// ── Specialty → colour helpers (hash-based) ───────────────────────────────────
const _kAccentPalette = [
  Color(0xFFFC8181),
  Color(0xFFF6AD55),
  Color(0xFF68D391),
  Color(0xFF9F7AEA),
  Color(0xFF3B82F6),
  Color(0xFF26C6B0),
  Color(0xFFF687B3),
  Color(0xFF4FD1C5),
  Color(0xFFED8936),
  Color(0xFF667EEA),
];
const _kBgPalette = [
  Color(0xFFFEE2E2),
  Color(0xFFFEF3C7),
  Color(0xFFDCFCE7),
  Color(0xFFEDE9FE),
  Color(0xFFDBEAFE),
  Color(0xFFD9F5F1),
  Color(0xFFFED7E2),
  Color(0xFFE6FFFA),
  Color(0xFFFEEBC8),
  Color(0xFFEBF4FF),
];
const _kIconPalette = <IconData>[
  Icons.favorite_rounded,
  Icons.face_retouching_natural,
  Icons.child_care_rounded,
  Icons.accessibility_new_rounded,
  Icons.psychology_rounded,
  Icons.local_hospital_rounded,
  Icons.pregnant_woman_rounded,
  Icons.visibility_rounded,
  Icons.medical_services_rounded,
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

Color    _accentFor(String? s) => _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
Color    _bgFor(String? s)     => _kBgPalette[_hashIndex(s, _kBgPalette.length)];
IconData _iconFor(String? s)   => _kIconPalette[_hashIndex(s, _kIconPalette.length)];

String _initials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
      sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ════════════════════════════════════════════════════════════════════
//  EXPLORE SCREEN
// ════════════════════════════════════════════════════════════════════
class DoctorExploreScreen extends ConsumerStatefulWidget {
  const DoctorExploreScreen({super.key});

  @override
  ConsumerState<DoctorExploreScreen> createState() =>
      _DoctorExploreScreenState();
}

class _DoctorExploreScreenState extends ConsumerState<DoctorExploreScreen>
    with SingleTickerProviderStateMixin {
  Position? _position;
  late AnimationController _animCtrl;
  late List<Animation<double>> _anims;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anims = List.generate(5, (i) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(i * 0.08, 0.55 + i * 0.07, curve: Curves.easeOut),
      ),
    ));
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    await ref.read(doctorsViewModelProvider.notifier).fetchDoctors(patientId);
    final pos = await LocationService.getCurrentPosition();
    if (mounted) setState(() => _position = pos);
  }

  void _goToSearch(BuildContext context, {String? specialty}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSearchScreen(initialSpecialty: specialty),
      ),
    );
  }

  // ── Derived lists ──────────────────────────────────────────────────

  List<DoctorDetails> _recentDoctors(List<DoctorDetails> all) =>
      all.where((d) => d.isRecentlyVisited == 1).take(10).toList();

  List<DoctorDetails> _nearbyDoctors(List<DoctorDetails> all) {
    if (_position == null) return [];
    final withDist = all
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) => MapEntry(
              d,
              _haversineKm(_position!.latitude, _position!.longitude,
                  d.latitude!, d.longitude!),
            ))
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return withDist.take(10).map((e) => e.key).toList();
  }

  List<String> _uniqueSpecialties(List<DoctorDetails> all) {
    final seen = <String>{};
    final result = <String>[];
    for (final d in all) {
      final s = d.specialization?.trim();
      if (s != null && s.isNotEmpty && seen.add(s.toLowerCase())) {
        result.add(s);
      }
    }
    return result;
  }

  Widget _fade(int i, Widget child) => AnimatedBuilder(
        animation: _anims[i],
        builder: (_, w) => Opacity(
          opacity: _anims[i].value,
          child: Transform.translate(
              offset: Offset(0, 14 * (1 - _anims[i].value)), child: w),
        ),
        child: child,
      );

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(doctorsViewModelProvider);
    final doctors     = state.doctors;
    final isLoading   = state.isLoading;
    final recent      = _recentDoctors(doctors);
    final nearby      = _nearbyDoctors(doctors);
    final specialties = _uniqueSpecialties(doctors);

    return Scaffold(
      backgroundColor: Colors.white,
      body: RefreshIndicator(
        color: _kPrimary,
        onRefresh: _loadData,
        child: CustomScrollView(
        slivers: [

          // ── HEADER ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: _fade(0, _buildHeader(context)),
          ),

          // ── BODY ───────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Recent Doctors
                if (isLoading || recent.isNotEmpty) ...[
                  _fade(1, _SectionTitle(
                    'Recent Doctors',
                    subtitle: 'Your last visits',
                  )),
                  const SizedBox(height: 10),
                  _fade(1, isLoading
                      ? _HorizontalShimmer(height: 170, itemWidth: 130)
                      : _buildRecentDoctors(context, recent)),
                  const SizedBox(height: 22),
                ],

                // Nearby Doctors
                if (_position != null && (isLoading || nearby.isNotEmpty)) ...[
                  _fade(2, _SectionTitle(
                    'Nearby Doctors',
                    subtitle: 'Doctors close to you',
                    action: 'See All',
                    onAction: () => _goToSearch(context),
                  )),
                  const SizedBox(height: 10),
                  _fade(2, isLoading
                      ? _HorizontalShimmer(height: 148, itemWidth: 210)
                      : _buildNearbyDoctors(context, nearby)),
                  const SizedBox(height: 22),
                ],

                // Browse by Specialty
                if (isLoading || specialties.isNotEmpty) ...[
                  _fade(3, _SectionTitle(
                    'Browse by Specialty',
                    subtitle: 'Find the right specialist',
                  )),
                  const SizedBox(height: 10),
                  _fade(3, isLoading
                      ? _buildSpecialtyShimmerGrid()
                      : _buildSpecialtyGrid(context, specialties)),
                ],

                // Empty state
                if (!isLoading && doctors.isEmpty) ...[
                  const SizedBox(height: 60),
                  _fade(4, Center(
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Container(
                        width: 60, height: 60,
                        decoration: BoxDecoration(
                            color: _kPrimaryLight,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.search_off_rounded,
                            size: 26, color: _kPrimary),
                      ),
                      const SizedBox(height: 12),
                      const Text('No doctors found',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: _kTextPrimary)),
                      const SizedBox(height: 4),
                      const Text('Pull down to refresh',
                          style: TextStyle(
                              fontSize: 12, color: _kTextMuted)),
                    ]),
                  )),
                ],

              ]),
            ),
          ),
        ],
      ),
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  HEADER  — matches HomeScreen flat white header style
  // ════════════════════════════════════════════════════════════════════
  Widget _buildHeader(BuildContext context) {
    return Container(
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
              // ── Title row: icon + title + action button ──
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Icon badge
                  Container(
                    width: 34, height: 34,
                    decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: _kPrimary.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.explore_rounded,
                        color: _kPrimary, size: 17),
                  ),
                  const SizedBox(width: 8),
                  // Title + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Find a Doctor',
                            style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: _kTextPrimary)),
                        const SizedBox(height: 1),
                        const Text('Book appointments near you',
                            style: TextStyle(
                                fontSize: 11,
                                color: _kTextSecondary)),
                      ],
                    ),
                  ),
                  // Notification button
                  // _HeaderBtn(
                  //   icon: Icons.notifications_outlined,
                  //   badge: true,
                  //   onTap: () {},
                  // ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Search bar — matches HomeScreen style ──
              GestureDetector(
                onTap: () => _goToSearch(context),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(children: [
                    const Icon(Icons.search_rounded,
                        color: _kTextMuted, size: 17),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Search doctors, specialties…',
                        style: TextStyle(
                            color: _kTextMuted, fontSize: 13),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 4),
                      decoration: BoxDecoration(
                          color: _kPrimaryLight,
                          borderRadius: BorderRadius.circular(6)),
                      child: const Text('Search',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: _kPrimary)),
                    ),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Recent Doctors horizontal list ──────────────────────────────────
  Widget _buildRecentDoctors(
      BuildContext context, List<DoctorDetails> docs) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _RecentDoctorCard(
          doctor: docs[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => BookAppointmentScreen(doctor: docs[i])),
          ),
        ),
      ),
    );
  }

  // ── Nearby Doctors horizontal list ──────────────────────────────────
  Widget _buildNearbyDoctors(
      BuildContext context, List<DoctorDetails> docs) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = docs[i];
          double? distKm;
          if (_position != null &&
              d.latitude != null &&
              d.longitude != null) {
            distKm = _haversineKm(_position!.latitude,
                _position!.longitude, d.latitude!, d.longitude!);
          }
          return _NearbyDoctorCard(
            doctor: d,
            distanceKm: distKm,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => BookAppointmentScreen(doctor: d)),
            ),
          );
        },
      ),
    );
  }

  // ── Specialty grid ───────────────────────────────────────────────────
  Widget _buildSpecialtyGrid(
      BuildContext context, List<String> specialties) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemCount: specialties.length,
      itemBuilder: (_, i) => _SpecialtyTile(
        name: specialties[i],
        onTap: () => _goToSearch(context, specialty: specialties[i]),
      ),
    );
  }

  Widget _buildSpecialtyShimmerGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.1,
      ),
      itemCount: 6,
      itemBuilder: (_, __) => _ShimmerBox(
        borderRadius: BorderRadius.circular(12),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HEADER BUTTON  — identical to HomeScreen
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
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _kBorder),
            ),
            child: Icon(icon, color: _kTextPrimary, size: 17),
          ),
          if (badge)
            Positioned(
              right: 7, top: 7,
              child: Container(
                width: 7, height: 7,
                decoration: const BoxDecoration(
                    color: _kWarning, shape: BoxShape.circle),
              ),
            ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SECTION TITLE  — matches HomeScreen _SectionTitle
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title,
      {this.subtitle, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 11, color: _kTextMuted)),
                ],
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _kPrimary)),
            ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════
//  RECENT DOCTOR CARD
// ════════════════════════════════════════════════════════════════════
class _RecentDoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final VoidCallback onTap;
  const _RecentDoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent    = _accentFor(doctor.specialization);
    final bg        = _bgFor(doctor.specialization);
    final initials  = _initials(doctor.name);
    final shortName = doctor.name?.replaceFirst(RegExp(r'^Dr\.\s*'), '')
        ?? doctor.name ?? 'Unknown';
    final spec      = doctor.specialization ?? '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 130,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar circle with initials
            Container(
              width: 52, height: 52,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border:
                    Border.all(color: accent.withOpacity(0.2), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ),
            const SizedBox(height: 8),
            Text(shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary)),
            const SizedBox(height: 2),
            Text(spec,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 10, color: _kTextMuted)),
            const SizedBox(height: 7),
            // Experience row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.work_history_rounded, size: 11, color: accent),
                const SizedBox(width: 3),
                Text(
                  doctor.experience != null
                      ? '${doctor.experience}y exp'
                      : 'Doctor',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: _kTextSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  NEARBY DOCTOR CARD
// ════════════════════════════════════════════════════════════════════
class _NearbyDoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final double?       distanceKm;
  final VoidCallback  onTap;
  const _NearbyDoctorCard(
      {required this.doctor,
      required this.distanceKm,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent    = _accentFor(doctor.specialization);
    final bg        = _bgFor(doctor.specialization);
    final isOpen    = doctor.isQueueAvailable == 1;
    final distLabel = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)} km'
        : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + availability badge row
            Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.local_hospital_rounded,
                    color: accent, size: 17),
              ),
              const Spacer(),
              if (doctor.isQueueAvailable != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen ? _kGreenLight : _kRedLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                          color: isOpen ? _kSuccess : _kError,
                          shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 4),
                    Text(isOpen ? 'Open' : 'Closed',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: isOpen ? _kSuccess : _kError)),
                  ]),
                ),
            ]),
            const SizedBox(height: 8),
            // Doctor name
            Text(doctor.name ?? 'Unknown Doctor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextPrimary)),
            const SizedBox(height: 3),
            // Address
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  size: 10, color: _kTextMuted),
              const SizedBox(width: 2),
              Expanded(
                child: Text(
                    doctor.clinicAddress ??
                        doctor.clinicName ??
                        'Address unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 10, color: _kTextMuted)),
              ),
            ]),
            const SizedBox(height: 8),
            // Distance + specialty tags
            Row(children: [
              if (distLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.near_me_rounded,
                        size: 10, color: _kPrimary),
                    const SizedBox(width: 3),
                    Text(distLabel,
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _kPrimary)),
                  ]),
                ),
                const SizedBox(width: 6),
              ],
              if (doctor.specialization != null)
                Expanded(
                  child: Text(doctor.specialization!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 10, color: _kTextMuted)),
                ),
            ]),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY TILE  (grid item)
// ════════════════════════════════════════════════════════════════════
class _SpecialtyTile extends StatelessWidget {
  final String name;
  final VoidCallback onTap;
  const _SpecialtyTile({required this.name, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(name);
    final bg     = _bgFor(name);
    final icon   = _iconFor(name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: accent.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.15)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: accent, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary)),
                const SizedBox(height: 2),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 9, color: _kTextMuted),
                  const SizedBox(width: 2),
                  const Text('See doctors',
                      style:
                          TextStyle(fontSize: 10, color: _kTextMuted)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SHIMMER HELPERS
// ════════════════════════════════════════════════════════════════════
class _ShimmerBox extends StatefulWidget {
  final double? width;
  final BorderRadius borderRadius;
  const _ShimmerBox({this.width, required this.borderRadius});

  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: widget.width,
          decoration: BoxDecoration(
            color: Color.lerp(
                const Color(0xFFEDF2F7),
                const Color(0xFFC8D6E5),
                _anim.value),
            borderRadius: widget.borderRadius,
          ),
        ),
      );
}

class _HorizontalShimmer extends StatelessWidget {
  final double height;
  final double itemWidth;
  const _HorizontalShimmer(
      {required this.height, required this.itemWidth});

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 10),
          itemBuilder: (_, __) => _ShimmerBox(
            width: itemWidth,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      );
}


