import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';


// ════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS
// ════════════════════════════════════════════════════════════════════
const kPrimary = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg = Color(0xFFF8F9FA);
const kCardBg = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid = Color(0xFF6B7280);
const kBorder = Color(0xFFE5E7EB);
const kRed = Color(0xFFEA4335);
const kGreen = Color(0xFF34A853);

// ════════════════════════════════════════════════════════════════════
//  MEDICINE TYPE
// ════════════════════════════════════════════════════════════════════
enum MedicineType { tablet, syrup, injection, drops, lotion, spray }

extension MedTypeX on MedicineType {
  String get label => const {
    MedicineType.tablet: 'Tablet',
    MedicineType.syrup: 'Syrup',
    MedicineType.injection: 'Injection',
    MedicineType.drops: 'Drops',
    MedicineType.lotion: 'Lotion',
    MedicineType.spray: 'Spray',
  }[this]!;

  IconData get icon => const {
    MedicineType.tablet: Icons.medication_rounded,
    MedicineType.syrup: Icons.local_drink_rounded,
    MedicineType.injection: Icons.vaccines_rounded,
    MedicineType.drops: Icons.water_drop_rounded,
    MedicineType.lotion: Icons.soap_rounded,
    MedicineType.spray: Icons.air_rounded,
  }[this]!;

  Color get color => const {
    MedicineType.tablet: Color(0xFF2B7FFF),
    MedicineType.syrup: Color(0xFF8B5CF6),
    MedicineType.injection: Color(0xFFEF4444),
    MedicineType.drops: Color(0xFF06B6D4),
    MedicineType.lotion: Color(0xFF10B981),
    MedicineType.spray: Color(0xFFF59E0B),
  }[this]!;

  // Maps enum index to DB medicine_type_id
  int get typeId => index + 1;
}

class MedicineEntry {
  MedicineType type;
  int? medicineId;
  String? selectedName;
  String searchText;
  String frequency;
  String duration;
  String timing;
  String tabletDosage;
  String syrupDosageMl;
  String injDosage;
  String injRoute;
  String dropsCount;
  String dropsApplication;
  String lotionApplyArea;
  String sprayPuffs;
  String sprayUsage;

  MedicineEntry()
    : type = MedicineType.tablet,
      medicineId = null,
      selectedName = null,
      searchText = '',
      frequency = '1-0-1',
      duration = '',
      timing = 'After Food',
      tabletDosage = '',
      syrupDosageMl = '',
      injDosage = '',
      injRoute = 'IV',
      dropsCount = '',
      dropsApplication = 'Eyes',
      lotionApplyArea = '',
      sprayPuffs = '',
      sprayUsage = 'Nasal';

  PrescriptionMedicineModel toApiModel() {
    String? tabletDose;
    String? syrupDose;
    String? injDose;
    String? injRouteVal;
    String? dropsCnt;
    String? dropsApp;
    String? lotionArea;
    String? sprayPuffsVal;
    String? sprayUsageVal;

    switch (type) {
      case MedicineType.tablet:
        tabletDose = tabletDosage.isEmpty ? null : tabletDosage;
        break;
      case MedicineType.syrup:
        syrupDose = syrupDosageMl.isEmpty ? null : syrupDosageMl;
        break;
      case MedicineType.injection:
        injDose = injDosage.isEmpty ? null : injDosage;
        injRouteVal = injRoute.isEmpty ? null : injRoute;
        break;
      case MedicineType.drops:
        dropsCnt = dropsCount.isEmpty ? null : dropsCount;
        dropsApp = dropsApplication.isEmpty ? null : dropsApplication;
        break;
      case MedicineType.lotion:
        lotionArea = lotionApplyArea.isEmpty ? null : lotionApplyArea;
        break;
      case MedicineType.spray:
        sprayPuffsVal = sprayPuffs.isEmpty ? null : sprayPuffs;
        sprayUsageVal = sprayUsage.isEmpty ? null : sprayUsage;
        break;
    }

    return PrescriptionMedicineModel(
      medicineId: medicineId,
      medicineTypeId: type.typeId,
      frequency: frequency.isEmpty ? null : frequency,
      duration: duration.isEmpty ? null : duration,
      timing: timing.isEmpty ? null : timing,
      tabletDosage: tabletDose,
      syrupDosageMl: syrupDose,
      injDosage: injDose,
      injRoute: injRouteVal,
      dropsCount: dropsCnt,
      dropsApplication: dropsApp,
      lotionApplyArea: lotionArea,
      sprayPuffs: sprayPuffsVal,
      sprayUsage: sprayUsageVal,
    );
  }
}

