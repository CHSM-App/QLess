// DEMO: five alternative layouts for the prescription medicine section, so
// doctors can try them side by side. Every layout edits the same
// List<MedicineEntry>, so validation and saving are untouched. Delete this
// file (and the switcher in _medicinesHeader) once one layout is chosen.
part of 'doctor_precriptionentry_screen.dart';

const kMedLayoutNames = ['Current', '1 · Table', '2 · Tap chips', '3 · Step by step', '4 · Quick grid', '5 · Shorthand'];

/// Selected layout; top-level so it sticks while the doctor moves between patients.
int medLayoutDemo = 0;

const _kDayChoices = [3, 5, 7, 10, 15, 30];
const _kFoodChoices = ['After Food', 'Before Food', 'With Food', 'Empty Stomach', 'At Bedtime'];
const _kFoodShort = {
  'After Food': 'AF', 'Before Food': 'BF', 'With Food': 'WF',
  'Empty Stomach': 'ES', 'At Bedtime': 'HS', 'As Directed': 'SOS',
};
const _kSlotNames = ['Morning', 'Afternoon', 'Night'];

// ── Shared helpers ────────────────────────────────────────────────────

MedicineType _typeOf(Medicine m) => MedicineType.values.firstWhere(
    (t) => t.typeId == (m.medTypeId ?? 1), orElse: () => MedicineType.tablet);

/// The amount one tap on a slot puts in.
String _onValue(MedicineType t) => switch (t) {
      MedicineType.syrups => '5ml',
      MedicineType.drops => '2',
      MedicineType.lotions => 'Apply',
      MedicineType.inhalers || MedicineType.sprays => '1 puff',
      MedicineType.powders => '½ tsp',
      _ => '1',
    };

List<String> _slots(MedicineEntry e) {
  final p = e.dosage.split('-');
  return p.length == 3 ? p : ['0', '0', '0'];
}

void _setSlot(MedicineEntry e, int i, String v) {
  final p = _slots(e)..[i] = v;
  e.dosage = p.join('-');
  e.frequency = p.map((s) => s == '0' ? '0' : '1').join('-');
  _demoQty(e);
}

int? _days(MedicineEntry e) {
  final n = int.tryParse(RegExp(r'\d+').firstMatch(e.duration)?.group(0) ?? '');
  if (n == null) return null;
  final d = e.duration.toLowerCase();
  return d.contains('week') ? n * 7 : d.contains('month') ? n * 30 : n;
}

void _setDays(MedicineEntry e, int? n) {
  e.duration = n == null ? '' : '$n days';
  _demoQty(e);
}

void _demoQty(MedicineEntry e) {
  if (e.fromClinic && e.qtyAuto) e.qtyGiven = e.suggestedQty();
}

String _fmtN(double v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Fill [e] from a catalog pick, the way _MedCard does: type defaults, then
/// clinic stock when it is on the shelf.
void _demoPick(MedicineEntry e, Medicine m, Map<int, ClinicStockItem> stock) {
  final t = _typeOf(m);
  if (t != e.type || e.medicineId == null) {
    e.type = t;
    final on = _onValue(t);
    e.dosage = '$on-0-$on';
    e.frequency = '1-0-1';
  }
  e.medicineId = m.medicineId;
  e.selectedName = m.medicineName ?? '';
  e.searchText = '';
  e.hasError = false;
  final item = stock[m.medicineId];
  e.source = item != null && item.balance > 0 ? 'clinic' : 'outside';
  e.administered = e.fromClinic && t == MedicineType.injections;
  e.unitPrice = e.fromClinic && item?.salePrice != null ? _fmtN(item!.salePrice!) : '';
  e.qtyAuto = true;
  _demoQty(e);
}

/// "1-0-1 · 5 days · After Food" — how the medicine reads back to the doctor.
String _summary(MedicineEntry e) => [
      e.dosage,
      if (e.duration.isNotEmpty) e.duration,
      if (e.timing.isNotEmpty && e.type != MedicineType.lotions) e.timing,
    ].join('  ·  ');

/// Parses paper-style shorthand like "1-0-1 5d AF". Unknown words are ignored.
({String? dosage, String? duration, String? timing}) parseRxShorthand(String text) {
  String? dosage, duration, timing;
  const food = {
    'AF': 'After Food', 'BF': 'Before Food', 'WF': 'With Food',
    'ES': 'Empty Stomach', 'HS': 'At Bedtime', 'SOS': 'As Directed',
  };
  final tokens = text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    final up = t.toUpperCase();
    if ('-'.allMatches(t).length == 2) {
      dosage = t.toLowerCase();
    } else if (food.containsKey(up)) {
      timing = food[up];
    } else {
      // "5d", "2w", "1m", or "5 days" split over two tokens
      var m = RegExp(r'^(\d+)(d|days?|w|wks?|weeks?|m|mon|months?)$', caseSensitive: false).firstMatch(t);
      if (m == null && RegExp(r'^\d+$').hasMatch(t) && i + 1 < tokens.length) {
        m = RegExp(r'^(\d+)(d|days?|w|wks?|weeks?|m|mon|months?)$', caseSensitive: false)
            .firstMatch('$t${tokens[i + 1]}');
        if (m != null) i++;
      }
      if (m != null) {
        final n = m.group(1)!;
        final u = m.group(2)!.toLowerCase();
        final unit = u.startsWith('w') ? 'weeks' : u.startsWith('m') ? 'months' : 'days';
        duration = '$n ${n == '1' ? unit.substring(0, unit.length - 1) : unit}';
      }
    }
  }
  return (dosage: dosage, duration: duration, timing: timing);
}

