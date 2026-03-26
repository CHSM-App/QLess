


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
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

  File? _doctorPhoto;
  File? _clinicPhoto;

  final ImagePicker _picker = ImagePicker();

  final List<Map<String, String>> _specializations = [
    {'value': 'general', 'label': 'General Physician'},
    {'value': 'cardiology', 'label': 'Cardiology'},
    {'value': 'dermatology', 'label': 'Dermatology'},
    {'value': 'pediatrics', 'label': 'Pediatrics'},
    {'value': 'orthopedics', 'label': 'Orthopedics'},
  ];

  @override
  void dispose() {
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

  Future<void> _pickImage(bool isDoctorPhoto) async {
    final XFile? image =
        await _picker.pickImage(source: ImageSource.gallery);
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

  bool _isBlank(TextEditingController controller) {
    return controller.text.trim().isEmpty;
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
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

    final doctorLogin = DoctorLogin(
      name: _fullNameController.text.trim(),
      mobile: _contactController.text.trim(),
      email: _emailController.text.trim(),
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
      roleId: 1
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

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 18, color: Color(0xFF0F172A)),
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
              fontSize: 17, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
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
                              ? const Icon(Icons.person, size: 52, color: Color(0xFF94A3B8))
                              : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Upload Doctor Photo',
                        style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Step 1 fields
                if (_step == 1) ...[
                  _buildTextField('Full Name', _fullNameController),
                  const SizedBox(height: 16),
                  _buildTextField('Contact No', _contactController, keyboard: TextInputType.phone),
                  const SizedBox(height: 16),
                  _buildTextField('Email', _emailController, keyboard: TextInputType.emailAddress),
                  const SizedBox(height: 16),
                  _buildDropdown(),
                  const SizedBox(height: 16),
                  _buildTextField('Qualification', _qualificationController),
                  const SizedBox(height: 16),
                  _buildTextField('License Number', _licenseController),
                  const SizedBox(height: 16),
                  _buildTextField('Experience (Years)', _experienceController,
                      keyboard: TextInputType.number),
                ],

                // Step 2 fields
                if (_step == 2) ...[
                  // Clinic photo
                  GestureDetector(
                    onTap: () => _pickImage(false),
                    child: CircleAvatar(
                      radius: 48,
                      backgroundColor: const Color(0xFFE2E8F0),
                      backgroundImage:
                          _clinicPhoto != null ? FileImage(_clinicPhoto!) : null,
                      child: _clinicPhoto == null
                          ? const Icon(Icons.local_hospital,
                              size: 52, color: Color(0xFF94A3B8))
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
                  _buildTextField('Consultation Fee', _consultationFeeController,
                      keyboard: TextInputType.number),
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
                          fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),

          // Loading indicator
          if (state.isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller,
      {TextInputType keyboard = TextInputType.text}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
        Text(label,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
        const Text('Specialization',
            style: TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500, color: Color(0xFF0F172A))),
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
              value: _selectedSpecialization.isEmpty ? null : _selectedSpecialization,
              hint: const Text('Select specialization'),
              isExpanded: true,
              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF94A3B8)),
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
    );
  }
}
