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

// ─── Design Tokens ────────────────────────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);
const kBgLight      = Color(0xFFF2FCFA);
const kTextDark     = Color(0xFF2D3748);
const kTextMid      = Color(0xFF718096);
const kTextMuted    = Color(0xFFA0AEC0);
const kBorder       = Color(0xFFEDF2F7);
const kDivider      = Color(0xFFE5E7EB);
const kCardBg       = Color(0xFFFFFFFF);
const kBg           = Color(0xFFFFFFFF);
const kSuccess      = Color(0xFF68D391);
const kWarning      = Color(0xFFF6AD55);
const kError        = Color(0xFFFC8181);
const kPurple       = Color(0xFF9F7AEA);
const kIndigo       = Color(0xFF7F9CF5);
const kBlueLight    = Color(0xFFDBEAFE);
const kGreenLight   = Color(0xFFDCFCE7);
const kAmberLight   = Color(0xFFFEF3C7);
const kPurpleLight  = Color(0xFFEDE9FE);
const kRedLight     = Color(0xFFFEE2E2);
const kFavActive    = Color(0xFFFC8181);
const kDarkBg       = Color(0xFF0F1F1D);
const kDarkSurface  = Color(0xFF1E2A28);

// ─── Review model ─────────────────────────────────────────────────────────────
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