String _toShorthand(MedicineEntry e) {
  final m = RegExp(r'^(\d+)\s*(\w)').firstMatch(e.duration);
  return [
    e.dosage,
    if (m != null) '${m.group(1)}${m.group(2)!.toLowerCase()}',
    if (_kFoodShort[e.timing] != null) _kFoodShort[e.timing]!,
  ].join(' ');
}

BoxDecoration _box({Color? border, Color color = Colors.white}) => BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: border ?? kBorder),
    );

const _tsName = TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: kTextPrimary);
const _tsSmall = TextStyle(fontSize: 11, color: kTextSecondary);

/// The layout switcher shown above the medicine section.
class MedLayoutSwitcher extends StatelessWidget {
  final ValueChanged<int> onChanged;
  const MedLayoutSwitcher({super.key, required this.onChanged});

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          const Text('Try layout: ', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted)),
          for (var i = 0; i < kMedLayoutNames.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(
                label: Text(kMedLayoutNames[i]),
                selected: medLayoutDemo == i,
                onSelected: (_) => onChanged(i),
                labelStyle: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600,
                    color: medLayoutDemo == i ? Colors.white : kTextPrimary),
                selectedColor: kPrimary,
                backgroundColor: Colors.white,
                showCheckmark: false,
                side: const BorderSide(color: kBorder),
                visualDensity: VisualDensity.compact,
              ),
            ),
        ]),
      );
}

/// Search-as-you-type medicine picker; clears itself after each pick.
class _MedSearch extends StatelessWidget {
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final ValueChanged<Medicine> onPicked;
  final String hint;
  final bool dense;

  const _MedSearch({
    super.key, required this.medicines, required this.stock, required this.onPicked,
    this.hint = 'Type medicine name…', this.dense = false,
  });

