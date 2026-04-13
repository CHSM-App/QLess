import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/view_models/favorite_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/domain/models/review_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';

// Uses same palette constants from book_appointment_screen.dart
// (kPrimary, kGreen, kOrange, kTextDark, kTextMid, kBorder, kBg, kCardBg,
//  kPrimaryBg, _kDarkSurface, _kDarkBg, kFavActive)

// ─── Review model (replace with real model from your domain) ─────────────────
class _Review {
  final String name;
  final double rating;
  final String comment;
  final String date;
  const _Review({
    required this.name,
    required this.rating,
    required this.comment,
    required this.date,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR PROFILE SCREEN
// ─────────────────────────────────────────────────────────────────────────────
class DoctorProfileScreen extends ConsumerStatefulWidget {
  final DoctorDetails doctor;
  final int?          bookingForMemberId;
  final bool          initialFavorite;   // ← pass from parent if available

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
  late bool _isFavorite;
  int? _favFetchedForDoctorId;
  int? _favFetchedForPatientId;
  bool _didRouteRefresh = false;
  bool _didFetchReviews = false;
  bool _didFetchAvailability = false;

  @override
  void initState() {
    super.initState();
    final did = widget.doctor.doctorId;
    final cached = did == null
        ? null
        : ref.read(favoriteViewModelProvider).doctorFavorites[did];
    _isFavorite = cached ?? widget.initialFavorite;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _tryFetchFavorite();
      _tryFetchReviews();
      _tryFetchAvailability();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // When returning to this screen, allow a fresh fetch.
    if (!_didRouteRefresh) {
      _didRouteRefresh = true;
      return;
    }
    _favFetchedForDoctorId = null;
    _favFetchedForPatientId = null;
    _tryFetchFavorite();
    _tryFetchReviews(force: true);
    _tryFetchAvailability(force: true);
  }

  void _showFavSnack(bool added) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: added ? kFavActive : kTextDark,
        duration: const Duration(seconds: 2),
        content: Row(children: [
          Icon(
            added ? Icons.favorite_rounded : Icons.favorite_border_rounded,
            color: Colors.white,
            size: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              added
                  ? 'Saved to Favourites'
                  : 'Add to Favourites',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final accent  = _dpAccent(widget.doctor.specialization);
    final initial = (widget.doctor.name?.isNotEmpty ?? false)
        ? widget.doctor.name![0].toUpperCase()
        : 'D';
    final did = widget.doctor.doctorId;
    final cached = did == null
        ? null
        : ref.watch(favoriteViewModelProvider).doctorFavorites[did];
    if (cached != null && cached != _isFavorite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isFavorite = cached);
      });
    }

    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      if (prev?.patientId != next.patientId) {
        _tryFetchFavorite();
      }
    });

    ref.listen<FavoriteState>(favoriteViewModelProvider, (prev, next) {
      final did = widget.doctor.doctorId;
      if (did == null) return;
      final prevFav = prev?.doctorFavorites[did];
      final nextFav = next.doctorFavorites[did];
      if (nextFav != null && nextFav != prevFav && mounted) {
        setState(() => _isFavorite = nextFav);
      }
      if (next.error != null && next.error != prev?.error && mounted) {
        _showErrorSnack(next.error!);
      }
    });

    final reviewState = ref.watch(reviewViewModelProvider);
    final reviews = reviewState.reviews ?? <ReviewModel>[];
    final availabilities = ref.watch(doctorsViewModelProvider).doctorAvailabilities;
    final avgRating = _avgRating(reviews);

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF4F6FB),
      body: CustomScrollView(
        slivers: [
          // ── Hero header ──────────────────────────────────────────────────
          SliverAppBar(
            expandedHeight: 280,
            pinned:         true,
            backgroundColor: kPrimary,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 18, color: Colors.white),
              onPressed: () => Navigator.pop(context),
            ),
            title: const Text(
              'Doctor Profile',
              style: TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white),
            ),
            // ── Favourite button in AppBar actions ──────────────────────
            actions: [
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: _FavoriteButton(
                  initialFav: _isFavorite,
                  onWhite:    true,   // on blue AppBar → use white style
                  onToggle: _handleFavoriteToggle,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              collapseMode: CollapseMode.pin,
              background: Container(
                color: kPrimary,
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                alignment: Alignment.bottomCenter,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    // ── Avatar with fav dot ────────────────────────────
                    Stack(
                      children: [
                        Container(
                          width: 76, height: 76,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                            border: Border.all(
                                color: Colors.white.withOpacity(0.5), width: 3),
                          ),
                          child: Center(
                            child: Text(initial, style: TextStyle(
                                fontSize: 30,
                                fontWeight: FontWeight.w700,
                                color: accent)),
                          ),
                        ),
                        // Small fav badge on avatar
                        AnimatedPositioned(
                          duration: const Duration(milliseconds: 250),
                          right: 0, bottom: 0,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 300),
                            opacity: _isFavorite ? 1.0 : 0.0,
                            child: Container(
                              width: 22, height: 22,
                              decoration: BoxDecoration(
                                color: kFavActive,
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: kPrimary, width: 2),
                              ),
                              child: const Icon(Icons.favorite_rounded,
                                  size: 11, color: Colors.white),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text('Dr. ${widget.doctor.name ?? 'Unknown'}',
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white)),
                    const SizedBox(height: 5),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      if (widget.doctor.specialization != null)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(_dpCap(widget.doctor.specialization!),
                            style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Colors.white)),
                        ),
                      if (widget.doctor.experience != null) ...[
                        const SizedBox(width: 8),
                        Text('${widget.doctor.experience} yrs exp',
                          style: TextStyle(
                              fontSize: 11,
                              color: Colors.white.withOpacity(0.75))),
                      ],
                    ]),
                    const SizedBox(height: 16),
                    // Stats row
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      _HeroStat(
                          label: reviews.isEmpty
                              ? 'Rating'
                              : '${reviews.length} ${reviews.length == 1 ? 'review' : 'reviews'}',
                          value: avgRating == 0
                              ? '--'
                              : avgRating.toStringAsFixed(1),
                          icon: Icons.star_rounded),
                      _HeroDiv(),
                      _HeroStat(
                          label: 'Experience',
                          value: '${widget.doctor.experience ?? 0} yrs'),
                      _HeroDiv(),
                      _HeroStat(label: 'Patients', value: '1.2k+'),
                      _HeroDiv(),
                      _HeroStat(
                        label: 'Fee',
                        value: widget.doctor.consultationFee != null
                            ? '₹${widget.doctor.consultationFee!.toStringAsFixed(0)}'
                            : '--',
                        valueColor: const Color(0xFF4ADE80),
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ),

          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

                // ── Quick favourite pill ─────────────────────────────────
                // Shown inline below hero so user can also tap here
                _FavouritePill(
                  isFav: _isFavorite,
                  onToggle: _handleFavoriteToggle,
                ),
                const SizedBox(height: 14),

                // ── About ──────────────────────────────────────────────────
                _SectionCard(
                  title: 'About Doctor',
                  child: Text(
                    'Dr. ${widget.doctor.name ?? 'Unknown'} is a specialist in '
                    '${_dpCap(widget.doctor.specialization ?? 'medicine')} with over '
                    '${widget.doctor.experience ?? 0} years of experience. Known for '
                    'compassionate care, thorough diagnosis, and patient-first approach.',
                    style: const TextStyle(
                        fontSize: 12.5, color: kTextMid, height: 1.6),
                  ),
                ),
                const SizedBox(height: 12),

                // ── Clinic info ─────────────────────────────────────────────
                _SectionCard(
                  title: 'Clinic Info',
                  child: Column(children: [
                    if (widget.doctor.clinicName != null ||
                        widget.doctor.clinicAddress != null)
                      _InfoRow(
                        icon: Icons.local_hospital_outlined,
                        iconColor: kPrimary,
                        iconBg: kPrimaryBg,
                        title: widget.doctor.clinicName ?? 'Clinic',
                        subtitle: widget.doctor.clinicAddress ?? '',
                      ),
                    const SizedBox(height: 10),
                    _buildWorkingHoursSection(availabilities),
                    if (widget.doctor.consultationFee != null) ...[
                      const SizedBox(height: 10),
                      _InfoRow(
                        icon: Icons.currency_rupee_rounded,
                        iconColor: const Color(0xFF92400E),
                        iconBg: const Color(0xFFFEF3C7),
                        title: 'Consultation Fee',
                        subtitle:
                            '₹${widget.doctor.consultationFee!.toStringAsFixed(0)} per visit',
                      ),
                    ],
                  ]),
                ),
                const SizedBox(height: 12),

                // ── Reviews ─────────────────────────────────────────────────
                _SectionCard(
                  title: 'Patient Reviews',
                  trailing: Row(children: [
                    const Icon(Icons.star_rounded, color: kOrange, size: 14),
                    const SizedBox(width: 3),
                    Text(
                      avgRating == 0 ? '--' : avgRating.toStringAsFixed(1),
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextDark,
                      ),
                    ),
                    Text(
                      '  (${reviews.length} reviews)',
                      style: const TextStyle(fontSize: 11, color: kTextMid),
                    ),
                  ]),
                  child: Column(
                    children: reviews.isEmpty
                        ? [
                            const _EmptyReviews(),
                          ]
                        : reviews
                            .map(_toUiReview)
                            .map((r) => _ReviewCard(review: r))
                            .toList(),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),

      // ── Book appointment button ──────────────────────────────────────────
      bottomNavigationBar: Container(
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
        decoration: const BoxDecoration(
          color: kCardBg,
          border: Border(top: BorderSide(color: kBorder, width: 0.5)),
        ),
        child: SizedBox(
          height: 50,
          child: ElevatedButton.icon(
            onPressed: () => Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => BookAppointmentScreen(
                  doctor:             widget.doctor,
                  bookingForMemberId: widget.bookingForMemberId,
                  initialFavorite:    _isFavorite,   // ← pass fav state across
                ),
              ),
            ),
            icon: const Icon(Icons.calendar_month_rounded, size: 17),
            label: const Text('Book Appointment',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ),
    );
  }

  void _tryFetchFavorite() {
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) return;
    if (_favFetchedForDoctorId == did && _favFetchedForPatientId == pid) {
      return;
    }
    _favFetchedForDoctorId = did;
    _favFetchedForPatientId = pid;
    ref.read(favoriteViewModelProvider.notifier).fetchFavoriteStatus(pid, did);
  }

  void _tryFetchReviews({bool force = false}) {
    final did = widget.doctor.doctorId ?? 0;
    if (did <= 0) return;
    if (_didFetchReviews && !force) return;
    _didFetchReviews = true;
    ref.read(reviewViewModelProvider.notifier).fetchDoctorReviews(did);
  }

  void _tryFetchAvailability({bool force = false}) {
    final did = widget.doctor.doctorId ?? 0;
    if (did <= 0) return;
    if (_didFetchAvailability && !force) return;
    _didFetchAvailability = true;
    ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(did);
  }

  Future<void> _handleFavoriteToggle(bool v) async {
    final prev = _isFavorite;
    setState(() => _isFavorite = v);

    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) {
      setState(() => _isFavorite = prev);
      _showErrorSnack('Please login to use favourites');
      return;
    }

    final notifier = ref.read(favoriteViewModelProvider.notifier);
    final ok = v
        ? await notifier.addFavoriteDoctor(pid, did)
        : await notifier.deleteFavoriteDoctor(pid, did);

    if (!ok) {
      setState(() => _isFavorite = prev);
      final err = ref.read(favoriteViewModelProvider).error ??
          'Failed to update favourites';
      _showErrorSnack(err);
      return;
    }

    _showFavSnack(v);
  }

  void _showErrorSnack(String message) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kRed,
        duration: const Duration(seconds: 2),
        content: Text(
          message,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAVOURITE BUTTON  (same as book_appointment_screen.dart — keep in sync)
// ─────────────────────────────────────────────────────────────────────────────
class _FavoriteButton extends StatefulWidget {
  final bool   initialFav;
  final bool   onWhite;     // true → white-tinted style (on blue AppBar)
  final void Function(bool) onToggle;

  const _FavoriteButton({
    required this.initialFav,
    required this.onToggle,
    this.onWhite = false,
  });

  @override
  State<_FavoriteButton> createState() => _FavoriteButtonState();
}

class _FavoriteButtonState extends State<_FavoriteButton>
    with SingleTickerProviderStateMixin {
  late bool _isFav;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _isFav = widget.initialFav;
    _ctrl  = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
    );
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.35)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 35),
      TweenSequenceItem(
          tween: Tween(begin: 1.35, end: 0.88)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.88, end: 1.06)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 20),
      TweenSequenceItem(
          tween: Tween(begin: 1.06, end: 1.0)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 15),
    ]).animate(_ctrl);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  void didUpdateWidget(_FavoriteButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialFav != widget.initialFav) {
      setState(() => _isFav = widget.initialFav);
    }
  }

  void _toggle() {
    HapticFeedback.mediumImpact();
    setState(() => _isFav = !_isFav);
    widget.onToggle(_isFav);
    _ctrl.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final isOnBlue = widget.onWhite;
    return GestureDetector(
      onTap: _toggle,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (_, child) =>
            Transform.scale(scale: _scale.value, child: child),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeInOut,
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _isFav
                ? kFavActive.withOpacity(0.18)
                : (isOnBlue
                    ? Colors.white.withOpacity(0.15)
                    : const Color(0xFFF3F4F6)),
            border: Border.all(
              color: _isFav
                  ? kFavActive.withOpacity(0.55)
                  : (isOnBlue
                      ? Colors.white.withOpacity(0.35)
                      : kBorder),
              width: 1.2,
            ),
            boxShadow: _isFav
                ? [BoxShadow(
                    color: kFavActive.withOpacity(0.3),
                    blurRadius: 10)]
                : [],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              transitionBuilder: (child, anim) =>
                  ScaleTransition(scale: anim, child: child),
              child: Icon(
                _isFav
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                key: ValueKey(_isFav),
                size: 18,
                color: _isFav
                    ? kFavActive
                    : (isOnBlue ? Colors.white : kTextMid),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FAVOURITE PILL  — inline row below hero section
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// FAVOURITE PILL  — inline row below hero section
// ─────────────────────────────────────────────────────────────────────────────
class _FavouritePill extends StatefulWidget {
  final bool isFav;
  final void Function(bool) onToggle;
  const _FavouritePill({required this.isFav, required this.onToggle});

  @override
  State<_FavouritePill> createState() => _FavouritePillState();
}

class _FavouritePillState extends State<_FavouritePill>
    with SingleTickerProviderStateMixin {
  late bool _isFav;
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _isFav = widget.isFav;
    _ctrl  = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _scale = TweenSequence<double>([
      TweenSequenceItem(
          tween: Tween(begin: 1.0, end: 1.2)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 40),
      TweenSequenceItem(
          tween: Tween(begin: 1.2, end: 0.9)
              .chain(CurveTween(curve: Curves.easeIn)),
          weight: 30),
      TweenSequenceItem(
          tween: Tween(begin: 0.9, end: 1.0)
              .chain(CurveTween(curve: Curves.easeOut)),
          weight: 30),
    ]).animate(_ctrl);
  }

  @override
  void didUpdateWidget(_FavouritePill old) {
    super.didUpdateWidget(old);
    if (old.isFav != widget.isFav) setState(() => _isFav = widget.isFav);
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => GestureDetector(
  //  onTap: _toggle,
    child: AnimatedBuilder(
      animation: _ctrl,
      builder: (_, child) =>
          Transform.scale(scale: _scale.value, child: child),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeInOut,
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: _isFav
              ? kFavActive.withOpacity(0.07)
              : kCardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: _isFav
                ? kFavActive.withOpacity(0.4)
                : kBorder,
            width: _isFav ? 1.2 : 0.5,
          ),
        ),
        child: Row(children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            transitionBuilder: (child, anim) =>
                ScaleTransition(scale: anim, child: child),
            child: Icon(
              _isFav
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              key: ValueKey(_isFav),
              color: _isFav ? kFavActive : kTextMid,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _isFav ? kFavActive : kTextMid,
            ),
            child: Text(_isFav
                ? 'Saved to Favourites'
                : 'Add to Favourites'),
          ),
          const Spacer(),
          // AnimatedContainer(
          //   duration: const Duration(milliseconds: 200),
          //   padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
          //   decoration: BoxDecoration(
          //     color: _isFav
          //         ? kFavActive.withOpacity(0.12)
          //         : const Color(0xFFF3F4F6),
          //     borderRadius: BorderRadius.circular(6),
          //   ),
          //   child: Text(
          //     _isFav ? 'Remove' : 'Save',
          //     style: TextStyle(
          //       fontSize: 10.5,
          //       fontWeight: FontWeight.w700,
          //       color: _isFav ? kFavActive : kTextMid,
          //     ),
          //   ),
          // ),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
Color _dpAccent(String? s) {
  const m = <String, Color>{
    'cardiology':    Color(0xFFEF4444),
    'dermatology':   Color(0xFFF59E0B),
    'pediatrics':    Color(0xFF10B981),
    'orthopedics':   Color(0xFF8B5CF6),
    'neurology':     Color(0xFF8B5CF6),
    'general':       Color(0xFF06B6D4),
    'gynecology':    Color(0xFFEC4899),
    'ophthalmology': Color(0xFF14B8A6),
  };
  return m[s?.toLowerCase()] ?? kPrimary;
}

String _dpCap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

double _avgRating(List<ReviewModel> reviews) {
  if (reviews.isEmpty) return 0;
  final sum = reviews.fold<double>(
    0,
    (acc, r) => acc + (r.rating?.toDouble() ?? 0),
  );
  return sum / reviews.length;
}

_Review _toUiReview(ReviewModel r) {
  final name = (r.patientName?.isNotEmpty ?? false)
      ? r.patientName!
      : (r.name?.isNotEmpty ?? false)
          ? r.name!
          : 'Patient';
  return _Review(
    name: name,
    rating: (r.rating ?? 0).toDouble(),
    comment: r.comment?.isNotEmpty == true
        ? r.comment!
        : 'No comment provided.',
    date: _fmtReviewDate(r.createdAt),
  );
}

String _fmtReviewDate(String? iso) {
  if (iso == null || iso.trim().isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  const months = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec',
  ];
  return '${months[dt.month - 1]} ${dt.year}';
}

// ── Working-hours helpers ────────────────────────────────────────────────────

String _fmtTime(String? t) {
  if (t == null || t.isEmpty) return '';
  final parts = t.split(':');
  if (parts.length < 2) return t;
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final period = h >= 12 ? 'PM' : 'AM';
  final h12 = h == 0 ? 12 : (h > 12 ? h - 12 : h);
  return '${h12.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')} $period';
}

Widget _buildWorkingHoursSection(List<DoctorAvailabilityModel> avail) {
  const dayOrder = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];
  const shortDay = {
    'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
    'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
  };

  // Per day: min start_time, max end_time among enabled slots
  final Map<String, (String, String)> byDay = {};
  for (final a in avail) {
    if (a.isEnabled != true || a.dayOfWeek == null) continue;
    final day  = a.dayOfWeek!;
    final s    = a.startTime ?? '';
    final e    = a.endTime   ?? '';
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
      iconColor: const Color(0xFF065F46),
      iconBg: const Color(0xFFD1FAE5),
      title: 'Working Hours',
      subtitle: 'Schedule not available',
    );
  }

  // Group days that share the same (start, end) → show "Mon, Tue: HH:MM – HH:MM"
  final Map<String, List<String>> byTime = {};
  for (final day in dayOrder) {
    if (!byDay.containsKey(day)) continue;
    final r   = byDay[day]!;
    final key = '${r.$1}|${r.$2}';
    byTime.putIfAbsent(key, () => []).add(day);
  }

  final rows = <Widget>[];
  bool first = true;
  for (final entry in byTime.entries) {
    final parts    = entry.key.split('|');
    final timeStr  = '${_fmtTime(parts[0])} – ${_fmtTime(parts[1])}';
    final dayLabel = entry.value.map((d) => shortDay[d] ?? d).join(', ');
    if (!first) rows.add(const SizedBox(height: 10));
    rows.add(_InfoRow(
      icon: Icons.access_time_rounded,
      iconColor: const Color(0xFF065F46),
      iconBg: const Color(0xFFD1FAE5),
      title: dayLabel,
      subtitle: timeStr,
    ));
    first = false;
  }

  return Column(children: rows);
}

