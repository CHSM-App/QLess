import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/review_model.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/view_models/favorite_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ── Shared colour palette (same across all screens) ───────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple     = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);
const kIndigo     = Color(0xFF7F9CF5);
const kIndigoLight = Color(0xFFE0E7FF);

// ── Specialty colour helper (hash-based, same as other screens) ───────────────
const _kAccentPalette = [
  Color(0xFFFC8181), Color(0xFFF6AD55), Color(0xFF68D391),
  Color(0xFF9F7AEA), Color(0xFF3B82F6), Color(0xFF26C6B0),
  Color(0xFFF687B3), Color(0xFF4FD1C5), Color(0xFFED8936), Color(0xFF667EEA),
];
const _kBgPalette = [
  Color(0xFFFEE2E2), Color(0xFFFEF3C7), Color(0xFFDCFCE7),
  Color(0xFFEDE9FE), Color(0xFFDBEAFE), Color(0xFFD9F5F1),
  Color(0xFFFED7E2), Color(0xFFE6FFFA), Color(0xFFFEEBC8), Color(0xFFEBF4FF),
];

int _hashIdx(String? s, int len) {
  if (s == null || s.isEmpty) return 0;
  var h = 0;
  for (final c in s.toLowerCase().codeUnits) h = (h * 31 + c) & 0x7fffffff;
  return h % len;
}

Color _accentFor(String? s) => _kAccentPalette[_hashIdx(s, _kAccentPalette.length)];
Color _bgFor(String? s)     => _kBgPalette[_hashIdx(s, _kBgPalette.length)];

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

double _avgRating(List<ReviewModel> reviews) {
  if (reviews.isEmpty) return 0;
  return reviews.fold<double>(0, (a, r) => a + (r.rating?.toDouble() ?? 0)) /
      reviews.length;
}

// ════════════════════════════════════════════════════════════════════
//  DOCTOR PROFILE SCREEN
// ════════════════════════════════════════════════════════════════════
class DoctorProfileScreen extends ConsumerStatefulWidget {
  final DoctorDetails doctor;
  final int?          bookingForMemberId;
  final bool          initialFavorite;

  const DoctorProfileScreen({
    super.key,
    required this.doctor,
    this.bookingForMemberId,
    this.initialFavorite = false,
  });

