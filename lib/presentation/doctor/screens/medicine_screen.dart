import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';

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

// ════════════════════════════════════════════════════════════════════
//  PAGE
// ════════════════════════════════════════════════════════════════════
class DoctorMedicinePage extends ConsumerStatefulWidget {
  const DoctorMedicinePage({super.key});

  @override
  ConsumerState<DoctorMedicinePage> createState() => _DoctorMedicinesTabState();
}

class _DoctorMedicinesTabState extends ConsumerState<DoctorMedicinePage> {
  final _searchController = TextEditingController();
  int _selectedType = 0;
  bool _hasFetched = false;
  late final ProviderSubscription<int?> _doctorIdSub;

  static const _types = [
    'All',
    'Tablet',
    'Lotion',
    'Syrup',
    'Injection',
    'Drops',
    'Spray',
  ];

  @override
  void initState() {
    super.initState();
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (prev, next) {
        if (next != null && next > 0) {
          _refreshMedicines(force: false);
        }
      },
    );
    Future.microtask(() => _refreshMedicines(force: false));
  }

  @override
  void dispose() {
    _searchController.dispose();
    _doctorIdSub.close();
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
    if (result == true) {
      final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
      ref
          .read(doctorLoginViewModelProvider.notifier)
          .fetchAllMedicines(doctorId);
    }
  }

  void _confirmDelete(Medicine medicine) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: kCardBg,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kRedAccent.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.delete_outline_rounded,
                  color: kRedAccent, size: 18),
            ),
            const SizedBox(width: 12),
            const Text(
              'Remove medicine',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextDark,
              ),
            ),
          ],
        ),
        content: Text(
          'Remove "${medicine.medicineName ?? 'this medicine'}" from your library? This cannot be undone.',
          style: const TextStyle(
            fontSize: 13.5,
            color: kTextMuted,
            height: 1.5,
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kTextMuted,
                    side: const BorderSide(color: kDivider),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    final id = medicine.medicineId ?? 0;
                    if (id == 0) return;
                    await ref
                        .read(prescriptionViewModelProvider.notifier)
                        .deleteMedicine(id);
                    final err = ref.read(prescriptionViewModelProvider).error;
                    if (err != null) {
                      _showSnack(err, isError: true);
                      return;
                    }
                    _showSnack('Medicine removed');
                    _refreshMedicines(force: true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: kRedAccent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Remove',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? kRedAccent : kAccentGreen,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  List<Medicine> _filtered(List<Medicine> medicines) {
    return medicines.where((m) {
      final matchType =
          _selectedType == 0 || m.medTypeName == _types[_selectedType];
      final query = _searchController.text.toLowerCase().trim();
      final matchSearch = query.isEmpty ||
          (m.medicineName?.toLowerCase().contains(query) ?? false) ||
          (m.medTypeName?.toLowerCase().contains(query) ?? false);
      return matchType && matchSearch;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    // Fetch handled in initState listener.

    final medicinesAsync = ref.watch(doctorLoginViewModelProvider).medicines;

    return Scaffold(
      backgroundColor: kSurface,
      body: Column(
        children: [
          // ── Top bar ───────────────────────────────────────────
          _TopBar(
            searchController: _searchController,
            selectedType: _selectedType,
            types: _types,
            onSearchChanged: () => setState(() {}),
            onTypeSelected: (i) => setState(() => _selectedType = i),
          ),

          // ── Count row ─────────────────────────────────────────
          if (medicinesAsync != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              child: medicinesAsync.when(
                data: (list) => _CountRow(
                  count: _filtered(list).length,
                  total: list.length,
                ),
                loading: () => const _CountShimmer(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: medicinesAsync == null
                ? const Center(
                    child:
                        CircularProgressIndicator(color: kPrimaryBlue))
                : medicinesAsync.when(
                    loading: () => const Center(
                        child: CircularProgressIndicator(
                            color: kPrimaryBlue)),
                    error: (e, _) =>
                        _ErrorState(onRetry: () => _refreshMedicines(force: true)),
                    data: (medicines) {
                      final filtered = _filtered(medicines);
                      if (filtered.isEmpty) {
                        return _EmptyState(
                          hasFilters: _selectedType != 0 ||
                              _searchController.text.isNotEmpty,
                        );
                      }
                      return RefreshIndicator(
                        color: kPrimaryBlue,
                        onRefresh: () async => _refreshMedicines(force: true),
                        child: ListView.separated(
                          padding:
                              const EdgeInsets.fromLTRB(20, 4, 20, 100),
                          itemCount: filtered.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 12),
                          itemBuilder: (_, i) => _MedicineCard(
                            medicine: filtered[i],
                            onDelete: () => _confirmDelete(filtered[i]),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),

      // ── FAB ───────────────────────────────────────────────────
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _goToAddMedicine,
        backgroundColor: kPrimaryBlue,
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add medicine',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: Colors.white,
            letterSpacing: 0.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Top Bar  (search + filter chips)
// ─────────────────────────────────────────────
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
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Search field
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kDivider),
            ),
            child: TextField(
              controller: searchController,
              onChanged: (_) => onSearchChanged(),
              style: const TextStyle(fontSize: 14, color: kTextDark),
              decoration: InputDecoration(
                hintText: 'Search medicines...',
                hintStyle:
                    const TextStyle(color: kTextMuted, fontSize: 14),
                prefixIcon: const Icon(Icons.search_rounded,
                    color: kTextMuted, size: 20),
                suffixIcon: searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: kTextMuted, size: 18),
                        onPressed: () {
                          searchController.clear();
                          onSearchChanged();
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding:
                    const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 14),

          // Filter chips
          SizedBox(
            height: 36,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = selectedType == i;
                return GestureDetector(
                  onTap: () => onTypeSelected(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel ? kPrimaryBlue : kCardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: sel ? kPrimaryBlue : kDivider,
                      ),
                    ),
                    child: Text(
                      types[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel ? Colors.white : kTextMuted,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 14),
          const Divider(height: 1, color: kDivider),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Count Row
// ─────────────────────────────────────────────
class _CountRow extends StatelessWidget {
  const _CountRow({required this.count, required this.total});
  final int count;
  final int total;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          '$count medicine${count != 1 ? 's' : ''}',
          style: const TextStyle(
            fontSize: 13,
            color: kTextMuted,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: kLightBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$total total',
            style: const TextStyle(
              fontSize: 11.5,
              color: kPrimaryBlue,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}

class _CountShimmer extends StatelessWidget {
  const _CountShimmer();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Text(
        'Loading...',
        style: TextStyle(fontSize: 13, color: kTextMuted),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Type style descriptor
// ─────────────────────────────────────────────
class _TypeStyle {
  const _TypeStyle(
      {required this.bg, required this.fg, required this.icon});
  final Color bg;
  final Color fg;
  final IconData icon;
}

// ─────────────────────────────────────────────
// Medicine Card
// ─────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  const _MedicineCard(
      {required this.medicine, required this.onDelete});

  final Medicine medicine;
  final VoidCallback onDelete;

  static const _typeStyles = {
    'Tablet':    _TypeStyle(bg: Color(0xFFE8F0FE), fg: kPrimaryBlue,        icon: Icons.medication_rounded),
    'Lotion':    _TypeStyle(bg: Color(0xFFF3E8FF), fg: Color(0xFF7C3AED),   icon: Icons.science_outlined),
    'Syrup':     _TypeStyle(bg: Color(0xFFD1FAE5), fg: Color(0xFF059669),   icon: Icons.local_drink_outlined),
    'Injection': _TypeStyle(bg: Color(0xFFFFEDD5), fg: Color(0xFFEA580C),   icon: Icons.colorize_outlined),
    'Drops':     _TypeStyle(bg: Color(0xFFEDE9FE), fg: Color(0xFF6D28D9),   icon: Icons.water_drop_outlined),
    'Spray':     _TypeStyle(bg: Color(0xFFD1FAE5), fg: Color(0xFF0F6E56),   icon: Icons.air_outlined),
  };

  @override
  Widget build(BuildContext context) {
    final style = _typeStyles[medicine.medTypeName] ??
        const _TypeStyle(
            bg: Color(0xFFF1F5F9),
            fg: kTextMuted,
            icon: Icons.medication_outlined);

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: kDivider),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Row(
          children: [
            // Icon container
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(style.icon, color: style.fg, size: 22),
            ),

            const SizedBox(width: 12),

            // Name + badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.medicineName ?? '—',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: kTextDark,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      medicine.medTypeName ?? '—',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: style.fg,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Delete button
            GestureDetector(
              onTap: onDelete,
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kRedAccent.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.delete_outline_rounded,
                    color: kRedAccent, size: 17),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Meta Pill
// ─────────────────────────────────────────────
class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.fg,
    required this.bg,
  });
  final IconData icon;
  final String label;
  final Color fg;
  final Color bg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: fg),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: fg,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Empty State
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({this.hasFilters = false});
  final bool hasFilters;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              color: kLightBlue,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.medication_outlined,
                color: kPrimaryBlue, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            hasFilters ? 'No results found' : 'No medicines yet',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            hasFilters
                ? 'Try a different search or filter.'
                : 'Tap the button below to add medicines.',
            style: const TextStyle(fontSize: 13.5, color: kTextMuted),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Error State
// ─────────────────────────────────────────────
class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: kRedAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.error_outline_rounded,
                color: kRedAccent, size: 32),
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load medicines',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Check your connection and try again.',
            style: TextStyle(fontSize: 13.5, color: kTextMuted),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Retry',
                style: TextStyle(fontWeight: FontWeight.w700)),
            style: ElevatedButton.styleFrom(
              backgroundColor: kPrimaryBlue,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                  horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
