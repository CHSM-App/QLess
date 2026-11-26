// Clinic medicine stock — doctor and receptionist manage it together.
// Balance = sum of every stock change (purchase, given on a prescription,
// adjustment) and may go negative. Online only: each change carries a
// client_uuid, so a retried save is recorded once.
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/core/network/network_errors.dart';
import 'package:qless/domain/models/clinic_stock.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';

const _primary   = Color(0xFF26C6B0);
const _primaryLt = Color(0xFFD9F5F1);
const _text      = Color(0xFF2D3748);
const _textSub   = Color(0xFF718096);
const _textMuted = Color(0xFFA0AEC0);
const _border    = Color(0xFFEDF2F7);
const _bg        = Color(0xFFF7F8FA);
const _green     = Color(0xFF276749);
const _greenLt   = Color(0xFFDCFCE7);
const _amber     = Color(0xFF975A16);
const _amberLt   = Color(0xFFFEF3C7);
const _red       = Color(0xFFC53030);
const _redLt     = Color(0xFFFEE2E2);

const _units = ['tablet', 'capsule', 'strip', 'bottle', 'vial', 'ampoule', 'tube', 'sachet', 'piece', 'ml'];

String _fmt(num v) => v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(2);

/// Random v4 UUID — dedupes a stock change sent twice.
String _uuid() {
  final r = Random.secure();
  final b = List<int>.generate(16, (_) => r.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final h = b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

/// Latest changes for one medicine at one clinic.
final _movementsProvider = FutureProvider.autoDispose
    .family<List<Map<String, dynamic>>, (String, int)>((ref, key) async {
  final raw = await ref.read(apiServiceProvider).getStockMovements(key.$1, key.$2) as Map<String, dynamic>;
  return (raw['data'] as List<dynamic>? ?? const []).cast<Map<String, dynamic>>();
});

// ════════════════════════════════════════════════════════════════════
//  Entry row on the Medicines page: "Clinic stock · 3 low"
// ════════════════════════════════════════════════════════════════════
class ClinicStockEntry extends ConsumerWidget {
  const ClinicStockEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clinicId = ref.watch(doctorLoginViewModelProvider.select((s) => s.clinicId));
    final stock = ref.watch(clinicStockProvider(clinicId)).valueOrNull ?? const {};
    final low = stock.values.where((s) => s.isLow || s.balance <= 0).length;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 2),
      child: Material(
        color: _primaryLt,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ClinicStockPage())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(children: [
              const Icon(Icons.inventory_2_outlined, color: _primary, size: 18),
              const SizedBox(width: 10),
              const Expanded(child: Text('Clinic stock',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: _text))),
              if (low > 0)
                _Badge('$low low', _amberLt, _amber)
              else if (stock.isNotEmpty)
                _Badge('${stock.length} items', Colors.white, _textSub),
              const SizedBox(width: 6),
              const Icon(Icons.chevron_right_rounded, color: _textSub, size: 20),
            ]),
          ),
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Stock page
// ════════════════════════════════════════════════════════════════════
class ClinicStockPage extends ConsumerStatefulWidget {
  const ClinicStockPage({super.key});

  @override
  ConsumerState<ClinicStockPage> createState() => _ClinicStockPageState();
}

class _ClinicStockPageState extends ConsumerState<ClinicStockPage> {
  final _search = TextEditingController();
  bool _lowOnly = false;

  @override
  void initState() {
    super.initState();
    // The Medicines tab keeps this provider alive; prescriptions saved since
    // then changed the balances.
    Future.microtask(() => ref.invalidate(clinicStockProvider(ref.read(doctorLoginViewModelProvider).clinicId)));
  }