class PrescriptionScreen extends ConsumerStatefulWidget {
  /// Pass patient_id and doctor_id from previous screen
  final int patientId;
  final int doctorId;

  const PrescriptionScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
  });

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  final _sympCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final _clinCtrl = TextEditingController();
  final _advCtrl = TextEditingController();
  DateTime? _followDate;
  final List<MedicineEntry> _meds = [];
  bool _requestedMeds = false;

  @override
  void dispose() {
    _sympCtrl.dispose();
    _diagCtrl.dispose();
    _clinCtrl.dispose();
    _advCtrl.dispose();
    super.dispose();
  }

  void _addMed() => setState(() => _meds.add(MedicineEntry()));
  void _delMed(int i) => setState(() => _meds.removeAt(i));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(
          ctx,
        ).copyWith(colorScheme: const ColorScheme.light(primary: kPrimary)),
        child: child!,
      ),
    );
    if (d != null) setState(() => _followDate = d);
  }

  String? _validate() {
    if (_sympCtrl.text.trim().isEmpty) return 'Please enter symptoms';
    if (_diagCtrl.text.trim().isEmpty) return 'Please enter diagnosis';
    if (_meds.isEmpty) return 'Please add at least one medicine';
    for (int i = 0; i < _meds.length; i++) {
      if (_meds[i].selectedName == null || _meds[i].medicineId == null) {
        return 'Please select medicine name for Medicine ${i + 1}';
      }
    }
    return null;
  }

  Future<void> _completePrescription() async {
    final error = _validate();
    if (error != null) {
      _showSnack(error, isError: true);
      return;
    }

    // Build follow-up date string (yyyy-MM-dd for SQL)
    String? followUpStr;
    if (_followDate != null) {
      followUpStr =
          '${_followDate!.year}-${_followDate!.month.toString().padLeft(2, '0')}-${_followDate!.day.toString().padLeft(2, '0')}';
    }

    // Build prescription model
    final prescription = PrescriptionModel(
      patientId: widget.patientId,
      doctorId: widget.doctorId,
      symptoms: _sympCtrl.text.trim(),
      diagnosis: _diagCtrl.text.trim(),
      clinicalNotes: _clinCtrl.text.trim().isEmpty
          ? null
          : _clinCtrl.text.trim(),
      followUpDate: followUpStr,
      advice: _advCtrl.text.trim().isEmpty ? null : _advCtrl.text.trim(),
      medicines: _meds.map((e) => e.toApiModel()).toList(),
    );

    await ref
        .read(prescriptionViewModelProvider.notifier)
        .insertPrescription(prescription);

    if (!mounted) return;

    final state = ref.read(prescriptionViewModelProvider);
    if (state.error == null) {
      _showSnack('Prescription saved!');
      // TODO: Navigate to next screen
      // Navigator.pushNamed(context, '/next');
    } else {
      _showSnack(state.error ?? 'Something went wrong', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kRed : kGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1100;
  bool get _isTablet => MediaQuery.of(context).size.width >= 650;

  @override
  Widget build(BuildContext context) {
    // Watch loading state to show overlay
    final state = ref.watch(prescriptionViewModelProvider);
    final doctorState = ref.watch(doctorLoginViewModelProvider);
    final doctorId = doctorState.doctorId ?? 0;
    if (!_requestedMeds && doctorId > 0) {
      _requestedMeds = true;
      Future.microtask(() {
        ref
            .read(doctorLoginViewModelProvider.notifier)
            .fetchAllMedicines(doctorId);
      });
    }
    final medicines = doctorState.medicines?.value ?? const <Medicine>[];

    return Stack(
      children: [
        Scaffold(
          backgroundColor: kBg,
          appBar: _appBar(),
          body: _isDesktop ? _desktopBody(medicines) : _mobileBody(medicines),
        ),

        if (state.isLoading)
          Container(
            color: Colors.black.withOpacity(0.35),
            child: const Center(
              child: CircularProgressIndicator(color: kPrimary),
            ),
          ),
      ],
    );
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: kCardBg,
    elevation: 0,
    surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(
        Icons.arrow_back_ios_new_rounded,
        color: kTextDark,
        size: 20,
      ),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text(
      'New Prescription',
      style: TextStyle(
        color: kTextDark,
        fontSize: 17,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
    ),
    centerTitle: true,
    actions: [
      IconButton(
        icon: const Icon(Icons.help_outline_rounded, color: kTextMid),
        onPressed: () {},
      ),
      IconButton(
        icon: const Icon(Icons.more_vert_rounded, color: kTextDark),
        onPressed: () {},
      ),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: kBorder),
    ),
  );

  // â”€â”€ Desktop two-col â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _desktopBody(List<Medicine> medicines) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        flex: 4,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 20, 14, 100),
          children: [
            _patientCard(),
            _vg(14),
            _textSection('Symptoms', _sympCtrl, 'Enter patient symptoms...'),
            _vg(12),
            _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis...'),
            _vg(12),
            _textSection('Clinical Notes', _clinCtrl, 'Add clinical notes...'),
            _vg(12),
            _followUpCard(),
          ],
        ),
      ),
      Expanded(
        flex: 6,
        child: Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(14, 20, 28, 100),
              children: [
                _medicinesHeader(),
                _vg(10),
                ..._buildMedCards(medicines),
                if (_meds.isEmpty) _emptyMeds(),
              ],
            ),
            _bottomBar(),
          ],
        ),
      ),
    ],
  );

  Widget _mobileBody(List<Medicine> medicines) {
    final hp = _isTablet ? 20.0 : 16.0;
    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.fromLTRB(hp, 16, hp, 110),
          children: [
            _patientCard(),
            _vg(16),
            _textSection('Symptoms', _sympCtrl, 'Enter patient symptoms...'),
            _vg(12),
            _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis...'),
            _vg(12),
            _textSection('Clinical Notes', _clinCtrl, 'Add clinical notes...'),
            _vg(16),
            _medicinesHeader(),
            _vg(10),
            ..._buildMedCards(medicines),
            if (_meds.isEmpty) _emptyMeds(),
            _vg(16),
            _followUpCard(),
          ],
        ),
        _bottomBar(),
      ],
    );
  }

  //  PATIENT CARD
 
  Widget _patientCard() => _card(
    child: Row(
      children: [
        Container(
          width: 52,
          height: 52,
          decoration: BoxDecoration(
            color: kPrimaryBg,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(Icons.person_rounded, color: kPrimary, size: 28),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rajesh Kumar',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextDark,
                ),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _chip('45 yrs'),
                  _chip('Male'),
                  _chip('Token #5', blue: true),
                ],
              ),
            ],
          ),
        ),
        _statusBadge('Active', kGreen),
      ],
    ),
  );

  //---------------------------------- TEXT SECTION-----------------------------------------
  
  Widget _textSection(String label, TextEditingController ctrl, String hint) =>
      _card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _secLabel(label),
            _vg(12),
            TextField(
              controller: ctrl,
              maxLines: 3,
              style: const TextStyle(fontSize: 14, color: kTextDark),
              decoration: _ideco(hint),
            ),
          ],
        ),
      );
