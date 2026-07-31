import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/navigation/navigator_key.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/appointment_response_model.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/domain/models/prescription.dart';
import 'package:qless/presentation/doctor/providers/doctor_usecase_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

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

// ════════════════════════════════════════════════════════════════════
//  DEFAULT SYMPTOMS LIST
// ════════════════════════════════════════════════════════════════════
const List<String> kDefaultSymptoms = [
  'Fever', 'Cough', 'Cold', 'Headache', 'Body ache', 'Sore throat',
  'Vomiting', 'Nausea', 'Diarrhea', 'Constipation', 'Abdominal pain',
  'Chest pain', 'Breathlessness', 'Fatigue', 'Weakness', 'Dizziness',
  'Loss of appetite', 'Joint pain', 'Back pain', 'Skin rash', 'Itching',
  'Burning urination', 'Weight loss', 'Weight gain', 'Anxiety',
  'Insomnia', 'Ear pain', 'Eye redness', 'Runny nose', 'Sneezing',
];

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
enum MedicineType { tablet, syrups, drops,injections, lotions,inhalers,sprays,powders}

extension MedTypeX on MedicineType {
  String get label => const {
    MedicineType.tablet:    'Tablet',
    MedicineType.syrups:     'Syrups',
      MedicineType.drops:     'Drops',
    MedicineType.injections: 'Injections',
    MedicineType.lotions:    'Lotions',
     MedicineType.inhalers:  'Inhalers',
    MedicineType.sprays:     'Sprays',
    MedicineType.powders:   'Powders',
   

  }[this]!;

  IconData get icon => const {
    MedicineType.tablet:    Icons.medication_rounded,
    MedicineType.syrups:     Icons.local_drink_rounded,
      MedicineType.drops:     Icons.water_drop_rounded,
    MedicineType.injections: Icons.vaccines_rounded,
  
    MedicineType.lotions:    Icons.soap_rounded,
     MedicineType.inhalers:  Icons.air_rounded,
    MedicineType.sprays:     Icons.air_rounded,
    MedicineType.powders:   Icons.grain_rounded,
   
  }[this]!;

  Color get color => const {
    MedicineType.tablet:    Color(0xFF26C6B0),
    MedicineType.syrups:     Color(0xFF9F7AEA),
        MedicineType.drops:     Color(0xFF3B82F6),
    MedicineType.injections: Color(0xFFFC8181),

    MedicineType.lotions:    Color(0xFF68D391),
        MedicineType.inhalers:  Color(0xFF1E40AF),
    MedicineType.sprays:     Color(0xFFF6AD55),
    MedicineType.powders:   Color(0xFF4DD9C8),

  }[this]!;

  Color get colorLight => const {
    MedicineType.tablet:    Color(0xFFD9F5F1),
    MedicineType.syrups:     Color(0xFFEDE9FE),
     MedicineType.drops:     Color(0xFFDBEAFE),
    MedicineType.injections: Color(0xFFFEE2E2),
   
    MedicineType.lotions:    Color(0xFFDCFCE7),
        MedicineType.inhalers:  Color(0xFFEBF8FF),
    MedicineType.sprays:     Color(0xFFFEF3C7),
    MedicineType.powders:   Color(0xFFE0F2F1),

  }[this]!;

  Color get colorDark => const {
    MedicineType.tablet:    Color(0xFF2BB5A0),
    MedicineType.syrups:     Color(0xFF6B46C1),
        MedicineType.drops:     Color(0xFF1E40AF),
    MedicineType.injections: Color(0xFFC53030),

    MedicineType.lotions:    Color(0xFF276749),
      MedicineType.inhalers:  Color(0xFF2D3748),
    MedicineType.sprays:     Color(0xFF975A16),
    MedicineType.powders:   Color(0xFF1A5643),
  
  }[this]!;

  int get typeId => index + 1;
}

// ════════════════════════════════════════════════════════════════════
//  PICKER OPTIONS
// ════════════════════════════════════════════════════════════════════
const _kDosageOpts = {
  'tablet':    ['0', '¼', '½', '¾', '1', '1½', '2', '3'],
  'syrups':     ['0', '2.5ml', '5ml', '7.5ml', '10ml', '15ml', '20ml'],
  'drops':     ['0', '1', '2', '3', '4', '5', '6'],
  'injections': ['0', '0.5', '1', '2', '4', '5', '10'],
  
  'lotions':    ['0', 'Apply', 'Thin layer', 'Thick layer'],
  'inhalers':  ['0', '1 puff', '2 puffs', '3 puffs', '4 puffs', '5 puffs'],
  'sprays':     ['0', '1 puff', '2 puffs', '3 puffs', '4 puffs'],
    'powders':   ['0', '½ tsp', '1 tsp', '1½ tsp', '2 tsp', '1 sachet', '2 sachets'],
  
};

// ════════════════════════════════════════════════════════════════════
//  MedicineEntry
// ════════════════════════════════════════════════════════════════════
class MedicineEntry {
    final GlobalKey cardKey = GlobalKey();
  bool hasError = false;
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
   String powderForm;
  String inhalerType;
  String inhalerTechnique;

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
        sprayUsage       = 'Nasal',
        powderForm       = 'Loose Powder',    // NEW
        inhalerType      = 'MDI',              // NEW
        inhalerTechnique = 'Shake & Inhale';   // NEW

