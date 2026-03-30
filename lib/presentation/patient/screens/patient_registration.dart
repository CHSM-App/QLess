// lib/presentation/patient/screens/patient_registration.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/shared/screens/otp_screen.dart';


class PatientRegistrationScreen extends ConsumerStatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  ConsumerState<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends ConsumerState<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController    = TextEditingController();
  final _mobileController      = TextEditingController();
  final _emailController       = TextEditingController();
  final _addressController     = TextEditingController();
  final _dobController         = TextEditingController();
  final _weightController      = TextEditingController();

  String?   _selectedGender;
  int?      _selectedGenderId;
  String?   _selectedBloodGroup;
  int?      _selectedBloodGroupId;
  DateTime? _selectedDob;

  // ── Theme constants ─────────────────────────────────────────────────────
  static const _primary = Color(0xFF0EA5E9);
  static const _dark    = Color(0xFF0F172A);
  static const _slate   = Color(0xFF64748B);
  static const _muted   = Color(0xFF94A3B8);
  static const _bg      = Color(0xFFF1F5F9);
  static const _border  = Color(0xFFE2E8F0);
  static const _red     = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    // Fetch master data after first frame to avoid provider modification during build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(masterViewModelProvider.notifier).fetchGenderList();
      ref.read(masterViewModelProvider.notifier).fetchBloodGroupList();
    });
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ── Validation ──────────────────────────────────────────────────────────
  String? _required(String? v, String field) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  String? _validateMobile(String? v) {
    if (v == null || v.trim().isEmpty) return 'Mobile number is required';
    if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
      return 'Enter a valid 10-digit number';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email is required';
    if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
      return 'Enter a valid email address';
    }
    return null;
  }

  String? _validateWeight(String? v) {
    if (v == null || v.trim().isEmpty) return 'Weight is required';
    final w = double.tryParse(v.trim());
    if (w == null || w <= 0 || w > 500) return 'Enter a valid weight in kg';
    return null;
  }

  // ── Date picker ─────────────────────────────────────────────────────────
  Future<void> _selectDob() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(now.year - 25),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
            primary: _primary,
            onPrimary: Colors.white,
          ),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDob = picked;
        _dobController.text =
            '${picked.day.toString().padLeft(2, '0')}/'
            '${picked.month.toString().padLeft(2, '0')}/'
            '${picked.year}';
      });
    }
  }

  // ── Submit ───────────────────────────────────────────────────────────────
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_selectedGenderId == null) {
      _snack('Please select your gender', isError: true);
      return;
    }
    if (_selectedDob == null) {
      _snack('Please select your date of birth', isError: true);
      return;
    }
    if (_selectedBloodGroupId == null) {
      _snack('Please select your blood group', isError: true);
      return;
    }

    final patient = Patients(
      name:        _fullNameController.text.trim(),
      mobileNo:    _mobileController.text.trim(),
      email:       _emailController.text.trim(),
      address:     _addressController.text.trim(),
      gender:      _selectedGender,
      DOB:         _selectedDob,
      bloodGroup:  _selectedBloodGroup,
      genderId:    _selectedGenderId,
      bloodGroupId: _selectedBloodGroupId,
      weight:      _weightController.text.trim(),
    );

    ref.read(patientLoginViewModelProvider.notifier).addPatient(patient);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(msg)),
        ]),
        backgroundColor: isError ? _red : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  // ── State listener ───────────────────────────────────────────────────────
  void _onStateChange(PatientLoginState? prev, PatientLoginState next) {
    // Navigate to OTP on success
    if (next.isSuccess && !(prev?.isSuccess ?? false)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OtpVerificationScreen(
            mobileNumber: _mobileController.text.trim(),
            role: 'patient',
          ),
        ),
      );
    }

    // Show API error
    if (next.error != null && next.error != prev?.error) {
      _snack(next.error!, isError: true);
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.listen<PatientLoginState>(patientLoginViewModelProvider, _onStateChange);
    final state = ref.watch(patientLoginViewModelProvider);
    final masterState = ref.watch(masterViewModelProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: _dark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Registration',
          style: TextStyle(
              fontSize: 17, fontWeight: FontWeight.w700, color: _dark),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header banner ─────────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.person_outline_rounded,
                          color: Colors.white, size: 24),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Create Patient Account',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: Colors.white)),
                        SizedBox(height: 2),
                        Text('Fill in your details to register',
                            style: TextStyle(
                                fontSize: 12.5, color: Colors.white70)),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ════════════════════════════════════════════════════
              // SECTION: Personal Information
              // ════════════════════════════════════════════════════
              const _SectionHeader(label: 'Personal Information'),
              const SizedBox(height: 14),

              _FieldLabel(label: 'Full Name'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _fullNameController,
                textCapitalization: TextCapitalization.words,
                style: _inputStyle,
                decoration: _decor(
                    hint: 'Enter your full name',
                    icon: Icons.person_outline_rounded),
                validator: (v) => _required(v, 'Full name'),
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Mobile Number'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _mobileController,
                keyboardType: TextInputType.phone,
                maxLength: 10,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                style: _inputStyle,
                decoration: _decor(
                  hint: '9876543210',
                  icon: Icons.phone_outlined,
                  prefixWidget: _PhonePrefix(),
                  counterText: '',
                ),
                validator: _validateMobile,
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Email Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                style: _inputStyle,
                decoration: _decor(
                    hint: 'patient@example.com',
                    icon: Icons.email_outlined),
                validator: _validateEmail,
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Address'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _addressController,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                style: _inputStyle,
                decoration: _decor(
                    hint: 'Enter your full address',
                    icon: Icons.location_on_outlined,
                    multiline: true),
                validator: (v) => _required(v, 'Address'),
              ),

              const SizedBox(height: 24),

              // ════════════════════════════════════════════════════
              // SECTION: Medical Information
              // ════════════════════════════════════════════════════
              const _SectionHeader(label: 'Medical Information'),
              const SizedBox(height: 14),

              _FieldLabel(label: 'Gender'),
              const SizedBox(height: 8),
              masterState.fetchGender.when(
                data: (list) {
                  final options = list
                      .where((e) =>
                          (e.gender?.trim().isNotEmpty ?? false) &&
                          (e.genderId != null))
                      .map((e) => _Option(
                            id: e.genderId!,
                            label: e.gender!.trim(),
                          ))
                      .toList();
                  if (options.isEmpty) {
                    return const _InlineError(
                        text: 'No gender data found');
                  }
                  return _GenderSelector(
                    options: options,
                    selectedId: _selectedGenderId,
                    onChanged: (opt) => setState(() {
                      _selectedGender = opt.label;
                      _selectedGenderId = opt.id;
                    }),
                  );
                },
                loading: () => const _InlineLoading(),
                error: (e, _) => _InlineError(
                    text: 'Unable to load gender list. Please retry.'),
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Date of Birth'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _dobController,
                readOnly: true,
                onTap: _selectDob,
                style: _inputStyle,
                decoration: _decor(
                  hint: 'Select date of birth',
                  icon: Icons.cake_outlined,
                  suffix: const Icon(Icons.calendar_today_outlined,
                      color: _muted, size: 18),
                ),
                validator: (v) =>
                    (v == null || v.isEmpty) ? 'Date of birth is required' : null,
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Blood Group'),
              const SizedBox(height: 8),
              masterState.fetchBloodGroup.when(
                data: (list) {
                  final groups = list
                      .where((e) =>
                          (e.bloodGroupName?.trim().isNotEmpty ?? false) &&
                          (e.bloodGroupId != null))
                      .map((e) => _Option(
                            id: e.bloodGroupId!,
                            label: e.bloodGroupName!.trim(),
                          ))
                      .toList();
                  if (groups.isEmpty) {
                    return const _InlineError(
                        text: 'No blood group data found');
                  }
                  return _BloodGroupPicker(
                    groups: groups,
                    selectedId: _selectedBloodGroupId,
                    onChanged: (opt) => setState(() {
                      _selectedBloodGroup = opt.label;
                      _selectedBloodGroupId = opt.id;
                    }),
                  );
                },
                loading: () => const _InlineLoading(),
                error: (e, _) => _InlineError(
                    text: 'Unable to load blood groups. Please retry.'),
              ),

              const SizedBox(height: 16),

              _FieldLabel(label: 'Weight (kg)'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}')),
                ],
                style: _inputStyle,
                decoration: _decor(
                  hint: 'e.g. 65.5',
                  icon: Icons.monitor_weight_outlined,
                  suffix: const Padding(
                    padding: EdgeInsets.only(right: 14),
                    child: Text('kg',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: _muted)),
                  ),
                ),
                validator: _validateWeight,
              ),

              const SizedBox(height: 32),

              // ── Submit button ──────────────────────────────────
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: _primary.withOpacity(0.30),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: state.isLoading ? null : _submit,
                    child: Center(
                      child: state.isLoading
                          ? const SizedBox(
                              width: 22,
                              height: 22,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2.5),
                            )
                          : const Text(
                              'Create Account',
                              style: TextStyle(
                                fontSize: 15.5,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 0.2,
                              ),
                            ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // ── Already have account ───────────────────────────
              Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Already have an account? ',
                        style: TextStyle(fontSize: 13, color: _slate)),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Text('Login',
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: _primary)),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Input decoration factory ─────────────────────────────────────────────
  static const _inputStyle = TextStyle(fontSize: 14, color: _dark);

  static InputDecoration _decor({
    required String hint,
    required IconData icon,
    Widget? prefixWidget,
    Widget? suffix,
    String? counterText,
    bool multiline = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      prefixIcon: prefixWidget ?? Icon(icon, color: _muted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: _bg,
      counterText: counterText,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 1.8)),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red)),
      focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _red, width: 1.8)),
      contentPadding: multiline
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.symmetric(vertical: 16),
      errorStyle: const TextStyle(fontSize: 11.5, color: _red),
    );
  }
}

