import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';

// ── Constants (same as DoctorProfilePage) ─────────────────────
const kPrimaryBlue = Color(0xFF1A73E8);
const kLightBlue   = Color(0xFFE8F0FE);
const kAccentGreen = Color(0xFF34A853);
const kRedAccent   = Color(0xFFEA4335);
const kSurface     = Color(0xFFF8F9FA);
const kCardBg      = Color(0xFFFFFFFF);
const kTextDark    = Color(0xFF1F2937);
const kTextMuted   = Color(0xFF6B7280);
const kDivider     = Color(0xFFE5E7EB);

// ── Main Edit Profile Page ─────────────────────────────────────
class DoctorEditProfilePage extends ConsumerStatefulWidget {
  const DoctorEditProfilePage({super.key});

  @override
  ConsumerState<DoctorEditProfilePage> createState() =>
      _DoctorEditProfilePageState();
}

class _DoctorEditProfilePageState
    extends ConsumerState<DoctorEditProfilePage>
    with SingleTickerProviderStateMixin {

  late final TabController _tabController;
  late final ProviderSubscription<DoctorLoginState> _doctorLoginSub;
  bool _didFetchProfile = false;
  bool _didPrefill = false;
  bool _isSubmitting = false;

  // ── Personal Info controllers ────────────────────────────────
  final _nameCtrl         = TextEditingController();
  final _emailCtrl        = TextEditingController();
  final _contactCtrl      = TextEditingController();
  final _qualCtrl         = TextEditingController();
  final _licenseCtrl      = TextEditingController();
  final _expCtrl          = TextEditingController();
  final _feeCtrl          = TextEditingController();
  String  _selectedGender  = 'Male';
  String  _selectedSpec    = 'Cardiology';

  // ── Clinic Info controllers ──────────────────────────────────
  final _clinicNameCtrl    = TextEditingController();
  final _clinicAddrCtrl   = TextEditingController();
  final _clinicContactCtrl = TextEditingController();
  final _clinicEmailCtrl   = TextEditingController();
  final _websiteCtrl       = TextEditingController();

  final _specs = const [
    'Cardiology', 'General Physician', 'Dermatology',
    'Pediatrics', 'Orthopedics',
  ];

  final _genders = const ['Male', 'Female', 'Other'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _doctorLoginSub = ref.listenManual<DoctorLoginState>(
      doctorLoginViewModelProvider,
      (prev, next) {
        _maybeFetchProfile(next);
        _prefillFromState(next);
      },
    );
    Future.microtask(() {
      final state = ref.read(doctorLoginViewModelProvider);
      _maybeFetchProfile(state);
      _prefillFromState(state);
    });
  }

  @override
  void dispose() {
    _doctorLoginSub.close();
    _tabController.dispose();
    _nameCtrl.dispose();    _emailCtrl.dispose();
    _contactCtrl.dispose(); _qualCtrl.dispose();
    _licenseCtrl.dispose(); _expCtrl.dispose();
    _feeCtrl.dispose();
    _clinicNameCtrl.dispose();  _clinicAddrCtrl.dispose();
    _clinicContactCtrl.dispose(); _clinicEmailCtrl.dispose();
    _websiteCtrl.dispose();
    super.dispose();
  }

  void _maybeFetchProfile(DoctorLoginState state) {
    if (_didFetchProfile) return;
    final mobile = state.mobile;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _didFetchProfile = true;
      ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
    }
  }

  void _prefillFromState(DoctorLoginState state) {
    if (_didPrefill) return;
    final details = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    if (details == null) return;
    _didPrefill = true;

    _setTextIfPresent(_nameCtrl, details.name ?? state.name);
    _setTextIfPresent(_emailCtrl, details.email ?? state.email);
    _setTextIfPresent(_contactCtrl, details.mobile ?? state.mobile);
    _setTextIfPresent(_qualCtrl, details.qualification);
    _setTextIfPresent(_licenseCtrl, details.licenseNo);
    _setTextIfPresent(_expCtrl, details.experience?.toString());
    _setTextIfPresent(
      _feeCtrl,
      details.consultationFee?.toStringAsFixed(0),
    );

    _setTextIfPresent(_clinicNameCtrl, details.clinicName ?? state.clinic_name);
    _setTextIfPresent(_clinicAddrCtrl, details.clinicAddress);
    _setTextIfPresent(_clinicContactCtrl, details.clinicContact);
    _setTextIfPresent(_clinicEmailCtrl, details.clinicEmail);
    _setTextIfPresent(_websiteCtrl, details.websiteName);

    _applyGender(details);
    _applySpecialization(details);
    if (mounted) setState(() {});
  }

  void _setTextIfPresent(TextEditingController ctrl, String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    ctrl.text = v;
  }

  void _applyGender(DoctorDetails details) {
    final id = details.genderId;
    if (id == null) return;
    if (id == 2) {
      _selectedGender = 'Female';
    } else if (id == 3) {
      _selectedGender = 'Other';
    } else {
      _selectedGender = 'Male';
    }
  }

  void _applySpecialization(DoctorDetails details) {
    final spec = details.specialization?.trim();
    if (spec == null || spec.isEmpty) return;
    if (_specs.contains(spec)) {
      _selectedSpec = spec;
    }
  }

  Future<void> _save() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final state = ref.read(doctorLoginViewModelProvider);
    final details = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    final doctorId = details?.doctorId ?? state.doctorId;
    final clinicId = details?.clinicId ?? state.clinic_id;
    final roleId = details?.roleId ?? _parseInt(state.roleId);

    final doctor = DoctorDetails(
      doctorId: doctorId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _contactCtrl.text.trim(),
      qualification: _qualCtrl.text.trim(),
      licenseNo: _licenseCtrl.text.trim(),
      experience: _parseInt(_expCtrl.text),
      specialization: _selectedSpec,
      roleId: roleId,
      clinicId: clinicId,
      clinicName: _clinicNameCtrl.text.trim(),
      clinicAddress: _clinicAddrCtrl.text.trim(),
      consultationFee: _parseDouble(_feeCtrl.text),
      websiteName: _websiteCtrl.text.trim(),
      clinicEmail: _clinicEmailCtrl.text.trim(),
      clinicContact: _clinicContactCtrl.text.trim(),
      genderId: _genderIdFor(_selectedGender),
      Token: state.token,
    );

    await ref.read(doctorLoginViewModelProvider.notifier)
        .addDoctorDetails(doctor);

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final after = ref.read(doctorLoginViewModelProvider);
    if (after.error != null && after.error!.isNotEmpty) {
      _showSnack(after.error!, success: false);
      return;
    }

    _showSnack('Doctor details updated successfully', success: true);
    final mobile = after.mobile;
    if (mobile != null && mobile.trim().isNotEmpty) {
      ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
    }
    Navigator.pop(context, true);
  }

  int? _parseInt(String? v) {
    if (v == null) return null;
    return int.tryParse(v.trim());
  }

  double? _parseDouble(String? v) {
    if (v == null) return null;
    return double.tryParse(v.trim());
  }

  int? _genderIdFor(String gender) {
    final g = gender.toLowerCase();
    if (g == 'female') return 2;
    if (g == 'other') return 3;
    return 1;
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? kAccentGreen : kRedAccent,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: kTextDark, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
            color: kTextDark,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 0.5, color: kDivider),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: kCardBg,
                border: Border(bottom: BorderSide(color: kDivider)),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: kPrimaryBlue,
                unselectedLabelColor: kTextMuted,
                labelStyle:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                indicatorColor: kPrimaryBlue,
                indicatorWeight: 2,
                tabs: const [
                  Tab(text: 'Personal Info'),
                  Tab(text: 'Clinic Info'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPersonalTab(),
                  _buildClinicTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Tab 1: Personal Info ───────────────────────────────────────
  Widget _buildPersonalTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Photo picker
          _buildPhotoCard(isDoctor: true),
          const SizedBox(height: 16),

          _sectionLabel('PERSONAL DETAILS'),
          const SizedBox(height: 8),
          _buildCard([
            _fieldTile('Full Name', _nameCtrl),
            _fieldTile('Email', _emailCtrl,
                keyboard: TextInputType.emailAddress),
            _fieldTile('Contact No', _contactCtrl,
                keyboard: TextInputType.phone),
            _genderTile(),
          ]),
          const SizedBox(height: 16),

          _sectionLabel('PROFESSIONAL DETAILS'),
          const SizedBox(height: 8),
          _buildCard([
            _specTile(),
            _fieldTile('Qualification', _qualCtrl),
            _fieldTile('License Number', _licenseCtrl),
            _fieldTile('Experience (Years)', _expCtrl,
                keyboard: TextInputType.number),
            _fieldTile('Consultation Fee (₹)', _feeCtrl,
                keyboard: TextInputType.number, showDivider: false),
          ]),
          const SizedBox(height: 20),
          _saveButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Tab 2: Clinic Info ─────────────────────────────────────────
  Widget _buildClinicTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPhotoCard(isDoctor: false),
          const SizedBox(height: 16),

          _sectionLabel('CLINIC DETAILS'),
          const SizedBox(height: 8),
          _buildCard([
            _fieldTile('Clinic Name', _clinicNameCtrl),
            _fieldTile('Clinic Address', _clinicAddrCtrl,
                maxLines: 3),
            _fieldTile('Clinic Contact', _clinicContactCtrl,
                keyboard: TextInputType.phone),
            _fieldTile('Clinic Email', _clinicEmailCtrl,
                keyboard: TextInputType.emailAddress),
            _fieldTile('Website', _websiteCtrl,
                showDivider: false),
          ]),
          const SizedBox(height: 16),

          _sectionLabel('LOCATION'),
          const SizedBox(height: 8),
          _buildCard([_locationTile()]),
          const SizedBox(height: 20),
          _saveButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Photo card ─────────────────────────────────────────────────
  Widget _buildPhotoCard({required bool isDoctor}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: _cardDeco(),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: kLightBlue,
                  shape: isDoctor
                      ? BoxShape.circle
                      : BoxShape.rectangle,
                  borderRadius: isDoctor
                      ? null
                      : BorderRadius.circular(14),
                  border: Border.all(
                      color: kPrimaryBlue, width: 2.5),
                ),
                child: Icon(
                  isDoctor
                      ? Icons.person
                      : Icons.local_hospital_outlined,
                  size: 38,
                  color: kPrimaryBlue,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    color: kAccentGreen,
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: kCardBg, width: 2),
                  ),
                  child: const Icon(
                    Icons.edit,
                    size: 13,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isDoctor
                ? 'Tap to change photo'
                : 'Tap to change clinic photo',
            style: const TextStyle(
                fontSize: 12, color: kTextMuted),
          ),
        ],
      ),
    );
  }

  // ── Field tile ─────────────────────────────────────────────────
  Widget _fieldTile(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kDivider),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  maxLines: maxLines,
                  style: const TextStyle(
                      fontSize: 13, color: kTextDark),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              thickness: 0.5,
              color: kDivider,
              indent: 14,
              endIndent: 14),
      ],
    );
  }

  // ── Gender selector tile ───────────────────────────────────────
  Widget _genderTile() {
    return Column(
      children: [
        const Divider(height: 1, thickness: 0.5,
            color: kDivider, indent: 14, endIndent: 14),
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Gender',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: _genders.map((g) {
                  final sel = _selectedGender == g;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () =>
                          setState(() => _selectedGender = g),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 200),
                        margin: const EdgeInsets.only(right: 8),
                        height: 40,
                        decoration: BoxDecoration(
                          color: sel
                              ? kTextDark.withOpacity(0.07)
                              : kSurface,
                          borderRadius:
                              BorderRadius.circular(10),
                          border: Border.all(
                            color: sel ? kTextDark : kDivider,
                            width: sel ? 1.5 : 1,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            g,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: sel
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: sel
                                  ? kTextDark
                                  : kTextMuted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Specialization dropdown tile ───────────────────────────────
  Widget _specTile() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: 14, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Specialization',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextMuted,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kDivider),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedSpec,
                    isExpanded: true,
                    icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: kTextMuted, size: 20),
                    style: const TextStyle(
                        fontSize: 13, color: kTextDark),
                    items: _specs
                        .map((s) => DropdownMenuItem(
                            value: s, child: Text(s)))
                        .toList(),
                    onChanged: (v) => setState(
                        () => _selectedSpec = v ?? _selectedSpec),
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 0.5,
            color: kDivider, indent: 14, endIndent: 14),
      ],
    );
  }

  // ── Location tile ──────────────────────────────────────────────
  Widget _locationTile() {
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coordinates',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextMuted,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 44,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12),
                  decoration: BoxDecoration(
                    color: kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kDivider),
                  ),
                  child: const Text(
                    '18.5204, 73.8567',
                    style: TextStyle(
                        fontSize: 13, color: kTextDark),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _LocBtn(
                icon: Icons.my_location_rounded,
                onTap: () {},
                isCircle: true,
              ),
              const SizedBox(width: 8),
              _LocBtn(
                icon: Icons.map_rounded,
                onTap: () {},
                isCircle: false,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Save button ────────────────────────────────────────────────
  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        onPressed: _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          textStyle: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600),
        ),
        child: const Text('Save Changes'),
      ),
    );
  }

  // ── Card wrapper ───────────────────────────────────────────────
  Widget _buildCard(List<Widget> children) {
    return Container(
      decoration: _cardDeco(),
      child: Column(children: children),
    );
  }

  // ── Section label ──────────────────────────────────────────────
  Widget _sectionLabel(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: kTextMuted,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  BoxDecoration _cardDeco() => BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kDivider, width: 0.5),
      );
}

// ── Location icon button ───────────────────────────────────────
class _LocBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isCircle;
  const _LocBtn({
    required this.icon,
    required this.onTap,
    required this.isCircle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: kPrimaryBlue,
          shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
          borderRadius:
              isCircle ? null : BorderRadius.circular(10),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}