  PrescriptionMedicineModel toApiModel() => PrescriptionMedicineModel(
    medicineId:       medicineId,
    medicineTypeId:   type.typeId,
    frequency:        frequency.isEmpty ? null : frequency,
    duration:         duration.isEmpty  ? null : duration,
    timing:           type == MedicineType.lotions ? null : (timing.isEmpty ? null : timing),
    tabletDosage:     type == MedicineType.tablet    ? (dosage.isEmpty ? null : dosage) : null,
    syrupDosageMl:    type == MedicineType.syrups     ? (dosage.isEmpty ? null : dosage) : null,
    injDosage:        type == MedicineType.injections ? (dosage.isEmpty ? null : dosage) : null,
    injRoute:         type == MedicineType.injections ? (injRoute.isEmpty ? null : injRoute) : null,
    dropsCount:       type == MedicineType.drops     ? (dosage.isEmpty ? null : dosage) : null,
    dropsApplication: type == MedicineType.drops     ? (dropsApplication.isEmpty ? null : dropsApplication) : null,
    lotionApplyArea:  type == MedicineType.lotions    ? (lotionApplyArea.isEmpty ? null : lotionApplyArea) : null,
    sprayPuffs:       type == MedicineType.sprays     ? (dosage.isEmpty ? null : dosage) : null,
    sprayUsage:       type == MedicineType.sprays     ? (sprayUsage.isEmpty ? null : sprayUsage) : null,
    lotionUsage:      type == MedicineType.lotions    ? (dosage.isEmpty ? null : dosage) : null,
 
   powderDosage: type == MedicineType.powders ? (dosage.isEmpty ? null : dosage) : null,
  powderForm:   type == MedicineType.powders ? (powderForm.isEmpty ? null : powderForm) : null,
  // Inhalers
  inhalerPuffs:     type == MedicineType.inhalers ? (dosage.isEmpty ? null : dosage) : null,
  inhalerType:      type == MedicineType.inhalers ? (inhalerType.isEmpty ? null : inhalerType) : null,
  inhalerTechnique: type == MedicineType.inhalers ? (inhalerTechnique.isEmpty ? null : inhalerTechnique) : null,
 
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
        Text(widget.label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 0.1)),
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
       Expanded(child: Text(_display, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary))),
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
            Text('Select per slot', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: ac)),
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
              child: const Text('Set', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ]),
    );
  }
Widget _slotLbl(String t) => Expanded(child: Text(t, textAlign: TextAlign.center,
   style: const TextStyle(fontSize: 13, color: Colors.black, fontWeight: FontWeight.w800)));
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
               color: isSel ? Colors.black : Colors.black54,
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
  final String? clinicId;
  /// The session this patient belongs to. A doctor can have multiple queue
  /// sessions running the same day (e.g. two slot blocks), each with its own
  /// token numbering starting at 1 — without this, "Complete & Next" picks
  /// the lowest token number across ALL sessions and can jump back to the
  /// first patient of a different, unrelated session.
  final int?    queueId;

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
    this.clinicId,
    this.queueId,
  });

  @override
  ConsumerState<PrescriptionScreen> createState() => _PrescriptionScreenState();
}