class _DoctorProfileScreenState extends ConsumerState<DoctorProfileScreen>
    with SingleTickerProviderStateMixin {
  late bool _isFavorite;
  int? _favFetchedForDoctorId;
  int? _favFetchedForPatientId;
  bool _didRouteRefresh  = false;
  bool _didFetchReviews  = false;
  bool _didFetchAvail    = false;
  late AnimationController _fadeCtrl;
  late Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);

    final did    = widget.doctor.doctorId;
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
  void dispose() {
    _fadeCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didRouteRefresh) { _didRouteRefresh = true; return; }
    _favFetchedForDoctorId  = null;
    _favFetchedForPatientId = null;
    _tryFetchFavorite();
    _tryFetchReviews(force: true);
    _tryFetchAvailability(force: true);
  }

  void _showFavSnack(bool added) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: added ? kPrimary : kTextDark,
      duration:        const Duration(seconds: 2),
      content: Row(children: [
        Icon(
          added ? Icons.favorite_rounded : Icons.favorite_border_rounded,
          color: Colors.white, size: 15,
        ),
        const SizedBox(width: 8),
        Text(
          added ? 'Saved to Favourites' : 'Removed from Favourites',
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ]),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isDark  = Theme.of(context).brightness == Brightness.dark;
    final accent  = _dpAccent(widget.doctor.specialization);
    final initial = (widget.doctor.name?.isNotEmpty ?? false)
        ? widget.doctor.name![0].toUpperCase()
        : 'D';
    final did = widget.doctor.doctorId;

    // Sync fav state from cache
    final cached = did == null
        ? null
        : ref.watch(favoriteViewModelProvider).doctorFavorites[did];
    if (cached != null && cached != _isFavorite) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _isFavorite = cached);
      });
    }

    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      if (prev?.patientId != next.patientId) _tryFetchFavorite();
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

    final reviewState    = ref.watch(reviewViewModelProvider);
    final reviews        = reviewState.reviews ?? <ReviewModel>[];
    final availabilities = ref.watch(doctorsViewModelProvider).doctorAvailabilities;
    final avgRating      = _avgRating(reviews);

    final bgColor = isDark ? kDarkBg : kBg;

    return Scaffold(
      backgroundColor: bgColor,
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          slivers: [
            // ── App Bar ──────────────────────────────────────────────────
            SliverAppBar(
              pinned:          true,
              expandedHeight:  300,
              backgroundColor: kBg,
              surfaceTintColor: Colors.transparent,
              elevation:       0,
              systemOverlayStyle: SystemUiOverlayStyle.dark,
              leading: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: _CircleIconBtn(
                  icon: Icons.arrow_back_ios_new_rounded,
                  onTap: () => Navigator.pop(context),
                ),
              ),
              actions: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _CircleIconBtn(
                    icon: _isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    iconColor: _isFavorite ? kFavActive : kTextMid,
                    bgColor: _isFavorite
                        ? kFavActive.withOpacity(0.1)
                        : kBorder.withOpacity(0.5),
                    onTap: () => _handleFavoriteToggle(!_isFavorite),
                  ),
                ),
              ],
              flexibleSpace: FlexibleSpaceBar(
                collapseMode: CollapseMode.pin,
                background: _HeroSection(
                  initial:    initial,
                  accent:     accent,
                  doctor:     widget.doctor,
                  avgRating:  avgRating,
                  reviews:    reviews,
                  isFavorite: _isFavorite,
                ),
              ),
            ),

            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),

                    // ── Quick action pills ──────────────────────────────
                    _ActionPillRow(
                      isFav: _isFavorite,
                      onFavToggle: _handleFavoriteToggle,
                    ),
                    const SizedBox(height: 16),

                    // ── About ────────────────────────────────────────────
                    _SectionCard(
                      icon: Icons.person_outline_rounded,
                      title: 'About Doctor',
                      child: Text(
                        'Dr. ${widget.doctor.name ?? 'Unknown'} is a specialist in '
                        '${_dpCap(widget.doctor.specialization ?? 'medicine')} with over '
                        '${widget.doctor.experience ?? 0} years of experience. Known for '
                        'compassionate care, thorough diagnosis, and a patient-first approach.',
                        style: const TextStyle(
                          fontSize: 13,
                          color: kTextMid,
                          height: 1.65,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // ── Stats chips ──────────────────────────────────────
                    _StatsRow(doctor: widget.doctor, avgRating: avgRating, reviews: reviews),
                    const SizedBox(height: 12),

                    // ── Clinic info ──────────────────────────────────────
                    _SectionCard(
                      icon: Icons.local_hospital_outlined,
                      title: 'Clinic Info',
                      child: Column(children: [
                        if (widget.doctor.clinicName != null ||
                            widget.doctor.clinicAddress != null) ...[
                          _InfoTile(
                            icon:       Icons.location_on_outlined,
                            iconColor:  kPrimary,
                            iconBg:     kPrimaryLight,
                            title:      widget.doctor.clinicName ?? 'Clinic',
                            subtitle:   widget.doctor.clinicAddress ?? '',
                          ),
                          const SizedBox(height: 10),
                        ],
                        _buildWorkingHoursSection(availabilities),
                        if (widget.doctor.consultationFee != null) ...[
                          const SizedBox(height: 10),
                          _InfoTile(
                            icon:      Icons.currency_rupee_rounded,
                            iconColor: const Color(0xFFD97706),
                            iconBg:    kAmberLight,
                            title:     'Consultation Fee',
                            subtitle:  '₹${widget.doctor.consultationFee!.toStringAsFixed(0)} per visit',
                          ),
                        ],
                      ]),
                    ),
                    const SizedBox(height: 12),

                    // ── Reviews ──────────────────────────────────────────
                    _SectionCard(
                      icon: Icons.star_outline_rounded,
                      title: 'Patient Reviews',
                      trailing: reviews.isEmpty
                          ? null
                          : _RatingBadge(avgRating: avgRating, count: reviews.length),
                      child: Column(
                        children: reviews.isEmpty
                            ? [const _EmptyReviews()]
                            : reviews
                                .map(_toUiReview)
                                .map((r) => _ReviewCard(review: r))
                                .toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // ── Book Appointment CTA ─────────────────────────────────────────────
      bottomNavigationBar: _BookingBar(
        onTap: () => Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => BookAppointmentScreen(
              doctor:             widget.doctor,
              bookingForMemberId: widget.bookingForMemberId,
              initialFavorite:    _isFavorite,
            ),
          ),
        ),
      ),
    );
  }

  // ── Private helpers ────────────────────────────────────────────────────────
  void _tryFetchFavorite() {
    final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    final did = widget.doctor.doctorId ?? 0;
    if (pid <= 0 || did <= 0) return;
    if (_favFetchedForDoctorId == did && _favFetchedForPatientId == pid) return;
    _favFetchedForDoctorId  = did;
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
    if (_didFetchAvail && !force) return;
    _didFetchAvail = true;
    ref.read(doctorsViewModelProvider.notifier).getDoctorAvailability(did);
  }

  Future<void> _handleFavoriteToggle(bool v) async {
    final prev = _isFavorite;
    setState(() => _isFavorite = v);
    HapticFeedback.lightImpact();

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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      behavior:        SnackBarBehavior.floating,
      margin:          const EdgeInsets.fromLTRB(16, 0, 16, 16),
      shape:           RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      backgroundColor: kError,
      duration:        const Duration(seconds: 2),
      content: Text(message,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    ));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO SECTION
// ─────────────────────────────────────────────────────────────────────────────
class _HeroSection extends StatelessWidget {
  final String          initial;
  final Color           accent;
  final DoctorDetails   doctor;
  final double          avgRating;
  final List<ReviewModel> reviews;
  final bool            isFavorite;

  const _HeroSection({
    required this.initial,
    required this.accent,
    required this.doctor,
    required this.avgRating,
    required this.reviews,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBg,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SizedBox(height: 60),
          // Avatar
          Stack(
            alignment: Alignment.center,
            children: [
              // Soft glow ring
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  shape:       BoxShape.circle,
                  color:       accent.withOpacity(0.08),
                  border:      Border.all(color: accent.withOpacity(0.2), width: 1.5),
                ),
              ),
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withOpacity(0.12),
                ),
                child: Center(
                  child: Text(initial, style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: accent,
                  )),
                ),
              ),
              // Fav badge
              if (isFavorite)
                Positioned(
                  right: 0, bottom: 0,
                  child: Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: kFavActive,
                      shape: BoxShape.circle,
                      border: Border.all(color: kBg, width: 2),
                      boxShadow: [
                        BoxShadow(color: kFavActive.withOpacity(0.3),
                            blurRadius: 6, offset: const Offset(0, 2))
                      ],
                    ),
                    child: const Icon(Icons.favorite_rounded,
                        size: 10, color: Colors.white),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Dr. ${doctor.name ?? 'Unknown'}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: kTextDark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (doctor.specialization != null)
              _SpecChip(label: _dpCap(doctor.specialization!), color: accent),
            if (doctor.experience != null) ...[
              const SizedBox(width: 6),
              _SpecChip(
                label: '${doctor.experience} yrs exp',
                color: kTextMuted,
                bgColor: kBorder,
              ),
            ],
          ]),
          const SizedBox(height: 18),
          // Mini stats bar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: IntrinsicHeight(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _MiniStat(
                    value: avgRating == 0
                        ? '--'
                        : avgRating.toStringAsFixed(1),
                    label: reviews.isEmpty
                        ? 'Rating'
                        : '${reviews.length} reviews',
                    icon: Icons.star_rounded,
                    iconColor: kWarning,
                  ),
                  _VertDivider(),
                  _MiniStat(
                    value: '${doctor.experience ?? 0}',
                    label: 'Years Exp',
                    icon: Icons.workspace_premium_outlined,
                    iconColor: kIndigo,
                  ),
                  _VertDivider(),
                  _MiniStat(
                    value: '1.2k+',
                    label: 'Patients',
                    icon: Icons.people_outline_rounded,
                    iconColor: kSuccess,
                  ),
                  _VertDivider(),
                  _MiniStat(
                    value: doctor.consultationFee != null
                        ? '₹${doctor.consultationFee!.toStringAsFixed(0)}'
                        : '--',
                    label: 'Fee',
                    icon: Icons.currency_rupee_rounded,
                    iconColor: kPrimary,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}