// Sub-widgets
class _HeroStat extends StatelessWidget {
  final String   label;
  final String   value;
  final IconData? icon;
  final Color    valueColor;
  const _HeroStat({
    required this.label,
    required this.value,
    this.icon,
    this.valueColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(children: [
      if (icon != null)
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, color: kOrange, size: 13),
          const SizedBox(width: 2),
          Text(value, style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: valueColor)),
        ])
      else
        Text(value, style: TextStyle(
            fontSize: 17, fontWeight: FontWeight.w700, color: valueColor)),
      const SizedBox(height: 3),
      Text(label, style: TextStyle(
          fontSize: 9.5, color: Colors.white.withOpacity(0.65))),
    ]),
  );
}

class _HeroDiv extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    width: 1, height: 32, color: Colors.white.withOpacity(0.2));
}

class _SectionCard extends StatelessWidget {
  final String  title;
  final Widget  child;
  final Widget? trailing;
  const _SectionCard({
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder, width: 0.5),
    ),
    padding: const EdgeInsets.all(14),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(title, style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700, color: kTextDark)),
        if (trailing != null) ...[const Spacer(), trailing!],
      ]),
      const SizedBox(height: 10),
      const Divider(height: 0, thickness: 0.5, color: kBorder),
      const SizedBox(height: 12),
      child,
    ]),
  );
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   title;
  final String   subtitle;
  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      width: 32, height: 32,
      decoration: BoxDecoration(
          color: iconBg, borderRadius: BorderRadius.circular(8)),
      child: Icon(icon, color: iconColor, size: 15),
    ),
    const SizedBox(width: 10),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(
          fontSize: 12.5, fontWeight: FontWeight.w600, color: kTextDark)),
      if (subtitle.isNotEmpty)
        Text(subtitle,
            style: const TextStyle(fontSize: 11, color: kTextMid)),
    ]),
  ]);
}

class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder, width: 0.5),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        CircleAvatar(
          radius: 14,
          backgroundColor: kPrimaryBg,
          child: Text(review.name[0], style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: kPrimary)),
        ),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(review.name, style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
          Row(children: [
            ...List.generate(5, (i) => Icon(
              i < review.rating.floor()
                  ? Icons.star_rounded
                  : Icons.star_outline_rounded,
              size: 11,
              color: i < review.rating.floor() ? kOrange : kBorder,
            )),
            const SizedBox(width: 4),
            Text(review.date,
                style: const TextStyle(fontSize: 10, color: kTextMid)),
          ]),
        ]),
      ]),
      const SizedBox(height: 8),
      Text(review.comment, style: const TextStyle(
          fontSize: 11.5, color: kTextMid, height: 1.5)),
    ]),
  );
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: kBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kBorder, width: 0.5),
    ),
    child: const Text(
      'No reviews yet. Be the first to share your experience.',
      style: TextStyle(fontSize: 11.5, color: kTextMid, height: 1.5),
    ),
  );
}


