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

  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // Doctor theme — navy/dark
  static const _primary = Color(0xFF0F172A);
  static const _slate   = Color(0xFF64748B);
  static const _border  = Color(0xFFE2E8F0);

  // Breakpoint: >= 600 → side rail (tablet/PC), < 600 → bottom nav (mobile)
  static const _wideBreakpoint = 600.0;

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded,             label: 'Home'),
    _NavItem(icon: Icons.people_alt_rounded,        label: 'Patients'),
    _NavItem(icon: Icons.medication_rounded,        label: 'Medicines'),
    _NavItem(icon: Icons.person_rounded,            label: 'Profile'),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _navItems.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 350),
      ),
    );
    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.22).animate(
              CurvedAnimation(parent: c, curve: Curves.elasticOut),
            ))
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
      // ── Tablet / PC layout: left side rail ──────────────────────────────
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: _currentIndex == 3 ? null : _buildAppBar(),
        body: Row(
          children: [
            _buildSideRail(),
            Expanded(
              child: IndexedStack(
                index: _currentIndex,
                children: pages,
              ),
            ),
          ],
        ),
      );
    } else {
      // ── Mobile layout: bottom nav ────────────────────────────────────────
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar : _buildAppBar(),
        body: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
        bottomNavigationBar: _buildBottomNav(),
      );
    }
  }

  // ── Shared AppBar ─────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    final doctorName = ref.watch(
      doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'),
    );
    final initial = doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D';

    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 0,
      title: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  initial,
                  style: const TextStyle(
                    fontSize: 17,
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
                    fontSize: 11.5,
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
      bottom: const _AppBarDivider(),
    );
  }

  // ── Left Side Rail (tablet / PC) ──────────────────────────────────────────
  Widget _buildSideRail() {
    return Container(
      width: 76,
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(right: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(4, 0),
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
                          color: selected
                              ? _primary.withOpacity(0.09)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: Icon(
                                _navItems[i].icon,
                                size: 22,
                                color: selected ? _primary : _slate,
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
                                color: selected ? _primary : _slate,
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

  // ── Bottom Navigation (mobile) ─────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _border, width: 1)),
        boxShadow: [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 62,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final selected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _iconScales[i],
                    builder: (context, _) => Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 250),
                              width: selected ? 46 : 0,
                              height: selected ? 30 : 0,
                              decoration: BoxDecoration(
                                color: selected
                                    ? _primary.withOpacity(0.10)
                                    : Colors.blue,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: Icon(
                                _navItems[i].icon,
                                size: 22,
                                color: selected ? Colors.blue : Colors.blueGrey,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: selected
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: selected ? _primary : _slate,
                          ),
                          child: Text(_navItems[i].label),
                        ),
                      ],
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
}

// ─────────────────────────────────────────────
// Internal helpers
// ─────────────────────────────────────────────

class _NavItem {
  const _NavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

class _AppBarDivider extends StatelessWidget implements PreferredSizeWidget {
  const _AppBarDivider();
  @override
  Size get preferredSize => const Size.fromHeight(1);
  @override
  Widget build(BuildContext context) =>
      Container(height: 1, color: const Color(0xFFE2E8F0));
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
            color: const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.notifications_outlined,
            color: Color(0xFF0F172A),
            size: 21,
          ),
        ),
        Positioned(
          top: 9,
          right: 10,
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
