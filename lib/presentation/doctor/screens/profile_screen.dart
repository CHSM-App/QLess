import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_edit_screen.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart' hide appointmentViewModelProvider;
import 'package:url_launcher/url_launcher.dart';

// ── Colour Palette (matches QueueHomePage + DoctorMedicinePage exactly) ───────
const kPrimary        = Color(0xFF26C6B0);
const kPrimaryDark    = Color(0xFF2BB5A0);
const kPrimaryLight   = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary    = Color(0xFF2D3748);
const kTextSecondary  = Color(0xFF718096);
const kTextMuted      = Color(0xFFA0AEC0);

const kBorder         = Color(0xFFEDF2F7);
const kDivider        = Color(0xFFE5E7EB);

const kError          = Color(0xFFFC8181);
const kRedLight       = Color(0xFFFEE2E2);
const kRedDark        = Color(0xFFC53030);

const kSuccess        = Color(0xFF68D391);
const kGreenLight     = Color(0xFFDCFCE7);
const kGreenDark      = Color(0xFF276749);

const kWarning        = Color(0xFFF6AD55);
const kAmberLight     = Color(0xFFFEF3C7);
const kAmberDark      = Color(0xFF975A16);

const kPurple         = Color(0xFF9F7AEA);
const kPurpleLight    = Color(0xFFEDE9FE);
const kPurpleDark     = Color(0xFF6B46C1);

const kInfo           = Color(0xFF3B82F6);
const kInfoLight      = Color(0xFFDBEAFE);
const kInfoDark       = Color(0xFF1E40AF);
const kPageBg         = Colors.white;
const kCardBg         = Color(0xFFF7F8FA);

// ── Card decoration ───────────────────────────────────────────────────────────
BoxDecoration _cardDec() => BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2)),
      ],
    );

// ════════════════════════════════════════════════════════════════════
//  DOCTOR SETTINGS PAGE
// ════════════════════════════════════════════════════════════════════
class DoctorSettingsPage extends ConsumerStatefulWidget {
  const DoctorSettingsPage({super.key});

  @override
  ConsumerState<DoctorSettingsPage> createState() => _DoctorSettingsPageState();
}