  @override
  void dispose() { _search.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final clinicId = ref.watch(doctorLoginViewModelProvider.select((s) => s.clinicId));
    final async = ref.watch(clinicStockProvider(clinicId));

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Clinic stock', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: _text)),
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        foregroundColor: _text,
        elevation: 0,
        bottom: const PreferredSize(preferredSize: Size.fromHeight(1), child: Divider(height: 1, color: _border)),
      ),
      floatingActionButton: clinicId == null ? null : FloatingActionButton.extended(
        onPressed: () => _addStock(clinicId, async.valueOrNull ?? const {}),
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add stock', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: clinicId == null
          ? const _Empty(icon: Icons.store_outlined, text: 'Select a clinic first')
          : Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Row(children: [
                  Expanded(child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: _deco('Search stock…').copyWith(
                      prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textMuted)),
                  )),
                  const SizedBox(width: 8),
                  FilterChip(
                    label: const Text('Low', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    selected: _lowOnly,
                    onSelected: (v) => setState(() => _lowOnly = v),
                    selectedColor: _amberLt,
                    checkmarkColor: _amber,
                    side: const BorderSide(color: _border),
                  ),
                ]),
              ),
              Expanded(child: async.when(
                loading: () => const Center(child: CircularProgressIndicator(color: _primary)),
                error: (_, __) => const _Empty(icon: Icons.cloud_off_rounded, text: 'Could not load stock'),
                data: (stock) {
                  final q = _search.text.trim().toLowerCase();
                  final items = stock.values.where((s) =>
                      (!_lowOnly || s.isLow || s.balance <= 0) &&
                      (q.isEmpty || (s.medicineName ?? '').toLowerCase().contains(q))).toList()
                    ..sort((a, b) => (a.medicineName ?? '').toLowerCase().compareTo((b.medicineName ?? '').toLowerCase()));
                  return RefreshIndicator(
                    color: _primary,
                    onRefresh: () => ref.refresh(clinicStockProvider(clinicId).future),
                    child: items.isEmpty
                        ? ListView(children: [
                            SizedBox(height: 300, child: _Empty(
                              icon: Icons.inventory_2_outlined,
                              text: stock.isEmpty ? 'No stock yet — tap "Add stock"' : 'Nothing matches',
                            )),
                          ])
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(12, 6, 12, 90),
                            itemCount: items.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 6),
                            itemBuilder: (_, i) => _StockTile(
                              item: items[i],
                              onTap: () => _openItem(clinicId, items[i]),
                            ),
                          ),
                  );
                },
              )),
            ]),
    );
  }

  // Pick one of the doctor's medicines, then record the purchase.
  Future<void> _addStock(String clinicId, Map<int, ClinicStockItem> stock) async {
    final meds = ref.read(doctorLoginViewModelProvider).medicines?.valueOrNull ?? const <Medicine>[];
    final picked = await showModalBottomSheet<Medicine>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _MedicinePicker(medicines: meds),
    );
    if (picked?.medicineId == null || !mounted) return;
    final item = stock[picked!.medicineId] ??
        ClinicStockItem(medicineId: picked.medicineId!, medicineName: picked.displayName);
    await _change(clinicId, item, _Mode.purchase);
  }

  Future<void> _openItem(String clinicId, ClinicStockItem item) => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.white,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
        builder: (sheet) => _ItemSheet(
          clinicId: clinicId,
          item: item,
          onAction: (mode) async {
            Navigator.pop(sheet);
            if (mode == null) {
              await _settings(clinicId, item);
            } else {
              await _change(clinicId, item, mode);
            }
          },
        ),
      );

  Future<void> _change(String clinicId, ClinicStockItem item, _Mode mode) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _ChangeDialog(clinicId: clinicId, item: item, mode: mode),
    );
    if (saved == true) _refresh(clinicId, item.medicineId);
  }

  Future<void> _settings(String clinicId, ClinicStockItem item) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _SettingsDialog(clinicId: clinicId, item: item),
    );
    if (saved == true) _refresh(clinicId, item.medicineId);
  }

  void _refresh(String clinicId, int medicineId) {
    ref.invalidate(clinicStockProvider(clinicId));
    ref.invalidate(_movementsProvider((clinicId, medicineId)));
  }
}

