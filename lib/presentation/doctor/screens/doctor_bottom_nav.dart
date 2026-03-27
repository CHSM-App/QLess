import 'dart:math' as math;
import 'package:flutter/material.dart';
// ── Palette ──────────────────────────────────
const kBg = Color(0xFFF0F4F1);
const kPrimary = Color(0xFF0B6E4F);
const kPrimaryLight = Color(0xFF13A875);
const kAccent = Color(0xFFE8F5F0);
const kCard = Colors.white;
const kText = Color(0xFF0D1F1A);
const kSub = Color(0xFF7A9B90);
const kRed = Color(0xFFE05C5C);
const kAmber = Color(0xFFF5A623);
const kBlue = Color(0xFF3D8EDE);
const kPurple = Color(0xFF8B5CF6);

// ─────────────────────────────────────────────
// MAIN DASHBOARD
// ─────────────────────────────────────────────
class DoctorBottomNav extends StatefulWidget {
  const DoctorBottomNav({super.key});

  @override
  State<DoctorBottomNav> createState() => _DoctorBottomNavState();
}

class _DoctorBottomNavState extends State<DoctorBottomNav>
    with SingleTickerProviderStateMixin {
  int _navIndex = 0;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(
        parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      drawer: _buildDrawer(),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            _buildSliverAppBar(),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: 20),
                  _statsRow(),
                  const SizedBox(height: 24),
                  _todaySchedule(),
                  const SizedBox(height: 24),
                  _patientQueue(),
                  const SizedBox(height: 24),
                  _recentActivities(),
                  const SizedBox(height: 24),
                  _weeklyOverview(),
                ]),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNav(),
    );
  }

  // ── Sliver AppBar ──────────────────────────
  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      floating: false,
      pinned: true,
      backgroundColor: kPrimary,
      surfaceTintColor: Colors.transparent,
      leading: Builder(
        builder: (ctx) => IconButton(
          icon: const Icon(Icons.menu_rounded, color: Colors.white),
          onPressed: () => Scaffold.of(ctx).openDrawer(),
        ),
      ),
      actions: [
        Stack(children: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, color: Colors.white),
            onPressed: () {},
          ),
          Positioned(
            top: 10,
            right: 12,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: kRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ]),
        Padding(
          padding: const EdgeInsets.only(right: 16),
          child: CircleAvatar(
            radius: 18,
            backgroundColor: Colors.white.withOpacity(0.2),
            child: const Icon(Icons.person_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: _sliverBackground(),
      ),
    );
  }

  Widget _sliverBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF063D2C), kPrimary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // decorative circles
          Positioned(
            top: -30,
            right: -30,
            child: _circle(120, Colors.white.withOpacity(0.05)),
          ),
          Positioned(
            bottom: 10,
            right: 60,
            child: _circle(60, Colors.white.withOpacity(0.04)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 80, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: kPrimaryLight.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.circle,
                              color: Color(0xFF4FFFB0), size: 8),
                          SizedBox(width: 5),
                          Text('On Duty',
                              style: TextStyle(
                                  color: Color(0xFF4FFFB0),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Dr. Arjun Nair',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const Text(
                  'Cardiologist · City Heart Hospital',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circle(double size, Color color) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, color: color),
    );
  }

  // ── Stats Row ──────────────────────────────
  Widget _statsRow() {
    return Row(
      children: [
        _statCard('24', 'Patients\nToday', Icons.people_alt_rounded, kPrimary),
        const SizedBox(width: 12),
        _statCard('6', 'Pending\nReviews', Icons.pending_actions_rounded, kAmber),
        const SizedBox(width: 12),
        _statCard('3', 'Critical\nCases', Icons.monitor_heart_rounded, kRed),
      ],
    );
  }

  Widget _statCard(
      String value, String label, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 14),
        decoration: BoxDecoration(
          color: kCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(height: 12),
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 26,
                fontWeight: FontWeight.w800,
              ),
            ),
            Text(
              label,
              style: const TextStyle(
                  color: kSub, fontSize: 11, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }

  // ── Today's Schedule ──────────────────────
  Widget _todaySchedule() {
    final appointments = [
      _ApptData('Sneha Kulkarni', 'Follow-up · Cardio',
          '09:00 AM', AppointmentStatus.inProgress, kPrimary),
      _ApptData('Manoj Desai', 'ECG Report · Cardio',
          '10:30 AM', AppointmentStatus.upcoming, kBlue),
      _ApptData('Riya Patil', 'Chest Pain · Urgent',
          '11:00 AM', AppointmentStatus.urgent, kRed),
      _ApptData('Vishal Torne', 'Routine Checkup',
          '02:00 PM', AppointmentStatus.upcoming, kPurple),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader("Today's Schedule", "View All"),
        const SizedBox(height: 14),
        ...appointments.map((a) => _appointmentTile(a)),
      ],
    );
  }

  Widget _appointmentTile(_ApptData appt) {
    final statusColor = appt.color;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border(
          left: BorderSide(color: statusColor, width: 4),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2)),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: statusColor.withOpacity(0.12),
            child: Text(
              appt.name.substring(0, 1),
              style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w800,
                  fontSize: 16),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appt.name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: kText)),
                const SizedBox(height: 2),
                Text(appt.detail,
                    style: const TextStyle(fontSize: 11, color: kSub)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(appt.time,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kText)),
              const SizedBox(height: 4),
              _statusBadge(appt.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(AppointmentStatus status) {
    String label;
    Color bg, text;
    switch (status) {
      case AppointmentStatus.inProgress:
        label = '● In Progress';
        bg = kPrimary.withOpacity(0.1);
        text = kPrimary;
        break;
      case AppointmentStatus.upcoming:
        label = 'Upcoming';
        bg = kBlue.withOpacity(0.1);
        text = kBlue;
        break;
      case AppointmentStatus.urgent:
        label = '⚠ Urgent';
        bg = kRed.withOpacity(0.1);
        text = kRed;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(label,
          style: TextStyle(
              fontSize: 10, color: text, fontWeight: FontWeight.w700)),
    );
  }

  // ── Patient Queue ─────────────────────────
  Widget _patientQueue() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Patient Queue', 'Manage'),
        const SizedBox(height: 14),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            itemCount: 6,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) {
              final colors = [
                kPrimary, kBlue, kRed, kAmber, kPurple, kPrimaryLight
              ];
              final names = [
                'Asha', 'Rohan', 'Priya', 'Kiran', 'Deepa', 'Sunil'
              ];
              final waits = [
                '5 min', '20 min', '35 min', '50 min', '1h 5m', '1h 20m'
              ];
              return _queueCard(
                  names[i], waits[i], colors[i], i + 1);
            },
          ),
        ),
      ],
    );
  }

  Widget _queueCard(
      String name, String wait, Color color, int qPos) {
    return Container(
      width: 90,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.12),
              blurRadius: 10,
              offset: const Offset(0, 3)),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: color.withOpacity(0.15),
                child:
                    Text(name[0], style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2)),
                  child: Center(
                    child: Text('$qPos',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 9,
                            fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(name,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kText)),
          const SizedBox(height: 2),
          Text(wait,
              style: const TextStyle(fontSize: 10, color: kSub)),
        ],
      ),
    );
  }

  // ── Recent Activities ─────────────────────
  Widget _recentActivities() {
    final activities = [
      _Activity(Icons.description_rounded, 'Prescription Sent',
          'Sneha Kulkarni · 5 min ago', kPrimary),
      _Activity(Icons.science_rounded, 'Lab Results Reviewed',
          'Manoj Desai · 30 min ago', kBlue),
      _Activity(Icons.monitor_heart_rounded, 'ECG Analysed',
          'Riya Patil · 1 hr ago', kRed),
      _Activity(Icons.note_alt_rounded, 'Case Notes Updated',
          'Vishal Torne · 2 hr ago', kAmber),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Recent Activity', 'All'),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: List.generate(activities.length, (i) {
              final a = activities[i];
              return Column(
                children: [
                  ListTile(
                    contentPadding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    leading: Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: a.color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(a.icon, color: a.color, size: 20),
                    ),
                    title: Text(a.title,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kText)),
                    subtitle: Text(a.sub,
                        style:
                            const TextStyle(fontSize: 11, color: kSub)),
                    trailing: const Icon(Icons.chevron_right_rounded,
                        color: kSub, size: 18),
                  ),
                  if (i < activities.length - 1)
                    Divider(
                        height: 1,
                        indent: 72,
                        color: Colors.grey.shade100),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }

  // ── Weekly Overview ───────────────────────
  Widget _weeklyOverview() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final counts = [18, 22, 15, 24, 20, 8, 4];
    final maxVal = counts.reduce(math.max).toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader('Weekly Patients', ''),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final isToday = i == 3;
                  final barH = (counts[i] / maxVal) * 80;
                  return Column(
                    children: [
                      Text(
                        '${counts[i]}',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: isToday ? kPrimary : kSub,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedContainer(
                        duration: Duration(milliseconds: 300 + i * 50),
                        width: 28,
                        height: barH,
                        decoration: BoxDecoration(
                          color: isToday
                              ? kPrimary
                              : kPrimary.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        days[i],
                        style: TextStyle(
                          fontSize: 11,
                          color: isToday ? kPrimary : kSub,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _overviewStat('111', 'Total Week'),
                  _divider(),
                  _overviewStat('15.9', 'Avg / Day'),
                  _divider(),
                  _overviewStat('98%', 'Satisfaction'),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _overviewStat(String val, String label) {
    return Column(
      children: [
        Text(val,
            style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: kPrimary)),
        Text(label,
            style: const TextStyle(fontSize: 11, color: kSub)),
      ],
    );
  }

  Widget _divider() {
    return Container(
        width: 1, height: 32, color: Colors.grey.shade200);
  }

  // ── Helpers ───────────────────────────────
  Widget _sectionHeader(String title, String action) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title,
            style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: kText,
                letterSpacing: -0.2)),
        if (action.isNotEmpty)
          GestureDetector(
            child: Text(action,
                style: const TextStyle(
                    fontSize: 12,
                    color: kPrimary,
                    fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }

  // ── Bottom Nav ────────────────────────────
  Widget _buildBottomNav() {
    final items = [
      _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Dashboard'),
      _NavItem(Icons.people_alt_rounded, Icons.people_alt_outlined, 'Patients'),
      _NavItem(Icons.calendar_month_rounded, Icons.calendar_month_outlined,
          'Schedule'),
      _NavItem(Icons.bar_chart_rounded, Icons.bar_chart_outlined, 'Analytics'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            const BorderRadius.vertical(top: Radius.circular(26)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.07),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (i) {
              final item = items[i];
              final active = _navIndex == i;
              return GestureDetector(
                onTap: () => setState(() => _navIndex = i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeInOut,
                  padding: EdgeInsets.symmetric(
                      horizontal: active ? 18 : 12, vertical: 10),
                  decoration: BoxDecoration(
                    color:
                        active ? kPrimary : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        active ? item.activeIcon : item.icon,
                        color:
                            active ? Colors.white : kSub,
                        size: 22,
                      ),
                      if (active) ...[
                        const SizedBox(width: 7),
                        Text(item.label,
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ],
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

  // ── Drawer ────────────────────────────────
  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: const Color(0xFF063D2C),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: kPrimaryLight,
                    child: Icon(Icons.person_rounded,
                        color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 14),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text('Dr. Arjun Nair',
                          style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 16)),
                      SizedBox(height: 2),
                      Text('Cardiologist',
                          style: TextStyle(
                              color: Colors.white60, fontSize: 13)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 30),
            _drawerTile(Icons.dashboard_rounded, 'Dashboard', true),
            _drawerTile(Icons.people_alt_rounded, 'My Patients', false),
            _drawerTile(Icons.science_rounded, 'Lab Reports', false),
            _drawerTile(Icons.description_rounded, 'Prescriptions', false),
            _drawerTile(Icons.calendar_today_rounded, 'Schedule', false),
            _drawerTile(Icons.bar_chart_rounded, 'Analytics', false),
            const Spacer(),
            Divider(color: Colors.white12, indent: 16, endIndent: 16),
            _drawerTile(Icons.settings_rounded, 'Settings', false),
            _drawerTile(Icons.logout_rounded, 'Logout', false),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _drawerTile(IconData icon, String label, bool active) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: active ? kPrimary : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
      ),
      child: ListTile(
        leading: Icon(icon,
            color: active ? Colors.white : Colors.white60, size: 22),
        title: Text(label,
            style: TextStyle(
                color: active ? Colors.white : Colors.white60,
                fontWeight:
                    active ? FontWeight.w700 : FontWeight.w400,
                fontSize: 14)),
        onTap: () => Navigator.pop(context),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ── Data Models ───────────────────────────────
enum AppointmentStatus { inProgress, upcoming, urgent }

class _ApptData {
  final String name, detail, time;
  final AppointmentStatus status;
  final Color color;
  _ApptData(this.name, this.detail, this.time, this.status, this.color);
}

class _Activity {
  final IconData icon;
  final String title, sub;
  final Color color;
  _Activity(this.icon, this.title, this.sub, this.color);
}

class _NavItem {
  final IconData icon, activeIcon;
  final String label;
  _NavItem(this.icon, this.activeIcon, this.label);
}