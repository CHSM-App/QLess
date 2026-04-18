import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';

// ── Colour palette (mirrors doctors_search_screen.dart) ──────────────────────
const _kPrimary      = Color(0xFF26C6B0);
const _kPrimaryDark  = Color(0xFF2BB5A0);
const _kPrimaryLight = Color(0xFFD9F5F1);

const _kTextPrimary   = Color(0xFF2D3748);
const _kTextSecondary = Color(0xFF718096);
const _kTextMuted     = Color(0xFFA0AEC0);

const _kBorder  = Color(0xFFEDF2F7);

const _kError      = Color(0xFFFC8181);
const _kRedLight   = Color(0xFFFEE2E2);
const _kSuccess    = Color(0xFF68D391);
const _kGreenLight = Color(0xFFDCFCE7);

// ── Specialty → colour helpers (hash-based, works for any string) ─────────────
const _kAccentPalette = [
  Color(0xFFFC8181), // red
  Color(0xFFF6AD55), // amber
  Color(0xFF68D391), // green
  Color(0xFF9F7AEA), // purple
  Color(0xFF3B82F6), // blue
  Color(0xFF26C6B0), // teal
  Color(0xFFF687B3), // pink
  Color(0xFF4FD1C5), // cyan
  Color(0xFFED8936), // orange
  Color(0xFF667EEA), // indigo
];
const _kBgPalette = [
  Color(0xFFFEE2E2), // red light
  Color(0xFFFEF3C7), // amber light
  Color(0xFFDCFCE7), // green light
  Color(0xFFEDE9FE), // purple light
  Color(0xFFDBEAFE), // blue light
  Color(0xFFD9F5F1), // teal light
  Color(0xFFFED7E2), // pink light
  Color(0xFFE6FFFA), // cyan light
  Color(0xFFFEEBC8), // orange light
  Color(0xFFEBF4FF), // indigo light
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

Color _accentFor(String? s) =>
    _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
Color _bgFor(String? s) =>
    _kBgPalette[_hashIndex(s, _kBgPalette.length)];
IconData _iconFor(String? s) =>
    _kIconPalette[_hashIndex(s, _kIconPalette.length)];

String _initials(String? name) {
  if (name == null || name.isEmpty) return '?';
  final parts = name.trim().split(RegExp(r'\s+'));
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}

/// Haversine distance in km.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) *
          cos(lat2 * pi / 180) *
          sin(dLon / 2) *
          sin(dLon / 2);
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

class _DoctorExploreScreenState extends ConsumerState<DoctorExploreScreen> {
  Position? _position;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadData();
    });
  }

  Future<void> _loadData() async {
    final patientId =
        ref.read(patientLoginViewModelProvider).patientId ?? 0;
    await ref
        .read(doctorsViewModelProvider.notifier)
        .fetchDoctors(patientId);

    final pos = await LocationService.getCurrentPosition();
    if (mounted) {
      setState(() => _position = pos);
    }
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

  List<DoctorDetails> _recentDoctors(List<DoctorDetails> all) => all
      .where((d) =>
          d.isRecentlyVisited == 1 || d.isRecentlyVisited == 1)
      .take(10)
      .toList();

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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorsViewModelProvider);
    final doctors = state.doctors;
    final isLoading = state.isLoading;

    final recent = _recentDoctors(doctors);
    final nearby = _nearbyDoctors(doctors);
    final specialties = _uniqueSpecialties(doctors);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: RefreshIndicator(
          color: _kPrimary,
          onRefresh: _loadData,
          child: CustomScrollView(
            slivers: [
              // ── Header ───────────────────────────────────────────
              SliverToBoxAdapter(child: _buildHeader(context)),

              // ── Recent Doctors ───────────────────────────────────
              if (isLoading || recent.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    title: 'Recent Doctors',
                    subtitle: 'Your last visits',
                  ),
                ),
                SliverToBoxAdapter(
                  child: isLoading
                      ? _HorizontalShimmer(height: 170, itemWidth: 130)
                      : _buildRecentDoctors(context, recent),
                ),
              ],

              // ── Nearby Doctors ───────────────────────────────────
              if (_position != null && (isLoading || nearby.isNotEmpty)) ...[
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    title: 'Nearby Doctors',
                    subtitle: 'Doctors close to you',
                    actionLabel: 'See All',
                    onAction: () => _goToSearch(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: isLoading
                      ? _HorizontalShimmer(height: 148, itemWidth: 210)
                      : _buildNearbyDoctors(context, nearby),
                ),
              ],

              // ── Browse by Specialty ──────────────────────────────
              if (isLoading || specialties.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: _sectionHeader(
                    title: 'Browse by Specialty',
                    subtitle: 'Find the right specialist',
                  ),
                ),
                if (isLoading)
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _ShimmerBox(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        childCount: 6,
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 0, 14, 100),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 10,
                        crossAxisSpacing: 10,
                        childAspectRatio: 2.0,
                      ),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => _SpecialtyTile(
                          name: specialties[i],
                          onTap: () =>
                              _goToSearch(context, specialty: specialties[i]),
                        ),
                        childCount: specialties.length,
                      ),
                    ),
                  ),
              ],

              // ── Empty state ──────────────────────────────────────
              if (!isLoading && doctors.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.search_off_rounded,
                            size: 48, color: _kTextMuted),
                        const SizedBox(height: 12),
                        const Text('No doctors found',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: _kTextPrimary)),
                        const SizedBox(height: 4),
                        const Text('Pull down to refresh',
                            style: TextStyle(
                                fontSize: 12, color: _kTextMuted)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [_kPrimary, _kPrimaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      ),
      child:
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Find a Doctor',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3)),
                  SizedBox(height: 2),
                  Text('Book appointments near you',
                      style:
                          TextStyle(color: Colors.white70, fontSize: 12)),
                ]),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_outlined,
                color: Colors.white, size: 18),
          ),
        ]),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => _goToSearch(context),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 2))
              ],
            ),
            child: Row(children: [
              const Icon(Icons.search_rounded,
                  color: _kTextMuted, size: 17),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Search doctors, specialties…',
                    style:
                        TextStyle(fontSize: 13, color: _kTextMuted)),
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
      ]),
    );
  }

  // ── Section header ───────────────────────────────────────────────────

  Widget _sectionHeader({
    required String title,
    required String subtitle,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 10),
      child: Row(children: [
        Expanded(
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: _kTextPrimary,
                        letterSpacing: -0.2)),
                const SizedBox(height: 1),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: _kTextMuted)),
              ]),
        ),
        if (actionLabel != null)
          GestureDetector(
            onTap: onAction,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text(actionLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kPrimary)),
                const SizedBox(width: 3),
                const Icon(Icons.arrow_forward_ios_rounded,
                    size: 10, color: _kPrimary),
              ]),
            ),
          ),
      ]),
    );
  }

  // ── Recent Doctors ─────────────────────────────────────────────────

  Widget _buildRecentDoctors(
      BuildContext context, List<DoctorDetails> doctors) {
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        itemCount: doctors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _RecentDoctorCard(
          doctor: doctors[i],
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookAppointmentScreen(doctor: doctors[i]),
            ),
          ),
        ),
      ),
    );
  }

  // ── Nearby Doctors ──────────────────────────────────────────────────

  Widget _buildNearbyDoctors(
      BuildContext context, List<DoctorDetails> doctors) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        itemCount: doctors.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) {
          final d = doctors[i];
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
                builder: (_) => BookAppointmentScreen(doctor: d),
              ),
            ),
          );
        },
      ),
    );
  }
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
    final accent = _accentFor(doctor.specialization);
    final bg = _bgFor(doctor.specialization);
    final initials = _initials(doctor.name);
    final displayName = doctor.name?.replaceFirst('Dr. ', '') ??
        doctor.name ??
        'Unknown';
    final spec = doctor.specialization ?? '';

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
            // Avatar
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: bg,
                shape: BoxShape.circle,
                border: Border.all(
                    color: accent.withOpacity(0.2), width: 2),
              ),
              alignment: Alignment.center,
              child: Text(initials,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: accent)),
            ),
            const SizedBox(height: 8),
            // Name
            Text(displayName,
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
                Icon(Icons.work_history_rounded,
                    size: 11, color: accent),
                const SizedBox(width: 3),
                Text(
                  doctor.experience != null
                      ? '${doctor.experience}y exp'
                      : 'Doctor',
                  style: TextStyle(
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
  final double? distanceKm;
  final VoidCallback onTap;
  const _NearbyDoctorCard(
      {required this.doctor,
      required this.distanceKm,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final accent = _accentFor(doctor.specialization);
    final bg = _bgFor(doctor.specialization);
    final isOpen = doctor.isQueueAvailable == 1;
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
            // Icon + availability badge
            Row(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(10)),
                child: Icon(Icons.local_hospital_rounded,
                    color: accent, size: 18),
              ),
              const Spacer(),
              if (doctor.isQueueAvailable != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen ? _kGreenLight : _kRedLight,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                              color:
                                  isOpen ? _kSuccess : _kError,
                              shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 4),
                        Text(isOpen ? 'Open' : 'Closed',
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: isOpen
                                    ? _kSuccess
                                    : _kError)),
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
            // Clinic / address
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
            // Distance + specialization
            Row(children: [
              if (distLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(6)),
                  child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
    final bg = _bgFor(name);
    final icon = _iconFor(name);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: accent, size: 18),
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
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: accent)),
                const SizedBox(height: 1),
                Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.arrow_forward_ios_rounded,
                      size: 9, color: _kTextMuted),
                  const SizedBox(width: 2),
                  const Text('See doctors',
                      style: TextStyle(
                          fontSize: 10, color: _kTextMuted)),
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
  const _ShimmerBox(
      {this.width, required this.borderRadius});

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
        vsync: this,
        duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.3, end: 0.7).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
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
}

class _HorizontalShimmer extends StatelessWidget {
  final double height;
  final double itemWidth;
  const _HorizontalShimmer(
      {required this.height, required this.itemWidth});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
        itemCount: 4,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, __) => _ShimmerBox(
          width: itemWidth,
          borderRadius: BorderRadius.circular(14),
        ),
      ),
    );
  }
}