  @override
  Widget build(BuildContext context) => Autocomplete<Medicine>(
        displayStringForOption: (m) => m.medicineName ?? '',
        optionsBuilder: (v) {
          final q = v.text.trim().toLowerCase();
          final list = medicines.where((m) => (m.medicineName ?? '').toLowerCase().contains(q)).toList()
            ..sort((a, b) {
              // names starting with the query first, then alphabetical
              final sa = (a.medicineName ?? '').toLowerCase().startsWith(q) ? 0 : 1;
              final sb = (b.medicineName ?? '').toLowerCase().startsWith(q) ? 0 : 1;
              return sa != sb ? sa - sb : (a.medicineName ?? '').toLowerCase().compareTo((b.medicineName ?? '').toLowerCase());
            });
          return list.take(40);
        },
        onSelected: onPicked,
        fieldViewBuilder: (ctx, ctrl, focus, submit) => TextField(
          controller: ctrl,
          focusNode: focus,
          onSubmitted: (_) => submit(),
          onTapOutside: (_) => focus.unfocus(),
          style: TextStyle(fontSize: dense ? 13 : 14, fontWeight: FontWeight.w600, color: kTextPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 12.5, color: kTextMuted),
            prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
            prefixIconConstraints: const BoxConstraints(minWidth: 36),
            filled: true,
            fillColor: kBg,
            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: dense ? 9 : 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
          ),
        ),
        optionsViewBuilder: (ctx, select, options) => Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(10),
            child: ConstrainedBox(
              // The popup lives in the full-screen overlay, which the keyboard
              // doesn't shrink — size it to what is left above the keyboard.
              constraints: BoxConstraints(
                maxWidth: 340,
                maxHeight: ((MediaQuery.sizeOf(ctx).height - MediaQuery.viewInsetsOf(ctx).bottom) * 0.45).clamp(120.0, 260.0),
              ),
              child: ListView(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                children: [
                  for (final m in options)
                    InkWell(
                      onTap: () => select(m),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                        child: Row(children: [
                          Icon(_typeOf(m).icon, size: 15, color: _typeOf(m).color),
                          const SizedBox(width: 9),
                          Expanded(child: Text(m.medicineName ?? '', style: const TextStyle(fontSize: 13, color: kTextPrimary),
                              overflow: TextOverflow.ellipsis)),
                          if ((stock[m.medicineId]?.balance ?? 0) > 0)
                            Text('${_fmtN(stock[m.medicineId]!.balance)} in stock',
                                style: const TextStyle(fontSize: 10.5, color: kGreenDark, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Picks once, then the parent swaps in a new (empty) search.
class _ClearingSearch extends StatefulWidget {
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final ValueChanged<Medicine> onPicked;
  final String hint;
  final bool dense;
  const _ClearingSearch({required this.medicines, required this.stock, required this.onPicked,
      this.hint = 'Type medicine name…', this.dense = false});

  @override
  State<_ClearingSearch> createState() => _ClearingSearchState();
}

class _ClearingSearchState extends State<_ClearingSearch> {
  int _gen = 0;
  @override
  Widget build(BuildContext context) => _MedSearch(
        key: ValueKey(_gen),
        medicines: widget.medicines, stock: widget.stock, hint: widget.hint, dense: widget.dense,
        onPicked: (m) {
          widget.onPicked(m);
          setState(() => _gen++);
        },
      );
}

/// Morning / Afternoon / Night toggle. Tap = on/off, long-press = pick amount.
class _SlotToggle extends StatelessWidget {
  final MedicineEntry e;
  final int slot;
  final VoidCallback changed;
  final bool big;
  final bool compact;
  const _SlotToggle({required this.e, required this.slot, required this.changed, this.big = false, this.compact = false});

  Future<void> _pickAmount(BuildContext context) async {
    final opts = (_kDosageOpts[e.type.name] ?? const ['0', '1']);
    final box = context.findRenderObject() as RenderBox;
    final pos = box.localToGlobal(Offset.zero);
    final v = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height, pos.dx + 1, 0),
      items: [for (final o in opts) PopupMenuItem(value: o, height: 38, child: Text(o == '0' ? 'None' : o))],
    );
    if (v != null) {
      _setSlot(e, slot, v);
      changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final v = _slots(e)[slot];
    final on = v != '0';
    final c = e.type.color;
    final label = compact ? _kSlotNames[slot][0] : _kSlotNames[slot];
    return GestureDetector(
      onTap: () {
        _setSlot(e, slot, on ? '0' : _onValue(e.type));
        changed();
      },
      onLongPress: () => _pickAmount(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: EdgeInsets.symmetric(vertical: big ? 18 : (compact ? 6 : 9), horizontal: compact ? 0 : 4),
        decoration: BoxDecoration(
          color: on ? c : Colors.white,
          borderRadius: BorderRadius.circular(big ? 14 : 10),
          border: Border.all(color: on ? c : kDivider, width: 1.3),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          if (big) Icon([Icons.wb_sunny_outlined, Icons.light_mode_outlined, Icons.nights_stay_outlined][slot],
              color: on ? Colors.white : kTextMuted, size: 26),
          Text(label, maxLines: 1, overflow: TextOverflow.fade, softWrap: false,
              style: TextStyle(fontSize: big ? 14 : (compact ? 11 : 12), fontWeight: FontWeight.w700,
                  color: on ? Colors.white : kTextSecondary)),
          if (!compact)
            Text(on ? v : '—', style: TextStyle(fontSize: big ? 13 : 11, color: on ? Colors.white : kTextMuted)),
        ]),
      ),
    );
  }
}

Widget _slotRow(MedicineEntry e, VoidCallback changed, {bool big = false, bool compact = false, double gap = 8}) => Row(children: [
      for (var i = 0; i < 3; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: _SlotToggle(e: e, slot: i, changed: changed, big: big, compact: compact)),
      ],
    ]);

Widget _pill(String label, bool selected, VoidCallback onTap, {double fontSize = 12}) => GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kPrimary : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? kPrimary : kDivider),
        ),
        child: Text(label, style: TextStyle(fontSize: fontSize, fontWeight: FontWeight.w600,
            color: selected ? Colors.white : kTextPrimary)),
      ),
    );

/// Qty box that follows the auto-suggested quantity until the doctor types.
class _QtyBox extends StatefulWidget {
  final MedicineEntry e;
  final VoidCallback changed;
  const _QtyBox({required this.e, required this.changed});
  @override
  State<_QtyBox> createState() => _QtyBoxState();
}

class _QtyBoxState extends State<_QtyBox> {
  late final _ctrl = TextEditingController(text: widget.e.qtyGiven);

  @override
  void didUpdateWidget(covariant _QtyBox old) {
    super.didUpdateWidget(old);
    if (_ctrl.text != widget.e.qtyGiven) _ctrl.text = widget.e.qtyGiven;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 58,
        child: TextField(
          controller: _ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
          decoration: InputDecoration(
            isDense: true,
            hintText: 'qty',
            contentPadding: const EdgeInsets.symmetric(vertical: 7),
            filled: true,
            fillColor: widget.e.hasError ? kRedLight : kBg,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: kBorder)),
          ),
          onChanged: (v) {
            widget.e.qtyGiven = v;
            widget.e.qtyAuto = false;
            widget.e.hasError = false;
            widget.changed();
          },
        ),
      );
}

/// One-line supply: "Clinic | Shop" + qty when given from the clinic.
class _SupplyLine extends StatelessWidget {
  final MedicineEntry e;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const _SupplyLine({required this.e, required this.stock, required this.changed});

  void _set(String s) {
    e.source = s;
    e.hasError = false;
    if (e.fromClinic) {
      e.qtyAuto = true;
      _demoQty(e);
      final p = stock[e.medicineId]?.salePrice;
      if (e.unitPrice.isEmpty && p != null) e.unitPrice = _fmtN(p);
      if (e.type == MedicineType.injections) e.administered = true;
    }
    changed();
  }

  @override
  Widget build(BuildContext context) {
    if (e.medicineId == null) return const SizedBox.shrink();
    final item = stock[e.medicineId];
    if (item == null) {
      return const Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.storefront_outlined, size: 14, color: kTextMuted),
        SizedBox(width: 4),
        Text('Medical shop', style: _tsSmall),
      ]);
    }
    return Row(mainAxisSize: MainAxisSize.min, children: [
      _pill('Clinic (${_fmtN(item.balance)})', e.fromClinic, () => _set('clinic'), fontSize: 11),
      const SizedBox(width: 5),
      _pill('Shop', !e.fromClinic, () => _set('outside'), fontSize: 11),
      if (e.fromClinic) ...[const SizedBox(width: 6), _QtyBox(e: e, changed: changed)],
    ]);
  }
}

