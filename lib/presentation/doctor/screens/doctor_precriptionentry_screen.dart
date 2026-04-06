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

  int get typeId => index + 1;
}

// ════════════════════════════════════════════════════════════════════
//  PICKER OPTIONS
//  _kDosageOpts  — per-type dose amounts  (goes to dosage API field)
//  _kFreqOpts    — times per slot         (goes to frequency API field)
// ════════════════════════════════════════════════════════════════════
const _kDosageOpts = {
  'tablet':    ['0', '¼', '½', '¾', '1', '1½', '2', '3'],
  'syrup':     ['0', '2.5ml', '5ml', '7.5ml', '10ml', '15ml', '20ml'],
  'injection': ['0', '0.5', '1', '2', '4', '5', '10'],
  'drops':     ['0', '1', '2', '3', '4', '5', '6'],
  'lotion':    ['0', 'Apply', 'Thin layer', 'Thick layer'],
  'spray':     ['0', '1 puff', '2 puffs', '3 puffs', '4 puffs'],
};

const _kFreqOpts = {
  'tablet':    ['0', '1', '2', '3'],
  'syrup':     ['0', '1', '2', '3'],
  'injection': ['0', '1', '2', '3'],
  'drops':     ['0', '1', '2', '3'],
  'lotion':    ['0', '1', '2', '3'],
  'spray':     ['0', '1', '2', '3'],
};

// ════════════════════════════════════════════════════════════════════
//  SlotPickerField  — reusable inline drum picker
//  Used for both dosage and frequency
// ════════════════════════════════════════════════════════════════════
class SlotPickerField extends StatefulWidget {
  final String label;
  final String subLabel;
  final String typeKey;
  final Color accentColor;
  final String initialValue;
  final Map<String, List<String>> optsMap;
  final ValueChanged<String> onChanged;

  const SlotPickerField({
    super.key,
    required this.label,
    required this.subLabel,
    required this.typeKey,
    required this.accentColor,
    required this.initialValue,
    required this.optsMap,
    required this.onChanged,
  });

  @override
  State<SlotPickerField> createState() => _SlotPickerFieldState();
}

class _SlotPickerFieldState extends State<SlotPickerField> {
  bool _open = false;
  late List<String> _committed;

  List<String> get _opts =>
      widget.optsMap[widget.typeKey] ?? widget.optsMap['tablet']!;

  @override
  void initState() {
    super.initState();
    _committed = _parse(widget.initialValue);
  }

  @override
  void didUpdateWidget(SlotPickerField old) {
    super.didUpdateWidget(old);
    if (old.typeKey != widget.typeKey) {
      _committed = _parse(widget.initialValue);
      setState(() {});
    }
    if (old.initialValue != widget.initialValue) {
      _committed = _parse(widget.initialValue);
      setState(() {});
    }
  }

  List<String> _parse(String v) {
    final parts = v.split('-');
    if (parts.length >= 3) return [parts[0], parts[1], parts[2]];
    final o = _opts;
    final def = o.length > 1 ? o[1] : o[0];
    return [def, '0', def];
  }

  String get _display => _committed.join(' – ');

