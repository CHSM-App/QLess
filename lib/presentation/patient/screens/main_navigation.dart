// lib/presentation/patient/screens/main_navigation.dart
//
// Drop-in navigation shell for the Patient side.
// Includes:
//   • Custom AppBar  (greeting + notification bell + avatar)
//   • 4-tab BottomNavigationBar  (Home | Appointments | Records | Profile)
//   • Placeholder screens for each tab  (replace bodies as you build them)
//
// Usage — navigate here after OTP verification:
//   Navigator.pushReplacement(context,
//     MaterialPageRoute(builder: (_) => const PatientMainScreen()));

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Entry point
// ─────────────────────────────────────────────────────────────────────────────
class PatientMainScreen extends StatefulWidget {
  const PatientMainScreen({super.key});

  @override
  State<PatientMainScreen> createState() => _PatientMainScreenState();
}

class _PatientMainScreenState extends State<PatientMainScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;

  // One AnimationController per tab for the icon pop effect
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  static const _primary   = Color(0xFF0EA5E9);
  static const _dark      = Color(0xFF0F172A);
  static const _slate     = Color(0xFF64748B);

  final _tabs = const [
    _TabItem(icon: Icons.home_rounded,            label: 'Home'),
    _TabItem(icon: Icons.calendar_month_rounded,  label: 'Appointments'),
    _TabItem(icon: Icons.folder_copy_rounded,     label: 'Records'),
    _TabItem(icon: Icons.person_rounded,          label: 'Profile'),
  ];

  final _screens = const [
    _HomeTab(),
    _AppointmentsTab(),
    _RecordsTab(),
    _ProfileTab(),
  ];

  @override
  void initState() {
    super.initState();
    _iconControllers = List.generate(
      _tabs.length,
      (_) => AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 300),
      ),
    );
    _iconScales = _iconControllers
        .map((c) => Tween<double>(begin: 1.0, end: 1.25).animate(
              CurvedAnimation(parent: c, curve: Curves.elasticOut),
            ))
        .toList();

    // Animate the first tab on load
    _iconControllers[0].forward();
  }

  @override
  void dispose() {
    for (final c in _iconControllers) {
      c.dispose();
    }
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _currentIndex) return;
    _iconControllers[_currentIndex].reverse();
    setState(() => _currentIndex = index);
    _iconControllers[index].forward(from: 0);
    HapticFeedback.selectionClick();
  }

  // ── AppBar titles per tab ────────────────────────────────────────────────
  static const _titles = ['Home', 'Appointments', 'Records', 'Profile'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      extendBody: true, // content goes behind the floating nav bar

      // ── APP BAR ──────────────────────────────────────────────────────────
      appBar: _currentIndex == 0
          ? _buildHomeAppBar()
          : _buildGenericAppBar(_titles[_currentIndex]),

      // ── BODY ─────────────────────────────────────────────────────────────
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        switchInCurve: Curves.easeOut,
        switchOutCurve: Curves.easeIn,
        transitionBuilder: (child, anim) => FadeTransition(
          opacity: anim,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.03),
              end: Offset.zero,
            ).animate(anim),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(_currentIndex),
          child: _screens[_currentIndex],
        ),
      ),

      // ── BOTTOM NAV ────────────────────────────────────────────────────────
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Home app bar (greeting style) ────────────────────────────────────────
  PreferredSizeWidget _buildHomeAppBar() {
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
            // Avatar
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: Text(
                  'A',   // ← replace with patient name initial
                  style: TextStyle(
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
              children: const [
                Text(
                  'Good morning 👋',
                  style: TextStyle(
                    fontSize: 12,
                    color: _slate,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                Text(
                  'Raj M',    // ← replace with patient name from state
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _dark,
                    height: 1.2,
                  ),
                ),
              ],
            ),
            const Spacer(),
            // Notification bell
            Stack(
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
                    color: _dark,
                    size: 22,
                  ),
                ),
                Positioned(
                  top: 8,
                  right: 9,
                  child: Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Color(0xFFEF4444),
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Generic app bar for other tabs ───────────────────────────────────────
  PreferredSizeWidget _buildGenericAppBar(String title) {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
      centerTitle: false,
      titleSpacing: 20,
      title: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: _dark,
          letterSpacing: -0.4,
        ),
      ),
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Stack(
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
                  color: _dark,
                  size: 22,
                ),
              ),
              Positioned(
                top: 8,
                right: 9,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: Color(0xFFEF4444),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 1, color: const Color(0xFFE2E8F0)),
      ),
    );
  }

  // ── Bottom navigation bar ─────────────────────────────────────────────────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: Color(0xFFE2E8F0), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 64,
          child: Row(
            children: List.generate(_tabs.length, (i) {
              final selected = _currentIndex == i;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _onTabTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: AnimatedBuilder(
                    animation: _iconScales[i],
                    builder: (context, _) {
                      return Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Icon with animated indicator dot
                          Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              AnimatedContainer(
                                duration: const Duration(milliseconds: 250),
                                width: selected ? 44 : 0,
                                height: selected ? 32 : 0,
                                decoration: BoxDecoration(
                                  color: selected
                                      ? _primary.withOpacity(0.12)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              Transform.scale(
                                scale: _iconScales[i].value,
                                child: Icon(
                                  _tabs[i].icon,
                                  size: 22,
                                  color: selected ? _primary : _slate,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: selected
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: selected ? _primary : _slate,
                            ),
                            child: Text(_tabs[i].label),
                          ),
                        ],
                      );
                    },
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
// Tab item model
// ─────────────────────────────────────────────────────────────────────────────
class _TabItem {
  const _TabItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder tab screens  (replace with your actual screen widgets)
// ─────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  static const _primary = Color(0xFF0EA5E9);
  static const _dark    = Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── Health summary card ─────────────────────────────
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0369A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _primary.withOpacity(0.30),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Health Summary',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'All vitals normal',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    _VitalChip(label: 'Blood Group', value: 'A+'),
                    const SizedBox(width: 10),
                    _VitalChip(label: 'Weight', value: '57 kg'),
                    const SizedBox(width: 10),
                    _VitalChip(label: 'Age', value: '22 yrs'),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 24),

          // ── Quick actions ────────────────────────────────────
          const Text(
            'Quick Actions',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: _dark,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _QuickAction(
                icon: Icons.add_circle_outline_rounded,
                label: 'Book\nAppointment',
                color: const Color(0xFF6366F1),
                onTap: () {},
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.history_rounded,
                label: 'View\nHistory',
                color: const Color(0xFF10B981),
                onTap: () {},
              ),
              const SizedBox(width: 12),
              _QuickAction(
                icon: Icons.medication_outlined,
                label: 'My\nMedicines',
                color: const Color(0xFFF59E0B),
                onTap: () {},
              ),
              // const SizedBox(width: 12),
              // _QuickAction(
              //   icon: Icons.emergency_outlined,
              //   label: 'Emergency',
              //   color: const Color(0xFFEF4444),
              //   onTap: () {},
              // ),
            ],
          ),

          const SizedBox(height: 24),

          // ── Upcoming appointment ─────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Upcoming Appointment',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                  letterSpacing: -0.2,
                ),
              ),
              Text(
                'See all',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: _primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _AppointmentCard(
            doctorName: 'Dr. Priya Sharma',
            specialty: 'Cardiologist',
            date: 'Mon, 28 Mar 2026',
            time: '10:30 AM',
            avatarColor: const Color(0xFF8B5CF6),
            initial: 'P',
          ),

          const SizedBox(height: 12),
          _AppointmentCard(
            doctorName: 'Dr. Rahul Mehta',
            specialty: 'Dermatologist',
            date: 'Wed, 30 Mar 2026',
            time: '2:00 PM',
            avatarColor: const Color(0xFF10B981),
            initial: 'R',
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
class _AppointmentsTab extends StatelessWidget {
  const _AppointmentsTab();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.calendar_month_rounded,
      title: 'Appointments',
      subtitle: 'Your upcoming and past appointments\nwill appear here.',
      color: Color(0xFF6366F1),
    );
  }
}

class _RecordsTab extends StatelessWidget {
  const _RecordsTab();

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.folder_copy_rounded,
      title: 'Medical Records',
      subtitle: 'Prescriptions, lab reports and\ndocuments will appear here.',
      color: Color(0xFF10B981),
    );
  }
}

