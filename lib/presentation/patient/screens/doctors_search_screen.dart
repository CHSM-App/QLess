import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/view_models/doctors_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ─── Colour palette ───────────────────────────────────────────────────────────
const kPrimary   = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg        = Color(0xFFF4F6FB);
const kCardBg    = Colors.white;
const kTextDark  = Color(0xFF1F2937);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kRed       = Color(0xFFEA4335);
const kGreen     = Color(0xFF34A853);
const kOrange    = Color(0xFFF59E0B);
const kPurple    = Color(0xFF8B5CF6);
const kCyan      = Color(0xFF06B6D4);

// ─── Dark mode surfaces ───────────────────────────────────────────────────────
const _kDarkSurface = Color(0xFF1E293B);
const _kDarkBg      = Color(0xFF0F172A);

// ─── Specialty → accent colour ────────────────────────────────────────────────
const _specialtyAccent = <String, Color>{
  'cardiology':    Color(0xFFEF4444),
  'dermatology':   Color(0xFFF59E0B),
  'pediatrics':    Color(0xFF10B981),
  'orthopedics':   Color(0xFF8B5CF6),
  'neurology':     Color(0xFF8B5CF6),
  'general':       Color(0xFF06B6D4),
  'gynecology':    Color(0xFFEC4899),
  'ophthalmology': Color(0xFF14B8A6),
};

const _specialtyBgMap = <String, Color>{
  'cardiology':    Color(0xFFFEE2E2),
  'dermatology':   Color(0xFFFEF3C7),
  'pediatrics':    Color(0xFFD1FAE5),
  'orthopedics':   Color(0xFFEDE9FE),
  'neurology':     Color(0xFFEDE9FE),
  'general':       Color(0xFFCFFAFE),
  'gynecology':    Color(0xFFFCE7F3),
  'ophthalmology': Color(0xFFCCFBF1),
};

Color _dssAccentFor(String? spec) =>
    _specialtyAccent[spec?.toLowerCase()] ?? kPrimary;

Color _dssSpecBgFor(String? spec) =>
    _specialtyBgMap[spec?.toLowerCase()] ?? kPrimaryBg;

String _dssCapitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

// ─── Queue status helpers ─────────────────────────────────────────────────────

/// Determines whether the patient can tap "Book" right now.
bool _canBook(DoctorDetails d) {
  // Queue must be explicitly available
  if ((d.isQueueAvailable ?? 0) != 1) return false;
  // Booking session must have started
  if ((d.isBookingStarted ?? 0) != 1) return false;
  // Queue must not be full
  if ((d.isQueueFull ?? 0) == 1) return false;
  return true;
}

/// Compact queue status model used by the card.
class _QueueStatus {
  final bool   queueEnabled;    // isQueueAvailable == 1
  final bool   bookingStarted;  // isBookingStarted == 1
  final bool   isFull;          // isQueueFull == 1
  final bool   canBook;         // combined flag for button enable
  final int?   current;         // currentQueueLength
  final int?   max;             // maxQueueLength
  final String? openAt;         // bookingStartTime (shown when not started yet)

  const _QueueStatus({
    required this.queueEnabled,
    required this.bookingStarted,
    required this.isFull,
    required this.canBook,
    required this.current,
    required this.max,
    required this.openAt,
  });

  factory _QueueStatus.from(DoctorDetails d) {
    final queueEnabled   = (d.isQueueAvailable  ?? 0) == 1;
    final bookingStarted = (d.isBookingStarted   ?? 0) == 1;
    final isFull         = (d.isQueueFull        ?? 0) == 1;
    return _QueueStatus(
      queueEnabled:   queueEnabled,
      bookingStarted: bookingStarted,
      isFull:         isFull,
      canBook:        queueEnabled && bookingStarted && !isFull,
      current:        d.currentQueueLength,
      max:            d.maxQueueLength,
      openAt:         d.bookingStartTime,
    );
  }

  /// Human-readable label shown in the queue pill on the card.
  String get label {
    if (!queueEnabled)   return 'Queue unavailable';
    if (isFull)          return 'Queue full';
    if (!bookingStarted) return openAt != null ? 'Opens $openAt' : 'Not started';
    if (current == null) return 'Queue open';
    if (max != null)     return '$current / $max in queue';
    return '$current in queue';
  }

