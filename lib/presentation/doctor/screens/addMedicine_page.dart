import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess  = Color(0xFF68D391);

// ════════════════════════════════════════════════════════════════════
//  ADD MEDICINE PAGE
// ════════════════════════════════════════════════════════════════════
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

  late final AnimationController _animCtrl;
  late final Animation<double>   _fadeAnim;
  late final Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 420));
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.05), end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();

    Future.microtask(
        () => ref.read(doctorLoginViewModelProvider.notifier).fetchMedicineTypes());
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

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
      await Future.delayed(const Duration(milliseconds: 800));
      if (mounted) Navigator.pop(context, true);
    } else {
      _snack(response['message'] ?? 'Failed to add medicine', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Row(children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(msg,
                style: const TextStyle(fontSize: 13, color: Colors.white))),
          ]),
          backgroundColor: isError ? kError : kPrimary,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 3),
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isSaving   = ref.watch(
        doctorLoginViewModelProvider.select((s) => s.isLoading));
    final typesAsync = ref.watch(
        doctorLoginViewModelProvider.select((s) => s.medicineTypes));

    ref.listen(doctorLoginViewModelProvider.select((s) => s.error), (_, error) {
      if (error != null) _snack(error, isError: true);
    });

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: kPrimary),
          ),
        ),
        title: const Text('Add Medicine',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                letterSpacing: -0.2)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: kBorder),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: SlideTransition(
          position: _slideAnim,
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 16, 14, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _heroBanner(),
                  const SizedBox(height: 16),
                  _sectionCard(children: [
                    _fieldLabel('Medicine Name', isRequired: true),
                    const SizedBox(height: 8),
                    _nameField(),
                    const SizedBox(height: 16),
                    const Divider(height: 1, color: kDivider),
                    const SizedBox(height: 16),
                    _fieldLabel('Medicine Type', isRequired: true),
                    const SizedBox(height: 8),
                    _typeSelector(typesAsync),
                  ]),
                  const SizedBox(height: 18),
                  _saveButton(isSaving),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Hero Banner
  // ---------------------------------------------------------------------------

  Widget _heroBanner() => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [kPrimary, kPrimaryDark],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: kPrimary.withOpacity(0.25),
                blurRadius: 14,
                offset: const Offset(0, 6)),
          ],
        ),
        child: Row(children: [
          Container(
            width: 46, height: 46,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.medication_rounded,
                color: Colors.white, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Medicine',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white)),
                SizedBox(height: 2),
                Text('Add to your medicine library',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Text('NEW',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 1.0)),
          ),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Section Card
  // ---------------------------------------------------------------------------

  Widget _sectionCard({required List<Widget> children}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );

  // ---------------------------------------------------------------------------
  // Field Label
  // ---------------------------------------------------------------------------

  Widget _fieldLabel(String label, {bool isRequired = false}) => Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
                letterSpacing: 0.2)),
        if (isRequired) ...[
          const SizedBox(width: 4),
          Container(
            width: 5, height: 5,
            decoration: const BoxDecoration(
                color: kPrimary, shape: BoxShape.circle),
          ),
        ],
      ]);

  // ---------------------------------------------------------------------------
  // Name Field
  // ---------------------------------------------------------------------------

  Widget _nameField() => TextFormField(
        controller: _nameCtrl,
        textCapitalization: TextCapitalization.words,
        style: const TextStyle(
            fontSize: 13, color: kTextPrimary, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'e.g. Paracetamol',
          hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
          prefixIcon: Container(
            margin: const EdgeInsets.fromLTRB(12, 0, 8, 0),
            width: 32, height: 32,
            decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.medication_outlined,
                color: kPrimary, size: 16),
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 52),
          filled: true,
          fillColor: const Color(0xFFF7F8FA),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimary, width: 1.5)),
          errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kError)),
          focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kError, width: 1.5)),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          errorStyle: const TextStyle(fontSize: 11, color: kError),
        ),
        validator: (v) =>
            (v == null || v.trim().isEmpty) ? 'Medicine name is required' : null,
      );

  // ---------------------------------------------------------------------------
  // Type Selector
  // ---------------------------------------------------------------------------

  Widget _typeSelector(dynamic typesAsync) {
    if (typesAsync == null) return _typeLoading();

    if (typesAsync is AsyncValue<List<Medicine>>) {
      return typesAsync.when(
        loading: _typeLoading,
        error: (_, __) => _typeError(),
        data: (types) => _typeList(types),
      );
    }
    if (typesAsync is List<Medicine>) return _typeList(typesAsync);
    return _typeError();
  }

  Widget _typeLoading() => Wrap(
        spacing: 8, runSpacing: 8,
        children: List.generate(4, (_) => Container(
          width: 80, height: 36,
          decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder)),
        )),
      );

  Widget _typeError() => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: kRedLight.withOpacity(0.5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kError.withOpacity(0.3)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded, color: kError, size: 15),
          const SizedBox(width: 8),
          const Expanded(child: Text('Failed to load types',
              style: TextStyle(fontSize: 12, color: kError))),
          GestureDetector(
            onTap: () => ref.read(doctorLoginViewModelProvider.notifier)
                .fetchMedicineTypes(),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                  color: kError,
                  borderRadius: BorderRadius.circular(7)),
              child: const Text('Retry',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
        ]),
      );

  Widget _typeList(List<Medicine> types) {
    if (types.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: const Color(0xFFF7F8FA),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder)),
        child: const Row(children: [
          Icon(Icons.info_outline_rounded, color: kTextMuted, size: 15),
          SizedBox(width: 8),
          Text('No medicine types available.',
              style: TextStyle(fontSize: 12, color: kTextMuted)),
        ]),
      );
    }

    return LayoutBuilder(builder: (_, constraints) {
      final w           = constraints.maxWidth;
      final minItemWidth = w > 600 ? 130.0 : 88.0;

      return Wrap(
        spacing: 8, runSpacing: 8,
        children: types.map<Widget>((type) {
          final sel = type.medTypeId != null
              ? _selectedType?.medTypeId == type.medTypeId
              : _selectedType?.medTypeName == type.medTypeName;

          return GestureDetector(
            onTap: () => setState(() => _selectedType = type),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              constraints: BoxConstraints(
                  minWidth: minItemWidth, maxWidth: w / 2 - 12),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: sel ? kPrimary : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: sel ? kPrimary : kBorder,
                    width: sel ? 1.5 : 1),
                boxShadow: sel
                    ? [BoxShadow(
                        color: kPrimary.withOpacity(0.2),
                        blurRadius: 6, offset: const Offset(0, 2))]
                    : [],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (sel) ...[
                    const Icon(Icons.check_rounded,
                        size: 13, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Flexible(
                    child: Text(type.medTypeName ?? '—',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sel ? Colors.white : kTextSecondary)),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      );
    });
  }

  // ---------------------------------------------------------------------------
  // Save Button
  // ---------------------------------------------------------------------------

  Widget _saveButton(bool isSaving) => SizedBox(
        width: double.infinity, height: 48,
        child: ElevatedButton(
          onPressed: isSaving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            disabledBackgroundColor: kPrimaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isSaving
                ? const SizedBox(
                    key: ValueKey('loading'),
                    width: 20, height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: Colors.white))
                : const Row(
                    key: ValueKey('label'),
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, color: Colors.white, size: 17),
                      SizedBox(width: 7),
                      Text('Save Medicine',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: Colors.white)),
                    ],
                  ),
          ),
        ),
      );
}