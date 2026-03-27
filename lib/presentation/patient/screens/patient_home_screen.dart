// ─── DATA MODELS ─────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import 'package:qless/core/theme/theme.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';

class Doctor {
  final String id, name, specialty, image, about, clinic, address;
  final double rating;
  final int experience, patientsAhead, reviewCount;
  final int waitMinutes;
  final bool isAvailable;
  final List<String> availableSlots;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    required this.image,
    required this.rating,
    required this.experience,
    required this.patientsAhead,
    required this.waitMinutes,
    required this.reviewCount,
    required this.about,
    required this.clinic,
    required this.address,
    required this.isAvailable,
    required this.availableSlots,
  });
}

class Appointment {
  final String id, doctorName, specialty, date, time, status;
  final String doctorImage;
  Appointment({
    required this.id,
    required this.doctorName,
    required this.specialty,
    required this.date,
    required this.time,
    required this.status,
    required this.doctorImage,
  });
}

class FamilyMember {
  String name, relation, bloodGroup, gender;
  int age;
  FamilyMember({
    required this.name,
    required this.relation,
    required this.age,
    required this.gender,
    required this.bloodGroup,
  });
}

// ─── SAMPLE DATA ─────────────────────────────────────────────────────────────

final List<Doctor> sampleDoctors = [
  Doctor(
    id: '1',
    name: 'Dr. Anika Sharma',
    specialty: 'Cardiologist',
    image: 'cardio',
    rating: 4.9,
    experience: 12,
    patientsAhead: 3,
    waitMinutes: 25,
    reviewCount: 248,
    about:
        'Dr. Anika Sharma is a leading Cardiologist with 12 years of experience. She specializes in preventive cardiology, heart failure management, and echocardiography.',
    clinic: 'Apollo Heart Center',
    address: '14 MG Road, Bangalore – 560001',
    isAvailable: true,
    availableSlots: [
      '9:00 AM',
      '9:30 AM',
      '10:00 AM',
      '11:30 AM',
      '2:00 PM',
      '3:00 PM',
    ],
  ),
  Doctor(
    id: '2',
    name: 'Dr. Rajesh Kumar',
    specialty: 'Orthopedist',
    image: 'ortho',
    rating: 4.7,
    experience: 8,
    patientsAhead: 1,
    waitMinutes: 10,
    reviewCount: 183,
    about:
        'Dr. Rajesh Kumar specializes in joint replacement, sports injuries, and spine surgery with 8 years of clinical practice.',
    clinic: 'Fortis Bone & Joint Clinic',
    address: '22 Nehru Place, New Delhi – 110019',
    isAvailable: true,
    availableSlots: [
      '10:00 AM',
      '10:30 AM',
      '11:00 AM',
      '4:00 PM',
      '4:30 PM',
    ],
  ),
  Doctor(
    id: '3',
    name: 'Dr. Priya Nair',
    specialty: 'Dermatologist',
    image: 'derm',
    rating: 4.8,
    experience: 6,
    patientsAhead: 5,
    waitMinutes: 40,
    reviewCount: 312,
    about:
        'Dr. Priya Nair is a board-certified Dermatologist focusing on cosmetic dermatology, acne treatment, and skin cancer screening.',
    clinic: 'Skin Studio Clinic',
    address: 'Plot 7, Jubilee Hills, Hyderabad – 500033',
    isAvailable: true,
    availableSlots: [
      '11:00 AM',
      '11:30 AM',
      '12:00 PM',
      '5:00 PM',
      '5:30 PM',
    ],
  ),
  Doctor(
    id: '4',
    name: 'Dr. Mohan Verma',
    specialty: 'Neurologist',
    image: 'neuro',
    rating: 4.6,
    experience: 15,
    patientsAhead: 0,
    waitMinutes: 5,
    reviewCount: 97,
    about:
        'Dr. Mohan Verma is a senior Neurologist specializing in epilepsy, stroke, and neurodegenerative disorders with 15 years of expertise.',
    clinic: 'NeuroLife Institute',
    address: '3 Park Street, Kolkata – 700016',
    isAvailable: true,
    availableSlots: ['9:00 AM', '9:30 AM', '3:00 PM', '3:30 PM', '4:00 PM'],
  ),
];

