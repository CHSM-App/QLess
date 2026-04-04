import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:image_picker/image_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/shared/view_models/master_viewmodel.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';

// ─── Color Palette ───────────────────────────────────────────────────────────
const kPrimaryBlue = Color(0xFF1A73E8);
const kLightBlue   = Color(0xFFE8F0FE);
const kAccentGreen = Color(0xFF34A853);
const kRedAccent   = Color(0xFFEA4335);
const kSurface     = Color(0xFFF8F9FA);
const kCardBg      = Color(0xFFFFFFFF);
const kTextDark    = Color(0xFF1F2937);
const kTextMuted   = Color(0xFF6B7280);
const kDivider     = Color(0xFFE5E7EB);

class DoctorProfileSetupScreen extends ConsumerStatefulWidget {
  const DoctorProfileSetupScreen({super.key});

  @override
  ConsumerState<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState
    extends ConsumerState<DoctorProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  int _step = 1;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // Controllers
  final _fullNameController       = TextEditingController();
  final _contactController        = TextEditingController();
  final _emailController          = TextEditingController();
  final _qualificationController  = TextEditingController();
  final _licenseController        = TextEditingController();
  final _experienceController     = TextEditingController();
  final _clinicNameController     = TextEditingController();
  final _clinicAddressController  = TextEditingController();
  final _clinicContactController  = TextEditingController();
  final _clinicEmailController    = TextEditingController();
  final _clinicWebsiteController  = TextEditingController();
  final _consultationFeeController = TextEditingController();

  String  _selectedSpecialization = '';
  String? _selectedGender;
  int?    _selectedGenderId;

