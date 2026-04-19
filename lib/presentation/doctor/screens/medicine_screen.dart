import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';

// ── Colour Palette (matches QueueHomePage exactly) ───────────────────────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF2BB5A0);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryLighter= Color(0xFFF2FCFA);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder        = Color(0xFFEDF2F7);

const kError         = Color(0xFFFC8181);
const kRedLight      = Color(0xFFFEE2E2);
const kRedDark       = Color(0xFFC53030);

const kSuccess       = Color(0xFF68D391);
const kGreenLight    = Color(0xFFDCFCE7);
const kGreenDark     = Color(0xFF276749);

const kWarning       = Color(0xFFF6AD55);
const kAmberLight    = Color(0xFFFEF3C7);
const kAmberDark     = Color(0xFF975A16);

const kPurple        = Color(0xFF9F7AEA);
const kPurpleLight   = Color(0xFFEDE9FE);
const kPurpleDark    = Color(0xFF6B46C1);

const kInfo          = Color(0xFF3B82F6);
const kInfoLight     = Color(0xFFDBEAFE);
const kInfoDark      = Color(0xFF1E40AF);

// ════════════════════════════════════════════════════════════════════
//  MEDICINE TYPE STYLES
// ════════════════════════════════════════════════════════════════════
class _TypeStyle {
  final Color bg, fg;
  final IconData icon;
  const _TypeStyle({required this.bg, required this.fg, required this.icon});
}

const _typeStyles = <String, _TypeStyle>{
  'Tablet':    _TypeStyle(bg: kPrimaryLight, fg: kPrimary,   icon: Icons.medication_rounded),
  'Lotion':    _TypeStyle(bg: kPurpleLight,  fg: kPurple,    icon: Icons.science_outlined),
  'Syrup':     _TypeStyle(bg: kGreenLight,   fg: kSuccess,   icon: Icons.local_drink_outlined),
  'Injection': _TypeStyle(bg: kAmberLight,   fg: kWarning,   icon: Icons.colorize_outlined),
  'Drops':     _TypeStyle(bg: kInfoLight,    fg: kInfo,      icon: Icons.water_drop_outlined),
  'Spray':     _TypeStyle(bg: kGreenLight,   fg: kSuccess,   icon: Icons.air_outlined),
};

const _defaultStyle = _TypeStyle(
  bg: Color(0xFFF7F8FA),
  fg: kTextMuted,
  icon: Icons.medication_outlined,
);

// ════════════════════════════════════════════════════════════════════
//  DOCTOR MEDICINE PAGE
// ════════════════════════════════════════════════════════════════════
class DoctorMedicinePage extends ConsumerStatefulWidget {
  const DoctorMedicinePage({super.key});

  @override
  ConsumerState<DoctorMedicinePage> createState() => _DoctorMedicinePageState();
}

class _DoctorMedicinePageState extends ConsumerState<DoctorMedicinePage> {
  final _searchCtrl  = TextEditingController();
  final _scrollCtrl  = ScrollController();
  int  _selectedType = 0;
  bool _hasFetched   = false;
  bool _fabVisible   = true;