Widget _delBtn(VoidCallback onTap) => IconButton(
      onPressed: onTap,
      icon: const Icon(Icons.close_rounded, size: 18, color: kTextMuted),
      visualDensity: VisualDensity.compact,
      tooltip: 'Remove',
    );

// ════════════════════════════════════════════════════════════════════
//  1 · TABLE — spreadsheet rows, always one blank row at the bottom
// ════════════════════════════════════════════════════════════════════
class MedTableDemo extends StatelessWidget {
  final List<MedicineEntry> meds;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const MedTableDemo({super.key, required this.meds, required this.medicines, required this.stock, required this.changed});

  static const _w = <double>[30, 190, 46, 46, 46, 64, 96, 240, 40];
  static const _head = ['#', 'Medicine', 'M', 'A', 'N', 'Days', 'Food', 'Give from', ''];

  Widget _cell(int col, Widget child, {Color? bg}) => Container(
        width: _w[col],
        height: 50,
        alignment: col == 1 || col == 7 ? Alignment.centerLeft : Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(color: bg, border: const Border(right: BorderSide(color: kBorder), bottom: BorderSide(color: kBorder))),
        child: child,
      );

  Widget _slotCell(MedicineEntry e, int i) {
    final v = _slots(e)[i];
    return _SlotTapCell(e: e, slot: i, value: v, changed: changed);
  }

  Widget _row(BuildContext context, int i) {
    final e = meds[i];
    final bg = e.hasError ? kRedLight : (i.isOdd ? kPrimaryLighter : Colors.white);
    return Row(key: e.cardKey, children: [
      _cell(0, Text('${i + 1}', style: _tsSmall), bg: bg),
      _cell(1, e.selectedName == null
          ? _MedSearch(medicines: medicines, stock: stock, dense: true, hint: 'Medicine…',
              onPicked: (m) { _demoPick(e, m, stock); changed(); })
          : InkWell(
              onTap: () { e.selectedName = null; e.medicineId = null; changed(); },
              child: Row(children: [
                Icon(e.type.icon, size: 14, color: e.type.color),
                const SizedBox(width: 6),
                Expanded(child: Text(e.selectedName!, style: _tsName.copyWith(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis)),
              ]),
            ), bg: bg),
      for (var s = 0; s < 3; s++) _cell(2 + s, _slotCell(e, s), bg: bg),
      _cell(5, _DaysCell(e: e, changed: changed), bg: bg),
      _cell(6, PopupMenuButton<String>(
        initialValue: e.timing,
        onSelected: (v) { e.timing = v; changed(); },
        itemBuilder: (_) => [for (final f in _kFoodChoices) PopupMenuItem(value: f, child: Text(f))],
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Flexible(child: Text(e.timing.replaceAll(' Food', ''), style: const TextStyle(fontSize: 12, color: kTextPrimary),
              overflow: TextOverflow.ellipsis)),
          const Icon(Icons.arrow_drop_down_rounded, size: 18, color: kTextMuted),
        ]),
      ), bg: bg),
      // scaleDown: a long stock count ("Clinic (1200)") must not overflow the cell
      _cell(7, FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
          child: _SupplyLine(e: e, stock: stock, changed: changed)), bg: bg),
      _cell(8, _delBtn(() { meds.removeAt(i); changed(); }), bg: bg),
    ]);
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: _box(),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              for (var c = 0; c < _head.length; c++)
                Container(
                  width: _w[c], height: 34, alignment: c == 1 || c == 7 ? Alignment.centerLeft : Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: const BoxDecoration(color: kBg, border: Border(right: BorderSide(color: kBorder), bottom: BorderSide(color: kDivider))),
                  child: Text(_head[c], style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kTextSecondary)),
                ),
            ]),
            for (var i = 0; i < meds.length; i++) _row(context, i),
            // The always-empty last row: picking a medicine here adds a row.
            Row(children: [
              _cell(0, const Icon(Icons.add_rounded, size: 16, color: kPrimary)),
              _cell(1, _ClearingSearch(medicines: medicines, stock: stock, dense: true, hint: 'Add medicine…',
                  onPicked: (m) { meds.add(_demoPick2(m, stock)); changed(); })),
              Container(
                width: _w.skip(2).reduce((a, b) => a + b), height: 50, alignment: Alignment.centerLeft,
                padding: const EdgeInsets.only(left: 10),
                decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: kBorder))),
                child: const Text('Tap M / A / N to switch on-off · long-press for ½, 2…', style: TextStyle(fontSize: 11, color: kTextMuted)),
              ),
            ]),
          ]),
        ),
      );
}

MedicineEntry _demoPick2(Medicine m, Map<int, ClinicStockItem> stock) {
  final e = MedicineEntry();
  e.duration = '5 days';
  _demoPick(e, m, stock);
  return e;
}

class _SlotTapCell extends StatelessWidget {
  final MedicineEntry e;
  final int slot;
  final String value;
  final VoidCallback changed;
  const _SlotTapCell({required this.e, required this.slot, required this.value, required this.changed});