class _DoctorSettingsPageState extends ConsumerState<DoctorSettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailAlerts          = false;
  bool _smsAlerts            = true;
  bool _darkMode             = false;
  bool _availableForConsult  = true;
  bool _didFetchProfile      = false;
  bool _didFetchCounts       = false;

  int  _savedLeadHours   = 0;
  int  _savedLeadMinutes = 0;
  int  _leadHours        = 0;
  int  _leadMinutes      = 0;
  bool _leadTimeEdited   = false;
  bool _isSavingLeadTime = false;
  int? _lastAppliedLeadTimeMinutes;

  late final ProviderSubscription<DoctorLoginState> _sub;

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<DoctorLoginState>(
      doctorLoginViewModelProvider,
      (prev, next) {
        if (!_didFetchProfile) {
          final mobile = next.mobile;
          if (mobile != null && mobile.trim().isNotEmpty) {
            _didFetchProfile = true;
            ref
                .read(doctorLoginViewModelProvider.notifier)
                .checkPhoneDoctor(mobile);
          }
        }
        final doctorId = next.doctorId;
        if (doctorId != null && doctorId > 0) _fetchCounts(doctorId);
      },
    );
    Future.microtask(() {
      final s = ref.read(doctorLoginViewModelProvider);
      final mobile = s.mobile;
      if (mobile != null && mobile.trim().isNotEmpty) {
        _didFetchProfile = true;
        ref
            .read(doctorLoginViewModelProvider.notifier)
            .checkPhoneDoctor(mobile);
      }
      final doctorId = s.doctorId;
      if (doctorId != null && doctorId > 0) _fetchCounts(doctorId);
    });
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }

  // ── Lead time helpers ─────────────────────────────────────────────────────

  void _setLeadTimeFromApi(int minutes) {
    final safe = minutes < 0 ? 0 : minutes;
    _leadHours   = (safe ~/ 60).clamp(0, 23);
    _leadMinutes = safe % 60;
    _savedLeadHours   = _leadHours;
    _savedLeadMinutes = _leadMinutes;
    _leadTimeEdited   = false;
  }

  void _onLeadTimeChanged(int h, int m) => setState(() {
        _leadHours      = h;
        _leadMinutes    = m;
        _leadTimeEdited = h != _savedLeadHours || m != _savedLeadMinutes;
      });

  Future<void> _updateLeadTime() async {
    setState(() => _isSavingLeadTime = true);
    final mins = _leadHours * 60 + _leadMinutes;
    final body = DoctorDetails(
      leadTime: mins,
      doctorId: ref.read(doctorLoginViewModelProvider).doctorId ?? 0,
    );
    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .updateLeadTime(body);
    setState(() {
      _savedLeadHours   = _leadHours;
      _savedLeadMinutes = _leadMinutes;
      _leadTimeEdited   = false;
      _isSavingLeadTime = false;
    });
  }

  void _cancelLeadTimeEdit() => setState(() {
        _leadHours      = _savedLeadHours;
        _leadMinutes    = _savedLeadMinutes;
        _leadTimeEdited = false;
      });

  // ── Refresh ───────────────────────────────────────────────────────────────

  Future<void> _refreshProfile() async {
    final mobile = ref.read(doctorLoginViewModelProvider).mobile;
    if (mobile != null && mobile.trim().isNotEmpty) {
      ref
          .read(doctorLoginViewModelProvider.notifier)
          .checkPhoneDoctor(mobile);
      await Future.delayed(const Duration(milliseconds: 600));
    }
  }

  // ── Counts fetch ──────────────────────────────────────────────────────────

  void _fetchCounts(int doctorId) {
    if (_didFetchCounts) return;
    _didFetchCounts = true;
    ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(doctorId);
    ref.read(reviewViewModelProvider.notifier).fetchDoctorReviews(doctorId);
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  // ── Bottom sheets ─────────────────────────────────────────────────────────

  void _showPersonalInfoSheet(DoctorLoginState s, DoctorDetails? d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalInfoSheet(
        initials:       _initials(d?.name ?? s.name),
        name:           d?.name ?? s.name ?? '—',
        mobile:         s.mobile ?? '—',
        specialization: d?.specialization ?? '—',
        qualification:  d?.qualification ?? '—',
        clinicName:     d?.clinicName ?? s.clinic_name ?? '—',
        experience:     d?.experience?.toString() ?? '—',
        fee:            d?.consultationFee != null
            ? '₹${d!.consultationFee!.toStringAsFixed(0)}'
            : '—',
        onProfileEdited: _refreshProfile,
      ),
    );
  }

  void _showProfessionalDetailsSheet(DoctorLoginState s, DoctorDetails? d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ProfessionalDetailsSheet(
        specialization: d?.specialization ?? '—',
        qualification:  d?.qualification ?? '—',
        licenseNo:      d?.licenseNo ?? '—',
        experience:     d?.experience?.toString() ?? '—',
        fee:            d?.consultationFee != null
            ? '₹${d!.consultationFee!.toStringAsFixed(0)}'
            : '—',
        clinicName:    d?.clinicName ?? s.clinic_name ?? '—',
        clinicAddress: d?.clinicAddress ?? '—',
        clinicEmail:   d?.clinicEmail ?? '—',
        clinicContact: d?.clinicContact ?? '—',
        websiteName:   d?.websiteName ?? '—',
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final doctorState   = ref.watch(doctorLoginViewModelProvider);
    final doctorDetails = doctorState.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    final stateLeadTime =
        doctorDetails?.leadTime ?? doctorState.leadTimeMinutes;
    if (stateLeadTime != null &&
        stateLeadTime != _lastAppliedLeadTimeMinutes &&
        !_leadTimeEdited) {
      _setLeadTimeFromApi(stateLeadTime);
      _lastAppliedLeadTimeMinutes = stateLeadTime;
    }

    final isLoading     = doctorState.phoneCheckResult.isLoading;
    final w             = MediaQuery.of(context).size.width;
    final isTablet      = w >= 600;
    final isLargeTablet = w >= 900;

    // ── Real counts & rating — all derived here, passed down ────────────────
    final apptState   = ref.watch(appointmentViewModelProvider);
    final reviewState = ref.watch(reviewViewModelProvider);

    // Completed appointments only (status = completed / done / closed)
    final patientCount = apptState.patientAppointmentsList.maybeWhen(
      data: (list) {
        const done = {'completed', 'done', 'closed'};
        return list
            .where((a) => done.contains(a.status?.toLowerCase().trim()))
            .map((a) => a.patientId)
            .where((id) => id != null)
            .toSet()
            .length;
      },
      orElse: () => null,
    );

    // Rating avg + review count — both from fetchDoctorReviews
    final reviews     = reviewState.reviews;
    final reviewCount = reviews?.length;   // total reviews received

    double? avgRating;
    if (reviews != null && reviews.isNotEmpty) {
      final vals = reviews
          .map((r) => r.rating)
          .whereType<num>()           // skip null ratings
          .map((n) => n.toDouble())
          .toList();
      if (vals.isNotEmpty) {
        avgRating = vals.fold(0.0, (sum, v) => sum + v) / vals.length;
      }
    }
    avgRating ??= doctorDetails?.rating; // fallback to profile-API rating

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(
        children: [
          // ── Header — exact same structure as DoctorMedicinePage ───────────
          _buildHeader(),

          // ── Body ─────────────────────────────────────────────────────────
          Expanded(
            child: isLoading
                ? const _SkeletonSettingsBody()
                : isLargeTablet
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: RefreshIndicator(
                              color: kPrimary,
                              strokeWidth: 2.5,
                              displacement: 40,
                              onRefresh: _refreshProfile,
                              child: _buildScroll(
                                isTablet: true,
                                s: doctorState,
                                d: doctorDetails,
                                patientCount: patientCount,
                                reviewCount: reviewCount,
                                avgRating: avgRating,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 300,
                            child: _buildRightPanel(),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        color: kPrimary,
                        strokeWidth: 2.5,
                        displacement: 40,
                        onRefresh: _refreshProfile,
                        child: _buildScroll(
                          isTablet: isTablet,
                          s: doctorState,
                          d: doctorDetails,
                          patientCount: patientCount,
                          reviewCount: reviewCount,
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  // ── Header — matches DoctorMedicinePage _buildHeader exactly ─────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Row(
            children: [
              // Icon badge — 34×34, same as medicine page
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kPrimary.withOpacity(0.2)),
                ),
                child: const Icon(Icons.settings_outlined,
                    color: kPrimary, size: 17),
              ),
              const SizedBox(width: 8),

              // Title + subtitle — same font sizes (16 / 11) as medicine page
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    SizedBox(height: 1),
                    Text(
                      'Manage your account & preferences',
                      style: TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Scrollable body ───────────────────────────────────────────────────────

  Widget _buildScroll({
    required bool isTablet,
    required DoctorLoginState s,
    DoctorDetails? d,
    int? patientCount,
    int? reviewCount,
    double? avgRating,
  }) {
    final hPad = isTablet ? 20.0 : 14.0;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(hPad, 14, hPad, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(isTablet, s, d,
              patientCount: patientCount,
              reviewCount: reviewCount,
              avgRating: avgRating),
          const SizedBox(height: 14),
          _sectionLabel('Account'),
          _buildAccountSection(s, d),
          const SizedBox(height: 14),
          _sectionLabel('Availability'),
          _buildAvailabilityCard(),
          const SizedBox(height: 14),
          _sectionLabel('Notifications'),
          _buildNotificationsCard(),
          const SizedBox(height: 14),
          _sectionLabel('Appearance'),
          _buildAppearanceCard(),
          const SizedBox(height: 14),
          _sectionLabel('Support'),
          _buildSupportCard(),
          const SizedBox(height: 14),
          _buildLogoutButton(),
        ],
      ),
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(
      bool isTablet, DoctorLoginState s, DoctorDetails? d,
      {int? patientCount, int? reviewCount, double? avgRating}) {
    final initials = _initials(d?.name ?? s.name);
    final name     = d?.name ?? s.name ?? 'Doctor';
    final clinic   = d?.clinicName ?? s.clinic_name ?? '';
    final spec     = d?.specialization ?? 'General';
    final qual     = d?.qualification ?? '';

    return Container(
      decoration: _cardDec(),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Teal gradient strip
        Container(
          height: 60,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [kPrimary, kPrimaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),

        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
          child: Column(children: [
            // Avatar overlapping strip
            Transform.translate(
              offset: const Offset(0, -30),
              child: Stack(alignment: Alignment.bottomRight, children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                        colors: [kPrimary, kPrimaryDark],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    border: Border.all(color: Colors.white, width: 3),
                    boxShadow: [
                      BoxShadow(
                          color: kPrimary.withOpacity(0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3))
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(initials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                ),
                Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: kSuccess,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: const Icon(Icons.edit_rounded,
                      color: Colors.white, size: 9),
                ),
              ]),
            ),

            // Name, spec, clinic — pulled up to close gap
            Transform.translate(
              offset: const Offset(0, -20),
              child: Column(children: [
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Text(name,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary,
                          letterSpacing: -0.2)),
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('Verified',
                        style: TextStyle(
                            fontSize: 10,
                            color: kPrimary,
                            fontWeight: FontWeight.w600)),
                  ),
                ]),
                const SizedBox(height: 2),
                Text(
                  [spec, if (qual.isNotEmpty) qual].join('  ·  '),
                  style: const TextStyle(
                      fontSize: 12, color: kTextSecondary),
                ),
                if (clinic.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(clinic,
                      style: const TextStyle(
                          fontSize: 11, color: kTextMuted)),
                ],
                const SizedBox(height: 10),
                _statsRow(d,
                    showFee: isTablet,
                    patientCount: patientCount,
                    reviewCount: reviewCount,
                    avgRating: avgRating),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  height: 36,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        Navigator.of(context, rootNavigator: true).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  const DoctorEditProfilePage()),
                        ).then((_) {
                          if (mounted) _refreshProfile();
                        }),
                    icon: const Icon(Icons.edit_outlined, size: 14),
                    label: const Text('Edit Profile',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kPrimary,
                      side: const BorderSide(color: kPrimary),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }

  Widget _statsRow(DoctorDetails? d,
      {required bool showFee, int? patientCount, int? reviewCount, double? avgRating}) {
    final exp      = d?.experience?.toString();
    final expT     = (exp != null && exp.isNotEmpty) ? '$exp yrs' : '—';
    final fee      = d?.consultationFee?.toStringAsFixed(0);
    final feeT     = (fee != null && fee.isNotEmpty) ? '₹$fee' : '—';
    final ratingT  = avgRating != null
        ? '${avgRating.toStringAsFixed(1)} ★'
        : '—';
    final patientsT = patientCount != null ? patientCount.toString() : '—';
    final reviewsT  = reviewCount  != null ? reviewCount.toString()  : '—';

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(expT, 'Experience'),
        _vDiv(),
        _statItem(ratingT, 'Rating'),
        _vDiv(),
        _statItem(patientsT, 'Patients'),
        _vDiv(),
        _statItem(reviewsT, 'Reviews'),
        if (showFee) ...[_vDiv(), _statItem(feeT, 'Fee')],
      ],
    );
  }

  Widget _statItem(String v, String l) => Column(children: [
        Text(v,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 2),
        Text(l,
            style: const TextStyle(fontSize: 10, color: kTextMuted)),
      ]);

  Widget _vDiv() =>
      Container(height: 26, width: 1, color: kBorder);

  // ── Account Section ───────────────────────────────────────────────────────

  Widget _buildAccountSection(DoctorLoginState s, DoctorDetails? d) =>
      _tileCard([
        _Item(Icons.person_outline_rounded, 'Personal Information',
            'Name, mobile, specialization',
            onTap: () => _showPersonalInfoSheet(s, d)),
        _Item(Icons.medical_information_outlined, 'Professional Details',
            'Specialization, license',
            onTap: () => _showProfessionalDetailsSheet(s, d)),
        _Item(Icons.lock_outline_rounded, 'Password & Security',
            'Change password, 2FA'),
        _Item(Icons.payment_outlined, 'Payment & Earnings',
            'Bank account, payouts'),
      ]);

Widget _buildAvailabilityCard() => Container(
      decoration: _cardDec(),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Consultation toggle
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: _availableForConsult ? kGreenLight : kRedLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.videocam_outlined,
                  color: _availableForConsult ? kSuccess : kError,
                  size: 17,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Available for Consultation',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                      ),
                    ),
                    Text(
                      _availableForConsult
                          ? 'Patients can book appointments'
                          : 'Not accepting patients',
                      style: const TextStyle(
                        fontSize: 11,
                        color: kTextMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _availableForConsult,
                activeColor: kSuccess,
                onChanged: (v) =>
                    setState(() => _availableForConsult = v),
              ),
            ],
          ),

          // Lead time (only when available)
          if (_availableForConsult) ...[
            const SizedBox(height: 12),
            const Divider(height: 1, color: kDivider),
            const SizedBox(height: 12),
            const Text(
              'Booking lead time',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 10),
            _buildLeadTimeRow(),

            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeInOut,
              child: _leadTimeEdited
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: _isSavingLeadTime
                                  ? null
                                  : _cancelLeadTimeEdit,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: kTextSecondary,
                                side: const BorderSide(color: kBorder),
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: const Text(
                                'Cancel',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: _isSavingLeadTime
                                  ? null
                                  : _updateLeadTime,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: kPrimary,
                                foregroundColor: Colors.white,
                                disabledBackgroundColor: kPrimaryLight,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10),
                                ),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 10),
                              ),
                              child: _isSavingLeadTime
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child:
                                          CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Update',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight:
                                            FontWeight.w600,
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],

          const SizedBox(height: 12),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 12),

          // ✅ Working Hours + Edit Schedule (same row)
       Row(
  mainAxisAlignment: MainAxisAlignment.spaceBetween,
  children: [
    Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: kGreenLight, // same style like queue/booking
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.access_time,
            size: 15,
            color: kPrimary,
          ),
        ),
        const SizedBox(width: 8),
        const Text(
          'Working Hours',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kTextPrimary,
          ),
        ),
      ],
    ),
    TextButton.icon(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const DoctorAvailabilityPage(),
        ),
      ),
      icon: const Icon(Icons.edit_calendar_outlined, size: 13),
      label: const Text(
        'Edit Schedule',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
      style: TextButton.styleFrom(
        foregroundColor: kPrimary,
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 30),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  ],
),
        ],
      ),
    );
  // ── Availability Card ─────────────────────────────────────────────────────

