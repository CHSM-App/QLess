import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/home_screen.dart';
import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/screens/patient_list.dart';
import 'package:qless/presentation/doctor/screens/profile_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
// THEME CONSTANTS  (single source of truth — change here, applies everywhere)
// ─────────────────────────────────────────────────────────────────────────────

class DoctorNavTheme {
  DoctorNavTheme._();

  

  // Brand palette
  static const teal        = Color(0xFF26C6B0);
  static const tealDark    = Color(0xFF2BB5A0);
  static const tealLight   = Color(0xFFD9F5F1);
  static const tealLighter = Color(0xFFF2FCFA);

  // Gradient stops
  static const gradientFrom = Color(0xFF4DD9C8);
  static const gradientTo   = Color(0xFF2BB5A0);

  // Text
  static const textPrimary = Color(0xFF2D3748);
  static const textSlate   = Color(0xFF718096);

  // Nav states
  static const activePill      = Color(0x1A26C6B0);   // 10% teal tint
  static const inactiveIcon    = Color(0xFFA0AEC0);   // cool light grey
  static const inactiveIconNav = Color(0xFF748598);   // side rail inactive

  // Scaffold
  static const scaffoldBg = Color(0xFFF8FFFE);

  // Breakpoint
  static const wideBreakpoint = 800.0; // px — switch to rail layout
}

// ─────────────────────────────────────────────────────────────────────────────
// NAV ITEM MODEL
// ─────────────────────────────────────────────────────────────────────────────

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