  /// Pill / icon colour.
  Color get color {
    if (!queueEnabled || isFull) return kRed;
    if (!bookingStarted)         return kOrange;
    if ((current ?? 0) == 0)    return kGreen;
    if ((current ?? 0) <= 5)    return kOrange;
    return kRed;
  }

  IconData get icon {
    if (!queueEnabled)   return Icons.block_rounded;
    if (isFull)          return Icons.people_alt_rounded;
    if (!bookingStarted) return Icons.access_time_rounded;
    return Icons.people_alt_rounded;
  }
}

// ─── Screen ───────────────────────────────────────────────────────────────────
class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedSpecialty;
  int?    _selectedMemberId;
  bool    _hasFetchedDoctors = false;
  bool    _hasFetchedFamily  = false;
  final Set<int> _fetchedFavoriteDoctorIds = <int>{};

  bool      _showFavoritesOnly  = false;
  Position? _userPosition;

  ProviderSubscription<TokenState>?        _tokenSub;
  ProviderSubscription<PatientLoginState>? _patientSub;
  ProviderSubscription<DoctorsState>?      _doctorsSub;

  @override
  void initState() {
    super.initState();
    _tokenSub = ref.listenManual<TokenState>(
      tokenProvider,
      (prev, next) => _tryFetch(),
    );
    _patientSub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) {
        if (prev?.patientId != next.patientId) {
          _fetchedFavoriteDoctorIds.clear();
        }
        _tryFetch();
      },
    );
    _doctorsSub = ref.listenManual<DoctorsState>(
      doctorsViewModelProvider,
      (_, next) => _tryFetchFavorites(next.doctors),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetch());
    _fetchUserPosition();
  }

  Future<void> _fetchUserPosition() async {
    final position = await LocationService.getCurrentPosition();
    if (mounted && position != null) {
      setState(() => _userPosition = position);
    }
  }

  void _tryFetch() {
    final tokenState = ref.read(tokenProvider);
    final tokenReady = !tokenState.isLoading &&
        (tokenState.accessToken ?? '').isNotEmpty;

    if (tokenReady && !_hasFetchedDoctors) {
      _hasFetchedDoctors = true;
      ref.read(doctorsViewModelProvider.notifier).fetchDoctors();
    }

    final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    if (tokenReady && patientId > 0 && !_hasFetchedFamily) {
      _hasFetchedFamily = true;
      ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(patientId);
    }

    _tryFetchFavorites(ref.read(doctorsViewModelProvider).doctors);
  }

  void _tryFetchFavorites(List<DoctorDetails> doctors) {
    final patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    if (patientId <= 0 || doctors.isEmpty) return;

    final favoriteNotifier = ref.read(favoriteViewModelProvider.notifier);
    for (final doctor in doctors) {
      final doctorId = doctor.doctorId;
      if (doctorId == null || !_fetchedFavoriteDoctorIds.add(doctorId)) {
        continue;
      }
      favoriteNotifier.fetchFavoriteStatus(patientId, doctorId);
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tokenSub?.close();
    _patientSub?.close();
    _doctorsSub?.close();
    super.dispose();
  }

  List<DoctorDetails> _filtered(List<DoctorDetails> all) {
    final favoriteIds = ref.read(
      favoriteViewModelProvider.select(
        (state) => state.doctorFavorites.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toSet(),
      ),
    );

    return all.where((d) {
      if (_showFavoritesOnly) {
        final id = d.doctorId;
        if (id == null || !favoriteIds.contains(id)) return false;
      }

      if (_searchController.text.isEmpty &&
          _userPosition != null &&
          d.latitude != null &&
          d.longitude != null) {
        final distanceMeters = Geolocator.distanceBetween(
          _userPosition!.latitude,
          _userPosition!.longitude,
          d.latitude!,
          d.longitude!,
        );
        if (distanceMeters > 100000) return false;
      }

      final q            = _searchController.text.toLowerCase();
      final matchesQuery = _searchController.text.isEmpty ||
          (d.name?.toLowerCase().contains(q) ?? false) ||
          (d.specialization?.toLowerCase().contains(q) ?? false) ||
          (d.clinicName?.toLowerCase().contains(q) ?? false);
      final matchesSpec  = _selectedSpecialty == null ||
          d.specialization?.toLowerCase() == _selectedSpecialty!.toLowerCase();

      return matchesQuery && matchesSpec;
    }).toList();
  }

  List<String> _uniqueSpecialties(List<DoctorDetails> all) {
    final seen = <String>{};
    return all
        .map((d) => d.specialization ?? '')
        .where((s) => s.isNotEmpty && seen.add(s))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final doctorsState = ref.watch(doctorsViewModelProvider);
    final patientState = ref.watch(patientLoginViewModelProvider);
    final familyState  = ref.watch(familyViewModelProvider);
    final isDark       = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? _kDarkBg : kBg,
      body: SafeArea(
        child: Column(
          children: [
            _Header(
              isDark:            isDark,
              showFavoritesOnly: _showFavoritesOnly,
              onFavoritesTap: () => setState(() {
                _showFavoritesOnly = !_showFavoritesOnly;
                if (!_showFavoritesOnly) _selectedSpecialty = null;
              }),
            ),

            if (_showFavoritesOnly)
              _FavoritesBanner(
                onClear: () => setState(() => _showFavoritesOnly = false),
              ),

            familyState.allfamilyMembers.maybeWhen(
              data: (members) => _BookingForDropdown(
                patientState:     patientState,
                members:          members,
                selectedMemberId: _selectedMemberId,
                onSelected:       (id) => setState(() => _selectedMemberId = id),
                isDark:           isDark,
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            _SearchBar(
              controller: _searchController,
              isDark:     isDark,
              onChanged:  (_) => setState(() {}),
            ),

            if (!_showFavoritesOnly && doctorsState.doctors.isNotEmpty) ...[
              _SpecialtyChips(
                specialties: _uniqueSpecialties(doctorsState.doctors),
                selected:    _selectedSpecialty,
                onSelected:  (s) => setState(
                  () => _selectedSpecialty = s == _selectedSpecialty ? null : s,
                ),
              ),
            ],

            if (doctorsState.doctors.isNotEmpty)
              _ResultsBar(
                count:           _filtered(doctorsState.doctors).length,
                isFavoritesMode: _showFavoritesOnly,
              ),

            Expanded(
              child: doctorsState.isLoading
                  ? const _LoadingList()
                  : doctorsState.doctors.isEmpty
                  ? _EmptyState(
                      onRetry: () => ref
                          .read(doctorsViewModelProvider.notifier)
                          .fetchDoctors(),
                    )
                  : _DoctorList(
                      doctors:          _filtered(doctorsState.doctors),
                      isDark:           isDark,
                      selectedMemberId: _selectedMemberId,
                      isFavoritesMode:  _showFavoritesOnly,
                      onRefresh: () => ref
                          .read(doctorsViewModelProvider.notifier)
                          .fetchDoctors(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HEADER
// ─────────────────────────────────────────────────────────────────────────────
class _Header extends ConsumerWidget {
  final bool         isDark;
  final bool         showFavoritesOnly;
  final VoidCallback onFavoritesTap;

  const _Header({
    required this.isDark,
    required this.showFavoritesOnly,
    required this.onFavoritesTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favCount = ref.watch(
      favoriteViewModelProvider.select(
        (state) => state.doctorFavorites.values.where((isFav) => isFav).length,
      ),
    );

    return Container(
      color: isDark ? _kDarkSurface : kCardBg,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Good morning',
                style: TextStyle(
                  fontSize: 11,
                  color: isDark ? Colors.white54 : kTextMid,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                showFavoritesOnly ? 'Favorite Doctors' : 'Find Doctors',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : kTextDark,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
          const Spacer(),
          GestureDetector(
            onTap: onFavoritesTap,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: showFavoritesOnly
                    ? kRed
                    : kRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Center(
                    child: Icon(
                      Icons.favorite_rounded,
                      color: showFavoritesOnly ? Colors.white : kRed,
                      size: 18,
                    ),
                  ),
                  if (!showFavoritesOnly && favCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          color: kRed,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '$favCount',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// FAVORITES BANNER
// ─────────────────────────────────────────────────────────────────────────────
class _FavoritesBanner extends StatelessWidget {
  final VoidCallback onClear;
  const _FavoritesBanner({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kRed.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kRed.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: kRed, size: 13),
          const SizedBox(width: 6),
          const Expanded(
            child: Text(
              'Showing your favorite doctors only',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kRed,
              ),
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Text(
              'Show all',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kPrimary,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING-FOR DROPDOWN
// ─────────────────────────────────────────────────────────────────────────────
class _BookingForDropdown extends StatelessWidget {
  final PatientLoginState  patientState;
  final List<FamilyMember> members;
  final int?               selectedMemberId;
  final ValueChanged<int?> onSelected;
  final bool               isDark;

  const _BookingForDropdown({
    required this.patientState,
    required this.members,
    required this.selectedMemberId,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: kPrimary.withOpacity(0.15),
              child: Text(
                (patientState.name?.isNotEmpty ?? false)
                    ? patientState.name![0].toUpperCase()
                    : 'M',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  patientState.name ?? 'Me',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : kTextDark,
                  ),
                ),
                Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.white38 : kTextMid,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      ...members.map((m) {
        final color = _dssAccentFor(m.relationName);
        return DropdownMenuItem<int?>(
          value: m.memberId,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withOpacity(0.15),
                child: Text(
                  m.memberName?.isNotEmpty == true
                      ? m.memberName![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.memberName ?? '?',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : kTextDark,
                    ),
                  ),
                  if (m.relationName?.isNotEmpty == true)
                    Text(
                      m.relationName!,
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white38 : kTextMid,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: kPrimaryBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.location_on_outlined, color: kPrimary, size: 14),
          const SizedBox(width: 6),
          Text(
            'Booking for',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? Colors.white54 : kTextMid,
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: selectedMemberId,
                isDense: true,
                isExpanded: true,
                icon: const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: kPrimary,
                ),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kPrimary,
                ),
                dropdownColor: isDark ? _kDarkSurface : Colors.white,
                items: items,
                onChanged: onSelected,
                selectedItemBuilder: (_) => [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      patientState.name ?? 'Me',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kPrimary,
                      ),
                    ),
                  ),
                  ...members.map(
                    (m) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        m.memberName ?? 'Member',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kPrimary,
                        ),
                      ),
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
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCH BAR
// ─────────────────────────────────────────────────────────────────────────────
class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String>  onChanged;
  final bool                  isDark;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Container(
        height: 42,
        decoration: BoxDecoration(
          color: isDark ? _kDarkSurface : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, color: kTextMid, size: 17),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                onChanged: onChanged,
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white : kTextDark,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Search name, specialty, clinic…',
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.white30 : const Color(0xFF9CA3AF),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            if (controller.text.isNotEmpty)
              GestureDetector(
                onTap: () {
                  controller.clear();
                  onChanged('');
                },
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.close_rounded, size: 15, color: kTextMid),
                ),
              )
            else
              Container(
                margin: const EdgeInsets.only(right: 8),
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.circular(7),
                ),
                child: const Icon(Icons.tune_rounded, color: Colors.white, size: 13),
              ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPECIALTY CHIPS
// ─────────────────────────────────────────────────────────────────────────────
class _SpecialtyChips extends StatelessWidget {
  final List<String>         specialties;
  final String?              selected;
  final ValueChanged<String> onSelected;

  const _SpecialtyChips({
    required this.specialties,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _Chip(
            label:    'All',
            selected: selected == null,
            accent:   kPrimary,
            bgColor:  kPrimaryBg,
            onTap:    () => onSelected('__all__'),
          ),
          ...specialties.map((s) => _Chip(
                label:    _dssCapitalize(s),
                selected: selected == s,
                accent:   _dssAccentFor(s),
                bgColor:  _dssSpecBgFor(s),
                onTap:    () => onSelected(s),
              )),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String       label;
  final bool         selected;
  final Color        accent;
  final Color        bgColor;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.selected,
    required this.accent,
    required this.bgColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: const EdgeInsets.only(right: 6, top: 3, bottom: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? accent : bgColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accent : accent.withOpacity(0.35),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : accent,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// RESULTS BAR
// ─────────────────────────────────────────────────────────────────────────────
class _ResultsBar extends StatelessWidget {
  final int  count;
  final bool isFavoritesMode;
  const _ResultsBar({required this.count, required this.isFavoritesMode});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 2),
      child: Row(
        children: [
          Text(
            isFavoritesMode
                ? '$count favorite${count == 1 ? '' : 's'} found'
                : '$count doctors available',
            style: const TextStyle(fontSize: 11, color: kTextMid),
          ),
          const Spacer(),
          if (!isFavoritesMode) ...[
            const Icon(Icons.sort_rounded, size: 13, color: kPrimary),
            const SizedBox(width: 3),
            const Text(
              'Sort',
              style: TextStyle(
                fontSize: 11,
                color: kPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR LIST
// ─────────────────────────────────────────────────────────────────────────────
class _DoctorList extends StatelessWidget {
  final List<DoctorDetails>     doctors;
  final bool                    isDark;
  final int?                    selectedMemberId;
  final bool                    isFavoritesMode;
  final Future<void> Function() onRefresh;

  const _DoctorList({
    required this.doctors,
    required this.isDark,
    required this.selectedMemberId,
    required this.isFavoritesMode,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (doctors.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isFavoritesMode
                  ? Icons.favorite_border_rounded
                  : Icons.search_off_rounded,
              size: 44,
              color: kTextMid.withOpacity(0.4),
            ),
            const SizedBox(height: 10),
            Text(
              isFavoritesMode
                  ? 'No favorite doctors yet'
                  : 'No doctors match your search',
              style: const TextStyle(fontSize: 13, color: kTextMid),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: kPrimary,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 20),
        itemCount: doctors.length,
        itemBuilder: (_, i) => _DoctorCard(
          doctor:           doctors[i],
          isDark:           isDark,
          selectedMemberId: selectedMemberId,
          isTopRated:       !isFavoritesMode && i == 0,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR CARD  (queue logic fully driven by _QueueStatus)
// ─────────────────────────────────────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final bool          isDark;
  final int?          selectedMemberId;
  final bool          isTopRated;

  const _DoctorCard({
    required this.doctor,
    required this.isDark,
    required this.selectedMemberId,
    this.isTopRated = false,
  });

  @override
  Widget build(BuildContext context) {
    final accent  = _dssAccentFor(doctor.specialization);
    final specBg  = _dssSpecBgFor(doctor.specialization);
    final initial = (doctor.name?.isNotEmpty ?? false)
        ? doctor.name![0].toUpperCase()
        : 'D';

    // ── Compute queue status from model fields ────────────────────────────
    final qs = _QueueStatus.from(doctor);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // ── Card body ─────────────────────────────────────────────────────
        Container(
          margin: EdgeInsets.only(bottom: 8, top: isTopRated ? 10 : 0),
          decoration: BoxDecoration(
            color: isDark ? _kDarkSurface : kCardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              // Red tint on card border when queue unavailable / full
              color: isTopRated
                  ? kPrimary
                  : (!qs.queueEnabled || qs.isFull)
                      ? kRed.withOpacity(0.25)
                      : kBorder,
              width: isTopRated ? 1.5 : 0.5,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(11, 11, 11, 11),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // ── Avatar ───────────────────────────────────────────────────
              Stack(
                clipBehavior: Clip.none,
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: accent,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  // Small availability dot on avatar
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: qs.canBook ? kGreen : kRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark ? _kDarkSurface : kCardBg,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),

              // ── Info column ──────────────────────────────────────────────
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Name + fee
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dr. ${doctor.name ?? 'Unknown'}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: isDark ? Colors.white : kTextDark,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (doctor.consultationFee != null)
                          Text(
                            '₹${doctor.consultationFee!.toStringAsFixed(0)}',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kGreen,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 3),

                    // Specialty + experience
                    Row(
                      children: [
                        if (doctor.specialization != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: specBg,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              _dssCapitalize(doctor.specialization!),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: accent,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        if (doctor.experience != null)
                          Text(
                            '${doctor.experience} yrs exp',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? Colors.white54 : kTextMid,
                            ),
                          ),
                      ],
                    ),

                    // Clinic name
                    if (doctor.clinicName != null ||
                        doctor.clinicAddress != null) ...[
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          Icon(Icons.local_hospital_rounded,
                              size: 10,
                              color: isDark ? Colors.white38 : kTextMid),
                          const SizedBox(width: 3),
                          Expanded(
                            child: Text(
                              [doctor.clinicName, doctor.clinicAddress]
                                  .where((s) => s != null && s.isNotEmpty)
                                  .join(' · '),
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.white54 : kTextMid,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Queue status pill ──────────────────────────────────
                    // Only rendered when the doctor has queue data at all.
                    // isQueueAvailable == null  → API didn't return queue info → hide
                    // isQueueAvailable == 0     → queue disabled → show "unavailable"
                    // isQueueAvailable == 1     → show rich status
                    if (doctor.isQueueAvailable != null) ...[
                      const SizedBox(height: 5),
                      _QueuePill(qs: qs, isDark: isDark),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),

              // ── Book button ──────────────────────────────────────────────
              // Disabled (greyed out) when booking is not possible.
              SizedBox(
                height: 32,
                child: ElevatedButton(
                  onPressed: qs.canBook
                      ? () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BookAppointmentScreen(
                                doctor:             doctor,
                                bookingForMemberId: selectedMemberId,
                              ),
                            ),
                          )
                      : null, // null disables the button
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isTopRated ? kPrimary : kTextDark,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: kBorder,
                    disabledForegroundColor: kTextMid,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(9),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(qs.canBook ? 'Book' : _bookButtonLabel(qs)),
                ),
              ),
            ],
          ),
        ),

        // ── "Top rated" badge ─────────────────────────────────────────────
        if (isTopRated)
          Positioned(
            top: 0,
            left: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kPrimary,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Text(
                'Top rated',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Short label for the disabled Book button so users know *why* they can't book.
  String _bookButtonLabel(_QueueStatus qs) {
    if (!qs.queueEnabled)   return 'Unavailable';
    if (qs.isFull)          return 'Full';
    if (!qs.bookingStarted) return 'Soon';
    return 'Book';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE PILL  – compact inline status widget shown inside the card
// ─────────────────────────────────────────────────────────────────────────────
class _QueuePill extends StatelessWidget {
  final _QueueStatus qs;
  final bool         isDark;

  const _QueuePill({required this.qs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Icon dot
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: qs.color.withOpacity(0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(qs.icon, size: 9, color: qs.color),
        ),
        const SizedBox(width: 4),

        // Status label
        Flexible(
          child: Text(
            qs.label,
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: qs.color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),

        // Progress bar when we have current + max
        if (qs.current != null && qs.max != null && qs.max! > 0) ...[
          const SizedBox(width: 6),
          SizedBox(
            width: 40,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (qs.current! / qs.max!).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: qs.color.withOpacity(0.15),
                valueColor: AlwaysStoppedAnimation<Color>(qs.color),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LOADING SHIMMER
// ─────────────────────────────────────────────────────────────────────────────
class _LoadingList extends StatelessWidget {
  const _LoadingList();

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
      itemCount: 5,
      itemBuilder: (_, __) => const _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  const _ShimmerCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Row(
        children: [
          const _ShimmerBox(width: 44, height: 44, radius: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                _ShimmerBox(width: 130, height: 12, radius: 4),
                SizedBox(height: 7),
                _ShimmerBox(width: 80, height: 18, radius: 4),
                SizedBox(height: 7),
                _ShimmerBox(width: 150, height: 10, radius: 4),
              ],
            ),
          ),
          const SizedBox(width: 10),
          const _ShimmerBox(width: 52, height: 32, radius: 9),
        ],
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const _ShimmerBox({
    required this.width,
    required this.height,
    required this.radius,
  });

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  final VoidCallback onRetry;
  const _EmptyState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: kPrimaryBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 30,
                color: kPrimary,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'No doctors found',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'We couldn\'t load the doctors list.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: kTextMid,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}