// ════════════════════════════════════════════════════════════════════
//  Pieces
// ════════════════════════════════════════════════════════════════════
class _StockTile extends StatelessWidget {
  final ClinicStockItem item;
  final VoidCallback onTap;
  const _StockTile({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = item.balance <= 0
        ? (_redLt, _red)
        : item.isLow ? (_amberLt, _amber) : (_greenLt, _green);
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: _border)),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(item.medicineName ?? 'Medicine', overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: _text)),
              const SizedBox(height: 2),
              Text([
                if (item.salePrice != null) '₹${_fmt(item.salePrice!)} / ${item.unit ?? 'unit'}',
                if (item.reorderLevel != null) 'reorder at ${_fmt(item.reorderLevel!)}',
              ].join(' · ').ifEmpty('Tap to set price and reorder level'),
                  style: const TextStyle(fontSize: 11, color: _textSub)),
            ])),
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 56),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
              child: Column(children: [
                Text(_fmt(item.balance), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: fg)),
                if (item.unit != null) Text(item.unit!, style: TextStyle(fontSize: 9.5, color: fg)),
              ]),
            ),
          ]),
        ),
      ),
    );
  }
}

extension on String {
  String ifEmpty(String other) => isEmpty ? other : this;
}

enum _Mode { purchase, remove, count }

class _ItemSheet extends ConsumerWidget {
  final String clinicId;
  final ClinicStockItem item;
  final ValueChanged<_Mode?> onAction; // null = settings
  const _ItemSheet({required this.clinicId, required this.item, required this.onAction});

  static const _reasonLabel = {
    'purchase': 'Purchase', 'dispense': 'Given', 'administer': 'Injected',
    'adjust': 'Adjusted', 'return': 'Returned',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final history = ref.watch(_movementsProvider((clinicId, item.medicineId)));
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.7,
      maxChildSize: 0.95,
      builder: (_, scroll) => ListView(controller: scroll, padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        Center(child: Container(width: 36, height: 4,
            decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 12),
        Text(item.medicineName ?? 'Medicine', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
        const SizedBox(height: 2),
        Text('In stock: ${_fmt(item.balance)} ${item.unit ?? ''}',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: item.balance <= 0 ? _red : _textSub)),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, children: [
          _action(Icons.add_shopping_cart_rounded, 'Purchase', () => onAction(_Mode.purchase)),
          _action(Icons.remove_circle_outline_rounded, 'Remove', () => onAction(_Mode.remove)),
          _action(Icons.fact_check_outlined, 'Set count', () => onAction(_Mode.count)),
          _action(Icons.tune_rounded, 'Price & unit', () => onAction(null)),
        ]),
        const SizedBox(height: 18),
        const Text('History', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: _textSub)),
        const SizedBox(height: 6),
        history.when(
          loading: () => const Padding(padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator(color: _primary))),
          error: (e, _) => Text(errorMessage(e), style: const TextStyle(fontSize: 12, color: _red)),
          data: (rows) => rows.isEmpty
              ? const Text('No changes yet', style: TextStyle(fontSize: 12, color: _textMuted))
              : Column(children: [
                  for (final m in rows) _historyRow(m),
                ]),
        ),
      ]),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) => ActionChip(
        avatar: Icon(icon, size: 16, color: _primary),
        label: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _text)),
        onPressed: onTap,
        backgroundColor: _bg,
        side: const BorderSide(color: _border),
      );

  Widget _historyRow(Map<String, dynamic> m) {
    final qty = num.tryParse('${m['qty']}') ?? 0;
    final at = DateTime.tryParse('${m['created_at']}');
    final who = m['created_by_name'] as String?;
    final detail = [
      if (at != null) DateFormat('d MMM, h:mm a').format(at),
      if (who != null && who.isNotEmpty) who,
      if (m['note'] is String && (m['note'] as String).isNotEmpty) m['note'],
      if (m['prescription_id'] != null) 'Rx #${m['prescription_id']}',
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        SizedBox(width: 56, child: Text('${qty > 0 ? '+' : ''}${_fmt(qty)}',
            style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: qty > 0 ? _green : _red))),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_reasonLabel[m['reason']] ?? '${m['reason']}',
              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: _text)),
          if (detail.isNotEmpty) Text(detail, style: const TextStyle(fontSize: 11, color: _textMuted)),
        ])),
      ]),
    );
  }
}