  @override
  ConsumerState<DoctorProfileScreen> createState() =>
      _DoctorProfileScreenState();
}

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen> {
  late bool _isFav;
  bool _didFetchReviews = false;
  bool _didFetchAvail   = false;
  int? _favFetchedDid;
  int? _favFetchedPid;

  @override
  void initState() {
    super.initState();
    final did    = widget.doctor.doctorId;
    final cached = did == null
        ? null
        : ref.read(favoriteViewModelProvider).doctorFavorites[did];
    _isFav = cached ?? widget.initialFavorite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryFetchFav();
      _tryFetchReviews();
      _tryFetchAvail();
    });
  }

  void _tryFetchFav() {
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) return;
    if (_favFetchedDid == did && _favFetchedPid == pid) return;
    _favFetchedDid = did;
    _favFetchedPid = pid;
    ref.read(favoriteViewModelProvider.notifier).fetchFavoriteStatus(pid, did);
  }

  void _tryFetchReviews({bool force = false}) {
    final did = widget.doctor.doctorId ?? 0;
    if (did <= 0 || (_didFetchReviews && !force)) return;
    _didFetchReviews = true;
    ref.read(reviewViewModelProvider.notifier).fetchDoctorReviews(did);
  }

  void _tryFetchAvail({bool force = false}) {
    final did = widget.doctor.doctorId ?? 0;
    if (did <= 0 || (_didFetchAvail && !force)) return;
    _didFetchAvail = true;
    ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(did);
  }

  Future<void> _toggleFav(bool v) async {
    final prev = _isFav;
    setState(() => _isFav = v);
    HapticFeedback.lightImpact();
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) {
      setState(() => _isFav = prev);
      _snack('Please login to use favourites', isError: true);
      return;
    }
    final n  = ref.read(favoriteViewModelProvider.notifier);
    final ok = v
        ? await n.addFavoriteDoctor(pid, did)
        : await n.deleteFavoriteDoctor(pid, did);
    if (!ok) {
      setState(() => _isFav = prev);
      _snack(ref.read(favoriteViewModelProvider).error ?? 'Failed', isError: true);
      return;
    }
    _snack(v ? 'Saved to Favourites' : 'Removed from Favourites');
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: isError ? kError : kPrimary,
        duration: const Duration(seconds: 2),
        content: Text(msg,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
      ));
  }

  // ════════════════════════════════════════════════════════════════════
  //  BUILD
  // ════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final d          = widget.doctor;
    final accent     = _accentFor(d.specialization);
    final accentBg   = _bgFor(d.specialization);
    final init       = d.name?.isNotEmpty == true
        ? d.name![0].toUpperCase()
        : 'D';
    final did        = d.doctorId;

    // Sync fav from cache
    final cached = did == null
        ? null
        : ref.watch(favoriteViewModelProvider).doctorFavorites[did];
    if (cached != null && cached != _isFav) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isFav = cached);
      });
    }

    ref.listen<FavoriteState>(favoriteViewModelProvider, (prev, next) {
      if (did == null) return;
      final nf = next.doctorFavorites[did];
      if (nf != null && nf != prev?.doctorFavorites[did] && mounted) {
        setState(() => _isFav = nf);
      }
    });

    final reviews       = ref.watch(reviewViewModelProvider).reviews ?? <ReviewModel>[];
    final availabilities = ref.watch(doctorsViewModelProvider).doctorAvailabilities;
    final avgRating     = _avgRating(reviews);
    final clinicText    = [d.clinicName, d.clinicAddress]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return Scaffold(
      backgroundColor: Colors.white,
      // ── AppBar — back arrow + icon badge + name, same as all other screens ──
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.only(left: 14),
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                color: kTextPrimary, size: 15),
          ),
        ),
        leadingWidth: 54,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                color: accentBg,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: accent.withOpacity(0.2)),
              ),
              child: Icon(Icons.person_rounded, color: accent, size: 15),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                'Dr. ${d.name ?? 'Profile'}',
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.2),
              ),
            ),
          ],
        ),
        actions: [
          // Favourite toggle — same style as explore/search fav button
          GestureDetector(
            onTap: () => _toggleFav(!_isFav),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 34, height: 34,
              margin: const EdgeInsets.only(right: 14),
              decoration: BoxDecoration(
                color: _isFav ? kRedLight : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _isFav ? kError.withOpacity(0.3) : kBorder),
              ),
              child: Icon(
                _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _isFav ? kError : kTextPrimary,
                size: 16,
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: kBorder, height: 1),
        ),
        systemOverlayStyle: SystemUiOverlayStyle.dark,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            // ── Doctor Hero Card ─────────────────────────────────
            _buildHeroCard(init, accent, accentBg, avgRating, reviews, d),
            const SizedBox(height: 10),

            // ── Stats row ────────────────────────────────────────
            _buildStatsRow(avgRating, reviews.length, d),
            const SizedBox(height: 10),

            // ── Action pills ─────────────────────────────────────
            _buildActionPills(),
            const SizedBox(height: 14),

            // ── About ────────────────────────────────────────────
            _buildSectionLabel('About Doctor'),
            const SizedBox(height: 8),
            _buildAboutCard(d),
            const SizedBox(height: 14),

            // ── Clinic Info ──────────────────────────────────────
            _buildSectionLabel('Clinic Info'),
            const SizedBox(height: 8),
            _buildClinicCard(d, clinicText, availabilities),
            const SizedBox(height: 14),

            // ── Reviews ──────────────────────────────────────────
            _buildSectionLabel('Patient Reviews',
                trailing: reviews.isEmpty
                    ? null
                    : _RatingBadge(avg: avgRating, count: reviews.length)),
            const SizedBox(height: 8),
            _buildReviewsCard(reviews),
            const SizedBox(height: 24),
          ],
        ),
      ),

      // ── Book CTA ─────────────────────────────────────────────────
      bottomNavigationBar: _BookingBar(
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookAppointmentScreen(
              doctor: d,
              bookingForMemberId: widget.bookingForMemberId,
              initialFavorite: _isFav,
            ),
          ),
        ),
      ),
    );
  }

  // ── Hero Card ──────────────────────────────────────────────────────
  Widget _buildHeroCard(String init, Color accent, Color accentBg,
      double avgRating, List<ReviewModel> reviews, DoctorDetails d) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(children: [
        // Avatar row
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Gradient avatar — mirrors profile/explore card avatar
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 58, height: 58,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [accent, accent.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  alignment: Alignment.center,
                  child: Text(init,
                      style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                ),
                if (_isFav)
                  Positioned(
                    bottom: -3, right: -3,
                    child: Container(
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        color: kError,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.favorite_rounded,
                          size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Dr. ${d.name ?? 'Unknown'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                  const SizedBox(height: 3),
                  // Spec + exp badges
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (d.specialization != null)
                        _Badge(
                            label: _cap(d.specialization!),
                            fg: accent,
                            bg: accentBg),
                      if (d.experience != null)
                        _Badge(
                            label: '${d.experience}y exp',
                            fg: kTextSecondary,
                            bg: kBorder),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Rating row
                  Row(children: [
                    const Icon(Icons.star_rounded,
                        size: 12, color: kWarning),
                    const SizedBox(width: 3),
                    Text(
                      avgRating == 0
                          ? 'No reviews'
                          : '${avgRating.toStringAsFixed(1)} (${reviews.length})',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: kTextSecondary),
                    ),
                    // if (d.consultationFee != null) ...[
                    //   const SizedBox(width: 8),
                    //   Container(
                    //     padding: const EdgeInsets.symmetric(
                    //         horizontal: 7, vertical: 2),
                    //     decoration: BoxDecoration(
                    //         color: kPrimaryLight,
                    //         borderRadius: BorderRadius.circular(6)),
                    //     child: Text(
                    //       '₹${d.consultationFee!.toStringAsFixed(0)}',
                    //       style: const TextStyle(
                    //           fontSize: 11,
                    //           fontWeight: FontWeight.w700,
                    //           color: kPrimary),
                    //     ),
                    //   ),
                    // ],
                  ]),
                ],
              ),
            ),
          ],
        ),

        // Divider
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: Divider(height: 1, thickness: 1, color: kBorder),
        ),

        // Mini stats bar — 4 columns
        IntrinsicHeight(
          child: Row(
            children: [
              _MiniStat(
                icon: Icons.star_rounded,
                iconColor: kWarning,
                iconBg: kAmberLight,
                value: avgRating == 0 ? '--' : avgRating.toStringAsFixed(1),
                label: 'Rating',
              ),
              _vertDiv(),
              _MiniStat(
                icon: Icons.workspace_premium_rounded,
                iconColor: kIndigo,
                iconBg: kIndigoLight,
                value: '${d.experience ?? 0}y',
                label: 'Exp',
              ),
              _vertDiv(),
              _MiniStat(
                icon: Icons.people_outline_rounded,
                iconColor: kSuccess,
                iconBg: kGreenLight,
                value: '1.2k+',
                label: 'Patients',
              ),
              _vertDiv(),
              _MiniStat(
                icon: Icons.event_available_rounded,
                iconColor: kPrimary,
                iconBg: kPrimaryLight,
                value: _isOpen(d) ? 'Open' : 'Closed',
                label: 'Status',
              ),
            ],
          ),
        ),
      ]),
    );
  }

  bool _isOpen(DoctorDetails d) => d.isQueueAvailable == 1;

  // ── Stats row ───────────────────────────────────────────────────────
  Widget _buildStatsRow(double avg, int reviewCount, DoctorDetails d) {
    final stats = [
      _StatItem(Icons.star_rounded,           kWarning, kAmberLight,
          avg == 0 ? 'N/A' : avg.toStringAsFixed(1), 'Rating'),
      _StatItem(Icons.rate_review_outlined,   kIndigo,  kIndigoLight,
          '$reviewCount', 'Reviews'),
      _StatItem(Icons.verified_outlined,      kSuccess, kGreenLight,
          'Yes', 'Verified'),
    ];
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < stats.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: kBorder),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 3)),
                ],
              ),
              child: Row(children: [
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                      color: s.bg, borderRadius: BorderRadius.circular(8)),
                  child: Icon(s.icon, size: 13, color: s.color),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.value,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      Text(s.label,
                          style: const TextStyle(
                              fontSize: 10, color: kTextMuted)),
                    ],
                  ),
                ),
              ]),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Action pills ────────────────────────────────────────────────────
  Widget _buildActionPills() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        Expanded(
          child: _ActionPill(
            icon: _isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            label: _isFav ? 'Saved' : 'Save',
            active: _isFav,
            activeColor: kError,
            onTap: () => _toggleFav(!_isFav),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionPill(
            icon: Icons.message_outlined,
            label: 'Message',
            onTap: () {},
          ),
        ),
      ]),
    );
  }

  // ── Section label — mirrors explore/profile _SectionLabel ──────────
  Widget _buildSectionLabel(String title, {Widget? trailing}) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          if (trailing != null) ...[const Spacer(), trailing],
        ]),
      );

  // ── About card ─────────────────────────────────────────────────────
  Widget _buildAboutCard(DoctorDetails d) => _Card(
        child: Text(
          'Dr. ${d.name ?? 'Unknown'} is a specialist in '
          '${_cap(d.specialization ?? 'medicine')} with over '
          '${d.experience ?? 0} years of experience. Known for '
          'compassionate care, thorough diagnosis, and a patient-first approach.',
          style: const TextStyle(
              fontSize: 12,
              color: kTextSecondary,
              height: 1.65,
              fontWeight: FontWeight.w400),
        ),
      );

  // ── Clinic card ─────────────────────────────────────────────────────
  Widget _buildClinicCard(DoctorDetails d, String clinicText,
      List<DoctorAvailabilityModel> avail) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (clinicText.isNotEmpty) ...[
            _InfoRow(
              icon: Icons.location_on_outlined,
              iconColor: kPrimary,
              iconBg: kPrimaryLight,
              title: d.clinicName ?? 'Clinic',
              subtitle: d.clinicAddress ?? '',
            ),
            const SizedBox(height: 10),
          ],
          _buildWorkingHours(avail),
          // if (d.consultationFee != null) ...[
          //   const SizedBox(height: 10),
          //   _InfoRow(
          //     icon: Icons.currency_rupee_rounded,
          //     iconColor: const Color(0xFFD97706),
          //     iconBg: kAmberLight,
          //     title: 'Consultation Fee',
          //     subtitle:
          //         '₹${d.consultationFee!.toStringAsFixed(0)} per visit',
          //   ),
          // ],
        ],
      ),
    );
  }

  Widget _buildWorkingHours(List<DoctorAvailabilityModel> avail) {
    const dayOrder = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
    ];
    const shortDay = {
      'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
      'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
    };

    final byDay = <String, (String, String)>{};
    for (final a in avail) {
      if (a.isEnabled != true || a.dayOfWeek == null) continue;
      final day = a.dayOfWeek!;
      final s   = a.startTime ?? '';
      final e   = a.endTime   ?? '';
      if (!byDay.containsKey(day)) {
        byDay[day] = (s, e);
      } else {
        final cur = byDay[day]!;
        byDay[day] = (
          s.compareTo(cur.$1) < 0 ? s : cur.$1,
          e.compareTo(cur.$2) > 0 ? e : cur.$2,
        );
      }
    }

    if (byDay.isEmpty) {
      return _InfoRow(
        icon: Icons.access_time_rounded,
        iconColor: kPrimary,
        iconBg: kPrimaryLight,
        title: 'Working Hours',
        subtitle: 'Schedule not available',
      );
    }

    final byTime = <String, List<String>>{};
    for (final day in dayOrder) {
      if (!byDay.containsKey(day)) continue;
      final r   = byDay[day]!;
      final key = '${r.$1}|${r.$2}';
      byTime.putIfAbsent(key, () => []).add(day);
    }

    final rows = <Widget>[];
    bool first = true;
    for (final entry in byTime.entries) {
      final parts   = entry.key.split('|');
      final timeStr = '${_fmtTime(parts[0])} – ${_fmtTime(parts[1])}';
      final dayLbl  =
          entry.value.map((d) => shortDay[d] ?? d).join(', ');
      if (!first) rows.add(const SizedBox(height: 10));
      rows.add(_InfoRow(
        icon: Icons.access_time_rounded,
        iconColor: kPrimary,
        iconBg: kPrimaryLight,
        title: dayLbl,
        subtitle: timeStr,
      ));
      first = false;
    }
    return Column(children: rows);
  }

  // ── Reviews card ────────────────────────────────────────────────────
  Widget _buildReviewsCard(List<ReviewModel> reviews) => _Card(
        child: reviews.isEmpty
            ? Row(children: [
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.rate_review_outlined,
                      size: 14, color: kPrimary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                      'No reviews yet. Be the first to share your experience.',
                      style: TextStyle(
                          fontSize: 12,
                          color: kTextSecondary,
                          height: 1.5)),
                ),
              ])
            : Column(
                children: reviews
                    .map((r) => _ReviewTile(review: r))
                    .toList()),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SHARED CARD CONTAINER  — same shadow/radius as all other screens
