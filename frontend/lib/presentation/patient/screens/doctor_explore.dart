// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:geolocator/geolocator.dart';
// import 'package:qless/domain/models/doctor_details.dart';
// import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
// import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
// import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
// import 'package:qless/presentation/patient/screens/location_services.dart';
// import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// // ── Colour palette (mirrors home_screen.dart) ─────────────────────────────────
// const _kPrimary      = Color(0xFF26C6B0);
// const _kPrimaryLight = Color(0xFFD9F5F1);
// const kPageBg = Color(0xFFF8F9FB);

// const _kTextPrimary   = Color(0xFF2D3748);
// const _kTextSecondary = Color(0xFF718096);
// const _kTextMuted     = Color(0xFFA0AEC0);

// const _kBorder  = Color(0xFFEDF2F7);
// const _kError      = Color(0xFFFC8181);
// const _kRedLight   = Color(0xFFFEE2E2);
// const _kSuccess    = Color(0xFF68D391);
// const _kGreenLight = Color(0xFFDCFCE7);
// const _kWarning    = Color(0xFFF6AD55);
// const _kAmberLight = Color(0xFFFEF3C7);
// const _kPurple     = Color(0xFF9F7AEA);
// const _kPurpleLight = Color(0xFFEDE9FE);
// const _kInfo       = Color(0xFF3B82F6);
// const _kInfoLight  = Color(0xFFDBEAFE);

// // ── Specialty → colour helpers (hash-based) ───────────────────────────────────
// const _kAccentPalette = [
//   Color(0xFFFC8181),
//   Color(0xFFF6AD55),
//   Color(0xFF68D391),
//   Color(0xFF9F7AEA),
//   Color(0xFF3B82F6),
//   Color(0xFF26C6B0),
//   Color(0xFFF687B3),
//   Color(0xFF4FD1C5),
//   Color(0xFFED8936),
//   Color(0xFF667EEA),
// ];
// const _kBgPalette = [
//   Color(0xFFFEE2E2),
//   Color(0xFFFEF3C7),
//   Color(0xFFDCFCE7),
//   Color(0xFFEDE9FE),
//   Color(0xFFDBEAFE),
//   Color(0xFFD9F5F1),
//   Color(0xFFFED7E2),
//   Color(0xFFE6FFFA),
//   Color(0xFFFEEBC8),
//   Color(0xFFEBF4FF),
// ];
// const _kIconPalette = <IconData>[
//   Icons.favorite_rounded,
//   Icons.face_retouching_natural,
//   Icons.child_care_rounded,
//   Icons.accessibility_new_rounded,
//   Icons.psychology_rounded,
//   Icons.local_hospital_rounded,
//   Icons.pregnant_woman_rounded,
//   Icons.visibility_rounded,
//   Icons.medical_services_rounded,
//   Icons.hearing_rounded,
// ];

// int _hashIndex(String? s, int length) {
//   if (s == null || s.isEmpty) return 0;
//   var h = 0;
//   for (final c in s.toLowerCase().codeUnits) {
//     h = (h * 31 + c) & 0x7fffffff;
//   }
//   return h % length;
// }

// Color    _accentFor(String? s) => _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
// Color    _bgFor(String? s)     => _kBgPalette[_hashIndex(s, _kBgPalette.length)];
// IconData _iconFor(String? s)   => _kIconPalette[_hashIndex(s, _kIconPalette.length)];

// String _initials(String? name) {
//   if (name == null || name.isEmpty) return '?';
//   final parts = name.trim().split(RegExp(r'\s+'));
//   if (parts.length == 1) return parts[0][0].toUpperCase();
//   return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
// }

// double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
//   const r = 6371.0;
//   final dLat = (lat2 - lat1) * pi / 180;
//   final dLon = (lon2 - lon1) * pi / 180;
//   final a = sin(dLat / 2) * sin(dLat / 2) +
//       cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
//       sin(dLon / 2) * sin(dLon / 2);
//   return r * 2 * atan2(sqrt(a), sqrt(1 - a));
// }

// // ════════════════════════════════════════════════════════════════════
// //  EXPLORE SCREEN
// // ════════════════════════════════════════════════════════════════════
// class DoctorExploreScreen extends ConsumerStatefulWidget {
//   const DoctorExploreScreen({super.key});

//   @override
//   ConsumerState<DoctorExploreScreen> createState() =>
//       DoctorExploreScreenState();
// }

// class DoctorExploreScreenState extends ConsumerState<DoctorExploreScreen>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _animCtrl;
//   late List<Animation<double>> _anims;
//   final _searchCtrl = TextEditingController();
//   bool _showAllNearby = false; // Nearby section: 6 shown, rest behind "Show more"
//   bool _showAllFavorites = false; // Favorites: 6 shown, rest behind "View more"
//   final _specialtyKey = GlobalKey();

//   @override
//   void initState() {
//     super.initState();
//     _animCtrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 800));
//     _anims = List.generate(6, (i) => Tween<double>(begin: 0, end: 1).animate(
//       CurvedAnimation(
//         parent: _animCtrl,
//         curve: Interval(i * 0.07, 0.55 + i * 0.06, curve: Curves.easeOut),
//       ),
//     ));
//     _animCtrl.forward();
//     WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
//   }

//   // Called from outside (deep link / "View all specialties") once this
//   // screen is already the active shell tab, since it's kept alive in an
//   // IndexedStack rather than pushed as a standalone route.
//   void scrollToSpecialtySection() => _scrollToSpecialtySection();

//   void _scrollToSpecialtySection() {
//     // Section title renders even during the loading shimmer, so this can fire
//     // right after the first frame instead of waiting on _loadData to finish.
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       final ctx = _specialtyKey.currentContext;
//       if (ctx != null) {
//         Scrollable.ensureVisible(
//           ctx,
//           duration: const Duration(milliseconds: 400),
//           curve: Curves.easeOut,
//         );
//       }
//     });
//   }

//   @override
//   void dispose() {
//     _animCtrl.dispose();
//     _searchCtrl.dispose();
//     super.dispose();
//   }

//   Future<void> _loadData() async {
//     final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
//     await ref.read(doctorsViewModelProvider.notifier).fetchDoctors(patientId);
//     if (!mounted) return;

//     // Fetch favorites for the loaded doctors so the Favorites section can populate
//     if (patientId > 0) {
//       final doctors = ref.read(doctorsViewModelProvider).doctors;
//       ref
//           .read(favoriteViewModelProvider.notifier)
//           .fetchFavoritesForDoctors(patientId, doctors);
//     }

//     // If no location has been set yet, fall back to device GPS
//     if (ref.read(selectedPositionProvider) == null) {
//       final pos = await LocationService.getCurrentPosition();
//       if (pos != null && mounted) {
//         ref.read(selectedPositionProvider.notifier).state = pos;
//       }
//     }
//   }

//   // ── Search filter ───────────────────────────────────────────────────
//   List<DoctorDetails> _applySearch(List<DoctorDetails> docs) {
//     final q = _searchCtrl.text.trim().toLowerCase();
//     if (q.isEmpty) return docs;
//     return docs.where((d) =>
//         (d.name?.toLowerCase().contains(q) ?? false) ||
//         (d.specialization?.toLowerCase().contains(q) ?? false) ||
//         (d.clinicName?.toLowerCase().contains(q) ?? false) ||
//         (d.clinicAddress?.toLowerCase().contains(q) ?? false)
//     ).toList();
//   }