final List<Appointment> sampleAppointments = [
  Appointment(
    id: '1',
    doctorName: 'Dr. Anika Sharma',
    specialty: 'Cardiologist',
    date: 'Tomorrow, 28 Mar',
    time: '10:00 AM',
    status: 'Upcoming',
    doctorImage: 'cardio',
  ),
  Appointment(
    id: '2',
    doctorName: 'Dr. Priya Nair',
    specialty: 'Dermatologist',
    date: '2 Apr 2025',
    time: '11:30 AM',
    status: 'Upcoming',
    doctorImage: 'derm',
  ),
  Appointment(
    id: '3',
    doctorName: 'Dr. Rajesh Kumar',
    specialty: 'Orthopedist',
    date: '15 Mar 2025',
    time: '9:00 AM',
    status: 'Completed',
    doctorImage: 'ortho',
  ),
  Appointment(
    id: '4',
    doctorName: 'Dr. Mohan Verma',
    specialty: 'Neurologist',
    date: '5 Mar 2025',
    time: '4:00 PM',
    status: 'Cancelled',
    doctorImage: 'neuro',
  ),
];

final List<FamilyMember> sampleFamily = [
  FamilyMember(
    name: 'Ravi Mehta',
    relation: 'Father',
    age: 62,
    gender: 'Male',
    bloodGroup: 'B+',
  ),
  FamilyMember(
    name: 'Sunita Mehta',
    relation: 'Mother',
    age: 58,
    gender: 'Female',
    bloodGroup: 'O+',
  ),
];

// ─── SPECIALTY DATA ───────────────────────────────────────────────────────────

final List<Map<String, dynamic>> specialties = [
  {'name': 'Cardiology', 'icon': Icons.favorite_rounded, 'color': 0xFFEF4444},
  {'name': 'Orthopedics', 'icon': Icons.accessibility_new, 'color': 0xFF3B82F6},
  {
    'name': 'Dermatology',
    'icon': Icons.face_retouching_natural,
    'color': 0xFFF59E0B
  },
  {'name': 'Neurology', 'icon': Icons.psychology, 'color': 0xFF8B5CF6},
  {'name': 'Pediatrics', 'icon': Icons.child_care, 'color': 0xFF10B981},
  {'name': 'Dentistry', 'icon': Icons.medical_services, 'color': 0xFF06B6D4},
  {'name': 'Ophthalmology', 'icon': Icons.visibility, 'color': 0xFFEC4899},
  {'name': 'Gynecology', 'icon': Icons.pregnant_woman, 'color': 0xFF14B8A6},
];

// ─── HELPERS & WIDGETS ───────────────────────────────────────────────────────

Color _doctorColor(String image) {
  switch (image) {
    case 'cardio':
      return const Color(0xFFEF4444);
    case 'ortho':
      return const Color(0xFF3B82F6);
    case 'derm':
      return const Color(0xFFF59E0B);
    case 'neuro':
      return const Color(0xFF8B5CF6);
    default:
      return AppTheme.primary;
  }
}

IconData _doctorIcon(String image) {
  switch (image) {
    case 'cardio':
      return Icons.favorite_rounded;
    case 'ortho':
      return Icons.accessibility_new;
    case 'derm':
      return Icons.face_retouching_natural;
    case 'neuro':
      return Icons.psychology;
    default:
      return Icons.local_hospital;
  }
}

Widget _doctorAvatar(String image, {double size = 56}) {
  final color = _doctorColor(image);
  final icon = _doctorIcon(image);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [color.withOpacity(0.8), color],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(size * 0.3),
    ),
    child: Icon(icon, color: Colors.white, size: size * 0.5),
  );
}