//   Widget _buildAvailabilityCard() => Container(
//         decoration: _cardDec(),
//         padding: const EdgeInsets.all(14),
//         child:
//             Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
//           // Consultation toggle
//           Row(children: [
//             Container(
//               width: 34,
//               height: 34,
//               decoration: BoxDecoration(
//                   color:
//                       _availableForConsult ? kGreenLight : kRedLight,
//                   borderRadius: BorderRadius.circular(10)),
//               child: Icon(Icons.videocam_outlined,
//                   color: _availableForConsult ? kSuccess : kError,
//                   size: 17),
//             ),
//             const SizedBox(width: 12),
//             Expanded(
//               child: Column(
//                   crossAxisAlignment: CrossAxisAlignment.start,
//                   children: [
//                     const Text('Available for Consultation',
//                         style: TextStyle(
//                             fontSize: 13,
//                             fontWeight: FontWeight.w700,
//                             color: kTextPrimary)),
//                     Text(
//                       _availableForConsult
//                           ? 'Patients can book appointments'
//                           : 'Not accepting patients',
//                       style: const TextStyle(
//                           fontSize: 11, color: kTextMuted),
//                     ),
//                   ]),
//             ),
//             Switch.adaptive(
//               value: _availableForConsult,
//               activeColor: kSuccess,
//               onChanged: (v) =>
//                   setState(() => _availableForConsult = v),
//             ),
//           ]),

