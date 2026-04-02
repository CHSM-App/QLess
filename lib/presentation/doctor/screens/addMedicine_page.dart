

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ─── Constants ───────────────────────────────────────────────────────────────
const kPrimaryBlue = Color(0xFF1A73E8);
const kLightBlue   = Color(0xFFE8F0FE);
const kAccentGreen = Color(0xFF34A853);
const kRedAccent   = Color(0xFFEA4335);
const kSurface     = Color(0xFFF8F9FA);
const kCardBg      = Color(0xFFFFFFFF);
const kTextDark    = Color(0xFF1F2937);
const kTextMuted   = Color(0xFF6B7280);
const kDivider     = Color(0xFFE5E7EB);

class AddMedicinePage extends ConsumerStatefulWidget {
  const AddMedicinePage({super.key});

  @override
  ConsumerState<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends ConsumerState<AddMedicinePage>
    with SingleTickerProviderStateMixin {
  final _formKey  = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  Medicine? _selectedType;
  bool _isEnsuringDoctorId = false;

  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end:   Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    Future.microtask(
      () => ref
          .read(doctorLoginViewModelProvider.notifier)
          .fetchMedicineTypes(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ─── Save ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_selectedType == null) {
      _snack('Please select a medicine type', isError: true);
      return;
    }

    final notifier   = ref.read(doctorLoginViewModelProvider.notifier);
    var   loginState = ref.read(doctorLoginViewModelProvider);
    var   doctorId   = loginState.doctorId ?? 0;

    if (doctorId == 0 && !_isEnsuringDoctorId) {
      _isEnsuringDoctorId = true;
      await notifier.loadFromStorage();
      loginState = ref.read(doctorLoginViewModelProvider);
      doctorId   = loginState.doctorId ?? 0;
      _isEnsuringDoctorId = false;
    }

    if (doctorId == 0) {
      _snack('Doctor ID not found. Please login again.', isError: true);
      return;
    }

    final medicine = Medicine(
      medicineName: _nameCtrl.text.trim(),
      medTypeId:    _selectedType!.medTypeId,
      medTypeName:  _selectedType!.medTypeName,
      doctorId:     doctorId,
    );

    final response = await ref
        .read(doctorLoginViewModelProvider.notifier)
        .addMedicine(medicine);

    if (response['success'] == 1) {
      _formKey.currentState?.reset();
      _nameCtrl.clear();
      setState(() => _selectedType = null);
      _snack('Medicine added successfully');
      await Future.delayed(const Duration(milliseconds: 900));
      if (mounted) Navigator.pop(context, true);
    } else {
      _snack(response['message'] ?? 'Failed to add medicine', isError: true);
    }
  }

  // ─── Snackbar ─────────────────────────────────────────────────────
  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(
                isError
                    ? Icons.error_outline_rounded
                    : Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 18,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  msg,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          backgroundColor: isError ? kRedAccent : kAccentGreen,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ─── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.isLoading),
    );
    final typesAsync = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.medicineTypes),
    );

    ref.listen(
      doctorLoginViewModelProvider.select((s) => s.error),
      (_, error) {
        if (error != null) _snack(error, isError: true);
      },
    );

    return Scaffold(
      backgroundColor: kSurface,
      appBar: _buildAppBar(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeroBanner(),
                  const SizedBox(height: 24),
                  _buildSectionCard(
                    children: [
                      _buildFieldLabel('Medicine Name', isRequired: true),
                      const SizedBox(height: 10),
                      _buildNameField(),
                      const SizedBox(height: 22),
                      Container(height: 1, color: kDivider),
                      const SizedBox(height: 22),
                      _buildFieldLabel('Medicine Type', isRequired: true),
                      const SizedBox(height: 10),
                      _buildTypeSelector(typesAsync),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildSaveButton(isSaving),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardBg,
      elevation: 0,
      centerTitle: true,
      scrolledUnderElevation: 1,
      shadowColor: kDivider,
      leading: _BackButton(),
      title: const Text(
        'Add Medicine',
        style: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: kTextDark,
          letterSpacing: -0.3,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: kDivider),
      ),
    );
  }

  // ─── Hero banner ──────────────────────────────────────────────────
  Widget _buildHeroBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1A73E8), Color(0xFF4D9EFF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: kPrimaryBlue.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: Colors.white,
              size: 26,
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'New Medicine',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                SizedBox(height: 3),
                Text(
                  'Add to your medicine library',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text(
              'NEW',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 1.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Section card ─────────────────────────────────────────────────
  Widget _buildSectionCard({required List<Widget> children}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kDivider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  // ─── Field label ──────────────────────────────────────────────────
  Widget _buildFieldLabel(String label, {bool isRequired = false}) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: kTextDark,
            letterSpacing: -0.1,
          ),
        ),
        if (isRequired) ...[
          const SizedBox(width: 5),
          Container(
            width: 6,
            height: 6,
            decoration: const BoxDecoration(
              color: kPrimaryBlue,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }

  // ─── Name field ───────────────────────────────────────────────────
  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtrl,
      textCapitalization: TextCapitalization.words,
      style: const TextStyle(
        fontSize: 14,
        color: kTextDark,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'e.g. Paracetamol',
        hintStyle: const TextStyle(color: kTextMuted, fontSize: 14),
        prefixIcon: Container(
          margin: const EdgeInsets.only(left: 14, right: 10),
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: kLightBlue,
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(
            Icons.medication_outlined,
            color: kPrimaryBlue,
            size: 18,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 56),
        filled: true,
        fillColor: kSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kDivider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kDivider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kPrimaryBlue, width: 1.8),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kRedAccent),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: kRedAccent, width: 1.8),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16),
        errorStyle: const TextStyle(fontSize: 11.5, color: kRedAccent),
      ),
      validator: (v) =>
          (v == null || v.trim().isEmpty) ? 'Medicine name is required' : null,
    );
  }

  // ─── Type selector ────────────────────────────────────────────────
  Widget _buildTypeSelector(dynamic typesAsync) {
    if (typesAsync == null) {
      return const SizedBox(
        height: 48,
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: kPrimaryBlue,
          ),
        ),
      );
    }

    if (typesAsync is AsyncValue<List<Medicine>>) {
      return typesAsync.when(
        loading: _buildTypeLoading,
        error:   (e, _) => _buildTypeError(),
        data:    (types) => _buildTypeList(types),
      );
    }

    if (typesAsync is List<Medicine>) {
      return _buildTypeList(typesAsync);
    }

    return _buildTypeError();
  }

  Widget _buildTypeLoading() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: List.generate(
        4,
        (_) => Container(
          width: 88,
          height: 40,
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kDivider),
          ),
        ),
      ),
    );
  }

  Widget _buildTypeError() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0F0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: kRedAccent, size: 17),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Failed to load types',
              style: TextStyle(fontSize: 13, color: kRedAccent),
            ),
          ),
          GestureDetector(
            onTap: () => ref
                .read(doctorLoginViewModelProvider.notifier)
                .fetchMedicineTypes(),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: kRedAccent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeList(List<Medicine> types) {
    if (types.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kDivider),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline_rounded, color: kTextMuted, size: 16),
            SizedBox(width: 8),
            Text(
              'No medicine types available.',
              style: TextStyle(fontSize: 13, color: kTextMuted),
            ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final w            = constraints.maxWidth;
        final minItemWidth = w > 600 ? 140.0 : 96.0;

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: types.map<Widget>((type) {
            final sel = type.medTypeId != null
                ? _selectedType?.medTypeId == type.medTypeId
                : _selectedType?.medTypeName == type.medTypeName;

            return GestureDetector(
              onTap: () => setState(() => _selectedType = type),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                constraints: BoxConstraints(
                  minWidth: minItemWidth,
                  maxWidth: w / 2 - 12,
                ),
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? kPrimaryBlue : kSurface,
                  borderRadius: BorderRadius.circular(11),
                  border: Border.all(
                    color: sel ? kPrimaryBlue : kDivider,
                    width: sel ? 1.8 : 1,
                  ),
                  boxShadow: sel
                      ? [
                          BoxShadow(
                            color: kPrimaryBlue.withOpacity(0.22),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : [],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (sel) ...[
                      const Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 5),
                    ],
                    Flexible(
                      child: Text(
                        type.medTypeName ?? '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight:
                              sel ? FontWeight.w700 : FontWeight.w500,
                          color: sel ? Colors.white : kTextMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  // ─── Save button ──────────────────────────────────────────────────
  Widget _buildSaveButton(bool isSaving) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: isSaving ? null : _save,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          disabledBackgroundColor: kPrimaryBlue.withOpacity(0.45),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ).copyWith(
          overlayColor: MaterialStateProperty.resolveWith(
            (states) => states.contains(MaterialState.pressed)
                ? Colors.white.withOpacity(0.12)
                : null,
          ),
        ),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: isSaving
              ? const SizedBox(
                  key: ValueKey('loading'),
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                )
              : const Row(
                  key: ValueKey('label'),
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.save_rounded, color: Colors.white, size: 19),
                    SizedBox(width: 9),
                    Text(
                      'Save Medicine',
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Back button ──────────────────────────────────────────────────────────────
class _BackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(10),
        child: Container(
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kDivider),
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 16,
            color: kTextDark,
          ),
        ),
      ),
    );
  }
}