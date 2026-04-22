


import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

// ════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — aligned with PatientListScreen
// ════════════════════════════════════════════════════════════════════
const kPrimary        = Color(0xFF26C6B0);
const kPrimaryDark    = Color(0xFF2BB5A0);
const kPrimaryLight   = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);
const _kGradFrom      = Color(0xFF4DD9C8);
const _kGradTo        = Color(0xFF2BB5A0);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);
const kBg      = Color(0xFFF7F8FA);
const kCardBg  = Colors.white;

const kSuccess     = Color(0xFF68D391);
const kGreenLight  = Color(0xFFDCFCE7);
const kGreenDark   = Color(0xFF276749);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kRedDark  = Color(0xFFC53030);

const kAmberLight = Color(0xFFFEF3C7);
const kAmberDark  = Color(0xFF975A16);
const kWarning    = Color(0xFFF6AD55);

const kPurple      = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kPurpleDark  = Color(0xFF6B46C1);

const kInfo      = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);
const kInfoDark  = Color(0xFF1E40AF);

// ════════════════════════════════════════════════════════════════════
//  BREAKPOINTS
// ════════════════════════════════════════════════════════════════════
const _kTabletBreak  = 650.0;
const _kDesktopBreak = 1050.0;

// ════════════════════════════════════════════════════════════════════
//  MEDICINE TYPE
// ════════════════════════════════════════════════════════════════════
enum MedicineType { tablet, syrup, injection, drops, lotion, spray }

extension MedTypeX on MedicineType {
  String get label => const {
    MedicineType.tablet:    'Tablet',
    MedicineType.syrup:     'Syrup',
    MedicineType.injection: 'Injection',
    MedicineType.drops:     'Drops',
    MedicineType.lotion:    'Lotion',
    MedicineType.spray:     'Spray',
  }[this]!;

  IconData get icon => const {
    MedicineType.tablet:    Icons.medication_rounded,
    MedicineType.syrup:     Icons.local_drink_rounded,
    MedicineType.injection: Icons.vaccines_rounded,
    MedicineType.drops:     Icons.water_drop_rounded,
    MedicineType.lotion:    Icons.soap_rounded,
    MedicineType.spray:     Icons.air_rounded,
  }[this]!;

  Color get color => const {
    MedicineType.tablet:    Color(0xFF26C6B0),
    MedicineType.syrup:     Color(0xFF9F7AEA),
    MedicineType.injection: Color(0xFFFC8181),
    MedicineType.drops:     Color(0xFF3B82F6),
    MedicineType.lotion:    Color(0xFF68D391),
    MedicineType.spray:     Color(0xFFF6AD55),
  }[this]!;

  Color get colorLight => const {
    MedicineType.tablet:    Color(0xFFD9F5F1),
    MedicineType.syrup:     Color(0xFFEDE9FE),
    MedicineType.injection: Color(0xFFFEE2E2),
    MedicineType.drops:     Color(0xFFDBEAFE),
    MedicineType.lotion:    Color(0xFFDCFCE7),
    MedicineType.spray:     Color(0xFFFEF3C7),
  }[this]!;

  Color get colorDark => const {
    MedicineType.tablet:    Color(0xFF2BB5A0),
    MedicineType.syrup:     Color(0xFF6B46C1),
    MedicineType.injection: Color(0xFFC53030),
    MedicineType.drops:     Color(0xFF1E40AF),
    MedicineType.lotion:    Color(0xFF276749),
    MedicineType.spray:     Color(0xFF975A16),
  }[this]!;

  int get typeId => index + 1;
}

// ════════════════════════════════════════════════════════════════════
//  PICKER OPTIONS
// ════════════════════════════════════════════════════════════════════
const _kDosageOpts = {
  'tablet':    ['0', '¼', '½', '¾', '1', '1½', '2', '3'],
  'syrup':     ['0', '2.5ml', '5ml', '7.5ml', '10ml', '15ml', '20ml'],
  'injection': ['0', '0.5', '1', '2', '4', '5', '10'],
  'drops':     ['0', '1', '2', '3', '4', '5', '6'],
  'lotion':    ['0', 'Apply', 'Thin layer', 'Thick layer'],
  'spray':     ['0', '1 puff', '2 puffs', '3 puffs', '4 puffs'],
};

// ════════════════════════════════════════════════════════════════════
//  MedicineEntry
// ════════════════════════════════════════════════════════════════════
class MedicineEntry {
  MedicineType type;
  int?    medicineId;
  String? selectedName;
  String  searchText;
  String  dosage;
  String  frequency;
  String  duration;
  String  timing;
  String  injRoute;
  String  dropsApplication;
  String  lotionApplyArea;
  String  sprayUsage;

  MedicineEntry()
      : type             = MedicineType.tablet,
        medicineId       = null,
        selectedName     = null,
        searchText       = '',
        dosage           = '1-0-1',
        frequency        = '1-0-1',
        duration         = '',
        timing           = 'After Food',
        injRoute         = 'IV',
        dropsApplication = 'Eyes',
        lotionApplyArea  = '',
        sprayUsage       = 'Nasal';