//---------------------MEDICINES HEADER SECTION------------------------------------------------
  Widget _medicinesHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _secLabel('Medicines', bare: true),
      GestureDetector(
        onTap: _addMed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add_rounded, color: Colors.white, size: 16),
              SizedBox(width: 5),
              Text(
                'Add Medicine',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ],
  );

  List<Widget> _buildMedCards(List<Medicine> medicines) => List.generate(
    _meds.length,
    (i) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _MedCard(
        index: i,
        entry: _meds[i],
        medicines: medicines,
        onDelete: () => _delMed(i),
        rebuild: () => setState(() {}),
      ),
    ),
  );

  Widget _emptyMeds() => _card(
    child: Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 28),
        child: Column(
          children: [
            Icon(
              Icons.medication_outlined,
              color: kPrimary.withOpacity(0.28),
              size: 44,
            ),
            const SizedBox(height: 10),
            const Text(
              'No medicines added yet',
              style: TextStyle(color: kTextMid, fontSize: 14),
            ),
            const SizedBox(height: 4),
            const Text(
              'Tap "+ Add Medicine" above',
              style: TextStyle(color: Color(0xFFB0B8C8), fontSize: 12),
            ),
          ],
        ),
      ),
    ),
  );
//------------------------------Follow-Up -------------------------------------------------
  Widget _followUpCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _secLabel('Follow-up & Advice'),
        _vg(14),
        GestureDetector(
          onTap: _pickDate,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kBorder),
            ),
            child: Row(
              children: [
                const Icon(Icons.event_rounded, color: kPrimary, size: 18),
                const SizedBox(width: 10),
                Text(
                  _followDate == null
                      ? 'Select follow-up date'
                      : '${_followDate!.day.toString().padLeft(2, '0')}/'
                            '${_followDate!.month.toString().padLeft(2, '0')}/'
                            '${_followDate!.year}',
                  style: TextStyle(
                    fontSize: 14,
                    color: _followDate == null
                        ? const Color(0xFFB0B8C8)
                        : kTextDark,
                    fontWeight: _followDate == null
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                const Spacer(),
                const Icon(Icons.arrow_drop_down_rounded, color: kTextMid),
              ],
            ),
          ),
        ),
        _vg(12),
        TextField(
          controller: _advCtrl,
          maxLines: 3,
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: _ideco('Advice / instructions for patient...'),
        ),
      ],
    ),
  );
  Widget _bottomBar() {
    final isLoading = ref.watch(prescriptionViewModelProvider).isLoading;

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        decoration: const BoxDecoration(
          color: kCardBg,
          boxShadow: [
            BoxShadow(
              color: Color(0x1A000000),
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Row(
          children: [
          
            Expanded(
              child: OutlinedButton(
                onPressed: isLoading
                    ? null
                    : () {
                        // TODO: implement save draft
                      },
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: kPrimary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Save Draft',
                  style: TextStyle(
                    color: kPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
           
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: isLoading ? null : _completePrescription,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2.5,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Complete & Next',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(width: 6),
                          Icon(Icons.arrow_forward_rounded, size: 18),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCardBg,
      borderRadius: BorderRadius.circular(16),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0B000000),
          blurRadius: 12,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: child,
  );

  Widget _vg(double h) => SizedBox(height: h);

  Widget _secLabel(String t, {bool bare = false}) => Row(
    children: [
      Container(
        width: 3,
        height: 16,
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 8),
      Text(
        t,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: kTextDark,
          letterSpacing: -0.2,
        ),
      ),
    ],
  );

  Widget _chip(String t, {bool blue = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: blue ? kPrimaryBg : kBg,
      borderRadius: BorderRadius.circular(6),
    ),
    child: Text(
      t,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: blue ? kPrimary : kTextMid,
      ),
    ),
  );

  Widget _statusBadge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      t,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c),
    ),
  );

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B8C8)),
    filled: true,
    fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
  );
}