//           // Lead time (only when available)
//           if (_availableForConsult) ...[
//             const SizedBox(height: 12),
//             const Divider(height: 1, color: kDivider),
//             const SizedBox(height: 12),
//             const Text('Booking lead time',
//                 style: TextStyle(
//                     fontSize: 12,
//                     fontWeight: FontWeight.w600,
//                     color: kTextPrimary)),
//             const SizedBox(height: 10),
//             _buildLeadTimeRow(),
//             AnimatedSize(
//               duration: const Duration(milliseconds: 220),
//               curve: Curves.easeInOut,
//               child: _leadTimeEdited
//                   ? Padding(
//                       padding: const EdgeInsets.only(top: 12),
//                       child: Row(children: [
//                         Expanded(
//                           child: OutlinedButton(
//                             onPressed: _isSavingLeadTime
//                                 ? null
//                                 : _cancelLeadTimeEdit,
//                             style: OutlinedButton.styleFrom(
//                               foregroundColor: kTextSecondary,
//                               side: const BorderSide(color: kBorder),
//                               shape: RoundedRectangleBorder(
//                                   borderRadius:
//                                       BorderRadius.circular(10)),
//                               padding: const EdgeInsets.symmetric(
//                                   vertical: 10),
//                             ),
//                             child: const Text('Cancel',
//                                 style: TextStyle(
//                                     fontSize: 13,
//                                     fontWeight: FontWeight.w600)),
//                           ),
//                         ),
//                         const SizedBox(width: 10),
//                         Expanded(
//                           child: ElevatedButton(
//                             onPressed: _isSavingLeadTime
//                                 ? null
//                                 : _updateLeadTime,
//                             style: ElevatedButton.styleFrom(
//                               backgroundColor: kPrimary,
//                               foregroundColor: Colors.white,
//                               disabledBackgroundColor: kPrimaryLight,
//                               elevation: 0,
//                               shape: RoundedRectangleBorder(
//                                   borderRadius:
//                                       BorderRadius.circular(10)),
//                               padding: const EdgeInsets.symmetric(
//                                   vertical: 10),
//                             ),
//                             child: _isSavingLeadTime
//                                 ? const SizedBox(
//                                     width: 16,
//                                     height: 16,
//                                     child: CircularProgressIndicator(
//                                         strokeWidth: 2,
//                                         color: Colors.white))
//                                 : const Text('Update',
//                                     style: TextStyle(
//                                         fontSize: 13,
//                                         fontWeight:
//                                             FontWeight.w600)),
//                           ),
//                         ),
//                       ]),
//                     )
//                   : const SizedBox.shrink(),
//             ),
//           ],

