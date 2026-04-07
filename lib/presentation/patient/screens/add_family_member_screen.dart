import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/family_viewmodel.dart';

// ── Colour palette ────────────────────────────────────────────────
const kPrimary   = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg        = Color(0xFFF4F6FB);
const kTextDark  = Color(0xFF1F2937);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kRed       = Color(0xFFEA4335);
const kGreen     = Color(0xFF34A853);
const kCyan      = Color(0xFF06B6D4);
const kCyanBg    = Color(0xFFF0F9FF);
const kCyanBorder = Color(0xFFBAE6FD);

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
  final _formKey        = GlobalKey<FormState>();
  final _nameCtrl       = TextEditingController();
  final _mobileCtrl     = TextEditingController();
  final _dobCtrl        = TextEditingController();

  int?     _selectedGenderId;
  int?     _selectedRelationId;
  DateTime? _selectedDate;
  bool     _isConfirmed = false;
  bool     _didSubmit   = false;

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
    _nameCtrl.text   = m.memberName ?? '';
    _mobileCtrl.text = m.mobileNo   ?? '';
    _selectedGenderId   = m.genderId;
    _selectedRelationId = m.relationId;
    _isConfirmed = true;
    if (m.dob != null) {
      _selectedDate   = m.dob;
      _dobCtrl.text   = _fmtDate(m.dob!);
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
      '${d.day.toString().padLeft(2, '0')} / '
      '${d.month.toString().padLeft(2, '0')} / '
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
      .firstWhere((r) => r?.relationId == _selectedRelationId, orElse: () => null);

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
    if (_selectedGenderId == null) { _snack('Please select a gender.'); return; }
    if (_selectedDate    == null) { _snack('Please select a date of birth.'); return; }
    if (_selectedRelationId == null) { _snack('Please select a relation.'); return; }
    if (!_isConfirmed)            { _snack('Please confirm the details are accurate.'); return; }

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
      mobileNo:     _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
    );

    debugPrint('SUBMIT DATA: ${member.toJson()}');
    _didSubmit = true;
    ref.read(familyViewModelProvider.notifier).addFamilyMember(member);
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        backgroundColor: kTextDark,
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
      if (next.error != null && next.error != prev?.error) _snack(next.error!);
    });

    final state = ref.watch(familyViewModelProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildProgressBar(),
                      const SizedBox(height: 18),

                      // Name
                      _label('Member name', required: true),
                      const SizedBox(height: 6),
                      _nameField(),
                      const SizedBox(height: 16),

                      // Gender
                      _label('Gender', required: true),
                      const SizedBox(height: 8),
                      _genderChips(),
                      const SizedBox(height: 16),

                      // DOB
                      _label('Date of birth', required: true),
                      const SizedBox(height: 6),
                      _dobField(),
                      if (_selectedDate != null) ...[
                        const SizedBox(height: 4),
                        Text('Age: ${_calcAge(_selectedDate!)} years',
                            style: const TextStyle(
                                fontSize: 12, color: kCyan, fontWeight: FontWeight.w500)),
                      ],
                      const SizedBox(height: 16),

                      // Relation
                      _label('Relation', required: true),
                      const SizedBox(height: 6),
                      _relationDropdown(),
                      const SizedBox(height: 16),

                      // Mobile
                      _label('Mobile number', optional: true),
                      const SizedBox(height: 6),
                      _mobileField(),
                      const SizedBox(height: 8),
                      _mobileHint(),
                      const SizedBox(height: 16),

                      // Confirm
                      _confirmBox(),
                      const SizedBox(height: 20),
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
  // Header & progress
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: kPrimaryBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: kPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isEditing ? 'Edit member' : 'Add new member',
                style: const TextStyle(fontSize: 17,
                    fontWeight: FontWeight.w600, color: kTextDark),
              ),
              const Text('Fill in the details below',
                  style: TextStyle(fontSize: 12, color: kTextMid)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return Row(
      children: [
        _ProgStep(active: false, done: true),
        const SizedBox(width: 6),
        _ProgStep(active: true, done: false),
        const SizedBox(width: 6),
        _ProgStep(active: false, done: false),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Form fields
  // ---------------------------------------------------------------------------

  Widget _label(String text, {bool required = false, bool optional = false}) {
    return RichText(
      text: TextSpan(
        text: text,
        style: const TextStyle(fontSize: 13,
            fontWeight: FontWeight.w500, color: kTextDark),
        children: [
          if (required)
            const TextSpan(text: ' *',
                style: TextStyle(color: kRed, fontSize: 13)),
          if (optional)
            const TextSpan(text: '  (optional)',
                style: TextStyle(color: kPrimary,
                    fontSize: 12, fontWeight: FontWeight.w400)),
        ],
      ),
    );
  }

  InputDecoration _dec(String hint, {Widget? suffix}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    filled: true,
    fillColor: Colors.white,
    suffixIcon: suffix,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kBorder, width: 0.8),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kRed, width: 1),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: kRed, width: 1.5),
    ),
  );

  Widget _nameField() => TextFormField(
    controller: _nameCtrl,
    textCapitalization: TextCapitalization.words,
    style: const TextStyle(fontSize: 14, color: kTextDark),
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
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 9),
            decoration: BoxDecoration(
              color: sel ? kPrimary : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: sel ? kPrimary : kBorder,
                width: sel ? 1.5 : 0.8,
              ),
            ),
            child: Text(opt.gender ?? '',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: sel ? Colors.white : kTextMid,
                )),
          ),
        ),
      );
    }).toList(),
  );

  Widget _dobField() => TextFormField(
    controller: _dobCtrl,
    readOnly: true,
    onTap: _pickDate,
    style: const TextStyle(fontSize: 14, color: kTextDark),
    decoration: _dec(
      'DD / MM / YYYY',
      suffix: GestureDetector(
        onTap: _pickDate,
        child: const Padding(
          padding: EdgeInsets.all(10),
          child: Icon(Icons.calendar_today_outlined,
              size: 18, color: kTextMid),
        ),
      ),
    ),
    validator: (v) =>
        (v == null || v.trim().isEmpty) ? 'Date of birth is required' : null,
  );

  Widget _relationDropdown() => DropdownButtonFormField<int>(
    value: _selectedRelationId,
    decoration: _dec(''),
    icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMid),
    hint: const Text('Select relation',
        style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14)),
    style: const TextStyle(fontSize: 14, color: kTextDark),
    items: widget.relationOptions
        .map((r) => DropdownMenuItem<int>(
              value: r.relationId,
              child: Text(r.relation ?? ''),
            ))
        .toList(),
    onChanged: (val) => setState(() => _selectedRelationId = val),
    validator: (v) => v == null ? 'Please select a relation' : null,
  );

  Widget _mobileField() => TextFormField(
    controller: _mobileCtrl,
    keyboardType: TextInputType.phone,
    style: const TextStyle(fontSize: 14, color: kTextDark),
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(10),
    ],
    decoration: _dec('Enter 10-digit number'),
  );

  Widget _mobileHint() => Container(
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: kCyanBg,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kCyanBorder, width: 0.8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.info_outline_rounded, size: 15, color: Color(0xFF0891B2)),
        const SizedBox(width: 6),
        const Expanded(
          child: Text(
            'This number will be used to access your benefits and cannot be changed once verified.',
            style: TextStyle(fontSize: 12, color: Color(0xFF0C4A6E), height: 1.5),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () {}, // TODO: verify flow
          child: const Text('Verify now',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kPrimary,
                decoration: TextDecoration.underline,
              )),
        ),
      ],
    ),
  );

  Widget _confirmBox() => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder, width: 0.8),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 20, height: 20,
          child: Checkbox(
            value: _isConfirmed,
            onChanged: (v) => setState(() => _isConfirmed = v ?? false),
            activeColor: kPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
            side: const BorderSide(color: Color(0xFFD1D5DB)),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
        ),
        const SizedBox(width: 10),
        const Expanded(
          child: Text(
            'I confirm that the above details provided are accurate. '
            "I acknowledge it's my responsibility to provide correct "
            'and updated information for availing benefits/services.',
            style: TextStyle(fontSize: 12.5, color: Color(0xFF4B5563), height: 1.5),
          ),
        ),
      ],
    ),
  );

  // ---------------------------------------------------------------------------
  // Save button
  // ---------------------------------------------------------------------------

  Widget _saveButton({required bool isLoading}) {
    final enabled = _isConfirmed && !isLoading;
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton(
          onPressed: enabled ? _onSave : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            disabledBackgroundColor: const Color(0xFF93C5FD),
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          child: isLoading
              ? const SizedBox(
                  width: 22, height: 22,
                  child: CircularProgressIndicator(
                      strokeWidth: 2.5, color: Colors.white),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline_rounded, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      _isEditing ? 'Update & continue' : 'Save & continue',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Progress step widget
// ---------------------------------------------------------------------------

class _ProgStep extends StatelessWidget {
  final bool active;
  final bool done;
  const _ProgStep({required this.active, required this.done});

  @override
  Widget build(BuildContext context) {
    final color = done
        ? kPrimary
        : active
            ? kCyan
            : kBorder;
    return Expanded(
      child: Container(height: 3, decoration: BoxDecoration(
        color: color, borderRadius: BorderRadius.circular(2))),
    );
  }
}