class _PrescriptionScreenState extends ConsumerState<PrescriptionScreen> {
  final _sympCtrl = TextEditingController();
  final _diagCtrl = TextEditingController();
  final _clinCtrl = TextEditingController();
  final _advCtrl  = TextEditingController();
  final _sympKey  = GlobalKey();
  bool _symptomsError = false;
  bool _showSymptomSuggestions = false;
  DateTime? _followDate;
  final List<MedicineEntry> _meds = [];
  int _lastDoctorId = 0;
  late final ProviderSubscription<int?> _doctorIdSub;
  bool _isSubmitting = false;
  List<AppointmentList> _previousVisitsCache = const [];

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
    _fetchPreviousVisits();
  }

  // Doctor-wide, ALL-clinic history — deliberately bypasses the shared
  // appointmentViewModelProvider list, which is scoped to whichever single
  // clinic the doctor is currently active in. A patient's past visits with
  // this doctor may have happened at a different clinic, so this hits the
  // usecase directly with clinicId omitted instead of mutating the shared
  // provider's "current clinic" state.
  Future<void> _fetchPreviousVisits() async {
    try {
      final all = await ref.read(appointmentUsecaseProvider)
          .fetchPatientAppointments(widget.doctorId);
      if (!mounted) return;
      final visits = all.where((a) =>
          a.patientId == widget.patientId &&
          a.appointmentId != widget.appointmentId &&
          (a.status?.toLowerCase().trim() ?? '') == 'completed').toList();
      visits.sort((a, b) {
        final da = DateTime.tryParse(a.appointmentDate ?? '');
        final db = DateTime.tryParse(b.appointmentDate ?? '');
        if (da == null || db == null) return 0;
        return db.compareTo(da);
      });
      setState(() => _previousVisitsCache = visits);
    } catch (_) {
      // Leave _previousVisitsCache as-is — card just won't show/refresh.
    }
  }

  void _openPreviousHistory(List<AppointmentList> visits) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => _PreviousHistoryPage(
      patientName: widget.patientName,
      visits: visits,
      onSelect: (a) => Navigator.push(context, MaterialPageRoute(builder: (_) => DoctorPrescriptionDetailScreen(
        appointmentId: a.appointmentId ?? 0,
        patientId:     widget.patientId,
        patientName:   widget.patientName,
        patientAge:    widget.patientAge,
        patientGender: widget.patientGender,
        queueNumber:   a.queueNumber,
      ))),
    )));
  }
 
  @override
  void dispose() {
    _sympCtrl.dispose(); _diagCtrl.dispose();
    _clinCtrl.dispose(); _advCtrl.dispose();
    _doctorIdSub.close();
    super.dispose();
  }
  void _addMed() {
  setState(() => _meds.insert(0, MedicineEntry()));
}
  // void _addMed() => setState(() => _meds.add(MedicineEntry()));
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
    final symptomsEmpty = _sympCtrl.text.trim().isEmpty;
    MedicineEntry? badMed;
    for (final m in _meds) {
      m.hasError = m.selectedName == null || m.medicineId == null;
      badMed ??= m.hasError ? m : null;
    }
    _symptomsError = symptomsEmpty;

    if (!symptomsEmpty && badMed == null) return null;

    setState(() {});
    final key = symptomsEmpty ? _sympKey : badMed!.cardKey;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = key.currentContext;
      if (ctx != null) {
        Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 250), alignment: 0.2);
      }
    });

    return symptomsEmpty
        ? 'Please enter symptoms'
        : 'Please select medicine name for Medicine ${_meds.indexOf(badMed!) + 1}';
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
    clinicId:      widget.clinicId,
  );

  Future<AppointmentResponseModel?> _completeQueueAction() async {
    try {
      final isOnline = ref.read(connectivityNotifierProvider).isOnline;
      final isSkipped = widget.patientStatus.toLowerCase().trim() == 'skipped';
      final AppointmentResponseModel result;
      if (isSkipped) {
        result = await ref.read(appointmentViewModelProvider.notifier)
            .endSession(AppointmentRequestModel(
              doctorId:      widget.doctorId,
              appointmentId: widget.appointmentId,
              patientId:     widget.patientId,
              clinicId:      widget.clinicId,
            ), isOnline: isOnline);
      } else {
        result = await ref.read(appointmentViewModelProvider.notifier)
            .queueNext(AppointmentRequestModel(
              operation:       'QUEUE_NEXT',
              doctorId:        widget.doctorId,
              appointmentId:   widget.appointmentId,
              patientId:       widget.patientId,
              appointmentDate: _todayApi(),
              clinicId:        widget.clinicId,
              queueId:         widget.queueId,
            ), isOnline: isOnline);
      }
      if (result.success == true) return result;
      // Show user-friendly message — never expose raw SQL errors
      final raw = result.message ?? '';
      final friendly = (raw.contains('PRIMARY KEY') || raw.contains('duplicate key') || raw.contains('Violation'))
          ? 'Prescription saved. Queue could not advance — please refresh the home screen.'
          : raw.isNotEmpty ? raw : 'Queue action failed';
      _showSnack(friendly, isError: true);
      return null;
    } catch (e) {
      _showSnack('Prescription saved. Queue could not advance — please refresh.', isError: true);
      return null;
    }
  }

  Future<void> _handleNextPatient() async {
    debugPrint('[RxDebug] _handleNextPatient: start');
    final result = await _completeQueueAction();
    debugPrint('[RxDebug] _handleNextPatient: _completeQueueAction returned '
        'success=${result?.success} message=${result?.message}');
    // Deliberately NOT gated on `mounted` from here on — `State.mounted`
    // stays true while this widget is merely deactivated (e.g. a Navigator
    // transition already under way), so it can't be trusted to skip
    // navigation. All Navigator calls below go through the app-root
    // `navigatorKey` instead of `Navigator.of(context)`, so they work even
    // if this screen's own context is no longer attached to the tree.
    if (result == null) {
      debugPrint('[RxDebug] _handleNextPatient: result null, popping');
      // queueNext failed but prescription was already saved — navigate back
      // so the user isn't stuck on the prescription screen.
      await Future.delayed(const Duration(milliseconds: 600));
      navigatorKey.currentState?.pop();
      return;
    }

    // API explicitly says no more queue patients — go back to patient list
    final msg = result.message?.trim() ?? '';
    if (msg.toLowerCase().contains('no patient left')) {
      debugPrint('[RxDebug] _handleNextPatient: "no patient left", popping');
      _showSnack(msg, isError: false);
      await Future.delayed(const Duration(milliseconds: 300));
      navigatorKey.currentState?.pop();
      return;
    }

    final nextToken = result.data?.isNotEmpty == true ? result.data!.first.nextToken : null;

    debugPrint('[RxDebug] _handleNextPatient: fetching patient appointments…');
    await ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(
        widget.doctorId,
        isOnline: ref.read(connectivityNotifierProvider).isOnline,
        clinicId: widget.clinicId);
    debugPrint('[RxDebug] _handleNextPatient: fetch done');

    final all = ref.read(appointmentViewModelProvider).patientAppointmentsList
        .maybeWhen(data: (l) => l, orElse: () => const <AppointmentList>[]);
    debugPrint('[RxDebug] _handleNextPatient: fetched ${all.length} appointments: '
        '${all.map((a) => '(id=${a.appointmentId},status=${a.status},queueId=${a.queueId},queueNum=${a.queueNumber})').join(', ')}');
    debugPrint('[RxDebug] _handleNextPatient: widget.appointmentId=${widget.appointmentId} widget.queueId=${widget.queueId}');

    final next = _pickNextAppointment(all, preferredQueue: nextToken);
    debugPrint('[RxDebug] _handleNextPatient: picked next = '
        '${next == null ? 'NULL' : '(id=${next.appointmentId}, patient=${next.patientName}, status=${next.status})'}');
    if (next == null) {
      _showSnack('No next patient found', isError: true);
      navigatorKey.currentState?.pop();
      return;
    }

    _showSnack('Prescription saved. Opening next patient…', isError: false);
    await Future.delayed(const Duration(milliseconds: 300));

    debugPrint('[RxDebug] _handleNextPatient: pushReplacement -> appointmentId=${next.appointmentId}');
    navigatorKey.currentState?.pushReplacement(MaterialPageRoute(builder: (_) => PrescriptionScreen(
      patientId:     next.patientId     ?? 0,
      doctorId:      next.doctorId      ?? widget.doctorId,
      userTypeId:    next.userType      ?? widget.userTypeId,
      appointmentId: next.appointmentId ?? 0,
      patientName:   next.patientName   ?? 'Patient',
      patientAge:    _ageString(next.dob),
      patientGender: next.gender,
      queueNumber:   next.queueNumber,
      patientStatus: next.status ?? 'booked',
      symptoms:      next.symptoms,
      clinicId:      widget.clinicId,
      queueId:       next.queueId ?? widget.queueId,
    )));
  }

  // Slot patients must never be auto-opened as the "next" queue patient
  bool _isSlotAppointment(AppointmentList a) =>
      a.bookingType == 2 ||
      (a.bookingType == null && a.startTime != null && a.endTime != null);

  AppointmentList? _pickNextAppointment(List<AppointmentList> list, {int? preferredQueue}) {
    // Scope to this patient's own session when we know it — a doctor can run
    // multiple queue sessions the same day, each with its own token numbering
    // starting at 1, so an unscoped pick can jump to a different session's
    // first patient instead of this session's real next one.
    final sameSession = widget.queueId == null
        ? list
        : list.where((a) => a.queueId == widget.queueId).toList();
    final inProgress = sameSession.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return s == 'in_progress' && a.appointmentId != widget.appointmentId
          && _isToday(_parseDate(a.appointmentDate))
          && !_isSlotAppointment(a);
    }).toList();
    if (inProgress.isNotEmpty) {
      inProgress.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
      return inProgress.first;
    }
    final candidates = sameSession.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return s == 'booked' && _isToday(_parseDate(a.appointmentDate))
          && a.appointmentId != widget.appointmentId
          && !_isSlotAppointment(a);
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
    debugPrint('[RxDebug] _completePrescription: tapped, _isSubmitting=$_isSubmitting');
    if (_isSubmitting) { debugPrint('[RxDebug] _completePrescription: blocked, already submitting'); return; }
    final error = _validate();
    if (error != null) { debugPrint('[RxDebug] _completePrescription: validation failed: $error'); _showSnack(error, isError: true); return; }
    setState(() => _isSubmitting = true);
    try {
      debugPrint('[RxDebug] _completePrescription: calling insertPrescription…');
      await ref.read(prescriptionViewModelProvider.notifier).insertPrescription(_buildPrescription());
      debugPrint('[RxDebug] _completePrescription: insertPrescription returned, mounted=$mounted');
      if (!mounted) { debugPrint('[RxDebug] _completePrescription: unmounted, abort'); return; }
      final state = ref.read(prescriptionViewModelProvider);
      debugPrint('[RxDebug] _completePrescription: state.error=${state.error}');
      if (state.error != null) { _showSnack(state.error!, isError: true); return; }
      await _handleNextPatient();
      debugPrint('[RxDebug] _completePrescription: _handleNextPatient returned');
    } finally {
      debugPrint('[RxDebug] _completePrescription: finally, mounted=$mounted');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _completeAndBack() async {
    debugPrint('[RxDebug] _completeAndBack: tapped, _isSubmitting=$_isSubmitting');
    if (_isSubmitting) { debugPrint('[RxDebug] _completeAndBack: blocked, already submitting'); return; }
    final error = _validate();
    if (error != null) { debugPrint('[RxDebug] _completeAndBack: validation failed: $error'); _showSnack(error, isError: true); return; }
    setState(() => _isSubmitting = true);
    try {
      debugPrint('[RxDebug] _completeAndBack: calling insertPrescription…');
      await ref.read(prescriptionViewModelProvider.notifier).insertPrescription(_buildPrescription());
      debugPrint('[RxDebug] _completeAndBack: insertPrescription returned, mounted=$mounted');
      if (!mounted) { debugPrint('[RxDebug] _completeAndBack: unmounted, abort'); return; }
      final state = ref.read(prescriptionViewModelProvider);
      debugPrint('[RxDebug] _completeAndBack: state.error=${state.error}');
      if (state.error != null) { _showSnack(state.error!, isError: true); return; }
      // Fire-and-forget — don't let endSession block or unmount the widget before pop
      ref.read(appointmentViewModelProvider.notifier).endSession(
        AppointmentRequestModel(
          doctorId:      widget.doctorId,
          appointmentId: widget.appointmentId,
          patientId:     widget.patientId,
          clinicId:      widget.clinicId,
        ),
        isOnline: ref.read(connectivityNotifierProvider).isOnline,
      ).catchError((_) => AppointmentResponseModel(success: false));
      _showSnack('Prescription saved', isError: false);
      await Future.delayed(const Duration(milliseconds: 300));
      debugPrint('[RxDebug] _completeAndBack: about to pop');
      // Uses navigatorKey, not Navigator.of(context) — `mounted` alone can't
      // be trusted to gate this (see _showSnack).
      navigatorKey.currentState?.pop();
    } finally {
      debugPrint('[RxDebug] _completeAndBack: finally, mounted=$mounted');
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _onSkip() async {
    try {
      final isOnline = ref.read(connectivityNotifierProvider).isOnline;
      final skipRes = await ref.read(appointmentViewModelProvider.notifier).queueSkip(
        AppointmentRequestModel(doctorId: widget.doctorId,
            appointmentId: widget.appointmentId, patientId: widget.patientId,
            isNext: 1, queueId: widget.queueId), isOnline: isOnline);
      if (!mounted) return;

      // SP rejected the skip (queue not started, invalid state, …) —
      // surface the real reason instead of navigating to a "next" patient.
      if (skipRes.success != true) {
        _showSnack(skipRes.message ?? 'Skip failed', isError: true);
        return;
      }

      // Last patient in queue — go back immediately, same as "No Patient Left"
      final skipMsg = skipRes.message?.trim() ?? '';
      if (skipMsg.toLowerCase().contains('last patient')) {
        _showSnack(skipMsg, isError: false);
        await Future.delayed(const Duration(milliseconds: 300));
        navigatorKey.currentState?.pop();
        return;
      }

      await ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(
          widget.doctorId, isOnline: isOnline, clinicId: widget.clinicId);
      if (!mounted) return;
      final all = ref.read(appointmentViewModelProvider).patientAppointmentsList
          .maybeWhen(data: (l) => l, orElse: () => <AppointmentList>[]);
      final next = _pickNextAppointment(all);
      if (next == null) {
        _showSnack(skipRes.message ?? 'Patient skipped', isError: false);
        await Future.delayed(const Duration(milliseconds: 300));
        navigatorKey.currentState?.pop();
        return;
      }
      navigatorKey.currentState?.pushReplacement(MaterialPageRoute(builder: (_) => PrescriptionScreen(
        patientId:     next.patientId     ?? 0,
        doctorId:      next.doctorId      ?? widget.doctorId,
        userTypeId:    next.userType      ?? widget.userTypeId,
        appointmentId: next.appointmentId ?? 0,
        patientName:   next.patientName   ?? 'Patient',
        patientAge:    _ageString(next.dob),
        patientGender: next.gender,
        queueNumber:   next.queueNumber,
        patientStatus: next.status ?? 'booked',
        symptoms:      next.symptoms,
        clinicId:      widget.clinicId,
        queueId:       next.queueId ?? widget.queueId,
      )));
    } catch (e) { _showSnack('Skip failed: $e', isError: true); }
  }

  // `State.mounted` can still read true while this widget is deactivated
  // (mid-removal from the tree, e.g. a Navigator transition already in
  // flight) — in that window `ScaffoldMessenger.of(context)` throws
  // "Looking up a deactivated widget's ancestor is unsafe", which used to
  // abort _handleNextPatient/_completeAndBack BEFORE they reached the
  // Navigator call that actually opens the next patient / pops back. Use the
  // app-root ScaffoldMessenger key instead of a context lookup so this can
  // never throw on a deactivated context, and callers can rely on it.
  void _showSnack(String msg, {bool isError = false}) {
    try {
      rootScaffoldMessengerKey.currentState?.showSnackBar(SnackBar(
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
    } catch (e) {
      debugPrint('[RxDebug] _showSnack failed: $e');
    }
  }

  double get _width => MediaQuery.of(context).size.width;
  bool get _isDesktop => _width >= _kDesktopBreak;
  bool get _isTablet  => _width >= _kTabletBreak;

  // @override
  // Widget build(BuildContext context) {
  //   final state       = ref.watch(prescriptionViewModelProvider);
  //   final doctorState = ref.watch(doctorLoginViewModelProvider);
  //   // valueOrNull (not .value): on an AsyncError, Riverpod's `.value` RETHROWS
  //   // the error during build — offline that crashed the whole screen. We want
  //   // a graceful empty catalog instead.
  //   final medicines   = doctorState.medicines?.valueOrNull ?? const <Medicine>[];

  //   return Stack(children: [
  //     Scaffold(
  //       backgroundColor: kBg,
  //       body: Column(children: [
  //         _buildHeader(),
  //         Expanded(
  //           child: _isDesktop
  //               ? _desktopBody(medicines)
  //               : _mobileBody(medicines),
  //         ),
  //       ]),
  //     ),
  //     if (state.isLoading)
  //       Container(
  //         color: Colors.black.withOpacity(0.28),
  //         child: const Center(child: CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5)),
  //       ),
  //   ]);
  // }

  @override
Widget build(BuildContext context) {
  final state       = ref.watch(prescriptionViewModelProvider);
  final doctorState = ref.watch(doctorLoginViewModelProvider);
  final medicines   = doctorState.medicines?.valueOrNull ?? const <Medicine>[];

  return Stack(children: [
    Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: GestureDetector(                          // ← हे add करा
        onTap: () => FocusScope.of(context).unfocus(), // ← keyboard dismiss
        child: Column(children: [
          _buildHeader(),
          Expanded(
            child: _isDesktop
                ? _desktopBody(medicines)
                : _mobileBody(medicines),
          ),
        ]),
      ),
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
              Text('New Prescription', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
              SizedBox(height: 1),
              Text('Fill in consultation details', style: TextStyle(fontSize: 11, color: kTextSecondary)),
            ]),
          ),
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
              if (_previousVisitsCache.isNotEmpty) ...[_previousHistoryCard(), _gap(12)],
              _symptomsSection(), _gap(10),
              _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis…'),
              // _gap(10),
              // _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'),
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
                if (_previousVisitsCache.isNotEmpty) ...[_previousHistoryCard(), _gap(12)],
                _symptomsSection(), _gap(10),
                _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis…'), _gap(10),
                // _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'), _gap(10),
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
          if (_previousVisitsCache.isNotEmpty) ...[_previousHistoryCard(), _gap(12)],
          _symptomsSection(), _gap(10),
          _textSection('Diagnosis', _diagCtrl, 'Enter diagnosis…'), _gap(12),
          // _textSection('Clinical Notes', _clinCtrl, 'Optional clinical notes…'), _gap(12),
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
        Text(widget.patientName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
            overflow: TextOverflow.ellipsis),
        const SizedBox(height: 4),
        Wrap(spacing: 5, runSpacing: 4, children: [
          if (widget.patientAge != null)    _chip(widget.patientAge!, bg: kInfoLight, fg: kInfoDark),
          if (widget.patientGender != null) _chip(widget.patientGender!, bg: kPrimaryLighter, fg: kPrimaryDark),
          if (widget.queueNumber != null)   _chip('Queue #${widget.queueNumber}', bg: kPrimaryLight, fg: kPrimaryDark),
        ]),
      ])),
    ]));
  }

  // ── Previous History card — only if this patient has past completed visits with this doctor ──
  Widget _previousHistoryCard() => GestureDetector(
    onTap: () => _openPreviousHistory(_previousVisitsCache),
    child: _card(child: Row(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10)),
        child: const Icon(Icons.history_rounded, color: kPurpleDark, size: 18),
      ),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Previous History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 2),
        Text('${_previousVisitsCache.length} earlier visit${_previousVisitsCache.length == 1 ? '' : 's'} with this patient',
            style: const TextStyle(fontSize: 11, color: kTextSecondary)),
      ])),
      const Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 20),
    ])),
  );

  Widget _textSection(String label, TextEditingController ctrl, String hint, {bool hasError = false, Key? key}) =>
      Container(key: key, child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secLabel(label), _gap(8),
        TextField(
          controller: ctrl, maxLines: 3,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
          decoration: _ideco(hint, hasError: hasError),
        ),
        if (hasError) ...[
          _gap(4),
          const Text('This field is required', style: TextStyle(fontSize: 11, color: kError, fontWeight: FontWeight.w600)),
        ],
      ])));

  void _addSymptom(String symptom) {
    final text = _sympCtrl.text;
    final lastComma = text.lastIndexOf(',');
    final before = (lastComma == -1 ? '' : text.substring(0, lastComma + 1).trim());

    final already = before.split(',').map((s) => s.trim().toLowerCase())
        .where((s) => s.isNotEmpty).toSet();
    if (already.contains(symptom.toLowerCase())) {
      setState(() => _showSymptomSuggestions = false);
      return;
    }

    _sympCtrl.text = before.isEmpty ? symptom : '$before $symptom';
    _sympCtrl.selection = TextSelection.collapsed(offset: _sympCtrl.text.length);
    setState(() => _showSymptomSuggestions = false);
  }

  String get _symptomSearchText {
    final text = _sympCtrl.text;
    final lastComma = text.lastIndexOf(',');
    return (lastComma == -1 ? text : text.substring(lastComma + 1)).trim();
  }

  Widget _symptomsSection() {
    final query = _symptomSearchText;
    final filtered = query.isEmpty
        ? kDefaultSymptoms
        : kDefaultSymptoms.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();
    final showDropdown = _showSymptomSuggestions;

    return TapRegion(
      onTapOutside: (_) { if (_showSymptomSuggestions) setState(() => _showSymptomSuggestions = false); },
      child: Container(key: _sympKey, child: _card(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _secLabel('Symptoms *'), _gap(8),
        TextField(
          controller: _sympCtrl, maxLines: 3,
          onTap: () => setState(() => _showSymptomSuggestions = true),
          onChanged: (_) => setState(() {}),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
          decoration: _ideco('Enter patient symptoms…', hasError: _symptomsError),
        ),
        if (_symptomsError) ...[
          _gap(4),
          const Text('This field is required', style: TextStyle(fontSize: 11, color: kError, fontWeight: FontWeight.w600)),
        ],
        if (showDropdown) ...[
          _gap(6),
          if (filtered.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ListView.separated(
                shrinkWrap: true, padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  return InkWell(
                    onTap: () => _addSymptom(s),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        const Icon(Icons.sick_outlined, color: kPrimary, size: 13),
                        const SizedBox(width: 9),
                        Expanded(child: Text(s,
                            style: const TextStyle(fontSize: 12, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis)),
                      ]),
                    ),
                  );
                },
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: kTextMuted),
              const SizedBox(width: 5),
              Expanded(child: Text('No matching symptom — you can type your own',
                  style: const TextStyle(fontSize: 11, color: kTextMuted))),
            ])),
        ],
      ]))),
    );
  }

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
List<Widget> _buildMedCards(List<Medicine> medicines) =>
  List.generate(_meds.length, (i) =>
    Padding(
      key: _meds[i].cardKey,
      padding: const EdgeInsets.only(bottom: 12),
      child: _MedCard(
        index: _meds.length - i,  // ← i+1 ऐवजी हे
        entry: _meds[i], medicines: medicines,
        onDelete: () => _delMed(i),
        rebuild: () => setState(() {}),
        onMedicineAdded: (m) => _onNewMedicineAdded(_meds[i], m),
      ),
    ),
  );

  Future<void> _onNewMedicineAdded(MedicineEntry entry, Medicine created) async {
    await ref.read(doctorLoginViewModelProvider.notifier)
        .fetchAllMedicines(widget.doctorId);
    if (!mounted) return;

    final refreshed = ref.read(doctorLoginViewModelProvider).medicines?.valueOrNull
        ?? const <Medicine>[];
    final createdName = (created.medicineName ?? '').trim().toLowerCase();
    final match = refreshed.where((m) =>
        (m.medicineName ?? '').trim().toLowerCase() == createdName &&
        m.medTypeId == created.medTypeId,
    ).toList();
    final saved = match.isNotEmpty ? match.last : created;

    final newType = MedicineType.values.firstWhere(
      (t) => t.typeId == (saved.medTypeId ?? 1),
      orElse: () => MedicineType.tablet,
    );
    setState(() {
      entry.type         = newType;
      entry.medicineId   = saved.medicineId;
      entry.selectedName = saved.medicineName ?? '';
      entry.searchText   = '';
    });
  }
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
      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
      decoration: _ideco('Advice / instructions for patient…'),
    ),
  ]));

  // ── Bottom Action Bar ────────────────────────────────────────────
  Widget _bottomBar() {
    final isLoading = ref.watch(prescriptionViewModelProvider).isLoading || _isSubmitting;
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
    Text(t, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary, letterSpacing: -0.2)),
  ]);

  Widget _chip(String t, {required Color bg, required Color fg}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
    decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
    child: Text(t, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
  );

  InputDecoration _ideco(String hint, {bool hasError = false}) => InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(fontSize: 12, color: kTextMuted),
    filled: true, fillColor: kBg,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    border:        OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: hasError ? kError : kBorder)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: hasError ? kError : kBorder)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: hasError ? kError : kPrimary, width: 1.5)),
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
  final ValueChanged<Medicine> onMedicineAdded;

  const _MedCard({
    required this.index, required this.entry, required this.medicines,
    required this.onDelete, required this.rebuild,
    required this.onMedicineAdded,
  });

  @override
  State<_MedCard> createState() => _MedCardState();
}