//           const SizedBox(height: 12),
//           const Divider(height: 1, color: kDivider),
//           const SizedBox(height: 12),
// // Working hours (single row)
// Row(
//   mainAxisAlignment: MainAxisAlignment.spaceBetween,
//   children: [
//     const Text(
//       'Working Hours',
//       style: TextStyle(
//         fontSize: 12,
//         fontWeight: FontWeight.w600,
//         color: kTextPrimary,
//       ),
//     ),
//     TextButton.icon(
//       onPressed: () => Navigator.push(
//         context,
//         MaterialPageRoute(
//           builder: (_) => const DoctorAvailabilityPage(),
//         ),
//       ),
//       icon: const Icon(Icons.edit_calendar_outlined, size: 13),
//       label: const Text(
//         'Edit Schedule',
//         style: TextStyle(
//           fontSize: 12,
//           fontWeight: FontWeight.w600,
//         ),
//       ),
//       style: TextButton.styleFrom(
//         foregroundColor: kPrimary,
//         padding: EdgeInsets.zero, // keeps it compact
//         minimumSize: Size(0, 30),
//         tapTargetSize: MaterialTapTargetSize.shrinkWrap,
//       ),
//     ),
//   ],
// ),
//         ]),
//       );

  Widget _buildLeadTimeRow() => Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
                color: kGreenLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.access_time_outlined,
                color: kSuccess, size: 15),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Queue booking',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: kTextPrimary)),
                SizedBox(height: 1),
                Text('How early patients can join',
                    style: TextStyle(fontSize: 10, color: kTextMuted)),
              ],
            ),
          ),
          Column(children: [
            const Row(children: [
              SizedBox(
                  width: 50,
                  child: Center(
                      child: Text('HH',
                          style: TextStyle(
                              fontSize: 10, color: kTextMuted)))),
              SizedBox(width: 12),
              SizedBox(
                  width: 50,
                  child: Center(
                      child: Text('MM',
                          style: TextStyle(
                              fontSize: 10, color: kTextMuted)))),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              _WheelPicker(
                key: ValueKey('h_${_leadHours}_$_savedLeadHours'),
                value: _leadHours,
                max: 24,
                onChanged: (v) =>
                    _onLeadTimeChanged(v, _leadMinutes),
              ),
              const SizedBox(width: 6),
              const Text(':',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const SizedBox(width: 6),
              _WheelPicker(
                key: ValueKey(
                    'm_${_leadMinutes}_$_savedLeadMinutes'),
                value: _leadMinutes,
                max: 60,
                onChanged: (v) =>
                    _onLeadTimeChanged(_leadHours, v),
              ),
            ]),
          ]),
        ],
      );

  Widget _dayRow(String day, String hours, bool active) =>
      Row(children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: active ? kSuccess : kError),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 88,
          child: Text(day,
              style: const TextStyle(
                  fontSize: 12, color: kTextPrimary)),
        ),
        Text(hours,
            style: TextStyle(
                fontSize: 12,
                color: active ? kTextPrimary : kTextMuted)),
      ]);

  // ── Notifications Card ────────────────────────────────────────────────────

  Widget _buildNotificationsCard() => Container(
        decoration: _cardDec(),
        child: Column(children: [
          _toggleTile(
              Icons.notifications_outlined, kAmberLight, kWarning,
              'Push Notifications', 'Appointment reminders & alerts',
              _notificationsEnabled,
              (v) => setState(() => _notificationsEnabled = v)),
          const Divider(height: 1, indent: 56, color: kDivider),
          _toggleTile(Icons.email_outlined, kInfoLight, kInfo,
              'Email Alerts', 'Daily summaries & reports',
              _emailAlerts,
              (v) => setState(() => _emailAlerts = v)),
          const Divider(height: 1, indent: 56, color: kDivider),
          _toggleTile(Icons.sms_outlined, kGreenLight, kSuccess,
              'SMS Notifications', 'Critical appointment updates',
              _smsAlerts,
              (v) => setState(() => _smsAlerts = v)),
        ]),
      );

  // ── Appearance Card ───────────────────────────────────────────────────────

  Widget _buildAppearanceCard() => Container(
        decoration: _cardDec(),
        child: Column(children: [
          _toggleTile(Icons.dark_mode_outlined, kPurpleLight, kPurple,
              'Dark Mode', 'Switch to dark theme',
              _darkMode,
              (v) => setState(() => _darkMode = v)),
          const Divider(height: 1, indent: 56, color: kDivider),
          _navTile(
              _Item(Icons.language_outlined, 'Language', 'English (India)')),
          const Divider(height: 1, indent: 56, color: kDivider),
          _navTile(
              _Item(Icons.text_fields_outlined, 'Text Size', 'Medium')),
        ]),
      );

  // ── Support Card ──────────────────────────────────────────────────────────