//   void _openBook(BuildContext context, DoctorDetails d) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(builder: (_) => BookAppointmentScreen(doctor: d)),
//     );
//   }

//   List<DoctorDetails> _favoriteDoctors(
//       List<DoctorDetails> all, Map<String, bool> favMap) =>
//       all
//           .where((d) => d.doctorId != null &&
//               favMap['${d.doctorId}_${d.clinicId ?? ''}'] == true)
//           .toList();

//   void _goToSearch(BuildContext context, {String? specialty}) {
//     Navigator.push(
//       context,
//       MaterialPageRoute(
//         builder: (_) => DoctorSearchScreen(initialSpecialty: specialty),
//       ),
//     );
//   }

//   // ── Derived lists ──────────────────────────────────────────────────

//   List<DoctorDetails> _recentDoctors(List<DoctorDetails> all) =>
//       all.where((d) => d.isRecentlyVisited == 1).take(10).toList();

//   // Doctors farther than this from the selected location are treated as a
//   // different city and excluded — keeps the list to "this city's" doctors
//   // instead of padding it with doctors from wherever else has any nearby fix.
//   static const double _cityRadiusKm = 30;

//   List<DoctorDetails> _nearbyDoctors(List<DoctorDetails> all, Position? position) {
//     if (position == null) return [];
//     final withDist = all
//         .where((d) => d.latitude != null && d.longitude != null)
//         .map((d) => MapEntry(
//               d,
//               _haversineKm(position.latitude, position.longitude,
//                   d.latitude!, d.longitude!),
//             ))
//         .where((e) => e.value <= _cityRadiusKm)
//         .toList()
//       ..sort((a, b) => a.value.compareTo(b.value));
//     return withDist.map((e) => e.key).toList();
//   }

//   List<String> _uniqueSpecialties(List<DoctorDetails> all) {
//     final seen = <String>{};
//     final result = <String>[];
//     for (final d in all) {
//       final s = d.specialization?.trim();
//       if (s != null && s.isNotEmpty && seen.add(s.toLowerCase())) {
//         result.add(s);
//       }
//     }
//     return result;
//   }

//   Widget _fade(int i, Widget child) => AnimatedBuilder(
//         animation: _anims[i],
//         builder: (_, w) => Opacity(
//           opacity: _anims[i].value,
//           child: Transform.translate(
//               offset: Offset(0, 14 * (1 - _anims[i].value)), child: w),
//         ),
//         child: child,
//       );

//   // ════════════════════════════════════════════════════════════════════
//   //  BUILD
//   // ════════════════════════════════════════════════════════════════════
//   @override
//   Widget build(BuildContext context) {
//     // On first login patientId loads from storage asynchronously, so the
//     // initState _loadData() can run with id 0 (empty doctors/favorites until a
//     // manual refresh). Re-run the load the moment a real patientId arrives.
//     ref.listen(
//       patientLoginViewModelProvider.select((s) => s.patientId),
//       (prev, next) {
//         if ((prev == null || prev == 0) && next != null && next != 0) {
//           _loadData();
//         }
//       },
//     );

//     final state       = ref.watch(doctorsViewModelProvider);
//     final position    = ref.watch(selectedPositionProvider);
//     final favMap      = ref.watch(favoriteViewModelProvider).doctorFavorites;
//     final allDoctors  = state.doctors;
//     final doctors     = _applySearch(allDoctors);
//     final isLoading   = state.isLoading;
//     final recent      = _recentDoctors(doctors);
//     final nearby      = _nearbyDoctors(doctors, position);
//     final favorites   = _favoriteDoctors(doctors, favMap);
//     final specialties = _uniqueSpecialties(doctors);

//     return Scaffold(
//       backgroundColor: kPageBg,
//       body: Column(
//         children: [
//           _fade(0, _buildHeader()),
//           Expanded(
//             child: RefreshIndicator(
//               color: _kPrimary,
//               onRefresh: _loadData,
//               child: CustomScrollView(
//                 physics: const AlwaysScrollableScrollPhysics(),
//                 slivers: [

//           // ── HEADER ─────────────────────────────────────────────────
//           // ── BODY ───────────────────────────────────────────────────
//                   SliverPadding(
//                     padding: const EdgeInsets.fromLTRB(14, 16, 14, 90),
//                     sliver: SliverList(
//                       delegate: SliverChildListDelegate([

//                 // Favorite Doctors — show 6, rest behind "View more"
//                 if (favorites.isNotEmpty) ...[
//                   _fade(1, _SectionTitle(
//                     'Favorite Doctors',
//                     subtitle: 'Your saved doctors',
//                     action: favorites.length > 6
//                         ? (_showAllFavorites ? 'View less' : 'View more')
//                         : null,
//                     onAction: favorites.length > 6
//                         ? () => setState(() => _showAllFavorites = !_showAllFavorites)
//                         : null,
//                   )),
//                   const SizedBox(height: 10),
//                   _fade(1, _buildFavoriteDoctors(
//                       context,
//                       _showAllFavorites ? favorites : favorites.take(6).toList())),
//                   const SizedBox(height: 22),
//                 ],

//                 // Recent Doctors
//                 if (isLoading || recent.isNotEmpty) ...[
//                   _fade(2, _SectionTitle(
//                     'Recent Doctors',
//                     subtitle: 'Your last visits',
//                   )),
//                   const SizedBox(height: 10),
//                   _fade(2, isLoading
//                       ? const _HorizontalShimmer(height: 200, isRecent: true)
//                       : _buildRecentDoctors(context, recent)),
//                   const SizedBox(height: 22),
//                 ],

//                 // Nearby Doctors — show 6, rest behind "Show more"
//                 if (position != null && (isLoading || nearby.isNotEmpty)) ...[
//                   _fade(3, _SectionTitle(
//                     'Nearby Doctors',
//                     subtitle: 'Doctors close to you',
//                     action: (!isLoading && nearby.length > 6)
//                         ? (_showAllNearby ? 'Show less' : 'Show more')
//                         : null,
//                     onAction: (!isLoading && nearby.length > 6)
//                         ? () => setState(() => _showAllNearby = !_showAllNearby)
//                         : null,
//                   )),
//                   const SizedBox(height: 10),
//                   _fade(3, isLoading
//                       ? const _HorizontalShimmer(height: 186, isRecent: false)
//                       : _buildNearbyDoctors(
//                           context,
//                           _showAllNearby ? nearby : nearby.take(6).toList(),
//                           position)),
//                   const SizedBox(height: 22),
//                 ],

//                 // Browse by Specialty
//                 if (isLoading || specialties.isNotEmpty) ...[
//                   KeyedSubtree(
//                     key: _specialtyKey,
//                     child: _fade(4, _SectionTitle(
//                       'Browse by Specialty',
//                       subtitle: 'Find the right specialist',
//                     )),
//                   ),
//                   const SizedBox(height: 10),
//                   _fade(4, isLoading
//                       ? _buildSpecialtyShimmerGrid()
//                       : _buildSpecialtyGrid(context, specialties)),
//                 ],

