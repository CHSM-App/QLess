
// ─── MAIN SHELL (Bottom Nav) ──────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:qless/presentation/patient/screens/appintment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/patient_home_screen.dart';
import 'package:qless/presentation/patient/screens/profile.dart';

class PatientBottomNav extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  const PatientBottomNav(
      {super.key, required this.onToggleTheme, required this.themeMode});
  @override
  State<PatientBottomNav> createState() => _PatientBottomNavState();
}

class _PatientBottomNavState extends State<PatientBottomNav> {
  int _tab = 0;
  final GlobalKey<AppointmentScreenState> _appointmentsKey =
      GlobalKey<AppointmentScreenState>();

  late final List<Widget> _screens;

  void _setTab(int i) {
    if (_tab != i) {
      setState(() => _tab = i);
    }
    if (i == 2) {
      _appointmentsKey.currentState?.refreshOnVisible();
    }
  }

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(
        onToggleTheme: widget.onToggleTheme,
        themeMode: widget.themeMode,
        onTabChange: _setTab,
      ),
      const DoctorSearchScreen(),
      AppointmentScreen(key: _appointmentsKey),
      const PatientProfilePage(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _tab, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: NavigationBar(
          selectedIndex: _tab,
          onDestinationSelected: _setTab,
          backgroundColor: Colors.transparent,
          elevation: 0,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.search_outlined),
              selectedIcon: Icon(Icons.search_rounded),
              label: 'Doctors',
            ),
            NavigationDestination(
              icon: Icon(Icons.calendar_today_outlined),
              selectedIcon: Icon(Icons.calendar_today_rounded),
              label: 'Appointments',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