  PrescriptionMedicineModel toApiModel() => PrescriptionMedicineModel(
    medicineId:       medicineId,
    medicineTypeId:   type.typeId,
    frequency:        frequency.isEmpty ? null : frequency,
    duration:         duration.isEmpty  ? null : duration,
    timing:           timing.isEmpty    ? null : timing,
    tabletDosage:     type == MedicineType.tablet    ? (dosage.isEmpty ? null : dosage) : null,
    syrupDosageMl:    type == MedicineType.syrup     ? (dosage.isEmpty ? null : dosage) : null,
    injDosage:        type == MedicineType.injection ? (dosage.isEmpty ? null : dosage) : null,
    injRoute:         type == MedicineType.injection ? (injRoute.isEmpty ? null : injRoute) : null,
    dropsCount:       type == MedicineType.drops     ? (dosage.isEmpty ? null : dosage) : null,
    dropsApplication: type == MedicineType.drops     ? (dropsApplication.isEmpty ? null : dropsApplication) : null,
    lotionApplyArea:  type == MedicineType.lotion    ? (lotionApplyArea.isEmpty ? null : lotionApplyArea) : null,
    sprayPuffs:       type == MedicineType.spray     ? (dosage.isEmpty ? null : dosage) : null,
    sprayUsage:       type == MedicineType.spray     ? (sprayUsage.isEmpty ? null : sprayUsage) : null,
    lotionUsage:      type == MedicineType.lotion    ? (dosage.isEmpty ? null : dosage) : null,
  );
}

// ════════════════════════════════════════════════════════════════════
//  SlotPickerField
// ════════════════════════════════════════════════════════════════════
class SlotPickerField extends StatefulWidget {
  final String label;
  final String subLabel;
  final String typeKey;
  final Color  accentColor;
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

  List<String> get _opts => widget.optsMap[widget.typeKey] ?? widget.optsMap['tablet']!;

  @override
  void initState() { super.initState(); _committed = _parse(widget.initialValue); }

  @override
  void didUpdateWidget(SlotPickerField old) {
    super.didUpdateWidget(old);
    if (old.typeKey != widget.typeKey || old.initialValue != widget.initialValue) {
      setState(() => _committed = _parse(widget.initialValue));
    }
  }

  List<String> _parse(String v) {
    final parts = v.split('-');
    if (parts.length >= 3) return [parts[0], parts[1], parts[2]];
    final o   = _opts;
    final def = o.length > 1 ? o[1] : o[0];
    return [def, '0', def];
  }

  String get _display => _committed.join(' – ');

  void _onSet(List<String> vals) {
    setState(() { _committed = List.from(vals); _open = false; });
    widget.onChanged(vals.join('-'));
  }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(widget.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary, letterSpacing: 0.1)),
        const SizedBox(width: 4),
        Text('(${widget.subLabel})', style: const TextStyle(fontSize: 10, color: kTextMuted)),
      ]),
      const SizedBox(height: 5),
      GestureDetector(
        onTap: () => setState(() => _open = !_open),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kBg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _open ? ac : kBorder, width: _open ? 1.5 : 1.0),
          ),
          child: Row(children: [
            Expanded(child: Text(_display, style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: ac))),
            Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: kTextMuted, size: 18),
          ]),
        ),
      ),
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 200),
        child: _open
            ? _InlineDrumPanel(
                key: ValueKey('${widget.typeKey}_${widget.label}'),
                opts: _opts, draft: List.from(_committed),
                accentColor: ac, onSet: _onSet,
                onDismiss: () => setState(() => _open = false),
              )
            : const SizedBox.shrink(),
      ),
    ]);
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
    required this.opts, required this.draft,
    required this.accentColor, required this.onSet, required this.onDismiss,
  });

  @override
  State<_InlineDrumPanel> createState() => _InlineDrumPanelState();
}

class _InlineDrumPanelState extends State<_InlineDrumPanel> {
  late List<String> _sel;

