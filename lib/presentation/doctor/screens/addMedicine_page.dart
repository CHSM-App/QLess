import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

class AddMedicinePage extends ConsumerStatefulWidget {
  const AddMedicinePage({super.key});

  @override
  ConsumerState<AddMedicinePage> createState() => _AddMedicinePageState();
}

class _AddMedicinePageState extends ConsumerState<AddMedicinePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  Medicine? _selectedType;
  bool _isEnsuringDoctorId = false;

  static const _dark   = Color(0xFF0F172A);
  static const _slate  = Color(0xFF64748B);
  static const _muted  = Color(0xFF94A3B8);
  static const _bg     = Color(0xFFF1F5F9);
  static const _border = Color(0xFFE2E8F0);
  static const _red    = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    Future.microtask(
      () => ref
          .read(doctorLoginViewModelProvider.notifier)
          .fetchMedicineTypes(),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  // Future<void> _save() async {
  //   if (!(_formKey.currentState?.validate() ?? false)) return;
  //   if (_selectedType == null) {
  //     _snack('Please select a medicine type');
  //     return;
  //   }

  //   final loginState = ref.read(doctorLoginViewModelProvider);

  //   final medicine = Medicine(
  //     medicineName: _nameCtrl.text.trim(),
  //     medTypeId:      _selectedType!.medTypeId,   
  //     medTypeName:  _selectedType!.medTypeName,
  //     doctorId:   loginState.doctorId,
  //   );

  //   final response = await ref
  //       .read(doctorLoginViewModelProvider.notifier)
  //       .addMedicine(medicine);


  //    if (response['success'] == 1) {
  //   _snack('Medicine added successfully');
  // } else {
  //   _snack(response['message'] ?? 'Failed to add medicine');
  // }

  //   // Only pop if no error
  //   // final error = ref.read(doctorLoginViewModelProvider).error;
  //   // if (error == null && mounted) {
  //   //   Navigator.pop(context);
  //   // }
  // }

  Future<void> _save() async {
  if (!(_formKey.currentState?.validate() ?? false)) return;
  if (_selectedType == null) {
    _snack('Please select a medicine type');
    return;
  }

  final notifier = ref.read(doctorLoginViewModelProvider.notifier);
  var loginState = ref.read(doctorLoginViewModelProvider);
  var doctorId = loginState.doctorId ?? 0;
  if (doctorId == 0 && !_isEnsuringDoctorId) {
    _isEnsuringDoctorId = true;
    await notifier.loadFromStorage();
    loginState = ref.read(doctorLoginViewModelProvider);
    doctorId = loginState.doctorId ?? 0;
    _isEnsuringDoctorId = false;
  }
  if (doctorId == 0) {
    _snack('Doctor ID not found. Please login again.');
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
    // ── Reset form ──────────────────────────────────────
    _formKey.currentState?.reset();
    _nameCtrl.clear();
    setState(() => _selectedType = null);
    // ────────────────────────────────────────────────────

    _snack('Medicine added successfully');

    // Wait for snackbar then go back with true (signals list to refresh)
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) Navigator.pop(context, true); // ← pass true
  } else {
    _snack(response['message'] ?? 'Failed to add medicine');
  }
}


  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: const Color.fromARGB(255, 28, 129, 42),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSaving = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.isLoading),
    );
    final typesAsync = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.medicineTypes),
    );

    // Show snack on any save error
    ref.listen(
      doctorLoginViewModelProvider.select((s) => s.error),
      (_, error) {
        if (error != null) _snack(error);
      },
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: _dark,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Medicine',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: _dark,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: _border),
        ),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Header banner ──────────────────────────────
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _dark,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.medication_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'New Medicine',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Add to your medicine library',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white60,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── Medicine Name ──────────────────────────────
              const _FieldLabel(label: 'Medicine Name *'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                style: const TextStyle(fontSize: 14, color: _dark),
                decoration: _decor(
                  hint: 'e.g. Paracetamol',
                  icon: Icons.medication_outlined,
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'Medicine name is required'
                    : null,
              ),

              const SizedBox(height: 18),

              // ── Medicine Type ──────────────────────────────
              const _FieldLabel(label: 'Medicine Type *'),
              const SizedBox(height: 8),

              // null = fetch not yet started (microtask pending)
              if (typesAsync == null)
                const SizedBox(
                  height: 44,
                  child: Center(
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                typesAsync.when(
                  // ── Loading skeleton ─────────────────────
                  loading: () => Row(
                    children: List.generate(
                      4,
                      (i) => Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(right: i == 3 ? 0 : 8),
                          child: Container(
                            height: 44,
                            decoration: BoxDecoration(
                              color: _bg,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(color: _border),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ── Error + retry ────────────────────────
                  error: (e, _) => Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: const Color(0xFFFECACA)),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          color: _red,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Failed to load types',
                            style: TextStyle(fontSize: 13, color: _red),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref
                              .read(doctorLoginViewModelProvider.notifier)
                              .fetchMedicineTypes(),
                          child: const Text(
                            'Retry',
                            style: TextStyle(
                              fontSize: 12,
                              color: _red,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ── Type chips from DB ───────────────────
                //   data: (types) => types.isEmpty
                //       ? const Text(
                //           'No medicine types available.',
                //           style: TextStyle(
                //             fontSize: 13,
                //             color: _muted,
                //           ),
                //         )
                //       : Wrap(
                //           spacing: 8,
                //           runSpacing: 8,
                //           children: types.map((type) {
                //             // Compare by medType ID (API now returns it)
                //             // Fall back to name comparison if ID is null
                //             final sel = type.medTypeId != null
                //                 ? _selectedType?.medTypeId == type.medTypeId
                //                 : _selectedType?.medTypeName ==
                //                     type.medTypeName;

                //             return GestureDetector(
                //               onTap: () =>
                //                   setState(() => _selectedType = type),
                //               child: AnimatedContainer(
                //                 duration:
                //                     const Duration(milliseconds: 180),
                //                 height: 44,
                //                 padding: const EdgeInsets.symmetric(
                //                     horizontal: 20),
                //                 decoration: BoxDecoration(
                //                   color: sel ? _dark : Colors.white,
                //                   borderRadius: BorderRadius.circular(11),
                //                   border: Border.all(
                //                     color: sel ? _dark : _border,
                //                     width: sel ? 1.8 : 1,
                //                   ),
                //                 ),
                //                 child: Center(
                //                   child: Text(
                //                     type.medTypeName ?? '—',
                //                     style: TextStyle(
                //                       fontSize: 13,
                //                       fontWeight: sel
                //                           ? FontWeight.w700
                //                           : FontWeight.w500,
                //                       color:
                //                           sel ? Colors.white : _slate,
                //                     ),
                //                   ),
                //                 ),
                //               ),
                //             );
                //           }).toList(),
                //         ),
                // ),
              data: (types) => types.isEmpty
    ? const Text(
        'No medicine types available.',
        style: TextStyle(fontSize: 13, color: _muted),
      )
    : LayoutBuilder(
        builder: (context, constraints) {
          final screenWidth = constraints.maxWidth;

          // 👇 Adjust min width based on device
          final minItemWidth = screenWidth > 600 ? 140.0 : 100.0;

          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: types.map((type) {
              final sel = type.medTypeId != null
                  ? _selectedType?.medTypeId == type.medTypeId
                  : _selectedType?.medTypeName == type.medTypeName;

              return ConstrainedBox(
                constraints: BoxConstraints(
                  minWidth: minItemWidth,
                  maxWidth: screenWidth / 2 - 12, // max 2 per row if long text
                ),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedType = type),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? _dark : Colors.white,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: sel ? _dark : _border,
                        width: sel ? 1.8 : 1,
                      ),
                    ),
                    child: Text(
                      type.medTypeName ?? '—',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : _slate,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
                ),

              const SizedBox(height: 32),

              // ── Save button ────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: isSaving ? null : _save,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _dark,
                    disabledBackgroundColor: _dark.withOpacity(0.5),
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor:
                                AlwaysStoppedAnimation(Colors.white),
                          ),
                        )
                      : const Text(
                          'Save Medicine',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static InputDecoration _decor({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: _muted, fontSize: 14),
      prefixIcon: Icon(icon, color: _muted, size: 20),
      filled: true,
      fillColor: _bg,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _dark, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _red, width: 1.8),
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16),
      errorStyle: const TextStyle(fontSize: 11.5, color: _red),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: Color(0xFF0F172A),
      ),
    );
  }
}
