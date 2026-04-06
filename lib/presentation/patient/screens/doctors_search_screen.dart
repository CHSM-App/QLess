import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ─── Colour tokens (matches app palette) ─────────────────────────────────────
const _kNavy = Color(0xFF0F172A);
const _kBlue = Color(0xFF3B82F6);
const _kSlate = Color(0xFF64748B);
const _kBorder = Color(0xFFE2E8F0);
const _kSurface = Color(0xFFF8FAFC);

// ─── Specialty → colour map ───────────────────────────────────────────────────
const _specialtyColors = <String, Color>{
  'cardiology': Color(0xFFEF4444),
  'dermatology': Color(0xFFF59E0B),
  'pediatrics': Color(0xFF10B981),
  'orthopedics': Color(0xFF8B5CF6),
  'neurology': Color(0xFF3B82F6),
  'general': Color(0xFF06B6D4),
  'gynecology': Color(0xFFEC4899),
  'ophthalmology': Color(0xFF14B8A6),
};

Color _colorFor(String? spec) =>
    spec == null ? _kBlue : (_specialtyColors[spec.toLowerCase()] ?? _kBlue);

String _capitalize(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

// ─── Screen ───────────────────────────────────────────────────────────────────

class DoctorSearchScreen extends ConsumerStatefulWidget {
  const DoctorSearchScreen({super.key});

  @override
  ConsumerState<DoctorSearchScreen> createState() => _DoctorSearchScreenState();
}

class _DoctorSearchScreenState extends ConsumerState<DoctorSearchScreen> {
  final _searchController = TextEditingController();
  String? _selectedSpecialty; // null = All
  int? _selectedMemberId; // null = patient themselves
  bool _hasFetchedDoctors = false;
  bool _hasFetchedFamily = false;
  ProviderSubscription<TokenState>? _tokenSub;
  ProviderSubscription<PatientLoginState>? _patientSub;

  @override
  void initState() {
    super.initState();
    _tokenSub = ref.listenManual<TokenState>(
      tokenProvider,
      (prev, next) => _tryFetch(),
    );
    _patientSub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) => _tryFetch(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) => _tryFetch());
  }

  void _tryFetch() {
    final tokenState = ref.read(tokenProvider);
    final tokenReady = !tokenState.isLoading &&
        (tokenState.accessToken ?? '').isNotEmpty;
    if (tokenReady && !_hasFetchedDoctors) {
      _hasFetchedDoctors = true;
      ref.read(doctorsViewModelProvider.notifier).fetchDoctors();
    }

    final patientId =
        ref.read(patientLoginViewModelProvider).patientId ?? 0;
    if (tokenReady && patientId > 0 && !_hasFetchedFamily) {
      _hasFetchedFamily = true;
      ref
          .read(familyViewModelProvider.notifier)
          .fetchAllFamilyMembers(patientId);
    }
  }
  @override
  void dispose() {
    _searchController.dispose();
    _tokenSub?.close();
    _patientSub?.close();
    super.dispose();
  }

  // ── Filtered list ─────────────────────────────────────────────────────────

  List<DoctorDetails> _filtered(List<DoctorDetails> all) {
    return all.where((d) {
      final q = _searchController.text.toLowerCase();
      final matchesQuery =
          _searchController.text.isEmpty ||
          (d.name?.toLowerCase().contains(q) ?? false) ||
          (d.specialization?.toLowerCase().contains(q) ?? false) ||
          (d.clinicName?.toLowerCase().contains(q) ?? false);
      final matchesSpec =
          _selectedSpecialty == null ||
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
    final familyState = ref.watch(familyViewModelProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F172A) : _kSurface;

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ───────────────────────────────────────────────────────
            _Header(isDark: isDark),

            // ── "Booking for" dropdown ────────────────────────────────────
            familyState.allfamilyMembers.maybeWhen(
              data: (members) => _BookingForDropdown(
                patientState: patientState,
                members: members,
                selectedMemberId: _selectedMemberId,
                onSelected: (id) => setState(() => _selectedMemberId = id),
                isDark: isDark,
              ),
              orElse: () => const SizedBox.shrink(),
            ),

            // ── Search bar ────────────────────────────────────────────────
            _SearchBar(
              controller: _searchController,
              isDark: isDark,
              onChanged: (_) => setState(() {}),
            ),

            // ── Specialty chips ───────────────────────────────────────────
            if (doctorsState.doctors.isNotEmpty)
              _SpecialtyChips(
                specialties: _uniqueSpecialties(doctorsState.doctors),
                selected: _selectedSpecialty,
                onSelected: (s) => setState(
                  () => _selectedSpecialty = s == _selectedSpecialty ? null : s,
                ),
              ),

            // ── List / states ─────────────────────────────────────────────
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

class _Header extends StatelessWidget {
  final bool isDark;
  const _Header({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: isDark ? const Color(0xFF1E293B) : Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
      child: Row(
        children: [
          const Text(
            'Find Doctors',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: _kNavy,
              letterSpacing: -0.4,
            ),
          ),
          const Spacer(),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: _kBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.tune_rounded, color: _kBlue, size: 20),
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
  final PatientLoginState patientState;
  final List<FamilyMember> members;
  final int? selectedMemberId;
  final ValueChanged<int?> onSelected;
  final bool isDark;

  const _BookingForDropdown({
    required this.patientState,
    required this.members,
    required this.selectedMemberId,
    required this.onSelected,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Build items: patient first, then family members
    final items = <DropdownMenuItem<int?>>[
      DropdownMenuItem<int?>(
        value: null,
        child: Row(
          children: [
            CircleAvatar(
              radius: 12,
              backgroundColor: _kNavy.withValues(alpha: 0.12),
              child: Text(
                (patientState.name?.isNotEmpty ?? false)
                    ? patientState.name![0].toUpperCase()
                    : 'M',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kNavy,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  patientState.name ?? 'Me',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: _kNavy,
                  ),
                ),
                const Text(
                  'You',
                  style: TextStyle(fontSize: 10, color: _kSlate),
                ),
              ],
            ),
          ],
        ),
      ),
      ...members.map((m) {
        final color = _colorFor(m.relationName);
        return DropdownMenuItem<int?>(
          value: m.memberId,
          child: Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: color.withValues(alpha: 0.12),
                child: Text(
                  m.memberName?.isNotEmpty == true
                      ? m.memberName![0].toUpperCase()
                      : '?',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    m.memberName ?? '?',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _kNavy,
                    ),
                  ),
                  if (m.relationName?.isNotEmpty == true)
                    Text(
                      m.relationName!,
                      style: const TextStyle(fontSize: 10, color: _kSlate),
                    ),
                ],
              ),
            ],
          ),
        );
      }),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 2),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: _kBlue.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _kBlue.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.person_pin_circle_rounded, color: _kBlue, size: 18),
          const SizedBox(width: 8),
          const Text(
            'Booking for',
            style: TextStyle(fontSize: 13, color: _kSlate),
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
                  size: 18,
                  color: _kBlue,
                ),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: _kBlue,
                ),
                dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                items: items,
                onChanged: (val) => onSelected(val),
                selectedItemBuilder: (_) => [
                  // patient
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      patientState.name ?? 'Me',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: _kBlue,
                      ),
                    ),
                  ),
                  // family members
                  ...members.map(
                    (m) => Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        m.memberName ?? 'Member',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: _kBlue,
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
  final ValueChanged<String> onChanged;
  final bool isDark;

  const _SearchBar({
    required this.controller,
    required this.onChanged,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: controller,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: _kNavy),
          decoration: InputDecoration(
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: _kSlate,
              size: 20,
            ),
            hintText: 'Search by name, specialty, clinic…',
            hintStyle: const TextStyle(fontSize: 13.5, color: _kSlate),
            suffixIcon: controller.text.isNotEmpty
                ? IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: _kSlate,
                    ),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SPECIALTY CHIPS
// ─────────────────────────────────────────────────────────────────────────────

class _SpecialtyChips extends StatelessWidget {
  final List<String> specialties;
  final String? selected;
  final ValueChanged<String> onSelected;

  const _SpecialtyChips({
    required this.specialties,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: specialties.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final spec = specialties[i];
          final isSelected = selected == spec;
          final color = _colorFor(spec);
          return GestureDetector(
            onTap: () => onSelected(spec),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? color : color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? color : color.withValues(alpha: 0.3),
                ),
              ),
              child: Text(
                _capitalize(spec),
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
            ),
          );
        },
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
  final Future<void> Function() onRefresh;

  const _DoctorList({
    required this.doctors,
    required this.isDark,
    required this.selectedMemberId,
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
              Icons.search_off_rounded,
              size: 52,
              color: _kSlate.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 12),
            const Text(
              'No doctors match your search',
              style: TextStyle(fontSize: 15, color: _kSlate),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: _kBlue,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        itemCount: doctors.length,
        itemBuilder: (_, i) => _DoctorCard(
          doctor:           doctors[i],
          isDark:           isDark,
          selectedMemberId: selectedMemberId,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DOCTOR CARD
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final bool          isDark;
  final int?          selectedMemberId;

  const _DoctorCard({
    required this.doctor,
    required this.isDark,
    required this.selectedMemberId,
  });

  @override
  Widget build(BuildContext context) {
    final specColor = _colorFor(doctor.specialization);
    final initial = (doctor.name?.isNotEmpty ?? false)
        ? doctor.name![0].toUpperCase()
        : 'D';

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [specColor, specColor.withValues(alpha: 0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Info column
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Dr. ${doctor.name ?? 'Unknown'}',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: _kNavy,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (doctor.consultationFee != null)
                        Text(
                          '₹${doctor.consultationFee!.toStringAsFixed(0)}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF059669),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (doctor.specialization != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: specColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5),
                          ),
                          child: Text(
                            _capitalize(doctor.specialization!),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              color: specColor,
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      if (doctor.experience != null)
                        Text(
                          '${doctor.experience} yrs',
                          style: const TextStyle(fontSize: 11, color: _kSlate),
                        ),
                    ],
                  ),
                  if (doctor.clinicName != null ||
                      doctor.clinicAddress != null) ...[
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_hospital_rounded,
                          size: 11,
                          color: _kSlate,
                        ),
                        const SizedBox(width: 3),
                        Expanded(
                          child: Text(
                            [doctor.clinicName, doctor.clinicAddress]
                                .where((s) => s != null && s.isNotEmpty)
                                .join(' · '),
                            style: const TextStyle(
                              fontSize: 11,
                              color: _kSlate,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                  if (doctor.queueLength != null) ...[
                    const SizedBox(height: 5),
                    Row(
                      children: [
                        const Icon(
                          Icons.people_alt_rounded,
                          size: 11,
                          color: Color(0xFFF59E0B),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          doctor.queueLength == 0
                              ? 'No queue'
                              : '${doctor.queueLength} in queue',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFF59E0B),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Book button
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookAppointmentScreen(
                      doctor:           doctor,
                      bookingForMemberId: selectedMemberId,
                    ),
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _kNavy,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                child: const Text('Book'),
              ),
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
      itemCount: 5,
      itemBuilder: (_, __) => _ShimmerCard(),
    );
  }
}

class _ShimmerCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _ShimmerBox(width: 60, height: 60, radius: 30),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _ShimmerBox(width: 140, height: 14, radius: 4),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 90, height: 22, radius: 6),
                    const SizedBox(height: 8),
                    _ShimmerBox(width: 110, height: 10, radius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _ShimmerBox(width: double.infinity, height: 1, radius: 0),
          const SizedBox(height: 12),
          Row(
            children: [
              _ShimmerBox(width: 90, height: 28, radius: 8),
              const SizedBox(width: 8),
              _ShimmerBox(width: 130, height: 28, radius: 8),
            ],
          ),
          const SizedBox(height: 14),
          _ShimmerBox(width: double.infinity, height: 44, radius: 10),
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
      color: const Color(0xFFE2E8F0),
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
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: _kBlue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.medical_services_outlined,
                size: 36,
                color: _kBlue,
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No doctors found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _kNavy,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We couldn\'t load the doctors list.\nCheck your connection and try again.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, color: _kSlate, height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _kNavy,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
