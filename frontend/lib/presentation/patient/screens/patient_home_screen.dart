import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart' as geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:qless/core/utils/name_utils.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/patient/providers/patient_usecase_provider.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/appointment_viewmodel.dart';
import 'package:qless/presentation/patient/screens/book_appointment_screen.dart';
import 'package:qless/presentation/patient/screens/doctors_search_screen.dart';
import 'package:qless/presentation/patient/screens/patient_bottom_nav.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/location_services.dart';
import 'package:qless/presentation/patient/screens/location_storage.dart';
import 'package:qless/presentation/patient/providers/notification_provider.dart';
import 'package:qless/presentation/patient/screens/patient_notification.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

// ── Colour Palette ─────────────────────────────────────────────────
const kPageBg = Color(0xFFF8F9FB);
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF1EA898);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);

const kBorder = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kSuccess = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);

// Darker variants of the status colours. The base tones are tuned for fills
// and borders; on their own light backgrounds (kGreenLight/kAmberLight/
// kRedLight) they wash out, so text and icons use these instead. Each keeps
// the hue of its base colour and only drops in lightness, so they read as the
// same family rather than a second, louder palette.
const kSuccessDark = Color(0xFF2F855A);
const kWarningDark = Color(0xFFB7791F);
const kErrorDark = Color(0xFFC53030);

// Banner text ink. Neutral on purpose: a tinted background reads best with
// plain dark text, letting the fill, icon and border carry the status colour.
const kBannerInk = Color(0xFF1F2933);
const kPurple = Color(0xFF9F7AEA);
const kPurpleLight = Color(0xFFEDE9FE);
const kInfo = Color(0xFF3B82F6);
const kInfoLight = Color(0xFFDBEAFE);

// ── Specialty colour/icon helpers ──────────────────────────────────
const _kAccentPalette = [
  Color(0xFFFC8181),
  Color(0xFFF6AD55),
  Color(0xFF68D391),
  Color(0xFF9F7AEA),
  Color(0xFF3B82F6),
  Color(0xFF26C6B0),
  Color(0xFFF687B3),
  Color(0xFF4FD1C5),
  Color(0xFFED8936),
  Color(0xFF667EEA),
];
const _kIconPalette = <IconData>[
  Icons.favorite_rounded,
  Icons.face_retouching_natural,
  Icons.child_care_rounded,
  Icons.accessibility_new_rounded,
  Icons.psychology_rounded,
  Icons.local_hospital_rounded,
  Icons.pregnant_woman_rounded,
  Icons.visibility_rounded,
  Icons.medical_services_rounded,
  Icons.hearing_rounded,
];

int _hashIndex(String? s, int length) {
  if (s == null || s.isEmpty) return 0;
  var h = 0;
  for (final c in s.toLowerCase().codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % length;
}

Color _accentForSpec(String? s) =>
    _kAccentPalette[_hashIndex(s, _kAccentPalette.length)];
IconData _iconForSpec(String? s) =>
    _kIconPalette[_hashIndex(s, _kIconPalette.length)];

List<Map<String, dynamic>> _buildSpecialtyList(List<DoctorDetails> doctors) {
  final seen = <String>{};
  final result = <Map<String, dynamic>>[];
  for (final d in doctors) {
    final s = d.specialization?.trim();
    if (s != null && s.isNotEmpty && seen.add(s.toLowerCase())) {
      result.add({
        'name': s,
        'icon': _iconForSpec(s),
        'color': _accentForSpec(s),
      });
    }
  }
  return result;
}

// ── Flat card helper ────────────────────────────────────────────────
// Replaces the old neomorphic (soft-UI) surface with a clean flat card:
// white surface, a hairline border, and only a whisper of shadow so cards
// still separate from the page without the heavy embossed look. Every call
// site that used to ask for a "pressed" (inset) look now gets a subtly
// tinted flat surface instead — same call signature, flatter result.
const _kCardBorder = Color(0xFFEDF1F5);
const _kCardShadow = Color(0x0F1A202C);

BoxDecoration _neoBox({
  double radius = 14,
  Color color = Colors.white,
  bool pressed = false,
  Border? border,
}) {
  return BoxDecoration(
    color: pressed ? kPrimaryLight.withOpacity(0.55) : color,
    borderRadius: BorderRadius.circular(radius),
    border:
        border ??
        Border.all(
          color: pressed ? kPrimary.withOpacity(0.18) : _kCardBorder,
          width: 1,
        ),
    boxShadow: pressed
        ? const []
        : const [
            BoxShadow(color: _kCardShadow, offset: Offset(0, 2), blurRadius: 8),
          ],
  );
}

// ── Doctor avatar helper ───────────────────────────────────────────
Color _avatarBg(String? spec) {
  final c = _accentForSpec(spec);
  return c.withOpacity(0.15);
}

Widget _doctorAvatar(String? spec, {double size = 46}) {
  final color = _accentForSpec(spec);
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: _avatarBg(spec),
      borderRadius: BorderRadius.circular(size * 0.27),
      border: Border.all(color: color.withOpacity(0.2), width: 1.5),
    ),
    child: Icon(_iconForSpec(spec), color: color, size: size * 0.44),
  );
}

// ── Time helpers ───────────────────────────────────────────────────
DateTime? _timeTodayFromRaw(String? raw) {
  final value = raw?.trim();
  if (value == null ||
      value.isEmpty ||
      value == '--' ||
      value.toLowerCase() == 'null') {
    return null;
  }

  final now = DateTime.now();
  final iso = DateTime.tryParse(value);
  if (iso != null) {
    final u = iso.toUtc();
    return DateTime(now.year, now.month, now.day, u.hour, u.minute);
  }

  final match = RegExp(
    r'^(\d{1,2}):(\d{2})(?::\d{2})?\s*([aApP][mM])?$',
  ).firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null || minute > 59) return null;

  final meridiem = match.group(3)?.toLowerCase();
  if (meridiem != null) {
    if (hour < 1 || hour > 12) return null;
    if (hour == 12) hour = 0;
    if (meridiem == 'pm') hour += 12;
  } else if (hour > 23) {
    return null;
  }

  return DateTime(now.year, now.month, now.day, hour, minute);
}