class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  static const _dark  = Color(0xFF0F172A);
  static const _slate = Color(0xFF64748B);

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
      child: Column(
        children: [
          // Avatar
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0EA5E9), Color(0xFF0284C7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'A',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            'Aniket M',  // ← replace with state
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _dark,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Patient',
            style: TextStyle(fontSize: 13, color: _slate),
          ),
          const SizedBox(height: 28),

          // Profile menu items
          _ProfileMenuItem(
            icon: Icons.person_outline_rounded,
            label: 'Personal Information',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.health_and_safety_outlined,
            label: 'Medical Details',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.notifications_outlined,
            label: 'Notifications',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.lock_outline_rounded,
            label: 'Change Password',
            onTap: () {},
          ),
          _ProfileMenuItem(
            icon: Icons.help_outline_rounded,
            label: 'Help & Support',
            onTap: () {},
          ),
          const SizedBox(height: 8),
          _ProfileMenuItem(
            icon: Icons.logout_rounded,
            label: 'Logout',
            color: const Color(0xFFEF4444),
            onTap: () {
              // Navigator.pushAndRemoveUntil(context,
              //   MaterialPageRoute(builder: (_) => const LoginScreen()),
              //   (_) => false);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Generic placeholder for tabs not yet built
// ─────────────────────────────────────────────
class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: color.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 34),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13.5,
                color: Color(0xFF64748B),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Small reusable home tab widgets
// ─────────────────────────────────────────────

class _VitalChip extends StatelessWidget {
  const _VitalChip({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white)),
          const SizedBox(height: 1),
          Text(label,
              style: const TextStyle(fontSize: 10, color: Colors.white70)),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x06000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0F172A),
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.avatarColor,
    required this.initial,
  });

  final String doctorName;
  final String specialty;
  final String date;
  final String time;
  final Color avatarColor;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: avatarColor,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(initial,
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(doctorName,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0F172A))),
                const SizedBox(height: 2),
                Text(specialty,
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF64748B))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(time,
                    style: const TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF0EA5E9))),
              ),
              const SizedBox(height: 4),
              Text(date,
                  style: const TextStyle(
                      fontSize: 10.5, color: Color(0xFF94A3B8))),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? const Color(0xFF0F172A);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
        leading: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: c.withOpacity(0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: c, size: 18),
        ),
        title: Text(label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: c,
            )),
        trailing: color == null
            ? const Icon(Icons.chevron_right_rounded,
                color: Color(0xFFCBD5E1), size: 20)
            : null,
      ),
    );
  }
}