  @override
  Widget build(BuildContext context) {
    final on = value != '0';
    return GestureDetector(
      onTap: () { _setSlot(e, slot, on ? '0' : _onValue(e.type)); changed(); },
      onLongPress: () async {
        final box = context.findRenderObject() as RenderBox;
        final pos = box.localToGlobal(Offset.zero);
        final v = await showMenu<String>(
          context: context,
          position: RelativeRect.fromLTRB(pos.dx, pos.dy + box.size.height, pos.dx + 1, 0),
          items: [for (final o in _kDosageOpts[e.type.name] ?? const ['0', '1'])
            PopupMenuItem(value: o, height: 38, child: Text(o == '0' ? 'None' : o))],
        );
        if (v != null) { _setSlot(e, slot, v); changed(); }
      },
      child: Container(
        width: 36, height: 34, alignment: Alignment.center,
        decoration: BoxDecoration(
          color: on ? e.type.color : Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: on ? e.type.color : kDivider),
        ),
        child: Text(on ? value.replaceAll(' puff', 'p').replaceAll('ml', '') : '0',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: on ? Colors.white : kTextMuted)),
      ),
    );
  }
}

class _DaysCell extends StatefulWidget {
  final MedicineEntry e;
  final VoidCallback changed;
  const _DaysCell({required this.e, required this.changed});
  @override
  State<_DaysCell> createState() => _DaysCellState();
}

class _DaysCellState extends State<_DaysCell> {
  late final _ctrl = TextEditingController(text: _days(widget.e)?.toString() ?? '');
  @override
  void didUpdateWidget(covariant _DaysCell old) {
    super.didUpdateWidget(old);
    final t = _days(widget.e)?.toString() ?? '';
    if (_ctrl.text != t) _ctrl.text = t;
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
        decoration: const InputDecoration(isDense: true, hintText: '—', border: InputBorder.none),
        onChanged: (v) { _setDays(widget.e, int.tryParse(v)); widget.changed(); },
      );
}

// ════════════════════════════════════════════════════════════════════
//  2 · TAP CHIPS — everything visible as one-tap chips, no dropdowns
// ════════════════════════════════════════════════════════════════════
class MedChipsDemo extends StatelessWidget {
  final List<MedicineEntry> meds;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const MedChipsDemo({super.key, required this.meds, required this.medicines, required this.stock, required this.changed});

  Widget _lbl(String t) => SizedBox(width: 44, child: Text(t, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted)));

  Widget _card(int i) {
    final e = meds[i];
    final days = _days(e);
    return Container(
      key: e.cardKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 6, 4, 12),
      decoration: _box(border: e.hasError ? kError : e.type.color.withValues(alpha: 0.35)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(e.type.icon, size: 16, color: e.type.color),
          const SizedBox(width: 8),
          Expanded(child: Text('${i + 1}.  ${e.selectedName ?? 'Choose a medicine'}', style: _tsName, overflow: TextOverflow.ellipsis)),
          _delBtn(() { meds.removeAt(i); changed(); }),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _slotRow(e, changed),
            const SizedBox(height: 10),
            SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
              _lbl('Days'),
              for (final d in _kDayChoices) Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _pill('$d', days == d, () { _setDays(e, days == d ? null : d); changed(); }),
              ),
            ])),
            if (e.type != MedicineType.lotions) ...[
              const SizedBox(height: 8),
              SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
                _lbl('Food'),
                for (final f in _kFoodChoices) Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: _pill(f.replaceAll(' Food', ''), e.timing == f, () { e.timing = f; changed(); }),
                ),
              ])),
            ],
            if (e.medicineId != null && stock[e.medicineId] != null) ...[
              const SizedBox(height: 8),
              Row(children: [_lbl('Give'), Flexible(child: _SupplyLine(e: e, stock: stock, changed: changed))]),
            ],
          ]),
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        _ClearingSearch(medicines: medicines, stock: stock, hint: 'Type to add a medicine…',
            onPicked: (m) { meds.insert(0, _demoPick2(m, stock)); changed(); }),
        const SizedBox(height: 4),
        const Text('Tap Morning / Afternoon / Night to switch on-off · long-press for ½, 2…', style: TextStyle(fontSize: 11, color: kTextMuted)),
        const SizedBox(height: 10),
        for (var i = 0; i < meds.length; i++) _card(i),
      ]);
}

// ════════════════════════════════════════════════════════════════════
//  3 · STEP BY STEP — one question per screen, big buttons
// ════════════════════════════════════════════════════════════════════
class MedWizardDemo extends StatelessWidget {
  final List<MedicineEntry> meds;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const MedWizardDemo({super.key, required this.meds, required this.medicines, required this.stock, required this.changed});

