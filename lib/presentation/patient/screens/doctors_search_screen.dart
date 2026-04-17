import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
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
const kPurpleLight= Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);

// ── Specialty → accent / bg ───────────────────────────────────────────────
const _specialtyAccent = <String, Color>{
  'cardiology'   : kError,
  'dermatology'  : kWarning,
  'pediatrics'   : kSuccess,
  'orthopedics'  : kPurple,
  'neurology'    : kInfo,
  'general'      : kPrimary,
  'gynecology'   : kPurple,
  'ophthalmology': kInfo,
};
const _specialtyBg = <String, Color>{
  'cardiology'   : kRedLight,
  'dermatology'  : kAmberLight,
  'pediatrics'   : kGreenLight,
  'orthopedics'  : kPurpleLight,
  'neurology'    : kInfoLight,
  'general'      : kPrimaryLight,
  'gynecology'   : kPurpleLight,
  'ophthalmology': kInfoLight,
};

Color _accentFor(String? s) => _specialtyAccent[s?.toLowerCase()] ?? kPrimary;
Color _bgFor(String? s)     => _specialtyBg[s?.toLowerCase()]     ?? kPrimaryLight;

String _cap(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1).toLowerCase()}';

/// Haversine distance in kilometres between two lat/lng points.
double _haversineKm(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * pi / 180;
  final dLon = (lon2 - lon1) * pi / 180;
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(lat1 * pi / 180) * cos(lat2 * pi / 180) *
          sin(dLon / 2) * sin(dLon / 2);
  return r * 2 * atan2(sqrt(a), sqrt(1 - a));
}

// ── Queue State ───────────────────────────────────────────────────────────
enum _QueueState { noQueue, unavailable, opensSoon, full, open, hasQueue }

_QueueState _queueStateFor(DoctorDetails d) {
  if (d.isQueueAvailable == null) return _QueueState.noQueue;
  if (d.isQueueAvailable == 0)    return _QueueState.unavailable;
  if (d.isBookingStarted != 1)    return _QueueState.opensSoon;
  if (d.isQueueFull == 1)         return _QueueState.full;
  final cur = d.currentQueueLength ?? 0;
  final max = d.maxQueueLength ?? 0;
  if (cur == 0 && max == 0)       return _QueueState.open;
  return _QueueState.hasQueue;
}

class _QueueStatus {
  final bool isVisible, canBook, tintCard;
  final String label, btnLabel;
  final Color color;
  final IconData icon;
  final double? progress;

  const _QueueStatus({
    required this.isVisible, required this.canBook, required this.tintCard,
    required this.label,     required this.btnLabel,
    required this.color,     required this.icon,
    this.progress,
  });

  factory _QueueStatus.from(DoctorDetails d) {
    final state = _queueStateFor(d);
    switch (state) {
      case _QueueState.noQueue:
        return const _QueueStatus(isVisible: false, canBook: true, tintCard: false,
            label: '', btnLabel: 'Book', color: kPrimary, icon: Icons.calendar_today_rounded);
      case _QueueState.unavailable:
        return const _QueueStatus(isVisible: true, canBook: false, tintCard: true,
            label: 'Queue unavailable', btnLabel: 'Unavailable',
            color: kError, icon: Icons.block_rounded);
      case _QueueState.opensSoon:
        final opensAt = d.bookingStartTime;
        final label   = opensAt != null ? 'Queue opens $opensAt' : 'Queue opens soon';
        if (d.isSlotAvailable == 1) {
          return _QueueStatus(isVisible: true, canBook: true, tintCard: false,
              label: label, btnLabel: 'Book', color: kWarning, icon: Icons.schedule_rounded);
        }
        return _QueueStatus(isVisible: true, canBook: false, tintCard: false,
            label: label, btnLabel: 'Soon', color: kWarning, icon: Icons.schedule_rounded);
      case _QueueState.full:
        return const _QueueStatus(isVisible: true, canBook: false, tintCard: true,
            label: 'Queue full', btnLabel: 'Full', color: kError, icon: Icons.group_off_rounded);
      case _QueueState.open:
        return const _QueueStatus(isVisible: true, canBook: true, tintCard: false,
            label: 'Queue open', btnLabel: 'Book', color: kPrimary, icon: Icons.event_available_rounded);
      case _QueueState.hasQueue:
        final cur  = d.currentQueueLength ?? 0;
        final max  = d.maxQueueLength ?? 1;
        final prog = (cur / max).clamp(0.0, 1.0);
        return _QueueStatus(
          isVisible: true, canBook: true, tintCard: false,
          label: '$cur / $max in queue', btnLabel: 'Book',
          color: cur > 5 ? kError : kWarning,
          icon: Icons.people_alt_rounded, progress: prog,
        );
    }
  }