// ════════════════════════════════════════════════════════════════════
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 14),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: child,
      );
}

// ════════════════════════════════════════════════════════════════════
//  BADGE  — mirrors profile/explore badge helper
// ════════════════════════════════════════════════════════════════════
class _Badge extends StatelessWidget {
  final String label;
  final Color  fg, bg;
  const _Badge({required this.label, required this.fg, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );
}

// ════════════════════════════════════════════════════════════════════
//  MINI STAT  — compact 4-col bar inside hero card
// ════════════════════════════════════════════════════════════════════
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, iconBg;
  final String   value, label;
  const _MiniStat({
    required this.icon, required this.iconColor,
    required this.iconBg, required this.value, required this.label,
  });
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 13, color: iconColor),
            const SizedBox(height: 3),
            Text(value,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            Text(label,
                style: const TextStyle(
                    fontSize: 10, color: kTextMuted)),
          ],
        ),
      );
}

Widget _vertDiv() =>
    Container(width: 1, height: 32, color: kBorder);

// ════════════════════════════════════════════════════════════════════
//  STAT ITEM MODEL
// ════════════════════════════════════════════════════════════════════
class _StatItem {
  final IconData icon;
  final Color    color, bg;
  final String   value, label;
  const _StatItem(this.icon, this.color, this.bg, this.value, this.label);
}