  Future<void> _open(BuildContext context, MedicineEntry? existing) async {
    final e = existing ?? (MedicineEntry()..duration = '5 days');
    final done = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _WizardSheet(e: e, medicines: medicines, stock: stock, startStep: existing == null ? 0 : 1),
    );
    if (done == true && existing == null) meds.add(e);
    changed();
    // "Add next" from the sheet comes back as done + reopen
    if (done == true && existing == null && context.mounted && _WizardSheet.addAnother) {
      _WizardSheet.addAnother = false;
      _open(context, null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        for (var i = 0; i < meds.length; i++)
          Container(
            key: meds[i].cardKey,
            margin: const EdgeInsets.only(bottom: 8),
            decoration: _box(border: meds[i].hasError ? kError : null),
            child: ListTile(
              onTap: () => _open(context, meds[i]),
              leading: CircleAvatar(radius: 16, backgroundColor: meds[i].type.colorLight,
                  child: Text('${i + 1}', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: meds[i].type.colorDark))),
              title: Text(meds[i].selectedName ?? 'Choose a medicine', style: _tsName),
              subtitle: Text([
                _summary(meds[i]),
                if (meds[i].fromClinic) 'Clinic ${meds[i].qtyGiven}',
              ].join('  ·  '), style: _tsSmall),
              trailing: _delBtn(() { meds.removeAt(i); changed(); }),
            ),
          ),
        const SizedBox(height: 4),
        FilledButton.icon(
          onPressed: () => _open(context, null),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add medicine'),
          style: FilledButton.styleFrom(
            backgroundColor: kPrimary,
            padding: const EdgeInsets.symmetric(vertical: 16),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        if (meds.isNotEmpty) const Padding(
          padding: EdgeInsets.only(top: 6),
          child: Text('Tap a medicine to change it', textAlign: TextAlign.center, style: TextStyle(fontSize: 11, color: kTextMuted)),
        ),
      ]);
}

class _WizardSheet extends StatefulWidget {
  final MedicineEntry e;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final int startStep;
  const _WizardSheet({required this.e, required this.medicines, required this.stock, required this.startStep});

  // ponytail: static flag to chain "add next" — fine for a demo, a result type if this stays.
  static bool addAnother = false;

  @override
  State<_WizardSheet> createState() => _WizardSheetState();
}

class _WizardSheetState extends State<_WizardSheet> {
  late int _step = widget.startStep;
  MedicineEntry get e => widget.e;
  static const _titles = ['Which medicine?', 'When to take?', 'For how many days?', 'Before or after food?'];

  void _next() {
    final last = e.type == MedicineType.lotions ? 2 : 3;
    if (_step >= last) {
      Navigator.pop(context, true);
    } else {
      setState(() => _step++);
    }
  }

  Widget _bigBtn(String label, bool selected, VoidCallback onTap) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? kPrimary : kBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: selected ? kPrimary : kDivider, width: 1.3),
          ),
          child: Text(label, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: selected ? Colors.white : kTextPrimary)),
        ),
      );

  Widget _body() {
    switch (_step) {
      case 0:
        // Results inside the sheet (not a popup): the sheet sits on the
        // keyboard, so a popup below the field had no room at all.
        return Flexible(child: _InlineMedPicker(medicines: widget.medicines, stock: widget.stock,
            onPicked: (m) { _demoPick(e, m, widget.stock); _next(); }));
      case 1:
        return Column(children: [
          _slotRow(e, () => setState(() {}), big: true, gap: 10),
          const SizedBox(height: 8),
          const Text('Long-press a box for ½, 2 …', style: TextStyle(fontSize: 11, color: kTextMuted)),
        ]);
      case 2:
        final days = _days(e);
        return GridView.count(
          crossAxisCount: 3, shrinkWrap: true, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final d in _kDayChoices) _bigBtn('$d days', days == d, () { _setDays(e, d); _next(); }),
          ],
        );
      default:
        return GridView.count(
          crossAxisCount: 2, shrinkWrap: true, mainAxisSpacing: 10, crossAxisSpacing: 10, childAspectRatio: 2.6,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final f in _kFoodChoices) _bigBtn(f, e.timing == f, () { e.timing = f; _next(); }),
          ],
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final last = e.type == MedicineType.lotions ? 2 : 3;
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 14, 18, 18 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          for (var i = 0; i <= last; i++) Expanded(child: Container(
            height: 4, margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(color: i <= _step ? kPrimary : kBorder, borderRadius: BorderRadius.circular(2)),
          )),
        ]),
        const SizedBox(height: 14),
        if (e.selectedName != null && _step > 0)
          Text(e.selectedName!, style: const TextStyle(fontSize: 12, color: kTextSecondary, fontWeight: FontWeight.w600)),
        Text(_titles[_step], style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kTextPrimary)),
        const SizedBox(height: 14),
        _body(),
        if (_step == 3 || (_step == 2 && last == 2) || _step == 1) ...[
          const SizedBox(height: 10),
          if (_step == 1 || _step == last) _SupplyLine(e: e, stock: widget.stock, changed: () => setState(() {})),
        ],
        const SizedBox(height: 14),
        Row(children: [
          if (_step > 0) TextButton(onPressed: () => setState(() => _step--), child: const Text('Back')),
          const Spacer(),
          if (_step == last && widget.startStep == 0)
            TextButton(onPressed: () { _WizardSheet.addAnother = true; Navigator.pop(context, true); }, child: const Text('Save & add next')),
          if (_step > 0) FilledButton(
            onPressed: _next,
            style: FilledButton.styleFrom(backgroundColor: kPrimary),
            child: Text(_step == last ? 'Done' : 'Next'),
          ),
        ]),
      ]),
    );
  }
}

class _InlineMedPicker extends StatefulWidget {
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final ValueChanged<Medicine> onPicked;
  const _InlineMedPicker({required this.medicines, required this.stock, required this.onPicked});
  @override
  State<_InlineMedPicker> createState() => _InlineMedPickerState();
}