  Color get dot => canBook ? kPrimary : kError;
}

// ════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════════════════════════
class DoctorSearchScreen extends ConsumerStatefulWidget {
  final String? initialSpecialty;
  const DoctorSearchScreen({super.key, this.initialSpecialty});
 
  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen>
    with SingleTickerProviderStateMixin {
  final _searchCtrl = TextEditingController();
  String? _specialty;
  int?    _selectedMemberId;
  bool    _favOnly = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double>   _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    Future.delayed(const Duration(milliseconds: 80), () => _fadeCtrl.forward());

    WidgetsBinding.instance.addPostFrameCallback((_) {

      ref.read(doctorsViewModelProvider.notifier).fetchDoctors(ref.read(patientLoginViewModelProvider).patientId ?? 0);
      final pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid > 0) {
        ref.read(familyViewModelProvider.notifier).fetchAllFamilyMembers(pid);
      }

            if (widget.initialSpecialty != null) {
        setState(() => _specialty = widget.initialSpecialty);
      }
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  List<DoctorDetails> _filtered(List<DoctorDetails> all) {
    return all.where((d) {
      final q      = _searchCtrl.text.toLowerCase();
      final matchQ = q.isEmpty ||
          (d.name?.toLowerCase().contains(q) ?? false) ||
          (d.specialization?.toLowerCase().contains(q) ?? false) ||
          (d.clinicName?.toLowerCase().contains(q) ?? false);
      final matchS = _specialty == null || d.specialization == _specialty;
      return matchQ && matchS;
    }).toList();
  }

  List<String> _specialties(List<DoctorDetails> all) {
    final seen = <String>{};
    return all
        .map((d) => d.specialization ?? '')
        .where((s) => s.isNotEmpty && seen.add(s))
        .toList();
  }

  Future<void> _refresh() async =>
      ref.read(doctorsViewModelProvider.notifier).fetchDoctors(ref.read(patientLoginViewModelProvider).patientId ?? 0);

  @override
  Widget build(BuildContext context) {
    final doctorsState = ref.watch(doctorsViewModelProvider);
    final patState     = ref.watch(patientLoginViewModelProvider);
    final famState     = ref.watch(familyViewModelProvider);

    final allDoctors = doctorsState.doctors;
    final members    = famState.allfamilyMembers.maybeWhen(
        data: (m) => m, orElse: () => <FamilyMember>[]);
    final docs       = _filtered(allDoctors);
    final specialties= _specialties(allDoctors);
    final isLoading  = doctorsState.isLoading;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildBookingRow(patState, members),
              _buildSearchBar(),
              if (!_favOnly)
                _buildSpecialtyChips(specialties)
              else
                _buildFavStrip(),
              if (!isLoading) _buildCountBadge(docs.length),
              Expanded(
                child: isLoading
                    ? const _LoadingShimmer()
                    : _buildDoctorList(docs),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 14, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _favOnly ? 'Favorites' : 'Find a Doctor',
                  style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: kTextPrimary),
                ),
                const SizedBox(height: 1),
                Text(
                  _favOnly ? 'Your saved doctors' : 'Book your appointment',
                  style: const TextStyle(fontSize: 11, color: kTextMuted),
                ),
              ],
            ),
          ),
          // Notification bell
          Container(
            width: 36, height: 36,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                color: kPrimary, size: 17),
          ),
          // Favorites toggle
          GestureDetector(
            onTap: () => setState(() {
              _favOnly = !_favOnly;
              if (!_favOnly) _specialty = null;
            }),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: _favOnly ? kRedLight : kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _favOnly
                      ? kError.withOpacity(0.3)
                      : kPrimary.withOpacity(0.2),
                ),
              ),
              child: Icon(
                _favOnly
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                color: _favOnly ? kError : kPrimary,
                size: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Booking Row
  // ---------------------------------------------------------------------------

  Widget _buildBookingRow(PatientLoginState patState, List<FamilyMember> members) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      decoration: BoxDecoration(
        color: kPrimaryLight.withOpacity(0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kPrimary.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_outline_rounded, color: kPrimary, size: 14),
          const SizedBox(width: 6),
          const Text('Booking for:',
              style: TextStyle(
                  fontSize: 12, color: kTextSecondary)),
          const SizedBox(width: 4),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<int?>(
                value: _selectedMemberId,
                isDense: true,
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded,
                    size: 15, color: kPrimary),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(12),
                hint: Text(
                  patState.name ?? 'Myself',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: kPrimary),
                ),
                items: [
                  DropdownMenuItem<int?>(
                    value: null,
                    child: _MemberOption(
                        label: patState.name ?? 'Myself',
                        sub: 'Self',
                        color: kPrimary),
                  ),
                  ...members.map((m) => DropdownMenuItem<int?>(
                        value: m.memberId,
                        child: _MemberOption(
                            label: m.memberName?.split(' ').first ?? '?',
                            sub: m.relationName ?? '',
                            color: kPurple),
                      )),
                ],
                onChanged: (id) => setState(() => _selectedMemberId = id),
                selectedItemBuilder: (ctx) => [
                  _DropSelected(patState.name ?? 'Myself'),
                  ...members.map(
                      (m) => _DropSelected(m.memberName?.split(' ').first ?? '?')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Search Bar
  // ---------------------------------------------------------------------------

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 11),
              child: Icon(Icons.search_rounded, color: kTextMuted, size: 17),
            ),
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Doctor, specialty, clinic…',
                  hintStyle: TextStyle(fontSize: 13, color: kTextMuted),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            _searchCtrl.text.isNotEmpty
                ? GestureDetector(
                    onTap: () { _searchCtrl.clear(); setState(() {}); },
                    child: Container(
                      margin: const EdgeInsets.only(right: 10),
                      width: 18, height: 18,
                      decoration: const BoxDecoration(
                          color: kTextMuted, shape: BoxShape.circle),
                      child: const Icon(Icons.close_rounded,
                          size: 11, color: Colors.white),
                    ),
                  )
                : Container(
                    margin: const EdgeInsets.only(right: 8),
                    width: 26, height: 26,
                    decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(7)),
                    child: const Icon(Icons.tune_rounded,
                        color: Colors.white, size: 13),
                  ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Specialty Chips
  // ---------------------------------------------------------------------------

  Widget _buildSpecialtyChips(List<String> specialties) {
    return SizedBox(
      height: 36,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
        children: [
          _SpecChip(
            label: 'All',
            selected: _specialty == null,
            accent: kPrimary,
            bg: kPrimaryLight,
            onTap: () => setState(() => _specialty = null),
          ),
          ...specialties.map((s) => _SpecChip(
                label: _cap(s),
                selected: _specialty == s,
                accent: _accentFor(s),
                bg: _bgFor(s),
                onTap: () =>
                    setState(() => _specialty = s == _specialty ? null : s),
              )),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Fav Strip
  // ---------------------------------------------------------------------------

  Widget _buildFavStrip() {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 8, 14, 0),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: kRedLight.withOpacity(0.4),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: kError.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.favorite_rounded, color: kError, size: 13),
          const SizedBox(width: 6),
          const Expanded(
            child: Text('Showing favorites only',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kError)),
          ),
          GestureDetector(
            onTap: () => setState(() => _favOnly = false),
            child: const Text('Show all',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                    decoration: TextDecoration.underline,
                    decorationColor: kPrimary)),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Count Badge
  // ---------------------------------------------------------------------------

  Widget _buildCountBadge(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 0),
      child: Row(
        children: [
          Container(
            width: 6, height: 6,
            decoration: const BoxDecoration(
                color: kPrimary, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            _favOnly
                ? '$count favorite${count == 1 ? '' : 's'}'
                : '$count doctors available',
            style: const TextStyle(
                fontSize: 11,
                color: kTextSecondary,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Doctor List
  // ---------------------------------------------------------------------------

  Widget _buildDoctorList(List<DoctorDetails> docs) {
    if (docs.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60, height: 60,
              decoration: const BoxDecoration(
                  color: kPrimaryLight, shape: BoxShape.circle),
              child: Icon(
                _favOnly
                    ? Icons.favorite_border_rounded
                    : Icons.search_off_rounded,
                size: 28, color: kPrimary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _favOnly ? 'No favorites yet' : 'No results found',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary),
            ),
            const SizedBox(height: 4),
            const Text('Try a different search',
                style: TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _refresh,
      color: kPrimary,
      strokeWidth: 2,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: docs.length,
        itemBuilder: (_, i) => _DoctorCard(
          doctor: docs[i],
          selectedMemberId: _selectedMemberId,
          onBook: (d) => Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BookAppointmentScreen(
                doctor: d,
                bookingForMemberId: _selectedMemberId,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  BOOKING ROW HELPERS
// ════════════════════════════════════════════════════════════════════
class _MemberOption extends StatelessWidget {
  final String label, sub;
  final Color color;
  const _MemberOption(
      {required this.label, required this.sub, required this.color});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          CircleAvatar(
            radius: 10,
            backgroundColor: color.withOpacity(0.15),
            child: Text(label.isNotEmpty ? label[0] : '?',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              Text(sub,
                  style: const TextStyle(fontSize: 10, color: kTextMuted)),
            ],
          ),
        ],
      );
}

class _DropSelected extends StatelessWidget {
  final String text;
  const _DropSelected(this.text);
  @override
  Widget build(BuildContext context) => Align(
        alignment: Alignment.centerLeft,
        child: Text(text,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: kPrimary)),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP
// ════════════════════════════════════════════════════════════════════
class _SpecChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color accent, bg;
  final VoidCallback onTap;
  const _SpecChip({
    required this.label, required this.selected,
    required this.accent, required this.bg, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? accent : bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? accent : accent.withOpacity(0.25),
          ),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : accent)),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  DOCTOR CARD
// ════════════════════════════════════════════════════════════════════
class _DoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final int?          selectedMemberId;
  final void Function(DoctorDetails) onBook;

  const _DoctorCard({
    required this.doctor,
    required this.selectedMemberId,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    final d          = doctor;
    final qs         = _QueueStatus.from(d);
    final accent     = _accentFor(d.specialization);
    final specBg     = _bgFor(d.specialization);
    final init       = (d.name?.isNotEmpty ?? false)
        ? d.name![0].toUpperCase()
        : 'D';
    final clinicText = [d.clinicName, d.clinicAddress]
        .where((s) => s != null && s.isNotEmpty)
        .join(' · ');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: qs.tintCard ? kError.withOpacity(0.25) : kBorder,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Avatar ────────────────────────────────────────
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: accent.withOpacity(0.2), width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(init,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: accent)),
              ),
              // Status dot
              Positioned(
                bottom: -2, right: -2,
                child: Container(
                  width: 12, height: 12,
                  decoration: BoxDecoration(
                    color: qs.dot,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Info ──────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + fee
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        'Dr. ${d.name ?? 'Unknown'}',
                        style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (d.consultationFee != null) ...[
                      const SizedBox(width: 6),
                      _FeeTag(fee: d.consultationFee!),
                    ],
                  ],
                ),
                const SizedBox(height: 4),

                // Specialty + experience + rating
                Row(
                  children: [
                    if (d.specialization != null)
                      _SpecTag(
                          label: _cap(d.specialization!),
                          accent: accent,
                          bg: specBg),
                    if (d.experience != null) ...[
                      const SizedBox(width: 6),
                      _ExpTag(years: d.experience!),
                    ],
                    const Spacer(),
                    const _RatingDot(),
                  ],
                ),

                // Clinic
                if (clinicText.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on_rounded,
                          size: 10, color: kTextMuted),
                      const SizedBox(width: 2),
                      Expanded(
                        child: Text(clinicText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontSize: 11, color: kTextMuted)),
                      ),
                    ],
                  ),
                ],

                // Queue pill
                if (qs.isVisible) ...[
                  const SizedBox(height: 5),
                  _QueuePill(status: qs),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),

          // ── Book Button ───────────────────────────────────
          _BookButton(status: qs, onBook: () => onBook(doctor)),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  CARD SUB-COMPONENTS
// ════════════════════════════════════════════════════════════════════
class _FeeTag extends StatelessWidget {
  final double fee;
  const _FeeTag({required this.fee});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: kPrimaryLight, borderRadius: BorderRadius.circular(6)),
        child: Text('₹${fee.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kPrimary)),
      );
}

class _SpecTag extends StatelessWidget {
  final String label;
  final Color accent, bg;
  const _SpecTag(
      {required this.label, required this.accent, required this.bg});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
            color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: accent)),
      );
}

class _ExpTag extends StatelessWidget {
  final int years;
  const _ExpTag({required this.years});
  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.workspace_premium_rounded,
              size: 11, color: kWarning),
          const SizedBox(width: 2),
          Text('${years}y exp',
              style: const TextStyle(fontSize: 11, color: kTextMuted)),
        ],
      );
}

