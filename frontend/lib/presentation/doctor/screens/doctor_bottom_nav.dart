import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/utils/name_utils.dart';
import 'package:qless/presentation/doctor/screens/home_screen.dart';
import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/screens/patient_list.dart';
import 'package:qless/presentation/doctor/screens/profile_screen.dart';
import 'package:qless/presentation/shared/controllers/sync_controller.dart';
import 'package:qless/presentation/shared/widgets/connectivity_banner.dart';

/// Programmatic tab-switch request for [DoctorBottomNav].
///
/// Set this to a target tab index from anywhere inside a doctor page
/// (e.g. the home queue card "Resume" action) to jump tabs. The bottom nav
/// listens, switches, then resets it back to null. Patient List is index 1.
final doctorNavTabRequestProvider = StateProvider<int?>((ref) => null);
const int kDoctorPatientListTab = 1;

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

  // NEW — icon badge colors (vivid chip treatment, replaces flat grey icons)
  static const iconChipInactive = Color(0xFFD9F5F1); // light teal chip bg
  static const iconChipActive   = Color(0xFF26C6B0); // solid teal (active)
  static const iconInactiveTint = Color(0xFF0F6E56);  // teal-800, icon color on chip

  // Active chip gradient + glow (adds depth to the flat teal fill)
  static const chipGradientFrom = Color(0xFF4DD9C8);
  static const chipGradientTo   = Color(0xFF1FA88F);
  static const chipGlow         = Color(0x5526C6B0); // 33% teal glow

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

const _navAccent   = DoctorNavTheme.tealDark;
const _navInactive = Color(0xFFA0AEC0);
const _neuNavBg    = Color(0xFFEEF2F7);
const _neuLight    = Color(0xFFFFFFFF);
const _neuDark     = Color(0xFFCDD5DE);

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
    // Honour programmatic tab-switch requests (e.g. home "Resume" → patient list).
    ref.listen<int?>(doctorNavTabRequestProvider, (_, next) {
      if (next == null) return;
      _onTabTap(next);
      // Reset so the same request can fire again later.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(doctorNavTabRequestProvider.notifier).state = null;
      });
    });

    // Boot the sync controller so pending offline ops flush when back online.
    ref.watch(syncControllerProvider);

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
    return ConnectivityBannerWrapper(
      child: Scaffold(
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
      ),
    );
  }

  // ── MOBILE layout: floating pill nav ──────────────────────────────────────

  Widget _buildMobileLayout(bool showAppBar) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: _neuNavBg,
        appBar: null,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(
                child: IndexedStack(
                  index: _currentIndex,
                  children: _pages,
                ),
              ),
              _buildPillNav(),
              const ConnectivityBannerBar(),
            ],
          ),
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
      decoration: const BoxDecoration(
        color: _neuNavBg,
        boxShadow: [
          BoxShadow(color: _neuLight, offset: Offset(-4, 0), blurRadius: 10),
          BoxShadow(color: _neuDark,  offset: Offset(4, 0),  blurRadius: 10),
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
                          color: _neuNavBg,
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: selected
                              ? const [
                                  BoxShadow(color: _neuLight, offset: Offset(-3, -3), blurRadius: 7),
                                  BoxShadow(color: _neuDark,  offset: Offset(3, 3),   blurRadius: 7),
                                ]
                              : null,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 220),
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  gradient: selected
                                      ? const LinearGradient(
                                          colors: [
                                            DoctorNavTheme.chipGradientFrom,
                                            DoctorNavTheme.chipGradientTo,
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        )
                                      : null,
                                  color: selected
                                      ? null
                                      : DoctorNavTheme.iconChipInactive,
                                  borderRadius: BorderRadius.circular(12),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: DoctorNavTheme.chipGlow,
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ]
                                      : null,
                                ),
                                child: Icon(
                                  selected
                                      ? _navItems[i].activeIcon
                                      : _navItems[i].icon,
                                  size: 19,
                                  color: selected
                                      ? Colors.white
                                      : DoctorNavTheme.iconInactiveTint,
                                ),
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
  // EXPANDING PILL BOTTOM BAR — selected tab grows into a teal-tinted pill
  // with icon + label side by side; others stay as plain grey icons.
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPillNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE2E8F0), width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_navItems.length, (i) {
              final selected = _currentIndex == i;
              return GestureDetector(
                onTap: () => _onTabTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? DoctorNavTheme.tealLight : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? _navItems[i].activeIcon : _navItems[i].icon,
                        size: 22,
                        color: selected ? DoctorNavTheme.tealDark : _navInactive,
                      ),
                      AnimatedSize(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        child: selected
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(width: 6),
                                  Text(
                                    _navItems[i].label,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                      color: DoctorNavTheme.tealDark,
                                    ),
                                  ),
                                ],
                              )
                            : const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ),
              );
            }),
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
  return _DoctorCardAppBar(doctorName: doctorName, initial: initial);
}

// ─────────────────────────────────────────────────────────────────────────────
// CARD-STYLE APP BAR
// Floating rounded card with a soft shadow, sitting over the tinted scaffold
// background instead of a flat full-width bar.
// ─────────────────────────────────────────────────────────────────────────────

class _DoctorCardAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _DoctorCardAppBar({required this.doctorName, required this.initial});

  final String doctorName;
  final String initial;

  @override
  Size get preferredSize => const Size.fromHeight(76);

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: Material(
        color: DoctorNavTheme.tealLighter,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: DoctorNavTheme.teal,
                    child: Text(
                      initial,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
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
                          doctorDisplayName(doctorName),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: DoctorNavTheme.textPrimary,
                            height: 1.2,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.notifications_outlined,
                    color: DoctorNavTheme.textSlate,
                    size: 24,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}