  @override
  void initState() { super.initState(); _sel = List.from(widget.draft); }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return Container(
      margin: const EdgeInsets.only(top: 5),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: ac.withOpacity(0.22)),
        boxShadow: [BoxShadow(color: ac.withOpacity(0.07), blurRadius: 14, offset: const Offset(0, 4))],
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: ac.withOpacity(0.07),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(11)),
          ),
          child: Row(children: [
            Icon(Icons.tune_rounded, color: ac, size: 13),
            const SizedBox(width: 5),
            Text('Select per slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: ac)),
            const Spacer(),
            GestureDetector(onTap: widget.onDismiss,
                child: const Icon(Icons.close_rounded, color: kTextMuted, size: 15)),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Row(children: [
            _slotLbl('Morning'), const SizedBox(width: 16),
            _slotLbl('Afternoon'), const SizedBox(width: 16),
            _slotLbl('Night'),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(child: _DrumPicker(opts: widget.opts, selected: _sel[0], accentColor: ac,
                onChanged: (v) => setState(() => _sel[0] = v))),
            Text('–', style: TextStyle(fontSize: 18, color: kTextMuted)),
            Expanded(child: _DrumPicker(opts: widget.opts, selected: _sel[1], accentColor: ac,
                onChanged: (v) => setState(() => _sel[1] = v))),
            Text('–', style: TextStyle(fontSize: 18, color: kTextMuted)),
            Expanded(child: _DrumPicker(opts: widget.opts, selected: _sel[2], accentColor: ac,
                onChanged: (v) => setState(() => _sel[2] = v))),
          ]),
        ),
        const Divider(height: 1, color: kBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => widget.onSet(_sel),
              style: ElevatedButton.styleFrom(
                backgroundColor: ac, foregroundColor: Colors.white, elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text('Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ]),
    );
  }

  Widget _slotLbl(String t) => Expanded(child: Text(t, textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 10, color: kTextMuted, fontWeight: FontWeight.w500)));
}

// ════════════════════════════════════════════════════════════════════
//  _DrumPicker
// ════════════════════════════════════════════════════════════════════
class _DrumPicker extends StatefulWidget {
  final List<String> opts;
  final String selected;
  final Color accentColor;
  final ValueChanged<String> onChanged;

  const _DrumPicker({required this.opts, required this.selected,
      required this.accentColor, required this.onChanged});

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
      if (idx >= 0) _ctrl.animateToItem(idx,
          duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final ac = widget.accentColor;
    return SizedBox(
      height: 110,
      child: Stack(alignment: Alignment.center, children: [
        Container(height: 36, margin: const EdgeInsets.symmetric(horizontal: 4),
            decoration: BoxDecoration(color: ac.withOpacity(0.10), borderRadius: BorderRadius.circular(7))),
        Positioned(top: 0, left: 0, right: 0, height: 37,
          child: IgnorePointer(child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [kCardBg, kCardBg.withOpacity(0)]),
          ))),
        ),
        Positioned(bottom: 0, left: 0, right: 0, height: 37,
          child: IgnorePointer(child: Container(decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter,
                colors: [kCardBg, kCardBg.withOpacity(0)]),
          ))),
        ),
        ListWheelScrollView.useDelegate(
          controller: _ctrl, itemExtent: 37, diameterRatio: 1.8,
          physics: const FixedExtentScrollPhysics(),
          onSelectedItemChanged: (i) => widget.onChanged(widget.opts[i]),
          childDelegate: ListWheelChildBuilderDelegate(
            childCount: widget.opts.length,
            builder: (_, i) {
              final isSel = widget.opts[i] == widget.selected;
              return Center(child: Text(widget.opts[i], style: TextStyle(
                fontSize: isSel ? 18 : 13,
                fontWeight: isSel ? FontWeight.w700 : FontWeight.w400,
                color: isSel ? ac : kTextMuted,
              )));
            },
          ),
        ),
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  _CompleteDropdown — split action button
// ════════════════════════════════════════════════════════════════════
class _CompleteDropdown extends StatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onBack;
  const _CompleteDropdown({required this.onNext, required this.onBack});

  @override
  State<_CompleteDropdown> createState() => _CompleteDropdownState();
}

class _CompleteDropdownState extends State<_CompleteDropdown> {
  int _selected = 0;

  static const _options = [
    (icon: Icons.arrow_forward_rounded, label: 'Complete & Next'),
    (icon: Icons.arrow_back_rounded,    label: 'Complete & Back'),
  ];

  VoidCallback get _action => _selected == 0 ? widget.onNext : widget.onBack;