  void _onSet(List<String> vals) {
    setState(() {
      _committed = List.from(vals);
      _open = false;
    });
    widget.onChanged(vals.join('-'));
  }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // label row
        Row(children: [
          Text(widget.label, style: const TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600,
            color: kTextMid, letterSpacing: 0.1,
          )),
          const SizedBox(width: 4),
          Text('(${widget.subLabel})', style: const TextStyle(
            fontSize: 11, color: Color(0xFFB0B8C8),
          )),
        ]),
        const SizedBox(height: 6),

        // display box
        GestureDetector(
          onTap: () => setState(() => _open = !_open),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: kBg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _open ? ac : kBorder,
                width: _open ? 1.8 : 1.0,
              ),
            ),
            child: Row(children: [
              Expanded(child: Text(
                _display,
                style: TextStyle(
                  fontSize: 19, fontWeight: FontWeight.w700, color: ac,
                ),
              )),
              Icon(
                _open
                    ? Icons.keyboard_arrow_up_rounded
                    : Icons.keyboard_arrow_down_rounded,
                color: kTextMid, size: 20,
              ),
            ]),
          ),
        ),

        // inline drum panel
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _open
              ? _InlineDrumPanel(
                  key: ValueKey('${widget.typeKey}_${widget.label}'),
                  opts: _opts,
                  draft: List.from(_committed),
                  accentColor: ac,
                  onSet: _onSet,
                  onDismiss: () => setState(() => _open = false),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  _InlineDrumPanel
// ════════════════════════════════════════════════════════════════════
class _InlineDrumPanel extends StatefulWidget {
  final List<String> opts;
  final List<String> draft;
  final Color accentColor;
  final ValueChanged<List<String>> onSet;
  final VoidCallback onDismiss;

  const _InlineDrumPanel({
    super.key,
    required this.opts,
    required this.draft,
    required this.accentColor,
    required this.onSet,
    required this.onDismiss,
  });

  @override
  State<_InlineDrumPanel> createState() => _InlineDrumPanelState();
}

class _InlineDrumPanelState extends State<_InlineDrumPanel> {
  late List<String> _sel;

  @override
  void initState() {
    super.initState();
    _sel = List.from(widget.draft);
  }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return Container(
      margin: const EdgeInsets.only(top: 6),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: ac.withOpacity(0.25)),
        boxShadow: [BoxShadow(
          color: ac.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4),
        )],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // header
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: ac.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
          ),
          child: Row(children: [
            Icon(Icons.tune_rounded, color: ac, size: 14),
            const SizedBox(width: 6),
            Text('Select per slot', style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w600, color: ac,
            )),
            const Spacer(),
            GestureDetector(
              onTap: widget.onDismiss,
              child: const Icon(Icons.close_rounded, color: kTextMid, size: 16),
            ),
          ]),
        ),

        // slot labels
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(children: [
            _slotLbl('Morning'),
            const SizedBox(width: 16),
            _slotLbl('Afternoon'),
            const SizedBox(width: 16),
            _slotLbl('Night'),
          ]),
        ),

        // drums
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 4, 10, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: _DrumPicker(
                opts: widget.opts, selected: _sel[0], accentColor: ac,
                onChanged: (v) => setState(() => _sel[0] = v),
              )),
              Text('–', style: TextStyle(fontSize: 20, color: kTextMid)),
              Expanded(child: _DrumPicker(
                opts: widget.opts, selected: _sel[1], accentColor: ac,
                onChanged: (v) => setState(() => _sel[1] = v),
              )),
              Text('–', style: TextStyle(fontSize: 20, color: kTextMid)),
              Expanded(child: _DrumPicker(
                opts: widget.opts, selected: _sel[2], accentColor: ac,
                onChanged: (v) => setState(() => _sel[2] = v),
              )),
            ],
          ),
        ),

        const Divider(height: 1, color: kBorder),

        // Set button
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSet(_sel),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Set', style: TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: 0.4,
              )),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _slotLbl(String t) => Expanded(child: Text(
    t, textAlign: TextAlign.center,
    style: const TextStyle(fontSize: 11, color: kTextMid, fontWeight: FontWeight.w500),
  ));
}

// ════════════════════════════════════════════════════════════════════
//  _DrumPicker  — single scroll column
// ════════════════════════════════════════════════════════════════════
class _DrumPicker extends StatefulWidget {
  final List<String> opts;
  final String selected;
  final Color accentColor;
  final ValueChanged<String> onChanged;

  const _DrumPicker({
    required this.opts,
    required this.selected,
    required this.accentColor,
    required this.onChanged,
  });

  @override
  State<_DrumPicker> createState() => _DrumPickerState();
}

class _DrumPickerState extends State<_DrumPicker> {
  late FixedExtentScrollController _ctrl;

  @override
  void initState() {
    super.initState();
    final idx = widget.opts.indexOf(widget.selected);
    _ctrl = FixedExtentScrollController(initialItem: idx < 0 ? 0 : idx);
  }

