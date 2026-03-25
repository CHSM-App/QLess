import 'package:flutter/material.dart';

class DoctorProfileSetupScreen extends StatefulWidget {
  const DoctorProfileSetupScreen({super.key});

  @override
  State<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState extends State<DoctorProfileSetupScreen> {
  int _step = 1;

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
    _qualificationController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _consultationFeeController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    if (_step == 1) {
      setState(() => _step = 2);
    } else {
      // Navigate to dashboard
      // Navigator.pushReplacementNamed(context, '/doctor/dashboard');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile setup complete!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            // ── STEP INDICATOR ─────────────────────────────
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

            // ── PROFILE PHOTO ───────────────────────────────
            Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 52,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload Photo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── STEP 1 FIELDS ───────────────────────────────
            if (_step == 1) ...[
              _buildLabel('Full Name'),
              _buildTextField(
                controller: _fullNameController,
                hint: 'Dr. John Smith',
                keyboardType: TextInputType.name,
              ),

                  const SizedBox(height: 16),

              _buildLabel('Contact No'),
              _buildTextField(
                controller: _contactController,
                hint: 'Contact No',
              ),
                const SizedBox(height: 16),

              _buildLabel('Email'),
              _buildTextField(
                controller: _emailController,
                hint: 'Email',
              ),
              const SizedBox(height: 16),

              _buildLabel('Specialization'),
              _buildDropdown(),
              const SizedBox(height: 16),

              _buildLabel('Qualification'),
              _buildTextField(
                controller: _qualificationController,
                hint: 'MBBS, MD',
              ),
              const SizedBox(height: 16),

              _buildLabel('License Number'),
              _buildTextField(
                controller: _licenseController,
                hint: 'MED123456',
              ),
              const SizedBox(height: 16),

              _buildLabel('Experience (Years)'),
              _buildTextField(
                controller: _experienceController,
                hint: '5',
                keyboardType: TextInputType.number,
              ),
            ],

            // ── STEP 2 FIELDS ───────────────────────────────
             Column(
              children: [
                Stack(
                  children: [
                    Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        color: const Color(0xFFE2E8F0),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.person,
                        size: 52,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: Color(0xFF0F172A),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.camera_alt,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Text(
                  'Upload  Clinic Photo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
              ],
            ),
            if (_step == 2) ...[
              _buildLabel('Clinic Name'),
              _buildTextField(
                controller: _clinicNameController,
                hint: 'City Medical Center',
              ),
              const SizedBox(height: 16),

              _buildLabel('Clinic Address'),
              _buildTextArea(
                controller: _clinicAddressController,
                hint: '123 Main St, City, State',
              ),

               const SizedBox(height: 16),

              _buildLabel('Clinic Contact No'),
              _buildTextArea(
                controller: _clinicContactController,
                hint: '123 Main St, City, State',
              ),
               const SizedBox(height: 16),

              _buildLabel('Clinic Email'),
              _buildTextArea(
                controller: _clinicContactController,
                hint: '123 Main St, City, State',
              ),
              const SizedBox(height: 16),

              _buildLabel('Consultation Fee'),
              _buildFeeField(),
            ],

            const SizedBox(height: 28),

            // ── SUBMIT BUTTON ────────────────────────────────
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
    );
  }

  Widget _buildLabel(String label) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildDropdown() {
    return Container(
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
          hint: const Text(
            'Select specialization',
            style: TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          ),
          isExpanded: true,
          icon: const Icon(Icons.keyboard_arrow_down,
              color: Color(0xFF94A3B8)),
          style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
          dropdownColor: Colors.white,
          items: _specializations
              .map((s) => DropdownMenuItem<String>(
                    value: s['value'],
                    child: Text(s['label']!),
                  ))
              .toList(),
          onChanged: (val) {
            setState(() => _selectedSpecialization = val ?? '');
          },
        ),
      ),
    );
  }

  Widget _buildTextArea({
    required TextEditingController controller,
    required String hint,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: TextField(
        controller: controller,
        maxLines: 3,
        style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle:
              const TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
    );
  }

  Widget _buildFeeField() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Text(
              '₹',
              style: TextStyle(fontSize: 15, color: Color(0xFF94A3B8)),
            ),
          ),
          Expanded(
            child: TextField(
              controller: _consultationFeeController,
              keyboardType: TextInputType.number,
              style:
                  const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
              decoration: const InputDecoration(
                hintText: '500',
                hintStyle:
                    TextStyle(fontSize: 14, color: Color(0xFF94A3B8)),
                border: InputBorder.none,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }
}