class _MedicinePicker extends StatefulWidget {
  final List<Medicine> medicines;
  const _MedicinePicker({required this.medicines});

  @override
  State<_MedicinePicker> createState() => _MedicinePickerState();
}

class _MedicinePickerState extends State<_MedicinePicker> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final list = widget.medicines
        .where((m) => m.displayName.toLowerCase().contains(_q.toLowerCase()))
        .toList()
      ..sort((a, b) => a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v.trim()),
              decoration: _deco('Search your medicines…').copyWith(
                  prefixIcon: const Icon(Icons.search_rounded, size: 18, color: _textMuted)),
            ),
          ),
          Expanded(child: list.isEmpty
              ? const _Empty(icon: Icons.medication_outlined, text: 'Add the medicine to your list first')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, color: _border),
                  itemBuilder: (_, i) => ListTile(
                    dense: true,
                    title: Text(list[i].displayName, style: const TextStyle(fontSize: 13, color: _text)),
                    subtitle: list[i].medTypeName == null ? null
                        : Text(list[i].medTypeName!, style: const TextStyle(fontSize: 11, color: _textMuted)),
                    onTap: () => Navigator.pop(context, list[i]),
                  ),
                )),
        ]),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Dialogs
// ════════════════════════════════════════════════════════════════════
class _ChangeDialog extends ConsumerStatefulWidget {
  final String clinicId;
  final ClinicStockItem item;
  final _Mode mode;
  const _ChangeDialog({required this.clinicId, required this.item, required this.mode});

  @override
  ConsumerState<_ChangeDialog> createState() => _ChangeDialogState();
}

class _ChangeDialogState extends ConsumerState<_ChangeDialog> {
  final _qty = TextEditingController();
  final _cost = TextEditingController();
  final _note = TextEditingController();
  final _clientUuid = _uuid(); // one per dialog: a retried save is recorded once
  String _why = 'Expired';
  String? _error;
  bool _saving = false;

  static const _removeReasons = ['Expired', 'Damaged', 'Lost', 'Returned to supplier', 'Other'];

  @override
  void dispose() { _qty.dispose(); _cost.dispose(); _note.dispose(); super.dispose(); }

  String get _title => switch (widget.mode) {
        _Mode.purchase => 'Purchase',
        _Mode.remove   => 'Remove from stock',
        _Mode.count    => 'Set actual count',
      };

  Future<void> _save() async {
    final n = double.tryParse(_qty.text.trim());
    final count = widget.mode == _Mode.count;
    if (n == null || n < 0 || (!count && n == 0)) {
      setState(() => _error = count ? 'Enter the count on the shelf' : 'Enter a quantity');
      return;
    }
    // "Set count" records the difference from what the app thinks is there
    final qty = switch (widget.mode) {
      _Mode.purchase => n,
      _Mode.remove   => -n,
      _Mode.count    => n - widget.item.balance,
    };
    if (qty == 0) { Navigator.pop(context, false); return; }

    final note = _note.text.trim();
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(apiServiceProvider).addStockMovement({
        'client_uuid': _clientUuid,
        'clinic_id':   widget.clinicId,
        'medicine_id': widget.item.medicineId,
        'qty':         qty,
        'reason':      widget.mode == _Mode.purchase ? 'purchase' : 'adjust',
        if (widget.mode == _Mode.purchase && _cost.text.trim().isNotEmpty)
          'unit_cost': double.tryParse(_cost.text.trim()),
        'note': switch (widget.mode) {
          _Mode.remove => [_why, if (note.isNotEmpty) note].join(': '),
          _Mode.count  => ['Stock count', if (note.isNotEmpty) note].join(': '),
          _            => note.isEmpty ? null : note,
        },
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = errorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.item.unit ?? 'units';
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(_title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('${widget.item.medicineName ?? ''} — now ${_fmt(widget.item.balance)} $unit',
            style: const TextStyle(fontSize: 12, color: _textSub)),
        const SizedBox(height: 14),
        _field(_qty, widget.mode == _Mode.count ? 'Count on shelf ($unit)' : 'Quantity ($unit)', autofocus: true),
        if (widget.mode == _Mode.purchase) ...[
          const SizedBox(height: 10),
          _field(_cost, 'Purchase price per unit (₹, optional)'),
        ],
        if (widget.mode == _Mode.remove) ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _why,
            items: [for (final r in _removeReasons) DropdownMenuItem(value: r, child: Text(r, style: const TextStyle(fontSize: 13)))],
            onChanged: (v) => setState(() => _why = v ?? _why),
            decoration: _deco('Reason'),
            dropdownColor: Colors.white,
          ),
        ],
        const SizedBox(height: 10),
        TextField(controller: _note, maxLength: 150, decoration: _deco('Note (optional)')),
        if (_error != null) Text(_error!, style: const TextStyle(fontSize: 12, color: _red)),
      ])),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSub))),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