  @override
  void didUpdateWidget(_DrumPicker old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected) {
      final idx = widget.opts.indexOf(widget.selected);
      if (idx >= 0) {
        _ctrl.animateToItem(idx,
            duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
      }
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return SizedBox(
      height: 120,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          height: 40,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: ac.withOpacity(0.10),
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        Positioned(top: 0, left: 0, right: 0, height: 40,
          child: IgnorePointer(child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [kCardBg, kCardBg.withOpacity(0)],
            ),
          ))),
        ),
        Positioned(bottom: 0, left: 0, right: 0, height: 40,
          child: IgnorePointer(child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter, end: Alignment.topCenter,
              colors: [kCardBg, kCardBg.withOpacity(0)],
            ),
          ))),
        ),
        ListWheelScrollView.useDelegate(
          controller: _ctrl,
          itemExtent: 40,
          diameterRatio: 1.8,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => widget.onChanged(widget.opts[i]),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.opts.length,
            builder: (_, i) {
              final isSel = widget.opts[i] == widget.selected;
              return Center(child: Text(
                widget.opts[i],
                style: TextStyle(
                  fontSize: isSel ? 20 : 14,
                  fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                  color: isSel ? ac : kTextMid,
                ),
              ));
            },
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  MedicineEntry
//  dosage  → per-slot dose    e.g. "½-0-1"   → API: tabletDosage etc.
//  frequency → per-slot times e.g. "1-0-1"   → API: frequency
// ════════════════════════════════════════════════════════════════════
class MedicineEntry {
  MedicineType type;
  int? medicineId;
  String? selectedName;
  String searchText;
  String dosage;
  String frequency;
  String duration;
  String timing;
  String injRoute;
  String dropsApplication;
  String lotionApplyArea;
  String sprayUsage;

  MedicineEntry()
      : type = MedicineType.tablet,
        medicineId = null,
        selectedName = null,
        searchText = '',
        dosage = '1-0-1',
        frequency = '1-0-1',
        duration = '',
        timing = 'After Food',
        injRoute = 'IV',
        dropsApplication = 'Eyes',
        lotionApplyArea = '',
        sprayUsage = 'Nasal';

  PrescriptionMedicineModel toApiModel() {
    return PrescriptionMedicineModel(
      medicineId:       medicineId,
      medicineTypeId:   type.typeId,
      frequency:        frequency.isEmpty ? null : frequency,
      duration:         duration.isEmpty  ? null : duration,
      timing:           timing.isEmpty    ? null : timing,
      // dosage goes to correct type-specific field
      tabletDosage:     type == MedicineType.tablet    ? (dosage.isEmpty ? null : dosage) : null,
      syrupDosageMl:    type == MedicineType.syrup     ? (dosage.isEmpty ? null : dosage) : null,
      injDosage:        type == MedicineType.injection ? (dosage.isEmpty ? null : dosage) : null,
      injRoute:         type == MedicineType.injection ? (injRoute.isEmpty ? null : injRoute) : null,
      dropsCount:       type == MedicineType.drops     ? (dosage.isEmpty ? null : dosage) : null,
      dropsApplication: type == MedicineType.drops     ? (dropsApplication.isEmpty ? null : dropsApplication) : null,
      lotionApplyArea:  type == MedicineType.lotion    ? (lotionApplyArea.isEmpty ? null : lotionApplyArea) : null,
      sprayPuffs:       type == MedicineType.spray     ? (dosage.isEmpty ? null : dosage) : null,
      sprayUsage:       type == MedicineType.spray     ? (sprayUsage.isEmpty ? null : sprayUsage) : null,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PrescriptionScreen
// ════════════════════════════════════════════════════════════════════
class PrescriptionScreen extends ConsumerStatefulWidget {
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
  final _advCtrl  = TextEditingController();
  DateTime? _followDate;
  final List<MedicineEntry> _meds = [];
  int _lastDoctorId = 0;

  @override
  void dispose() {
    _sympCtrl.dispose(); _diagCtrl.dispose();
    _clinCtrl.dispose(); _advCtrl.dispose();
    super.dispose();
  }

  void _addMed() => setState(() => _meds.add(MedicineEntry()));
  void _delMed(int i) => setState(() => _meds.removeAt(i));

  void _maybeFetchMedicines(int doctorId) {
    if (doctorId == 0 || doctorId == _lastDoctorId) return;
    _lastDoctorId = doctorId;
    ref.read(doctorLoginViewModelProvider.notifier).fetchAllMedicines(doctorId);
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 7)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(primary: kPrimary)),
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
      if (_meds[i].selectedName == null || _meds[i].medicineId == null)
        return 'Please select medicine name for Medicine ${i + 1}';
    }
    return null;
  }

  Future<void> _completePrescription() async {
    final error = _validate();
    if (error != null) { _showSnack(error, isError: true); return; }

    String? followUpStr;
    if (_followDate != null) {
      followUpStr =
          '${_followDate!.year}-${_followDate!.month.toString().padLeft(2, '0')}-${_followDate!.day.toString().padLeft(2, '0')}';
    }

    final prescription = PrescriptionModel(
      patientId:    widget.patientId,
      doctorId:     widget.doctorId,
      symptoms:     _sympCtrl.text.trim(),
      diagnosis:    _diagCtrl.text.trim(),
      clinicalNotes: _clinCtrl.text.trim().isEmpty ? null : _clinCtrl.text.trim(),
      followUpDate: followUpStr,
      advice:       _advCtrl.text.trim().isEmpty ? null : _advCtrl.text.trim(),
      medicines:    _meds.map((e) => e.toApiModel()).toList(),
    );

    await ref.read(prescriptionViewModelProvider.notifier).insertPrescription(prescription);
    if (!mounted) return;

    final state = ref.read(prescriptionViewModelProvider);
    if (state.error == null) {
      _showSnack('Prescription saved!');
    } else {
      _showSnack(state.error ?? 'Something went wrong', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: isError ? kRed : kGreen,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ));
  }

  bool get _isDesktop => MediaQuery.of(context).size.width >= 1100;
  bool get _isTablet  => MediaQuery.of(context).size.width >= 650;

  @override
  Widget build(BuildContext context) {
    ref.listen(doctorLoginViewModelProvider.select((s) => s.doctorId), (_, next) {
      _maybeFetchMedicines(next ?? 0);
    });

    final state       = ref.watch(prescriptionViewModelProvider);
    final doctorState = ref.watch(doctorLoginViewModelProvider);
    final doctorId    = doctorState.doctorId ?? 0;
    _maybeFetchMedicines(doctorId);
    final medicines   = doctorState.medicines?.value ?? const <Medicine>[];

    return Stack(children: [
      Scaffold(
        backgroundColor: kBg,
        appBar: _appBar(),
        body: _isDesktop ? _desktopBody(medicines) : _mobileBody(medicines),
      ),
      if (state.isLoading)
        Container(
          color: Colors.black.withOpacity(0.35),
          child: const Center(child: CircularProgressIndicator(color: kPrimary)),
        ),
    ]);
  }

  PreferredSizeWidget _appBar() => AppBar(
    backgroundColor: kCardBg, elevation: 0, surfaceTintColor: Colors.transparent,
    leading: IconButton(
      icon: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextDark, size: 20),
      onPressed: () => Navigator.pop(context),
    ),
    title: const Text('New Prescription', style: TextStyle(
      color: kTextDark, fontSize: 17, fontWeight: FontWeight.w700, letterSpacing: -0.3,
    )),
    centerTitle: true,
    actions: [
      IconButton(icon: const Icon(Icons.help_outline_rounded, color: kTextMid), onPressed: () {}),
      IconButton(icon: const Icon(Icons.more_vert_rounded, color: kTextDark), onPressed: () {}),
    ],
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(height: 1, color: kBorder),
    ),
  );

  Widget _desktopBody(List<Medicine> medicines) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(flex: 4, child: ListView(
        padding: const EdgeInsets.fromLTRB(28, 20, 14, 100),
        children: [
          _patientCard(), _vg(14),
          _textSection('Symptoms', _sympCtrl, 'Enter patient symptoms...'), _vg(12),
          _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis...'), _vg(12),
          _textSection('Clinical Notes', _clinCtrl, 'Add clinical notes...'), _vg(12),
          _followUpCard(),
        ],
      )),
      Expanded(flex: 6, child: Stack(children: [
        ListView(
          padding: const EdgeInsets.fromLTRB(14, 20, 28, 100),
          children: [
            _medicinesHeader(), _vg(10),
            ..._buildMedCards(medicines),
            if (_meds.isEmpty) _emptyMeds(),
          ],
        ),
        _bottomBar(),
      ])),
    ],
  );

  Widget _mobileBody(List<Medicine> medicines) {
    final hp = _isTablet ? 20.0 : 16.0;
    return Stack(children: [
      ListView(
        padding: EdgeInsets.fromLTRB(hp, 16, hp, 110),
        children: [
          _patientCard(), _vg(16),
          _textSection('Symptoms', _sympCtrl, 'Enter patient symptoms...'), _vg(12),
          _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis...'), _vg(12),
          _textSection('Clinical Notes', _clinCtrl, 'Add clinical notes...'), _vg(16),
          _medicinesHeader(), _vg(10),
          ..._buildMedCards(medicines),
          if (_meds.isEmpty) _emptyMeds(),
          _vg(16),
          _followUpCard(),
        ],
      ),
      _bottomBar(),
    ]);
  }

  Widget _patientCard() => _card(child: Row(children: [
    Container(
      width: 52, height: 52,
      decoration: BoxDecoration(color: kPrimaryBg, borderRadius: BorderRadius.circular(14)),
      child: const Icon(Icons.person_rounded, color: kPrimary, size: 28),
    ),
    const SizedBox(width: 14),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Rajesh Kumar', style: TextStyle(
        fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark,
      )),
      const SizedBox(height: 5),
      Wrap(spacing: 6, runSpacing: 4, children: [
        _chip('45 yrs'), _chip('Male'), _chip('Token #5', blue: true),
      ]),
    ])),
    _statusBadge('Active', kGreen),
  ]));

  Widget _textSection(String label, TextEditingController ctrl, String hint) =>
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secLabel(label), _vg(12),
        TextField(
          controller: ctrl, maxLines: 3,
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: _ideco(hint),
        ),
      ]));

  Widget _medicinesHeader() => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      _secLabel('Medicines', bare: true),
      GestureDetector(
        onTap: _addMed,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(10)),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 16),
            SizedBox(width: 5),
            Text('Add Medicine', style: TextStyle(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ]),
        ),
      ),
    ],
  );

  List<Widget> _buildMedCards(List<Medicine> medicines) => List.generate(
    _meds.length,
    (i) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: _MedCard(
        index: i, entry: _meds[i], medicines: medicines,
        onDelete: () => _delMed(i),
        rebuild: () => setState(() {}),
      ),
    ),
  );

  Widget _emptyMeds() => _card(child: Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 28),
    child: Column(children: [
      Icon(Icons.medication_outlined, color: kPrimary.withOpacity(0.28), size: 44),
      const SizedBox(height: 10),
      const Text('No medicines added yet', style: TextStyle(color: kTextMid, fontSize: 14)),
      const SizedBox(height: 4),
      const Text('Tap "+ Add Medicine" above',
          style: TextStyle(color: Color(0xFFB0B8C8), fontSize: 12)),
    ]),
  )));

  Widget _followUpCard() => _card(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _secLabel('Follow-up & Advice'), _vg(14),
      GestureDetector(
        onTap: _pickDate,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: kBg, borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorder),
          ),
          child: Row(children: [
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
                color: _followDate == null ? const Color(0xFFB0B8C8) : kTextDark,
                fontWeight: _followDate == null ? FontWeight.w400 : FontWeight.w600,
              ),
            ),
            const Spacer(),
            const Icon(Icons.arrow_drop_down_rounded, color: kTextMid),
          ]),
        ),
      ),
      _vg(12),
      TextField(
        controller: _advCtrl, maxLines: 3,
        style: const TextStyle(fontSize: 14, color: kTextDark),
        decoration: _ideco('Advice / instructions for patient...'),
      ),
    ],
  ));

  Widget _bottomBar() {
    final isLoading = ref.watch(prescriptionViewModelProvider).isLoading;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        decoration: const BoxDecoration(
          color: kCardBg,
          boxShadow: [BoxShadow(color: Color(0x1A000000), blurRadius: 20, offset: Offset(0, -4))],
        ),
        child: Row(children: [
          Expanded(child: OutlinedButton(
            onPressed: isLoading ? null : () {},
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: kPrimary, width: 1.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Save Draft', style: TextStyle(
              color: kPrimary, fontWeight: FontWeight.w600, fontSize: 15,
            )),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: ElevatedButton(
            onPressed: isLoading ? null : _completePrescription,
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimary, foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: isLoading
                ? const SizedBox(height: 20, width: 20,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Complete & Next', style: TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15,
                    )),
                    SizedBox(width: 6),
                    Icon(Icons.arrow_forward_rounded, size: 18),
                  ]),
          )),
        ]),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    width: double.infinity, padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: kCardBg, borderRadius: BorderRadius.circular(16),
      boxShadow: const [BoxShadow(
        color: Color(0x0B000000), blurRadius: 12, offset: Offset(0, 2),
      )],
    ),
    child: child,
  );

  Widget _vg(double h) => SizedBox(height: h);

  Widget _secLabel(String t, {bool bare = false}) => Row(children: [
    Container(width: 3, height: 16,
        decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(t, style: const TextStyle(
      fontSize: 15, fontWeight: FontWeight.w700, color: kTextDark, letterSpacing: -0.2,
    )),
  ]);

  Widget _chip(String t, {bool blue = false}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: blue ? kPrimaryBg : kBg, borderRadius: BorderRadius.circular(6),
    ),
    child: Text(t, style: TextStyle(
      fontSize: 12, fontWeight: FontWeight.w500,
      color: blue ? kPrimary : kTextMid,
    )),
  );

  Widget _statusBadge(String t, Color c) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(
      color: c.withOpacity(0.12), borderRadius: BorderRadius.circular(8),
    ),
    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c)),
  );

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B8C8)),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.5)),
  );
}

