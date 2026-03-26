


import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/doctor_login.dart';
import 'package:qless/presentation/providers/viewModel_provider.dart';
import 'package:qless/presentation/viewmodels/doctor_login_viewmodel.dart';


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

  void _handleSubmit() {
    if (_step == 1) {
      setState(() => _step = 2);
    } else {
      final doctorLogin = DoctorLogin(
        name: _fullNameController.text,
        mobile: _contactController.text,
        email: _emailController.text,
        specialization: _selectedSpecialization,
        qualification: _qualificationController.text,
        licenseNo: _licenseController.text,
        experience: int.tryParse(_experienceController.text),
        image: _doctorPhoto?.path,
        clinicName: _clinicNameController.text,
        clinicAddress: _clinicAddressController.text,
        clinicContact: _clinicContactController.text,
        clinicEmail: _clinicEmailController.text,
        consultationFee: double.tryParse(_consultationFeeController.text),
        //clinicImage: _clinicPhoto?.path,
      );

      ref.read(doctorLoginViewModelProvider.notifier).addDoctorDetails(doctorLogin);
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