//                 // Empty state
//                 if (!isLoading && doctors.isEmpty) ...[
//                   const SizedBox(height: 60),
//                   _fade(5, Center(
//                     child: Column(mainAxisSize: MainAxisSize.min, children: [
//                       Container(
//                         width: 60, height: 60,
//                         decoration: BoxDecoration(
//                             color: _kPrimaryLight,
//                             shape: BoxShape.circle),
//                         child: const Icon(Icons.search_off_rounded,
//                             size: 26, color: _kPrimary),
//                       ),
//                       const SizedBox(height: 12),
//                       const Text('No doctors found',
//                           style: TextStyle(
//                               fontSize: 14,
//                               fontWeight: FontWeight.w700,
//                               color: _kTextPrimary)),
//                       const SizedBox(height: 4),
//                       const Text('Pull down to refresh',
//                           style: TextStyle(
//                               fontSize: 12, color: _kTextMuted)),
//                     ]),
//                   )),
//                 ],

//                       ]),
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   // ════════════════════════════════════════════════════════════════════
//   //  HEADER  — matches HomeScreen flat white header style
//   // ════════════════════════════════════════════════════════════════════
//   Widget _buildHeader() {
//     return Container(
//       decoration: const BoxDecoration(
//         color: Colors.white,
//         border: Border(
//           bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1),
//         ),
//       ),
//       child: SafeArea(
//         bottom: false,
//         child: Padding(
//           padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
//           child: AppExpandableHeaderSearch(
//             controller: _searchCtrl,
//             leadingIcon: Icons.explore_rounded,
//             title: 'Find a Doctor',
//             subtitle: 'Book appointments near you',
//             hintText: 'Search doctor, specialty, clinic...',
//             accentColor: _kPrimary,
//             leadingBackgroundColor: _kPrimaryLight,
//             titleColor: _kTextPrimary,
//             subtitleColor: _kTextSecondary,
//             fieldColor: const Color(0xFFF7F8FA),
//             borderColor: _kBorder,
//             iconColor: _kTextMuted,
//             textColor: _kTextPrimary,
//             onChanged: (_) => setState(() {}),
//           ),
//         ),
//       ),
//     );
//   }

//   // ── Recent Doctors horizontal list ──────────────────────────────────
//   Widget _buildRecentDoctors(
//       BuildContext context, List<DoctorDetails> docs) {
//     return SizedBox(
//       height: 200,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: docs.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 10),
//         itemBuilder: (_, i) => _RecentDoctorCard(
//           doctor: docs[i],
//           onTap: () => _openBook(context, docs[i]),
//           onBook: () => _openBook(context, docs[i]),
//         ),
//       ),
//     );
//   }

//   // ── Favorite Doctors horizontal list ────────────────────────────────
//   Widget _buildFavoriteDoctors(
//       BuildContext context, List<DoctorDetails> docs) {
//     return SizedBox(
//       height: 200,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: docs.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 10),
//         itemBuilder: (_, i) => _RecentDoctorCard(
//           doctor: docs[i],
//           onTap: () => _openBook(context, docs[i]),
//           onBook: () => _openBook(context, docs[i]),
//         ),
//       ),
//     );
//   }

//   // ── Nearby Doctors horizontal list ──────────────────────────────────
//   Widget _buildNearbyDoctors(
//       BuildContext context, List<DoctorDetails> docs, Position? position) {
//     return SizedBox(
//       height: 186,
//       child: ListView.separated(
//         scrollDirection: Axis.horizontal,
//         itemCount: docs.length,
//         separatorBuilder: (_, __) => const SizedBox(width: 10),
//         itemBuilder: (_, i) {
//           final d = docs[i];
//           double? distKm;
//           if (position != null &&
//               d.latitude != null &&
//               d.longitude != null) {
//             distKm = _haversineKm(position.latitude,
//                 position.longitude, d.latitude!, d.longitude!);
//           }
//           void book() => Navigator.push(
//                 context,
//                 MaterialPageRoute(
//                     builder: (_) => BookAppointmentScreen(doctor: d)),
//               );
//           return _NearbyDoctorCard(
//             doctor: d,
//             distanceKm: distKm,
//             onTap: book,
//             onBook: book,
//           );
//         },
//       ),
//     );
//   }

//   // ── Specialty grid ───────────────────────────────────────────────────
//   Widget _buildSpecialtyGrid(
//       BuildContext context, List<String> specialties) {
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         mainAxisSpacing: 10,
//         crossAxisSpacing: 10,
//         childAspectRatio: 2.1,
//       ),
//       itemCount: specialties.length,
//       itemBuilder: (_, i) => _SpecialtyTile(
//         name: specialties[i],
//         onTap: () => _goToSearch(context, specialty: specialties[i]),
//       ),
//     );
//   }
// Widget _buildSpecialtyShimmerGrid() {
//     return GridView.builder(
//       shrinkWrap: true,
//       physics: const NeverScrollableScrollPhysics(),
//       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
//         crossAxisCount: 2,
//         mainAxisSpacing: 10,
//         crossAxisSpacing: 10,
//         childAspectRatio: 2.1,
//       ),
//       itemCount: 6,
//       itemBuilder: (_, __) => _ShimmerBox(
//         borderRadius: BorderRadius.circular(12),
//         height: null,
//       ),
//     );
//   }
// } // ← closes _DoctorExploreScreenState



// // ════════════════════════════════════════════════════════════════════
// //  HEADER BUTTON  — identical to HomeScreen
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
//               color: const Color(0xFFF7F8FA),
//               borderRadius: BorderRadius.circular(10),
//               border: Border.all(color: _kBorder),
//             ),
//             child: Icon(icon, color: _kTextPrimary, size: 17),
//           ),
//           if (badge)
//             Positioned(
//               right: 7, top: 7,
//               child: Container(
//                 width: 7, height: 7,
//                 decoration: const BoxDecoration(
//                     color: _kWarning, shape: BoxShape.circle),
//               ),
//             ),
//         ]),
//       );
// }

// // ════════════════════════════════════════════════════════════════════
// //  SECTION TITLE  — matches HomeScreen _SectionTitle
// // ════════════════════════════════════════════════════════════════════
// class _SectionTitle extends StatelessWidget {
//   final String title;
//   final String? subtitle;
//   final String? action;
//   final VoidCallback? onAction;
//   const _SectionTitle(this.title,
//       {this.subtitle, this.action, this.onAction});