// ─────────────────────────────────────────────
// Small reusable widgets
// ─────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 4,
        height: 18,
        decoration: BoxDecoration(
          color: const Color(0xFF0EA5E9),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(label,
          style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Color(0xFF0F172A),
              letterSpacing: -0.1)),
    ]);
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(label,
        style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A)));
  }
}

class _PhonePrefix extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(mainAxisSize: MainAxisSize.min, children: const [
        Text('🇮🇳  +91',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF0F172A))),
        SizedBox(width: 6),
        Icon(Icons.keyboard_arrow_down_rounded,
            color: Color(0xFF94A3B8), size: 16),
        SizedBox(width: 6),
        SizedBox(
            height: 22,
            child: VerticalDivider(
                color: Color(0xFFCBD5E1), width: 1, thickness: 1)),
        SizedBox(width: 2),
      ]),
    );
  }
}

class _Option {
  final int id;
  final String label;
  const _Option({required this.id, required this.label});
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.options,
    required this.selectedId,
    required this.onChanged,
  });

  final List<_Option> options;
  final int? selectedId;
  final ValueChanged<_Option> onChanged;
  static const _iconMap = {
    'male': Icons.male_rounded,
    'female': Icons.female_rounded,
    'other': Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final opt = options[i];
        final icon =
            _iconMap[opt.label.toLowerCase()] ?? Icons.person_outline_rounded;
        final isSelected = selectedId == opt.id;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                height: 48,
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF0EA5E9).withOpacity(0.1)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF0EA5E9)
                        : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.8 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 18,
                        color: isSelected
                            ? const Color(0xFF0EA5E9)
                            : const Color(0xFF94A3B8)),
                    const SizedBox(width: 5),
                    Text(opt.label,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: isSelected
                                ? const Color(0xFF0EA5E9)
                                : const Color(0xFF64748B))),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}

class _BloodGroupPicker extends StatelessWidget {
  const _BloodGroupPicker({
    required this.groups,
    required this.selectedId,
    required this.onChanged,
  });

  final List<_Option> groups;
  final int? selectedId;
  final ValueChanged<_Option> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: groups.map((g) {
        final isSelected = selectedId == g.id;
        return GestureDetector(
          onTap: () => onChanged(g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 60,
            height: 40,
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF0EA5E9)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0EA5E9)
                    : const Color(0xFFE2E8F0),
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: const Color(0xFF0EA5E9).withOpacity(0.25),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      )
                    ]
                  : [],
            ),
            child: Center(
              child: Text(g.label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF64748B))),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 48,
      child: Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: Color(0xFFEF4444)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}