  @override
  Widget build(BuildContext context) {
    final opt = _options[_selected];
    return Row(children: [
      Expanded(
        child: ElevatedButton(
          onPressed: _action,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary, foregroundColor: Colors.white, elevation: 0,
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.only(
              topLeft: Radius.circular(10), bottomLeft: Radius.circular(10),
            )),
            padding: const EdgeInsets.symmetric(vertical: 13),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(opt.label, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
            const SizedBox(width: 4),
            Icon(opt.icon, size: 14),
          ]),
        ),
      ),
      Container(width: 1, height: 46, color: Colors.white.withOpacity(0.3)),
      PopupMenuButton<int>(
        onSelected: (v) => setState(() => _selected = v),
        padding: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        color: Colors.white,
        offset: const Offset(0, -110),
        itemBuilder: (_) => [
          _menuItem(0, Icons.arrow_forward_rounded, 'Complete & Next'),
          _menuItem(1, Icons.arrow_back_rounded,    'Complete & Back'),
        ],
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: const BoxDecoration(
            color: kPrimary,
            borderRadius: BorderRadius.only(
              topRight: Radius.circular(10), bottomRight: Radius.circular(10),
            ),
          ),
          child: const Icon(Icons.keyboard_arrow_up_rounded, color: Colors.white, size: 18),
        ),
      ),
    ]);
  }

  PopupMenuItem<int> _menuItem(int value, IconData icon, String label) {
    final isActive = _selected == value;
    return PopupMenuItem<int>(
      value: value,
      child: Row(children: [
        Icon(icon, size: 15, color: isActive ? kPrimary : kTextMuted),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(
          fontSize: 13, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
          color: isActive ? kPrimary : kTextPrimary,
        )),
        if (isActive) ...[
          const Spacer(),
          const Icon(Icons.check_rounded, size: 13, color: kPrimary),
        ],
      ]),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  PrescriptionScreen
// ════════════════════════════════════════════════════════════════════
class PrescriptionScreen extends ConsumerStatefulWidget {
  final int     patientId;
  final int     doctorId;
  final int     userTypeId;
  final int     appointmentId;
  final String  patientName;
  final String? patientAge;
  final String? patientGender;
  final int?    queueNumber;
  final String  patientStatus;
  final String? symptoms;

  const PrescriptionScreen({
    super.key,
    required this.patientId,
    required this.doctorId,
    required this.userTypeId,
    required this.appointmentId,
    required this.patientName,
    this.patientAge,
    this.patientGender,
    this.queueNumber,
    this.patientStatus = 'booked',
    this.symptoms,
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
  late final ProviderSubscription<int?> _doctorIdSub;

  // @override
  // void initState() {
  //   super.initState();
  //   _doctorIdSub = ref.listenManual<int?>(
  //     doctorLoginViewModelProvider.select((s) => s.doctorId),
  //     (_, next) => _maybeFetchMedicines(next ?? 0),
  //   );
  //   WidgetsBinding.instance.addPostFrameCallback((_) {
  //     if (mounted) _maybeFetchMedicines(widget.doctorId);
  //   });
  // }

  @override
  void initState() {
    super.initState();
    if (widget.symptoms != null && widget.symptoms!.trim().isNotEmpty) {
      _sympCtrl.text = widget.symptoms!.trim();
    }
 
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) => _maybeFetchMedicines(next ?? 0),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeFetchMedicines(widget.doctorId);
    });
  }
 
  @override
  void dispose() {
    _sympCtrl.dispose(); _diagCtrl.dispose();
    _clinCtrl.dispose(); _advCtrl.dispose();
    _doctorIdSub.close();
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
    for (int i = 0; i < _meds.length; i++) {
      if (_meds[i].selectedName == null || _meds[i].medicineId == null)
        return 'Please select medicine name for Medicine ${i + 1}';
    }
    return null;
  }

  String _todayApi() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  String? _ageString(String? dob) {
    if (dob == null || dob.trim().isEmpty) return null;
    final dt = DateTime.tryParse(dob.trim());
    if (dt == null) return null;
    final now = DateTime.now();
    int age = now.year - dt.year;
    if (now.month < dt.month || (now.month == dt.month && now.day < dt.day)) age--;
    return '$age y';
  }

  String? _followUpStr() {
    if (_followDate == null) return null;
    return '${_followDate!.year}-${_followDate!.month.toString().padLeft(2, '0')}-${_followDate!.day.toString().padLeft(2, '0')}';
  }

  PrescriptionModel _buildPrescription() => PrescriptionModel(
    patientId:     widget.patientId,
    doctorId:      widget.doctorId,
    symptoms:      _sympCtrl.text.trim(),
    diagnosis:     _diagCtrl.text.trim(),
    clinicalNotes: _clinCtrl.text.trim().isEmpty ? null : _clinCtrl.text.trim(),
    userType:      widget.userTypeId,
    appointmentId: widget.appointmentId,
    followUpDate:  _followUpStr(),
    advice:        _advCtrl.text.trim().isEmpty ? null : _advCtrl.text.trim(),
    medicines:     _meds.map((e) => e.toApiModel()).toList(),
  );

  Future<AppointmentResponseModel?> _completeQueueAction() async {
    try {
      final isSkipped = widget.patientStatus.toLowerCase().trim() == 'skipped';
      final AppointmentResponseModel result;
      if (isSkipped) {
        result = await ref.read(appointmentViewModelProvider.notifier)
            .queueRecall(AppointmentRequestModel(
              appointmentId: widget.appointmentId, doctorId: widget.doctorId));
      } else {
        result = await ref.read(appointmentViewModelProvider.notifier)
            .queueNext(AppointmentRequestModel(
              operation:       'QUEUE_NEXT',
              doctorId:        widget.doctorId,
              appointmentId:   widget.appointmentId,
              patientId:       widget.patientId,
              appointmentDate: _todayApi(),
            ));
      }
      if (result.success == true) return result;
      _showSnack(result.message ?? 'Queue action failed', isError: true);
      return null;
    } catch (e) {
      _showSnack(e.toString().replaceFirst('Exception: ', ''), isError: true);
      return null;
    }
  }

  Future<void> _handleNextPatient() async {
    final result = await _completeQueueAction();
    if (!mounted || result == null) return;

    if (widget.patientStatus.toLowerCase().trim() == 'skipped') {
      _showSnack(result.message ?? 'Patient attended', isError: false);
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted) Navigator.pop(context);
      return;
    }

    final nextToken = result.data?.isNotEmpty == true ? result.data!.first.nextToken : null;

    await ref.read(appointmentViewModelProvider.notifier)
        .fetchPatientAppointments(widget.doctorId);
    if (!mounted) return;

    final all = ref.read(appointmentViewModelProvider).patientAppointmentsList
        .maybeWhen(data: (l) => l, orElse: () => const <AppointmentList>[]);

    final next = _pickNextAppointment(all, preferredQueue: nextToken);
    if (next == null) {
      _showSnack('No next patient found', isError: true);
      Navigator.pop(context);
      return;
    }

    _showSnack('Prescription saved. Opening next patient…', isError: false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;

    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PrescriptionScreen(
      patientId:     next.patientId     ?? 0,
      doctorId:      next.doctorId      ?? widget.doctorId,
      userTypeId:    next.userType      ?? widget.userTypeId,
      appointmentId: next.appointmentId ?? 0,
      patientName:   next.patientName   ?? 'Patient',
      patientAge:    _ageString(next.dob),
      patientGender: next.gender,
      queueNumber:   next.queueNumber,
    )));
  }

  AppointmentList? _pickNextAppointment(List<AppointmentList> list, {int? preferredQueue}) {
    final inProgress = list.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return s == 'in_progress' && a.appointmentId != widget.appointmentId
          && _isToday(_parseDate(a.appointmentDate));
    }).toList();
    if (inProgress.isNotEmpty) {
      inProgress.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
      return inProgress.first;
    }
    final candidates = list.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return s == 'booked' && _isToday(_parseDate(a.appointmentDate))
          && a.appointmentId != widget.appointmentId;
    }).toList();
    if (preferredQueue != null) {
      final match = candidates.where((a) => a.queueNumber == preferredQueue).toList();
      if (match.isNotEmpty) return match.first;
    }
    candidates.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return candidates.isEmpty ? null : candidates.first;
  }

  int _sortKey(AppointmentList a) {
    if (a.queueNumber != null) return a.queueNumber!;
    final dt = a.startTime == null ? null : DateTime.tryParse(a.startTime!);
    if (dt != null) return 100000 + dt.hour * 60 + dt.minute;
    return 200000;
  }

  DateTime? _parseDate(String? s) => s == null ? null : DateTime.tryParse(s.trim());

  bool _isToday(DateTime? d) {
    if (d == null) return false;
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  Future<void> _completePrescription() async {
    final error = _validate();
    if (error != null) { _showSnack(error, isError: true); return; }
    await ref.read(prescriptionViewModelProvider.notifier).insertPrescription(_buildPrescription());
    if (!mounted) return;
    final state = ref.read(prescriptionViewModelProvider);
    if (state.error != null) { _showSnack(state.error!, isError: true); return; }
    await _handleNextPatient();
  }

  Future<void> _completeAndBack() async {
    final error = _validate();
    if (error != null) { _showSnack(error, isError: true); return; }
    await ref.read(prescriptionViewModelProvider.notifier).insertPrescription(_buildPrescription());
    if (!mounted) return;
    final state = ref.read(prescriptionViewModelProvider);
    if (state.error != null) { _showSnack(state.error!, isError: true); return; }
    try {
      await ref.read(appointmentViewModelProvider.notifier).endSession(
        AppointmentRequestModel(doctorId: widget.doctorId,
            appointmentId: widget.appointmentId, patientId: widget.patientId));
    } catch (_) {}
    if (!mounted) return;
    _showSnack('Prescription saved', isError: false);
    await Future.delayed(const Duration(milliseconds: 300));
    if (mounted) Navigator.pop(context);
  }

  Future<void> _onSkip() async {
    try {
      await ref.read(appointmentViewModelProvider.notifier).queueSkip(
        AppointmentRequestModel(doctorId: widget.doctorId,
            appointmentId: widget.appointmentId, patientId: widget.patientId,
            isNext: 1));
      if (!mounted) return;
      await ref.read(appointmentViewModelProvider.notifier)
          .fetchPatientAppointments(widget.doctorId);
      if (!mounted) return;
      final all = ref.read(appointmentViewModelProvider).patientAppointmentsList
          .maybeWhen(data: (l) => l, orElse: () => <AppointmentList>[]);
      final next = _pickNextAppointment(all);
      if (next == null) { _showSnack('No next patient', isError: false); Navigator.pop(context); return; }
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => PrescriptionScreen(
        patientId:     next.patientId     ?? 0,
        doctorId:      next.doctorId      ?? widget.doctorId,
        userTypeId:    next.userType      ?? widget.userTypeId,
        appointmentId: next.appointmentId ?? 0,
        patientName:   next.patientName   ?? 'Patient',
        patientAge:    _ageString(next.dob),
        patientGender: next.gender,
        queueNumber:   next.queueNumber,
        patientStatus: next.status ?? 'booked',
      )));
    } catch (e) { _showSnack('Skip failed: $e', isError: true); }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Row(children: [
        Icon(
          isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
          color: Colors.white, size: 14,
        ),
        const SizedBox(width: 7),
        Expanded(child: Text(msg, style: const TextStyle(fontSize: 13, color: Colors.white))),
      ]),
      backgroundColor: isError ? kError : kPrimary,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      duration: const Duration(seconds: 2),
    ));
  }

  double get _width => MediaQuery.of(context).size.width;
  bool get _isDesktop => _width >= _kDesktopBreak;
  bool get _isTablet  => _width >= _kTabletBreak;

  @override
  Widget build(BuildContext context) {
    final state       = ref.watch(prescriptionViewModelProvider);
    final doctorState = ref.watch(doctorLoginViewModelProvider);
    final medicines   = doctorState.medicines?.value ?? const <Medicine>[];

    return Stack(children: [
      Scaffold(
        backgroundColor: kBg,
        body: Column(children: [
          _buildHeader(),
          Expanded(
            child: _isDesktop
                ? _desktopBody(medicines)
                : _mobileBody(medicines),
          ),
        ]),
      ),
      if (state.isLoading)
        Container(
          color: Colors.black.withOpacity(0.28),
          child: const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5)),
        ),
    ]);
  }

  // ── Header — matches PatientListScreen header exactly ────────────
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: kBorder, width: 1)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(children: [
          // Back button
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: kTextPrimary, size: 15),
            ),
          ),
          const SizedBox(width: 10),
          // Icon badge — same 34×34 style as PatientListScreen
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kPrimary.withOpacity(0.2)),
            ),
            child: const Icon(Icons.description_outlined, color: kPrimary, size: 16),
          ),
          const SizedBox(width: 8),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('New Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
              SizedBox(height: 1),
              Text('Fill in consultation details', style: TextStyle(fontSize: 11, color: kTextSecondary)),
            ]),
          ),
          IconButton(icon: const Icon(Icons.help_outline_rounded, color: kTextMuted, size: 18), onPressed: () {}),
        ]),
      ),
    ),
  );

  // ── Desktop — 3-column ───────────────────────────────────────────
  Widget _desktopBody(List<Medicine> medicines) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Left: Patient info + text fields
      SizedBox(
        width: 300,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(right: BorderSide(color: kBorder)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _patientCard(), _gap(12),
              _textSection('Symptoms *', _sympCtrl, 'Enter patient symptoms…'), _gap(10),
              _textSection('Diagnosis *', _diagCtrl, 'Enter diagnosis…'), _gap(10),
              _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'),
            ],
          ),
        ),
      ),
      // Center: Medicines
      Expanded(
        child: Stack(children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [
              _medicinesHeader(), _gap(10),
              ..._buildMedCards(medicines),
              if (_meds.isEmpty) _emptyMeds(),
            ],
          ),
          _bottomBar(),
        ]),
      ),
      // Right: Follow-up & advice
      SizedBox(
        width: 260,
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(left: BorderSide(color: kBorder)),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 100),
            children: [_followUpCard()],
          ),
        ),
      ),
    ],
  );

  // ── Tablet — 2-column ────────────────────────────────────────────
  Widget _mobileBody(List<Medicine> medicines) {
    if (_isTablet) {
      return Stack(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            flex: 4,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 14, 10, 110),
              children: [
                _patientCard(), _gap(12),
                _textSection('Symptoms *', _sympCtrl, 'Enter patient symptoms…'), _gap(10),
                _textSection('Diagnosis *', _diagCtrl, 'Enter diagnosis…'), _gap(10),
                _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'), _gap(10),
                _followUpCard(),
              ],
            ),
          ),
          Expanded(
            flex: 5,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(10, 14, 16, 110),
              children: [
                _medicinesHeader(), _gap(10),
                ..._buildMedCards(medicines),
                if (_meds.isEmpty) _emptyMeds(),
              ],
            ),
          ),
        ]),
        _bottomBar(),
      ]);
    }
    // Mobile — single column
    return Stack(children: [
      ListView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
        children: [
          _patientCard(), _gap(12),
          _textSection('Symptoms *', _sympCtrl, 'Enter patient symptoms…'), _gap(10),
          _textSection('Diagnosis *', _diagCtrl, 'Enter diagnosis…'), _gap(10),
          _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'), _gap(12),
          _medicinesHeader(), _gap(10),
          ..._buildMedCards(medicines),
          if (_meds.isEmpty) _emptyMeds(),
          _gap(12),
          _followUpCard(),
        ],
      ),
      _bottomBar(),
    ]);
  }

  // ── Patient Card — matches PatientListScreen card style ──────────
  Widget _patientCard() {
    final inits = widget.patientName.trim().split(' ').take(2)
        .map((w) => w.isNotEmpty ? w[0] : '').join().toUpperCase();
    return _card(child: Row(children: [
      Container(
        width: 44, height: 44,
        decoration: const BoxDecoration(
          gradient: LinearGradient(colors: [_kGradFrom, _kGradTo],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
          shape: BoxShape.circle,
        ),
        alignment: Alignment.center,
        child: Text(inits, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.patientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Wrap(spacing: 5, runSpacing: 4, children: [
          if (widget.patientAge != null)    _chip(widget.patientAge!, bg: kInfoLight, fg: kInfoDark),
          if (widget.patientGender != null) _chip(widget.patientGender!, bg: kPrimaryLighter, fg: kPrimaryDark),
          if (widget.queueNumber != null)   _chip('Queue #${widget.queueNumber}', bg: kPrimaryLight, fg: kPrimaryDark),
        ]),
      ])),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(color: kGreenLight, borderRadius: BorderRadius.circular(8)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(color: kSuccess, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          const Text('Active', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kGreenDark)),
        ]),
      ),
    ]));
  }

  Widget _textSection(String label, TextEditingController ctrl, String hint) =>
      _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secLabel(label), _gap(8),
        TextField(
          controller: ctrl, maxLines: 3,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
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
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_kGradFrom, _kGradTo],
                begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.add_rounded, color: Colors.white, size: 15),
            SizedBox(width: 5),
            Text('Add Medicine', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ),
      ),
    ],
  );

  List<Widget> _buildMedCards(List<Medicine> medicines) => List.generate(_meds.length, (i) =>
    Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _MedCard(
        index: i, entry: _meds[i], medicines: medicines,
        onDelete: () => _delMed(i),
        rebuild: () => setState(() {}),
      ),
    ),
  );

  Widget _emptyMeds() => _card(child: Center(child: Padding(
    padding: const EdgeInsets.symmetric(vertical: 22),
    child: Column(children: [
      Container(
        width: 48, height: 48,
        decoration: BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
        child: const Icon(Icons.medication_outlined, color: kPrimary, size: 22),
      ),
      const SizedBox(height: 8),
      const Text('No medicines added yet', style: TextStyle(color: kTextSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
      const SizedBox(height: 3),
      const Text('Tap "+ Add Medicine" above', style: TextStyle(color: kTextMuted, fontSize: 11)),
    ]),
  )));

  Widget _followUpCard() => _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _secLabel('Follow-up & Advice'), _gap(12),
    GestureDetector(
      onTap: _pickDate,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: kBorder)),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(7)),
            child: const Icon(Icons.event_rounded, color: kPrimary, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(
            _followDate == null
                ? 'Select follow-up date'
                : '${_followDate!.day.toString().padLeft(2, '0')}/${_followDate!.month.toString().padLeft(2, '0')}/${_followDate!.year}',
            style: TextStyle(
              fontSize: 13,
              color: _followDate == null ? kTextMuted : kTextPrimary,
              fontWeight: _followDate == null ? FontWeight.w400 : FontWeight.w600,
            ),
          )),
          const Icon(Icons.arrow_drop_down_rounded, color: kTextMuted, size: 20),
        ]),
      ),
    ),
    _gap(10),
    TextField(
      controller: _advCtrl, maxLines: 3,
      style: const TextStyle(fontSize: 13, color: kTextPrimary),
      decoration: _ideco('Advice / instructions for patient…'),
    ),
  ]));

  // ── Bottom Action Bar ────────────────────────────────────────────
  Widget _bottomBar() {
    final isLoading = ref.watch(prescriptionViewModelProvider).isLoading;
    return Positioned(
      bottom: 0, left: 0, right: 0,
      child: Container(
        padding: EdgeInsets.fromLTRB(14, 10, 14, MediaQuery.of(context).padding.bottom + 10),
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: kBorder)),
          boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 16, offset: Offset(0, -3))],
        ),
        child: Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: isLoading ? null : _onSkip,
              icon: const Icon(Icons.skip_next_rounded, size: 15, color: kAmberDark),
              label: const Text('Skip & Next', style: TextStyle(color: kAmberDark, fontWeight: FontWeight.w700, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kAmberLight, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 13),
                backgroundColor: kAmberLight,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            flex: 3,
            child: isLoading
                ? Container(
                    height: 46,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [_kGradFrom, _kGradTo],
                          begin: Alignment.topLeft, end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    alignment: Alignment.center,
                    child: const SizedBox(height: 18, width: 18,
                        child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)),
                  )
                : _CompleteDropdown(onNext: _completePrescription, onBack: _completeAndBack),
          ),
        ]),
      ),
    );
  }

  // ── Shared helpers ───────────────────────────────────────────────
  Widget _card({required Widget child}) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
      boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
    ),
    child: child,
  );

  Widget _gap(double h) => SizedBox(height: h);

  Widget _secLabel(String t, {bool bare = false}) => Row(children: [
    Container(width: 3, height: 14, decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 7),
    Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary, letterSpacing: -0.2)),
  ]);

  Widget _chip(String t, {required Color bg, required Color fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
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

  void _disposeControllers() { _durCtrl.dispose(); _areaCtrl.dispose(); }

  String _freqFromDosage(String dosage) {
    final parts = dosage.split('-');
    if (parts.length < 3) return e.frequency;
    return parts.map((p) => p == '0' ? '0' : '1').join('-');
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

  static const _timingOpts = ['After Food', 'Before Food', 'With Food', 'Empty Stomach', 'At Bedtime', 'As Directed'];
  static const _routeOpts  = ['IV', 'IM', 'SC', 'Intradermal'];
  static const _appOpts    = ['Eyes', 'Ears', 'Nose', 'Both Eyes', 'Both Ears'];
  static const _sprayUsage = ['Nasal', 'Oral (Inhaler)', 'Throat'];

  @override
  Widget build(BuildContext context) {
    final tc = e.type.color;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tc.withOpacity(0.30), width: 1.2),
        boxShadow: [BoxShadow(color: tc.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, 2))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(tc),
        Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 14), child: _body()),
      ]),
    );
  }

  Widget _header(Color tc) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: tc.withOpacity(0.07),
      borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
    ),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: tc.withOpacity(0.15), borderRadius: BorderRadius.circular(7)),
        child: Icon(e.type.icon, color: tc, size: 14),
      ),
      const SizedBox(width: 9),
      Text('Medicine ${widget.index + 1}',
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
      const SizedBox(width: 7),
      _TypePill(value: e.type, onChanged: _onTypeChange),
      const Spacer(),
      GestureDetector(
        onTap: widget.onDelete,
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(color: kRedLight, borderRadius: BorderRadius.circular(7)),
          child: const Icon(Icons.delete_outline_rounded, color: kError, size: 16),
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
      e.frequency = _freqFromDosage(val);
    }),
  );

  Widget _commonBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _gap(10),
    _dosagePicker(), _gap(10),
    _r2([
      _txtField('Duration', 'e.g. 5 days', _durCtrl, onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _injBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _gap(10),
    _dropField('Route', e.injRoute, _routeOpts, (v) => setState(() => e.injRoute = v!)),
    _gap(10), _dosagePicker(), _gap(10),
    _r2([
      _txtField('Duration', 'e.g. 3 days', _durCtrl, onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _dropsBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _gap(10),
    _dropField('Application', e.dropsApplication, _appOpts, (v) => setState(() => e.dropsApplication = v!)),
    _gap(10), _dosagePicker(label: 'Drops per slot'), _gap(10),
    _r2([
      _txtField('Duration', 'e.g. 5 days', _durCtrl, onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _lotionBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _gap(10),
    _txtField('Apply Area / Body Part', 'e.g. Scalp, Face', _areaCtrl, onChanged: (v) => e.lotionApplyArea = v),
    _gap(10), _dosagePicker(label: 'Application per slot'), _gap(10),
    _r2([
      _txtField('Duration', 'e.g. 7 days', _durCtrl, onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, ['Morning', 'Evening', 'Night', 'Morning & Night', 'As Directed'],
          (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _sprayBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    _nameSearch(), _gap(10),
    _dropField('Usage', e.sprayUsage, _sprayUsage, (v) => setState(() => e.sprayUsage = v!)),
    _gap(10), _dosagePicker(label: 'Puffs per slot'), _gap(10),
    _r2([
      _txtField('Duration', 'e.g. 7 days', _durCtrl, onChanged: (v) => e.duration = v),
      _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
    ]),
  ]);

  Widget _nameSearch() {
    final all = widget.medicines.where((m) => (m.medTypeId ?? 0) == e.type.typeId).toList();
    final filtered = e.searchText.isEmpty
        ? all
        : all.where((m) => (m.medicineName ?? '').toLowerCase().contains(e.searchText.toLowerCase())).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('Medicine Name  ·  ${e.type.label}'), _gap(5),
      if (all.isEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(color: kAmberLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: kAmberDark.withOpacity(0.3))),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, size: 13, color: kAmberDark),
            SizedBox(width: 6),
            Expanded(child: Text('No medicines found for this type.', style: TextStyle(fontSize: 11, color: kAmberDark))),
          ]),
        ),
      if (e.selectedName != null)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: e.type.colorLight,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: e.type.color.withOpacity(0.3)),
          ),
          child: Row(children: [
            Icon(e.type.icon, color: e.type.color, size: 15),
            const SizedBox(width: 8),
            Expanded(child: Text(e.selectedName!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
                overflow: TextOverflow.ellipsis)),
            GestureDetector(
              onTap: () => setState(() { e.selectedName = null; e.medicineId = null; e.searchText = ''; }),
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(color: kBorder, shape: BoxShape.circle),
                child: const Icon(Icons.close_rounded, size: 11, color: kTextSecondary),
              ),
            ),
          ]),
        )
      else ...[
        TextField(
          onChanged: (v) => setState(() => e.searchText = v),
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: _ideco('Search ${e.type.label} name…').copyWith(
            prefixIcon: Padding(padding: const EdgeInsets.symmetric(horizontal: 11),
                child: Icon(Icons.search_rounded, color: e.type.color, size: 16)),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
        if (e.searchText.isNotEmpty) ...[
          _gap(4),
          if (filtered.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ListView.separated(
                shrinkWrap: true, padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
                itemBuilder: (_, i) => InkWell(
                  onTap: () => setState(() {
                    e.selectedName = filtered[i].medicineName ?? '';
                    e.medicineId   = filtered[i].medicineId;
                    e.searchText   = '';
                  }),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(children: [
                      Icon(e.type.icon, color: e.type.color, size: 13),
                      const SizedBox(width: 9),
                      Expanded(child: Text(filtered[i].medicineName ?? '',
                          style: const TextStyle(fontSize: 12, color: kTextPrimary),
                          overflow: TextOverflow.ellipsis)),
                      Icon(Icons.add_circle_outline_rounded, color: e.type.color, size: 15),
                    ]),
                  ),
                ),
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: kTextMuted),
              const SizedBox(width: 5),
              Expanded(child: Text('No ${e.type.label} found for "${e.searchText}"',
                  style: const TextStyle(fontSize: 11, color: kTextMuted))),
            ])),
        ],
      ],
    ]);
  }

  Widget _txtField(String label, String hint, TextEditingController ctrl,
      {required ValueChanged<String> onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label), _gap(5),
        TextField(controller: ctrl, onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: kTextPrimary),
          decoration: _ideco(hint)),
      ]);

  Widget _dropField(String label, String value, List<String> opts, ValueChanged<String?> cb) {
    final safe = opts.contains(value) ? value : opts.first;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl(label), _gap(5),
      DropdownButtonFormField<String>(
        value: safe, isExpanded: true,
        items: opts.map((o) => DropdownMenuItem(value: o,
            child: Text(o, style: const TextStyle(fontSize: 12), overflow: TextOverflow.ellipsis))).toList(),
        onChanged: cb,
        decoration: _ideco('').copyWith(contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
        dropdownColor: Colors.white,
        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: kTextMuted, size: 17),
      ),
    ]);
  }

  Widget _r2(List<Widget> ch) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Expanded(child: ch[0]), const SizedBox(width: 8), Expanded(child: ch[1]),
  ]);

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: kTextSecondary, letterSpacing: 0.1));

  Widget _gap(double h) => SizedBox(height: h);

  InputDecoration _ideco(String hint) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
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
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: value.colorLight,
      borderRadius: BorderRadius.circular(7),
      border: Border.all(color: value.color.withOpacity(0.35)),
    ),
    child: DropdownButtonHideUnderline(
      child: DropdownButton<MedicineType>(
        value: value, isDense: true,
        icon: Icon(Icons.keyboard_arrow_down_rounded, size: 14, color: value.colorDark),
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: value.colorDark),
        dropdownColor: Colors.white,
        items: MedicineType.values.map((t) => DropdownMenuItem(
          value: t,
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(t.icon, size: 13, color: t.color),
            const SizedBox(width: 5),
            Text(t.label, style: TextStyle(color: t.colorDark, fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        )).toList(),
        onChanged: (v) { if (v != null) onChanged(v); },
      ),
    ),
  );
}