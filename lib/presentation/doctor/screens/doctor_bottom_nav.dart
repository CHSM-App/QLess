import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qless/presentation/doctor/screens/home_screen.dart';

import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/screens/patient_list.dart';
import 'package:qless/presentation/doctor/screens/profile_screen.dart';


class DoctorBottomNav extends StatefulWidget {
  final String doctorName;
  final int businessId;

  const DoctorBottomNav({
    super.key,
    this.doctorName = 'Doctor',
    this.businessId = 0,
  });

  @override
  State<DoctorBottomNav> createState() => _DoctorMainScreenState();
}

class _DoctorMainScreenState extends State<DoctorBottomNav>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // Doctor theme — navy/dark
  static const _primary = Color(0xFF0F172A);
  static const _accent  = Color(0xFF3B82F6);
  static const _slate   = Color(0xFF64748B);
  static const _border  = Color(0xFFE2E8F0);

  static const _navItems = [
    _NavItem(icon: Icons.home_rounded,             label: 'Home'),
    _NavItem(icon: Icons.people_alt_rounded,        label: 'Patients'),
    _NavItem(icon: Icons.medication_rounded,        label: 'Medicines'),
    _NavItem(icon: Icons.person_rounded,            label: 'Profile'),
  ];

  static const _titles = ['', 'Patients', 'My Medicines', 'Profile'];

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
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: _buildHomeAppBar(),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          QueueHomePage(),
          DoctorPatientsPage(),
          DoctorMedicinePage(),
          DoctorProfilePage(),
        ],
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Home AppBar ───────────────────────────────────────────────────────────
  PreferredSizeWidget _buildHomeAppBar() {
    final initial = widget.doctorName.isNotEmpty
        ? widget.doctorName[0].toUpperCase()
        : 'D';

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
                  'Dr. ${widget.doctorName}',
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

  // ── Generic AppBar ────────────────────────────────────────────────────────
  PreferredSizeWidget _buildGenericAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      titleSpacing: 20,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _primary,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: _NotificationBell(),
        ),
      ],
      bottom: const _AppBarDivider(),
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────────────
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
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            Transform.scale(
                              scale: _iconScales[i].value,
                              child: Icon(
                                _navItems[i].icon,
                                size: 22,
                                color: selected ? _primary : _slate,
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