  File?  _doctorPhoto;
  File?  _clinicPhoto;
  String? _fcmToken;
  double? _latitude;
  double? _longitude;
  StreamSubscription<String>? _tokenRefreshSub;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _specializations = [
    {'value': 'general',      'label': 'General Physician'},
    {'value': 'cardiology',   'label': 'Cardiology'},
    {'value': 'dermatology',  'label': 'Dermatology'},
    {'value': 'pediatrics',   'label': 'Pediatrics'},
    {'value': 'orthopedics',  'label': 'Orthopedics'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(masterViewModelProvider.notifier).fetchGenderList();
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    _tokenRefreshSub?.cancel();
    _fullNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _qualificationController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicContactController.dispose();
    _clinicEmailController.dispose();
    _clinicWebsiteController.dispose();
    _consultationFeeController.dispose();
    super.dispose();
  }

  void _animateStep() {
    _animController.reset();
    _animController.forward();
  }

  Future<void> _pickImage(bool isDoctorPhoto) async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        if (isDoctorPhoto) {
          _doctorPhoto = File(image.path);
        } else {
          _clinicPhoto = File(image.path);
        }
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError('Location permission permanently denied. Enable it in settings.');
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      _showError('Failed to get location');
    }
  }

  Future<void> _selectFromMap() async {
    final result = await Navigator.push<LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLatLng: _latitude != null && _longitude != null
              ? LatLng(_latitude!, _longitude!)
              : const LatLng(15.9073, 73.6990),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude  = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  bool _isBlank(TextEditingController c) => c.text.trim().isEmpty;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(message, style: const TextStyle(fontSize: 13))),
          ],
        ),
        backgroundColor: kRedAccent,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (_step == 1) {
      if (_isBlank(_fullNameController))       return _showError('Full Name is required');
      if (_isBlank(_contactController))        return _showError('Contact No is required');
      if (_isBlank(_emailController))          return _showError('Email is required');
      if (_selectedGenderId == null || _selectedGenderId! <= 0)
                                               return _showError('Gender is required');
      if (_selectedSpecialization.isEmpty)     return _showError('Specialization is required');
      if (_isBlank(_qualificationController))  return _showError('Qualification is required');
      if (_isBlank(_licenseController))        return _showError('License Number is required');
      if (_isBlank(_experienceController))     return _showError('Experience is required');
      if (int.tryParse(_experienceController.text.trim()) == null)
                                               return _showError('Experience must be a valid number');
      setState(() => _step = 2);
      _animateStep();
      return;
    }

    if (_isBlank(_clinicNameController))    return _showError('Clinic Name is required');
    if (_isBlank(_clinicAddressController)) return _showError('Clinic Address is required');
    if (_isBlank(_clinicContactController)) return _showError('Clinic Contact is required');
    if (_isBlank(_clinicEmailController))   return _showError('Clinic Email is required');

    if (_fcmToken == null) {
      try { _fcmToken = await FirebaseMessaging.instance.getToken(); }
      catch (e) { debugPrint('FCM token refresh failed: $e'); }
    }

    final doctorLogin = DoctorDetails(
      name:            _fullNameController.text.trim(),
      mobile:          _contactController.text.trim(),
      email:           _emailController.text.trim(),
      genderId:        _selectedGenderId,
      specialization:  _selectedSpecialization,
      qualification:   _qualificationController.text.trim(),
      licenseNo:       _licenseController.text.trim(),
      experience:      int.tryParse(_experienceController.text.trim()),
      image:           _doctorPhoto?.path,
      clinicName:      _clinicNameController.text.trim(),
      clinicAddress:   _clinicAddressController.text.trim(),
      clinicContact:   _clinicContactController.text.trim(),
      clinicEmail:     _clinicEmailController.text.trim(),
      websiteName:     _clinicWebsiteController.text.trim(),
      consultationFee: _consultationFeeController.text.trim().isEmpty
          ? null
          : double.tryParse(_consultationFeeController.text.trim()),
      imageUrl:        _clinicPhoto?.path,
      latitude:        _latitude,
      longitude:       _longitude,
      roleId:          1,
      Token:           _fcmToken,
    );

    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .addDoctorDetails(doctorLogin);

    final latestState = ref.read(doctorLoginViewModelProvider);
    if (latestState.error == null && mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    } else if (latestState.error != null) {
      _showError(latestState.error!);
    }
  }

  // ─── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(doctorLoginViewModelProvider);
    final masterState = ref.watch(masterViewModelProvider);

    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          FadeTransition(
            opacity: _fadeAnim,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStepIndicator(),
                  const SizedBox(height: 20),
                  if (_step == 1) _buildStep1(masterState),
                  if (_step == 2) _buildStep2(),
                  const SizedBox(height: 24),
                  _buildCTA(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          if (state.isLoading)
            Container(
              color: Colors.black26,
              child: const Center(
                child: CircularProgressIndicator(color: kPrimaryBlue),
              ),
            ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardBg,
      elevation: 0,
      surfaceTintColor: kCardBg,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: kDivider),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kTextDark),
        onPressed: () {
          if (_step == 2) {
            setState(() => _step = 1);
            _animateStep();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: const Text(
        'Profile Setup',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextDark),
      ),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kLightBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            'Step $_step of 2',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimaryBlue,
            ),
          ),
        ),
      ],
    );
  }

  // ─── Step indicator ────────────────────────────────────────────────────────

  Widget _buildStepIndicator() {
    return Row(
      children: [
        _StepChip(
          index: 1,
          label: 'Personal Info',
          icon: Icons.person_outline_rounded,
          state: _step == 1
              ? _StepState.active
              : _StepState.done,
        ),
        Expanded(
          child: Container(
            height: 2,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: _step == 2 ? kPrimaryBlue : kDivider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        _StepChip(
          index: 2,
          label: 'Clinic Details',
          icon: Icons.local_hospital_outlined,
          state: _step == 2 ? _StepState.active : _StepState.pending,
        ),
      ],
    );
  }

  // ─── Step 1 ────────────────────────────────────────────────────────────────

  Widget _buildStep1(MasterState masterState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Avatar
        Center(child: _AvatarPicker(
          photo: _doctorPhoto,
          icon: Icons.person_rounded,
          label: 'Upload Doctor Photo',
          onTap: () => _pickImage(true),
        )),
        const SizedBox(height: 24),

        _SectionHeader(title: 'Basic Details'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildField('Full Name', _fullNameController, hint: 'Dr. Arjun Sharma', required: true),
          _buildField('Contact No', _contactController, hint: '+91 98765 43210',
              keyboard: TextInputType.phone, required: true),
          _buildField('Email Address', _emailController, hint: 'doctor@email.com',
              keyboard: TextInputType.emailAddress, required: true),
          _buildGenderSection(masterState),
        ]),

        const SizedBox(height: 16),
        _SectionHeader(title: 'Professional Info'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildDropdown(),
          _buildField('Qualification', _qualificationController, hint: 'MBBS, MD...', required: true),
          Row(children: [
            Expanded(child: _buildField('License No', _licenseController, hint: 'MCI-XXXXX', required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildField('Experience (yrs)', _experienceController,
                hint: 'e.g. 8', keyboard: TextInputType.number, required: true)),
          ]),
        ]),
      ],
    );
  }

  // ─── Step 2 ────────────────────────────────────────────────────────────────

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Center(child: _AvatarPicker(
          photo: _clinicPhoto,
          icon: Icons.local_hospital_rounded,
          label: 'Upload Clinic Photo',
          onTap: () => _pickImage(false),
        )),
        const SizedBox(height: 24),

        _SectionHeader(title: 'Clinic Details'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildField('Clinic Name', _clinicNameController, hint: 'Apollo Clinic', required: true),
          _buildTextArea('Clinic Address', _clinicAddressController,
              hint: '123, MG Road, Panaji, Goa', required: true),
          Row(children: [
            Expanded(child: _buildField('Clinic Contact', _clinicContactController,
                hint: '+91...', keyboard: TextInputType.phone, required: true)),
            const SizedBox(width: 12),
            Expanded(child: _buildField('Clinic Email', _clinicEmailController,
                hint: 'clinic@...', keyboard: TextInputType.emailAddress, required: true)),
          ]),
          Row(children: [
            Expanded(child: _buildField('Website', _clinicWebsiteController, hint: 'www.clinic.com')),
            const SizedBox(width: 12),
            Expanded(child: _buildField('Consult. Fee (₹)', _consultationFeeController,
                hint: '500', keyboard: TextInputType.number)),
          ]),
        ]),

        const SizedBox(height: 16),
        _SectionHeader(title: 'Location'),
        const SizedBox(height: 12),
        _Card(children: [_buildLocationField()]),
      ],
    );
  }

  // ─── CTA button ────────────────────────────────────────────────────────────

  Widget _buildCTA() {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _step == 1 ? 'Continue' : 'Complete Setup',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: 0.3),
            ),
            const SizedBox(width: 8),
            Icon(
              _step == 1 ? Icons.arrow_forward_rounded : Icons.check_circle_outline_rounded,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Field builders ────────────────────────────────────────────────────────

  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFBCC1C8), fontSize: 14),
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimaryBlue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFBCC1C8), fontSize: 14),
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kDivider),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kDivider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: kPrimaryBlue, width: 1.5),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(label: 'Specialization', required: true),
          const SizedBox(height: 6),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedSpecialization.isNotEmpty ? kPrimaryBlue : kDivider,
                width: _selectedSpecialization.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSpecialization.isEmpty ? null : _selectedSpecialization,
                hint: const Text(
                  'Select specialization',
                  style: TextStyle(color: Color(0xFFBCC1C8), fontSize: 14),
                ),
                isExpanded: true,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMuted),
                style: const TextStyle(fontSize: 14, color: kTextDark),
                items: _specializations
                    .map((s) => DropdownMenuItem<String>(
                          value: s['value'],
                          child: Text(s['label']!),
                        ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedSpecialization = val ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenderSection(MasterState masterState) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(label: 'Gender', required: true),
          const SizedBox(height: 8),
          masterState.fetchGender.when(
            data: (list) {
              final options = list
                  .map((e) => e.gender)
                  .whereType<String>()
                  .where((e) => e.trim().isNotEmpty)
                  .toList();
              if (options.isEmpty) return const _InlineLoading();
              final idByName = <String, int>{};
              for (final g in list) {
                final name = g.gender?.trim();
                final id   = g.genderId;
                if (name != null && name.isNotEmpty && id != null) {
                  idByName[name] = id;
                }
              }
              return _GenderSelector(
                options: options,
                selected: _selectedGender,
                onChanged: (v) => setState(() {
                  _selectedGender   = v;
                  _selectedGenderId = idByName[v];
                }),
              );
            },
            loading: () => const _InlineLoading(),
            error:   (_, __) => const _InlineError(text: 'Unable to load gender list'),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Clinic Location'),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 50,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  color: hasLocation ? kLightBlue : kSurface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: hasLocation ? kPrimaryBlue : kDivider,
                    width: hasLocation ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      hasLocation ? Icons.location_on_rounded : Icons.location_off_rounded,
                      size: 16,
                      color: hasLocation ? kPrimaryBlue : kTextMuted,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasLocation
                            ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                            : 'No location selected',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasLocation ? kPrimaryBlue : kTextMuted,
                          fontWeight: hasLocation ? FontWeight.w500 : FontWeight.normal,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            _LocationButton(
              icon: Icons.my_location_rounded,
              tooltip: 'Use GPS',
              onTap: _getCurrentLocation,
            ),
            const SizedBox(width: 8),
            _LocationButton(
              icon: Icons.map_outlined,
              tooltip: 'Pick on map',
              onTap: _selectFromMap,
            ),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 3, height: 14, decoration: BoxDecoration(
          color: kPrimaryBlue,
          borderRadius: BorderRadius.circular(2),
        )),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextDark,
            letterSpacing: 0.3,
          ),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextMuted),
        ),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*', style: TextStyle(color: kRedAccent, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ],
    );
  }
}

