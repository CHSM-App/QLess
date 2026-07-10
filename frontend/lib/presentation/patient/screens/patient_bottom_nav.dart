import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qless/presentation/patient/screens/appintment_screen.dart';
import 'package:qless/presentation/patient/screens/doctor_explore.dart';
import 'package:qless/presentation/patient/screens/patient_home_screen.dart';
import 'package:qless/presentation/patient/screens/profile.dart';
import 'package:qless/presentation/shared/widgets/connectivity_banner.dart';

// Global handle so notification taps can drive the patient shell from
// anywhere (in-app inbox, FCM tray) — they switch the active tab and pass
// deep-link args to the in-shell AppointmentScreen, which keeps the bottom
// bar visible and avoids pushing standalone screens on top of the shell.
GlobalKey<PatientBottomNavState> patientShellKey =
    GlobalKey<PatientBottomNavState>();

// Cold-start FCM tap fires before the shell mounts (getInitialMessage runs
// in main() pre-runApp). Queue the deep link here; the shell's initState
// drains it on mount.
({String? filter, int? appointmentId})? _pendingAppointmentsDeepLink;
int? _pendingRatingAppointmentId;

/// Apply an Appointments deep link now if the shell is mounted, otherwise
/// queue it for when the shell mounts. Safe to call from FCM handlers that
/// may fire before the UI exists.
void requestAppointmentsDeepLink({String? filter, int? appointmentId}) {
  final state = patientShellKey.currentState;
  if (state != null) {
    state.openAppointmentsDeepLink(
      filter: filter,
      appointmentId: appointmentId,
    );
  } else {
    _pendingAppointmentsDeepLink =
        (filter: filter, appointmentId: appointmentId);
  }
}

/// Jump directly to the review dialog for [appointmentId] (used by the
/// "Appointment Complete — review it" notification). Queues for shell
/// mount if FCM tap fired on cold start.
void requestAppointmentsRatingDialog(int appointmentId) {
  if (appointmentId <= 0) return;
  final state = patientShellKey.currentState;
  if (state != null) {
    state.openAppointmentsRatingDialog(appointmentId);
  } else {
    _pendingRatingAppointmentId = appointmentId;
  }
}

// "View all specialties" on Home switches to the Doctors tab (index 1) and
// scrolls it to the Browse by Specialty section — the tab is kept alive in
// an IndexedStack, so this must drive the existing instance rather than
// push a standalone route (which would hide the bottom bar).
void requestDoctorExploreSpecialty() {
  patientShellKey.currentState?.openDoctorExploreSpecialty();
}

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
  State<PatientBottomNav> createState() => PatientBottomNavState();
}

class PatientBottomNavState extends State<PatientBottomNav>
    with TickerProviderStateMixin {
  int _tab = 0;
  bool _isDragging = false;
  double? _dragX;
  int? _dragHoverIndex;

  final GlobalKey<AppointmentScreenState> _appointmentsKey =
      GlobalKey<AppointmentScreenState>();
  final GlobalKey<DoctorExploreScreenState> _doctorExploreKey =
      GlobalKey<DoctorExploreScreenState>();

  late final List<Widget> _screens;
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // ── Palette ────────────────────────────────────────────────────
static const _accent      = Color(0xFF6366F1); // indigo
static const _accentDark  = Color(0xFF4F46E5);
static const _inactiveClr = Color(0xFF94A3B8); // muted slate for inactive icons/labels
static const _pillBg      = Colors.white;
static const _pillBorder  = Color(0xFFE2E8F0);
static const _activePill  = Color(0x1A6366F1); // 10% indigo tint
static const _iconChipInactive = Color(0xFFEEF0FF); // soft indigo chip bg
static const _iconChipActive   = Color(0xFF6366F1); // solid indigo (active)
static const _compactNavHeight = 54.0;
static const _regularNavHeight = 64.0;

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

  // Called by notification tap handlers (in-app inbox + FCM tray) to drop
  // the patient on the Appointments tab with a specific filter / detail
  // sheet pre-opened. Keeps the bottom bar visible — pushing /appointment
  // as a standalone route hides it.
  void openAppointmentsDeepLink({String? filter, int? appointmentId}) {
    _setTab(2);
    // Defer so the IndexedStack swap has finished and the in-shell
    // AppointmentScreen's state is available.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appointmentsKey.currentState?.applyDeepLink(
        filter: filter,
        appointmentId: appointmentId,
      );
    });
  }

  // 'Appointment Complete — review it' notification: switch to Appointments
  // tab (so the review submission has list context to refresh on) and ask
  // the in-shell screen to pop the rating dialog as soon as the row loads.
  void openAppointmentsRatingDialog(int appointmentId) {
    _setTab(2);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _appointmentsKey.currentState?.applyRatingDeepLink(appointmentId);
    });
  }

  // 'View all specialties' on Home: switch to the Doctors tab (index 1) and
  // scroll it to the Browse by Specialty section.
  void openDoctorExploreSpecialty() {
    _setTab(1);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _doctorExploreKey.currentState?.scrollToSpecialtySection();
    });
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
        onSeeAllAppointments: () => openAppointmentsDeepLink(filter: 'upcoming'),
      ),
      
      DoctorExploreScreen(key: _doctorExploreKey),
      AppointmentScreen(key: _appointmentsKey, onTabChange: _setTab),
      const PatientProfilePage(),
    ];

    if (_tab == 2) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _appointmentsKey.currentState?.refreshOnVisible();
      });
    }

    // Drain any FCM deep link queued before the shell mounted (cold-start
    // notification tap). Done after first frame so the IndexedStack screens
    // have their states ready to receive applyDeepLink.
    final pending = _pendingAppointmentsDeepLink;
    if (pending != null) {
      _pendingAppointmentsDeepLink = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        openAppointmentsDeepLink(
          filter: pending.filter,
          appointmentId: pending.appointmentId,
        );
      });
    }

    final pendingRating = _pendingRatingAppointmentId;
    if (pendingRating != null) {
      _pendingRatingAppointmentId = null;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        openAppointmentsRatingDialog(pendingRating);
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
  return PopScope(
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _setTab(0);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFFF3F4F8),
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFFF3F4F8),
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Expanded(child: IndexedStack(index: _tab, children: _screens)),
              _buildBottomNav(),
              const ConnectivityBannerBar(),
            ],
          ),
        ),
      ),
    ),
  );
}
  // ── Expanding Pill Bar — selected tab grows into a tinted pill with
  // icon + label side by side; others stay as plain grey icons. ──────
  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: _pillBorder, width: 0.6)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(_navItems.length, (i) {
              final selected = _tab == i;
              return GestureDetector(
                onTap: () => _setTab(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected ? _iconChipInactive : Colors.transparent,
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        selected ? _navItems[i].activeIcon : _navItems[i].icon,
                        size: 22,
                        color: selected ? _accentDark : _inactiveClr,
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
                                      color: _accentDark,
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