// ── Shimmer ────────────────────────────────────────────────────────
class _Shimmer extends StatefulWidget {
  final double width, height;
  const _Shimmer({required this.width, required this.height});
  @override
  State<_Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<_Shimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);
    _anim = Tween<double>(
      begin: 0.15,
      end: 0.45,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(_anim.value),
        borderRadius: BorderRadius.circular(4),
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  HOME SCREEN
// ════════════════════════════════════════════════════════════════════
class HomeScreen extends ConsumerStatefulWidget {
  final VoidCallback onToggleTheme;
  final ThemeMode themeMode;
  final Function(int) onTabChange;
  final VoidCallback? onSeeAllAppointments;

  const HomeScreen({
    super.key,
    required this.onToggleTheme,
    required this.themeMode,
    required this.onTabChange,
    this.onSeeAllAppointments,
  });

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animCtrl;
  late List<Animation<double>> _anims;

  String _location = '';
  bool _locationLoaded = false;
  bool _didFetch = false;
  bool _isFetching = false;

  List<Map<String, dynamic>> _cachedSpecialties = [];
  bool _popupShown = false;
  final Map<int, double> _clinicRatings = {};

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _anims = List.generate(
      6,
      (i) => Tween<double>(begin: 0, end: 1).animate(
        CurvedAnimation(
          parent: _animCtrl,
          curve: Interval(i * 0.08, 0.55 + i * 0.07, curve: Curves.easeOut),
        ),
      ),
    );

    _animCtrl.forward();
    _initLocation();
    Future.microtask(_ensurePatientIdAndFetch);
  }

  @override
  void dispose() {
    ref.read(appointmentViewModelProvider.notifier).unwatchClinics();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_isFetching || _didFetch) return;
    _isFetching = true;
    try {
      final notifier = ref.read(patientLoginViewModelProvider.notifier);
      var pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (pid == 0) {
        await notifier.loadFromStoragePatient();
        pid = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      }
      if (pid == 0) return;
      _didFetch = true;
      // Refresh the notification inbox in parallel so the header bell's unread
      // count is accurate on cold start — without this, the badge stays empty
      // until an FCM arrives or the user opens the Notifications screen.
      ref.read(notificationProvider.notifier).loadFromServer();
      await Future.wait([
        ref
            .read(appointmentViewModelProvider.notifier)
            .getPatientAppointments(pid),
        ref.read(doctorsViewModelProvider.notifier).fetchDoctors(pid),
      ]);
      if (!mounted) return;
      _loadTopRatings(ref.read(doctorsViewModelProvider).doctors);
      final appts =
          ref
              .read(appointmentViewModelProvider)
              .patientAppointmentsList
              ?.value ??
          [];
      final now = DateTime.now();
      final liveDocIds = appts
          .where((a) {
            final s = a.status?.toLowerCase() ?? '';
            if (s != 'booked' && s != 'in_progress' && s != 'skipped')
              return false;
            if (a.bookingType != 1) return false;
            final d = DateTime.tryParse(a.appointmentDate ?? '');
            return d != null &&
                d.year == now.year &&
                d.month == now.month &&
                d.day == now.day;
          })
          .map((a) => a.doctorId)
          .whereType<int>()
          .toSet()
          .toList();
      if (liveDocIds.isNotEmpty) {
        ref
            .read(appointmentViewModelProvider.notifier)
            .watchClinics(liveDocIds, pid);
      }
    } finally {
      _isFetching = false;
    }
  }

  Future<void> _loadTopRatings(List<DoctorDetails> doctors) async {
    final rated =
        doctors
            .where(
              (d) =>
                  d.doctorId != null &&
                  (d.rating ?? 0) >= 3.5 &&
                  (d.reviewCount ?? 0) >= 3,
            )
            .toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));
    final toFetch = rated
        .take(3)
        .where((d) => !_clinicRatings.containsKey(d.doctorId))
        .toList();
    if (toFetch.isEmpty) return;
    final reviewUsecase = ref.read(reviewUsecaseProvider);
    final apptUsecase = ref.read(appointmentUsecaseProvider);
    final results = await Future.wait(
      toFetch.map((d) async {
        final id = d.doctorId!;
        final clinicId = d.clinicId;
        try {
          final allReviews = await reviewUsecase.getDoctorReviews(
            id,
            clinicId ?? '',
          );
          if (allReviews.isEmpty) return MapEntry(id, d.rating ?? 0.0);
          var reviews = allReviews;
          if (clinicId != null && clinicId.isNotEmpty) {
            try {
              final appts = await apptUsecase.fetchPatientAppointments(
                id,
                clinicId: clinicId,
              );
              final apptIds = appts
                  .map((a) => a.appointmentId)
                  .whereType<int>()
                  .toSet();
              if (apptIds.isNotEmpty) {
                final filtered = allReviews
                    .where(
                      (r) =>
                          r.appointmentId != null &&
                          apptIds.contains(r.appointmentId),
                    )
                    .toList();
                if (filtered.isNotEmpty) reviews = filtered;
              }
            } catch (_) {
              // appointment fetch failed — keep all reviews
            }
          }
          final avg =
              reviews.fold<double>(
                0,
                (a, r) => a + (r.rating?.toDouble() ?? 0),
              ) /
              reviews.length;
          return MapEntry(id, avg);
        } catch (_) {
          return MapEntry(id, d.rating ?? 0.0);
        }
      }),
    );
    if (!mounted) return;
    setState(() {
      for (final e in results) {
        _clinicRatings[e.key] = e.value;
      }
    });
  }

  /// Runs once per cold start. A previously saved location — whether picked
  /// manually or auto-detected on the very first run — is the source of truth
  /// on every reopen / logout-reopen: it is shown instantly and the device is
  /// NOT re-located. GPS detection happens only when nothing usable has ever
  /// been saved (true first launch), so the first-set location persists.
  Future<void> _initLocation() async {
    final isManual = await LocationStorage.isManual();
    final saved = await LocationStorage.getLocation();
    if (saved != null &&
        saved.isNotEmpty &&
        (isManual || !_isGenericLocation(saved))) {
      if (mounted) {
        setState(() {
          _location = saved;
          _locationLoaded = true;
        });
      }
      _geocodeAndStore(saved);
      return;
    }
    // First launch (or only a generic/failed value saved) → detect via GPS.
    await _ensureLocationPermission();
  }

  Future<void> _ensureLocationPermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await LocationService.requestPermissionOnce();
    }
    if (perm == LocationPermission.deniedForever) {
      if (mounted) _showLocationSnack();
      await _detectLocation();
      return;
    }
    await _detectLocation();
  }

  /// GPS detection + auto-save. Only reached on first launch (see
  /// [_initLocation]); manual changes go through [_openLocationPicker] /
  /// "Use Current Location" instead.
  Future<void> _detectLocation() async {
    final pos = await LocationService.getCurrentPosition();
    // Reuse the fix we already have instead of asking Geolocator for a second,
    // independent GPS fix — on a first-time cold start the extra fix often
    // pushes the total wait past the timeout and the header falls back to an
    // error string instead of the real location.
    final current = pos != null
        ? await LocationService.addressFromPosition(pos)
        : await LocationService.getCurrentAddress();
    if (mounted) {
      setState(() {
        _location = current;
        _locationLoaded = true;
      });
      await LocationStorage.saveLocation(current, isManual: false);
      if (_isPermIssue(current)) _showLocationSnack();
      if (pos != null) {
        ref.read(selectedPositionProvider.notifier).state = pos;
      }
    }
  }

  /// Geocodes a city/address string to coordinates and stores in shared provider.
  Future<void> _geocodeAndStore(String address) async {
    try {
      final locations = await geocoding.locationFromAddress(address);
      if (locations.isNotEmpty && mounted) {
        final loc = locations.first;
        ref.read(selectedPositionProvider.notifier).state = Position(
          latitude: loc.latitude,
          longitude: loc.longitude,
          timestamp: DateTime.now(),
          accuracy: 0,
          altitude: 0,
          altitudeAccuracy: 0,
          heading: 0,
          headingAccuracy: 0,
          speed: 0,
          speedAccuracy: 0,
        );
      }
    } catch (_) {
      // Geocoding failed — nearby filter will stay at last known position
    }
  }

  void _openLocationPicker() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LocationSheet(
        currentLocation: _location,
        onSelected: (loc) async {
          setState(() {
            _location = loc;
            _locationLoaded = true;
          });
          await LocationStorage.saveLocation(loc, isManual: true);
          if (_isPermIssue(loc)) _showLocationSnack();
          _geocodeAndStore(loc);
        },
      ),
    );
  }

  bool _isPermIssue(String v) {
    final s = v.toLowerCase();
    return s.contains('location disabled') || s.contains('permission');
  }

  bool _isGenericLocation(String v) {
    final s = v.trim().toLowerCase();
    if (s.contains('location ') ||
        s.contains('permission') ||
        s.contains('unknown'))
      return true;
    return RegExp(r'^-?\d+(\.\d+)?\s*,\s*-?\d+(\.\d+)?$').hasMatch(s);
  }

  void _showLocationSnack() {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWindows
              ? 'Enable Windows location services'
              : 'Enable phone location services',
        ),
        action: SnackBarAction(
          label: 'Open Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  bool _isToday(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final n = DateTime.now();
    return p.year == n.year && p.month == n.month && p.day == n.day;
  }

  bool _isUpcoming(AppointmentList a) {
    final p = DateTime.tryParse(a.appointmentDate ?? '');
    if (p == null) return false;
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    return DateTime(p.year, p.month, p.day).isAfter(today);
  }

  // Completed / cancelled appointments must not appear in the home
  // "Upcoming Appointments" list. 'reschedule' stays (it's actionable).
  bool _isActiveAppt(AppointmentList a) {
    final s = a.status?.toLowerCase().trim() ?? '';
    return s != 'cancelled' &&
        s != 'cancled' &&
        s != 'completed' &&
        s != 'complete';
  }

  Widget _fade(int i, Widget child) => AnimatedBuilder(
    animation: _anims[i],
    builder: (_, w) => Opacity(
      opacity: _anims[i].value,
      child: Transform.translate(
        offset: Offset(0, 14 * (1 - _anims[i].value)),
        child: w,
      ),
    ),
    child: child,
  );

  void _goToSearch({String? specialty}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorSearchScreen(initialSpecialty: specialty),
      ),
    );
  }

  // Top rated doctor tap → straight to the booking screen for that doctor
  // (same as other apps; no detour through the search list).
  Future<void> _goToBook(DoctorDetails doctor) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => BookAppointmentScreen(doctor: doctor)),
    );
    if (ok == true && mounted) {
      _didFetch = false;
      _ensurePatientIdAndFetch();
    }
  }

  Widget _buildAppointmentsSection() {
    final vmState = ref.watch(appointmentViewModelProvider);
    final async = vmState.patientAppointmentsList;
    final offline = vmState.offlineDoctors;
    if (async == null || async is AsyncLoading)
      return _apptShell(loading: true);
    return async.when(
      loading: () => _apptShell(loading: true),
      error: (_, __) => const SizedBox.shrink(),
      data: (list) {
        DateTime? apptTime(AppointmentList a) =>
            _timeTodayFromRaw(a.startTime) ??
            _timeTodayFromRaw(a.estimatedArrivalTime);

        final today = list.where(_isToday).where(_isActiveAppt).toList()
          ..sort((a, b) {
            final ta = apptTime(a)?.millisecondsSinceEpoch;
            final tb = apptTime(b)?.millisecondsSinceEpoch;
            if (ta == null && tb == null) return 0;
            if (ta == null) return 1;
            if (tb == null) return -1;
            return ta.compareTo(tb);
          });
        final upcoming = list.where(_isUpcoming).where(_isActiveAppt).toList()
          ..sort((a, b) {
            final da = DateTime.tryParse(a.appointmentDate ?? '');
            final db = DateTime.tryParse(b.appointmentDate ?? '');
            if (da == null && db == null) return 0;
            if (da == null) return 1;
            if (db == null) return -1;
            return da.compareTo(db);
          });
        final combined = [...today, ...upcoming];
        final shown = combined.take(3).toList();
        final hasMore = combined.length > 3;

        if (!_popupShown) {
          final todayActive = today.where((a) {
            final s = a.status?.toLowerCase().trim() ?? '';
            return s != 'cancelled' &&
                s != 'cancled' &&
                s != 'completed' &&
                s != 'complete';
          }).toList();
          if (todayActive.isNotEmpty) {
            final now = DateTime.now();
            DateTime? resolveTime(AppointmentList a) =>
                _timeTodayFromRaw(a.startTime) ??
                _timeTodayFromRaw(a.estimatedArrivalTime);

            todayActive.sort((a, b) {
              final ta = resolveTime(a)?.millisecondsSinceEpoch;
              final tb = resolveTime(b)?.millisecondsSinceEpoch;
              if (ta == null && tb == null) return 0;
              if (ta == null) return 1;
              if (tb == null) return -1;
              return ta.compareTo(tb);
            });

            final nowMinutes = now.hour * 60 + now.minute;
            AppointmentList? next;
            for (final a in todayActive) {
              final t = resolveTime(a);
              if (t == null) continue;
              final apptMinutes = t.hour * 60 + t.minute;
              if (apptMinutes >= nowMinutes) {
                next = a;
                break;
              }
            }
            if (next == null) {
              for (final a in todayActive.reversed) {
                if (resolveTime(a) != null) {
                  next = a;
                  break;
                }
              }
            }
            final popupAppointment = next ?? todayActive.first;
            _popupShown = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _showTodayAppointmentPopup(popupAppointment);
            });
          }
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              'Upcoming Appointments',
              action: hasMore ? 'See All' : null,
              onAction: () => widget.onSeeAllAppointments != null
                  ? widget.onSeeAllAppointments!()
                  : widget.onTabChange(2),
            ),
            const SizedBox(height: 10),
            if (shown.isEmpty)
              _EmptyNote('No upcoming appointments')
            else
              ...shown.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ApptCard(
                    // Stable identity per appointment. Without it the socket's
                    // silent refetch tears down and recreates every card, so
                    // the State is lost and didUpdateWidget never sees the
                    // isMyTurn false→true transition — the "your turn" haptic
                    // was landing in initState, which is deliberately silent.
                    key: ValueKey(e.value.appointmentId ?? e.key),
                    appointment: e.value,
                    isToday: _isToday(e.value),
                    isNext: e.key == 0,
                    doctorOffline: offline.contains(e.value.doctorId),
                    queueEvent: vmState
                        .doctorQueueEvents['${e.value.doctorId}_${e.value.queueId}'],
                    currentServingOverride: vmState
                        .doctorCurrentServing['${e.value.doctorId}_${e.value.clinicId}'],
                    onCancel: () => _handleCancel(e.value),
                    onMarkArrived: () {
                      final familyId =
                          ref.read(patientLoginViewModelProvider).patientId ??
                          0;
                      final patientId = e.value.patientId ?? 0;
                      final appointmentId = e.value.appointmentId ?? 0;
                      if (familyId == 0 ||
                          patientId == 0 ||
                          appointmentId == 0) {
                        return Future.value(false);
                      }
                      return ref
                          .read(appointmentViewModelProvider.notifier)
                          .markArrived(appointmentId, patientId, familyId);
                    },
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  /// Confirms and cancels, then refreshes the list. Mirrors _handleCancel in
  /// the appointments screen so both surfaces behave identically.
  Future<void> _handleCancel(AppointmentList a) async {
    if (ref.read(connectivityNotifierProvider).isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No internet connection. Connect to cancel the appointment.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  color: kRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.cancel_outlined,
                  size: 24,
                  color: kError,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Cancel Appointment',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Are you sure you want to cancel this appointment?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: kTextSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        foregroundColor: kTextSecondary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'No',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text(
                        'Yes, Cancel',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    await ref
        .read(appointmentViewModelProvider.notifier)
        .cancelAppointment(a.appointmentId!);
    if (!mounted) return;
    final id = ref.read(patientLoginViewModelProvider).patientId;
    if (id != null && id != 0) {
      ref
          .read(appointmentViewModelProvider.notifier)
          .getPatientAppointments(id);
    }
  }

  void _showTodayAppointmentPopup(AppointmentList appt) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TodayAppointmentPopup(appointment: appt),
    );
  }

  Widget _apptShell({required bool loading}) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _SectionTitle(
        'Upcoming Appointments',
        action: 'See All',
        onAction: () => widget.onTabChange(2),
      ),
      const SizedBox(height: 10),
      if (loading) ...[
        const _ApptSkeletonCard(),
        const SizedBox(height: 8),
        const _ApptSkeletonCard(),
      ],
    ],
  );

  // Widget _buildSpecialtiesSection(List<DoctorDetails> doctors, bool isLoading) {
  //   if (doctors.isNotEmpty) {
  //     _cachedSpecialties = _buildSpecialtyList(doctors);
  //   }
  //   final specList = _cachedSpecialties;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _SectionTitle('Most Searched Specialties'),
  //       const SizedBox(height: 10),
  //       if (isLoading && specList.isEmpty)
  //         SizedBox(
  //           height: 98,
  //           child: ListView.separated(
  //             scrollDirection: Axis.horizontal,
  //             physics: const BouncingScrollPhysics(),
  //             itemCount: 6,
  //             separatorBuilder: (_, __) => const SizedBox(width: 10),
  //             itemBuilder: (_, __) => _SpecialtyChipSkeleton(),
  //           ),
  //         )
  //       else if (specList.isEmpty)
  //         const SizedBox.shrink()
  //       else
  //         SizedBox(
  //           height: 98,
  //           child: ListView.separated(
  //             scrollDirection: Axis.horizontal,
  //             physics: const BouncingScrollPhysics(),
  //             itemCount: specList.length,
  //             separatorBuilder: (_, __) => const SizedBox(width: 10),
  //             itemBuilder: (_, i) {
  //               final s = specList[i];
  //               return _SpecialtyChip(
  //                 icon:  s['icon']  as IconData,
  //                 label: s['name']  as String,
  //                 color: s['color'] as Color,
  //                 onTap: () => _goToSearch(specialty: s['name'] as String),
  //               );
  //             },
  //           ),
  //         ),
  //     ],
  //   );
  // }
  Widget _buildSpecialtiesSection(List<DoctorDetails> doctors, bool isLoading) {
    if (doctors.isNotEmpty) {
      _cachedSpecialties = _buildSpecialtyList(doctors);
    }
    final specList = _cachedSpecialties;
    final shown = specList.take(4).toList();
    final hasMore = specList.length > 4;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Specialties',
          action: hasMore ? 'View all' : null,
          onAction: hasMore ? () => requestDoctorExploreSpecialty() : null,
        ),
        const SizedBox(height: 10),
        // padding: zero — GridView applies its own default padding, which
        // showed up as dead space above and below the tiles. mainAxisExtent
        // pins each row to the pill's real height (34 icon + 10/10 padding
        // + border) instead of letting childAspectRatio derive a taller cell
        // from the screen width, which is what left the big gap below.
        if (isLoading && specList.isEmpty)
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: List.generate(4, (_) => _SpecialtyPillSkeleton()),
          )
        else if (specList.isEmpty)
          const SizedBox.shrink()
        else
          GridView.builder(
            shrinkWrap: true,
            padding: EdgeInsets.zero,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: shown.length,
            gridDelegate:
                const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 10,
                  crossAxisSpacing: 10,
                  mainAxisExtent: 56,
                ),
            itemBuilder: (_, i) {
              final s = shown[i];
              return _SpecialtyPillCard(
                icon: s['icon'] as IconData,
                label: s['name'] as String,
                color: s['color'] as Color,
                onTap: () => _goToSearch(specialty: s['name'] as String),
              );
            },
          ),
      ],
    );
  }

  // Widget _buildTopRatedDoctorsSection(
  //     List<DoctorDetails> doctors, bool isLoading) {
  //   // Top rated = avg rating >= 3.5 AND at least 3 reviews, so a single stray
  //   // review can't push a doctor to the top. Both fields come straight from the
  //   // getDoctors response (server-aggregated) — no per-doctor review fetch.
  //   final rated = doctors
  //       .where((d) =>
  //           d.doctorId != null &&
  //           (d.rating ?? 0) >= 3.5 &&
  //           (d.reviewCount ?? 0) >= 3)
  //       .toList()
  //     ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

  //   final hasMore = rated.length > 3;
  //   final shownDoctors = rated.take(3).toList();
  //   final stillLoading = isLoading;

  //   return Column(
  //     crossAxisAlignment: CrossAxisAlignment.start,
  //     children: [
  //       _SectionTitle(
  //         'Top Rated Doctors',
  //         action: hasMore ? 'Show all' : null,
  //         onAction: hasMore ? () => _goToSearch() : null,
  //       ),
  //       const SizedBox(height: 10),
  //       if (stillLoading && shownDoctors.isEmpty) ...[
  //         const _TopDoctorSkeletonCard(),
  //         const SizedBox(height: 8),
  //         const _TopDoctorSkeletonCard(),
  //       ] else if (shownDoctors.isEmpty)
  //         const _EmptyNote('No top rated doctors available')
  //       else
  //         ...shownDoctors.map(
  //           (doctor) => Padding(
  //             padding: const EdgeInsets.only(bottom: 8),
  //             child: _TopDoctorCard(
  //               doctor: doctor,
  //               cardRating: _clinicRatings[doctor.doctorId] ?? doctor.rating,
  //               onTap: () => _goToBook(doctor),
  //             ),
  //           ),
  //         ),
  //     ],
  //   );
  // }
  Widget _buildTopRatedDoctorsSection(
    List<DoctorDetails> doctors,
    bool isLoading,
  ) {
    final rated =
        doctors
            .where(
              (d) =>
                  d.doctorId != null &&
                  (d.rating ?? 0) >= 3.5 &&
                  (d.reviewCount ?? 0) >= 3,
            )
            .toList()
          ..sort((a, b) => (b.rating ?? 0).compareTo(a.rating ?? 0));

    final hasMore = rated.length > 6;
    final shownDoctors = rated.take(6).toList();
    final stillLoading = isLoading;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionTitle(
          'Top Rated Doctors',
          action: hasMore ? 'Show all' : null,
          onAction: hasMore ? () => _goToSearch() : null,
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: stillLoading && shownDoctors.isEmpty
              ? ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: 3,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, __) => const _TopDoctorSkeletonCard(),
                )
              : shownDoctors.isEmpty
              ? const _EmptyNote('No top rated doctors available')
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: shownDoctors.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (_, i) {
                    final doctor = shownDoctors[i];
                    return _TopDoctorCard(
                      doctor: doctor,
                      cardRating:
                          _clinicRatings[doctor.doctorId] ?? doctor.rating,
                      onTap: () => _goToBook(doctor),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loginState = ref.watch(patientLoginViewModelProvider);
    final doctorsState = ref.watch(doctorsViewModelProvider);
    final name = loginState.name ?? 'there';
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17
        ? 'Good Afternoon 👋'
        : 'Good Evening 👋';

    // Any new booking from any screen → refresh so upcoming section is current
    // and watchClinics starts for the new clinic if it's a walk-in today.
    ref.listen<AppointmentState>(appointmentViewModelProvider, (prev, next) {
      if (next.isSuccess &&
          next.bookingResponse != null &&
          next.bookingResponse != prev?.bookingResponse) {
        _didFetch = false;
        _ensurePatientIdAndFetch();
      }
    });

    return Scaffold(
      backgroundColor: kPageBg,
      body: RefreshIndicator(
        color: kPrimary,
        strokeWidth: 2,
        onRefresh: () async {
          _didFetch = false;
          await _ensurePatientIdAndFetch();
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(color: kPageBg),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _fade(
                          0,
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      greeting,
                                      style: const TextStyle(
                                        color: kTextSecondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      name,
                                      style: const TextStyle(
                                        color: kTextPrimary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    GestureDetector(
                                      onTap: _openLocationPicker,
                                      child: Container(
                                        constraints: const BoxConstraints(
                                          maxWidth: 140,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: _neoBox(
                                          radius: 20,
                                          pressed: true,
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(
                                              Icons.location_on_rounded,
                                              color: kPrimary,
                                              size: 10,
                                            ),
                                            const SizedBox(width: 3),
                                            if (!_locationLoaded)
                                              _Shimmer(width: 60, height: 8)
                                            else
                                              Flexible(
                                                child: Text(
                                                  _location,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  maxLines: 1,
                                                  style: const TextStyle(
                                                    color: kPrimary,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            const SizedBox(width: 2),
                                            const Icon(
                                              Icons.keyboard_arrow_down,
                                              color: kPrimary,
                                              size: 12,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              _HeaderBtn(
                                icon: Icons.notifications_outlined,
                                badge: true,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsScreen(),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SliverPadding(
              padding: const EdgeInsets.fromLTRB(14, 6, 14, 90),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // ── Hero booking card ─────────────────────────────
                  _fade(1, _HeroBookCard(onTap: () => widget.onTabChange(1))),
                  const SizedBox(height: 18),

                  _fade(
                    2,
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _SectionTitle('Quick Actions'),
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.calendar_month_rounded,
                                label: 'Appointments',
                                color: kPrimary,
                                onTap: () => widget.onTabChange(2),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.group_add_rounded,
                                label: 'Family',
                                color: kPurple,
                                onTap: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const FamilyMembersScreen(),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _QuickTile(
                                icon: Icons.medical_information_rounded,
                                label: 'Records',
                                color: kWarning,
                                onTap: () => widget.onTabChange(3),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  _fade(3, _buildAppointmentsSection()),
                  const SizedBox(height: 10),

                  _fade(
                    4,
                    _buildSpecialtiesSection(
                      doctorsState.doctors,
                      doctorsState.isLoading,
                    ),
                  ),
                  const SizedBox(height: 18),

                  _fade(
                    5,
                    _buildTopRatedDoctorsSection(
                      doctorsState.doctors,
                      doctorsState.isLoading,
                    ),
                  ),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  LOCATION SHEET
// ════════════════════════════════════════════════════════════════════
const List<String> _allCities = [
  'Bengaluru, IN',
  'Mumbai, IN',
  'Delhi, IN',
  'Hyderabad, IN',
  'Pune, IN',
  'Chennai, IN',
  'Kolkata, IN',
  'Ahmedabad, IN',
  'Jaipur, IN',
  'Surat, IN',
  'Lucknow, IN',
  'Kanpur, IN',
  'Nagpur, IN',
  'Indore, IN',
  'Thane, IN',
  'Bhopal, IN',
  'Visakhapatnam, IN',
  'Patna, IN',
  'Vadodara, IN',
  'Ghaziabad, IN',
  'Ludhiana, IN',
  'Agra, IN',
  'Nashik, IN',
  'Faridabad, IN',
  'Meerut, IN',
  'Rajkot, IN',
  'Varanasi, IN',
  'Srinagar, IN',
  'Aurangabad, IN',
  'Dhanbad, IN',
  'Amritsar, IN',
  'Navi Mumbai, IN',
  'Coimbatore, IN',
  'Madurai, IN',
  'Vijayawada, IN',
  'Guwahati, IN',
  'Chandigarh, IN',
  'Hubli, IN',
  'Mysuru, IN',
  'Tiruchirappalli, IN',
];

class _LocationSheet extends StatefulWidget {
  final String currentLocation;
  final ValueChanged<String> onSelected;
  const _LocationSheet({
    required this.currentLocation,
    required this.onSelected,
  });
  @override
  State<_LocationSheet> createState() => _LocationSheetState();
}

class _LocationSheetState extends State<_LocationSheet> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  bool _isLoadingGPS = false;
  bool _isSearching = false;

  static const _apiKey = 'AIzaSyDTRL5VzQ9UAwsCB9uCbSNj5wZasYHjFKA';

  // predictions from Google Places
  List<Map<String, dynamic>> _predictions = [];
  // fallback static list when search is empty
  List<String> _staticSuggestions = _allCities;

  bool get _hasQuery => _ctrl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _ctrl.addListener(_onType);
  }

  @override
  void dispose() {
    _ctrl.removeListener(_onType);
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _onType() {
    final q = _ctrl.text.trim();
    if (q.isEmpty) {
      setState(() {
        _predictions = [];
        _staticSuggestions = _allCities;
      });
      return;
    }
    // also filter static list as fallback
    setState(() {
      _staticSuggestions = _allCities
          .where((c) => c.toLowerCase().contains(q.toLowerCase()))
          .toList();
    });
    _fetchPredictions(q);
  }

  Future<void> _fetchPredictions(String query) async {
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:in'
        '&language=en'
        '&types=(cities)' // only city-level results
        '&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
        });
      } else {
        debugPrint('Places status: ${data['status']}');
        setState(() => _predictions = []);
      }
    } catch (e) {
      debugPrint('Places error: $e');
      setState(() => _predictions = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _pick(String loc) {
    widget.onSelected(loc);
    Navigator.pop(context);
  }

  Future<void> _useGPS() async {
    setState(() => _isLoadingGPS = true);
    try {
      final current = await LocationService.getCurrentAddress();
      if (!mounted) return;
      final hasIssue =
          current.toLowerCase().contains('location disabled') ||
          current.toLowerCase().contains('permission');
      widget.onSelected(current);
      if (!hasIssue) {
        await LocationStorage.saveLocation(current, isManual: false);
        Navigator.pop(context);
      } else {
        setState(() => _isLoadingGPS = false);
        _snack();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingGPS = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to detect location')),
      );
    }
  }

  void _snack() {
    final isWindows =
        !kIsWeb && defaultTargetPlatform == TargetPlatform.windows;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isWindows
              ? 'Enable Windows location services'
              : 'Enable phone location services',
        ),
        action: SnackBarAction(
          label: 'Settings',
          onPressed: () => Geolocator.openLocationSettings(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: kBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: kPrimary,
                      size: 17,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Choose Location',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                          ),
                        ),
                        if (widget.currentLocation.isNotEmpty)
                          Text(
                            'Current: ${widget.currentLocation}',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7F8FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder),
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // ── Search field ─────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  textInputAction: TextInputAction.done,
                  style: const TextStyle(
                    color: Color(0xFF1A1D2E),
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search city or place…',
                    hintStyle: const TextStyle(color: kTextMuted, fontSize: 13),
                    prefixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(11),
                            child: SizedBox(
                              width: 15,
                              height: 15,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: kPrimary,
                              ),
                            ),
                          )
                        : const Icon(
                            Icons.search_rounded,
                            color: kTextMuted,
                            size: 17,
                          ),
                    suffixIcon: _ctrl.text.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              _ctrl.clear();
                              _focus.requestFocus();
                            },
                            child: const Icon(
                              Icons.clear_rounded,
                              color: kTextMuted,
                              size: 15,
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                  ),
                  onSubmitted: (val) {
                    final v = val.trim();
                    if (v.isEmpty) return;
                    if (_predictions.isNotEmpty) {
                      _pick(_predictions.first['description'] ?? v);
                    } else if (_staticSuggestions.isNotEmpty) {
                      _pick(_staticSuggestions.first);
                    } else {
                      _pick(v);
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── GPS button ───────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _isLoadingGPS ? null : _useGPS,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: kPrimaryLight.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kPrimary.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: _isLoadingGPS
                            ? const Padding(
                                padding: EdgeInsets.all(7),
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(
                                Icons.my_location_rounded,
                                color: Colors.white,
                                size: 15,
                              ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isLoadingGPS
                                  ? 'Detecting…'
                                  : 'Use Current Location',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: kTextPrimary,
                              ),
                            ),
                            const Text(
                              'Auto-detect via GPS',
                              style: TextStyle(fontSize: 10, color: kTextMuted),
                            ),
                          ],
                        ),
                      ),
                      if (!_isLoadingGPS)
                        const Icon(
                          Icons.chevron_right_rounded,
                          color: kPrimary,
                          size: 17,
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Clear location ───────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: () async {
                  await LocationStorage.clearLocation();
                  if (!mounted) return;
                  widget.onSelected('');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Location cache cleared')),
                  );
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(
                        Icons.delete_outline_rounded,
                        size: 15,
                        color: kTextMuted,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Clear Saved Location',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // ── Section label ────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      !_hasQuery
                          ? 'POPULAR CITIES'
                          : _predictions.isNotEmpty
                          ? 'SUGGESTIONS'
                          : 'RESULTS',
                      style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                        color: kTextMuted,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider(color: kBorder, height: 1)),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ── Results list ─────────────────────────────────────────
            Flexible(
              child: _hasQuery && _predictions.isNotEmpty
                  // Google Places predictions
                  ? ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _predictions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final p = _predictions[i];
                        final mainText =
                            p['structured_formatting']?['main_text'] ??
                            p['description'] ??
                            '';
                        final secondText =
                            p['structured_formatting']?['secondary_text'] ?? '';
                        final fullDesc = p['description'] ?? mainText;
                        return GestureDetector(
                          onTap: () => _pick(fullDesc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: kPrimaryLight,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: const Icon(
                                    Icons.location_on_rounded,
                                    color: kPrimary,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        mainText,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: kTextPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (secondText.isNotEmpty) ...[
                                        const SizedBox(height: 1),
                                        Text(
                                          secondText,
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: kTextMuted,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.north_west_rounded,
                                  color: kBorder,
                                  size: 14,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  // Static / filtered city list
                  : _staticSuggestions.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 28,
                            color: kTextMuted,
                          ),
                          SizedBox(height: 6),
                          Text(
                            'No cities found',
                            style: TextStyle(color: kTextMuted, fontSize: 12),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
                      itemCount: _staticSuggestions.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kBorder, height: 1),
                      itemBuilder: (_, i) {
                        final loc = _staticSuggestions[i];
                        final isActive = loc == widget.currentLocation;
                        return GestureDetector(
                          onTap: () => _pick(loc),
                          child: Container(
                            color: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 9),
                            child: Row(
                              children: [
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: isActive
                                        ? kPrimary
                                        : const Color(0xFFF7F8FA),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    isActive
                                        ? Icons.location_on_rounded
                                        : Icons.location_city_rounded,
                                    color: isActive ? Colors.white : kTextMuted,
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    loc,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isActive
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: isActive ? kPrimary : kTextPrimary,
                                    ),
                                  ),
                                ),
                                if (isActive)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: kPrimaryLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: const Text(
                                      'Active',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: kPrimary,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: kBorder,
                                    size: 15,
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HERO BOOK CARD
//  Flat teal banner that replaces the old "highlighted quick action" tile.
//  Two soft decorative circles give it depth without shadows/gradients.
// ════════════════════════════════════════════════════════════════════
class _HeroBookCard extends StatelessWidget {
  final VoidCallback onTap;
  const _HeroBookCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: kPrimary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -20,
            top: -26,
            child: Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.10),
              ),
            ),
          ),
          Positioned(
            right: 26,
            bottom: -34,
            child: Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.08),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Feeling unwell?',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: 210,
                child: Text(
                  'Book a doctor and skip the waiting room queue.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 12,
                    height: 1.3,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: onTap,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Book appointment',
                        style: TextStyle(
                          color: kPrimaryDark,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(width: 6),
                      Icon(
                        Icons.arrow_forward_rounded,
                        color: kPrimaryDark,
                        size: 14,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  HEADER BUTTON
// ════════════════════════════════════════════════════════════════════
// When `badge: true`, the button watches `notificationProvider` and shows the
// unread count as a numeric badge. The bell icon also performs a periodic
// shake animation while there are unread notifications — borrowed from the
// Instagram/Practo header pattern — and falls silent once everything is read.
class _HeaderBtn extends ConsumerStatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool badge;
  const _HeaderBtn({
    required this.icon,
    required this.onTap,
    this.badge = false,
  });

  @override
  ConsumerState<_HeaderBtn> createState() => _HeaderBtnState();
}

class _HeaderBtnState extends ConsumerState<_HeaderBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shake;

  @override
  void initState() {
    super.initState();
    // ~3s cycle. The actual shake plays in the first ~25% of the timeline
    // (a TweenSequence wobble), the remaining ~75% is a flat 0 hold so the
    // bell pulses every few seconds instead of wobbling continuously — same
    // cadence Instagram uses for its activity bell.
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: 0.25), weight: 4),
      TweenSequenceItem(tween: Tween(begin: 0.25, end: -0.25), weight: 6),
      TweenSequenceItem(tween: Tween(begin: -0.25, end: 0.18), weight: 6),
      TweenSequenceItem(tween: Tween(begin: 0.18, end: -0.12), weight: 5),
      TweenSequenceItem(tween: Tween(begin: -0.12, end: 0.0), weight: 4),
      TweenSequenceItem(tween: ConstantTween(0.0), weight: 75),
    ]).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Start/stop the loop based on unread count. Run after the current frame
  // so we don't mutate animation state from inside build().
  void _syncAnimation(int unread) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (unread > 0 && !_ctrl.isAnimating) {
        _ctrl.repeat();
      } else if (unread == 0 && _ctrl.isAnimating) {
        _ctrl.stop();
        _ctrl.value = 0;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final unread = widget.badge
        ? ref.watch(notificationProvider).where((n) => !n.isRead).length
        : 0;
    _syncAnimation(unread);

    return GestureDetector(
      onTap: widget.onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: _neoBox(radius: 10),
            alignment: Alignment.center,
            child: AnimatedBuilder(
              animation: _shake,
              builder: (_, child) => Transform.rotate(
                angle: _shake.value,
                // Pivot from the top so the bell swings like it's hanging.
                alignment: Alignment.topCenter,
                child: child,
              ),
              child: Icon(
                widget.icon,
                color: const Color(0xFFE53935),
                size: 20,
              ),
            ),
          ),
          if (unread > 0)
            Positioned(
              right: -3,
              top: -3,
              child: Container(
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: kWarning,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                alignment: Alignment.center,
                child: Text(
                  unread > 99 ? '99+' : '$unread',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    height: 1.0,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SECTION TITLE
// ════════════════════════════════════════════════════════════════════
class _SectionTitle extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionTitle(this.title, {this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 3,
            height: 15,
            decoration: BoxDecoration(
              color: kPrimary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 7),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
      if (action != null)
        GestureDetector(
          onTap: onAction,
          child: Text(
            action!,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: kPrimary,
            ),
          ),
        ),
    ],
  );
}

// ════════════════════════════════════════════════════════════════════
//  QUICK TILE
//  Simple flat icon + label tile — replaces the old animated "highlighted"
//  quick action card now that booking has its own hero banner above.
// ════════════════════════════════════════════════════════════════════
class _QuickTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _QuickTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
        decoration: _neoBox(radius: 14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 17),
            ),
            const SizedBox(height: 7),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  EMPTY NOTE
// ════════════════════════════════════════════════════════════════════
class _EmptyNote extends StatelessWidget {
  final String message;
  const _EmptyNote(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
    decoration: BoxDecoration(
      color: kPrimaryLight.withOpacity(0.4),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kPrimary.withOpacity(0.15)),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.calendar_today_rounded, size: 13, color: kPrimary),
        const SizedBox(width: 6),
        Text(
          message,
          style: const TextStyle(fontSize: 12, color: kTextSecondary),
        ),
      ],
    ),
  );
}

// // ════════════════════════════════════════════════════════════════════
// //  TOP DOCTOR CARD
// // ════════════════════════════════════════════════════════════════════
// class _TopDoctorCard extends StatelessWidget {
//   final DoctorDetails doctor;
//   final double? cardRating;
//   final VoidCallback onTap;
//   const _TopDoctorCard({required this.doctor, required this.onTap, this.cardRating});

//   @override
//   Widget build(BuildContext context) {
//     final name = doctor.name?.trim();
//     final spec = doctor.specialization?.trim();
//     final clinic = doctor.clinicName?.trim();
//     final rating = (cardRating != null && cardRating! > 0) ? cardRating : null;

//     return GestureDetector(
//       onTap: onTap,
//       child: Container(
//         padding: const EdgeInsets.all(12),
//         decoration: _neoBox(radius: 12),
//         child: Row(
//           children: [
//             _doctorAvatar(spec, size: 42),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(
//                     'Dr. ${name?.isNotEmpty == true ? name : 'Doctor'}',
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: const TextStyle(
//                       fontSize: 13,
//                       fontWeight: FontWeight.w700,
//                       color: kTextPrimary,
//                     ),
//                   ),
//                   if (spec != null && spec.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       spec,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 11,
//                         color: kTextSecondary,
//                       ),
//                     ),
//                   ],
//                   if (clinic != null && clinic.isNotEmpty) ...[
//                     const SizedBox(height: 2),
//                     Text(
//                       clinic,
//                       maxLines: 1,
//                       overflow: TextOverflow.ellipsis,
//                       style: const TextStyle(
//                         fontSize: 10,
//                         color: kTextMuted,
//                       ),
//                     ),
//                   ],
//                 ],
//               ),
//             ),
//             if (rating != null)
//               Container(
//                 padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
//                 decoration: BoxDecoration(
//                   color: kAmberLight,
//                   borderRadius: BorderRadius.circular(8),
//                   border: Border.all(color: kWarning.withValues(alpha: 0.25)),
//                 ),
//                 child: Row(
//                   mainAxisSize: MainAxisSize.min,
//                   children: [
//                     const Icon(Icons.star_rounded, size: 12, color: kWarning),
//                     const SizedBox(width: 4),
//                     Text(
//                       rating.toStringAsFixed(1),
//                       style: const TextStyle(
//                         fontSize: 10,
//                         fontWeight: FontWeight.w700,
//                         color: kWarning,
//                       ),
//                     ),
//                   ],
//                 ),
//               ),
//           ],
//         ),
//       ),
//     );
//   }
// }

// class _TopDoctorSkeletonCard extends StatelessWidget {
//   const _TopDoctorSkeletonCard();

//   @override
//   Widget build(BuildContext context) => Container(
//         padding: const EdgeInsets.all(12),
//         decoration: _neoBox(radius: 12),
//         child: Row(
//           children: const [
//             _Shimmer(width: 42, height: 42),
//             SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   _Shimmer(width: 140, height: 11),
//                   SizedBox(height: 5),
//                   _Shimmer(width: 100, height: 10),
//                   SizedBox(height: 5),
//                   _Shimmer(width: 120, height: 9),
//                 ],
//               ),
//             ),
//             SizedBox(width: 8),
//             _Shimmer(width: 32, height: 22),
//           ],
//         ),
//       );
// }

class _TopDoctorCard extends StatelessWidget {
  final DoctorDetails doctor;
  final double? cardRating;
  final VoidCallback onTap;
  const _TopDoctorCard({
    required this.doctor,
    required this.onTap,
    this.cardRating,
  });

  @override
  Widget build(BuildContext context) {
    final name = doctor.name?.trim();
    final spec = doctor.specialization?.trim();
    final rating = (cardRating != null && cardRating! > 0) ? cardRating : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 132,
        padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
        decoration: _neoBox(radius: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                _doctorAvatar(spec, size: 56),
                if (rating != null)
                  Positioned(
                    right: -8,
                    top: -8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: kWarning,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            size: 10,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              doctorDisplayName(name),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            if (spec != null && spec.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                spec,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryDark,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TopDoctorSkeletonCard extends StatelessWidget {
  const _TopDoctorSkeletonCard();

  @override
  Widget build(BuildContext context) => Container(
    width: 132,
    padding: const EdgeInsets.fromLTRB(12, 16, 12, 14),
    decoration: _neoBox(radius: 16),
    child: const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(child: _Shimmer(width: 56, height: 56)),
        SizedBox(height: 10),
        _Shimmer(width: 90, height: 11),
        SizedBox(height: 6),
        _Shimmer(width: 70, height: 9),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  QUEUE PROGRESS RING
//  Draws the NOW circle's outline as a progress arc: a faint full track
//  plus a solid sweep covering serving/total of the circle, starting at
//  12 o'clock and filling clockwise as the queue advances.
// ════════════════════════════════════════════════════════════════════
class _QueueRingPainter extends CustomPainter {
  final double progress; // 0.0 – 1.0
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _QueueRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    this.strokeWidth = 3,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final center = rect.center;
    final radius = (size.shortestSide - strokeWidth) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    if (progress <= 0) return;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2, // start at 12 o'clock
      2 * math.pi * progress.clamp(0.0, 1.0),
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_QueueRingPainter old) =>
      old.progress != progress ||
      old.color != color ||
      old.trackColor != trackColor ||
      old.strokeWidth != strokeWidth;
}

// ── "Your turn" pulse ──────────────────────────────────────────────
// Matches _ArrivedBlinkBadge on the doctor home screen so the same motion
// means the same thing on both sides: 850ms, reversing, scale + glow.
const _kTurnPulsePeriod = Duration(milliseconds: 850);

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT CARD
// ════════════════════════════════════════════════════════════════════
class _ApptCard extends StatefulWidget {
  final AppointmentList appointment;
  final bool isToday;
  final bool isNext;
  final bool doctorOffline;
  final String? queueEvent;

  /// Real current_serving from socket events — used for skipped patients where
  /// the SP echoes their own token instead of the actual serving number.
  final int? currentServingOverride;

  /// Called when the patient taps "I've Arrived at Clinic" after being
  /// skipped. Returns true on success so the card can show a confirmation.
  final Future<bool> Function()? onMarkArrived;

  /// Called when the patient confirms cancelling this appointment. The parent
  /// owns the confirm dialog and the refresh, matching the appointments screen.
  final VoidCallback? onCancel;
  const _ApptCard({
    super.key,
    required this.appointment,
    this.isToday = false,
    this.isNext = false,
    this.doctorOffline = false,
    this.queueEvent,
    this.currentServingOverride,
    this.onMarkArrived,
    this.onCancel,
  });
  @override
  State<_ApptCard> createState() => _ApptCardState();
}

class _ApptCardState extends State<_ApptCard> with TickerProviderStateMixin {
  /// Drives the NOW ring's sweep so it glides to the new fraction when the
  /// queue advances instead of snapping.
  late AnimationController _ringCtrl;
  late Animation<double> _ringSweep;

  /// Drives the whole-card "your turn" pulse: a continuous scale + glow
  /// breathe, the same motion the doctor screen uses on a recall badge.
  late AnimationController _turnCtrl;

  /// True once the doctor has recalled this patient (they were called, missed
  /// it, and are being called again), which swaps the glow from teal to amber.
  bool _isRecallAlert = false;

  bool _arrivedSending = false;
  bool _arrivedSent = false;

  /// serving/total as a 0–1 fraction, guarding against a null or zero total.
  double get _queueProgress {
    final appt = widget.appointment;
    final total = appt.totalQueue ?? 0;
    if (total <= 0) return 0;
    final serving = widget.currentServingOverride ?? appt.currentServing ?? 0;
    return (serving / total).clamp(0.0, 1.0);
  }

  @override
  void initState() {
    super.initState();
    // Fill the ring from empty to the current fraction on first paint.
    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _ringSweep = Tween<double>(
      begin: 0,
      end: _queueProgress,
    ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic));
    _ringCtrl.forward();

    // Continuous breathe, mirroring _ArrivedBlinkBadge on the doctor home
    // screen (850ms, repeat(reverse: true), scale + glow). The doctor sees
    // that pulse on the patient they need to recall; the patient sees the same
    // pulse on the card they need to act on, so one motion means "you're up"
    // on both sides of the app. It keeps breathing until the turn is over.
    _turnCtrl = AnimationController(vsync: this, duration: _kTurnPulsePeriod);

    // Mounting straight into a live turn means the patient is seeing this card
    // for the first time in that state — opening the app on a call, or
    // returning to this tab — so it buzzes. Repeat buzzing on every socket
    // refresh is prevented by the ValueKey at the call site, which keeps this
    // State alive across refetches instead of remounting it.
    if (widget.appointment.isMyTurn == true) _startTurnPulse();
  }

  /// Buzz pattern marking the moment the turn arrives. Deliberately much
  /// louder than the single taps used for ordinary button feedback: this is
  /// the one alert the patient cannot afford to miss, and it has to carry
  /// through a pocket or a bag. Four heavy pulses for a first call, six for a
  /// recall — the extra length is what makes "again" recognisable without
  /// looking at the screen.
  void _turnBuzz({required bool isRecall}) {
    // ~110ms apart reads as one continuous burst rather than separate taps.
    const gap = Duration(milliseconds: 110);
    final pulses = isRecall ? 6 : 4;

    for (var i = 0; i < pulses; i++) {
      Future.delayed(gap * i, () {
        if (!mounted) return;
        // Alternate heavy/medium so the burst has texture instead of being a
        // flat rumble the hand stops noticing partway through.
        if (i.isEven) {
          HapticFeedback.heavyImpact();
        } else {
          HapticFeedback.mediumImpact();
        }
      });
    }
  }

  /// Fires one heavy pulse per breathe cycle so the phone keeps buzzing for
  /// as long as the turn stays active, instead of going silent after the
  /// initial burst. Hooked to _turnCtrl's forward-start so it repeats in
  /// lockstep with the visible pulse rather than running its own timer.
  void _onTurnCycle(AnimationStatus status) {
    if (status == AnimationStatus.forward) {
      HapticFeedback.heavyImpact();
    }
  }

  /// Starts (or re-marks) the continuous pulse and buzzes once. Called when
  /// the turn arrives and again on each doctor recall; the recall only flips
  /// the glow colour, leaving the controller running so the breathe never
  /// visibly restarts.
  void _startTurnPulse({bool isRecall = false}) {
    _turnBuzz(isRecall: isRecall);
    if (_isRecallAlert != isRecall) {
      setState(() => _isRecallAlert = isRecall);
    }
    if (!_turnCtrl.isAnimating) {
      _turnCtrl.addStatusListener(_onTurnCycle);
      _turnCtrl.repeat(reverse: true);
    }
  }

  /// True only for a genuine doctor recall: the serving number actually moved
  /// AND now points at this patient's own token.
  ///
  /// Without the "points at my token" half, this returned true every time the
  /// queue advanced for anyone else — and since the socket refetches the whole
  /// appointment list on every event, that buzzed the phone over and over
  /// while the patient simply sat on their turn.
  bool _isRecallOf(
    _ApptCard old,
    AppointmentList prev,
    AppointmentList curr,
  ) {
    final myToken = curr.myQueueNumber ?? curr.queueNumber;
    if (myToken == null) return false;

    // Socket override wins when present — it lands before the refetch does.
    final prevServing = old.currentServingOverride ?? prev.currentServing;
    final currServing = widget.currentServingOverride ?? curr.currentServing;

    return currServing != prevServing && currServing == myToken;
  }

  /// Turn is over (doctor completed or moved on) — settle back to a still card.
  void _stopTurnPulse() {
    if (!_turnCtrl.isAnimating) return;
    _turnCtrl.removeStatusListener(_onTurnCycle);
    _turnCtrl.stop();
    _turnCtrl.value = 0;
    if (_isRecallAlert) setState(() => _isRecallAlert = false);
  }

  Future<void> _handleMarkArrived() async {
    if (widget.onMarkArrived == null || _arrivedSending || _arrivedSent) return;
    setState(() => _arrivedSending = true);
    final ok = await widget.onMarkArrived!();
    if (!mounted) return;
    setState(() {
      _arrivedSending = false;
      if (ok) _arrivedSent = true;
    });
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not notify the clinic. Please try again.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  void didUpdateWidget(_ApptCard old) {
    super.didUpdateWidget(old);
    final prev = old.appointment;
    final curr = widget.appointment;
    if (curr.currentServing != prev.currentServing ||
        curr.totalQueue != prev.totalQueue ||
        curr.isMyTurn != prev.isMyTurn) {
      // Sweep the ring from wherever it is now to the new fraction.
      _ringSweep = Tween<double>(
        begin: _ringSweep.value,
        end: _queueProgress,
      ).animate(CurvedAnimation(parent: _ringCtrl, curve: Curves.easeOutCubic));
      _ringCtrl.forward(from: 0);
    }
    // Turn just arrived → start the pulse.
    if (curr.isMyTurn == true && prev.isMyTurn != true) {
      _startTurnPulse();
    }
    // Doctor recall: the turn was already true and the doctor called this
    // patient again. isMyTurn never flips, so the check above can't catch it.
    //
    // The serving number must have changed AND landed back on this patient's
    // own token — that combination only happens on a real recall. Reacting to
    // any serving change would buzz every time the queue moved for someone
    // else, because the socket refetches the whole list on every event.
    else if (curr.isMyTurn == true &&
        prev.isMyTurn == true &&
        _isRecallOf(old, prev, curr)) {
      _startTurnPulse(isRecall: true);
    }
    // Turn is over → stop pulsing.
    else if (curr.isMyTurn != true && prev.isMyTurn == true) {
      _stopTurnPulse();
    }
  }

  @override
  void dispose() {
    _ringCtrl.dispose();
    _turnCtrl.dispose();
    super.dispose();
  }

  // Text uses the neutral ink rather than a tint of the background, so the
  // message stays legible and the colour is carried by the fill, icon and
  // border instead of a same-hue-on-same-hue pairing.
  Widget _buildQueueBanner(String event, {Widget? trailing}) {
    final (
      Color bg,
      Color fg,
      Color iconColor,
      Color border,
      IconData icon,
      String text,
    ) = switch (event) {
      'queue_started' => (
        kGreenLight,
        kBannerInk,
        kSuccessDark,
        kSuccess.withOpacity(0.35),
        Icons.play_circle_fill_rounded,
        'Queue is live',
      ),
      'queue_paused' => (
        kAmberLight,
        kBannerInk,
        kWarningDark,
        kWarning.withOpacity(0.35),
        Icons.pause_circle_outline_rounded,
        'Queue paused temporarily',
      ),
      'queue_paused_emergency' => (
        kRedLight,
        kBannerInk,
        kErrorDark,
        kError.withOpacity(0.35),
        Icons.warning_amber_rounded,
        'Emergency break • queue on hold',
      ),
      'queue_stopped' => (
        const Color(0xFFF7F8FA),
        kTextSecondary,
        kTextMuted,
        kBorder,
        Icons.stop_circle_outlined,
        'Queue stopped for today',
      ),
      _ => (
        kPrimaryLight,
        kBannerInk,
        kPrimary,
        kPrimary.withOpacity(0.2),
        Icons.info_outline_rounded,
        event,
      ),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(13)),
        border: Border(bottom: BorderSide(color: border)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 15, color: iconColor),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: fg,
              ),
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: 8), trailing],
        ],
      ),
    );
  }

  String _fmtDate(String? raw) {
    if (raw == null) return '—';
    final dt = DateTime.tryParse(raw);
    return dt == null ? raw : DateFormat('d MMM yyyy').format(dt);
  }

  String _fmtClockTime(String? raw) {
    final parsed = _timeTodayFromRaw(raw);
    if (parsed != null) return DateFormat('h:mm a').format(parsed);
    final value = raw?.trim();
    return value == null || value.isEmpty ? '--' : value;
  }

  @override
  Widget build(BuildContext context) {
    final appt = widget.appointment;
    final name = appt.doctorName ?? 'Doctor';
    final spec = appt.specialization ?? '';
    final dateStr = _fmtDate(appt.appointmentDate);
    final isSlot = appt.bookingType == 2;
    final timeStr = isSlot
        ? () {
            final start = _fmtClockTime(appt.startTime);
            final end = _fmtClockTime(appt.endTime);
            return (end.isNotEmpty && end != '--') ? '$start – $end' : start;
          }()
        : 'Est. ${_fmtClockTime(appt.estimatedArrivalTime)}';

    final myToken = appt.myQueueNumber ?? appt.queueNumber;
    final totalQ = appt.totalQueue;
    final isSkipped = appt.queueState?.toLowerCase() == 'skipped';
    final isMyTurn = appt.isMyTurn ?? false;
    // Socket override is always fresher than the SP value.
    // Sanitize: when no socket data is available yet, the SP echoes the
    // patient's own queue_number as current_serving (SP bug). Discard it so
    // we show nothing rather than a misleading value.
    final rawServing = widget.currentServingOverride ?? appt.currentServing;
    final serving =
        (widget.currentServingOverride == null &&
            rawServing != null &&
            rawServing == myToken &&
            !isMyTurn)
        ? null
        : rawServing;
    // Show queue row (QUEUE NO. chip + badges) for today when token exists OR skipped.
    // The Skipped badge lives inside this row so it must show even when SP returns
    // null for my_queue_number (which happens for skipped patients).
    final showQueueSection = widget.isToday && (myToken != null || isSkipped);
    // NOW circle: hide when serving is unknown (null) to avoid showing stale/wrong data.
    final showQueue = widget.isToday && myToken != null && serving != null;

    // Derive effective queue event (socket live OR API cold-start)
    String? queueEvent = widget.queueEvent;
    if (queueEvent == null && widget.isToday && appt.bookingType == 1) {
      if (appt.queueStarted == true) queueEvent = 'queue_started';
    }
    final showBanner = widget.isToday && queueEvent != null;

    // Cancellable states mirror _canCancel in the appointments screen so both
    // surfaces offer the action on exactly the same appointments.
    final apptStatus = appt.status?.toLowerCase();
    final canCancel =
        widget.onCancel != null &&
        appt.appointmentId != null &&
        (apptStatus == 'upcoming' ||
            apptStatus == 'booked' ||
            apptStatus == 'confirmed');

    // Status badge — rides along in the queue banner when one is showing,
    // otherwise it gets its own row above the doctor block. Only the
    // actionable states get one; a plain "Today" chip said nothing the date
    // row below didn't already say, so there is no badge in that case.
    final Widget? statusBadge = isMyTurn
        // Static badge. The pulse lives on the card as a whole (see the
        // wrapper at the end of build), so animating this chip too would
        // compound into two motions at once.
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: _isRecallAlert ? kWarning : kPrimary,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.notifications_active_rounded,
                  color: Colors.white,
                  size: 12,
                ),
                SizedBox(width: 4),
                Text(
                  'Your Turn!',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : isSkipped
        ? Container(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
            decoration: BoxDecoration(
              color: kError,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.block_rounded, color: Colors.white, size: 11),
                SizedBox(width: 4),
                Text(
                  'Skipped',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          )
        : null;

    Color borderColor;
    double borderWidth;
    if (isMyTurn) {
      borderColor = kPrimary;
      borderWidth = 2;
    } else if (isSkipped) {
      borderColor = kError;
      borderWidth = 2;
    } else if (queueEvent == 'queue_paused_emergency') {
      borderColor = kError;
      borderWidth = 2;
    } else if (queueEvent == 'queue_paused') {
      borderColor = kWarning;
      borderWidth = 1.8;
    } else if (queueEvent == 'queue_started' || widget.isNext) {
      borderColor = kPrimary;
      borderWidth = 1.8;
    } else {
      borderColor = kBorder;
      borderWidth = 1;
    }

    // Built directly rather than inside an AnimatedBuilder: nothing in the
    // card body ticks every frame any more, so a per-frame rebuild would be
    // pure waste. The two things that do animate (the NOW ring sweep and the
    // "your turn" pulse) own their own builders further down.
    final card = Container(
      decoration: _neoBox(
        radius: 14,
        border: borderWidth > 1
            ? Border.all(color: borderColor, width: borderWidth)
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Queue status banner (live socket event) ──────────
          if (showBanner)
            _buildQueueBanner(
              queueEvent,
              trailing: showQueueSection ? statusBadge : null,
            ),

          // ── Doctor offline warning ───────────────────────────
          if (widget.doctorOffline)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: kWarning.withOpacity(0.12),
                // Only round top corners when no queue banner sits above this strip.
                borderRadius: showBanner
                    ? BorderRadius.zero
                    : const BorderRadius.vertical(top: Radius.circular(13)),
                border: Border(
                  bottom: BorderSide(color: kWarning.withOpacity(0.3)),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off_rounded, size: 13, color: kWarning),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '${doctorDisplayName(appt.doctorName)} has a network connection issue. Please come at your estimated time.',
                      style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: kWarning,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          // ── TOP ROW: status badge, only when no banner carries it ──
          if (showQueueSection && !showBanner && statusBadge != null) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Row(children: [const Spacer(), statusBadge]),
            ),
            // Hairline between the badge row and the doctor block.
            const Padding(
              padding: EdgeInsets.fromLTRB(12, 9, 12, 0),
              child: Divider(color: kDivider, height: 1, thickness: 1),
            ),
          ],

          // ── MAIN ROW: Avatar + Info + NOW badge ─────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Queue token takes the avatar's slot when this
                  // appointment has one; otherwise fall back to the
                  // specialty icon (slot bookings, future dates).
                  if (showQueueSection && myToken != null)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(13),
                        border: Border.all(
                          color: kPrimary.withOpacity(0.3),
                          width: 1.5,
                        ),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            'QUEUE',
                            style: TextStyle(
                              fontSize: 7,
                              fontWeight: FontWeight.w700,
                              color: kPrimaryDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            myToken.toString().padLeft(2, '0'),
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: kPurple,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    _doctorAvatar(spec, size: 48),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorDisplayName(name),
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (spec.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            spec,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              color: kTextSecondary,
                            ),
                          ),
                        ],
                        if ((appt.clinicName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on_outlined,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  appt.clinicName ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if ((appt.patientName ?? '').isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.person_outline_rounded,
                                size: 12,
                                color: kPrimary,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  appt.patientName ?? '',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),

                  // NOW badge (queue live indicator)
                  if (showQueue) ...[
                    const SizedBox(width: 10),
                    const VerticalDivider(
                      color: kDivider,
                      width: 1,
                      thickness: 1,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Plain progress ring — the circle and its text never
                        // scale, pulse or blink. Only the arc moves, and only
                        // when the queue actually advances (see _ringSweep),
                        // so the numbers stay readable at all times.
                        SizedBox(
                          width: 56,
                          height: 56,
                          child: Center(
                            child: AnimatedBuilder(
                              animation: _ringSweep,
                              builder: (context, child) => CustomPaint(
                                size: const Size(53, 53),
                                painter: _QueueRingPainter(
                                  progress: _ringSweep.value,
                                  color: kPrimary,
                                  trackColor: kPrimary.withOpacity(0.18),
                                  strokeWidth: 3,
                                ),
                                child: child,
                              ),
                              child: SizedBox(
                                width: 53,
                                height: 53,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Text(
                                      'NOW',
                                      style: TextStyle(
                                        fontSize: 8,
                                        fontWeight: FontWeight.w700,
                                        color: kTextSecondary,
                                        letterSpacing: 0.4,
                                      ),
                                    ),
                                    Text(
                                      '$serving/${totalQ ?? 0}',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                        color: kTextPrimary,
                                        height: 1.15,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        if (queueEvent == 'queue_started') ...[
                          const SizedBox(height: 4),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  color: kPrimary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              const Text(
                                'live',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: kTextSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── BOTTOM ROW: date • time, with cancel on the right ──
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: Divider(color: kDivider, height: 1, thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 7, 12, 7),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  Expanded(
                    child: Row(
                      mainAxisAlignment: canCancel
                          ? MainAxisAlignment.start
                          : MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.calendar_today_rounded,
                          size: 13,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            dateStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(width: 9),
                        const VerticalDivider(
                          color: kDivider,
                          width: 1,
                          thickness: 1,
                        ),
                        const SizedBox(width: 9),
                        const Icon(
                          Icons.access_time_rounded,
                          size: 13,
                          color: kPrimary,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            timeStr,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: kTextPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Icon-only cancel. The label is dropped to keep the row
                  // on one line, so the button carries a tooltip and a
                  // semantics label for anyone who can't read the icon.
                  if (canCancel) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: 'Cancel appointment',
                      child: GestureDetector(
                        onTap: widget.onCancel,
                        child: Semantics(
                          button: true,
                          label: 'Cancel appointment',
                          child: Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(
                              color: kRedLight,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: kError.withOpacity(0.35),
                              ),
                            ),
                            child: const Icon(
                              Icons.close_rounded,
                              size: 15,
                              color: kError,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── "I've Arrived at Clinic" — only for skipped patients ────
          if (isSkipped && widget.onMarkArrived != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
              child: (appt.isArrived == true || _arrivedSent)
                  ? Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: kPrimary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: kPrimary.withOpacity(0.25)),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            color: kPrimary,
                            size: 14,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Doctor notified — you are marked as arrived',
                            style: TextStyle(
                              color: kPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )
                  : GestureDetector(
                      onTap: _arrivedSending ? null : _handleMarkArrived,
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kError,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _arrivedSending
                            ? const SizedBox(
                                height: 16,
                                width: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.location_on_rounded,
                                    color: Colors.white,
                                    size: 15,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    "I've Arrived at Clinic",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                      ),
                    ),
            ),
        ],
      ),
    );

    if (!isMyTurn) return card;

    // "Your turn" → the card breathes on the same 850ms reversing loop the
    // doctor screen uses for its Recall button. No coloured glow: the teal
    // halo bled out around the card and read as a stray green shadow, so the
    // motion alone carries the alert. State is still visible when the card is
    // at rest via the 2px accent border and the "Your Turn!" badge.
    // The scale is 1.02 rather than the badge's 1.10 because this is a
    // full-width card — a 10% swell would shove the rows below it around.
    return AnimatedBuilder(
      animation: _turnCtrl,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.02 * _turnCtrl.value,
        child: child,
      ),
      child: card,
    );
  }
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP
//  Flat icon tile + label — no bordered wrapper, matches the mockup's
//  larger, simpler icon tiles.
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 76,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
      decoration: _neoBox(radius: 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
        ],
      ),
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  SPECIALTY CHIP SKELETON
// ════════════════════════════════════════════════════════════════════
class _SpecialtyChipSkeleton extends StatefulWidget {
  @override
  State<_SpecialtyChipSkeleton> createState() => _SpecialtyChipSkeletonState();
}

class _SpecialtyChipSkeletonState extends State<_SpecialtyChipSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
    width: 76,
    padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
    decoration: _neoBox(radius: 14),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E0),
                  Color(0xFFE2E8F0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _Shimmer(width: 40, height: 8),
      ],
    ),
  );
}

// ════════════════════════════════════════════════════════════════════
//  APPOINTMENT SKELETON CARD
// ════════════════════════════════════════════════════════════════════
class _ApptSkeletonCard extends StatefulWidget {
  const _ApptSkeletonCard();
  @override
  State<_ApptSkeletonCard> createState() => _ApptSkeletonCardState();
}

class _ApptSkeletonCardState extends State<_ApptSkeletonCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _bar({double? width, required double height}) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      width: width,
      height: height,
      margin: const EdgeInsets.only(bottom: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(5),
        gradient: LinearGradient(
          begin: Alignment(_anim.value - 1, 0),
          end: Alignment(_anim.value + 1, 0),
          colors: const [
            Color(0xFFEDF2F7),
            Color(0xFFE2E8F0),
            Color(0xFFCBD5E0),
            Color(0xFFE2E8F0),
            Color(0xFFEDF2F7),
          ],
        ),
      ),
    ),
  );

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _anim,
    builder: (_, __) => Container(
      padding: const EdgeInsets.all(12),
      decoration: _neoBox(radius: 14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFCBD5E0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _bar(width: 130, height: 13),
                _bar(width: 90, height: 10),
                const SizedBox(height: 3),
                Row(
                  children: [
                    _bar(width: 70, height: 10),
                    const SizedBox(width: 8),
                    _bar(width: 55, height: 10),
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

// ════════════════════════════════════════════════════════════════════
//  TODAY APPOINTMENT POPUP
// ════════════════════════════════════════════════════════════════════
class _TodayAppointmentPopup extends StatelessWidget {
  final AppointmentList appointment;
  const _TodayAppointmentPopup({required this.appointment});

  String _fmtTime(String? raw) {
    if (raw == null || raw.isEmpty) return '—';
    final parsed = _timeTodayFromRaw(raw);
    if (parsed != null) return DateFormat('h:mm a').format(parsed);
    final parts = raw.split(':');
    if (parts.length < 2) return raw;
    final dt = DateTime(
      2000,
      1,
      1,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1]) ?? 0,
    );
    return DateFormat('h:mm a').format(dt);
  }

  String _bookingLabel(int? type) {
    if (type == 2) return 'Slot';
    if (type == 1) return 'Queue';
    return 'Appointment';
  }

  Color _bookingColor(int? type) => type == 2 ? kInfo : kPrimary;

  @override
  Widget build(BuildContext context) {
    final appt = appointment;
    final doctorName = doctorDisplayName(appt.doctorName);
    final spec = appt.specialization ?? '';
    final clinic = appt.clinicName ?? '';
    final isQueue =
        appt.bookingType == 1 ||
        (appt.startTime == null || appt.startTime!.isEmpty);
    final timeStr = isQueue
        ? _fmtTime(appt.estimatedArrivalTime)
        : _fmtTime(appt.startTime);
    final endStr = isQueue ? null : _fmtTime(appt.endTime);
    final myToken = appt.myQueueNumber ?? appt.queueNumber;
    final serving = appt.currentServing;
    final isMyTurn = appt.isMyTurn ?? false;
    final isSkipped = appt.queueState?.toLowerCase() == 'skipped';
    final typeLabel = _bookingLabel(appt.bookingType);
    final typeColor = _bookingColor(appt.bookingType);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      backgroundColor: Colors.white,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.fromLTRB(16, 20, 48, 16),
                decoration: const BoxDecoration(
                  color: kPrimary,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Today\'s Appointment',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You have an appointment today',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _doctorAvatar('cardio', size: 48),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                doctorName,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: kTextPrimary,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (spec.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Text(
                                  spec,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: kTextSecondary,
                                  ),
                                ),
                              ],
                              if (clinic.isNotEmpty) ...[
                                const SizedBox(height: 2),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.local_hospital_outlined,
                                      size: 10,
                                      color: kTextMuted,
                                    ),
                                    const SizedBox(width: 3),
                                    Flexible(
                                      child: Text(
                                        clinic,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: kTextMuted,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: typeColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: typeColor.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            typeLabel,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: typeColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Divider(color: kBorder, height: 1),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        _InfoChip(
                          icon: Icons.access_time_rounded,
                          label: isQueue ? 'Est. Arrival' : 'Time',
                          value:
                              (endStr != null &&
                                  endStr.isNotEmpty &&
                                  endStr != '—')
                              ? '$timeStr – $endStr'
                              : timeStr,
                          color: kPrimary,
                        ),
                        if (myToken != null) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.confirmation_number_outlined,
                            label: 'Your Token',
                            value: myToken.toString().padLeft(2, '0'),
                            color: kPurple,
                          ),
                        ],
                        if (serving != null && serving > 0) ...[
                          const SizedBox(width: 8),
                          _InfoChip(
                            icon: Icons.people_alt_outlined,
                            label: 'Now Serving',
                            value: serving.toString().padLeft(2, '0'),
                            color: kInfo,
                          ),
                        ],
                      ],
                    ),
                    if (isMyTurn) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: kPrimary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.notifications_active_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'It\'s Your Turn!',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else if (isSkipped) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: kError,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.block_rounded,
                              color: Colors.white,
                              size: 15,
                            ),
                            SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'You were skipped — please contact the clinic',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if ((appt.patientName ?? '').isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          const Icon(
                            Icons.person_outline_rounded,
                            size: 12,
                            color: kTextMuted,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'For: ${appt.patientName}',
                            style: const TextStyle(
                              fontSize: 11,
                              color: kTextMuted,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          Positioned(
            top: 10,
            right: 10,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.25),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Info chip used inside today popup ─────────────────────────────
class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String label, value;
  final Color color;
  const _InfoChip({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 10, color: color),
              const SizedBox(width: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

// class _SpecialtyPillCard extends StatelessWidget {
//   final IconData icon;
//   final String label;
//   final Color color;
//   final VoidCallback onTap;
//   const _SpecialtyPillCard({
//     required this.icon,
//     required this.label,
//     required this.color,
//     required this.onTap,
//   });

//   @override
//   Widget build(BuildContext context) => GestureDetector(
//         onTap: onTap,
//         child: Container(
//           padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
//           decoration: BoxDecoration(
//             color: color.withOpacity(0.14),
//             borderRadius: BorderRadius.circular(16),
//           ),
//           child: Row(
//             children: [
//               Container(
//                 width: 34,
//                 height: 34,
//                 decoration: BoxDecoration(color: color, shape: BoxShape.circle),
//                 child: Icon(icon, color: Colors.white, size: 17),
//               ),
//               const SizedBox(width: 10),
//               Expanded(
//                 child: Text(label,
//                     maxLines: 1,
//                     overflow: TextOverflow.ellipsis,
//                     style: TextStyle(
//                         fontSize: 12.5,
//                         fontWeight: FontWeight.w700,
//                         color: color)),
//               ),
//             ],
//           ),
//         ),
//       );
// }

class _SpecialtyPillCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const _SpecialtyPillCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: _neoBox(radius: 16),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: color.withOpacity(0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 17),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SpecialtyPillSkeleton extends StatefulWidget {
  @override
  State<_SpecialtyPillSkeleton> createState() => _SpecialtyPillSkeletonState();
}

class _SpecialtyPillSkeletonState extends State<_SpecialtyPillSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    )..repeat();
    _anim = Tween<double>(
      begin: -2.0,
      end: 2.0,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    decoration: _neoBox(radius: 16),
    child: Row(
      children: [
        AnimatedBuilder(
          animation: _anim,
          builder: (_, __) => Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment(_anim.value - 1, 0),
                end: Alignment(_anim.value + 1, 0),
                colors: const [
                  Color(0xFFEDF2F7),
                  Color(0xFFE2E8F0),
                  Color(0xFFCBD5E0),
                  Color(0xFFE2E8F0),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: _Shimmer(width: 60, height: 10)),
      ],
    ),
  );
}
