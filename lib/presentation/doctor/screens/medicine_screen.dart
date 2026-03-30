// lib/screens/doctor/tabs/doctor_medicines_tab.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';

class DoctorMedicinePage extends ConsumerStatefulWidget {
  const DoctorMedicinePage({super.key});

  @override
  ConsumerState<DoctorMedicinePage> createState() => _DoctorMedicinesTabState();
}

class _DoctorMedicinesTabState extends ConsumerState<DoctorMedicinePage> {
  final _searchController = TextEditingController();
  int _selectedType = 0;

  static const _types = ['All', 'Tablet','Lotions', 'Syrup', 'Injection', 'Drops', 'Spray'];
  


  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(_refreshMedicines);
  }

  // Single source of truth — always reads doctorId from provider
  void _refreshMedicines() {
    final doctorId =
        ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    ref
        .read(doctorLoginViewModelProvider.notifier)
        .fetchAllMedicines(doctorId);
  }

  void _goToAddMedicine() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicinePage()),
    );

  // Refresh the list if save was successful
  if (result == true) {
    ref
      .read(doctorLoginViewModelProvider.notifier)
      .fetchAllMedicines(ref.read(doctorLoginViewModelProvider).doctorId ?? 0); 
  }
}



  // void _deleteMedicine(int index) {
  //   showDialog(
  //     context: context,
  //     builder: (_) => AlertDialog(
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
  //       title: const Text(
  //         'Remove Medicine',
  //         style: TextStyle(
  //             fontSize: 16,
  //             fontWeight: FontWeight.w700,
  //             color: Color(0xFF0F172A)),
  //       ),
  //       content: Text(
  //         'Remove "${[index].medicineName}" from your library?',
  //         style: const TextStyle(fontSize: 13.5, color: Color(0xFF64748B)),
  //       ),
  //       actions: [
  //         TextButton(
  //           onPressed: () => Navigator.pop(context),
  //           child: const Text('Cancel',
  //               style: TextStyle(color: Color(0xFF64748B))),
  //         ),
  //         TextButton(
  //           onPressed: () {
  //             setState(() => _medicines.removeAt(index));
  //             Navigator.pop(context);
  //           },
  //           child: const Text('Remove',
  //               style: TextStyle(
  //                   color: Color(0xFFEF4444), fontWeight: FontWeight.w700)),
  //         ),
  //       ],
  //     ),
  //   );
  // }


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
    final medicinesAsync =
        ref.watch(doctorLoginViewModelProvider).medicines;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Column(
        children: [
          // ── Search bar ────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                style: const TextStyle(
                    fontSize: 14, color: Color(0xFF0F172A)),
                decoration: const InputDecoration(
                  hintText: 'Search medicines...',
                  hintStyle:
                      TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                  prefixIcon: Icon(Icons.search_rounded,
                      color: Color(0xFF94A3B8), size: 20),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ),

          // ── Type filter chips ─────────────────────────────────
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _types.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final sel = _selectedType == i;
                return GestureDetector(
                  onTap: () => setState(() => _selectedType = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color:
                          sel ? const Color(0xFF0F172A) : Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(
                        color: sel
                            ? const Color(0xFF0F172A)
                            : const Color(0xFFE2E8F0),
                      ),
                    ),
                    child: Text(
                      _types[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500,
                        color: sel
                            ? Colors.white
                            : const Color(0xFF64748B),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          const SizedBox(height: 4),

          // ── Count ─────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: medicinesAsync!.when(
                data: (list) => Text(
                  '${_filtered(list).length} medicines',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                loading: () => const Text(
                  'Loading...',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFF94A3B8),
                  ),
                ),
                error: (_, __) => const Text(
                  'Error loading medicines',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: Color(0xFFEF4444),
                  ),
                ),
              ),
            ),
          ),

          // ── List ──────────────────────────────────────────────
          Expanded(
            child: medicinesAsync!.when(
              loading: () => const Center(
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => const Center(
                child: Text('Failed to load medicines'),
              ),
              data: (medicines) {
                final filtered = _filtered(medicines);

                if (filtered.isEmpty) {
                  return const _EmptyState();
                }

                return ListView.separated(
                  padding:
                      const EdgeInsets.fromLTRB(16, 10, 16, 100),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: 10),
                  itemBuilder: (_, i) => _MedicineCard(
                    medicine: filtered[i],
                    onDelete: () {
                      // TODO: connect delete API
                    },
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
        backgroundColor: const Color(0xFF0F172A),
        elevation: 4,
        icon: const Icon(Icons.add_rounded, color: Colors.white),
        label: const Text(
          'Add Medicine',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Medicine Card
// ─────────────────────────────────────────────
class _MedicineCard extends StatelessWidget {
  const _MedicineCard(
      {required this.medicine, required this.onDelete});

  final Medicine medicine;
  final VoidCallback onDelete;

  static const _typeColors = {
    'Tablet': [Color(0xFFEFF6FF), Color(0xFF3B82F6)],
    'Syrup': [Color(0xFFECFDF5), Color(0xFF10B981)],
    'Injection': [Color(0xFFFFF7ED), Color(0xFFF97316)],
    'Drops': [Color(0xFFF5F3FF), Color(0xFF8B5CF6)],
  };

  @override
  Widget build(BuildContext context) {
    final colors = _typeColors[medicine.medTypeName] ??
        [const Color(0xFFF1F5F9), const Color(0xFF64748B)];

    final strengthLabel =
        medicine.strength != null ? '${medicine.strength} mg' : '—';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x05000000),
              blurRadius: 8,
              offset: Offset(0, 2))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header row ────────────────────────────────────────
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colors[0],
                  borderRadius: BorderRadius.circular(7),
                ),
                child: Text(
                  medicine.medTypeName ?? '—',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: colors[1]),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  medicine.medicineName ?? '—',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A)),
                ),
              ),
              GestureDetector(
                onTap: onDelete,
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.delete_outline_rounded,
                      color: Color(0xFFEF4444), size: 16),
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          // ── Detail row ────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                _MedDetail(
                  icon: Icons.scale_outlined,
                  label: strengthLabel,
                ),
                if (medicine.mobileNo != null &&
                    medicine.mobileNo!.isNotEmpty) ...[
                  const _Dot(),
                  _MedDetail(
                    icon: Icons.phone_outlined,
                    label: medicine.mobileNo!,
                  ),
                ],
                if (medicine.medicineId != null) ...[
                  const _Dot(),
                  _MedDetail(
                    icon: Icons.tag_rounded,
                    label: 'ID ${medicine.medicineId}',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MedDetail extends StatelessWidget {
  const _MedDetail({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: const Color(0xFF94A3B8)),
        const SizedBox(width: 4),
        Text(label,
            style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      height: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: const BoxDecoration(
          color: Color(0xFFCBD5E1), shape: BoxShape.circle),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
                color: Color(0xFFF1F5F9), shape: BoxShape.circle),
            child: const Icon(Icons.medication_outlined,
                color: Color(0xFF94A3B8), size: 30),
          ),
          const SizedBox(height: 14),
          const Text('No medicines yet',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF0F172A))),
          const SizedBox(height: 6),
          const Text('Tap the button below to add medicines.',
              style: TextStyle(fontSize: 13, color: Color(0xFF64748B))),
        ],
      ),
    );
  }
}