class _RatingDot extends StatelessWidget {
  const _RatingDot();
  @override
  Widget build(BuildContext context) => const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star_rounded, size: 11, color: kWarning),
          SizedBox(width: 2),
          Text('4.8',
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary)),
        ],
      );
}

class _QueuePill extends StatelessWidget {
  final _QueueStatus status;
  const _QueuePill({required this.status});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(
              color: status.color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(status.icon, size: 11, color: status.color),
                const SizedBox(width: 4),
                Text(status.label,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: status.color)),
              ],
            ),
          ),
          if (status.progress != null) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 52,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: status.progress,
                  minHeight: 3,
                  backgroundColor: kBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(status.color),
                ),
              ),
            ),
          ],
        ],
      );
}

class _BookButton extends StatelessWidget {
  final _QueueStatus status;
  final VoidCallback onBook;
  const _BookButton({required this.status, required this.onBook});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 64, height: 36,
          child: ElevatedButton(
            onPressed: status.canBook ? onBook : null,
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  status.canBook ? kPrimary : status.color.withOpacity(0.1),
              foregroundColor:
                  status.canBook ? Colors.white : status.color,
              disabledBackgroundColor: status.color.withOpacity(0.1),
              disabledForegroundColor: status.color,
              elevation: 0,
              padding: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              textStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w700),
            ),
            child: Text(status.btnLabel),
          ),
        ),
        if (status.canBook) ...[
          const SizedBox(height: 3),
          const Text('~15 min',
              style: TextStyle(fontSize: 10, color: kTextMuted)),
        ],
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LOADING SHIMMER
// ════════════════════════════════════════════════════════════════════
class _LoadingShimmer extends StatefulWidget {
  const _LoadingShimmer();
  @override
  State<_LoadingShimmer> createState() => _LoadingShimmerState();
}

class _LoadingShimmerState extends State<_LoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double>   _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
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
      builder: (_, __) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
        itemCount: 5,
        itemBuilder: (_, __) => _ShimmerCard(phase: _anim.value),
      ),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  final double phase;
  const _ShimmerCard({required this.phase});

  Color get _s1 =>
      Color.lerp(const Color(0xFFE2E8F0), const Color(0xFFF7F9FC), phase)!;
  Color get _s2 =>
      Color.lerp(const Color(0xFFF1F5F9), const Color(0xFFE2E8F0), phase)!;

  Widget _bar(double w, double h) => Container(
        width: w, height: h,
        margin: const EdgeInsets.only(bottom: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: [_s1, _s2, _s1],
              stops: [0, 0.5 + phase * 0.3, 1]),
          borderRadius: BorderRadius.circular(4),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
                color: _s1, borderRadius: BorderRadius.circular(12)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [_bar(140, 14), _bar(90, 11), _bar(110, 11)],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 64, height: 36,
            decoration: BoxDecoration(
                color: _s1, borderRadius: BorderRadius.circular(10)),
          ),
        ],
      ),
    );
  }
}