class _MedCard extends StatefulWidget {
  final int index;
  final MedicineEntry entry;
  final List<Medicine> medicines;
  final VoidCallback onDelete;
  final VoidCallback rebuild;
  const _MedCard({
    required this.index,
    required this.entry,
    required this.medicines,
    required this.onDelete,
    required this.rebuild,
  });
  @override
  State<_MedCard> createState() => _MedCardState();
}

class _MedCardState extends State<_MedCard> {
  MedicineEntry get e => widget.entry;

  late TextEditingController _freqCtrl;
  late TextEditingController _durCtrl;
  late TextEditingController _dosageCtrl;
  late TextEditingController _mlCtrl;
  late TextEditingController _injDoseCtrl;
  late TextEditingController _dropsCtrl;
  late TextEditingController _areaCtrl;
  late TextEditingController _puffsCtrl;

  @override
  void initState() {
    super.initState();
    _initControllers();
  }

  void _initControllers() {
    _freqCtrl = TextEditingController(text: e.frequency);
    _durCtrl = TextEditingController(text: e.duration);
    _dosageCtrl = TextEditingController(text: e.tabletDosage);
    _mlCtrl = TextEditingController(text: e.syrupDosageMl);
    _injDoseCtrl = TextEditingController(text: e.injDosage);
    _dropsCtrl = TextEditingController(text: e.dropsCount);
    _areaCtrl = TextEditingController(text: e.lotionApplyArea);
    _puffsCtrl = TextEditingController(text: e.sprayPuffs);
  }