//   @override
//   Widget build(BuildContext context) => Row(
//         crossAxisAlignment: CrossAxisAlignment.end,
//         children: [
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(title,
//                     style: const TextStyle(
//                         fontSize: 14,
//                         fontWeight: FontWeight.w700,
//                         color: _kTextPrimary)),
//                 if (subtitle != null) ...[
//                   const SizedBox(height: 1),
//                   Text(subtitle!,
//                       style: const TextStyle(
//                           fontSize: 12, color: _kTextMuted)),
//                 ],
//               ],
//             ),
//           ),
//           if (action != null)
//             GestureDetector(
//               onTap: onAction,
//               child: Text(action!,
//                   style: const TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w600,
//                       color: _kPrimary)),
//             ),
//         ],
//       );
// }

// // ════════════════════════════════════════════════════════════════════
// //  RECENT DOCTOR CARD
// // ════════════════════════════════════════════════════════════════════
// class _RecentDoctorCard extends StatelessWidget {
//   final DoctorDetails doctor;
//   final VoidCallback onTap;
//   final VoidCallback onBook;
//   const _RecentDoctorCard({
//     required this.doctor,
//     required this.onTap,
//     required this.onBook,
//   });

//   @override
//   Widget build(BuildContext context) {
//     final accent    = _accentFor(doctor.specialization);
//     final bg        = _bgFor(doctor.specialization);
//     final initials  = _initials(doctor.name);
//     final shortName = doctor.name?.replaceFirst(RegExp(r'^Dr\.\s*'), '')
//         ?? doctor.name ?? 'Unknown';
//     final spec      = doctor.specialization ?? '';

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 130,
//         decoration: BoxDecoration(
//          color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: _kBorder),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.04),
//                 blurRadius: 10,
//                 offset: const Offset(0, 3)),
//           ],
//         ),
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.center,
//           children: [
//             // Avatar circle with initials
//             Container(
//               width: 52, height: 52,
//               decoration: BoxDecoration(
//                 color: bg,
//                 shape: BoxShape.circle,
//                 border:
//                     Border.all(color: accent.withOpacity(0.2), width: 2),
//               ),
//               alignment: Alignment.center,
//               child: Text(initials,
//                   style: TextStyle(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w700,
//                       color: accent)),
//             ),
//             const SizedBox(height: 8),
//             Text(shortName,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w700,
//                     color: _kTextPrimary)),
//             const SizedBox(height: 2),
//             Text(spec,
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 textAlign: TextAlign.center,
//                 style: const TextStyle(
//                     fontSize: 12, color: _kTextMuted)),
//             const SizedBox(height: 7),
//             // Experience row
//             Row(
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Icon(Icons.work_history_rounded, size: 11, color: accent),
//                 const SizedBox(width: 3),
//                 Text(
//                   doctor.experience != null
//                       ? '${doctor.experience}y exp'
//                       : 'Doctor',
//                   style: const TextStyle(
//                       fontSize: 12,
//                       fontWeight: FontWeight.w500,
//                       color: _kTextSecondary),
//                 ),
//               ],
//             ),
//             const Spacer(),
//             // Book button
//             GestureDetector(
//               onTap: onBook,
//               child: Container(
//                 width: double.infinity,
//                 height: 28,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: _kPrimary,
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow: [
//                     BoxShadow(
//                         color: _kPrimary.withOpacity(0.25),
//                         blurRadius: 6,
//                         offset: const Offset(0, 2)),
//                   ],
//                 ),
//                 child: const Text('Book',
//                     style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════
// //  NEARBY DOCTOR CARD
// // ════════════════════════════════════════════════════════════════════
// class _NearbyDoctorCard extends StatelessWidget {
//   final DoctorDetails doctor;
//   final double?       distanceKm;
//   final VoidCallback  onTap;
//   final VoidCallback  onBook;
//   const _NearbyDoctorCard(
//       {required this.doctor,
//       required this.distanceKm,
//       required this.onTap,
//       required this.onBook});

//   @override
//   Widget build(BuildContext context) {
//     final accent    = _accentFor(doctor.specialization);
//     final bg        = _bgFor(doctor.specialization);
//     final isOnLeave = doctor.isOnLeave == 1;
//     final isOpen    = !isOnLeave && doctor.isQueueAvailable == 1;
//     final distLabel = distanceKm != null
//         ? '${distanceKm!.toStringAsFixed(1)} km'
//         : null;

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         width: 210,
//         decoration: BoxDecoration(
//           color: Colors.white,
//           borderRadius: BorderRadius.circular(14),
//           border: Border.all(color: _kBorder),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.04),
//                 blurRadius: 10,
//                 offset: const Offset(0, 3)),
//           ],
//         ),
//         padding: const EdgeInsets.all(12),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             // Icon + availability badge row
//             Row(children: [
//               Container(
//                 width: 36, height: 36,
//                 decoration: BoxDecoration(
//                     color: bg,
//                     borderRadius: BorderRadius.circular(10)),
//                 child: Icon(Icons.local_hospital_rounded,
//                     color: accent, size: 17),
//               ),
//               const Spacer(),
//               if (isOnLeave || doctor.isQueueAvailable != null)
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 7, vertical: 3),
//                   decoration: BoxDecoration(
//                     color: isOnLeave
//                         ? _kAmberLight
//                         : (isOpen ? _kGreenLight : _kRedLight),
//                     borderRadius: BorderRadius.circular(6),
//                   ),
//                   child: Row(mainAxisSize: MainAxisSize.min, children: [
//                     Container(
//                       width: 5, height: 5,
//                       decoration: BoxDecoration(
//                           color: isOnLeave
//                               ? _kWarning
//                               : (isOpen ? _kSuccess : _kError),
//                           shape: BoxShape.circle),
//                     ),
//                     const SizedBox(width: 4),
//                     Text(
//                         isOnLeave ? 'On Leave' : (isOpen ? 'Open' : 'Closed'),
//                         style: TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: isOnLeave
//                                 ? _kWarning
//                                 : (isOpen ? _kSuccess : _kError))),
//                   ]),
//                 ),
//             ]),
//             const SizedBox(height: 8),
//             // Doctor name
//             Text(doctor.name ?? 'Unknown Doctor',
//                 maxLines: 1,
//                 overflow: TextOverflow.ellipsis,
//                 style: const TextStyle(
//                     fontSize: 13,
//                     fontWeight: FontWeight.w700,
//                     color: _kTextPrimary)),
//             const SizedBox(height: 3),
//             // Address
//             Row(children: [
//               const Icon(Icons.location_on_rounded,
//                   size: 10, color: _kTextMuted),
//               const SizedBox(width: 2),
//               Expanded(
//                 child: Text(
//                     doctor.clinicAddress ??
//                         doctor.clinicName ??
//                         'Address unavailable',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                         fontSize: 12, color: _kTextMuted)),
//               ),
//             ]),
//             const SizedBox(height: 8),
//             // Distance + specialty tags
//             Row(children: [
//               if (distLabel != null) ...[
//                 Container(
//                   padding: const EdgeInsets.symmetric(
//                       horizontal: 7, vertical: 3),
//                   decoration: BoxDecoration(
//                       color: _kPrimaryLight,
//                       borderRadius: BorderRadius.circular(6)),
//                   child: Row(mainAxisSize: MainAxisSize.min, children: [
//                     const Icon(Icons.near_me_rounded,
//                         size: 10, color: _kPrimary),
//                     const SizedBox(width: 3),
//                     Text(distLabel,
//                         style: const TextStyle(
//                             fontSize: 11,
//                             fontWeight: FontWeight.w700,
//                             color: _kPrimary)),
//                   ]),
//                 ),
//                 const SizedBox(width: 6),
//               ],
//               if (doctor.specialization != null)
//                 Expanded(
//                   child: Text(doctor.specialization!,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                           fontSize: 12, color: _kTextMuted)),
//                 ),
//             ]),
//             const Spacer(),
//             // Book button
//             GestureDetector(
//               onTap: onBook,
//               child: Container(
//                 width: double.infinity,
//                 height: 30,
//                 alignment: Alignment.center,
//                 decoration: BoxDecoration(
//                   color: _kPrimary,
//                   borderRadius: BorderRadius.circular(8),
//                   boxShadow: [
//                     BoxShadow(
//                         color: _kPrimary.withOpacity(0.25),
//                         blurRadius: 6,
//                         offset: const Offset(0, 2)),
//                   ],
//                 ),
//                 child: const Text('Book',
//                     style: TextStyle(
//                         fontSize: 11,
//                         fontWeight: FontWeight.w700,
//                         color: Colors.white)),
//               ),
//             ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// // ════════════════════════════════════════════════════════════════════
// //  SPECIALTY TILE  (grid item)
// // ════════════════════════════════════════════════════════════════════
// class _SpecialtyTile extends StatelessWidget {
//   final String name;
//   final VoidCallback onTap;
//   const _SpecialtyTile({required this.name, required this.onTap});

//   @override
//   Widget build(BuildContext context) {
//     final accent = _accentFor(name);
//     final bg     = _bgFor(name);
//     final icon   = _iconFor(name);

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         decoration: BoxDecoration(
//           color: accent.withOpacity(0.08),
//           borderRadius: BorderRadius.circular(12),
//           border: Border.all(color: accent.withOpacity(0.15)),
//           boxShadow: [
//             BoxShadow(
//                 color: Colors.black.withOpacity(0.03),
//                 blurRadius: 8,
//                 offset: const Offset(0, 2)),
//           ],
//         ),
//         padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//         child: Row(children: [
//           Container(
//             width: 34, height: 34,
//             decoration: BoxDecoration(
//               color: bg,
//               borderRadius: BorderRadius.circular(9),
//             ),
//             child: Icon(icon, color: accent, size: 17),
//           ),
//           const SizedBox(width: 10),
//           Expanded(
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               mainAxisAlignment: MainAxisAlignment.center,
//               children: [
//                 Text(name,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                         fontSize: 12,
//                         fontWeight: FontWeight.w700,
//                         color: _kTextPrimary)),
//                 const SizedBox(height: 2),
//                 Row(mainAxisSize: MainAxisSize.min, children: [
//                   const Icon(Icons.arrow_forward_ios_rounded,
//                       size: 9, color: _kTextMuted),
//                   const SizedBox(width: 2),
//                   const Text('See doctors',
//                       style:
//                           TextStyle(fontSize: 10, color: _kTextMuted)),
//                 ]),
//               ],
//             ),
//           ),
//         ]),
//       ),
//     );
//   }
// }
// class _ShimmerBox extends StatefulWidget {
//   final double? width;
//   final double? height;
//   final BorderRadius borderRadius;
//   const _ShimmerBox({this.width, this.height, required this.borderRadius});

//   @override
//   State<_ShimmerBox> createState() => _ShimmerBoxState();
// }

// class _ShimmerBoxState extends State<_ShimmerBox>
//     with SingleTickerProviderStateMixin {
//   late AnimationController _ctrl;
//   late Animation<double> _anim;

//   @override
//   void initState() {
//     super.initState();
//     _ctrl = AnimationController(
//         vsync: this, duration: const Duration(milliseconds: 1300))
//       ..repeat();
//     _anim = Tween<double>(begin: -2.0, end: 2.0)
//         .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
//   }

//   @override
//   void dispose() { _ctrl.dispose(); super.dispose(); }

//   @override
//   Widget build(BuildContext context) => AnimatedBuilder(
//         animation: _anim,
//         builder: (_, __) => Container(
//           width: widget.width,
//           height: widget.height,
//           decoration: BoxDecoration(
//             borderRadius: widget.borderRadius,
//             gradient: LinearGradient(
//               begin: Alignment(_anim.value - 1, 0),
//               end: Alignment(_anim.value + 1, 0),
//               colors: const [
//                 Color(0xFFEDF2F7),
//                 Color(0xFFE2E8F0),
//                 Color(0xFFCBD5E0),
//                 Color(0xFFE2E8F0),
//                 Color(0xFFEDF2F7),
//               ],
//             ),
//           ),
//         ),
//       );
// }

// // Skeleton for Recent Doctor card (130×200, includes Book button)
// class _RecentDoctorSkeleton extends StatelessWidget {
//   const _RecentDoctorSkeleton();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 130,
//       decoration: BoxDecoration(
//         color: Colors.white,
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _kBorder),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
//       ),
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.center,
//         children: [
//           // Avatar circle
//           _ShimmerBox(width: 52, height: 52, borderRadius: BorderRadius.circular(26)),
//           const SizedBox(height: 10),
//           // Name line
//           _ShimmerBox(width: 90, height: 11, borderRadius: BorderRadius.circular(6)),
//           const SizedBox(height: 6),
//           // Specialty line
//           _ShimmerBox(width: 65, height: 9, borderRadius: BorderRadius.circular(6)),
//           const SizedBox(height: 10),
//           // Experience row
//           _ShimmerBox(width: 70, height: 9, borderRadius: BorderRadius.circular(6)),
//           const Spacer(),
//           // Book button placeholder
//           _ShimmerBox(height: 28, borderRadius: BorderRadius.circular(8)),
//         ],
//       ),
//     );
//   }
// }

// // Skeleton for Nearby Doctor card (210×148)
// class _NearbyDoctorSkeleton extends StatelessWidget {
//   const _NearbyDoctorSkeleton();

//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: 210,
//       decoration: BoxDecoration(
//         color: const Color(0xFFF7F8FA),
//         borderRadius: BorderRadius.circular(14),
//         border: Border.all(color: _kBorder),
//         boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
//       ),
//       padding: const EdgeInsets.all(12),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           // Icon + badge row
//           Row(children: [
//             _ShimmerBox(width: 36, height: 36, borderRadius: BorderRadius.circular(10)),
//             const Spacer(),
//             _ShimmerBox(width: 55, height: 22, borderRadius: BorderRadius.circular(6)),
//           ]),
//           const SizedBox(height: 10),
//           // Doctor name
//           _ShimmerBox(height: 13, borderRadius: BorderRadius.circular(6)),
//           const SizedBox(height: 6),
//           // Address
//           _ShimmerBox(width: 140, height: 10, borderRadius: BorderRadius.circular(6)),
//           const SizedBox(height: 10),
//           // Distance + specialty tags
//           Row(children: [
//             _ShimmerBox(width: 60, height: 22, borderRadius: BorderRadius.circular(6)),
//             const SizedBox(width: 8),
//             _ShimmerBox(width: 80, height: 10, borderRadius: BorderRadius.circular(6)),
//           ]),
//         ],
//       ),
//     );
//   }
// }

// class _HorizontalShimmer extends StatelessWidget {
//   final double height;
//   final bool isRecent;
//   const _HorizontalShimmer({
//     required this.height,
//     this.isRecent = false,
//   });

//   @override
//   Widget build(BuildContext context) => SizedBox(
//         height: height,
//         child: ListView.separated(
//           scrollDirection: Axis.horizontal,
//           physics: const BouncingScrollPhysics(),
//           padding: const EdgeInsets.only(right: 4),
//           itemCount: 4,
//           separatorBuilder: (_, __) => const SizedBox(width: 10),
//           itemBuilder: (_, __) =>
//               isRecent ? const _RecentDoctorSkeleton() : const _NearbyDoctorSkeleton(),
//         ),
//       );
// }

import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ── Colour palette (mirrors home_screen.dart) ─────────────────────────────────
const _kPrimary       = Color(0xFF26C6B0);
const _kPrimaryDark   = Color(0xFF1AA893);
const _kPrimaryLight  = Color(0xFFD9F5F1);
const kPageBg         = Color(0xFFF8F9FB);

const _kTextPrimary   = Color(0xFF2D3748);
const _kTextSecondary = Color(0xFF718096);
const _kTextMuted     = Color(0xFFA0AEC0);

const _kBorder      = Color(0xFFEDF2F7);
const _kError       = Color(0xFFFC8181);
const _kRedLight    = Color(0xFFFEE2E2);
const _kSuccess     = Color(0xFF68D391);
const _kGreenLight  = Color(0xFFDCFCE7);
const _kWarning     = Color(0xFFF6AD55);
const _kAmberLight  = Color(0xFFFEF3C7);
const _kPurple      = Color(0xFF9F7AEA);
const _kPurpleLight = Color(0xFFEDE9FE);
const _kInfo        = Color(0xFF3B82F6);
const _kInfoLight   = Color(0xFFDBEAFE);

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
      DoctorExploreScreenState();
}

