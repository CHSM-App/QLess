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

  late final List<Widget> _screens;
  late final List<AnimationController> _iconControllers;
  late final List<Animation<double>> _iconScales;

  // ── Palette ────────────────────────────────────────────────────
// ── Palette (update these to match doctor) ─────────────────────
static const _accent      = Color(0xFF6366F1); // match doctor indigo
static const _inactiveClr = Color(0xFF1E293B); // match doctor dark slate
static const _pillBg      = Color(0x12FFFFFF);
static const _pillBorder  = Color(0x26000000);
static const _activePill  = Color(0x1A6366F1); // match doctor 10% indigo tint
static const _compactNavHeight = 48.0;
static const _regularNavHeight = 56.0;

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
      
      const DoctorExploreScreen(),
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
  return ConnectivityBannerWrapper(
    child: PopScope(
    canPop: _tab == 0,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _setTab(0);
    },
    child: AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
      child: Scaffold(
        extendBody: true,
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            Positioned.fill(
              child: SafeArea(
                bottom: false,
                child: IndexedStack(index: _tab, children: _screens),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: _buildBottomNav(),
            ),
          ],
        ),
      ),
    ),
    ),
  );
}
  // ── Floating Glass Pill ───────────────────────────────────────
  Widget _buildBottomNav() {
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
                  color: _pillBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                    color: _pillBorder,
                    width: 0.3,
                  ),
                ),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final totalWidth = constraints.maxWidth;
                    final itemCount = _navItems.length;
                    final itemWidth = totalWidth / itemCount;
                    final pillWidth = itemWidth - 10;
                    final currentCenter = (_tab + 0.5) * itemWidth;
                    final minCenter = itemWidth / 2;
                    final maxCenter = totalWidth - itemWidth / 2;
                    final dragCenter = (_dragX ?? currentCenter)
                        .clamp(minCenter, maxCenter)
                        .toDouble();
                    final pillLeft = (dragCenter - pillWidth / 2)
                        .clamp(0.0, totalWidth - pillWidth)
                        .toDouble();

                    return GestureDetector(
                      onHorizontalDragStart: (details) {
                        setState(() {
                          _isDragging = true;
                          _dragX = details.localPosition.dx;
                          _dragHoverIndex = _tab;
                        });
                      },
                      onHorizontalDragUpdate: (details) {
                        setState(() {
                          _dragX = details.localPosition.dx
                              .clamp(minCenter, maxCenter)
                              .toDouble();
                          final hoverIndex =
                              ((_dragX ?? currentCenter) / itemWidth)
                                  .floor()
                                  .clamp(0, itemCount - 1);
                          if (hoverIndex != _dragHoverIndex) {
                            _dragHoverIndex = hoverIndex;
                            HapticFeedback.selectionClick();
                          }
                        });
                      },
                      onHorizontalDragEnd: (_) {
                        final targetCenter = (_dragX ?? currentCenter)
                            .clamp(minCenter, maxCenter)
                            .toDouble();
                        final newIndex = (targetCenter / itemWidth)
                            .floor()
                            .clamp(0, itemCount - 1);
                        setState(() {
                          _isDragging = false;
                          _dragX = null;
                          _dragHoverIndex = null;
                        });
                        _setTab(newIndex);
                      },
                      onHorizontalDragCancel: () {
                        setState(() {
                          _isDragging = false;
                          _dragX = null;
                          _dragHoverIndex = null;
                        });
                      },
                      behavior: HitTestBehavior.translucent,
                      child: Stack(
                        children: [
                          AnimatedPositioned(
                            duration: _isDragging
                                ? Duration.zero
                                : const Duration(milliseconds: 220),
                            curve: Curves.easeInOut,
                            left: pillLeft,
                            top: 5,
                            width: pillWidth,
                            height: pillHeight,
                            child: Container(
                              decoration: BoxDecoration(
                                color: _activePill,
                                borderRadius: BorderRadius.circular(22),
                              ),
                            ),
                          ),
                          Row(
                            children: List.generate(_navItems.length, (i) {
                              final selected = _tab == i;
                              return Expanded(
                                child: GestureDetector(
                                  onTap: () => _setTab(i),
                                  behavior: HitTestBehavior.opaque,
                                  child: AnimatedBuilder(
                                    animation: _iconScales[i],
                                    builder: (context, _) => Container(
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
                                                  ? _accent
                                                  : _inactiveClr,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          AnimatedDefaultTextStyle(
                                            duration: const Duration(
                                                milliseconds: 200),
                                            style: TextStyle(
                                              fontSize: isCompact ? 8 : 9,
                                              fontWeight: selected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                              color: selected
                                                  ? _accent
                                                  : _inactiveClr,
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
