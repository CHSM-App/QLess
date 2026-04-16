import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/family_viewmodel.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF2BB5A0);
const kPrimaryLight  = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder        = Color(0xFFEDF2F7);
const kError         = Color(0xFFFC8181);
const kRedLight      = Color(0xFFFEE2E2);
const kInfo          = Color(0xFF3B82F6);
const kInfoLight     = Color(0xFFDBEAFE);
const kWarning       = Color(0xFFF6AD55);
const kAmberLight    = Color(0xFFFEF3C7);

// =============================================================================
// Screen
// =============================================================================

class AddFamilyMemberScreen extends ConsumerStatefulWidget {
  final FamilyMember?       existingMember;
  final List<GenderModel>   genderOptions;
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
      RelationModel(relationId: 1, relation: 'Parent'),
      RelationModel(relationId: 2, relation: 'Spouse'),
      RelationModel(relationId: 3, relation: 'Child'),
      RelationModel(relationId: 4, relation: 'Sibling'),
      RelationModel(relationId: 5, relation: 'Parent-in-law'),
      RelationModel(relationId: 6, relation: 'Partner'),
      RelationModel(relationId: 7, relation: 'Grandparent'),
      RelationModel(relationId: 8, relation: 'Other'),
    ],
  });

  @override
  ConsumerState<AddFamilyMemberScreen> createState() =>
      _AddFamilyMemberScreenState();
}