// ════════════════════════════════════════════════════════════════════
//  _MedCard
// ════════════════════════════════════════════════════════════════════
class _MedCard extends StatefulWidget {
  final int index;
  final MedicineEntry entry;
  final List<Medicine> medicines;
  final VoidCallback onDelete;
  final VoidCallback rebuild;

  const _MedCard({
    required this.index, required this.entry, required this.medicines,
    required this.onDelete, required this.rebuild,
  });

  @override
  State<_MedCard> createState() => _MedCardState();
}

class _MedCardState extends State<_MedCard> {
  MedicineEntry get e => widget.entry;

  late TextEditingController _durCtrl;
  late TextEditingController _areaCtrl;

  @override
  void initState() { super.initState(); _initControllers(); }

  void _initControllers() {
    _durCtrl  = TextEditingController(text: e.duration);
    _areaCtrl = TextEditingController(text: e.lotionApplyArea);
  }

  String _freqFromDosage(String dosage) {
    final parts = dosage.split('-');
    if (parts.length < 3) return e.frequency;
    return parts.map((p) => p == '0' ? '0' : '1').join('-');
  }

  void _disposeControllers() {
    _durCtrl.dispose();
    _areaCtrl.dispose();
  }

  void _onTypeChange(MedicineType t) {
    _disposeControllers();
    e.type = t;
    e.medicineId = null; e.selectedName = null; e.searchText = '';
    e.dosage = '1-0-1'; e.frequency = '1-0-1'; e.duration = '';
    _initControllers();
    setState(() {});
    widget.rebuild();
  }