class HomeScreen extends StatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final Function(int) onTabChange;
  const HomeScreen(
      {super.key,
      required this.onToggleTheme,
      required this.themeMode,
      required this.onTabChange});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _itemAnims;

  @override
  void initState() {
    super.initState();
    _animCtrl =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _itemAnims = List.generate(6, (i) {
      return Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(i * 0.1, 0.6 + i * 0.07, curve: Curves.easeOut),
        ),
      );
    });
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark
                      ? [
                          const Color(0xFF1E293B),
                          const Color(0xFF0F172A),
                        ]
                      : [
                          const Color(0xFF1A73E8),
                          const Color(0xFF0D5DBF),
                        ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(32),
                  bottomRight: Radius.circular(32),
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedBuilder(
                        animation: _itemAnims[0],
                        builder: (_, child) => Opacity(
                          opacity: _itemAnims[0].value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _itemAnims[0].value)),
                            child: child,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Good Morning 👋',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.75),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Arjun Mehta',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                _HeaderBtn(
                                  icon: widget.themeMode == ThemeMode.dark
                                      ? Icons.light_mode_rounded
                                      : Icons.dark_mode_rounded,
                                  onTap: widget.onToggleTheme,
                                ),
                                const SizedBox(width: 10),
                                _HeaderBtn(
                                  icon: Icons.notifications_outlined,
                                  onTap: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              const NotificationsScreen())),
                                  badge: true,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      AnimatedBuilder(
                        animation: _itemAnims[1],
                        builder: (_, child) => Opacity(
                          opacity: _itemAnims[1].value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - _itemAnims[1].value)),
                            child: child,
                          ),
                        ),
                        child: GestureDetector(
                          onTap: () => widget.onTabChange(1),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.3),
                                  width: 1),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.search_rounded,
                                    color: Colors.white.withOpacity(0.8),
                                    size: 22),
                                const SizedBox(width: 10),
                                Text(
                                  'Search doctors or specialties...',
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Quick Actions
                AnimatedBuilder(
                  animation: _itemAnims[2],
                  builder: (_, child) => Opacity(
                    opacity: _itemAnims[2].value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _itemAnims[2].value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Quick Actions'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _QuickAction(
                            icon: Icons.calendar_month_rounded,
                            label: 'Book\nAppointment',
                            color: const Color(0xFF1A73E8),
                            onTap: () => widget.onTabChange(1),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.history_rounded,
                            label: 'My\nAppointments',
                            color: const Color(0xFF00BFA5),
                            onTap: () => widget.onTabChange(2),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.group_add_rounded,
                            label: 'Add\nFamily',
                            color: const Color(0xFF7C3AED),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) =>
                                        const FamilyMembersScreen())),
                          ),
                          const SizedBox(width: 12),
                          _QuickAction(
                            icon: Icons.medical_information_rounded,
                            label: 'My\nRecords',
                            color: const Color(0xFFF59E0B),
                            onTap: () {},
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Upcoming Appointments
                AnimatedBuilder(
                  animation: _itemAnims[3],
                  builder: (_, child) => Opacity(
                    opacity: _itemAnims[3].value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _itemAnims[3].value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Upcoming Appointments', action: 'See All',
                          onAction: () => widget.onTabChange(2)),
                      const SizedBox(height: 16),
                      ...sampleAppointments
                          .where((a) => a.status == 'Upcoming')
                          .map((a) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _UpcomingCard(appointment: a),
                              )),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Specialties
                AnimatedBuilder(
                  animation: _itemAnims[4],
                  builder: (_, child) => Opacity(
                    opacity: _itemAnims[4].value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _itemAnims[4].value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Most Searched Specialties'),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 110,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: specialties.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: 12),
                          itemBuilder: (_, i) {
                            final s = specialties[i];
                            return _SpecialtyChip(
                              icon: s['icon'],
                              label: s['name'],
                              color: Color(s['color']),
                              onTap: () {
                                
                              },
                              // onTap: () => Navigator.push(
                              //     context,
                              //     MaterialPageRoute(
                              //         builder: (_) =>
                              //             const DoctorSearchScreen())),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                // Top Doctors
                AnimatedBuilder(
                  animation: _itemAnims[5],
                  builder: (_, child) => Opacity(
                    opacity: _itemAnims[5].value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _itemAnims[5].value)),
                      child: child,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _SectionTitle('Top Rated Doctors', action: 'View All',
                          onAction: () => widget.onTabChange(1)),
                      const SizedBox(height: 16),
                      ...sampleDoctors
                          .take(2)
                          .map((d) => Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _DoctorCard(
                                    doctor: d,
                                    onTap: () {
                                      
                                    },
                                    // onTap: () => Navigator.push(
                                    //     context,
                                    //     MaterialPageRoute(
                                    //         builder: (_) =>
                                    //             DoctorProfileScreen(
                                    //                 doctor: d)))
                                    ),
                              )),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeaderBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn(
      {required this.icon, required this.onTap, this.badge = false});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          if (badge)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: const BoxDecoration(
                  color: Color(0xFFF59E0B),
                  shape: BoxShape.circle,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: isDark ? Colors.white : AppTheme.textPrimary,
          ),
        ),
        if (action != null)
          GestureDetector(
            onTap: onAction,
            child: Text(
              action!,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickAction(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: isDark
                ? color.withOpacity(0.15)
                : color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white70 : AppTheme.textPrimary,
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

class _UpcomingCard extends StatelessWidget {
  final Appointment appointment;
  const _UpcomingCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A73E8).withOpacity(isDark ? 0.25 : 0.08),
            const Color(0xFF00BFA5).withOpacity(isDark ? 0.25 : 0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: const Color(0xFF1A73E8).withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          _doctorAvatar(appointment.doctorImage, size: 52),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.doctorName,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  appointment.specialty,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white54 : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.calendar_today_rounded,
                        size: 13, color: AppTheme.primary),
                    const SizedBox(width: 4),
                    Text(
                      appointment.date,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.access_time_rounded,
                        size: 13, color: AppTheme.secondary),
                    const SizedBox(width: 4),
                    Text(
                      appointment.time,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.secondary),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.videocam_rounded,
                color: Colors.white, size: 18),
          ),
        ],
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyChip(
      {required this.icon,
      required this.label,
      required this.color,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 90,
        decoration: BoxDecoration(
          color: isDark
              ? color.withOpacity(0.15)
              : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white70 : AppTheme.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── DOCTOR CARD ─────────────────────────────────────────────────────────────

class _DoctorCard extends StatelessWidget {
  final Doctor doctor;
  final VoidCallback onTap;
  const _DoctorCard({required this.doctor, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.2 : 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _doctorAvatar(doctor.image, size: 64),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          doctor.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      Row(
                        children: [
                          const Icon(Icons.star_rounded,
                              color: Color(0xFFF59E0B), size: 16),
                          const SizedBox(width: 3),
                          Text(
                            doctor.rating.toString(),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF59E0B),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    doctor.specialty,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      _InfoTag(
                          icon: Icons.work_history_rounded,
                          label: '${doctor.experience}yr',
                          color: const Color(0xFF10B981)),
                      const SizedBox(width: 8),
                      _InfoTag(
                          icon: Icons.people_rounded,
                          label:
                              '${doctor.patientsAhead} ahead',
                          color: const Color(0xFFF59E0B)),
                      const SizedBox(width: 8),
                      _InfoTag(
                          icon: Icons.timer_rounded,
                          label: '~${doctor.waitMinutes}min',
                          color: const Color(0xFF6366F1)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: onTap,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            side: const BorderSide(color: AppTheme.primary),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('View Profile',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            
                          },
                          // onPressed: () => Navigator.push(
                          //   context,
                          //   MaterialPageRoute(
                          //     builder: (_) =>
                          //         BookAppointmentScreen(doctor: doctor),
                          //   ),
                          // ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                          child: const Text('Book Now',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoTag extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _InfoTag(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(isDark ? 0.2 : 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}