import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/master_data.dart';

class AddFamilyMemberScreen extends StatefulWidget {
  /// Pass an existing member to pre-fill the form for editing.
  final FamilyMember? existingMember;

  /// Gender options loaded from the API / DB (Gender_id + Gender label).
  final List<GenderModel> genderOptions;

  /// Relation options loaded from the API / DB (relation_id + relation label).
  final List<RelationModel> relationOptions;

  const AddFamilyMemberScreen({
    super.key,
    this.existingMember,
    this.genderOptions = const [
      GenderModel(genderId: 1, gender: 'Male'),
      GenderModel(genderId: 2, gender: 'Female'),
      GenderModel(genderId: 3, gender: 'Other'),
    ],
    this.relationOptions = const [
      RelationModel(relationId: 2, relation: 'Spouse'),
      RelationModel(relationId: 3, relation: 'Child'),
      RelationModel(relationId: 4, relation: 'Parent'),
      RelationModel(relationId: 5, relation: 'Sibling'),
      RelationModel(relationId: 6, relation: 'Other'),
    ],
  });

  @override
  State<AddFamilyMemberScreen> createState() => _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState extends State<AddFamilyMemberScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _mobileController = TextEditingController();
  final _dobController = TextEditingController();

  /// Holds the selected Gender_id.
  int? _selectedGenderId;

  /// Holds the selected relation_id.
  int? _selectedRelationId;

  DateTime? _selectedDate;
  bool _isConfirmed = false;