Widget _buildSupportCard() => _tileCard([
    _Item(Icons.help_outline_rounded, 'Help Center', 'FAQs & documentation'),
    _Item(Icons.chat_bubble_outline_rounded, 'Contact Support', 'Chat, Email, Phone'),
    _Item(Icons.privacy_tip_outlined, 'Privacy Policy', null, onTap: () async {
      final uri = Uri.parse('https://qless.vengurlatech.com/login/privacy');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    }),
    _Item(Icons.description_outlined, 'Terms of Service', null),
    _Item(Icons.info_outline_rounded, 'App Version', 'v2.4.1 (Build 204)'),
  ]);
  // ── Logout Button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() => SizedBox(
        width: double.infinity,
        height: 44,
        child: ElevatedButton.icon(
          onPressed: () => showDialog(
            context: context,
            builder: (_) => Dialog(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: const BoxDecoration(
                            color: kRedLight,
                            shape: BoxShape.circle),
                        child: const Icon(Icons.logout_rounded,
                            color: kError, size: 22),
                      ),
                      const SizedBox(height: 12),
                      const Text('Log Out?',
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      const SizedBox(height: 6),
                      const Text(
                        'You will be signed out and returned to the start screen.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 13,
                            color: kTextSecondary,
                            height: 1.5),
                      ),
                      const SizedBox(height: 20),
                      Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              side:
                                  const BorderSide(color: kBorder),
                              foregroundColor: kTextSecondary,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 11),
                            ),
                            child: const Text('Cancel',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async {
                              Navigator.pop(context);
                              await ref
                                  .read(tokenProvider.notifier)
                                  .clearTokens();
                              await ref
                                  .read(doctorLoginViewModelProvider
                                      .notifier)
                                  .logout();
                              if (mounted) {
                                Navigator.of(context,
                                        rootNavigator: true)
                                    .pushAndRemoveUntil(
                                  MaterialPageRoute(
                                      builder: (_) =>
                                          const ContinueAsScreen()),
                                  (_) => false,
                                );
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: kError,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(10)),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 11),
                            ),
                            child: const Text('Log Out',
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ]),
                    ]),
              ),
            ),
          ),
          icon: const Icon(Icons.logout_rounded, size: 16),
          label: const Text('Log out of account',
              style: TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w600)),
          style: ElevatedButton.styleFrom(
            backgroundColor: kRedLight,
            foregroundColor: kError,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );

  // ── Right Panel (desktop) ─────────────────────────────────────────────────

  Widget _buildRightPanel() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(0, 14, 20, 100),
        child: Container(
          decoration: _cardDec(),
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Quick Stats',
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
            const SizedBox(height: 10),
            _quickStat("Today's Appointments", '8',
                Icons.calendar_today_outlined, kPrimary),
            const SizedBox(height: 7),
            _quickStat('Pending Reports', '3',
                Icons.assignment_outlined, kWarning),
            const SizedBox(height: 7),
            _quickStat('New Messages', '12',
                Icons.message_outlined, kSuccess),
            const SizedBox(height: 16),
            const Text('Account Health',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary)),
            const SizedBox(height: 10),
            _healthRow('Profile Completion', 0.85),
            const SizedBox(height: 7),
            _healthRow('Document Verification', 1.0),
            const SizedBox(height: 7),
            _healthRow('Rating Score', 0.97),
          ]),
        ),
      );

  Widget _quickStat(
      String label, String value, IconData icon, Color color) =>
      Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F8FA),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(width: 10),
          Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: kTextSecondary))),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ]),
      );

  Widget _healthRow(String label, double value) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: kTextSecondary)),
              Text('${(value * 100).toInt()}%',
                  style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
            ]),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: kBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
                value == 1.0 ? kSuccess : kPrimary),
            minHeight: 5,
          ),
        ),
      ]);

  // ── Shared tile builders ──────────────────────────────────────────────────

  Widget _tileCard(List<_Item> items) => Container(
        decoration: _cardDec(),
        child: Column(
          children: items.asMap().entries.map((e) {
            return Column(children: [
              _navTile(e.value),
              if (e.key < items.length - 1)
                const Divider(
                    height: 1, indent: 56, color: kDivider),
            ]);
          }).toList(),
        ),
      );

  Widget _navTile(_Item item) => InkWell(
        onTap: item.onTap ?? () {},
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          child: Row(children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: kPrimary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.label,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                    if (item.subtitle != null)
                      Text(item.subtitle!,
                          style: const TextStyle(
                              fontSize: 11, color: kTextMuted)),
                  ]),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: kTextMuted, size: 17),
          ]),
        ),
      );

  Widget _toggleTile(
    IconData icon,
    Color iconBg,
    Color iconFg,
    String label,
    String subtitle,
    bool value,
    ValueChanged<bool> onChanged,
  ) =>
      Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 10),
        child: Row(children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconFg, size: 17),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 11, color: kTextMuted)),
                ]),
          ),
          Switch.adaptive(
              value: value,
              activeColor: kPrimary,
              onChanged: onChanged),
        ]),
      );

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 8),
        child: Text(
          title.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextMuted,
              letterSpacing: 1.0),
        ),
      );
}

