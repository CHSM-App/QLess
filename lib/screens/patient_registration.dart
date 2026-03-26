import 'package:flutter/material.dart';

class PatientRegistrationScreen extends StatefulWidget {
  const PatientRegistrationScreen({super.key});

  @override
  State<PatientRegistrationScreen> createState() =>
      _PatientRegistrationScreenState();
}

class _PatientRegistrationScreenState extends State<PatientRegistrationScreen> {
  final _fullNameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();
  final _weightController = TextEditingController();

  String? _selectedGender;
  String? _selectedBloodGroup;

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

  Future<void> _selectDob() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 18),
      firstDate: DateTime(1900),
      lastDate: now,
    );

    if (pickedDate != null) {
      final day = pickedDate.day.toString().padLeft(2, '0');
      final month = pickedDate.month.toString().padLeft(2, '0');
      final year = pickedDate.year.toString();

      setState(() {
        _dobController.text = '$day/$month/$year';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 18,
            color: Color(0xFF0F172A),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Patient Registration',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: Color(0xFF0F172A),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildTextField('Full Name', _fullNameController),
            const SizedBox(height: 16),
            _buildTextField(
              'Mobile Number',
              _mobileController,
              keyboard: TextInputType.phone,
            ),
            const SizedBox(height: 16),
            _buildTextField(
              'Email',
              _emailController,
              keyboard: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            _buildTextArea('Address', _addressController),
            const SizedBox(height: 16),
            _buildGenderDropdown(),
            const SizedBox(height: 16),
            _buildDateField(),
            const SizedBox(height: 16),
            _buildBloodGroupDropdown(),
            const SizedBox(height: 16),
            _buildTextField(
              'Weight',
              _weightController,
              keyboard: const TextInputType.numberWithOptions(decimal: true),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0F172A),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text(
                  'Continue',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
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
              value: _selectedGender,
              isExpanded: true,
              hint: const Text('Select gender'),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF94A3B8),
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Other', child: Text('Other')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'DOB',
          style: TextStyle(
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
            controller: _dobController,
            readOnly: true,
            onTap: _selectDob,
            style: const TextStyle(fontSize: 14, color: Color(0xFF0F172A)),
            decoration: const InputDecoration(
              border: InputBorder.none,
              hintText: 'Select date of birth',
              hintStyle: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
              ),
              suffixIcon: Icon(
                Icons.calendar_today_outlined,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
              contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Blood Group',
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
              value: _selectedBloodGroup,
              isExpanded: true,
              hint: const Text('Select blood group'),
              icon: const Icon(
                Icons.keyboard_arrow_down,
                color: Color(0xFF94A3B8),
              ),
              items: const [
                DropdownMenuItem(value: 'A+', child: Text('A+')),
                DropdownMenuItem(value: 'A-', child: Text('A-')),
                DropdownMenuItem(value: 'B+', child: Text('B+')),
                DropdownMenuItem(value: 'B-', child: Text('B-')),
                DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                DropdownMenuItem(value: 'O+', child: Text('O+')),
                DropdownMenuItem(value: 'O-', child: Text('O-')),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedBloodGroup = value;
                });
              },
            ),
          ),
        ),
      ],
    );
  }
}