class _SettingsDialog extends ConsumerStatefulWidget {
  final String clinicId;
  final ClinicStockItem item;
  const _SettingsDialog({required this.clinicId, required this.item});

  @override
  ConsumerState<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends ConsumerState<_SettingsDialog> {
  late final _price = TextEditingController(text: widget.item.salePrice == null ? '' : _fmt(widget.item.salePrice!));
  late final _reorder = TextEditingController(text: widget.item.reorderLevel == null ? '' : _fmt(widget.item.reorderLevel!));
  late String? _unit = widget.item.unit;
  String? _error;
  bool _saving = false;

  @override
  void dispose() { _price.dispose(); _reorder.dispose(); super.dispose(); }

  Future<void> _save() async {
    setState(() { _saving = true; _error = null; });
    try {
      await ref.read(apiServiceProvider).saveStockItem({
        'clinic_id':     widget.clinicId,
        'medicine_id':   widget.item.medicineId,
        'unit':          _unit,
        'reorder_level': double.tryParse(_reorder.text.trim()),
        'sale_price':    double.tryParse(_price.text.trim()),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() { _saving = false; _error = errorMessage(e); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final units = {..._units, if (_unit != null) _unit!}.toList();
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Price & unit', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: _text)),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(widget.item.medicineName ?? '', style: const TextStyle(fontSize: 12, color: _textSub)),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _unit,
          items: [for (final u in units) DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))],
          onChanged: (v) => setState(() => _unit = v),
          decoration: _deco('Counted in'),
          dropdownColor: Colors.white,
        ),
        const SizedBox(height: 10),
        _field(_price, 'Price to patient per unit (₹)'),
        const SizedBox(height: 10),
        _field(_reorder, 'Warn when stock is at or below'),
        if (_error != null) Padding(padding: const EdgeInsets.only(top: 8),
            child: Text(_error!, style: const TextStyle(fontSize: 12, color: _red))),
      ])),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: _textSub))),
        FilledButton(
          onPressed: _saving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: _primary),
          child: _saving
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  Small shared bits
// ════════════════════════════════════════════════════════════════════
Widget _field(TextEditingController c, String label, {bool autofocus = false}) => TextField(
      controller: c,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}'))],
      decoration: _deco(label),
    );

InputDecoration _deco(String label) => InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(fontSize: 12.5, color: _textSub),
      isDense: true,
      filled: true,
      fillColor: _bg,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: _primary, width: 1.5)),
    );

class _Badge extends StatelessWidget {
  final String text;
  final Color bg, fg;
  const _Badge(this.text, this.bg, this.fg);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
        child: Text(text, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
      );
}

class _Empty extends StatelessWidget {
  final IconData icon;
  final String text;
  const _Empty({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 36, color: _textMuted),
        const SizedBox(height: 8),
        Text(text, style: const TextStyle(fontSize: 13, color: _textSub)),
      ]));
}