class _MedCardState extends State<_MedCard> {
  MedicineEntry get e => widget.entry;
  late TextEditingController _durCtrl;
  late TextEditingController _areaCtrl;
  bool _showSuggestions = false;

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

  // void _onTypeChange(MedicineType t) {
  //   _disposeControllers();
  //   e.type = t;
  //   e.medicineId = null; e.selectedName = null; e.searchText = '';
  //   e.dosage = '1-0-1'; e.frequency = '1-0-1'; e.duration = '';
  //     e.powderForm       = 'Loose Powder';   // NEW
  // e.inhalerType      = 'MDI';            // NEW
  // e.inhalerTechnique = 'Shake & Inhale'; // NEW
  //   _initControllers();
  //   setState(() {});
  //   widget.rebuild();
  // }
void _onTypeChange(MedicineType t) {
  _disposeControllers();
  e.type = t;
  e.medicineId = null; e.selectedName = null; e.searchText = '';
  
  // ← Type-specific default dosage
  switch (t) {
    case MedicineType.powders:
      e.dosage = '½ tsp-0-½ tsp';
      e.frequency = '1-0-1';
      break;
    case MedicineType.inhalers:
    case MedicineType.sprays:
      e.dosage = '1 puff-0-1 puff';
      e.frequency = '1-0-1';
      break;
    case MedicineType.drops:
      e.dosage = '2-0-2';
      e.frequency = '1-0-1';
      break;
    case MedicineType.syrups:
      e.dosage = '5ml-0-5ml';
      e.frequency = '1-0-1';
      break;
    default:
      e.dosage = '1-0-1';
      e.frequency = '1-0-1';
  }
  
  e.duration = '';
  e.powderForm = 'Loose Powder';
  e.inhalerType = 'MDI';
  e.inhalerTechnique = 'Shake & Inhale';
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
        border: Border.all(color: e.hasError ? kError : tc.withOpacity(0.30), width: e.hasError ? 1.6 : 1.2),
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
  Text('Medicine ${widget.index}',  
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary)),
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
      case MedicineType.syrups:     return _commonBody();
          case MedicineType.drops:     return _dropsBody();
        case MedicineType.injections: return _injBody();
  