  @override
  void dispose() { _disposeControllers(); super.dispose(); }

  static const _timingOpts = [
    'After Food', 'Before Food', 'With Food', 'Empty Stomach', 'At Bedtime', 'As Directed',
  ];
  static const _routeOpts  = ['IV', 'IM', 'SC', 'Intradermal'];
  static const _appOpts    = ['Eyes', 'Ears', 'Nose', 'Both Eyes', 'Both Ears'];
  static const _sprayUsage = ['Nasal', 'Oral (Inhaler)', 'Throat'];

  @override
  Widget build(BuildContext context) {
    final tc = e.type.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tc.withOpacity(0.28), width: 1.2),
        boxShadow: [BoxShadow(
            color: tc.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 3))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(tc),
        Padding(padding: const EdgeInsets.all(14), child: _body()),
      ]),
    );
  }

  Widget _header(Color tc) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
    decoration: BoxDecoration(
      color: tc.withOpacity(0.07),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(15)),
    ),
    child: Row(children: [
      Container(
        width: 30, height: 30,
        decoration: BoxDecoration(
            color: tc.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
        child: Icon(e.type.icon, color: tc, size: 16),
      ),
      const SizedBox(width: 10),
      Text('Medicine ${widget.index + 1}', style: const TextStyle(
        fontSize: 14, fontWeight: FontWeight.w700, color: kTextDark,
      )),
      const SizedBox(width: 8),
      _TypePill(value: e.type, onChanged: _onTypeChange),
      const Spacer(),
      GestureDetector(
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
              color: kRed.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.delete_outline_rounded, color: kRed, size: 18),
        ),
      ),
    ]),
  );

  Widget _body() {
    switch (e.type) {
      case MedicineType.tablet:    return _commonBody();
      case MedicineType.syrup:     return _commonBody();
      case MedicineType.injection: return _injBody();
      case MedicineType.drops:     return _dropsBody();
      case MedicineType.lotion:    return _lotionBody();
      case MedicineType.spray:     return _sprayBody();
    }
  }

  // ── dosage picker helper ─────────────────────────────────────────
  Widget _dosagePicker({String? label}) => SlotPickerField(
    key: ValueKey('dosage_${e.type.name}'),
    label: label ?? 'Dosage per slot',
    subLabel: 'Morning – Afternoon – Night',
    typeKey: e.type.name,
    accentColor: e.type.color,
    initialValue: e.dosage,
    optsMap: _kDosageOpts,
    onChanged: (val) => setState(() {
      e.dosage = val;
      // Derive frequency from dosage: any non-zero dose counts as 1 time.
      e.frequency = _freqFromDosage(val);
    }),
  );

  // ── frequency picker helper ──────────────────────────────────────
  Widget _freqPicker() => SlotPickerField(
    key: ValueKey('freq_${e.type.name}'),
    label: 'Frequency per slot',
    subLabel: 'Times – Morning – Afternoon – Night',
    typeKey: e.type.name,
    accentColor: e.type.color,
    initialValue: e.frequency,
    optsMap: _kFreqOpts,
    onChanged: (val) => setState(() => e.frequency = val),
  );

  Widget _commonBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _vg(12),
    _dosagePicker(), _vg(12),
    _r2([
      _txtField('Duration', 'e.g. 5 days, 2 weeks', _durCtrl,
          onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts,
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _injBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _vg(12),
    _dropField('Route', e.injRoute, _routeOpts,
        (v) => setState(() => e.injRoute = v!)),
    _vg(12),
    _dosagePicker(), _vg(12),
    _r2([
      _txtField('Duration', 'e.g. 3 days, 5 days', _durCtrl,
          onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts,
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _dropsBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _vg(12),
    _dropField('Application', e.dropsApplication, _appOpts,
        (v) => setState(() => e.dropsApplication = v!)),
    _vg(12),
    _dosagePicker(label: 'Drops per slot'), _vg(12),
    _r2([
      _txtField('Duration', 'e.g. 5 days, 1 week', _durCtrl,
          onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts,
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _lotionBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _vg(12),
    _txtField('Apply Area / Body Part', 'e.g. Scalp, Face, Both arms', _areaCtrl,
        onChanged: (v) => e.lotionApplyArea = v),
    _vg(12),
    _dosagePicker(label: 'Application per slot'), _vg(12),
    _r2([
      _txtField('Duration', 'e.g. 7 days, 2 weeks', _durCtrl,
          onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing,
          ['Morning', 'Evening', 'Night', 'Morning & Night', 'As Directed'],
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _sprayBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _vg(12),
    _dropField('Usage', e.sprayUsage, _sprayUsage,
        (v) => setState(() => e.sprayUsage = v!)),
    _vg(12),
    _dosagePicker(label: 'Puffs per slot'), _vg(12),
    _r2([
      _txtField('Duration', 'e.g. 7 days, 1 month', _durCtrl,
          onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts,
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  // ── name search ──────────────────────────────────────────────────
  Widget _nameSearch() {
    final all = widget.medicines
        .where((m) => (m.medTypeId ?? 0) == e.type.typeId)
        .toList();
    final filtered = e.searchText.isEmpty
        ? all
        : all.where((m) => (m.medicineName ?? '')
            .toLowerCase()
            .contains(e.searchText.toLowerCase()))
            .toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('Medicine Name  ·  ${e.type.label}'),
      _vg(6),
      if (all.isEmpty)
        Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(children: const [
          Icon(Icons.info_outline_rounded, size: 13, color: kTextMid),
          SizedBox(width: 6),
          Text('No medicines found for this type. Add medicines first.',
              style: TextStyle(fontSize: 12, color: kTextMid)),
        ])),
      if (e.selectedName != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: e.type.color.withOpacity(0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: e.type.color.withOpacity(0.30)),
          ),
          child: Row(children: [
            Icon(e.type.icon, color: e.type.color, size: 16),
            const SizedBox(width: 8),
            Expanded(child: Text(e.selectedName!, style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark,
            ), overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () => setState(() {
                e.selectedName = null; e.medicineId = null; e.searchText = '';
              }),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: kBorder, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 12, color: kTextMid),
              ),
            ),
          ]),
        )
      else ...[
        TextField(
          onChanged: (v) => setState(() => e.searchText = v),
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: _ideco('Search or type ${e.type.label} name...').copyWith(
            prefixIcon: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, color: e.type.color, size: 18),
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
                color: kCardBg, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
                boxShadow: const [BoxShadow(
                  color: Color(0x12000000), blurRadius: 8, offset: Offset(0, 4),
                )],
              ),
              child: ListView.separated(
                shrinkWrap: true, padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, color: kBorder, indent: 14, endIndent: 14),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => setState(() {
                    e.selectedName = filtered[i].medicineName ?? '';
                    e.medicineId = filtered[i].medicineId;
                    e.searchText = '';
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                    child: Row(children: [
                      Icon(e.type.icon, color: e.type.color, size: 14),
                      const SizedBox(width: 10),
                      Expanded(child: Text(filtered[i].medicineName ?? '',
                          style: const TextStyle(fontSize: 13, color: kTextDark),
                          overflow: TextOverflow.ellipsis)),
                      Icon(Icons.add_circle_outline_rounded, color: e.type.color, size: 16),
                    ]),
                  ),
                ),
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(top: 6), child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 13, color: kTextMid),
              const SizedBox(width: 6),
              Text('No ${e.type.label} found for "${e.searchText}"',
                  style: const TextStyle(fontSize: 12, color: kTextMid)),
            ])),
        ],
      ],
    ]);
  }

  Widget _txtField(String label, String hint, TextEditingController ctrl,
      {required ValueChanged<String> onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label), _vg(6),
        TextField(
          controller: ctrl, onChanged: onChanged,
          style: const TextStyle(fontSize: 14, color: kTextDark),
          decoration: _ideco(hint),
        ),
      ]);

  Widget _dropField(String label, String value, List<String> opts,
      ValueChanged<String?> cb) {
    final safe = opts.contains(value) ? value : opts.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label), _vg(6),
      DropdownButtonFormField<String>(
        value: safe, isExpanded: true,
        items: opts.map((o) => DropdownMenuItem(
            value: o,
            child: Text(o,
                style: const TextStyle(fontSize: 13),
                overflow: TextOverflow.ellipsis))).toList(),
        onChanged: cb,
        decoration: _ideco('').copyWith(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        ),
        dropdownColor: kCardBg,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMid, size: 18),
      ),
    ]);
  }

  Widget _r2(List<Widget> ch) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [Expanded(child: ch[0]), const SizedBox(width: 10), Expanded(child: ch[1])],
  );

  Widget _lbl(String t) => Text(t, style: const TextStyle(
    fontSize: 12, fontWeight: FontWeight.w600, color: kTextMid, letterSpacing: 0.1,
  ));

  Widget _vg(double h) => SizedBox(height: h);

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 13, color: Color(0xFFB0B8C8)),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: kPrimary, width: 1.5)),
  );
}

// ════════════════════════════════════════════════════════════════════
//  _TypePill
// ════════════════════════════════════════════════════════════════════
class _TypePill extends StatelessWidget {
  final MedicineType value;
  final ValueChanged<MedicineType> onChanged;
  const _TypePill({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kCardBg, borderRadius: BorderRadius.circular(8),
        border: Border.all(color: value.color.withOpacity(0.4)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<MedicineType>(
          value: value, isDense: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, size: 15, color: value.color),
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: value.color),
          dropdownColor: kCardBg,
          items: MedicineType.values.map((t) => DropdownMenuItem(
            value: t,
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(t.icon, size: 14, color: t.color),
              const SizedBox(width: 5),
              Text(t.label, style: TextStyle(
                color: t.color, fontSize: 12, fontWeight: FontWeight.w600,
              )),
            ]),
          )).toList(),
          onChanged: (v) { if (v != null) onChanged(v); },
        ),
      ),
    );
  }
}