// ── Item model ────────────────────────────────────────────────────────────────
class _Item {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  const _Item(this.icon, this.label, this.subtitle, {this.onTap});
}
// ════════════════════════════════════════════════════════════════════
//  PROFESSIONAL DETAILS SHEET  — overflow fixed
// ════════════════════════════════════════════════════════════════════
class _ProfessionalDetailsSheet extends StatelessWidget {
  final String specialization, qualification, licenseNo, experience,
      fee, clinicName, clinicAddress, clinicEmail, clinicContact,
      websiteName;

  const _ProfessionalDetailsSheet({
    required this.specialization,
    required this.qualification,
    required this.licenseNo,
    required this.experience,
    required this.fee,
    required this.clinicName,
    required this.clinicAddress,
    required this.clinicEmail,
    required this.clinicContact,
    required this.websiteName,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight   = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // ── Sheet header (fixed, not scrollable) ──────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.badge_outlined,
                    size: 17, color: kPrimary),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Professional Details',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary),
                ),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder)),
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: kTextMuted),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kDivider),

          // ── Scrollable rows ───────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  _IRow(Icons.medical_services_outlined, kPrimary,
                      kPrimaryLight, 'Specialization', specialization),
                  _IRow(Icons.school_outlined, kPurple, kPurpleLight,
                      'Qualification', qualification),
                  _IRow(Icons.verified_outlined, kSuccess, kGreenLight,
                      'License No.', licenseNo),
                  _IRow(Icons.work_history_outlined, kSuccess,
                      kGreenLight, 'Experience', experience),
                  _IRow(Icons.currency_rupee_outlined, kWarning,
                      kAmberLight, 'Consultation Fee', fee),
                  _IRow(Icons.local_hospital_outlined, kWarning,
                      kAmberLight, 'Clinic', clinicName),
                  _IRow(Icons.location_on_outlined, kError, kRedLight,
                      'Clinic Address', clinicAddress),
                  _IRow(Icons.email_outlined, kInfo, kInfoLight,
                      'Clinic Email', clinicEmail),
                  _IRow(Icons.phone_outlined, kSuccess, kGreenLight,
                      'Clinic Contact', clinicContact),
                  _IRow(Icons.public_outlined, kPrimary, kPrimaryLight,
                      'Website', websiteName,
                      isLast: true),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PERSONAL INFO SHEET  — overflow fixed (same pattern)
// ════════════════════════════════════════════════════════════════════
class _PersonalInfoSheet extends StatelessWidget {
  final String initials, name, mobile, specialization,
      qualification, clinicName, experience, fee;
  final Future<void> Function()? onProfileEdited;

  const _PersonalInfoSheet({
    required this.initials,
    required this.name,
    required this.mobile,
    required this.specialization,
    required this.qualification,
    required this.clinicName,
    required this.experience,
    required this.fee,
    this.onProfileEdited,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final maxHeight   = MediaQuery.of(context).size.height * 0.85;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // ── Avatar + name row (fixed) ─────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                      colors: [kPrimary, kPrimaryDark],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: kTextPrimary)),
                      const SizedBox(height: 3),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(6)),
                        child: const Text('Verified Doctor',
                            style: TextStyle(
                                fontSize: 11,
                                color: kPrimary,
                                fontWeight: FontWeight.w600)),
                      ),
                    ]),
              ),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                      color: const Color(0xFFF7F8FA),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kBorder)),
                  child: const Icon(Icons.close_rounded,
                      size: 15, color: kTextMuted),
                ),
              ),
            ]),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kDivider),

          // ── Scrollable rows + CTA ─────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  _IRow(Icons.phone_outlined, kSuccess, kGreenLight,
                      'Mobile', mobile),
                  _IRow(Icons.medical_services_outlined, kPrimary,
                      kPrimaryLight, 'Specialization', specialization),
                  _IRow(Icons.school_outlined, kPurple, kPurpleLight,
                      'Qualification', qualification),
                  _IRow(Icons.local_hospital_outlined, kWarning,
                      kAmberLight, 'Clinic', clinicName),
                  _IRow(Icons.work_history_outlined, kSuccess,
                      kGreenLight, 'Experience',
                      experience != '—' ? '$experience years' : '—'),
                  _IRow(Icons.currency_rupee_outlined, kWarning,
                      kAmberLight, 'Consultation Fee', fee,
                      isLast: true),
                  const SizedBox(height: 12),

                  // Edit Profile CTA
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: SizedBox(
                      width: double.infinity,
                      height: 44,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const DoctorEditProfilePage()),
                          ).then((_) => onProfileEdited?.call());
                        },
                        icon: const Icon(Icons.edit_outlined, size: 14),
                        label: const Text('Edit Profile',
                            style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: kPrimary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
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
// ── Shared info row ───────────────────────────────────────────────────────────
class _IRow extends StatelessWidget {
  final IconData icon;
  final Color iconFg, iconBg;
  final String label, value;
  final bool isLast;

  const _IRow(this.icon, this.iconFg, this.iconBg, this.label,
      this.value,
      {this.isLast = false});

  @override
  Widget build(BuildContext context) => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 16, vertical: 10),
          child: Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, color: iconFg, size: 14),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: kTextMuted)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                  ]),
            ),
          ]),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 58, color: kDivider),
      ]);
}

