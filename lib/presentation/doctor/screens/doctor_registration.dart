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

class DoctorProfileSetupScreen extends ConsumerStatefulWidget {
  const DoctorProfileSetupScreen({super.key});

  @override
  ConsumerState<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState
    extends ConsumerState<DoctorProfileSetupScreen> {
  int _step = 1;

  // Controllers
  final _fullNameController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _qualificationController = TextEditingController();
  final _licenseController = TextEditingController();
  final _experienceController = TextEditingController();
  final _clinicNameController = TextEditingController();
  final _clinicAddressController = TextEditingController();
  final _clinicContactController = TextEditingController();
  final _clinicEmailController = TextEditingController();
  final _clinicWebsiteController = TextEditingController();
  final _consultationFeeController = TextEditingController();

  String _selectedSpecialization = '';
  String? _selectedGender;
  int? _selectedGenderId;

  File? _doctorPhoto;
  File? _clinicPhoto;
  String? _fcmToken;
  double? _latitude;
  double? _longitude;
  StreamSubscription<String>? _tokenRefreshSub;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _specializations = [
    {'value': 'general', 'label': 'General Physician'},
    {'value': 'cardiology', 'label': 'Cardiology'},
    {'value': 'dermatology', 'label': 'Dermatology'},
    {'value': 'pediatrics', 'label': 'Pediatrics'},
    {'value': 'orthopedics', 'label': 'Orthopedics'},
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(masterViewModelProvider.notifier).fetchGenderList();
    });
  }

  @override
  void dispose() {
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

  Future<void> _initFcm() async {
    try {
      final messaging = FirebaseMessaging.instance;
      await messaging.requestPermission(alert: true, badge: true, sound: true);
      final token = await messaging.getToken();
      if (!mounted) return;
      setState(() => _fcmToken = token);
      _tokenRefreshSub = messaging.onTokenRefresh.listen((token) {
        if (mounted) {
          setState(() => _fcmToken = token);
        }
      });
    } catch (e) {
      debugPrint('FCM token fetch failed: $e');
    }
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
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
    } catch (e) {
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
        _latitude = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  bool _isBlank(TextEditingController controller) {
    return controller.text.trim().isEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleSubmit() async {
    if (_step == 1) {
      if (_isBlank(_fullNameController)) {
        return _showError('Full Name is required');
      }
      if (_isBlank(_contactController)) {
        return _showError('Contact No is required');
      }
      
      if (_isBlank(_emailController)) {
        return _showError('Email is required');
      }
      if (_selectedGenderId == null || _selectedGenderId! <= 0) {
        return _showError('Gender is required');
      }
      if (_selectedSpecialization.isEmpty) {
        return _showError('Specialization is required');
      }
      if (_isBlank(_qualificationController)) {
        return _showError('Qualification is required');
      }
      if (_isBlank(_licenseController)) {
        return _showError('License Number is required');
      }
      if (_isBlank(_experienceController)) {
        return _showError('Experience is required');
      }
      final experience = int.tryParse(_experienceController.text.trim());
      if (experience == null) {
        return _showError('Experience must be a valid number');
      }

      setState(() => _step = 2);
      return;
    }

    // Step 2 validation (clinic image + consultation fee are optional)
    if (_isBlank(_clinicNameController)) {
      return _showError('Clinic Name is required');
    }
    if (_isBlank(_clinicAddressController)) {
      return _showError('Clinic Address is required');
    }
    if (_isBlank(_clinicContactController)) {
      return _showError('Clinic Contact is required');
    }
    if (_isBlank(_clinicEmailController)) {
      return _showError('Clinic Email is required');
    }

    if (_fcmToken == null) {
      try {
        _fcmToken = await FirebaseMessaging.instance.getToken();
      } catch (e) {
        debugPrint('FCM token refresh failed: $e');
      }
    }

    final doctorLogin = DoctorDetails(
      name: _fullNameController.text.trim(),
      mobile: _contactController.text.trim(),
      email: _emailController.text.trim(),
      genderId: _selectedGenderId,
      specialization: _selectedSpecialization,
      qualification: _qualificationController.text.trim(),
      licenseNo: _licenseController.text.trim(),
      experience: int.tryParse(_experienceController.text.trim()),
      image: _doctorPhoto?.path, // optional
      clinicName: _clinicNameController.text.trim(),
      clinicAddress: _clinicAddressController.text.trim(),
      clinicContact: _clinicContactController.text.trim(),
      clinicEmail: _clinicEmailController.text.trim(),
      websiteName: _clinicWebsiteController.text.trim(),
      consultationFee: _consultationFeeController.text.trim().isEmpty
          ? null
          : double.tryParse(_consultationFeeController.text.trim()),
      imageUrl: _clinicPhoto?.path, // optional
      latitude: _latitude,
      longitude: _longitude,
      roleId: 1,
      Token: _fcmToken,
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorLoginViewModelProvider);
    final masterState = ref.watch(masterViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF0F172A),
          ),
          onPressed: () {
            if (_step == 2) {
              setState(() => _step = 1);
            } else {
              Navigator.pop(context);
            }
          },
        ),
        title: const Text(
          'Profile Setup',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: Column(
              children: [
                // Step indicator
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _step == 1 ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _step == 1
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: _step == 2 ? 32 : 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: _step == 2
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFCBD5E1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Doctor Photo
                if (_step == 1)
                  Column(
                    children: [
                      GestureDetector(
                        onTap: () => _pickImage(true),
                        child: CircleAvatar(
                          radius: 48,
                          backgroundColor: const Color(0xFFE2E8F0),
                          backgroundImage: _doctorPhoto != null
                              ? FileImage(_doctorPhoto!)
                              : null,
                          child: _doctorPhoto == null
                              ? const Icon(
                                  Icons.person,
                                  size: 52,
                                  color: Color(0xFF94A3B8),
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload Doctor Photo',
                        style: TextStyle(
                          fontSize: 13,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Step 1 fields
                if (_step == 1) ...[
                  _buildTextField('Full Name', _fullNameController),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Contact No',
                    _contactController,
                    keyboard: TextInputType.phone,
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Email',
                    _emailController,
                    keyboard: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  _buildGenderSection(masterState),
                  const SizedBox(height: 16),
                  _buildDropdown(),
                  const SizedBox(height: 16),
                  _buildTextField('Qualification', _qualificationController),
                  const SizedBox(height: 16),
                  _buildTextField('License Number', _licenseController),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Experience (Years)',
                    _experienceController,
                    keyboard: TextInputType.number,
                  ),
                ],

                // Step 2 fields
                if (_step == 2) ...[
                  // Clinic photo
                  GestureDetector(
                    onTap: () => _pickImage(false),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage: _clinicPhoto != null
                          ? FileImage(_clinicPhoto!)
                          : null,
                      child: _clinicPhoto == null
                          ? const Icon(
                              Icons.local_hospital,
                              size: 52,
                              color: Color(0xFF94A3B8),
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Upload Clinic Photo',
                    style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField('Clinic Name', _clinicNameController),
                  const SizedBox(height: 16),
                  _buildTextArea('Clinic Address', _clinicAddressController),
                  const SizedBox(height: 16),
                  _buildTextField('Clinic Contact', _clinicContactController),
                  const SizedBox(height: 16),
                  _buildTextField('Clinic Email', _clinicEmailController),
                  const SizedBox(height: 16),
                  _buildTextField('Clinic Website', _clinicWebsiteController),
                  const SizedBox(height: 16),
                  _buildTextField(
                    'Consultation Fee',
                    _consultationFeeController,
                    keyboard: TextInputType.number,
                  ),
                  const SizedBox(height: 16),
                  _buildLocationField(),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: _handleSubmit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0F172A),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(13),
                      ),
                    ),
                    child: Text(
                      _step == 1 ? 'Continue' : 'Complete Setup',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading indicator
          if (state.isLoading) const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Location',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Container(
                height: 52,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Text(
                  hasLocation
                      ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                      : 'No location selected',
                  style: TextStyle(
                    fontSize: 14,
                    color: hasLocation
                        ? const Color(0xFF0F172A)
                        : const Color(0xFF94A3B8),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: _getCurrentLocation,
              child: Container(
                width: 52,
                height: 52,
                decoration: const BoxDecoration(
                  color: Color(0xFF3B82F6),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.navigation_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
            const SizedBox(width: 8),
            GestureDetector(
              onTap: _selectFromMap,
              child: Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.map_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTextField(
    String label,
    TextEditingController controller, {
    TextInputType keyboard = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            keyboardType: keyboard,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTextArea(String label, TextEditingController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: TextField(
            controller: controller,
            maxLines: 3,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Specialization',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 52,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedSpecialization.isEmpty
                  ? null
                  : _selectedSpecialization,
              hint: const Text('Select specialization'),
              isExpanded: true,
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF94A3B8),
              ),
              items: _specializations
                  .map(
                    (s) => DropdownMenuItem<String>(
                      value: s['value'],
                      child: Text(s['label']!),
                    ),
                  )
                  .toList(),
              onChanged: (val) =>
                  setState(() => _selectedSpecialization = val ?? ''),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderSection(MasterState masterState) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
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
              final id = g.genderId;
              if (name != null && name.isNotEmpty && id != null) {
                idByName[name] = id;
              }
            }
            return _GenderSelector(
              options: options,
              selected: _selectedGender,
              onChanged: (v) => setState(() {
                _selectedGender = v;
                _selectedGenderId = idByName[v];
              }),
            );
          },
          loading: () => const _InlineLoading(),
          error: (e, _) =>
              const _InlineError(text: 'Unable to load gender list'),
        ),
      ],
    );
  }
}

class _GenderSelector extends StatelessWidget {
  const _GenderSelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  static const _iconMap = {
    'male': Icons.male_rounded,
    'female': Icons.female_rounded,
    'other': Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(options.length, (i) {
        final label = options[i];
        final icon =
            _iconMap[label.toLowerCase()] ?? Icons.person_outline_rounded;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.only(right: i < options.length - 1 ? 8 : 0),
            child: _GenderOption(
              label: label,
              icon: icon,
              isSelected: selected == label,
              onTap: () => onChanged(label),
            ),
          ),
        );
      }),
    );
  }
}

class _GenderOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _GenderOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF0F172A).withOpacity(0.08)
              : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFE2E8F0),
            width: isSelected ? 1.8 : 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon,
                size: 18,
                color: isSelected
                    ? const Color(0xFF0F172A)
                    : const Color(0xFF94A3B8)),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color:
                    isSelected ? const Color(0xFF0F172A) : const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ),
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
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF0F172A)),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Select Location',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            child: const Text(
              'Confirm',
              style: TextStyle(
                color: Color(0xFF3B82F6),
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: CameraPosition(
              target: _selected,
              zoom: 14,
            ),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Text(
                '${_selected.latitude.toStringAsFixed(4)}, ${_selected.longitude.toStringAsFixed(4)}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF0F172A),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