  bool get _isEditing => widget.existingMember != null;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _prefillIfEditing();
  }

  void _prefillIfEditing() {
    final m = widget.existingMember;
    if (m == null) return;

    _nameController.text = m.memberName ?? '';
    _mobileController.text = m.mobileNo ?? '';
    _selectedGenderId = m.genderId;
    _selectedRelationId = m.relationId;

    if (m.dob != null) {
      _selectedDate = m.dob;
      _dobController.text = _formatDisplayDate(m.dob!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _mobileController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  /// Formats a DateTime to "DD/MM/YYYY" for display.
  String _formatDisplayDate(DateTime date) =>
      '${date.day.toString().padLeft(2, '0')}/'
      '${date.month.toString().padLeft(2, '0')}/'
      '${date.year}';

  int _calculateAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  GenderModel? get _selectedGenderOption => widget.genderOptions
      .cast<GenderModel?>()
      .firstWhere((g) => g?.genderId == _selectedGenderId, orElse: () => null);

  RelationModel? get _selectedRelationOption => widget.relationOptions
      .cast<RelationModel?>()
      .firstWhere((r) => r?.relationId == _selectedRelationId,
          orElse: () => null);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: now,
      builder: (context, child) => Theme(
        data: Theme.of(context).copyWith(
          colorScheme: const ColorScheme.light(primary: Color(0xFF3D5AF1)),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobController.text = _formatDisplayDate(picked);
      });
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedGenderId == null) {
      _showSnack('Please select a gender.');
      return;
    }
    if (_selectedDate == null) {
      _showSnack('Please select a date of birth.');
      return;
    }
    if (_selectedRelationId == null) {
      _showSnack('Please select a relation.');
      return;
    }
    if (!_isConfirmed) {
      _showSnack('Please confirm that the details are accurate.');
      return;
    }

    final member = FamilyMember(
      memberId: widget.existingMember?.memberId,
      memberName: _nameController.text.trim(),
      genderId: _selectedGenderId,
      genderName: _selectedGenderOption?.gender,
      dob: _selectedDate,
      relationId: _selectedRelationId,
      relationName: _selectedRelationOption?.relation,
      mobileNo: _mobileController.text.trim().isEmpty
          ? null
          : _mobileController.text.trim(),
    );

    Navigator.of(context).pop(member);
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            Expanded(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildLabel('Member Name', required: true),
                      const SizedBox(height: 8),
                      _buildNameField(),
                      const SizedBox(height: 20),

                      _buildLabel('Gender', required: true),
                      const SizedBox(height: 10),
                      _buildGenderSelector(),
                      const SizedBox(height: 20),

                      _buildLabel('Date of Birth', required: true),
                      const SizedBox(height: 8),
                      _buildDobField(),
                      const SizedBox(height: 20),

                      _buildLabel('Relation', required: true),
                      const SizedBox(height: 8),
                      _buildRelationDropdown(),
                      const SizedBox(height: 20),

                      _buildLabel('Enter Mobile Number', optional: true),
                      const SizedBox(height: 8),
                      _buildMobileField(),
                      const SizedBox(height: 8),
                      _buildMobileHint(),
                      const SizedBox(height: 20),

                      _buildConfirmationCheckbox(),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.arrow_back, color: Color(0xFF1A1A2E)),
          ),
          const SizedBox(width: 12),
          Text(
            _isEditing ? 'Edit Member' : 'Add New Member',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Form fields
  // ---------------------------------------------------------------------------

  Widget _buildLabel(String text,
      {bool required = false, bool optional = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: Color(0xFF1A1A2E),
        ),
        children: [
          if (required)
            const TextSpan(
              text: ' *',
              style: TextStyle(color: Color(0xFFE91E8C)),
            ),
          if (optional)
            const TextSpan(
              text: ' (Optional)',
              style: TextStyle(
                color: Color(0xFF3D5AF1),
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameController,
      textCapitalization: TextCapitalization.words,
      decoration: _inputDecoration('Enter member name'),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Name is required' : null,
    );
  }

  /// Renders gender chips driven by [widget.genderOptions] (int ID + String label).
  Widget _buildGenderSelector() {
    return Row(
      children: widget.genderOptions.map((option) {
        final isSelected = _selectedGenderId == option.genderId;
        return Padding(
          padding: const EdgeInsets.only(right: 10),
          child: GestureDetector(
            onTap: () => setState(() => _selectedGenderId = option.genderId),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding:
                  const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFF3D5AF1)
                    : const Color(0xFFF0F1F8),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? const Color(0xFF3D5AF1)
                      : const Color(0xFFD0D3E8),
                ),
              ),
              child: Text(
                option.gender??"",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color:
                      isSelected ? Colors.white : const Color(0xFF6B7280),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDobField() {
    return TextFormField(
      controller: _dobController,
      readOnly: true,
      onTap: _pickDate,
      decoration: _inputDecoration('DD/MM/YYYY').copyWith(
        suffixIcon: GestureDetector(
          onTap: _pickDate,
          child: const Icon(Icons.calendar_today_outlined,
              color: Color(0xFF6B7280), size: 20),
        ),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Date of birth is required' : null,
    );
  }

  /// Dropdown driven by [widget.relationOptions] (int ID + String label).
  Widget _buildRelationDropdown() {
    return DropdownButtonFormField<int>(
      value: _selectedRelationId,
      items: widget.relationOptions
          .map((r) => DropdownMenuItem<int>(
                value: r.relationId,
                child: Text(r.relation??""),
              ))
          .toList(),
      onChanged: (val) => setState(() => _selectedRelationId = val),
      hint: const Text(
        'Select Relation',
        style: TextStyle(color: Color(0xFF9E9E9E)),
      ),
      decoration: _inputDecoration(''),
      validator: (v) => v == null ? 'Please select a relation' : null,
      icon:
          const Icon(Icons.keyboard_arrow_down, color: Color(0xFF6B7280)),
    );
  }

  Widget _buildMobileField() {
    return TextFormField(
      controller: _mobileController,
      keyboardType: TextInputType.phone,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: _inputDecoration('Enter Mobile Number'),
    );
  }

  Widget _buildMobileHint() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline, size: 16, color: Color(0xFF6B7280)),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'This number will be used to access your benefits and cannot be changed once verified.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {
            // TODO: trigger verify flow
          },
          child: const Text(
            'Verify Now',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmationCheckbox() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F6FA),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 22,
            height: 22,
            child: Checkbox(
              value: _isConfirmed,
              onChanged: (val) =>
                  setState(() => _isConfirmed = val ?? false),
              activeColor: const Color(0xFF3D5AF1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(4),
              ),
              side: const BorderSide(color: Color(0xFFB0B4D0)),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'I confirm that the above details provided by me are accurate. '
              "I acknowledge that it's my responsibility to provide correct "
              'and updated information for availing the benefits/services.',
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF4A4A6A),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Save button
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: _isConfirmed ? _onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3D5AF1),
            disabledBackgroundColor: const Color(0xFFB0B4D0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            _isEditing ? 'Update & Continue' : 'Save & Continue',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Shared input decoration
  // ---------------------------------------------------------------------------

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9E9E9E), fontSize: 14),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFFD0D3E8), width: 1.2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide:
            const BorderSide(color: Color(0xFF3D5AF1), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
