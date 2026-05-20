import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';

// ── Colour palette (matches login + continue_as screens) ──────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF1EA898);
const kPrimaryDarker = Color(0xFF158578);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryGlow   = Color(0xFF4DD9C4);

const kBgSoft  = Color(0xFFF7FAFC);
const kSurface = Color(0xFFFFFFFF);
const kBg      = Color(0xFFF7FAFC); // page background

const kTextPrimary   = Color(0xFF1A202C);
const kTextSecondary = Color(0xFF4A5568);
const kTextMuted     = Color(0xFF94A3B8);

const kBorder       = Color(0xFFF1F5F9);
const kBorderStrong = Color(0xFFE2E8F0);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kPurple     = Color(0xFF9F7AEA);
const kPurpleLight= Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);

class PatientRegistrationScreen extends ConsumerStatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  ConsumerState<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState
    extends ConsumerState<PatientRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullNameController = TextEditingController();
  final _mobileController   = TextEditingController();
  final _emailController    = TextEditingController();
  final _addressController  = TextEditingController();
  final _dobController      = TextEditingController();
  final _weightController   = TextEditingController();

  String?   _selectedGender;
  int?      _selectedGenderId;
  String?   _selectedBloodGroup;
  int?      _selectedBloodGroupId;
  DateTime? _selectedDob;

  File?             _patientImage;
  final ImagePicker _picker = ImagePicker();

  Timer?  _mobileDebounce;
  String? _mobileExistsError;

  final List<_Option> _genderOptions = const [
    _Option(id: 1, label: 'Male'),
    _Option(id: 2, label: 'Female'),
    _Option(id: 3, label: 'Other'),
  ];

  final List<_Option> _bloodGroupOptions = const [
    _Option(id: 1, label: 'A+'),
    _Option(id: 2, label: 'A-'),
    _Option(id: 3, label: 'B+'),
    _Option(id: 4, label: 'B-'),
    _Option(id: 5, label: 'AB+'),
    _Option(id: 6, label: 'AB-'),
    _Option(id: 7, label: 'O+'),
    _Option(id: 8, label: 'O-'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
    });
  }

  @override
  void dispose() {
    _mobileDebounce?.cancel();
    _fullNameController.dispose();
    _mobileController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  // ── Mobile existence check ──────────────────────────────────────────────
  void _onMobileChanged(String value) {
    _mobileDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 10) {
      if (_mobileExistsError != null) setState(() => _mobileExistsError = null);
      return;
    }
    _mobileDebounce = Timer(const Duration(milliseconds: 800), () async {
      final result = await ref
          .read(patientLoginViewModelProvider.notifier)
          .mobileExistPatient(trimmed);
      if (!mounted) return;
      setState(() {
        _mobileExistsError =
            result.isNotEmpty ? 'Mobile number already registered.' : null;
      });
    });
  }

  // ── Image picker ────────────────────────────────────────────────────────
  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? picked = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );
      if (picked != null) {
        setState(() => _patientImage = File(picked.path));
      }
    } catch (e) {
      _snack('Could not pick image: $e', isError: true);
    }
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: kSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorderStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Upload Profile Photo',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how you want to upload your photo',
                style: TextStyle(fontSize: 12.5, color: kTextSecondary),
              ),
              const SizedBox(height: 22),
              Row(
                children: [
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      color: kPrimary,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.camera);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ImageSourceTile(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      color: kPurple,
                      onTap: () {
                        Navigator.pop(context);
                        _pickImage(ImageSource.gallery);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (_patientImage != null)
                SizedBox(
                  width: double.infinity,
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      setState(() => _patientImage = null);
                    },
                    icon: const Icon(Icons.delete_outline_rounded,
                        color: kError, size: 18),
                    label: const Text(
                      'Remove Photo',
                      style: TextStyle(
                          color: kError, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
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
            primary: kPrimary,
            onPrimary: Colors.white,
            onSurface: kTextPrimary,
          ),
          dialogBackgroundColor: kSurface,
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

  // ── Submit ──────────────────────────────────────────────────────────────
  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    if (_mobileExistsError != null) {
      _snack(_mobileExistsError!, isError: true);
      return;
    }
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
      name:         _fullNameController.text.trim(),
      mobileNo:     _mobileController.text.trim(),
      email:        _emailController.text.trim(),
      address:      _addressController.text.trim(),
      gender:       _selectedGender,
      DOB:          _selectedDob,
      bloodGroup:   _selectedBloodGroup,
      genderId:     _selectedGenderId,
      bloodGroupId: _selectedBloodGroupId,
      weight:       _weightController.text.trim(),
    );

    debugPrint('Image before submit: $_patientImage');
    ref
        .read(patientLoginViewModelProvider.notifier)
        .addPatient(patient, image: _patientImage);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ]),
        backgroundColor: isError ? kTextPrimary : kPrimaryDark,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  void _onStateChange(PatientLoginState? prev, PatientLoginState next) {
    if (next.isSuccess && !(prev?.isSuccess ?? false)) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen(role: 'patient')),
      );
    }
    if (next.error != null && next.error != prev?.error) {
      _snack(next.error!, isError: true);
    }
  }

  // ── Build ───────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    ref.listen<PatientLoginState>(patientLoginViewModelProvider, _onStateChange);
    final state = ref.watch(patientLoginViewModelProvider);

    return Scaffold(
      backgroundColor: kBg,
      appBar: _SimpleTitleBar(
        title: 'Patient Registration',
        subtitle: 'Fill in your details to continue',
        onBack: () => Navigator.pop(context),
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                        // Avatar picker
                        Center(child: _buildAvatarPicker()),
                        const SizedBox(height: 22),

                        // ─── Personal Information card ────────────
                        _SectionCard(
                          icon: Icons.person_outline_rounded,
                          iconBg: kPrimaryLight,
                          iconColor: kPrimaryDark,
                          title: 'Personal Information',
                          subtitle: 'Your basic contact details',
                          children: [
                            const _FieldLabel(label: 'Full Name', required: true),
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

                            const _FieldLabel(
                                label: 'Mobile Number', required: true),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _mobileController,
                              keyboardType: TextInputType.phone,
                              maxLength: 10,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              style: _inputStyle,
                              onChanged: _onMobileChanged,
                              decoration: _decor(
                                hint: '9876543210',
                                icon: Icons.phone_outlined,
                                prefixWidget: const _PhonePrefix(),
                                counterText: '',
                              ),
                              validator: _validateMobile,
                            ),
                            if (_mobileExistsError != null) ...[
                              const SizedBox(height: 6),
                              _FieldHint(
                                text: _mobileExistsError!,
                                icon: Icons.error_outline_rounded,
                                color: kError,
                              ),
                            ],
                            const SizedBox(height: 16),

                            const _FieldLabel(
                                label: 'Email Address', required: true),
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

                            const _FieldLabel(
                                label: 'Address', required: true),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              textCapitalization:
                                  TextCapitalization.sentences,
                              style: _inputStyle,
                              decoration: _decor(
                                  hint: 'Enter your full address',
                                  icon: Icons.location_on_outlined,
                                  multiline: true),
                              validator: (v) => _required(v, 'Address'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // ─── Medical Information card ─────────────
                        _SectionCard(
                          icon: Icons.medical_information_outlined,
                          iconBg: kInfoLight,
                          iconColor: kInfo,
                          title: 'Medical Information',
                          subtitle: 'Helps us provide better care',
                          children: [
                            const _FieldLabel(label: 'Gender', required: true),
                            const SizedBox(height: 10),
                            _GenderSelector(
                              options: _genderOptions,
                              selectedId: _selectedGenderId,
                              onChanged: (opt) => setState(() {
                                _selectedGender = opt.label;
                                _selectedGenderId = opt.id;
                              }),
                            ),
                            const SizedBox(height: 18),

                            const _FieldLabel(
                                label: 'Date of Birth', required: true),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _dobController,
                              readOnly: true,
                              onTap: _selectDob,
                              style: _inputStyle,
                              decoration: _decor(
                                hint: 'Select date of birth',
                                icon: Icons.cake_outlined,
                                suffix: const Padding(
                                  padding: EdgeInsets.only(right: 14),
                                  child: Icon(
                                      Icons.calendar_today_outlined,
                                      color: kTextMuted,
                                      size: 18),
                                ),
                              ),
                              validator: (v) => (v == null || v.isEmpty)
                                  ? 'Date of birth is required'
                                  : null,
                            ),
                            const SizedBox(height: 18),

                            const _FieldLabel(
                                label: 'Blood Group', required: true),
                            const SizedBox(height: 10),
                            _BloodGroupPicker(
                              groups: _bloodGroupOptions,
                              selectedId: _selectedBloodGroupId,
                              onChanged: (opt) => setState(() {
                                _selectedBloodGroup = opt.label;
                                _selectedBloodGroupId = opt.id;
                              }),
                            ),
                            const SizedBox(height: 18),

                            const _FieldLabel(
                                label: 'Weight (kg)', required: true),
                            const SizedBox(height: 8),
                            TextFormField(
                              controller: _weightController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
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
                                          fontWeight: FontWeight.w700,
                                          color: kTextSecondary)),
                                ),
                              ),
                              validator: _validateWeight,
                            ),
                          ],
                        ),

                        const SizedBox(height: 26),

                        // ─── Submit Button ────────────────────────
                        _SubmitButton(
                          isLoading: state.isLoading,
                          onPressed: _submit,
                        ),

                        const SizedBox(height: 20),

                        // ─── Login link card ──────────────────────
                        _BackToLoginLink(
                          onTap: () => Navigator.pop(context),
                        ),

                        const SizedBox(height: 16),

                        // ─── Secure footer ────────────────────────
                        const _SecureFooter(),
                      ],
                    ),
          ),
        ),
      ),
    );
  }

  // ── Avatar picker widget ────────────────────────────────────────────────
  Widget _buildAvatarPicker() {
    return GestureDetector(
      onTap: _showImageSourceSheet,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _patientImage == null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kPrimaryLight, Colors.white],
                        )
                      : null,
                  color: _patientImage != null ? Colors.white : null,
                  border: Border.all(
                    color: _patientImage != null
                        ? kPrimary
                        : kBorderStrong,
                    width: _patientImage != null ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: _patientImage != null
                    ? ClipOval(
                        child: Image.file(
                          _patientImage!,
                          fit: BoxFit.cover,
                          width: 104,
                          height: 104,
                        ),
                      )
                    : const Icon(
                        Icons.person_outline_rounded,
                        size: 46,
                        color: kPrimaryDark,
                      ),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryDark],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            _patientImage != null ? 'Change Photo' : 'Add Photo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _patientImage != null ? kPrimaryDark : kTextPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Optional',
            style: TextStyle(
              fontSize: 11,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Input decoration factory ────────────────────────────────────────────
  static const _inputStyle = TextStyle(
    fontSize: 14,
    color: kTextPrimary,
    fontWeight: FontWeight.w500,
  );

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
      hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
      prefixIcon: prefixWidget ?? Icon(icon, color: kTextMuted, size: 20),
      suffixIcon: suffix,
      filled: true,
      fillColor: kBgSoft,
      counterText: counterText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderStrong),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kBorderStrong),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kPrimary, width: 1.6),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kError),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: kError, width: 1.6),
      ),
      contentPadding: multiline
          ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
          : const EdgeInsets.symmetric(vertical: 16),
      errorStyle: const TextStyle(
          fontSize: 11.5, color: kError, fontWeight: FontWeight.w500),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIMPLE TITLE BAR (replaces gradient hero)