class _AvatarPicker extends StatelessWidget {
  final File? photo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.photo,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88,
            height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kLightBlue,
              border: Border.all(color: kPrimaryBlue, width: 2),
            ),
            child: photo != null
                ? ClipOval(child: Image.file(photo!, fit: BoxFit.cover))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 42, color: kPrimaryBlue),
                      Positioned(
                        bottom: 6,
                        right: 6,
                        child: Container(
                          width: 22,
                          height: 22,
                          decoration: const BoxDecoration(
                            color: kPrimaryBlue,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.add_rounded, color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: kPrimaryBlue, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

class _LocationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _LocationButton({required this.icon, required this.tooltip, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: kLightBlue,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kPrimaryBlue.withOpacity(0.3)),
          ),
          child: Icon(icon, color: kPrimaryBlue, size: 20),
        ),
      ),
    );
  }
}

// ─── Step chip ───────────────────────────────────────────────────────────────

enum _StepState { active, done, pending }

class _StepChip extends StatelessWidget {
  final int index;
  final String label;
  final IconData icon;
  final _StepState state;

  const _StepChip({
    required this.index,
    required this.label,
    required this.icon,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    IconData displayIcon;

    switch (state) {
      case _StepState.active:
        bg = kLightBlue; fg = kPrimaryBlue; border = kPrimaryBlue;
        displayIcon = icon;
      case _StepState.done:
        bg = const Color(0xFFE6F4EA); fg = kAccentGreen; border = kAccentGreen;
        displayIcon = Icons.check_rounded;
      case _StepState.pending:
        bg = kSurface; fg = kTextMuted; border = kDivider;
        displayIcon = icon;
    }

    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5),
          ),
          child: Icon(displayIcon, size: 14, color: fg),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: state == _StepState.pending ? FontWeight.normal : FontWeight.w600,
            color: fg,
          ),
        ),
      ],
    );
  }
}