      case MedicineType.lotions:    return _lotionBody();
        case MedicineType.inhalers:  return _inhalersBody();
      case MedicineType.sprays:     return _sprayBody();
       case MedicineType.powders:   return _powdersBody();
  
    }
  }
  Widget _powdersBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  _nameSearch(), _gap(10),
  _dropField('Form', e.powderForm, ['Loose Powder', 'Sachet', 'Dusting Powder', 'Oral Powder'],
      (v) => setState(() => e.powderForm = v!)),
  _gap(10),
  _dosagePicker(label: 'Dose per slot'), _gap(10),
  _r2([
    _txtField('Duration', 'e.g. 5 days', _durCtrl, onChanged: (v) => e.duration = v),
    _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
  ]),
]);

Widget _inhalersBody() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
  _nameSearch(), _gap(10),
  _r2([
    _dropField('Inhaler Type', e.inhalerType,
        ['MDI', 'DPI', 'Nebulizer', 'Soft Mist', 'BAI'],
        (v) => setState(() => e.inhalerType = v!)),
    _dropField('Usage', e.sprayUsage,
        ['Bronchodilator', 'Steroid', 'Combination', 'Rescue', 'Preventer'],
        (v) => setState(() => e.sprayUsage = v!)),
  ]),
  _gap(10),
  _dosagePicker(label: 'Puffs per slot'), _gap(10),
  _r2([
    _txtField('Duration', 'e.g. 30 days', _durCtrl, onChanged: (v) => e.duration = v),
    _dropField('Timing', e.timing, _timingOpts, (v) => setState(() => e.timing = v!)),
  ]),
  _gap(10),
  _dropField('Device Technique', e.inhalerTechnique,
      ['Shake & Inhale', 'Slow Deep Breath', 'Breath-Actuated', 'Spacer Required'],
      (v) => setState(() => e.inhalerTechnique = v!)),
]);

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
    _txtField('Duration', 'e.g. 7 days', _durCtrl, onChanged: (v) => e.duration = v),
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

  void _onMedicineSelected(Medicine m) {
    final newType = MedicineType.values.firstWhere(
      (t) => t.typeId == (m.medTypeId ?? 1),
      orElse: () => MedicineType.tablet,
    );
    if (newType != e.type) {
      _onTypeChange(newType);
    }
    setState(() {
      e.selectedName    = m.medicineName ?? '';
      e.medicineId      = m.medicineId;
      e.searchText      = '';
      _showSuggestions  = false;
    });
  }

  Widget _nameSearch() {
    final all = widget.medicines;
    final filtered = e.searchText.isEmpty
        ? (List<Medicine>.from(all)
            ..sort((a, b) => (a.medicineName ?? '').toLowerCase().compareTo((b.medicineName ?? '').toLowerCase())))
        : all.where((m) => (m.medicineName ?? '').toLowerCase().contains(e.searchText.toLowerCase())).toList();
    final showDropdown = _showSuggestions || e.searchText.isNotEmpty;

    return TapRegion(
      onTapOutside: (_) { if (_showSuggestions) setState(() => _showSuggestions = false); },
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _lbl('Medicine Name'), _gap(5),
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: e.type.color.withOpacity(0.12), borderRadius: BorderRadius.circular(5)),
              child: Text(e.type.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: e.type.colorDark)),
            ),
            const SizedBox(width: 6),
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
          onTap: () => setState(() => _showSuggestions = true),
          onChanged: (v) => setState(() { e.searchText = v; _showSuggestions = true; }),
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
          decoration: _ideco('Search medicine name…').copyWith(
            prefixIcon: const Padding(padding: EdgeInsets.symmetric(horizontal: 11),
                child: Icon(Icons.search_rounded, color: kPrimary, size: 16)),
            prefixIconConstraints: const BoxConstraints(minWidth: 40),
          ),
        ),
        if (showDropdown) ...[
          _gap(4),
          if (filtered.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              decoration: BoxDecoration(
                color: Colors.white, borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
                boxShadow: const [BoxShadow(color: Color(0x10000000), blurRadius: 8, offset: Offset(0, 3))],
              ),
              child: ListView.separated(
                shrinkWrap: true, padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
                itemBuilder: (_, i) {
                  final med = filtered[i];
                  final medType = MedicineType.values.firstWhere(
                    (t) => t.typeId == (med.medTypeId ?? 1),
                    orElse: () => MedicineType.tablet,
                  );
                  return InkWell(
                    onTap: () => _onMedicineSelected(med),
                    borderRadius: BorderRadius.circular(10),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      child: Row(children: [
                        Icon(medType.icon, color: medType.color, size: 13),
                        const SizedBox(width: 9),
                        Expanded(child: Text(med.medicineName ?? '',
                            style: const TextStyle(fontSize: 12, color: kTextPrimary),
                            overflow: TextOverflow.ellipsis)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: medType.colorLight, borderRadius: BorderRadius.circular(5)),
                          child: Text(medType.label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: medType.colorDark)),
                        ),
                      ]),
                    ),
                  );
                },
              ),
            )
          else
            Padding(padding: const EdgeInsets.only(top: 5), child: Row(children: [
              const Icon(Icons.info_outline_rounded, size: 12, color: kTextMuted),
              const SizedBox(width: 5),
              Expanded(child: Text(e.searchText.isEmpty
                      ? 'No medicines added yet'
                      : 'No medicine found for "${e.searchText}"',
                  style: const TextStyle(fontSize: 11, color: kTextMuted))),
            ])),
          _gap(6),
          InkWell(
            onTap: _openAddMedicinePopup,
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary.withOpacity(0.3)),
              ),
              child: const Row(children: [
                Icon(Icons.add_circle_outline_rounded, color: kPrimary, size: 15),
                SizedBox(width: 8),
                Text('Add New Medicine', style: TextStyle(
                    fontSize: 12.5, fontWeight: FontWeight.w700, color: kPrimary)),
              ]),
            ),
          ),
        ],
      ],
    ]));
  }

  void _openAddMedicinePopup() {
    setState(() => _showSuggestions = false);
    final dialogNavigator = Navigator.of(context);
    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 640),
          child: AddMedicinePage(
            onSaved: (created) {
              // Defer past AddMedicinePage's own _save() completion (it keeps
              // using `ref`/`context` right after this callback returns) so
              // popping the dialog here doesn't dispose it mid-call.
              Future.microtask(() {
                if (dialogNavigator.mounted) dialogNavigator.pop();
                if (mounted) widget.onMedicineAdded(created);
              });
            },
          ),
        ),
      ),
    );
  }

  Widget _txtField(String label, String hint, TextEditingController ctrl,
      {required ValueChanged<String> onChanged}) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _lbl(label), _gap(5),
        TextField(controller: ctrl, onChanged: onChanged,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
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

  Widget _lbl(String t) => Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextSecondary, letterSpacing: 0.1));

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
//  _PreviousHistorySheet — this patient's past visits with THIS doctor,
//  newest first. Tap a date to open that visit's prescription.
// ════════════════════════════════════════════════════════════════════
class _PreviousHistoryPage extends StatelessWidget {
  final String patientName;
  final List<AppointmentList> visits;
  final ValueChanged<AppointmentList> onSelect;