class _InlineMedPickerState extends State<_InlineMedPicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final q = _q.trim().toLowerCase();
    final list = widget.medicines.where((m) => (m.medicineName ?? '').toLowerCase().contains(q)).toList()
      ..sort((a, b) => (a.medicineName ?? '').toLowerCase().compareTo((b.medicineName ?? '').toLowerCase()));
    return Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        autofocus: true,
        onChanged: (v) => setState(() => _q = v),
        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: kTextPrimary),
        decoration: InputDecoration(
          isDense: true, hintText: 'Type medicine name…', filled: true, fillColor: kBg,
          prefixIcon: const Icon(Icons.search_rounded, color: kPrimary, size: 18),
          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      ),
      const SizedBox(height: 6),
      Flexible(
        child: list.isEmpty
            ? const Padding(padding: EdgeInsets.all(12), child: Text('No medicine found', style: _tsSmall))
            : ListView.separated(
                shrinkWrap: true,
                padding: EdgeInsets.zero,
                itemCount: list.length,
                separatorBuilder: (_, __) => const Divider(height: 1, color: kBorder),
                itemBuilder: (_, i) {
                  final m = list[i];
                  final bal = widget.stock[m.medicineId]?.balance ?? 0;
                  return ListTile(
                    dense: true,
                    onTap: () => widget.onPicked(m),
                    leading: Icon(_typeOf(m).icon, size: 18, color: _typeOf(m).color),
                    title: Text(m.medicineName ?? '', style: const TextStyle(fontSize: 14, color: kTextPrimary)),
                    trailing: bal > 0 ? Text('${_fmtN(bal)} in stock',
                        style: const TextStyle(fontSize: 11, color: kGreenDark, fontWeight: FontWeight.w600)) : null,
                  );
                },
              ),
      ),
    ]);
  }
}

// ════════════════════════════════════════════════════════════════════
//  4 · QUICK GRID — tap a medicine button, sensible defaults filled in
// ════════════════════════════════════════════════════════════════════
class MedGridDemo extends StatefulWidget {
  final List<MedicineEntry> meds;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const MedGridDemo({super.key, required this.meds, required this.medicines, required this.stock, required this.changed});
  @override
  State<MedGridDemo> createState() => _MedGridDemoState();
}

class _MedGridDemoState extends State<MedGridDemo> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final meds = widget.meds;
    final q = _q.toLowerCase();
    // In-stock medicines first: they are what this clinic usually gives.
    final shown = widget.medicines.where((m) => (m.medicineName ?? '').toLowerCase().contains(q)).toList()
      ..sort((a, b) {
        final sa = (widget.stock[a.medicineId]?.balance ?? 0) > 0 ? 0 : 1;
        final sb = (widget.stock[b.medicineId]?.balance ?? 0) > 0 ? 0 : 1;
        return sa != sb ? sa - sb : (a.medicineName ?? '').toLowerCase().compareTo((b.medicineName ?? '').toLowerCase());
      });

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      TextField(
        onChanged: (v) => setState(() => _q = v),
        style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        decoration: InputDecoration(
          isDense: true, hintText: 'Filter medicines…', filled: true, fillColor: kBg,
          prefixIcon: const Icon(Icons.filter_list_rounded, size: 18, color: kPrimary),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
        ),
      ),
      const SizedBox(height: 8),
      ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 150),
        child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: [
          for (final m in shown.take(60))
            Builder(builder: (_) {
              final added = meds.any((e) => e.medicineId == m.medicineId);
              return _pill(added ? '✓ ${m.medicineName}' : (m.medicineName ?? ''), added, () {
                if (added) {
                  meds.removeWhere((e) => e.medicineId == m.medicineId);
                } else {
                  meds.add(_demoPick2(m, widget.stock));
                }
                widget.changed();
              });
            }),
        ])),
      ),
      const Padding(
        padding: EdgeInsets.symmetric(vertical: 6),
        child: Text('Tap a medicine to add it with 1-0-1 · 5 days · After food, then adjust below',
            style: TextStyle(fontSize: 11, color: kTextMuted)),
      ),
      for (var i = 0; i < meds.length; i++) _row(i),
    ]);
  }

  Widget _row(int i) {
    final e = widget.meds[i];
    final days = _days(e) ?? 0;
    final changed = widget.changed;
    return Container(
      key: e.cardKey,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 4, 2, 8),
      decoration: _box(border: e.hasError ? kError : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Text(e.selectedName ?? '—', style: _tsName, overflow: TextOverflow.ellipsis)),
          _delBtn(() { widget.meds.removeAt(i); changed(); }),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Row(children: [
            Expanded(flex: 5, child: _slotRow(e, changed, compact: true, gap: 4)),
            const SizedBox(width: 8),
            // days stepper
            _roundBtn(Icons.remove_rounded, () { _setDays(e, days > 1 ? days - 1 : null); changed(); }),
            SizedBox(width: 44, child: Text(days == 0 ? '—' : '${days}d', textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: kTextPrimary))),
            _roundBtn(Icons.add_rounded, () { _setDays(e, days + 1); changed(); }),
            const SizedBox(width: 8),
            if (e.type != MedicineType.lotions)
              GestureDetector(
                onTap: () { e.timing = e.timing == 'After Food' ? 'Before Food' : 'After Food'; changed(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  decoration: BoxDecoration(color: kInfoLight, borderRadius: BorderRadius.circular(8)),
                  child: Text(_kFoodShort[e.timing] ?? 'AF', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: kInfoDark)),
                ),
              ),
          ]),
        ),
        if (e.medicineId != null && widget.stock[e.medicineId] != null)
          Padding(padding: const EdgeInsets.only(top: 6), child: _SupplyLine(e: e, stock: widget.stock, changed: changed)),
      ]),
    );
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 28, height: 28,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: kDivider)),
          child: Icon(icon, size: 16, color: kTextSecondary),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  5 · SHORTHAND — write it like on paper: "1-0-1 5d AF"