class DoctorExploreScreenState extends ConsumerState<DoctorExploreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _anims;
  final _searchCtrl = TextEditingController();
  bool _showAllNearby = false; // Nearby section: 6 shown, rest behind "Show more"
  bool _showAllFavorites = false; // Favorites: 6 shown, rest behind "View more"
  final _specialtyKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    _anims = List.generate(6, (i) => Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animCtrl,
        curve: Interval(i * 0.07, 0.55 + i * 0.06, curve: Curves.easeOut),
      ),
    ));
    _animCtrl.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  // Called from outside (deep link / "View all specialties") once this
  // screen is already the active shell tab, since it's kept alive in an
  // IndexedStack rather than pushed as a standalone route.
  void scrollToSpecialtySection() => _scrollToSpecialtySection();

  void _scrollToSpecialtySection() {
    // Section title renders even during the loading shimmer, so this can fire
    // right after the first frame instead of waiting on _loadData to finish.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _specialtyKey.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    await ref.read(doctorsViewModelProvider.notifier).fetchDoctors(patientId);
    if (!mounted) return;

    // Fetch favorites for the loaded doctors so the Favorites section can populate
    if (patientId > 0) {
      final doctors = ref.read(doctorsViewModelProvider).doctors;
      ref
          .read(favoriteViewModelProvider.notifier)
          .fetchFavoritesForDoctors(patientId, doctors);
    }

    // If no location has been set yet, fall back to device GPS
    if (ref.read(selectedPositionProvider) == null) {
      final pos = await LocationService.getCurrentPosition();
      if (pos != null && mounted) {
        ref.read(selectedPositionProvider.notifier).state = pos;
      }
    }
  }

  // ── Search filter ───────────────────────────────────────────────────
  List<DoctorDetails> _applySearch(List<DoctorDetails> docs) {
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return docs;
    return docs.where((d) =>
        (d.name?.toLowerCase().contains(q) ?? false) ||
        (d.specialization?.toLowerCase().contains(q) ?? false) ||
        (d.clinicName?.toLowerCase().contains(q) ?? false) ||
        (d.clinicAddress?.toLowerCase().contains(q) ?? false)
    ).toList();
  }

  void _openBook(BuildContext context, DoctorDetails d) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookAppointmentScreen(doctor: d)),
    );
  }

  List<DoctorDetails> _favoriteDoctors(
      List<DoctorDetails> all, Map<String, bool> favMap) =>
      all
          .where((d) => d.doctorId != null &&
              favMap['${d.doctorId}_${d.clinicId ?? ''}'] == true)
          .toList();

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

  // Doctors farther than this from the selected location are treated as a
  // different city and excluded — keeps the list to "this city's" doctors
  // instead of padding it with doctors from wherever else has any nearby fix.
  static const double _cityRadiusKm = 30;

  List<DoctorDetails> _nearbyDoctors(List<DoctorDetails> all, Position? position) {
    if (position == null) return [];
    final withDist = all
        .where((d) => d.latitude != null && d.longitude != null)
        .map((d) => MapEntry(
              d,
              _haversineKm(position.latitude, position.longitude,
                  d.latitude!, d.longitude!),
            ))
        .where((e) => e.value <= _cityRadiusKm)
        .toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    return withDist.map((e) => e.key).toList();
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
    // On first login patientId loads from storage asynchronously, so the
    // initState _loadData() can run with id 0 (empty doctors/favorites until a
    // manual refresh). Re-run the load the moment a real patientId arrives.
    ref.listen(
      patientLoginViewModelProvider.select((s) => s.patientId),
      (prev, next) {
        if ((prev == null || prev == 0) && next != null && next != 0) {
          _loadData();
        }
      },
    );

    final state       = ref.watch(doctorsViewModelProvider);
    final position    = ref.watch(selectedPositionProvider);
    final favMap      = ref.watch(favoriteViewModelProvider).doctorFavorites;
    final allDoctors  = state.doctors;
    final doctors     = _applySearch(allDoctors);
    final isLoading   = state.isLoading;
    final recent      = _recentDoctors(doctors);
    final nearby      = _nearbyDoctors(doctors, position);
    final favorites   = _favoriteDoctors(doctors, favMap);
    final specialties = _uniqueSpecialties(doctors);

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(
        children: [
          _fade(0, _buildHeader()),
          Expanded(
            child: RefreshIndicator(
              color: _kPrimary,
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(14, 18, 14, 90),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([

                // Favorite Doctors — show 6, rest behind "View more"
                if (favorites.isNotEmpty) ...[
                  _fade(1, _SectionTitle(
                    'Favorite Doctors',
                    subtitle: 'Your saved doctors',
                    icon: Icons.favorite_rounded,
                    iconColor: _kError,
                    iconBg: _kRedLight,
                    action: favorites.length > 6
                        ? (_showAllFavorites ? 'View less' : 'View more')
                        : null,
                    onAction: favorites.length > 6
                        ? () => setState(() => _showAllFavorites = !_showAllFavorites)
                        : null,
                  )),
                  const SizedBox(height: 12),
                  _fade(1, _buildFavoriteDoctors(
                      context,
                      _showAllFavorites ? favorites : favorites.take(6).toList())),
                  const SizedBox(height: 26),
                ],

                // Recent Doctors
                if (isLoading || recent.isNotEmpty) ...[
                  _fade(2, _SectionTitle(
                    'Recent Doctors',
                    subtitle: 'Your last visits',
                    icon: Icons.history_rounded,
                    iconColor: _kInfo,
                    iconBg: _kInfoLight,
                  )),
                  const SizedBox(height: 12),
                  _fade(2, isLoading
                      ? const _HorizontalShimmer(height: 206, isRecent: true)
                      : _buildRecentDoctors(context, recent)),
                  const SizedBox(height: 26),
                ],

                // Nearby Doctors — show 6, rest behind "Show more"
                if (position != null && (isLoading || nearby.isNotEmpty)) ...[
                  _fade(3, _SectionTitle(
                    'Nearby Doctors',
                    subtitle: 'Doctors close to you',
                    icon: Icons.near_me_rounded,
                    iconColor: _kPrimaryDark,
                    iconBg: _kPrimaryLight,
                    action: (!isLoading && nearby.length > 6)
                        ? (_showAllNearby ? 'Show less' : 'Show more')
                        : null,
                    onAction: (!isLoading && nearby.length > 6)
                        ? () => setState(() => _showAllNearby = !_showAllNearby)
                        : null,
                  )),
                  const SizedBox(height: 12),
                  _fade(3, isLoading
                      ? const _HorizontalShimmer(height: 196, isRecent: false)
                      : _buildNearbyDoctors(
                          context,
                          _showAllNearby ? nearby : nearby.take(6).toList(),
                          position)),
                  const SizedBox(height: 26),
                ],

                // Browse by Specialty
                if (isLoading || specialties.isNotEmpty) ...[
                  KeyedSubtree(
                    key: _specialtyKey,
                    child: _fade(4, _SectionTitle(
                      'Browse by Specialty',
                      subtitle: 'Find the right specialist',
                      icon: Icons.grid_view_rounded,
                      iconColor: _kPurple,
                      iconBg: _kPurpleLight,
                    )),
                  ),
                  const SizedBox(height: 12),
                  _fade(4, isLoading
                      ? _buildSpecialtyShimmerGrid()
                      : _buildSpecialtyGrid(context, specialties)),
                ],

                // Empty state
                if (!isLoading && doctors.isEmpty) ...[
                  const SizedBox(height: 50),
                  _fade(5, _buildEmptyState()),
                ],

                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ════════════════════════════════════════════════════════════════════
  //  HEADER  — soft teal gradient backdrop behind the search field
  // ════════════════════════════════════════════════════════════════════
  Widget _buildHeader() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFFFFF), Color(0xFFF3FBFA)],
        ),
        border: const Border(
          bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1),
        ),
        boxShadow: [
          BoxShadow(
              color: _kPrimary.withOpacity(0.05),
              blurRadius: 16,
              offset: const Offset(0, 6)),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: AppExpandableHeaderSearch(
                  controller: _searchCtrl,
                  leadingIcon: Icons.explore_rounded,
                  title: 'Find a Doctor',
                  subtitle: 'Book appointments near you',
                  hintText: 'Search doctor, specialty, clinic...',
                  accentColor: _kPrimary,
                  leadingBackgroundColor: _kPrimaryLight,
                  titleColor: _kTextPrimary,
                  subtitleColor: _kTextSecondary,
                  fieldColor: const Color(0xFFF7F8FA),
                  borderColor: _kBorder,
                  iconColor: _kTextMuted,
                  textColor: _kTextPrimary,
                  onChanged: (_) => setState(() {}),
                ),
              ),
              const SizedBox(width: 10),
              _HeaderBtn(
                icon: Icons.tune_rounded,
                onTap: () => _goToSearch(context),
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
      height: 206,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _RecentDoctorCard(
          doctor: docs[i],
          onTap: () => _openBook(context, docs[i]),
          onBook: () => _openBook(context, docs[i]),
        ),
      ),
    );
  }

  // ── Favorite Doctors horizontal list ────────────────────────────────
  Widget _buildFavoriteDoctors(
      BuildContext context, List<DoctorDetails> docs) {
    return SizedBox(
      height: 206,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _RecentDoctorCard(
          doctor: docs[i],
          onTap: () => _openBook(context, docs[i]),
          onBook: () => _openBook(context, docs[i]),
          favorited: true,
        ),
      ),
    );
  }

  // ── Nearby Doctors horizontal list ──────────────────────────────────
  Widget _buildNearbyDoctors(
      BuildContext context, List<DoctorDetails> docs, Position? position) {
    return SizedBox(
      height: 196,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: docs.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) {
          final d = docs[i];
          double? distKm;
          if (position != null &&
              d.latitude != null &&
              d.longitude != null) {
            distKm = _haversineKm(position.latitude,
                position.longitude, d.latitude!, d.longitude!);
          }
          void book() => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => BookAppointmentScreen(doctor: d)),
              );
          return _NearbyDoctorCard(
            doctor: d,
            distanceKm: distKm,
            onTap: book,
            onBook: book,
          );
        },
      ),
    );
  }

  // ── Specialty grid ───────────────────────────────────────────────────
  // Height is fixed (not aspect-ratio-derived) so narrow screens (≤320px)
  // don't squeeze the tile shorter than its content needs — that squeeze is
  // what was causing the RenderFlex overflow on small devices.
  static const double _kSpecialtyTileHeight = 68;

  Widget _buildSpecialtyGrid(
      BuildContext context, List<String> specialties) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: tileWidth / _kSpecialtyTileHeight,
          ),
          itemCount: specialties.length,
          itemBuilder: (_, i) => _SpecialtyTile(
            name: specialties[i],
            onTap: () => _goToSearch(context, specialty: specialties[i]),
          ),
        );
      },
    );
  }

  Widget _buildSpecialtyShimmerGrid() {
    return LayoutBuilder(
      builder: (_, constraints) {
        final tileWidth = (constraints.maxWidth - 12) / 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: tileWidth / _kSpecialtyTileHeight,
          ),
          itemCount: 6,
          itemBuilder: (_, __) => _ShimmerBox(
            borderRadius: BorderRadius.circular(14),
            height: null,
          ),
        );
      },
    );
  }

  // ── Empty state ────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 84, height: 84,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kPrimaryLight, _kPrimaryLight.withOpacity(0.4)],
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.search_off_rounded,
              size: 34, color: _kPrimary),
        ),
        const SizedBox(height: 16),
        const Text('No doctors found',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: _kTextPrimary)),
        const SizedBox(height: 4),
        const Text('Pull down to refresh, or try a different search',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: _kTextMuted)),
      ]),
    );
  }
} // ← closes _DoctorExploreScreenState