class _SpecChip extends StatelessWidget {
  final String label;
  final Color  color;
  final Color? bgColor;
  const _SpecChip({required this.label, required this.color, this.bgColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color:        bgColor ?? color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(label, style: TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w600,
      color: color == kTextMuted ? kTextMuted : color,
    )),
  );
}

class _MiniStat extends StatelessWidget {
  final String   value;
  final String   label;
  final IconData icon;
  final Color    iconColor;
  const _MiniStat({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, size: 14, color: iconColor),
      const SizedBox(height: 4),
      Text(value, style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: kTextDark,
        letterSpacing: -0.2,
      )),
      const SizedBox(height: 2),
      Text(label, style: const TextStyle(
        fontSize: 10,
        color: kTextMuted,
        fontWeight: FontWeight.w400,
      )),
    ]),
  );
}

class _VertDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) =>
      Container(width: 1, height: 36, color: kBorder);
}

// ─────────────────────────────────────────────────────────────────────────────
// CIRCLE ICON BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _CircleIconBtn extends StatelessWidget {
  final IconData icon;
  final Color?   iconColor;
  final Color?   bgColor;
  final VoidCallback onTap;

  const _CircleIconBtn({
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.bgColor,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 36, height: 36,
      decoration: BoxDecoration(
        shape:  BoxShape.circle,
        color:  bgColor ?? kBorder.withOpacity(0.6),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Icon(icon, size: 16, color: iconColor ?? kTextDark),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// ACTION PILL ROW
// ─────────────────────────────────────────────────────────────────────────────
class _ActionPillRow extends StatelessWidget {
  final bool isFav;
  final void Function(bool) onFavToggle;
  const _ActionPillRow({required this.isFav, required this.onFavToggle});

  @override
  Widget build(BuildContext context) => Row(children: [
    Expanded(
      child: _ActionPill(
        icon:      isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
        label:     isFav ? 'Saved' : 'Save Doctor',
        active:    isFav,
        activeColor: kFavActive,
        onTap:     () => onFavToggle(!isFav),
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: _ActionPill(
        icon:  Icons.share_outlined,
        label: 'Share',
        onTap: () {},
      ),
    ),
    const SizedBox(width: 8),
    Expanded(
      child: _ActionPill(
        icon:  Icons.message_outlined,
        label: 'Message',
        onTap: () {},
      ),
    ),
  ]);
}

class _ActionPill extends StatelessWidget {
  final IconData icon;
  final String   label;
  final bool     active;
  final Color?   activeColor;
  final VoidCallback onTap;

  const _ActionPill({
    required this.icon,
    required this.label,
    required this.onTap,
    this.active      = false,
    this.activeColor,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? (activeColor ?? kPrimary) : kTextMid;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color:        active ? color.withOpacity(0.08) : kBg,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(
            color: active ? color.withOpacity(0.3) : kBorder,
            width: active ? 1.2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: color,
          )),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// STATS ROW
// ─────────────────────────────────────────────────────────────────────────────
class _StatsRow extends StatelessWidget {
  final DoctorDetails     doctor;
  final double            avgRating;
  final List<ReviewModel> reviews;
  const _StatsRow({
    required this.doctor,
    required this.avgRating,
    required this.reviews,
  });

  @override
  Widget build(BuildContext context) => Row(children: [
    _StatChip(
      icon:      Icons.star_rounded,
      iconColor: kWarning,
      iconBg:    kAmberLight,
      value:     avgRating == 0 ? 'N/A' : avgRating.toStringAsFixed(1),
      label:     'Avg Rating',
    ),
    const SizedBox(width: 8),
    _StatChip(
      icon:      Icons.rate_review_outlined,
      iconColor: kIndigo,
      iconBg:    kBlueLight,
      value:     '${reviews.length}',
      label:     'Reviews',
    ),
    const SizedBox(width: 8),
    _StatChip(
      icon:      Icons.verified_outlined,
      iconColor: kSuccess,
      iconBg:    kGreenLight,
      value:     'Verified',
      label:     'Profile',
    ),
  ]);
}

class _StatChip extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   value;
  final String   label;
  const _StatChip({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color:        kBg,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color:        iconBg,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            )),
            Text(label, style: const TextStyle(
              fontSize: 10,
              color: kTextMuted,
            )),
          ],
        )),
      ]),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final String   title;
  final Widget   child;
  final Widget?  trailing;
  const _SectionCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color:        kCardBg,
      borderRadius: BorderRadius.circular(14),
      border:       Border.all(color: kBorder, width: 1),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Header
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color:        kPrimaryLight,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 13, color: kPrimary),
          ),
          const SizedBox(width: 8),
          Text(title, style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: kTextDark,
            letterSpacing: -0.1,
          )),
          if (trailing != null) ...[const Spacer(), trailing!],
        ]),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Divider(height: 18, thickness: 1, color: kBorder),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
        child: child,
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// INFO TILE
// ─────────────────────────────────────────────────────────────────────────────
class _InfoTile extends StatelessWidget {
  final IconData icon;
  final Color    iconColor;
  final Color    iconBg;
  final String   title;
  final String   subtitle;
  const _InfoTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 34, height: 34,
        decoration: BoxDecoration(
          color:        iconBg,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 15),
      ),
      const SizedBox(width: 10),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: kTextDark,
        )),
        if (subtitle.isNotEmpty)
          Text(subtitle, style: const TextStyle(
            fontSize: 11,
            color: kTextMid,
            height: 1.4,
          )),
      ])),
    ],
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// RATING BADGE
// ─────────────────────────────────────────────────────────────────────────────
class _RatingBadge extends StatelessWidget {
  final double avgRating;
  final int    count;
  const _RatingBadge({required this.avgRating, required this.count});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color:        kAmberLight,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.star_rounded, color: kWarning, size: 12),
      const SizedBox(width: 3),
      Text(
        avgRating == 0 ? '--' : avgRating.toStringAsFixed(1),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Color(0xFF92400E),
        ),
      ),
      Text(
        ' ($count)',
        style: const TextStyle(fontSize: 10, color: Color(0xFFB45309)),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// REVIEW CARD
// ─────────────────────────────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final _Review review;
  const _ReviewCard({required this.review});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color:        const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: kBorder, width: 1),
    ),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
            color:  kPrimaryLight,
            shape:  BoxShape.circle,
          ),
          child: Center(
            child: Text(review.name[0], style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kPrimary,
            )),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.name, style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kTextDark,
            )),
            Row(children: [
              ...List.generate(5, (i) => Icon(
                i < review.rating.floor()
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                size: 10,
                color: i < review.rating.floor() ? kWarning : kBorder,
              )),
              const SizedBox(width: 4),
              Text(review.date, style: const TextStyle(
                fontSize: 10, color: kTextMuted,
              )),
            ]),
          ],
        )),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color:        kGreenLight,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            '${review.rating.toStringAsFixed(1)} ★',
            style: const TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: Color(0xFF166534),
            ),
          ),
        ),
      ]),
      const SizedBox(height: 8),
      Text(review.comment, style: const TextStyle(
        fontSize: 11.5,
        color: kTextMid,
        height: 1.55,
      )),
    ]),
  );
}