// ════════════════════════════════════════════════════════════════════
class MedShorthandDemo extends StatelessWidget {
  final List<MedicineEntry> meds;
  final List<Medicine> medicines;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  const MedShorthandDemo({super.key, required this.meds, required this.medicines, required this.stock, required this.changed});

  @override
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: _box(color: kPrimaryLighter, border: kPrimaryLight),
          child: const Text(
            'Write like on paper:  1-0-1  5d  AF\n'
            'd / w / m = days / weeks / months  ·  AF BF WF = after / before / with food  ·  HS = bedtime  ·  ES = empty stomach  ·  SOS',
            style: TextStyle(fontSize: 11.5, color: kTextSecondary, height: 1.5),
          ),
        ),
        const SizedBox(height: 10),
        for (var i = 0; i < meds.length; i++)
          _ShorthandRow(key: ObjectKey(meds[i]), index: i, e: meds[i], stock: stock, changed: changed,
              onDelete: () { meds.removeAt(i); changed(); }),
        _ClearingSearch(medicines: medicines, stock: stock, hint: 'Type to add a medicine…',
            onPicked: (m) { meds.add(_demoPick2(m, stock)); changed(); }),
      ]);
}

class _ShorthandRow extends StatefulWidget {
  final int index;
  final MedicineEntry e;
  final Map<int, ClinicStockItem> stock;
  final VoidCallback changed;
  final VoidCallback onDelete;
  const _ShorthandRow({super.key, required this.index, required this.e, required this.stock, required this.changed, required this.onDelete});
  @override
  State<_ShorthandRow> createState() => _ShorthandRowState();
}

class _ShorthandRowState extends State<_ShorthandRow> {
  late final _ctrl = TextEditingController(text: _toShorthand(widget.e));
  static const _quick = ['1-0-1', '1-1-1', '1-0-0', '0-0-1', '3d', '5d', '7d', 'AF', 'BF', 'HS'];

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  void _apply(String text) {
    final r = parseRxShorthand(text);
    final e = widget.e;
    if (r.dosage != null) {
      e.dosage = r.dosage!;
      e.frequency = _slots(e).map((s) => s == '0' ? '0' : '1').join('-');
    }
    e.duration = r.duration ?? '';
    if (r.timing != null) e.timing = r.timing!;
    _demoQty(e);
    widget.changed();
  }

  /// Tap a quick token: replace the same kind of token, or append it.
  void _insert(String tok) {
    final parts = _ctrl.text.trim().split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
    bool sameKind(String t) => tok.contains('-') ? t.contains('-')
        : RegExp(r'^\d').hasMatch(tok) ? RegExp(r'^\d+[a-z]', caseSensitive: false).hasMatch(t) && !t.contains('-')
        : _kFoodShort.containsValue(t.toUpperCase());
    final i = parts.indexWhere(sameKind);
    if (i >= 0) { parts[i] = tok; } else { parts.add(tok); }
    _ctrl.text = parts.join(' ');
    _apply(_ctrl.text);
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.e;
    final r = parseRxShorthand(_ctrl.text);
    final s = _slots(e);
    final readBack = [
      for (var i = 0; i < 3; i++) if (s[i] != '0') '${_kSlotNames[i]} ${s[i]}',
      r.duration ?? 'days?',
      if (e.type != MedicineType.lotions) e.timing,
    ].join(' · ');
    return Container(
      key: e.cardKey,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 4, 4, 10),
      decoration: _box(border: e.hasError ? kError : null),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text('${widget.index + 1}. ', style: _tsName),
          Expanded(child: Text(e.selectedName ?? '—', style: _tsName, overflow: TextOverflow.ellipsis)),
          _delBtn(widget.onDelete),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 8),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            TextField(
              controller: _ctrl,
              onChanged: (v) { _apply(v); setState(() {}); },
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 1, color: kTextPrimary, fontFamily: 'monospace'),
              decoration: InputDecoration(
                isDense: true, hintText: '1-0-1 5d AF',
                filled: true, fillColor: kBg,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: kBorder)),
              ),
            ),
            const SizedBox(height: 4),
            Text(readBack, style: TextStyle(fontSize: 11.5, color: r.duration == null ? kAmberDark : kGreenDark, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Wrap(spacing: 5, runSpacing: 5, children: [
              for (final t in _quick) GestureDetector(
                onTap: () => setState(() => _insert(t)),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: kBg, borderRadius: BorderRadius.circular(6), border: Border.all(color: kDivider)),
                  child: Text(t, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSecondary)),
                ),
              ),
            ]),
            if (e.medicineId != null && widget.stock[e.medicineId] != null)
              Padding(padding: const EdgeInsets.only(top: 8), child: _SupplyLine(e: e, stock: widget.stock, changed: widget.changed)),
          ]),
        ),
      ]),
    );
  }
}