class _AddFamilyMemberScreenState
    extends ConsumerState<AddFamilyMemberScreen> {
  final _formKey    = GlobalKey<FormState>();
  final _nameCtrl   = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _dobCtrl    = TextEditingController();

  int?      _selectedGenderId;
  int?      _selectedRelationId;
  DateTime? _selectedDate;
  bool      _isConfirmed = false;
  bool      _didSubmit   = false;

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
    _nameCtrl.text      = m.memberName ?? '';
    _mobileCtrl.text    = m.mobileNo   ?? '';
    _selectedGenderId   = m.genderId;
    _selectedRelationId = m.relationId;
    _isConfirmed        = true;
    if (m.dob != null) {
      _selectedDate = m.dob;
      _dobCtrl.text = _fmtDate(m.dob!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mobileCtrl.dispose();
    _dobCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';

  int _calcAge(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  GenderModel? get _selGender => widget.genderOptions
      .cast<GenderModel?>()
      .firstWhere((g) => g?.genderId == _selectedGenderId, orElse: () => null);

  RelationModel? get _selRelation => widget.relationOptions
      .cast<RelationModel?>()
      .firstWhere((r) => r?.relationId == _selectedRelationId,
          orElse: () => null);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(1990, 1, 1),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(primary: kPrimary),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dobCtrl.text = _fmtDate(picked);
      });
    }
  }

  void _onSave() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedGenderId == null)  { _snack('Please select a gender.');        return; }
    if (_selectedDate == null)       { _snack('Please select date of birth.');   return; }
    if (_selectedRelationId == null) { _snack('Please select a relation.');      return; }
    if (!_isConfirmed)               { _snack('Please confirm the details.');    return; }

    final patientId = ref.read(patientLoginViewModelProvider).patientId;
    if (patientId == null || patientId == 0) {
      _snack('Unable to find patient ID. Please login again.');
      return;
    }

    final member = FamilyMember(
      memberId:     widget.existingMember?.memberId,
      familyId:     patientId,
      memberName:   _nameCtrl.text.trim(),
      genderId:     _selectedGenderId,
      genderName:   _selGender?.gender,
      dob:          _selectedDate,
      relationId:   _selectedRelationId,
      relationName: _selRelation?.relation,
      mobileNo:     _mobileCtrl.text.trim().isEmpty
          ? null
          : _mobileCtrl.text.trim(),
    );

    _didSubmit = true;
    ref.read(familyViewModelProvider.notifier).addFamilyMember(member);
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              size: 15,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg,
                  style: const TextStyle(fontSize: 13, color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    ref.listen<FamilyState>(familyViewModelProvider, (prev, next) {
      if (_didSubmit && next.isSuccess && !(prev?.isSuccess ?? false)) {
        _snack(_isEditing
            ? 'Member updated successfully'
            : 'Member added successfully');
        final result = FamilyMember(
          familyId:     ref.read(patientLoginViewModelProvider).patientId!,
          memberId:     widget.existingMember?.memberId,
          memberName:   _nameCtrl.text.trim(),
          genderId:     _selectedGenderId,
          genderName:   _selGender?.gender,
          dob:          _selectedDate,
          relationId:   _selectedRelationId,
          relationName: _selRelation?.relation,
          mobileNo:     _mobileCtrl.text.trim().isEmpty
              ? null
              : _mobileCtrl.text.trim(),
        );
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!mounted) return;
          Navigator.of(context).pop(result);
        });
      }
      if (next.error != null && next.error != prev?.error) {
        _snack(next.error!, isError: true);
      }
    });

    final state = ref.watch(familyViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Progress
                      _buildProgressBar(),
                      const SizedBox(height: 16),

                      // ── Name ──────────────────────────────────────
                      _label('Full Name', required: true),
                      const SizedBox(height: 5),
                      _nameField(),
                      const SizedBox(height: 13),

                      // ── Gender ────────────────────────────────────
                      _label('Gender', required: true),
                      const SizedBox(height: 6),
                      _genderChips(),
                      const SizedBox(height: 13),

                      // ── DOB + Relation row ────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Date of Birth', required: true),
                                const SizedBox(height: 5),
                                _dobField(),
                                if (_selectedDate != null) ...[
                                  const SizedBox(height: 3),
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: kPrimaryLight,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          '${_calcAge(_selectedDate!)} yrs',
                                          style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: kPrimary),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            flex: 5,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _label('Relation', required: true),
                                const SizedBox(height: 5),
                                _relationDropdown(),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 13),

                      // ── Mobile ────────────────────────────────────
                      _label('Mobile Number', optional: true),
                      const SizedBox(height: 5),
                      _mobileField(),
                      const SizedBox(height: 7),
                      _mobileHint(),
                      const SizedBox(height: 13),

                      // ── Confirm ───────────────────────────────────
                      _confirmBox(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            ),
            _saveButton(isLoading: state.isLoading),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Header
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 15, color: kPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit Member' : 'Add New Member',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                    letterSpacing: -0.2),
              ),
              const Text(
                'Fill in the details below',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        _ProgStep(done: true,  active: false),
        const SizedBox(width: 5),
        _ProgStep(done: false, active: true),
        const SizedBox(width: 5),
        _ProgStep(done: false, active: false),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Form helpers
  // ---------------------------------------------------------------------------

  Widget _label(String text,
      {bool required = false, bool optional = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: kTextPrimary),
        children: [
          if (required)
            const TextSpan(
                text: ' *',
                style: TextStyle(color: kError, fontSize: 12)),
          if (optional)
            const TextSpan(
                text: '  optional',
                style: TextStyle(
                    color: kTextMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder, width: 1),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kError, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kError, width: 1.5),
    ),
    errorStyle: const TextStyle(fontSize: 11, color: kError),
  );

  Widget _nameField() => TextFormField(
    controller: _nameCtrl,
    textCapitalization: TextCapitalization.words,
    style: const TextStyle(fontSize: 14, color: kTextPrimary),
    decoration: _dec('Enter full name'),
    validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Name is required' : null,
  );

  Widget _genderChips() => Row(
    children: widget.genderOptions.map((opt) {
      final sel = _selectedGenderId == opt.genderId;
      return Padding(
        padding: const EdgeInsets.only(right: 8),
        child: GestureDetector(
          onTap: () => setState(() => _selectedGenderId = opt.genderId),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: sel ? kPrimary : Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: sel ? kPrimary : kBorder,
                width: sel ? 1.5 : 1,
              ),
            ),
            child: Text(
              opt.gender ?? '',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: sel ? Colors.white : kTextSecondary,
              ),
            ),
          ),
        ),
      );
    }).toList(),
  );

  Widget _dobField() => TextFormField(
    controller: _dobCtrl,
    readOnly: true,
    onTap: _pickDate,
    style: const TextStyle(fontSize: 13, color: kTextPrimary),
    decoration: _dec(
      'DD/MM/YYYY',
      suffix: GestureDetector(
        onTap: _pickDate,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.calendar_month_outlined,
              size: 17, color: kTextMuted),
        ),
      ),
    ),
    validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Required' : null,
  );

  Widget _relationDropdown() => DropdownButtonFormField<int>(
    value: _selectedRelationId,
    decoration: _dec(''),
    isExpanded: true,
    icon: const Icon(Icons.keyboard_arrow_down_rounded,
        size: 18, color: kTextMuted),
    hint: const Text('Select',
        style: TextStyle(color: kTextMuted, fontSize: 13)),
    style: const TextStyle(fontSize: 13, color: kTextPrimary),
    dropdownColor: Colors.white,
    borderRadius: BorderRadius.circular(12),
    items: widget.relationOptions
        .map((r) => DropdownMenuItem<int>(
              value: r.relationId,
              child: Text(r.relation ?? ''),
            ))
        .toList(),
    onChanged: (val) => setState(() => _selectedRelationId = val),
    validator: (v) => v == null ? 'Required' : null,
  );

  Widget _mobileField() => TextFormField(
    controller: _mobileCtrl,
    keyboardType: TextInputType.phone,
    style: const TextStyle(fontSize: 14, color: kTextPrimary),
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ],
    decoration: _dec('10-digit mobile number'),
  );

  Widget _mobileHint() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: kInfoLight.withOpacity(0.4),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: kInfoLight, width: 1),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 13, color: kInfo),
        const SizedBox(width: 6),
        Expanded(
          child: const Text(
            'This number will be used to access benefits and cannot be changed once verified.',
            style: TextStyle(
                fontSize: 11, color: kInfo, height: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {},
          child: const Text(
            'Verify',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kPrimary,
                decoration: TextDecoration.underline,
                decorationColor: kPrimary),
          ),
        ),
      ],
    ),
  );

  Widget _confirmBox() => GestureDetector(
    onTap: () => setState(() => _isConfirmed = !_isConfirmed),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: _isConfirmed ? kPrimaryLight.withOpacity(0.5) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: _isConfirmed ? kPrimary : kBorder,
          width: _isConfirmed ? 1.5 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 18,
            height: 18,
            child: Checkbox(
              value: _isConfirmed,
              onChanged: (v) => setState(() => _isConfirmed = v ?? false),
              activeColor: kPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4)),
              side: const BorderSide(color: kTextMuted),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              visualDensity: VisualDensity.compact,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'I confirm the details provided are accurate and acknowledge my responsibility to provide correct information for availing benefits/services.',
              style: TextStyle(
                  fontSize: 11.5,
                  color: kTextSecondary,
                  height: 1.55),
            ),
          ),
        ],
      ),
    ),
  );

  // ---------------------------------------------------------------------------
  // Save button
  // ---------------------------------------------------------------------------

  Widget _saveButton({required bool isLoading}) {
    final enabled = _isConfirmed && !isLoading;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton(
          onPressed: enabled ? _onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            disabledBackgroundColor: kPrimaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 17),
                    const SizedBox(width: 6),
                    Text(
                      _isEditing ? 'Update & Continue' : 'Save & Continue',
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// =============================================================================
// Progress step
// =============================================================================

class _ProgStep extends StatelessWidget {
  final bool active;
  final bool done;
  const _ProgStep({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? kPrimary
        : active
            ? kPrimary.withOpacity(0.4)
            : kBorder;
    return Expanded(
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}