  static const _types = [
    'All', 'Tablet', 'Lotion', 'Syrup', 'Injection', 'Drops', 'Spray',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _refresh(force: false),
    );
  }

  void _onScroll() {
    if (_scrollCtrl.position.userScrollDirection ==
        ScrollDirection.reverse && _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (_scrollCtrl.position.userScrollDirection ==
        ScrollDirection.forward && !_fabVisible) {
      setState(() => _fabVisible = true);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Data ──────────────────────────────────────────────────────────────────

  void _refresh({required bool force}) {
    if (_hasFetched && !force) return;
    final doctorId = ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
    if (doctorId == 0) return;
    _hasFetched = true;
    ref
        .read(doctorLoginViewModelProvider.notifier)
        .fetchAllMedicines(doctorId);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _goToAdd() async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicinePage()),
    );
    if (result == true) _refresh(force: true);
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  List<Medicine> _filtered(List<Medicine> list) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return list.where((m) {
      final typeMatch =
          _selectedType == 0 || m.medTypeName == _types[_selectedType];
      final searchMatch = q.isEmpty ||
          (m.medicineName?.toLowerCase().contains(q) ?? false) ||
          (m.medTypeName?.toLowerCase().contains(q) ?? false);
      return typeMatch && searchMatch;
    }).toList();
  }

  // ── Delete ────────────────────────────────────────────────────────────────

  void _confirmDelete(Medicine medicine) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                    color: kRedLight, shape: BoxShape.circle),
                child: const Icon(Icons.delete_outline_rounded,
                    size: 22, color: kError),
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                'Remove Medicine?',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Remove "${medicine.medicineName ?? 'this medicine'}" permanently?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: kBorder),
                      foregroundColor: kTextSecondary,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await ref
                          .read(prescriptionViewModelProvider.notifier)
                          .deleteMedicine(medicine.medicineId ?? 0);
                      _refresh(force: true);
                      _snack('Medicine removed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kError,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                    ),
                    child: const Text('Remove',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(
            isError
                ? Icons.error_outline_rounded
                : Icons.check_circle_outline_rounded,
            color: Colors.white,
            size: 15,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(msg,
                style:
                    const TextStyle(fontSize: 13, color: Colors.white)),
          ),
        ]),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state          = ref.watch(doctorLoginViewModelProvider);
    final medicinesAsync = state.medicines ?? const AsyncValue.loading();

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      body: Column(
        children: [
          // ── Header (matches QueueHomePage header style exactly) ──────────
          _buildHeader(),

          // ── Count row ───────────────────────────────────────────────────
          medicinesAsync.when(
            data: (list) => _CountRow(
                count: _filtered(list).length, total: list.length),
            loading: () => const _SkeletonCountRow(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // ── Main content ────────────────────────────────────────────────
          Expanded(
            child: medicinesAsync.when(
              loading: () => const _SkeletonList(),
              error: (_, __) =>
                  _ErrorState(onRetry: () => _refresh(force: true)),
              data: (medicines) {
                final filtered = _filtered(medicines);
                if (filtered.isEmpty) {
                  return _EmptyState(
                    hasFilters: _selectedType != 0 ||
                        _searchCtrl.text.isNotEmpty,
                  );
                }
                return LayoutBuilder(builder: (_, constraints) {
                  final isWide = constraints.maxWidth > 700;
                  return RefreshIndicator(
                    color: kPrimary,
                    strokeWidth: 2.5,
                    displacement: 40,
                    onRefresh: () async {
                      _refresh(force: true);
                      // wait a bit so indicator is visible
                      await Future.delayed(
                          const Duration(milliseconds: 600));
                    },
                    child: isWide
                        ? _buildGrid(filtered)
                        : _buildList(filtered, _scrollCtrl),
                  );
                });
              },
            ),
          ),
        ],
      ),

      // ── FAB ─────────────────────────────────────────────────────────────
      floatingActionButton: AnimatedSlide(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        offset: _fabVisible ? Offset.zero : const Offset(0, 0.6),
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 300),
          opacity: _fabVisible ? 1.0 : 0.0,
          child: Padding(
            padding: const EdgeInsets.only(bottom: 80),
            child: FloatingActionButton.extended(
              onPressed: _fabVisible ? _goToAdd : null,
              backgroundColor: kPrimary,
              elevation: 3,
              icon: const Icon(Icons.add_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Add Medicine',
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Header — matches QueueHomePage _buildHeader style exactly ─────────────
  Widget _buildHeader() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
            bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // ── Title row ───────────────────────────────────────────────
              Row(
                children: [
                  // Icon badge — same size/radius as home page
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: kPrimary.withOpacity(0.2)),
                    ),
                    child: const Icon(Icons.medication_rounded,
                        color: kPrimary, size: 17),
                  ),
                  const SizedBox(width: 8),

                  // Title + subtitle — same font sizes as home page
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Medicines',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Manage your medicines list',
                          style: TextStyle(
                            fontSize: 11,
                            color: kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),

              // ── Search bar ──────────────────────────────────────────────
              Container(
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: Row(
                  children: [
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 11),
                      child: Icon(Icons.search_rounded,
                          size: 17, color: kTextMuted),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _searchCtrl,
                        onChanged: (_) => setState(() {}),
                        style: const TextStyle(
                            fontSize: 13, color: kTextPrimary),
                        decoration: const InputDecoration(
                          hintText: 'Search medicines…',
                          hintStyle: TextStyle(
                              fontSize: 13, color: kTextMuted),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                    if (_searchCtrl.text.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchCtrl.clear();
                          setState(() {});
                        },
                        child: Container(
                          margin: const EdgeInsets.only(right: 10),
                          width: 18,
                          height: 18,
                          decoration: const BoxDecoration(
                              color: kTextMuted,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.close_rounded,
                              size: 11, color: Colors.white),
                        ),
                      ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Filter chips ────────────────────────────────────────────
              SizedBox(
                height: 32,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: 6),
                  itemBuilder: (_, i) {
                    final sel = _selectedType == i;
                    return GestureDetector(
                      onTap: () =>
                          setState(() => _selectedType = i),
                      child: AnimatedContainer(
                        duration:
                            const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: sel
                              ? kPrimary
                              : Colors.white,
                          border: Border.all(
                              color: sel
                                  ? kPrimary
                                  : kBorder),
                          borderRadius:
                              BorderRadius.circular(20),
                        ),
                        child: Text(
                          _types[i],
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: sel
                                ? FontWeight.w700
                                : FontWeight.w500,
                            color: sel
                                ? Colors.white
                                : kTextSecondary,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── List (mobile) ─────────────────────────────────────────────────────────
  Widget _buildList(List<Medicine> medicines, [ScrollController? controller]) =>
      ListView.separated(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 140),
        itemCount: medicines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) => _MedicineCard(
          medicine: medicines[i],
          onDelete: () => _confirmDelete(medicines[i]),
        ),
      );

  // ── Grid (tablet / desktop) ───────────────────────────────────────────────
  Widget _buildGrid(List<Medicine> medicines) => GridView.builder(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 120),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 340,
          childAspectRatio: 3.4,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: medicines.length,
        itemBuilder: (_, i) => _MedicineCard(
          medicine: medicines[i],
          onDelete: () => _confirmDelete(medicines[i]),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  MEDICINE CARD
// ════════════════════════════════════════════════════════════════════
class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final VoidCallback onDelete;
  const _MedicineCard({required this.medicine, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final style =
        _typeStyles[medicine.medTypeName] ?? _defaultStyle;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // ── Icon badge ────────────────────────────────────────────
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: style.bg,
                borderRadius: BorderRadius.circular(10)),
            child: Icon(style.icon, color: style.fg, size: 19),
          ),
          const SizedBox(width: 10),

          // ── Name + type badge ─────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  medicine.medicineName ?? '—',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                      color: style.bg,
                      borderRadius: BorderRadius.circular(6)),
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

          // ── Delete button ─────────────────────────────────────────
          GestureDetector(
            onTap: onDelete,
            child: Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                  color: kRedLight,
                  borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.delete_outline_rounded,
                  color: kError, size: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  COUNT ROW
// ════════════════════════════════════════════════════════════════════
class _CountRow extends StatelessWidget {
  final int count, total;
  const _CountRow({required this.count, required this.total});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(
          children: [
            Text(
              '$count medicine${count != 1 ? 's' : ''}',
              style: const TextStyle(
                  fontSize: 12, color: kTextMuted),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 9, vertical: 3),
              decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                '$total total',
                style: const TextStyle(
                  fontSize: 11,
                  color: kPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY STATE
// ════════════════════════════════════════════════════════════════════
class _EmptyState extends StatelessWidget {
  final bool hasFilters;
  const _EmptyState({this.hasFilters = false});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.medication_outlined,
                  size: 28, color: kPrimary),
            ),
            const SizedBox(height: 12),
            Text(
              hasFilters
                  ? 'No matching medicines'
                  : 'No medicines added yet',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hasFilters
                  ? 'Try a different filter or search'
                  : 'Tap + to add a new medicine',
              style: const TextStyle(
                  fontSize: 12, color: kTextMuted),
            ),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  ERROR STATE
// ════════════════════════════════════════════════════════════════════
// ════════════════════════════════════════════════════════════════════
//  SHIMMER HELPERS
// ════════════════════════════════════════════════════════════════════
class _Shimmer extends StatefulWidget {
  final double width, height, radius;
  const _Shimmer(
      {required this.width, required this.height, this.radius = 6});

  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1100))
      ..repeat(reverse: true);
    _anim = Tween<double>(begin: 0.4, end: 1.0).animate(
        CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: _anim,
        child: Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            color: const Color(0xFFE2E8F0),
            borderRadius: BorderRadius.circular(widget.radius),
          ),
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON COUNT ROW
// ════════════════════════════════════════════════════════════════════
class _SkeletonCountRow extends StatelessWidget {
  const _SkeletonCountRow();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
        child: Row(
          children: [
            const _Shimmer(width: 90, height: 12, radius: 6),
            const Spacer(),
            const _Shimmer(width: 56, height: 22, radius: 20),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON MEDICINE CARD
// ════════════════════════════════════════════════════════════════════
class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            const _Shimmer(width: 40, height: 40, radius: 10),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _Shimmer(width: 130, height: 13),
                  SizedBox(height: 6),
                  _Shimmer(width: 60, height: 20, radius: 6),
                ],
              ),
            ),
            const _Shimmer(width: 30, height: 30, radius: 9),
          ],
        ),
      );
}

// ════════════════════════════════════════════════════════════════════
//  SKELETON LIST
// ════════════════════════════════════════════════════════════════════
class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) => ListView.separated(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 140),
        itemCount: 7,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, __) => const _SkeletonCard(),
      );
}

// ════════════════════════════════════════════════════════════════════
//  ERROR STATE
// ════════════════════════════════════════════════════════════════════
class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;
  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                  color: kRedLight, shape: BoxShape.circle),
              child: const Icon(Icons.wifi_off_rounded,
                  size: 26, color: kError),
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Please check your connection',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 38,
              child: ElevatedButton(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text(
                  'Retry',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        ),
      );
}