const _navItems = [
  _NavItem(
    icon: Icons.home_outlined,
    activeIcon: Icons.home_rounded,
    label: 'Queue',
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

const _navAccent = Color(0xFF6366F1);
const _navInactive = Color(0xFF1E293B);
const _navActivePill = Color(0x1A6366F1);
const _navPillBg = Color(0x12FFFFFF);
const _navPillBorder = Color(0x26000000);
const _compactNavHeight = 48.0;
const _regularNavHeight = 56.0;

// ─────────────────────────────────────────────────────────────────────────────
// MAIN SHELL WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class DoctorBottomNav extends ConsumerStatefulWidget {
  const DoctorBottomNav({super.key});

  @override
  ConsumerState<DoctorBottomNav> createState() => _DoctorBottomNavState();
}

class _DoctorBottomNavState extends ConsumerState<DoctorBottomNav>
    with TickerProviderStateMixin {
  // ── State ──────────────────────────────────────────────────────────────────
  int _currentIndex = 0;

  // Drag state (pill nav)
  bool   _isDragging     = false;
  double? _dragX;
  int?    _dragHoverIndex;

  // Icon bounce animations
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>>   _iconScales;

  // ── Pages ──────────────────────────────────────────────────────────────────
  late final List<Widget> _pages;

  // ── Lifecycle ──────────────────────────────────────────────────────────────

  @override
  void initState() {
    super.initState();

    _pages = [
      const QueueHomePage(),
      const PatientListScreen(),
      const DoctorMedicinePage(),
      const DoctorSettingsPage(),
    ];

    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );

    _iconScales = _iconControllers.map((c) {
      return Tween<double>(begin: 1.0, end: 1.18).animate(
        CurvedAnimation(parent: c, curve: Curves.elasticOut),
      );
    }).toList();

    // Animate first tab on launch
    _iconControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── Tab switching ──────────────────────────────────────────────────────────

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    _iconControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _iconControllers[index].forward(from: 0);
    HapticFeedback.selectionClick();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isWide =
        MediaQuery.of(context).size.width >= DoctorNavTheme.wideBreakpoint;

    // Profile page hides the shared app bar (manages its own header)
final showAppBar = false;

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onTabTap(0);
      },
      child: isWide
          ? _buildWideLayout(showAppBar)
          : _buildMobileLayout(showAppBar),
    );
  }

  // ── WIDE layout (tablet / desktop): sidebar rail + content ────────────────

  Widget _buildWideLayout(bool showAppBar) {
    return Scaffold(
      backgroundColor: DoctorNavTheme.scaffoldBg,
 appBar: null,
      body: Row(
        children: [
          _buildSideRail(),
          Expanded(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
        ],
      ),
    );
  }

  // ── MOBILE layout: floating pill nav ──────────────────────────────────────

  Widget _buildMobileLayout(bool showAppBar) {
    return Scaffold(
      backgroundColor: const Color(0xFFEEF2FF),
      extendBody: true,
      extendBodyBehindAppBar: true,
appBar: null,
      body: Stack(
        children: [
          Positioned.fill(
            child: IndexedStack(
              index: _currentIndex,
              children: _pages,
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildPillNav(),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SHARED APP BAR
  // One design used on every screen — frosted glass, teal avatar gradient,
  // teal notification bell. Profile page opts out via showAppBar flag.
  // ─────────────────────────────────────────────────────────────────────────

  PreferredSizeWidget _buildAppBar() {
    final doctorName = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'),
    );
    final initial =
        doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return AppBar(
      backgroundColor: Colors.white.withOpacity(0.88),
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,

      // Frosted-glass background
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: const SizedBox.expand(),
        ),
      ),

      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            // ── Avatar (teal gradient) ──
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    DoctorNavTheme.gradientFrom,
                    DoctorNavTheme.gradientTo,
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: DoctorNavTheme.teal.withOpacity(0.28),
                    blurRadius: 10,
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

            // ── Greeting + name ──
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Good morning 👋',
                  style: TextStyle(
                    fontSize: 11,
                    color: DoctorNavTheme.textSlate,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'Dr. $doctorName',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: DoctorNavTheme.textPrimary,
                    height: 1.2,
                  ),
                ),
              ],
            ),

            const Spacer(),

            // ── Notification bell (teal) ──
            _TealNotificationBell(),
          ],
        ),
      ),

      // Hairline divider at the bottom of the app bar
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(
          height: 1,
          color: DoctorNavTheme.tealLight.withOpacity(0.6),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SIDE RAIL  (tablet / desktop — 76 px wide)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSideRail() {
    return Container(
      width: 76,
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          right: BorderSide(color: Color(0xFFE2E8F0)),
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
                padding:
                    const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                child: Tooltip(
                  message: _navItems[i].label,
                  preferBelow: false,
                  child: GestureDetector(
                    onTap: () => _onTabTap(i),
                    behavior: HitTestBehavior.opaque,
                    child: AnimatedBuilder(
                      animation: _iconScales[i],
                      builder: (_, __) => AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: double.infinity,
                        padding:
                            const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: selected
                              ? _navActivePill
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: Icon(
                                selected
                                    ? _navItems[i].activeIcon
                                    : _navItems[i].icon,
                                size: 22,
                                color: selected
                                    ? _navAccent
                                    : _navInactive,
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
                                color: selected
                                    ? _navAccent
                                    : _navInactive,
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

  // ─────────────────────────────────────────────────────────────────────────
  // FLOATING PILL NAV  (mobile — glass morphism, draggable indicator)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPillNav() {
    final isCompact = MediaQuery.of(context).size.width < 360;
    final navHeight = isCompact ? _compactNavHeight : _regularNavHeight;
    final pillHeight = navHeight - 10;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
              child: Container(
                height: navHeight,
                decoration: BoxDecoration(
                  color: _navPillBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _navPillBorder,
                    width: 0.3,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (_, constraints) {
                    final totalWidth  = constraints.maxWidth;
                    final itemCount   = _navItems.length;
                    final itemWidth   = totalWidth / itemCount;
                    final pillWidth   = itemWidth - 10;
                    final curCenter   = (_currentIndex + 0.5) * itemWidth;
                    final minCenter   = itemWidth / 2;
                    final maxCenter   = totalWidth - itemWidth / 2;
                    final dragCenter  =
                        (_dragX ?? curCenter).clamp(minCenter, maxCenter);
                    final pillLeft    =
                        (dragCenter - pillWidth / 2)
                            .clamp(0.0, totalWidth - pillWidth);

                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: (d) => setState(() {
                        _isDragging      = true;
                        _dragX           = d.localPosition.dx;
                        _dragHoverIndex  = _currentIndex;
                      }),
                      onHorizontalDragUpdate: (d) => setState(() {
                        _dragX = d.localPosition.dx
                            .clamp(minCenter, maxCenter);
                        final hover =
                            ((_dragX ?? curCenter) / itemWidth)
                                .floor()
                                .clamp(0, itemCount - 1);
                        if (hover != _dragHoverIndex) {
                          _dragHoverIndex = hover;
                          HapticFeedback.selectionClick();
                        }
                      }),
                      onHorizontalDragEnd: (_) {
                        final target =
                            (_dragX ?? curCenter)
                                .clamp(minCenter, maxCenter);
                        final newIdx =
                            (target / itemWidth)
                                .floor()
                                .clamp(0, itemCount - 1);
                        setState(() {
                          _isDragging     = false;
                          _dragX          = null;
                          _dragHoverIndex = null;
                        });
                        _onTabTap(newIdx);
                      },
                      onHorizontalDragCancel: () => setState(() {
                        _isDragging     = false;
                        _dragX          = null;
                        _dragHoverIndex = null;
                      }),
                      child: Stack(
                        children: [
                          // Sliding active-tab indicator
                          AnimatedPositioned(
                            duration: _isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            left:   pillLeft,
                            top:    5,
                            width:  pillWidth,
                            height: pillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _navActivePill,
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),

                          // Nav items
                          Row(
                            children: List.generate(_navItems.length, (i) {
                              final selected = _currentIndex == i;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _onTabTap(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedBuilder(
                                    animation: _iconScales[i],
                                    builder: (_, __) => Container(
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 3,
                                        vertical: 4,
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
                                              size: isCompact ? 18 : 20,
                                              color: selected
                                                  ? _navAccent
                                                  : _navInactive,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                              milliseconds: 200,
                                            ),
                                            style: TextStyle(
                                              fontSize: isCompact ? 8 : 9,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? _navAccent
                                                  : _navInactive,
                                              letterSpacing: 0.1,
                                            ),
                                            child: Text(
                                              _navItems[i].label,
                                              overflow: TextOverflow.ellipsis,
                                            ),
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

// ─────────────────────────────────────────────────────────────────────────────
// REUSABLE TEAL NOTIFICATION BELL
// Drop this widget into any screen that needs the bell independently.
// ─────────────────────────────────────────────────────────────────────────────

class _TealNotificationBell extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: DoctorNavTheme.teal.withOpacity(0.10),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: DoctorNavTheme.tealLight,
              width: 1,
            ),
          ),
          child: Icon(
            Icons.notifications_outlined,
            color: DoctorNavTheme.teal,
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
              color: Color(0xFFFC8181),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PUBLIC EXPORTS — use these in any screen that needs the shared components
// ─────────────────────────────────────────────────────────────────────────────

/// Reusable teal notification bell — use anywhere a standalone bell is needed.
class DoctorNotificationBell extends _TealNotificationBell {}

PreferredSizeWidget buildDoctorAppBar({
  required String doctorName,
  required String initial,
}) {
  return AppBar(
    backgroundColor: Colors.white.withOpacity(0.88),
    elevation: 0,
    automaticallyImplyLeading: false,
    systemOverlayStyle: SystemUiOverlayStyle.dark,
    titleSpacing: 0,
    flexibleSpace: ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: const SizedBox.expand(),
      ),
    ),
    title: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Teal gradient avatar
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [
                  DoctorNavTheme.gradientFrom,
                  DoctorNavTheme.gradientTo,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: DoctorNavTheme.teal.withOpacity(0.28),
                  blurRadius: 10,
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
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Good morning 👋',
                style: TextStyle(
                  fontSize: 11,
                  color: DoctorNavTheme.textSlate,
                  fontWeight: FontWeight.w400,
                ),
              ),
              Text(
                'Dr. $doctorName',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: DoctorNavTheme.textPrimary,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const Spacer(),
          _TealNotificationBell(),
        ],
      ),
    ),
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(1),
      child: Container(
        height: 1,
        color: DoctorNavTheme.tealLight.withOpacity(0.6),
      ),
    ),
  );
}