  const _PreviousHistoryPage({
    required this.patientName,
    required this.visits,
    required this.onSelect,
  });

  String _fmtDate(String? raw) {
    final d = DateTime.tryParse(raw ?? '');
    return d == null ? 'Unknown date' : DateFormat('EEEE, d MMMM yyyy').format(d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(children: [
        Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(bottom: BorderSide(color: kBorder, width: 1)),
          ),
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
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
                Container(
                  width: 34, height: 34,
                  decoration: BoxDecoration(
                    color: kPurpleLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPurple.withOpacity(0.2)),
                  ),
                  child: const Icon(Icons.history_rounded, color: kPurpleDark, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Previous History', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: kTextPrimary)),
                  const SizedBox(height: 1),
                  Text(patientName, style: const TextStyle(fontSize: 11, color: kTextSecondary), overflow: TextOverflow.ellipsis),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                  decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(20)),
                  child: Text('${visits.length}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kPurpleDark)),
                ),
              ]),
            ),
          ),
        ),
        Expanded(
          child: visits.isEmpty
              ? const Center(child: Text('No previous visits', style: TextStyle(color: kTextMuted, fontSize: 13)))
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
                  itemCount: visits.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final v = visits[i];
                    return GestureDetector(
                      onTap: () => onSelect(v),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: kBorder),
                          boxShadow: const [BoxShadow(color: Color(0x08000000), blurRadius: 8, offset: Offset(0, 2))],
                        ),
                        child: Row(children: [
                          Container(
                            width: 36, height: 36,
                            decoration: BoxDecoration(color: kPurpleLight, borderRadius: BorderRadius.circular(10)),
                            child: const Icon(Icons.event_note_rounded, color: kPurpleDark, size: 16),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(_fmtDate(v.appointmentDate), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                            if (v.queueNumber != null) ...[
                              const SizedBox(height: 3),
                              Text('Queue #${v.queueNumber}', style: const TextStyle(fontSize: 11, color: kTextMuted)),
                            ],
                          ])),
                          const Icon(Icons.chevron_right_rounded, color: kTextMuted, size: 20),
                        ]),
                      ),
                    );
                  },
                ),
        ),
      ]),
    );
  }
}