class _EmptyReviews extends StatelessWidget {
  const _EmptyReviews();

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color:        const Color(0xFFFAFAFA),
      borderRadius: BorderRadius.circular(12),
      border:       Border.all(color: kBorder, width: 1),
    ),
    child: Row(children: [
      Container(
        width: 32, height: 32,
        decoration: BoxDecoration(
          color:        kPrimaryLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.rate_review_outlined, size: 14, color: kPrimary),
      ),
      const SizedBox(width: 10),
      const Expanded(
        child: Text(
          'No reviews yet. Be the first to share your experience.',
          style: TextStyle(fontSize: 12, color: kTextMid, height: 1.5),
        ),
      ),
    ]),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// BOOKING BAR
// ─────────────────────────────────────────────────────────────────────────────
class _BookingBar extends StatelessWidget {
  final VoidCallback onTap;
  const _BookingBar({required this.onTap});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.fromLTRB(
      16, 12, 16, 12 + MediaQuery.of(context).padding.bottom,
    ),
    decoration: const BoxDecoration(
      color: kBg,
      border: Border(top: BorderSide(color: kBorder, width: 1)),
    ),
    child: SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation:       0,
          shadowColor:     kPrimary.withOpacity(0.3),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.calendar_month_rounded, size: 16),
          const SizedBox(width: 8),
          const Text(
            'Book Appointment',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color:        Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Text(
              'Confirm →',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ]),
      ),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Helpers