// ─────────────────────────────────────────────────────────────────────────────
class _SimpleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _SimpleTitleBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 68,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(
              bottom: BorderSide(color: kBorder, width: 1),
            ),
          ),
          child: Row(
            children: [
              // Back button
              Material(
                color: kBgSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: const BorderSide(color: kBorderStrong, width: 0.5),
                ),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(11),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: kTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Title + subtitle
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              // Role badge
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.favorite_border_rounded,
                        size: 11, color: kPrimaryDarker),
                    SizedBox(width: 5),
                    Text(
                      'Patient',
                      style: TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                        letterSpacing: 0.2,
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
}


// ─────────────────────────────────────────────────────────────────────────────
// SECTION CARD
// ─────────────────────────────────────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: kTextPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                          fontSize: 11.5,
                          color: kTextSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            const Divider(color: kBorder, height: 22, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBMIT BUTTON
// ─────────────────────────────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onPressed;
  const _SubmitButton({required this.isLoading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimary, kPrimaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: isLoading
              ? []
              : [
                  BoxShadow(
                    color: kPrimary.withOpacity(0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: isLoading ? null : onPressed,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2.5),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded,
                            color: Colors.white, size: 19),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BACK TO LOGIN LINK CARD
// ─────────────────────────────────────────────────────────────────────────────
class _BackToLoginLink extends StatelessWidget {
  final VoidCallback onTap;
  const _BackToLoginLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: kPrimaryLight.withOpacity(0.4),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: kPrimary.withOpacity(0.25), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.login_rounded,
                  color: kPrimaryDark,
                  size: 18,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Already have an account?',
                      style: TextStyle(
                        fontSize: 12,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Sign in instead',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: kPrimaryDarker,
                        letterSpacing: -0.1,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios_rounded,
                color: kPrimaryDark,
                size: 13,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER + DECOR
// ─────────────────────────────────────────────────────────────────────────────
class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: kTextMuted),
          SizedBox(width: 6),
          Text(
            'Your data is protected and encrypted',
            style: TextStyle(
              fontSize: 11.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SMALL REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────
class _ImageSourceTile extends StatelessWidget {
  const _ImageSourceTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            color: color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: color.withOpacity(0.22)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 26),
              ),
              const SizedBox(height: 10),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label, this.required = false});
  final String label;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: 0.1,
          ),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text(
            '*',
            style: TextStyle(
              fontSize: 13,
              color: kError,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ],
    );
  }
}

class _FieldHint extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  const _FieldHint({
    required this.text,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Row(
          children: [
            Icon(icon, size: 13, color: color),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11.5,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🇮🇳', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text(
            '+91',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 22,
            child: VerticalDivider(
                color: kBorderStrong, width: 1, thickness: 1),
          ),
          SizedBox(width: 2),
        ],
      ),
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
        final icon = _iconMap[opt.label.toLowerCase()] ??
            Icons.person_outline_rounded;
        final isSelected = selectedId == opt.id;
        return Expanded(
          child: Padding(
            padding:
                EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => onChanged(opt),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                height: 56,
                decoration: BoxDecoration(
                  color: isSelected ? kPrimaryLight : kBgSoft,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? kPrimary : kBorderStrong,
                    width: isSelected ? 1.8 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kPrimary.withOpacity(0.18),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? kPrimaryDarker : kTextSecondary,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      opt.label,
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: isSelected
                            ? FontWeight.w800
                            : FontWeight.w600,
                        color: isSelected ? kPrimaryDarker : kTextSecondary,
                      ),
                    ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        // 4-column grid that flexes
        final spacing = 8.0;
        final itemWidth =
            (constraints.maxWidth - (spacing * 3)) / 4;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: groups.map((g) {
            final isSelected = selectedId == g.id;
            return GestureDetector(
              onTap: () => onChanged(g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: itemWidth,
                height: 46,
                decoration: BoxDecoration(
                  gradient: isSelected
                      ? const LinearGradient(
                          colors: [kPrimary, kPrimaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: isSelected ? null : kBgSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? kPrimary : kBorderStrong,
                    width: isSelected ? 0 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: kPrimary.withOpacity(0.32),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : [],
                ),
                child: Center(
                  child: Text(
                    g.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: isSelected ? Colors.white : kTextPrimary,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 56,
      child: Center(
        child: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: kRedLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kError.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, size: 18, color: kError),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kError,
              ),
            ),
          ),
        ],
      ),
    );
  }
}