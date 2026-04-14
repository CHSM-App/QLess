import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/home_screen.dart';
import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/screens/patient_list.dart';
import 'package:qless/presentation/doctor/screens/profile_screen.dart';

class DoctorBottomNav extends ConsumerStatefulWidget {
  const DoctorBottomNav({super.key});

  @override
  ConsumerState<DoctorBottomNav> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends ConsumerState<DoctorBottomNav>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  bool _isDragging = false;
  double? _dragX;
  int? _dragHoverIndex;

  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // ── Light theme palette ──────────────────────────────────────
  static const _primary = Color(0xFF1E293B);
  static const _slate = Color(0xFF64748B);
  static const _accent = Color(0xFF6366F1); // indigo active
  static const _inactiveClr = Color(0xFF1E293B);
  static const _pillBg = Color(0x00FFFFFF); // fully transparent
  static const _pillBorder = Color(0x00FFFFFF); // fully transparent border
  static const _activePill = Color(0x1A6366F1); // 10% indigo tint

  static const _wideBreakpoint = 600.0;

  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.people_alt_outlined,
      activeIcon: Icons.people_alt_rounded,
      label: 'Patients',
    ),
    _NavItem(
      icon: Icons.medication_outlined,
      activeIcon: Icons.medication_rounded,
      label: 'Medicines',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _iconScales = _iconControllers
        .map(
          (c) => Tween<double>(
            begin: 1.0,
            end: 1.18,
          ).animate(CurvedAnimation(parent: c, curve: Curves.elasticOut)),
        )
        .toList();
    _iconControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) c.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    _iconControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _iconControllers[index].forward(from: 0);
    HapticFeedback.selectionClick();
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= _wideBreakpoint;

    final pages = [
      QueueHomePage(),
      PatientListScreen(),
      DoctorMedicinePage(),
      DoctorSettingsPage(),
    ];

    if (isWide) {
      // ── Tablet / PC: left side rail ──────────────────────────
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _currentIndex == 3 ? null : _buildAppBar(),
        body: Row(
          children: [
            _buildSideRail(),
            Expanded(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
          ],
        ),
      );
    } else {
      // ── Mobile: floating pill nav ─────────────────────────────
      return Scaffold(
        backgroundColor: Colors.transparent,
        extendBody: true, // page draws behind the pill
        extendBodyBehindAppBar: false,
        appBar: _currentIndex == 3 ? null : _buildAppBar(),
        body: Stack(
          children: [
            Positioned.fill(
              child: IndexedStack(index: _currentIndex, children: pages),
            ),
            Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
          ],
        ),
      );
    }
  }

  // ── AppBar ────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final doctorName = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'),
    );
    final initial = doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.85),
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: const SizedBox.expand(),
        ),
      ),
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF6366F1).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Good morning 👋',
                  style: TextStyle(
                    fontSize: 11,
                    color: _slate,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'Dr. $doctorName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _primary,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const Spacer(),
            _NotificationBell(),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: Colors.white.withOpacity(0.6)),
      ),
    );
  }

  // ── Side Rail (tablet / PC) ───────────────────────────────────
  Widget _buildSideRail() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(4, 0),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Column(
            children: List.generate(_navItems.length, (i) {
              final selected = _currentIndex == i;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Tooltip(
                  message: _navItems[i].label,
                  preferBelow: false,
                  child: GestureDetector(
                    onTap: () => _onTabTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedBuilder(
                      animation: _iconScales[i],
                      builder: (context, _) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected ? _activePill : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: Icon(
                                _navItems[i].icon,
                                size: 22,
                                color: selected
                                    ? _accent
                                    : const Color.fromARGB(255, 116, 133, 156),
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedDefaultTextStyle(
                              duration: const Duration(milliseconds: 200),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: selected
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                                color: selected ? _accent : _inactiveClr,
                              ),
                              child: Text(
                                _navItems[i].label,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // ── Floating Light Glass Pill Nav (mobile) ────────────────────
  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.10),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 24,
                offset: const Offset(0, 14), // extra bottom shadow
              ),
              BoxShadow(
                color: Colors.white.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, -2), // subtle top highlight
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: const Color(0x12FFFFFF), // slightly stronger wash
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: const Color(0x66FFFFFF),
                    width: 1.2,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final itemCount = _navItems.length;
                    final itemWidth = totalWidth / itemCount;
                    final pillWidth = itemWidth - 10;
                    final pillHeight = (64 - 16).toDouble();
                    final currentCenter = (_currentIndex + 0.5) * itemWidth;
                    final minCenter = itemWidth / 2;
                    final maxCenter = totalWidth - itemWidth / 2;
                    final dragCenter = (_dragX ?? currentCenter)
                        .clamp(minCenter, maxCenter)
                        .toDouble();
                    final pillLeft = (dragCenter - pillWidth / 2)
                        .clamp(0.0, totalWidth - pillWidth)
                        .toDouble();

                    return GestureDetector(
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                          _dragX = details.localPosition.dx;
                          _dragHoverIndex = _currentIndex;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _dragX = details.localPosition.dx
                              .clamp(minCenter, maxCenter)
                              .toDouble();
                          final hoverIndex =
                              ((_dragX ?? currentCenter) / itemWidth)
                                  .floor()
                                  .clamp(0, itemCount - 1);
                          if (hoverIndex != _dragHoverIndex) {
                            _dragHoverIndex = hoverIndex;
                            HapticFeedback.selectionClick();
                          }
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        final targetCenter = (_dragX ?? currentCenter)
                            .clamp(minCenter, maxCenter)
                            .toDouble();
                        final newIndex = (targetCenter / itemWidth)
                            .floor()
                            .clamp(0, itemCount - 1);
                        setState(() {
                          _isDragging = false;
                          _dragX = null;
                          _dragHoverIndex = null;
                        });
                        _onTabTap(newIndex);
                      },
                      onHorizontalDragCancel: () {
                        setState(() {
                          _isDragging = false;
                          _dragX = null;
                          _dragHoverIndex = null;
                        });
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: _isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            left: pillLeft,
                            top: 8,
                            width: pillWidth,
                            height: pillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _activePill,
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(_navItems.length, (i) {
                              final selected = _currentIndex == i;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _onTabTap(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedBuilder(
                                    animation: _iconScales[i],
                                    builder: (context, _) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 5,
                                        vertical: 8,
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Transform.scale(
                                            scale: _iconScales[i].value,
                                            child: Icon(
                                              selected
                                                  ? _navItems[i].activeIcon
                                                  : _navItems[i].icon,
                                              size: 22,
                                              color: selected
                                                  ? _accent
                                                  : _inactiveClr,
                                            ),
                                          ),
                                          const SizedBox(height: 3),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? _accent
                                                  : _inactiveClr,
                                              letterSpacing: 0.1,
                                            ),
                                            child: Text(_navItems[i].label),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helpers ────────────────────────────────────────────────────

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _NotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF6366F1).withOpacity(0.08),
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF6366F1),
            size: 20,
          ),
        ),
        Positioned(
          top: 8,
          right: 9,
          child: Container(
            width: 7,
            height: 7,
            decoration: const BoxDecoration(
              color: Color(0xFFEF4444),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}
