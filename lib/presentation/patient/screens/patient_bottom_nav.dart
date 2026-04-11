import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qless/presentation/patient/screens/appintment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/patient_home_screen.dart';
import 'package:qless/presentation/patient/screens/profile.dart';

class PatientBottomNav extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final int initialTab;

  const PatientBottomNav({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    this.initialTab = 0,
  });

  @override
  State<PatientBottomNav> createState() => _PatientBottomNavState();
}

class _PatientBottomNavState extends State<PatientBottomNav>
    with TickerProviderStateMixin {
  int _tab = 0;

  final GlobalKey<AppointmentScreenState> _appointmentsKey =
      GlobalKey<AppointmentScreenState>();

  late final List<Widget> _screens;
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // ── Palette ────────────────────────────────────────────────────
// ── Palette (update these to match doctor) ─────────────────────
static const _accent      = Color(0xFF6366F1); // match doctor indigo
static const _inactiveClr = Color(0xFF1E293B); // match doctor dark slate
static const _pillBg      = Color(0xC0FFFFFF); // match doctor 75% white
static const _pillBorder  = Color(0xF0FFFFFF); // match doctor near-opaque white
static const _activePill  = Color(0x1A6366F1); // match doctor 10% indigo tint

  static const _navItems = [
    _NavItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _NavItem(
      icon: Icons.search_outlined,
      activeIcon: Icons.search_rounded,
      label: 'Doctors',
    ),
    _NavItem(
      icon: Icons.calendar_today_outlined,
      activeIcon: Icons.calendar_today_rounded,
      label: 'Appointments',
    ),
    _NavItem(
      icon: Icons.person_outline,
      activeIcon: Icons.person_rounded,
      label: 'Profile',
    ),
  ];

  void _setTab(int i) {
    if (_tab == i) return;
    _iconControllers[_tab].reverse();
    setState(() => _tab = i);
    _iconControllers[i].forward(from: 0);
    HapticFeedback.selectionClick();
    if (i == 2) {
      _appointmentsKey.currentState?.refreshOnVisible();
    }
  }

  @override
  void initState() {
    super.initState();

    // clamp initial tab
    _tab = widget.initialTab.clamp(0, 3);

    // animation controllers
    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 380),
      ),
    );
    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.18).animate(
              CurvedAnimation(parent: c, curve: Curves.elasticOut),
            ))
        .toList();
    _iconControllers[_tab].forward();

    // screens
    _screens = [
      HomeScreen(
        onToggleTheme: widget.onToggleTheme,
        themeMode: widget.themeMode,
        onTabChange: _setTab,
      ),
      const DoctorSearchScreen(),
      AppointmentScreen(key: _appointmentsKey, onTabChange: _setTab),
      const PatientProfilePage(),
    ];

    if (_tab == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appointmentsKey.currentState?.refreshOnVisible();
      });
    }
  }

  @override
  void dispose() {
    for (final c in _iconControllers) c.dispose();
    super.dispose();

  }

  @override
Widget build(BuildContext context) {
  return Scaffold(
    extendBody: true,
    extendBodyBehindAppBar: true,
    backgroundColor: const Color(0xFFEEF2FF), // ← real bg, not transparent
    body: IndexedStack(index: _tab, children: _screens),
    bottomNavigationBar: _buildBottomNav(),
  );
}
  // ── Floating Glass Pill ───────────────────────────────────────
  Widget _buildBottomNav() {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              // deep black shadow
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                blurRadius: 32,
                spreadRadius: 0,
                offset: const Offset(0, 10),
              ),
              // indigo colour shadow
              BoxShadow(
                color: const Color(0xFF3730A3).withOpacity(0.14),
                blurRadius: 24,
                spreadRadius: -2,
                offset: const Offset(0, 8),
              ),
              // top white highlight
              BoxShadow(
                color: Colors.white.withOpacity(0.9),
                blurRadius: 0,
                spreadRadius: 0,
                offset: const Offset(0, -1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 28, sigmaY: 28),
              child: Container(
                height: 64,
                decoration: BoxDecoration(
                  color: _pillBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: _pillBorder, width: 1.2),
                ),
                child: Row(
                  children: List.generate(_navItems.length, (i) {
                    final selected = _tab == i;
                    return Expanded(
                      child: GestureDetector(
                        onTap: () => _setTab(i),
                        behavior: HitTestBehavior.opaque,
                        child: AnimatedBuilder(
                          animation: _iconScales[i],
                          builder: (context, _) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            margin: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? _activePill
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(22),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
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
                                  duration: const Duration(milliseconds: 200),
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper ─────────────────────────────────────────────────────

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