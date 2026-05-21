import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/medicine.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ── Colour Palette (matches QueueHomePage exactly) ───────────────────────────
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);

const kBorder = Color(0xFFEDF2F7);

const kError = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kRedDark = Color(0xFFC53030);

const kSuccess = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kGreenDark = Color(0xFF276749);

const kWarning = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kAmberDark = Color(0xFF975A16);

const kPurple = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kPurpleDark = Color(0xFF6B46C1);

const kInfo = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);
const kInfoDark = Color(0xFF1E40AF);
const kPageBg = Colors.white;
const kCardBg = Color(0xFFF7F8FA);

// ── Premium medical surface tokens (matched to home_screen) ─────────────────
const kHairline = Color(0xFFE8EEF1);
const LinearGradient kPrimaryGradient = LinearGradient(
  colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);
const LinearGradient kCardGlassGradient = LinearGradient(
  colors: [Colors.white, Color(0xFFFBFEFD)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

// ════════════════════════════════════════════════════════════════════
//  MEDICINE TYPE STYLES
// ════════════════════════════════════════════════════════════════════
class _TypeStyle {
  final Color bg, fg;
  final IconData icon;
  const _TypeStyle({required this.bg, required this.fg, required this.icon});
}

const _typeStyles = <String, _TypeStyle>{
  'Tablet': _TypeStyle(
    bg: kPrimaryLight,
    fg: kPrimary,
    icon: Icons.medication_rounded,
  ),
  'Lotions': _TypeStyle(
    bg: kPurpleLight,
    fg: kPurple,
    icon: Icons.science_outlined,
  ),
  'Syrups': _TypeStyle(
    bg: kGreenLight,
    fg: kSuccess,
    icon: Icons.local_drink_outlined,
  ),
  'Injections': _TypeStyle(
    bg: kAmberLight,
    fg: kWarning,
    icon: Icons.colorize_outlined,
  ),
  'Drops': _TypeStyle(
    bg: kInfoLight,
    fg: kInfo,
    icon: Icons.water_drop_outlined,
  ),
  'Sprays': _TypeStyle(bg: kGreenLight, fg: kSuccess, icon: Icons.air_outlined),

  // FIXED Inhalers icon
  'Inhalers': _TypeStyle(
    bg: kAmberLight,
    fg: kWarning,
    icon: Icons.air, // best available alternative
  ),

  // NEW Powders
  'Powders': _TypeStyle(
    bg: kPurpleLight,
    fg: kPurple,
    icon: Icons.grain_outlined, // looks like powder/granules
  ),
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
  final _searchCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  int _selectedType = 0;
  bool _hasFetched = false;
  bool _fabVisible = true;

  static const _types = [
    'All',
    'Tablet',
    'Lotions',
    'Syrups',
    'Injections',
    'Drops',
    'Sprays',
    'Inhalers',
    'Powders',
  ];

  // ── Lifecycle ─────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();
    _scrollCtrl.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(force: false));
  }

  void _onScroll() {
    if (_scrollCtrl.position.userScrollDirection == ScrollDirection.reverse &&
        _fabVisible) {
      setState(() => _fabVisible = false);
    } else if (_scrollCtrl.position.userScrollDirection ==
            ScrollDirection.forward &&
        !_fabVisible) {
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
    ref.read(doctorLoginViewModelProvider.notifier).fetchAllMedicines(doctorId);
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _goToAdd() async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const AddMedicinePage()),
    );
    _refresh(force: true);
  }

  // ── Filter ────────────────────────────────────────────────────────────────

  List<Medicine> _filtered(List<Medicine> list) {
    final q = _searchCtrl.text.toLowerCase().trim();
    return list.where((m) {
      final typeMatch =
          _selectedType == 0 || m.medTypeName == _types[_selectedType];
      final searchMatch =
          q.isEmpty ||
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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
                  color: kRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: kError,
                ),
              ),
              const SizedBox(height: 12),

              // Title
              const Text(
                'Remove Medicine?',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle
              Text(
                'Remove "${medicine.medicineName ?? 'this medicine'}" permanently?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        foregroundColor: kTextSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Remove',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
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
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 15,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(doctorLoginViewModelProvider);
    final medicinesAsync = state.medicines ?? const AsyncValue.loading();

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(
        children: [
          // ── Header (matches QueueHomePage header style exactly) ──────────
          _buildHeader(),

          // ── Count row ───────────────────────────────────────────────────
          medicinesAsync.when(
            data: (list) =>
                _CountRow(count: _filtered(list).length, total: list.length),
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
                    hasFilters:
                        _selectedType != 0 || _searchCtrl.text.isNotEmpty,
                  );
                }
                return LayoutBuilder(
                  builder: (_, constraints) {
                    final isWide = constraints.maxWidth > 700;
                    return RefreshIndicator(
                      color: kPrimary,
                      strokeWidth: 2.5,
                      displacement: 40,
                      onRefresh: () async {
                        _refresh(force: true);
                        // wait a bit so indicator is visible
                        await Future.delayed(const Duration(milliseconds: 600));
                      },
                      child: isWide
                          ? _buildGrid(filtered)
                          : _buildList(filtered, _scrollCtrl),
                    );
                  },
                );
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
            child: GestureDetector(
              onTap: _fabVisible ? _goToAdd : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 11),
                decoration: BoxDecoration(
                  gradient: kPrimaryGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(Icons.add_rounded,
                        color: Colors.white, size: 18),
                    SizedBox(width: 6),
                    Text(
                      'Add Medicine',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
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
        border: Border(bottom: BorderSide(color: Color(0xFFEDF2F7), width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppExpandableHeaderSearch(
                controller: _searchCtrl,
                leadingIcon: Icons.medication_rounded,
                title: 'Medicines',
                subtitle: 'Manage your medicines list',
                hintText: 'Search medicines...',
                accentColor: kPrimary,
                leadingBackgroundColor: kPrimaryLight,
                titleColor: kTextPrimary,
                subtitleColor: kTextMuted,
                fieldColor: const Color(0xFFF7F8FA),
                borderColor: kBorder,
                iconColor: kTextMuted,
                textColor: kTextPrimary,
                onChanged: (_) => setState(() {}),
              ),

              const SizedBox(height: 6),

              // ── Filter chips ────────────────────────────────────────────
              SizedBox(
                height: 28,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _types.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 5),
                  itemBuilder: (_, i) {
                    final sel = _selectedType == i;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedType = i),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 11,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: sel ? kPrimaryGradient : null,
                          color: sel ? null : Colors.white,
                          border: Border.all(
                            color: sel
                                ? kPrimary.withOpacity(0.0)
                                : kHairline,
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _types[i],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: sel ? Colors.white : kTextSecondary,
                            letterSpacing: 0.1,
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
        padding: const EdgeInsets.fromLTRB(12, 6, 12, 140),
        itemCount: medicines.length,
        separatorBuilder: (_, __) => const SizedBox(height: 6),
        itemBuilder: (_, i) => _MedicineCard(
          medicine: medicines[i],
          onDelete: () => _confirmDelete(medicines[i]),
        ),
      );

  // ── Grid (tablet / desktop) ───────────────────────────────────────────────
  Widget _buildGrid(List<Medicine> medicines) => GridView.builder(
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 120),
    gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
      maxCrossAxisExtent: 320,
      childAspectRatio: 3.6,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
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
    final style = _typeStyles[medicine.medTypeName] ?? _defaultStyle;

    return Container(
      decoration: BoxDecoration(
        gradient: kCardGlassGradient,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kHairline),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Row(
        children: [
          // ── Icon badge with gradient tint ─────────────────────────
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [style.bg, Colors.white],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: style.fg.withOpacity(0.18)),
            ),
            alignment: Alignment.center,
            child: Icon(style.icon, color: style.fg, size: 17),
          ),
          const SizedBox(width: 9),

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
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                    letterSpacing: -0.1,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: style.bg,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: style.fg.withOpacity(0.18)),
                  ),
                  child: Text(
                    medicine.medTypeName ?? '—',
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      color: style.fg,
                      letterSpacing: 0.2,
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
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kError.withOpacity(0.15)),
              ),
              child: const Icon(
                Icons.delete_outline_rounded,
                color: kError,
                size: 15,
              ),
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
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        Text(
          '$count medicine${count != 1 ? 's' : ''}',
          style: const TextStyle(
            fontSize: 10.5,
            color: kTextSecondary,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: kPrimaryLight,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: kPrimary.withOpacity(0.18)),
          ),
          child: Text(
            '$total total',
            style: const TextStyle(
              fontSize: 9.5,
              color: kPrimaryDark,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.2,
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
            color: kPrimaryLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.medication_outlined,
            size: 28,
            color: kPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          hasFilters ? 'No matching medicines' : 'No medicines added yet',
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
          style: const TextStyle(fontSize: 12, color: kTextMuted),
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
  const _Shimmer({required this.width, required this.height, this.radius = 6});

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
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.4,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
    padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
    child: Row(
      children: [
        const _Shimmer(width: 80, height: 11, radius: 6),
        const Spacer(),
        const _Shimmer(width: 50, height: 20, radius: 20),
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
      gradient: kCardGlassGradient,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kHairline),
    ),
    padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
    child: Row(
      children: [
        const _Shimmer(width: 36, height: 36, radius: 10),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              _Shimmer(width: 130, height: 12),
              SizedBox(height: 6),
              _Shimmer(width: 56, height: 16, radius: 6),
            ],
          ),
        ),
        const _Shimmer(width: 29, height: 29, radius: 9),
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
    padding: const EdgeInsets.fromLTRB(12, 6, 12, 140),
    itemCount: 7,
    separatorBuilder: (_, __) => const SizedBox(height: 6),
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
            color: kRedLight,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded, size: 26, color: kError),
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
              padding: const EdgeInsets.symmetric(horizontal: 24),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    ),
  );
}