// ════════════════════════════════════════════════════════════════════
//  HEADER BUTTON  — soft rounded square, teal-tinted on tap
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
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: _kPrimaryLight,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: _kPrimary.withOpacity(0.15)),
            ),
            child: Icon(icon, color: _kPrimaryDark, size: 19),
          ),
          if (badge)
            Positioned(
              right: 8, top: 8,
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
//  SECTION TITLE  — icon badge + label, matches HomeScreen conventions
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Color? iconColor;
  final Color? iconBg;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title,
      {this.subtitle, this.icon, this.iconColor, this.iconBg, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: iconBg ?? _kPrimaryLight,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 16, color: iconColor ?? _kPrimary),
            ),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary,
                        letterSpacing: -0.2)),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(subtitle!,
                      style: const TextStyle(
                          fontSize: 12, color: _kTextMuted)),
                ],
              ],
            ),
          ),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: _kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(action!,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: _kPrimaryDark)),
              ),
            ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════
//  RECENT / FAVORITE DOCTOR CARD
// ════════════════════════════════════════════════════════════════════
class _RecentDoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final VoidCallback onTap;
  final VoidCallback onBook;
  final bool favorited;
  const _RecentDoctorCard({
    required this.doctor,
    required this.onTap,
    required this.onBook,
    this.favorited = false,
  });

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
        width: 138,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Avatar circle with gradient ring + initials
                Container(
                  width: 54, height: 54,
                  padding: const EdgeInsets.all(2.4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [accent, accent.withOpacity(0.4)],
                    ),
                  ),
                  child: Container(
                    decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: Text(initials,
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: accent)),
                  ),
                ),
                if (favorited)
                  Positioned(
                    right: -3, top: -3,
                    child: Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 4),
                        ],
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 12, color: _kError),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 9),
            Text(shortName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary)),
            const SizedBox(height: 2),
            Text(spec,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 11.5, color: _kTextMuted)),
            const SizedBox(height: 8),
            // Experience chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.work_history_rounded, size: 11, color: accent),
                  const SizedBox(width: 3),
                  Text(
                    doctor.experience != null
                        ? '${doctor.experience}y exp'
                        : 'Doctor',
                    style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: accent),
                  ),
                ],
              ),
            ),
            const Spacer(),
            // Book button
            GestureDetector(
              onTap: onBook,
              child: Container(
                width: double.infinity,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimary, _kPrimaryDark],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Text('Book',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
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
  final VoidCallback  onBook;
  const _NearbyDoctorCard(
      {required this.doctor,
      required this.distanceKm,
      required this.onTap,
      required this.onBook});

  @override
  Widget build(BuildContext context) {
    final accent    = _accentFor(doctor.specialization);
    final bg        = _bgFor(doctor.specialization);
    final isOnLeave = doctor.isOnLeave == 1;
    final isOpen    = !isOnLeave && doctor.isQueueAvailable == 1;
    final distLabel = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)} km'
        : null;
    final statusColor = isOnLeave ? _kWarning : (isOpen ? _kSuccess : _kError);
    final statusBg     = isOnLeave ? _kAmberLight : (isOpen ? _kGreenLight : _kRedLight);
    final statusLabel  = isOnLeave ? 'On Leave' : (isOpen ? 'Open' : 'Closed');

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 216,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.045),
                blurRadius: 14,
                offset: const Offset(0, 5)),
          ],
        ),
        padding: const EdgeInsets.all(13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon + availability badge row
            Row(children: [
              Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(11)),
                child: Icon(Icons.local_hospital_rounded,
                    color: accent, size: 18),
              ),
              const Spacer(),
              if (isOnLeave || doctor.isQueueAvailable != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    if (isOpen)
                      _PulseDot(color: statusColor)
                    else
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                            color: statusColor, shape: BoxShape.circle),
                      ),
                    const SizedBox(width: 5),
                    Text(statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: statusColor)),
                  ]),
                ),
            ]),
            const SizedBox(height: 10),
            // Doctor name
            Text(doctor.name ?? 'Unknown Doctor',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: _kTextPrimary)),
            const SizedBox(height: 4),
            // Address
            Row(children: [
              const Icon(Icons.location_on_rounded,
                  size: 11, color: _kTextMuted),
              const SizedBox(width: 3),
              Expanded(
                child: Text(
                    doctor.clinicAddress ??
                        doctor.clinicName ??
                        'Address unavailable',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 12, color: _kTextMuted)),
              ),
            ]),
            const SizedBox(height: 9),
            // Distance + specialty tags
            Row(children: [
              if (distLabel != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                      color: _kPrimaryLight,
                      borderRadius: BorderRadius.circular(20)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.near_me_rounded,
                        size: 11, color: _kPrimaryDark),
                    const SizedBox(width: 3),
                    Text(distLabel,
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: _kPrimaryDark)),
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
                          fontSize: 12, color: _kTextMuted)),
                ),
            ]),
            const Spacer(),
            // Book button
            GestureDetector(
              onTap: onBook,
              child: Container(
                width: double.infinity,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_kPrimary, _kPrimaryDark],
                  ),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: [
                    BoxShadow(
                        color: _kPrimary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3)),
                  ],
                ),
                child: const Text('Book',
                    style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PULSE DOT  — small animated "live" indicator for open/queue-active status
// ════════════════════════════════════════════════════════════════════
class _PulseDot extends StatefulWidget {
  final Color color;
  const _PulseDot({required this.color});

  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1400))
    ..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 9, height: 9,
        child: AnimatedBuilder(
          animation: _ctrl,
          builder: (_, __) {
            final t = _ctrl.value;
            return Stack(alignment: Alignment.center, children: [
              Opacity(
                opacity: (1 - t).clamp(0.0, 1.0),
                child: Container(
                  width: 9 * (1 + t),
                  height: 9 * (1 + t),
                  decoration: BoxDecoration(
                      color: widget.color, shape: BoxShape.circle),
                ),
              ),
              Container(
                width: 5, height: 5,
                decoration:
                    BoxDecoration(color: widget.color, shape: BoxShape.circle),
              ),
            ]);
          },
        ),
      );
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.035),
                blurRadius: 10,
                offset: const Offset(0, 3)),
          ],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(children: [
          Container(
            width: 38, height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [bg, accent.withOpacity(0.28)],
              ),
              borderRadius: BorderRadius.circular(11),
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
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: _kTextPrimary)),
                const SizedBox(height: 2),
                Row(children: [
                  Flexible(
                    child: Text('See doctors',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: accent)),
                  ),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 9, color: accent),
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
//  SHIMMER PRIMITIVES
// ════════════════════════════════════════════════════════════════════
class _ShimmerBox extends StatefulWidget {
  final double? width;
  final double? height;
  final BorderRadius borderRadius;
  const _ShimmerBox({this.width, this.height, required this.borderRadius});

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
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
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

// Skeleton for Recent Doctor card (138×206, includes Book button)
class _RecentDoctorSkeleton extends StatelessWidget {
  const _RecentDoctorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 138,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _ShimmerBox(width: 54, height: 54, borderRadius: BorderRadius.circular(27)),
          const SizedBox(height: 11),
          _ShimmerBox(width: 90, height: 11, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 6),
          _ShimmerBox(width: 65, height: 9, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 11),
          _ShimmerBox(width: 70, height: 9, borderRadius: BorderRadius.circular(20)),
          const Spacer(),
          _ShimmerBox(height: 30, borderRadius: BorderRadius.circular(10)),
        ],
      ),
    );
  }
}