  void _disposeControllers() {
    _freqCtrl.dispose();
    _durCtrl.dispose();
    _dosageCtrl.dispose();
    _mlCtrl.dispose();
    _injDoseCtrl.dispose();
    _dropsCtrl.dispose();
    _areaCtrl.dispose();
    _puffsCtrl.dispose();
  }

  void _onTypeChange(MedicineType t) {
    _disposeControllers();
    e.type = t;
    e.medicineId = null;
    e.selectedName = null;
    e.searchText = '';
    e.frequency = '1-0-1';
    e.duration = '';
    _initControllers();
    setState(() {});
    widget.rebuild();
  }

  @override
  void dispose() {
    _disposeControllers();
    super.dispose();
  }

  static const List<String> _timingOpts = [
    'After Food',
    'Before Food',
    'With Food',
    'Empty Stomach',
    'At Bedtime',
    'As Directed',
  ];
  static const List<String> _routeOpts = ['IV', 'IM', 'SC', 'Intradermal'];
  static const List<String> _appOpts = [
    'Eyes',
    'Ears',
    'Nose',
    'Both Eyes',
    'Both Ears',
  ];
  static const List<String> _sprayUsageOpts = [
    'Nasal',
    'Oral (Inhaler)',
    'Throat',
  ];

  @override
  Widget build(BuildContext context) {
    final tc = e.type.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.withOpacity(0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: tc.withOpacity(0.07),
            blurRadius: 14,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(tc),
          Padding(padding: const EdgeInsets.all(14), child: _body()),
        ],
      ),
    );
  }

  Widget _header(Color tc) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: tc.withOpacity(0.07),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
    ),
    child: Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tc.withOpacity(0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(e.type.icon, color: tc, size: 16),
        ),
        const SizedBox(width: 10),
        Text(
          'Medicine ${widget.index + 1}',
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: kTextDark,
          ),
        ),
        const SizedBox(width: 8),
        _TypePill(value: e.type, onChanged: _onTypeChange),
        const Spacer(),
        GestureDetector(
          onTap: widget.onDelete,
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: kRed.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.delete_outline_rounded,
              color: kRed,
              size: 18,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _body() {
    switch (e.type) {
      case MedicineType.tablet:
        return _tabletBody();
      case MedicineType.syrup:
        return _syrupBody();
      case MedicineType.injection:
        return _injBody();
      case MedicineType.drops:
        return _dropsBody();
      case MedicineType.lotion:
        return _lotionBody();
      case MedicineType.spray:
        return _sprayBody();
    }
  }

  Widget _tabletBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _txtField(
        'Dosage',
        'e.g. 500mg, 10mg',
        _dosageCtrl,
        hint2: 'Tablet strength',
        onChanged: (v) => e.tabletDosage = v,
      ),
      _vg(10),
      _freqField(),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 5 days, 2 weeks',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField(
          'Timing',
          e.timing,
          _timingOpts,
          (v) => setState(() => e.timing = v!),
        ),
      ]),
    ],
  );

  Widget _syrupBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _txtField(
        'Dosage (ml)',
        'e.g. 5 ml, 10 ml',
        _mlCtrl,
        onChanged: (v) => e.syrupDosageMl = v,
      ),
      _vg(10),
      _freqField(),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 5 days, 1 week',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField(
          'Timing',
          e.timing,
          _timingOpts,
          (v) => setState(() => e.timing = v!),
        ),
      ]),
    ],
  );



  Widget _injBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _r2([
        _txtField(
          'Dosage',
          'e.g. 1g, 4mg/ml',
          _injDoseCtrl,
          onChanged: (v) => e.injDosage = v,
        ),
        _dropField(
          'Route',
          e.injRoute,
          _routeOpts,
          (v) => setState(() => e.injRoute = v!),
        ),
      ]),
      _vg(10),
      _freqField(),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 3 days, 5 days',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField(
          'Timing',
          e.timing,
          _timingOpts,
          (v) => setState(() => e.timing = v!),
        ),
      ]),
    ],
  );

  Widget _dropsBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _r2([
        _txtField(
          'No. of Drops',
          'e.g. 1, 2, 3',
          _dropsCtrl,
          onChanged: (v) => e.dropsCount = v,
        ),
        _dropField(
          'Application',
          e.dropsApplication,
          _appOpts,
          (v) => setState(() => e.dropsApplication = v!),
        ),
      ]),
      _vg(10),
      _freqField(),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 5 days, 1 week',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField(
          'Timing',
          e.timing,
          _timingOpts,
          (v) => setState(() => e.timing = v!),
        ),
      ]),
    ],
  );

  Widget _lotionBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _txtField(
        'Apply Area / Body Part',
        'e.g. Scalp, Face, Both arms',
        _areaCtrl,
        onChanged: (v) => e.lotionApplyArea = v,
      ),
      _vg(10),
      _freqField(hint: 'e.g. 1-0-0, 0-0-1'),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 7 days, 2 weeks',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField('Timing', e.timing, [
          'Morning',
          'Evening',
          'Night',
          'Morning & Night',
          'As Directed',
        ], (v) => setState(() => e.timing = v!)),
      ]),
    ],
  );

  Widget _sprayBody() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _nameSearch(),
      _vg(10),
      _r2([
        _txtField(
          'Puffs / Dose',
          'e.g. 1, 2, 3 puffs',
          _puffsCtrl,
          onChanged: (v) => e.sprayPuffs = v,
        ),
        _dropField(
          'Usage',
          e.sprayUsage,
          _sprayUsageOpts,
          (v) => setState(() => e.sprayUsage = v!),
        ),
      ]),
      _vg(10),
      _freqField(hint: 'e.g. 1-0-1, 0-0-1'),
      _vg(10),
      _r2([
        _txtField(
          'Duration',
          'e.g. 7 days, 1 month',
          _durCtrl,
          onChanged: (v) => e.duration = v,
        ),
        _dropField(
          'Timing',
          e.timing,
          _timingOpts,
          (v) => setState(() => e.timing = v!),
        ),
      ]),
    ],
  );

  Widget _freqField({String hint = 'e.g. 1-0-1, 0-0-1, SOS'}) {
    const quickFills = [
      '1-0-0',
      '0-1-0',
      '0-0-1',
      '1-0-1',
      '1-1-1',
      '1-1-0',
      'SOS',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Frequency  (Morning â€“ Afternoon â€“ Evening)'),
        _vg(6),
        TextField(
          controller: _freqCtrl,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: kTextDark,
            letterSpacing: 1.2,
          ),
          onChanged: (v) => e.frequency = v,
          decoration: _ideco(hint).copyWith(
            prefixIcon: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.schedule_rounded, color: kPrimary, size: 18),
            ),
            prefixIconConstraints: const BoxConstraints(minWidth: 44),
            suffixIcon: const Tooltip(
              message:
                  'Format: Morning-Afternoon-Evening\n1 = 1 tablet/dose,  0 = skip,  Â½ = half dose\nSOS = as needed',
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  Icons.info_outline_rounded,
                  color: kTextMid,
                  size: 16,
                ),
              ),
            ),
          ),
        ),
        _vg(8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: quickFills
              .map(
                (q) => GestureDetector(
                  onTap: () => setState(() {
                    e.frequency = q;
                    _freqCtrl.text = q;
                    _freqCtrl.selection = TextSelection.collapsed(
                      offset: q.length,
                    );
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: e.frequency == q
                          ? e.type.color.withOpacity(0.15)
                          : kBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: e.frequency == q ? e.type.color : kBorder,
                        width: e.frequency == q ? 1.5 : 1,
                      ),
                    ),
                    child: Text(
                      q,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: e.frequency == q
                            ? FontWeight.w700
                            : FontWeight.w500,
                        color: e.frequency == q ? e.type.color : kTextMid,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ],
    );
  }

  Widget _nameSearch() {
    final all = widget.medicines
        .where((m) => (m.medTypeId ?? 0) == e.type.typeId)
        .toList();
    final filtered = e.searchText.isEmpty
        ? all
        : all
              .where(
                (m) => (m.medicineName ?? '').toLowerCase().contains(
                  e.searchText.toLowerCase(),
                ),
              )
              .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl('Medicine Name  Â·  ${e.type.label}'),
        _vg(6),
        if (all.isEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: const [
                Icon(Icons.info_outline_rounded, size: 13, color: kTextMid),
                SizedBox(width: 6),
                Text(
                  'No medicines found for this type. Add medicines first.',
                  style: TextStyle(fontSize: 12, color: kTextMid),
                ),
              ],
            ),
          ),
        if (e.selectedName != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: e.type.color.withOpacity(0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: e.type.color.withOpacity(0.30)),
            ),
            child: Row(
              children: [
                Icon(e.type.icon, color: e.type.color, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    e.selectedName!,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextDark,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                GestureDetector(
                  onTap: () => setState(() {
                    e.selectedName = null;
                    e.medicineId = null;
                    e.searchText = '';
                  }),
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(
                      color: kBorder,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.close_rounded,
                      size: 12,
                      color: kTextMid,
                    ),
                  ),
                ),
              ],
            ),
          )
        else ...[
          TextField(
            onChanged: (v) => setState(() => e.searchText = v),
            style: const TextStyle(fontSize: 14, color: kTextDark),
            decoration: _ideco('Search or type ${e.type.label} name...')
                .copyWith(
                  prefixIcon: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Icon(
                      Icons.search_rounded,
                      color: e.type.color,
                      size: 18,
                    ),
                  ),
                  prefixIconConstraints: const BoxConstraints(minWidth: 44),
                ),
          ),
          if (e.searchText.isNotEmpty) ...[
            _vg(4),
            if (filtered.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 190),
                decoration: BoxDecoration(
                  color: kCardBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(
                    height: 1,
                    color: kBorder,
                    indent: 14,
                    endIndent: 14,
                  ),
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => setState(() {
                      e.selectedName = filtered[i].medicineName ?? '';
                      e.medicineId = filtered[i].medicineId;
                      e.searchText = '';
                    }),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      child: Row(
                        children: [
                          Icon(e.type.icon, color: e.type.color, size: 14),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              filtered[i].medicineName ?? '',
                              style: const TextStyle(
                                fontSize: 13,
                                color: kTextDark,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Icon(
                            Icons.add_circle_outline_rounded,
                            color: e.type.color,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 13,
                      color: kTextMid,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'No ${e.type.label} found for "${e.searchText}"',
                      style: const TextStyle(fontSize: 12, color: kTextMid),
                    ),
                  ],
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _txtField(
    String label,
    String hint,
    TextEditingController ctrl, {
    String? hint2,
    required ValueChanged<String> onChanged,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _lbl(label),
      if (hint2 != null) ...[
        _vg(2),
        Text(
          hint2,
          style: const TextStyle(fontSize: 11, color: Color(0xFFB0B8C8)),
        ),
      ],
      _vg(6),
      TextField(
        controller: ctrl,
        onChanged: onChanged,
        style: const TextStyle(fontSize: 14, color: kTextDark),
        decoration: _ideco(hint),
      ),
    ],
  );

  Widget _dropField(
    String label,
    String value,
    List<String> opts,
    ValueChanged<String?> cb,
  ) {
    final safe = opts.contains(value) ? value : opts.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _lbl(label),
        _vg(6),
        DropdownButtonFormField<String>(
          value: safe,
          isExpanded: true,
          items: opts
              .map(
                (o) => DropdownMenuItem(
                  value: o,
                  child: Text(
                    o,
                    style: const TextStyle(fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: cb,
          decoration: _ideco('').copyWith(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 11,
            ),
          ),
          dropdownColor: kCardBg,
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: kTextMid,
            size: 18,
          ),
        ),
      ],
    );
  }

  Widget _r2(List<Widget> ch) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: ch[0]),
      const SizedBox(width: 10),
      Expanded(child: ch[1]),
    ],
  );

  Widget _lbl(String t) => Text(
    t,
    style: const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: kTextMid,
      letterSpacing: 0.1,
    ),
  );

  Widget _vg(double h) => SizedBox(height: h);

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B8C8)),
    filled: true,
    fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kBorder),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(10),
      borderSide: const BorderSide(color: kPrimary, width: 1.5),
    ),
  );
}

class _TypePill extends StatelessWidget {
  final MedicineType value;
  final ValueChanged<MedicineType> onChanged;
  const _TypePill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value.color.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MedicineType>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down_rounded,
            size: 15,
            color: value.color,
          ),
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: value.color,
          ),
          dropdownColor: kCardBg,
          items: MedicineType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(t.icon, size: 14, color: t.color),
                      const SizedBox(width: 5),
                      Text(
                        t.label,
                        style: TextStyle(
                          color: t.color,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
