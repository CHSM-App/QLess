import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ── Colour palette ────────────────────────────────────────────────
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
const kMuted     = Color(0xFF9CA3AF);

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Roboto',
        scaffoldBackgroundColor: kBg,
        colorScheme: ColorScheme.fromSeed(seedColor: kPrimary),
      ),
      home: const PatientEditProfilePage(),
    );
  }
}

class PatientEditProfilePage extends ConsumerStatefulWidget {
  const PatientEditProfilePage({super.key});
  @override
  ConsumerState<PatientEditProfilePage> createState() =>
      _PatientEditProfilePageState();
}

class _PatientEditProfilePageState extends ConsumerState<PatientEditProfilePage> {
  final _formKey = GlobalKey<FormState>();

  final _nameController    = TextEditingController();
  final _mobileController  = TextEditingController();
  final _emailController   = TextEditingController();
  final _addressController = TextEditingController();
  final _weightController  = TextEditingController();

  String    _selectedGender     = 'Female';
  String    _selectedBloodGroup = 'B+';
  DateTime? _selectedDob        = DateTime(1992, 3, 12);

  late final ProviderSubscription<PatientLoginState> _patientLoginSub;
  bool _didFetchProfile = false;
  bool _didPrefill = false;
  bool _didSubmit = false;

  final _bloodGroups = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];
  final _genders     = ['Male', 'Female', 'Other'];
  final _genderIcons = <String, IconData>{
    'Male'  : Icons.male_rounded,
    'Female': Icons.female_rounded,
    'Other' : Icons.transgender_rounded,
  };

  @override
  void initState() {
    super.initState();
    _patientLoginSub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) {
        _maybeFetchProfile(next);
        _prefillFromState(next);
        _handleSubmit(prev, next);
      },
    );
    Future.microtask(() {
      final state = ref.read(patientLoginViewModelProvider);
      _maybeFetchProfile(state);
      _prefillFromState(state);
    });
  }

  @override
  void dispose() {
    _patientLoginSub.close();
    _nameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _maybeFetchProfile(PatientLoginState state) {
    if (_didFetchProfile) return;
    final mobile = state.mobileNo;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _didFetchProfile = true;
      ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
    }
  }

  void _prefillFromState(PatientLoginState state) {
    if (_didPrefill) return;
    final details = state.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    if (details == null) return;
    _didPrefill = true;

    _setTextIfPresent(_nameController, details.name ?? state.name);
    _setTextIfPresent(_mobileController, details.mobileNo ?? state.mobileNo);
    _setTextIfPresent(_emailController, details.email ?? state.email);
    _setTextIfPresent(_addressController, details.address);
    _setTextIfPresent(_weightController, details.weight);

    _applyGender(details);
    _applyBloodGroup(details);
    _selectedDob = details.DOB ?? _selectedDob;
    if (mounted) setState(() {});
  }

  void _handleSubmit(PatientLoginState? prev, PatientLoginState next) {
    if (!_didSubmit) return;
    final prevSuccess = prev?.isSuccess ?? false;
    if (next.isSuccess && !prevSuccess) {
      _didSubmit = false;
      _showSnack('Profile updated successfully', success: true);
      final mobile = next.mobileNo;
      if (mobile != null && mobile.trim().isNotEmpty) {
        ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
      }
      Future.delayed(const Duration(milliseconds: 300), () {
        if (!mounted) return;
        Navigator.pop(context, true);
      });
      return;
    }
    if (next.error != null && next.error != prev?.error) {
      _didSubmit = false;
      _showSnack(next.error ?? 'Failed to update profile', success: false);
    }
  }

  void _setTextIfPresent(TextEditingController ctrl, String? value) {
    final v = value?.trim();
    if (v == null || v.isEmpty) return;
    ctrl.text = v;
  }

  void _applyGender(Patients details) {
    final g = details.gender?.trim();
    if (g != null && g.isNotEmpty && _genders.contains(g)) {
      _selectedGender = g;
      return;
    }
    final id = details.genderId;
    if (id == 2) {
      _selectedGender = 'Female';
    } else if (id == 3) {
      _selectedGender = 'Other';
    } else if (id == 1) {
      _selectedGender = 'Male';
    }
  }

  void _applyBloodGroup(Patients details) {
    final bg = details.bloodGroup?.trim();
    if (bg != null && bg.isNotEmpty) {
      final match = _bloodGroups.contains(bg) ? bg : null;
      if (match != null) _selectedBloodGroup = match;
    }
  }

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1992, 3, 12),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: kPrimary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  String get _formattedDob {
    if (_selectedDob == null) return 'Select date of birth';
    return '${_selectedDob!.day.toString().padLeft(2, '0')} / '
        '${_selectedDob!.month.toString().padLeft(2, '0')} / '
        '${_selectedDob!.year}';
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state = ref.read(patientLoginViewModelProvider);
    final patientId = state.patientId ?? 0;
    final genderId = _genderIdFor(_selectedGender);
    final bloodGroupId = _bloodGroupIdFor(_selectedBloodGroup);

    final patient = Patients(
      patientId: patientId > 0 ? patientId : null,
      name: _nameController.text.trim(),
      mobileNo: _mobileController.text.trim(),
      email: _emailController.text.trim(),
      address: _addressController.text.trim(),
      genderId: genderId,
      DOB: _selectedDob,
      bloodGroupId: bloodGroupId,
      weight: _weightController.text.trim(),
    );

    _didSubmit = true;
    ref.read(patientLoginViewModelProvider.notifier).addPatient(patient);
  }

  int? _genderIdFor(String gender) {
    final idx = _genders.indexOf(gender);
    if (idx < 0) return null;
    return idx + 1;
  }

  int? _bloodGroupIdFor(String bloodGroup) {
    final idx = _bloodGroups.indexOf(bloodGroup);
    if (idx < 0) return null;
    return idx + 1;
  }

  void _showSnack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg)),
          ],
        ),
        backgroundColor: success ? kGreen : kRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Weight is required';
    final w = double.tryParse(v.trim());
    if (w == null || w <= 0 || w > 500) return 'Enter valid weight in kg';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,

      // ── AppBar — NO save button ──────────────────────────────
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: kTextDark),
          ),
        ),
        title: const Text(
          'Edit Profile',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: kTextDark),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: kBorder),
        ),
      ),

      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Avatar ───────────────────────────────────────
              _avatarCard(),
              const SizedBox(height: 14),

              // ── Personal info ─────────────────────────────────
              _sectionCard(
                accentColor: kPrimary,
                title: 'Personal Information',
                children: [
                  _fieldLabel('Full Name'),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _nameController,
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded,
                    iconColor: kPrimary,
                    isFocused: true,
                    validator: (v) => _required(v, 'Full name'),
                    capitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Mobile Number'),
                  const SizedBox(height: 6),
                  _mobileField(),
                  const SizedBox(height: 14),
                  _fieldLabel('Email Address'),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _emailController,
                    hint: 'patient@example.com',
                    icon: Icons.email_outlined,
                    iconColor: kPurple,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) {
                        return 'Email is required';
                      }
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+')
                          .hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  _fieldLabel('Address'),
                  const SizedBox(height: 6),
                  _inputField(
                    controller: _addressController,
                    hint: 'Enter your full address',
                    icon: Icons.location_on_outlined,
                    iconColor: kOrange,
                    maxLines: 3,
                    validator: (v) => _required(v, 'Address'),
                    capitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // ── Medical info ──────────────────────────────────
              _sectionCard(
                accentColor: kRed,
                title: 'Medical Information',
                children: [
                  _fieldLabel('Gender'),
                  const SizedBox(height: 8),
                  _genderSelector(),
                  const SizedBox(height: 14),
                  _fieldLabel('Date of Birth'),
                  const SizedBox(height: 6),
                  _dobField(),
                  const SizedBox(height: 14),
                  _fieldLabel('Blood Group'),
                  const SizedBox(height: 8),
                  _bloodGroupPicker(),
                  const SizedBox(height: 14),
                  _fieldLabel('Weight'),
                  const SizedBox(height: 6),
                  _weightField(),
                ],
              ),
              const SizedBox(height: 28),

              // ── Buttons — ONLY at bottom ──────────────────────
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        backgroundColor: kCardBg,
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextMid,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding:
                            const EdgeInsets.symmetric(vertical: 15),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text(
                        'Save Changes',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Avatar card ────────────────────────────────────────────────
  Widget _avatarCard() {
    final displayName = _nameController.text.trim().isNotEmpty
        ? _nameController.text.trim()
        : 'Patient';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimaryBg,
                  border: Border.all(color: kPrimary, width: 2.5),
                ),
                child: const Icon(Icons.person, size: 44, color: kPrimary),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: GestureDetector(
                  onTap: () {},
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: kOrange,
                      shape: BoxShape.circle,
                      border: Border.all(color: kCardBg, width: 2.5),
                    ),
                    child: const Icon(Icons.edit,
                        size: 13, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            displayName,
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: kTextDark),
          ),
          const SizedBox(height: 3),
          const Text(
            'Tap icon to change photo',
            style: TextStyle(fontSize: 12, color: kTextMid),
          ),
        ],
      ),
    );
  }

  // ── Section card ───────────────────────────────────────────────
  Widget _sectionCard({
    required Color accentColor,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
          ]),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // ── Field label ────────────────────────────────────────────────
  Widget _fieldLabel(String label) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: kTextMid,
        letterSpacing: 0.5,
      ),
    );
  }

  // ── Generic input field ────────────────────────────────────────
  Widget _inputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    bool isFocused = false,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      textCapitalization: capitalization,
      style: const TextStyle(fontSize: 14, color: kTextDark),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kMuted, fontSize: 14),
        prefixIcon: Icon(icon, color: iconColor, size: 20),
        filled: true,
        fillColor: isFocused ? const Color(0xFFF8FAFF) : kBg,
        contentPadding: maxLines > 1
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
            : const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isFocused ? kPrimary : kBorder,
            width: isFocused ? 1.5 : 1,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed, width: 1.8),
        ),
        errorStyle: const TextStyle(fontSize: 11.5, color: kRed),
      ),
      validator: validator,
    );
  }

  // ── Mobile field ───────────────────────────────────────────────
  Widget _mobileField() {
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      maxLength: 10,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: const TextStyle(fontSize: 14, color: kTextDark),
      decoration: InputDecoration(
        hintText: '3001234567',
        hintStyle: const TextStyle(color: kMuted, fontSize: 14),
        counterText: '',
        prefixIcon: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.phone_outlined, color: kCyan, size: 18),
              const SizedBox(width: 6),
              const Text('🇵🇰 +92',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextDark)),
              const SizedBox(width: 4),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  color: kMuted, size: 16),
              const SizedBox(width: 6),
              Container(width: 1, height: 20, color: kBorder),
              const SizedBox(width: 2),
            ],
          ),
        ),
        filled: true,
        fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed),
        ),
        errorStyle: const TextStyle(fontSize: 11.5, color: kRed),
      ),
      validator: (v) {
        if (v == null || v.trim().isEmpty) return 'Mobile is required';
        if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
          return 'Enter valid 10-digit number';
        }
        return null;
      },
    );
  }

  // ── Gender selector ────────────────────────────────────────────
  Widget _genderSelector() {
    return Row(
      children: _genders.map((g) {
        final isSelected = _selectedGender == g;
        final index = _genders.indexOf(g);
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: index < _genders.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedGender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryBg : kBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kPrimary : kBorder,
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _genderIcons[g] ?? Icons.person_outline_rounded,
                      size: 18,
                      color: isSelected ? kPrimary : kMuted,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      g,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: isSelected ? kPrimary : kTextMid,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── DOB field ──────────────────────────────────────────────────
  Widget _dobField() {
    return GestureDetector(
      onTap: _pickDob,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 15),
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Icon(Icons.cake_outlined, color: kOrange, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _formattedDob,
                style: TextStyle(
                  fontSize: 14,
                  color:
                      _selectedDob != null ? kTextDark : kMuted,
                ),
              ),
            ),
            const Icon(Icons.calendar_today_outlined,
                color: kMuted, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Blood group picker ─────────────────────────────────────────
  Widget _bloodGroupPicker() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _bloodGroups.map((g) {
        final isSelected = _selectedBloodGroup == g;
        return GestureDetector(
          onTap: () => setState(() => _selectedBloodGroup = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 42,
            decoration: BoxDecoration(
              color: isSelected ? kRed : kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? kRed : kBorder,
              ),
            ),
            child: Center(
              child: Text(
                g,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isSelected ? Colors.white : kTextMid,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ── Weight field ───────────────────────────────────────────────
  Widget _weightField() {
    return TextFormField(
      controller: _weightController,
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
      ],
      style: const TextStyle(fontSize: 14, color: kTextDark),
      decoration: InputDecoration(
        hintText: 'e.g. 65.5',
        hintStyle: const TextStyle(color: kMuted, fontSize: 14),
        prefixIcon: const Icon(Icons.monitor_weight_outlined,
            color: kGreen, size: 20),
        suffixIcon: Padding(
          padding: const EdgeInsets.only(right: 12),
          child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            padding: const EdgeInsets.symmetric(horizontal: 10),
            decoration: BoxDecoration(
              color: kBorder,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'kg',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextMid),
            ),
          ),
        ),
        filled: true,
        fillColor: kBg,
        contentPadding: const EdgeInsets.symmetric(vertical: 15),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kPrimary, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: kRed),
        ),
        errorStyle: const TextStyle(fontSize: 11.5, color: kRed),
      ),
      validator: _validateWeight,
    );
  }
}