// Skeleton for Nearby Doctor card (216×196)
class _NearbyDoctorSkeleton extends StatelessWidget {
  const _NearbyDoctorSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 216,
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 3))],
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            _ShimmerBox(width: 38, height: 38, borderRadius: BorderRadius.circular(11)),
            const Spacer(),
            _ShimmerBox(width: 55, height: 22, borderRadius: BorderRadius.circular(20)),
          ]),
          const SizedBox(height: 11),
          _ShimmerBox(height: 13, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 6),
          _ShimmerBox(width: 140, height: 10, borderRadius: BorderRadius.circular(6)),
          const SizedBox(height: 11),
          Row(children: [
            _ShimmerBox(width: 60, height: 22, borderRadius: BorderRadius.circular(20)),
            const SizedBox(width: 8),
            _ShimmerBox(width: 80, height: 10, borderRadius: BorderRadius.circular(6)),
          ]),
        ],
      ),
    );
  }
}

class _HorizontalShimmer extends StatelessWidget {
  final double height;
  final bool isRecent;
  const _HorizontalShimmer({
    required this.height,
    this.isRecent = false,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        height: height,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: 4),
          itemCount: 4,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (_, __) =>
              isRecent ? const _RecentDoctorSkeleton() : const _NearbyDoctorSkeleton(),
        ),
      );
}