// ─── Gender selector ─────────────────────────────────────────────────────────

class _GenderSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _GenderSelector({required this.options, required this.selected, required this.onChanged});

  static const _iconMap = {
    'male':   Icons.male_rounded,
    'female': Icons.female_rounded,
    'other':  Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        children: List.generate(options.length, (i) {
          final label     = options[i];
          final icon      = _iconMap[label.toLowerCase()] ?? Icons.person_outline_rounded;
          final isSelected = selected == label;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () => onChanged(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected ? kLightBlue : kSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? kPrimaryBlue : kDivider,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(icon, size: 16,
                          color: isSelected ? kPrimaryBlue : kTextMuted),
                      const SizedBox(width: 5),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? kPrimaryBlue : kTextMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ─── Inline states ────────────────────────────────────────────────────────────

class _InlineLoading extends StatelessWidget {
  const _InlineLoading();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 44,
      child: Center(
        child: SizedBox(
          width: 18, height: 18,
          child: CircularProgressIndicator(strokeWidth: 2, color: kPrimaryBlue),
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
          const Icon(Icons.error_outline_rounded, size: 18, color: kRedAccent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500,
                  color: Color(0xFFB91C1C)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// MAP PICKER SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class _MapPickerScreen extends StatefulWidget {
  final LatLng initialLatLng;
  const _MapPickerScreen({required this.initialLatLng});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late LatLng _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLatLng;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurface,
      appBar: AppBar(
        backgroundColor: kCardBg,
        elevation: 0,
        surfaceTintColor: kCardBg,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kDivider),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: kTextDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: kTextDark),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: TextButton(
              onPressed: () => Navigator.pop(context, _selected),
              style: TextButton.styleFrom(
                backgroundColor: kPrimaryBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              ),
              child: const Text(
                'Confirm',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(target: _selected, zoom: 14),
            onTap: (latLng) => setState(() => _selected = latLng),
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _selected,
              ),
            },
          ),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: kCardBg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kPrimaryBlue.withOpacity(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: const BoxDecoration(
                      color: kLightBlue,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: kPrimaryBlue, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Selected coordinates',
                        style: TextStyle(fontSize: 11, color: kTextMuted),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${_selected.latitude.toStringAsFixed(4)}, ${_selected.longitude.toStringAsFixed(4)}',
                        style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark,
                        ),
                      ),
                    ],
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