// ════════════════════════════════════════════════════════════════════
//  INFO ROW  — mirrors profile/explore _InfoTile / _menuRow
// ════════════════════════════════════════════════════════════════════
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor, iconBg;
  final String   title, subtitle;
  const _InfoRow({
    required this.icon, required this.iconColor,
    required this.iconBg, required this.title, required this.subtitle,
  });
  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
                color: iconBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                if (subtitle.isNotEmpty)
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11,
                          color: kTextSecondary,
                          height: 1.4)),
              ],
            ),
          ),
        ],
      );
}

// ════════════════════════════════════════════════════════════════════
//  ACTION PILL
// ════════════════════════════════════════════════════════════════════
class _ActionPill extends StatelessWidget {
  final IconData     icon;
  final String       label;
  final bool         active;
  final Color?       activeColor;
  final VoidCallback onTap;
  const _ActionPill({
    required this.icon, required this.label, required this.onTap,
    this.active = false, this.activeColor,
  });
  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? kPrimary) : kTextSecondary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: active ? color.withOpacity(0.08) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: active ? color.withOpacity(0.3) : kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 15, color: color),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: color)),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  RATING BADGE
// ════════════════════════════════════════════════════════════════════
class _RatingBadge extends StatelessWidget {
  final double avg;
  final int    count;
  const _RatingBadge({required this.avg, required this.count});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: kAmberLight, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.star_rounded, color: kWarning, size: 11),
          const SizedBox(width: 3),
          Text(
            avg == 0 ? '--' : avg.toStringAsFixed(1),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Color(0xFF92400E)),
          ),
          Text(' ($count)',
              style: const TextStyle(
                  fontSize: 10, color: Color(0xFFB45309))),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  REVIEW TILE  — compact, no overflow