// ════════════════════════════════════════════════════════════════════
//  WHEEL PICKER
// ════════════════════════════════════════════════════════════════════
class _WheelPicker extends StatefulWidget {
  final int value, max;
  final ValueChanged<int> onChanged;

  const _WheelPicker({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
  });

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  late final FixedExtentScrollController _ctrl;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur  = widget.value.clamp(0, widget.max - 1);
    _ctrl = FixedExtentScrollController(initialItem: _cur);
  }

  @override
  void didUpdateWidget(covariant _WheelPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final target = widget.value.clamp(0, widget.max - 1);
      final delta  = (target - _cur).abs();
      if (delta <= 3) {
        _ctrl.animateToItem(target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic);
      } else {
        _ctrl.jumpToItem(target);
      }
      _cur = target;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 30,
            diameterRatio: 2.0,
            perspective: 0.002,
            physics: const FixedExtentScrollPhysics(),
            controller: _ctrl,
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _cur = i);
              widget.onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max,
              builder: (_, i) {
                final sel = i == _cur;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      fontSize: sel ? 16 : 12,
                      fontWeight: sel
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: sel ? kPrimary : kTextMuted,
                    ),
                    child: Text(i.toString().padLeft(2, '0')),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SHIMMER HELPER
// ════════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer(
      {required this.width, required this.height, this.radius = 6});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON — PROFILE CARD
// ════════════════════════════════════════════════════════════════════
class _SkeletonProfileCard extends StatelessWidget {
  const _SkeletonProfileCard();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(children: [
          // gradient strip placeholder
          Container(height: 60, color: const Color(0xFFE2E8F0)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Column(children: [
              Transform.translate(
                offset: const Offset(0, -30),
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE2E8F0),
                    border: Border.all(color: Colors.white, width: 3),
                  ),
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -20),
                child: Column(children: const [
                  _Shimmer(width: 140, height: 14),
                  SizedBox(height: 8),
                  _Shimmer(width: 100, height: 11),
                  SizedBox(height: 4),
                  _Shimmer(width: 80, height: 10),
                  SizedBox(height: 14),
                  // stats row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _Shimmer(width: 50, height: 30),
                      _Shimmer(width: 50, height: 30),
                      _Shimmer(width: 50, height: 30),
                    ],
                  ),
                  SizedBox(height: 14),
                  _Shimmer(
                      width: double.infinity, height: 36, radius: 10),
                ]),
              ),
            ]),
          ),
        ]),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON — SECTION LABEL
// ════════════════════════════════════════════════════════════════════
class _SkeletonSectionLabel extends StatelessWidget {
  const _SkeletonSectionLabel();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 8),
        child: _Shimmer(width: 70, height: 10),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON — TILE CARD
// ════════════════════════════════════════════════════════════════════
class _SkeletonTileCard extends StatelessWidget {
  final int rows;
  const _SkeletonTileCard({required this.rows});

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: List.generate(rows, (i) {
            return Column(children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 13),
                child: Row(children: const [
                  _Shimmer(width: 34, height: 34, radius: 10),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Shimmer(width: 120, height: 12),
                        SizedBox(height: 5),
                        _Shimmer(width: 80, height: 10),
                      ],
                    ),
                  ),
                  _Shimmer(width: 16, height: 16, radius: 4),
                ]),
              ),
              if (i < rows - 1)
                const Divider(height: 1, indent: 56, color: kBorder),
            ]);
          }),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON — FULL SETTINGS BODY
// ════════════════════════════════════════════════════════════════════
class _SkeletonSettingsBody extends StatelessWidget {
  const _SkeletonSettingsBody();

  @override
  Widget build(BuildContext context) => ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 100),
        children: const [
          _SkeletonProfileCard(),
          SizedBox(height: 14),
          _SkeletonSectionLabel(),
          _SkeletonTileCard(rows: 4),
          SizedBox(height: 14),
          _SkeletonSectionLabel(),
          _SkeletonTileCard(rows: 2),
          SizedBox(height: 14),
          _SkeletonSectionLabel(),
          _SkeletonTileCard(rows: 3),
          SizedBox(height: 14),
          _SkeletonSectionLabel(),
          _SkeletonTileCard(rows: 3),
          SizedBox(height: 14),
          _SkeletonSectionLabel(),
          _SkeletonTileCard(rows: 5),
        ],
      );
}