// ─────────────────────────────────────────────────────────────────────────────
Color _dpAccent(String? s) {
  const m = <String, Color>{
    'cardiology':    Color(0xFFFC8181),
    'dermatology':   Color(0xFFF6AD55),
    'pediatrics':    Color(0xFF68D391),
    'orthopedics':   Color(0xFF9F7AEA),
    'neurology':     Color(0xFF7F9CF5),
    'general':       Color(0xFF26C6B0),
    'gynecology':    Color(0xFFF687B3),
    'ophthalmology': Color(0xFF4FD1C5),
  };
  return m[s?.toLowerCase()] ?? kPrimary;
}

String _dpCap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

double _avgRating(List<ReviewModel> reviews) {
  if (reviews.isEmpty) return 0;
  final sum = reviews.fold<double>(
    0, (acc, r) => acc + (r.rating?.toDouble() ?? 0),
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
    name:    name,
    rating:  (r.rating ?? 0).toDouble(),
    comment: r.comment?.isNotEmpty == true ? r.comment! : 'No comment provided.',
    date:    _fmtReviewDate(r.createdAt),
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

Widget _buildWorkingHoursSection(List<DoctorAvailabilityModel> avail) {
  const dayOrder = [
    'Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'
  ];
  const shortDay = {
    'Monday': 'Mon', 'Tuesday': 'Tue', 'Wednesday': 'Wed',
    'Thursday': 'Thu', 'Friday': 'Fri', 'Saturday': 'Sat', 'Sunday': 'Sun',
  };

  final Map<String, (String, String)> byDay = {};
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
    return _InfoTile(
      icon:      Icons.access_time_rounded,
      iconColor: kPrimary,
      iconBg:    kPrimaryLight,
      title:     'Working Hours',
      subtitle:  'Schedule not available',
    );
  }

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
    rows.add(_InfoTile(
      icon:      Icons.access_time_rounded,
      iconColor: kPrimary,
      iconBg:    kPrimaryLight,
      title:     dayLabel,
      subtitle:  timeStr,
    ));
    first = false;
  }

  return Column(children: rows);
}