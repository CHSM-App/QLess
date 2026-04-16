import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';

class _C {
  _C._();
  static const teal = Color(0xFF26C6B0);
  static const tealLight = Color(0xFFD9F5F1);
  static const textPrimary = Color(0xFF2D3748);
  static const textMuted = Color(0xFFA0AEC0);
  static const border = Color(0xFFEDF2F7);
  static const bg = Color(0xFFF8FFFE);
  static const card = Colors.white;
  static const red = Color(0xFFFC8181);
  static const green = Color(0xFF68D391);
}

// ─────────────────────────────────────────────
// Main Page
// ─────────────────────────────────────────────
class DoctorMedicinePage extends ConsumerStatefulWidget {
  const DoctorMedicinePage({super.key});

  @override
  ConsumerState<DoctorMedicinePage> createState() => _DoctorMedicinePageState();
}

class _DoctorMedicinePageState extends ConsumerState<DoctorMedicinePage> {
  final _searchController = TextEditingController();
  int _selectedType = 0;
  bool _hasFetched = false;

  static const _types = ['All', 'Tablet', 'Lotion', 'Syrup', 'Injection', 'Drops', 'Spray'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refreshMedicines(force: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _refreshMedicines({required bool force}) {
    if (_hasFetched && !force) return;
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (doctorId == 0) return;
    _hasFetched = true;
    ref.read(doctorLoginViewModelProvider.notifier).fetchAllMedicines(doctorId);
  }

  void _goToAddMedicine() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicinePage()),
    );
    if (result == true) _refreshMedicines(force: true);
  }

  void _confirmDelete(Medicine medicine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Medicine?', style: TextStyle(fontWeight: FontWeight.w600)),
        content: Text('Remove "${medicine.medicineName ?? 'this medicine'}" permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: _C.red),
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(prescriptionViewModelProvider.notifier).deleteMedicine(medicine.medicineId ?? 0);
              _refreshMedicines(force: true);
              _showSnack('Medicine removed');
            },
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: _C.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  List<Medicine> _filtered(List<Medicine> list) {
    final query = _searchController.text.toLowerCase().trim();
    return list.where((m) {
      final typeMatch = _selectedType == 0 || m.medTypeName == _types[_selectedType];
      final searchMatch = query.isEmpty ||
          (m.medicineName?.toLowerCase().contains(query) ?? false) ||
          (m.medTypeName?.toLowerCase().contains(query) ?? false);
      return typeMatch && searchMatch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorLoginViewModelProvider);
    final medicinesAsync = state.medicines ?? const AsyncValue.loading();

    return Scaffold(
      backgroundColor: _C.bg,
      body: Column(
        children: [
          _TopBar(
            searchController: _searchController,
            selectedType: _selectedType,
            types: _types,
            onSearchChanged: () => setState(() {}),
            onTypeSelected: (i) => setState(() => _selectedType = i),
          ),

          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
            child: medicinesAsync.when(
              data: (list) => _CountRow(count: _filtered(list).length, total: list.length),
              loading: () => const Text('Loading medicines...', style: TextStyle(color: _C.textMuted)),
              error: (_, __) => const SizedBox(),
            ),
          ),

          Expanded(
            child: medicinesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: _C.teal)),
              error: (_, __) => _ErrorState(onRetry: () => _refreshMedicines(force: true)),
              data: (medicines) {
                final filtered = _filtered(medicines);
                if (filtered.isEmpty) {
                  return _EmptyState(hasFilters: _selectedType != 0 || _searchController.text.isNotEmpty);
                }

                return LayoutBuilder(
                  builder: (context, constraints) {
                    final isWideScreen = constraints.maxWidth > 900;

                    return RefreshIndicator(
                      color: _C.teal,
                      onRefresh: () async => _refreshMedicines(force: true),
                      child: isWideScreen
                          ? _buildCompactGrid(filtered)
                          : _buildCompactList(filtered),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddMedicine,
        backgroundColor: _C.teal,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Add Medicine', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
    );
  }

  // Compact List (Mobile)
  Widget _buildCompactList(List<Medicine> medicines) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      itemCount: medicines.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _CompactMedicineCard(
        medicine: medicines[i],
        onDelete: () => _confirmDelete(medicines[i]),
      ),
    );
  }

  // Compact Grid (Tablet/Desktop)
  Widget _buildCompactGrid(List<Medicine> medicines) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 90),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 340,
        childAspectRatio: 3.4,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: medicines.length,
      itemBuilder: (_, i) => _CompactMedicineCard(
        medicine: medicines[i],
        onDelete: () => _confirmDelete(medicines[i]),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Compact Medicine Card (Main Focus)
// ─────────────────────────────────────────────
class _CompactMedicineCard extends StatelessWidget {
  const _CompactMedicineCard({required this.medicine, required this.onDelete});

  final Medicine medicine;
  final VoidCallback onDelete;

  static const _typeStyles = {
    'Tablet': _TypeStyle(bg: Color(0xFFE0F2FE), fg: Color(0xFF26C6B0), icon: Icons.medication_rounded),
    'Lotion': _TypeStyle(bg: Color(0xFFF3E8FF), fg: Color(0xFF7C3AED), icon: Icons.science_outlined),
    'Syrup': _TypeStyle(bg: Color(0xFFDCFCE7), fg: Color(0xFF10B981), icon: Icons.local_drink_outlined),
    'Injection': _TypeStyle(bg: Color(0xFFFEF3C7), fg: Color(0xFFF59E0B), icon: Icons.colorize_outlined),
    'Drops': _TypeStyle(bg: Color(0xFFEDE9FE), fg: Color(0xFF7C3AED), icon: Icons.water_drop_outlined),
    'Spray': _TypeStyle(bg: Color(0xFFDCFCE7), fg: Color(0xFF10B981), icon: Icons.air_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final style = _typeStyles[medicine.medTypeName] ??
        const _TypeStyle(bg: Color(0xFFF1F5F9), fg: Colors.grey, icon: Icons.medication_outlined);

    return Container(
      decoration: BoxDecoration(
        color: _C.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _C.border),
        boxShadow: const [
          BoxShadow(color: Color(0x05000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          // Icon
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: style.bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(style.icon, color: style.fg, size: 22),
          ),

          const SizedBox(width: 12),

          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.medicineName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: _C.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    medicine.medTypeName ?? '—',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: style.fg,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Delete Button
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: _C.red.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.delete_outline_rounded, color: _C.red, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypeStyle {
  const _TypeStyle({required this.bg, required this.fg, required this.icon});
  final Color bg, fg;
  final IconData icon;
}

// Top Bar, CountRow, EmptyState, ErrorState (compact version)
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.searchController,
    required this.selectedType,
    required this.types,
    required this.onSearchChanged,
    required this.onTypeSelected,
  });

  final TextEditingController searchController;
  final int selectedType;
  final List<String> types;
  final VoidCallback onSearchChanged;
  final ValueChanged<int> onTypeSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _C.card,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 12),
      child: Column(
        children: [
          // Search
          Container(
            height: 48,
            decoration: BoxDecoration(
              border: Border.all(color: _C.border),
              borderRadius: BorderRadius.circular(14),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              style: const TextStyle(fontSize: 14.5),
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                hintStyle: TextStyle(color: _C.textMuted, fontSize: 14.5),
                prefixIcon: const Icon(Icons.search_rounded, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () {
                        searchController.clear();
                        onSearchChanged();
                      })
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // Filter Chips (Compact)
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (context, i) {
                final selected = selectedType == i;
                return GestureDetector(
                  onTap: () => onTypeSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected ? _C.teal : _C.card,
                      border: Border.all(color: selected ? _C.teal : _C.border),
                      borderRadius: BorderRadius.circular(30),
                    ),
                    child: Text(
                      types[i],
                      style: TextStyle(
                        fontSize: 12.8,
                        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                        color: selected ? Colors.white : _C.textMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _CountRow extends StatelessWidget {
  const _CountRow({required this.count, required this.total});
  final int count, total;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text('$count medicine${count != 1 ? 's' : ''}',
              style: TextStyle(fontSize: 13.5, color: _C.textMuted)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
            decoration: BoxDecoration(color: _C.tealLight, borderRadius: BorderRadius.circular(20)),
            child: Text('$total total', style: TextStyle(fontSize: 12, color: _C.teal, fontWeight: FontWeight.w600)),
          ),
        ],
      );
}

class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({this.hasFilters = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 42, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(hasFilters ? 'No matching medicines' : 'No medicines added yet',
                style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
              hasFilters ? 'Try different filter or search' : 'Tap + to add new medicine',
              style: TextStyle(fontSize: 13.5, color: _C.textMuted),
            ),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 42, color: Colors.redAccent),
            const SizedBox(height: 16),
            const Text('Failed to load', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      );
}