// ════════════════════════════════════════════════════════════════════
class _ReviewTile extends StatelessWidget {
  final ReviewModel review;
  const _ReviewTile({required this.review});

  String get _name {
    final n = review.patientName?.isNotEmpty == true
        ? review.patientName!
        : (review.name?.isNotEmpty == true ? review.name! : 'Patient');
    return n;
  }

  double get _rating => (review.rating ?? 0).toDouble();

  String get _date {
    final iso = review.createdAt;
    if (iso == null || iso.isEmpty) return '';
    final dt = DateTime.tryParse(iso);
    if (dt == null) return '';
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return '${m[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              // Avatar circle
              Container(
                width: 28, height: 28,
                decoration: const BoxDecoration(
                    color: kPrimaryLight, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text(
                  _name.isNotEmpty ? _name[0].toUpperCase() : 'P',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: kPrimary),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                    Row(children: [
                      ...List.generate(
                          5,
                          (i) => Icon(
                                i < _rating.floor()
                                    ? Icons.star_rounded
                                    : Icons.star_outline_rounded,
                                size: 10,
                                color: i < _rating.floor()
                                    ? kWarning
                                    : kBorder,
                              )),
                      const SizedBox(width: 4),
                      if (_date.isNotEmpty)
                        Text(_date,
                            style: const TextStyle(
                                fontSize: 10, color: kTextMuted)),
                    ]),
                  ],
                ),
              ),
              // Rating chip
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                    color: kGreenLight,
                    borderRadius: BorderRadius.circular(6)),
                child: Text(
                  '${_rating.toStringAsFixed(1)} ★',
                  style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF166534)),
                ),
              ),
            ]),
            const SizedBox(height: 7),
            Text(
              review.comment?.isNotEmpty == true
                  ? review.comment!
                  : 'No comment provided.',
              style: const TextStyle(
                  fontSize: 11,
                  color: kTextSecondary,
                  height: 1.5),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  BOOKING BAR  — same as profile's edit button but full-width teal
// ════════════════════════════════════════════════════════════════════
class _BookingBar extends StatelessWidget {
  final VoidCallback onTap;
  const _BookingBar({required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        padding: EdgeInsets.fromLTRB(
            16, 10, 16, 10 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder, width: 1)),
        ),
        child: SizedBox(
          height: 46,
          child: ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.calendar_month_rounded, size: 15),
                const SizedBox(width: 8),
                const Text('Book Appointment',
                    style: TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('Confirm →',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  HELPERS
// ════════════════════════════════════════════════════════════════════
String _fmtTime(String? t) {
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h      = int.tryParse(parts[0]) ?? 0;
  final m      = int.tryParse(parts[1]) ?? 0;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12    = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
}