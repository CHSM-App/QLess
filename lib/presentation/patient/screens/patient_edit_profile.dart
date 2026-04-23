import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);

const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);

const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);

const kPurple      = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);

const kInfo      = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

// =============================================================================
// Page
// =============================================================================

class PatientEditProfilePage extends ConsumerStatefulWidget {
  const PatientEditProfilePage({super.key});
  @override
  ConsumerState<PatientEditProfilePage> createState() =>
      _PatientEditProfilePageState();
}

class _PatientEditProfilePageState
    extends ConsumerState<PatientEditProfilePage> {
  final _formKey          = GlobalKey<FormState>();
  final _nameController   = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController  = TextEditingController();
  final _addressController= TextEditingController();
  final _weightController = TextEditingController();
  File? _pickedImage;
final ImagePicker _picker = ImagePicker();

String? _networkImageUrl;   // ← add this


  String    _selectedGender     = 'Female';
  String    _selectedBloodGroup = 'B+';
  DateTime? _selectedDob        = DateTime(1992, 3, 12);

  late final ProviderSubscription<PatientLoginState> _sub;
  bool _didFetchProfile = false;
  bool _didPrefill      = false;
  bool _didSubmit       = false;

  final _bloodGroups = ['A+', 'A−', 'B+', 'B−', 'AB+', 'AB−', 'O+', 'O−'];
  final _genders     = ['Male', 'Female', 'Other'];
  final _genderIcons = <String, IconData>{
    'Male'  : Icons.male_rounded,
    'Female': Icons.female_rounded,
    'Other' : Icons.transgender_rounded,
  };

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<PatientLoginState>(
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
    _sub.close();
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

    _set(_nameController,    details.name    ?? state.name);
    _set(_mobileController,  details.mobileNo ?? state.mobileNo);
    _set(_emailController,   details.email   ?? state.email);
    _set(_addressController, details.address);
    _set(_weightController,  details.weight);
    _networkImageUrl = details.imgUrl ?? details.imgUrl ?? details.imgUrl;

    _applyGender(details);
    _applyBloodGroup(details);
    _selectedDob = details.DOB ?? _selectedDob;
    if (mounted) setState(() {});
  }

  void _handleSubmit(PatientLoginState? prev, PatientLoginState next) {
    if (!_didSubmit) return;
    if (next.isSuccess && !(prev?.isSuccess ?? false)) {
      _didSubmit = false;
      _snack('Profile updated successfully', success: true);
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
      _snack(next.error ?? 'Failed to update profile', success: false);
    }
  }

  void _set(TextEditingController c, String? v) {
    final s = v?.trim();
    if (s != null && s.isNotEmpty) c.text = s;
  }

  void _applyGender(Patients d) {
    final g = d.gender?.trim();
    if (g != null && g.isNotEmpty && _genders.contains(g)) {
      _selectedGender = g;
      return;
    }
    final id = d.genderId;
    if (id == 2) _selectedGender = 'Female';
    else if (id == 3) _selectedGender = 'Other';
    else if (id == 1) _selectedGender = 'Male';
  }

  void _applyBloodGroup(Patients d) {
    final bg = d.bloodGroup?.trim();
    if (bg != null && bg.isNotEmpty && _bloodGroups.contains(bg)) {
      _selectedBloodGroup = bg;
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDob() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDob ?? DateTime(1992, 3, 12),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: kPrimary, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _selectedDob = picked);
  }

  String get _formattedDob {
    if (_selectedDob == null) return 'Select date of birth';
    return '${_selectedDob!.day.toString().padLeft(2, '0')}/'
        '${_selectedDob!.month.toString().padLeft(2, '0')}/'
        '${_selectedDob!.year}';
  }

  void _save() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final state     = ref.read(patientLoginViewModelProvider);
    final patientId = state.patientId ?? 0;

    final patient = Patients(
      patientId:   patientId > 0 ? patientId : null,
      name:        _nameController.text.trim(),
      mobileNo:    _mobileController.text.trim(),
      email:       _emailController.text.trim(),
      address:     _addressController.text.trim(),
      genderId:    _genderIdFor(_selectedGender),
      DOB:         _selectedDob,
      bloodGroupId:_bloodGroupIdFor(_selectedBloodGroup),
      weight:      _weightController.text.trim(),
    );

    _didSubmit = true;
ref.read(patientLoginViewModelProvider.notifier).addPatient(patient, image: _pickedImage);
  }

  int? _genderIdFor(String g) {
    final i = _genders.indexOf(g);
    return i < 0 ? null : i + 1;
  }

  int? _bloodGroupIdFor(String bg) {
    final i = _bloodGroups.indexOf(bg);
    return i < 0 ? null : i + 1;
  }

  void _snack(String msg, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(fontSize: 13, color: Colors.white))),
          ],
        ),
        backgroundColor: success ? kPrimary : kError,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
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

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              _avatarCard(),
              const SizedBox(height: 12),

              // Personal info
              _sectionCard(
                icon: Icons.person_outline_rounded,
                iconFg: kPrimary,
                iconBg: kPrimaryLight,
                title: 'Personal Information',
                children: [
                  _twoColRow(
                    left: _field(
                      label: 'Full Name',
                      controller: _nameController,
                      hint: 'Enter full name',
                      icon: Icons.person_outline_rounded,
                      iconColor: kPrimary,
                      validator: (v) => _required(v, 'Full name'),
                      capitalization: TextCapitalization.words,
                    ),
                    right: _mobileField(),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    label: 'Email Address',
                    controller: _emailController,
                    hint: 'patient@example.com',
                    icon: Icons.email_outlined,
                    iconColor: kPurple,
                    keyboardType: TextInputType.emailAddress,
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Email is required';
                      if (!RegExp(r'^[^@]+@[^@]+\.[^@]+').hasMatch(v.trim())) {
                        return 'Enter a valid email';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    label: 'Address',
                    controller: _addressController,
                    hint: 'Enter your full address',
                    icon: Icons.location_on_outlined,
                    iconColor: kWarning,
                    maxLines: 2,
                    validator: (v) => _required(v, 'Address'),
                    capitalization: TextCapitalization.sentences,
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Medical info
              _sectionCard(
                icon: Icons.medical_information_outlined,
                iconFg: kError,
                iconBg: kRedLight,
                title: 'Medical Information',
                children: [
                  // Gender
                  _fieldLabel('Gender'),
                  const SizedBox(height: 6),
                  _genderSelector(),
                  const SizedBox(height: 12),

                  // DOB + Weight row
                  _twoColRow(
                    left: _dobTile(),
                    right: _weightField(),
                  ),
                  const SizedBox(height: 12),

                  // Blood group
                  _fieldLabel('Blood Group'),
                  const SizedBox(height: 6),
                  _bloodGroupPicker(),
                ],
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        side: const BorderSide(color: kBorder),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        foregroundColor: kTextSecondary,
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      onPressed: _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Text('Save Changes',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w700)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
      leading: GestureDetector(
        onTap: () => Navigator.pop(context),
        child: Container(
          margin: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kPrimaryLight,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 15, color: kPrimary),
        ),
      ),
      title: const Text(
        'Edit Profile',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: -0.2),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kBorder),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Avatar Card
  // ---------------------------------------------------------------------------

  // Widget _avatarCard() {
  //   final name = _nameController.text.trim().isNotEmpty
  //       ? _nameController.text.trim()
  //       : 'Patient';
  //   final initials = name.trim().split(RegExp(r'\s+')).take(2)
  //       .map((w) => w[0].toUpperCase()).join();

  //   return Container(
  //     width: double.infinity,
  //     padding: const EdgeInsets.symmetric(vertical: 18),
  //     decoration: BoxDecoration(
  //       color: Colors.white,
  //       borderRadius: BorderRadius.circular(14),
  //       border: Border.all(color: kBorder),
  //       boxShadow: [
  //         BoxShadow(
  //             color: Colors.black.withOpacity(0.04),
  //             blurRadius: 12,
  //             offset: const Offset(0, 4)),
  //       ],
  //     ),
  //     child: Column(
  //       children: [
  //         Stack(
  //           children: [
  //             Container(
  //               width: 72,
  //               height: 72,
  //               decoration: BoxDecoration(
  //                 gradient: const LinearGradient(
  //                   colors: [kPrimary, kPrimaryDark],
  //                   begin: Alignment.topLeft,
  //                   end: Alignment.bottomRight,
  //                 ),
  //                 borderRadius: BorderRadius.circular(18),
  //               ),
  //               alignment: Alignment.center,
  //               child: Text(initials,
  //                   style: const TextStyle(
  //                       fontSize: 24,
  //                       fontWeight: FontWeight.w700,
  //                       color: Colors.white)),
  //             ),
  //             Positioned(
  //               bottom: 0,
  //               right: 0,
  //               child: GestureDetector(
  //                 onTap: () {},
  //                 child: Container(
  //                   width: 24,
  //                   height: 24,
  //                   decoration: BoxDecoration(
  //                     color: kWarning,
  //                     shape: BoxShape.circle,
  //                     border: Border.all(color: Colors.white, width: 2),
  //                   ),
  //                   child: const Icon(Icons.edit_rounded,
  //                       size: 12, color: Colors.white),
  //                 ),
  //               ),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 8),
  //         Text(name,
  //             style: const TextStyle(
  //                 fontSize: 14,
  //                 fontWeight: FontWeight.w700,
  //                 color: kTextPrimary)),
  //         const SizedBox(height: 2),
  //         const Text('Tap icon to change photo',
  //             style: TextStyle(fontSize: 11, color: kTextMuted)),
  //       ],
  //     ),
  //   );
  // }

  Widget _avatarCard() {
  final name = _nameController.text.trim().isNotEmpty
      ? _nameController.text.trim()
      : 'Patient';
  final initials = name.trim().split(RegExp(r'\s+')).take(2)
      .map((w) => w[0].toUpperCase()).join();

  return Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 18),
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
    child: Column(
      children: [
        Stack(
          children: [
           
          Container(
  width: 72,
  height: 72,
  decoration: BoxDecoration(
    gradient: (_pickedImage == null && _networkImageUrl == null)
        ? const LinearGradient(
            colors: [kPrimary, kPrimaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
        : null,
    borderRadius: BorderRadius.circular(18),
    image: _pickedImage != null
        ? DecorationImage(
            image: FileImage(_pickedImage!),
            fit: BoxFit.cover,
          )
        : (_networkImageUrl != null && _networkImageUrl!.isNotEmpty)
            ? DecorationImage(
                image: NetworkImage(_networkImageUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {},   // silently fallback
              )
            : null,
  ),
  alignment: Alignment.center,
  child: (_pickedImage == null && (_networkImageUrl == null || _networkImageUrl!.isEmpty))
      ? Text(initials,
          style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.white))
      : null,
),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: _pickImage,         // ← opens bottom sheet
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: kWarning,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.edit_rounded,
                      size: 12, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(name,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary)),
        const SizedBox(height: 2),
       Text(
  _pickedImage != null
      ? 'Photo selected'
      : (_networkImageUrl != null && _networkImageUrl!.isNotEmpty)
          ? 'Tap icon to change photo'
          : 'Tap icon to add photo',
  style: TextStyle(
      fontSize: 11,
      color: _pickedImage != null ? kSuccess : kTextMuted),
),
      ],
    ),
  );
}
Future<void> _pickImage() async {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Profile Photo',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Choose how to set your profile picture',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
            const SizedBox(height: 16),
            _sourceOption(
              icon: Icons.camera_alt_outlined,
              iconBg: kPrimaryLight,
              iconFg: kPrimary,
              label: 'Take a Photo',
              subtitle: 'Use your camera',
              onTap: () async {
                Navigator.pop(ctx);
                final xfile = await _picker.pickImage(
                  source: ImageSource.camera,
                  imageQuality: 80,
                );
                if (xfile != null) {
                  setState(() => _pickedImage = File(xfile.path));
                }
              },
            ),
            const SizedBox(height: 10),
            _sourceOption(
              icon: Icons.photo_library_outlined,
              iconBg: kPurpleLight,
              iconFg: kPurple,
              label: 'Choose from Gallery',
              subtitle: 'Pick from your photos',
              onTap: () async {
                Navigator.pop(ctx);
                final xfile = await _picker.pickImage(
                  source: ImageSource.gallery,
                  imageQuality: 80,
                );
                if (xfile != null) {
                  setState(() => _pickedImage = File(xfile.path));
                }
              },
            ),
            if (_pickedImage != null) ...[
              const SizedBox(height: 10),
              _sourceOption(
                icon: Icons.delete_outline_rounded,
                iconBg: kRedLight,
                iconFg: kError,
                label: 'Remove Photo',
                subtitle: 'Reset to initials avatar',
              onTap: () {
  Navigator.pop(ctx);
  setState(() {
    _pickedImage = null;
    _networkImageUrl = null;   // ← add this
  });
},
              ),
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

Widget _sourceOption({
  required IconData icon,
  required Color iconBg,
  required Color iconFg,
  required String label,
  required String subtitle,
  required VoidCallback onTap,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: iconFg),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary)),
              Text(subtitle,
                  style: const TextStyle(fontSize: 11, color: kTextMuted)),
            ],
          ),
          const Spacer(),
          const Icon(Icons.chevron_right_rounded, size: 18, color: kTextMuted),
        ],
      ),
    ),
  );
}

  // ---------------------------------------------------------------------------
  // Section Card
  // ---------------------------------------------------------------------------

  Widget _sectionCard({
    required IconData icon,
    required Color iconFg,
    required Color iconBg,
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                  color: iconBg, borderRadius: BorderRadius.circular(8)),
              child: Icon(icon, size: 15, color: iconFg),
            ),
            const SizedBox(width: 8),
            Text(title,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary)),
          ]),
          const SizedBox(height: 14),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 14),
          ...children,
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Field helpers
  // ---------------------------------------------------------------------------

  Widget _twoColRow({required Widget left, required Widget right}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: left),
        const SizedBox(width: 10),
        Expanded(child: right),
      ],
    );
  }

  Widget _fieldLabel(String label) => Padding(
        padding: const EdgeInsets.only(bottom: 0),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
                letterSpacing: 0.3)),
      );

  InputDecoration _dec({
    required String hint,
    required IconData icon,
    required Color iconColor,
    Widget? suffix,
  }) =>
      InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
        prefixIcon: Icon(icon, size: 17, color: iconColor),
        suffixIcon: suffix,
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kPrimary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kError),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: kError, width: 1.5),
        ),
        errorStyle: const TextStyle(fontSize: 10.5, color: kError),
      );

  Widget _field({
    required String label,
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required Color iconColor,
    int maxLines = 1,
    TextInputType keyboardType = TextInputType.text,
    TextCapitalization capitalization = TextCapitalization.none,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel(label),
        const SizedBox(height: 5),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          keyboardType: keyboardType,
          textCapitalization: capitalization,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: _dec(hint: hint, icon: icon, iconColor: iconColor),
          validator: validator,
        ),
      ],
    );
  }

  Widget _mobileField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Mobile Number'),
        const SizedBox(height: 5),
        TextFormField(
          controller: _mobileController,
          keyboardType: TextInputType.phone,
          maxLength: 10,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: '10-digit number',
            hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
            counterText: '',
            prefixIcon: const Icon(Icons.phone_outlined,
                color: kPrimary, size: 17),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kError),
            ),
            errorStyle: const TextStyle(fontSize: 10.5, color: kError),
          ),
          validator: (v) {
            if (v == null || v.trim().isEmpty) return 'Mobile is required';
            if (!RegExp(r'^\d{10}$').hasMatch(v.trim())) {
              return 'Enter valid 10-digit number';
            }
            return null;
          },
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Gender Selector
  // ---------------------------------------------------------------------------

  Widget _genderSelector() {
    return Row(
      children: _genders.asMap().entries.map((e) {
        final i   = e.key;
        final g   = e.value;
        final sel = _selectedGender == g;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < _genders.length - 1 ? 8 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedGender = g),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                decoration: BoxDecoration(
                  color: sel ? kPrimary : Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: sel ? kPrimary : kBorder,
                    width: sel ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _genderIcons[g] ?? Icons.person_outline_rounded,
                      size: 15,
                      color: sel ? Colors.white : kTextMuted,
                    ),
                    const SizedBox(width: 4),
                    Text(g,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: sel ? Colors.white : kTextSecondary)),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // DOB Tile
  // ---------------------------------------------------------------------------

  Widget _dobTile() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Date of Birth'),
        const SizedBox(height: 5),
        GestureDetector(
          onTap: _pickDob,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_outlined,
                    size: 16, color: kWarning),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formattedDob,
                    style: TextStyle(
                        fontSize: 13,
                        color: _selectedDob != null
                            ? kTextPrimary
                            : kTextMuted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Blood Group Picker
  // ---------------------------------------------------------------------------

  Widget _bloodGroupPicker() {
    return Wrap(
      spacing: 7,
      runSpacing: 7,
      children: _bloodGroups.map((g) {
        final sel = _selectedBloodGroup == g;
        return GestureDetector(
          onTap: () => setState(() => _selectedBloodGroup = g),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 52,
            height: 38,
            decoration: BoxDecoration(
              color: sel ? kError : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? kError : kBorder,
              ),
            ),
            alignment: Alignment.center,
            child: Text(g,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white : kTextSecondary)),
          ),
        );
      }).toList(),
    );
  }

  // ---------------------------------------------------------------------------
  // Weight Field
  // ---------------------------------------------------------------------------

  Widget _weightField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _fieldLabel('Weight'),
        const SizedBox(height: 5),
        TextFormField(
          controller: _weightController,
          keyboardType:
              const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,1}')),
          ],
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: InputDecoration(
            hintText: 'e.g. 65.5',
            hintStyle:
                const TextStyle(color: kTextMuted, fontSize: 13),
            prefixIcon: const Icon(Icons.monitor_weight_outlined,
                size: 17, color: Color(0xFF38A169)),
            suffixIcon: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 9),
                padding: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text('kg',
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kTextSecondary)),
              ),
            ),
            filled: true,
            fillColor: Colors.white,
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimary, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kError),
            ),
            errorStyle: const TextStyle(fontSize: 10.5, color: kError),
          ),
          validator: _validateWeight,
        ),
      ],
    );
  }
}