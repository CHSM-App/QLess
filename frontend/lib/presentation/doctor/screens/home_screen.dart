
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qless/core/network/dio_provider.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/appointment_list.dart';
import 'package:qless/domain/models/appointment_request_model.dart';
import 'package:qless/domain/models/doctor_availability_model.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/addMedicine_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_patient_history.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';
import 'package:qless/presentation/doctor/screens/doctor_prescription_history.dart';
import 'package:qless/presentation/doctor/screens/medicine_screen.dart';
import 'package:qless/presentation/doctor/view_models/appointment_list_viewmodel.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';

// ─────────────────────────────────────────────────────────────────────────────
// DESIGN TOKENS
// ─────────────────────────────────────────────────────────────────────────────

// Page & card surfaces
const kPageBg         = Color(0xFFF8F9FB); // grey-50
const kCardBg         = Colors.white;
const kCardBorder     = Color(0xFFE2E8F0);

// Primary (teal)
const kPrimary        = Color(0xFF1D9E75);
const kPrimaryDark    = Color(0xFF0F6E56);
const kPrimaryLight   = Color(0xFFE1F5EE);
const kPrimaryLighter = Color(0xFFF0FBF8);

// Text
const kTextPrimary    = Color(0xFF0F172A);
const kTextSecondary  = Color(0xFF64748B);
const kTextMuted      = Color(0xFF94A3B8);

const kBorder         = Color(0xFFE2E8F0);
const kHairline       = Color(0xFFE2E8F0);

// Green
const kGreen          = Color(0xFF22C55E);
const kGreenDark      = Color(0xFF166534);
const kGreenLight     = Color(0xFFF0FDF4);
const kGreenBorder    = Color(0xFFBBF7D0);

// Amber
const kAmber          = Color(0xFFF59E0B);
const kAmberDark      = Color(0xFF92400E);
const kAmberLight     = Color(0xFFFEF3C7);
const kAmberBorder    = Color(0xFFFDE68A);

// Red
const kRed            = Color(0xFFEF4444);
const kRedDark        = Color(0xFF7F1D1D);
const kRedLight       = Color(0xFFFEE2E2);
const kRedBorder      = Color(0xFFFECACA);

// Purple
const kPurple         = Color(0xFF8B5CF6);
const kPurpleDark     = Color(0xFF4C1D95);
const kPurpleLight    = Color(0xFFEDE9FE);
const kPurpleBorder   = Color(0xFFDDD6FE);

// Blue (waiting stat)
const kBlueLight      = Color(0xFFEFF6FF);
const kBlueBorder     = Color(0xFFBFDBFE);
const kBlueDark       = Color(0xFF1E40AF);

// No shadows, no gradients
const List<BoxShadow> kNoShadow = [];

int? _minutesFromTimeString(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  final value = raw.trim();
  final dt = DateTime.tryParse(value);
  if (dt != null) {
    final local = dt.isUtc ? dt.toLocal() : dt;
    return local.hour * 60 + local.minute;
  }

  final match = RegExp(r'(\d{1,2}):(\d{2})\s*([AP]M)?',
          caseSensitive: false)
      .firstMatch(value);
  if (match == null) return null;

  var hour = int.tryParse(match.group(1) ?? '');
  final minute = int.tryParse(match.group(2) ?? '');
  if (hour == null || minute == null) return null;

  final suffix = match.group(3)?.toUpperCase();
  if (suffix == 'PM' && hour != 12) hour += 12;
  if (suffix == 'AM' && hour == 12) hour = 0;
  return hour * 60 + minute;
}

bool _hasSessionEndedToday(String? endTime) {
  final endMinutes = _minutesFromTimeString(endTime);
  if (endMinutes == null) return false;
  final now = DateTime.now();
  return now.hour * 60 + now.minute >= endMinutes;
}

// ─────────────────────────────────────────────────────────────────────────────
// QUEUE HOME PAGE
// ─────────────────────────────────────────────────────────────────────────────

class QueueHomePage extends ConsumerStatefulWidget {
  const QueueHomePage({super.key});

  @override
  ConsumerState<QueueHomePage> createState() => _QueueHomePageState();
}

class _Tip {
  final String emoji;
  final String title;
  final String body;
  const _Tip(this.emoji, this.title, this.body);
}

const List<_Tip> _kDoctorTips = [
  _Tip('⏸', 'Pause Queue',
      'Tap Pause anytime to take a quick break — patients see the live status update instantly.'),
  _Tip('⚠️', 'Emergency Pause',
      'Use the warning icon for urgent breaks — the queue order stays intact when you resume.'),
  _Tip('⏭', 'Skip a Patient',
      'No-show? Tap Skip to move on. Skipped patients can rejoin with a fresh token.'),
  _Tip('🗓', 'Set Your Schedule',
      'Use Edit Schedule to add weekly time slots, max queue length and slot duration.'),
  _Tip('💊', 'Build Medicine Library',
      'Add common medicines once in Edit Medicine — pick them faster while prescribing.'),
  _Tip('📋', 'Patient History',
      'Open Patient History to review past visits, prescriptions and notes in one place.'),
  _Tip('🔄', 'Pull to Refresh',
      'Swipe down on the home screen to fetch the latest queue and appointment status.'),
  _Tip('✕', 'Close the Queue',
      'Tap Close at the end of a session — frees the slot and updates today\'s stats.'),
];

class _QueueHomePageState extends ConsumerState<QueueHomePage> {
  bool _hasFetched = false;
  bool _walkInExpanded = false;
  final Map<int, bool> _patientsExpanded = {};
  late final ProviderSubscription<int?> _doctorIdSub;
  ProviderSubscription<String?>? _clinicIdSub;

  final PageController _tipsController = PageController();
  int _currentTip = 0;
  Timer? _tipsTimer;

  @override
  void initState() {
    super.initState();
    _doctorIdSub = ref.listenManual<int?>(
      doctorLoginViewModelProvider.select((s) => s.doctorId),
      (_, next) {
        if (next != null && next > 0) _loadData();
      },
    );
    // Clinic switch (doctor multi-clinic / receptionist) madhe queue refresh
    _clinicIdSub = ref.listenManual<String?>(
      doctorLoginViewModelProvider.select((s) => s.clinic_id),
      (prev, next) {
        if (next != null && next != prev) _loadData(force: true);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _loadData();
    });
    _tipsTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted || !_tipsController.hasClients) return;
      final next = (_currentTip + 1) % _kDoctorTips.length;
      _tipsController.animateToPage(
        next,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeInOut,
      );
    });
  }

  @override
  void dispose() {
    _tipsTimer?.cancel();
    _tipsController.dispose();
    _doctorIdSub.close();
    _clinicIdSub?.close();
    super.dispose();
  }

  int get _doctorId => ref.read(doctorLoginViewModelProvider).doctorId ?? 0;
  String? get _clinicId => ref.read(doctorLoginViewModelProvider).clinic_id;

  String get _doctorName {
    if (ref.read(tokenProvider).roleId == 3) {
      return ref.read(receptionistLoginViewModelProvider).name ?? 'Receptionist';
    }
    return ref.read(doctorLoginViewModelProvider).name ?? 'Doctor';
  }

  Future<void> _loadData({bool force = false}) async {
    if (_doctorId == 0) return;
    if (_hasFetched && !force) return;
    _hasFetched = true;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId, clinicId: _clinicId);
    await Future.wait([
      ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(_doctorId, clinicId: _clinicId),
      ref.read(doctorSettingsViewModelProvider.notifier).getDoctorSchedule(_doctorId, clinicId: _clinicId),
    ]);
  }

  Future<void> _refreshData() => _loadData(force: true);

  // ── Queue filters ─────────────────────────────────────────────────────────

  List<AppointmentList> _todayQueue(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'booked') return false;
      if (a.bookingType != 1) return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
  }

  List<AppointmentList> _completedToday(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'completed') return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }

  List<AppointmentList> _skippedToday(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if ((a.status?.toLowerCase() ?? '') != 'skipped') return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList();
  }

  List<AppointmentList> _todayActivePatients(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress' || s == 'skipped') &&
          d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
  }

  int _todayTotalCount(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      return d.year == today.year && d.month == today.month && d.day == today.day;
    }).length;
  }

  List<({DateTime date, int count})> _lastSevenDaysCompleted(List<AppointmentList> all) {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final out = <({DateTime date, int count})>[];
    for (int i = 0; i < 7; i++) {
      final d = start.add(Duration(days: i));
      final n = all.where((a) {
        if ((a.status?.toLowerCase() ?? '') != 'completed') return false;
        final ad = DateTime.tryParse(a.appointmentDate ?? '');
        if (ad == null) return false;
        return ad.year == d.year && ad.month == d.month && ad.day == d.day;
      }).length;
      out.add((date: d, count: n));
    }
    return out;
  }

  // ── Snack ─────────────────────────────────────────────────────────────────

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: kPrimaryDark,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      duration: const Duration(seconds: 2),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }

  Future<bool> _confirm({
    required String title,
    required String message,
    required String confirmLabel,
    Color confirmColor = kPrimaryDark,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        content: Text(message,
            style: const TextStyle(fontSize: 13.5, color: kTextSecondary, height: 1.4)),
        actionsPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextSecondary, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: confirmColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(confirmLabel, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    return ok == true;
  }

  // ── Queue actions ─────────────────────────────────────────────────────────

  Future<void> _onQueueStart(int? queueId) async {
    final ok = await _confirm(
      title: 'Start Queue?',
      message: 'Patients will be notified that the queue is now live.',
      confirmLabel: 'Start',
      confirmColor: kPrimaryDark,
    );
    if (!ok) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStart(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue started');
      await _refreshData();
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  Future<void> _onQueueResume(int? queueId) async {
    await _onQueueStart(queueId);
    if (!mounted) return;
    ref.read(doctorNavTabRequestProvider.notifier).state = kDoctorPatientListTab;
  }

  Future<void> _onQueuePause(int? queueId) async {
    final ok = await _confirm(
      title: 'Pause Queue?',
      message: 'Waiting patients will be notified that the queue is paused. You can resume any time.',
      confirmLabel: 'Pause',
      confirmColor: kAmberDark,
    );
    if (!ok) return;
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
      await _refreshData();
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  Future<void> _onQueueStop(int? queueId) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueStop(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue closed');
      await _refreshData();
    } catch (_) {
      _snack('Failed to close queue');
    }
  }

  Future<void> _onQueueNext(AppointmentList current) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueNext(AppointmentRequestModel(
            doctorId: _doctorId,
            appointmentId: current.appointmentId ?? 0,
            clinicId: _clinicId,
          ));
      _snack(res.message ?? 'Next patient');
    } catch (_) {
      _snack('Failed');
    }
  }

  Future<void> _onQueueSkip(AppointmentList current) async {
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queueSkip(AppointmentRequestModel(
            doctorId: _doctorId,
            appointmentId: current.appointmentId ?? 0,
          ));
      _snack(res.message ?? 'Patient skipped');
    } catch (_) {
      _snack('Failed to skip');
    }
  }

  Future<void> _onQueuePauseEmergency(int? queueId) async {
    if (queueId == null) { _snack('Queue ID not available'); return; }
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePauseEmergency(queueId);
      _snack(res.message ?? 'Queue paused (emergency)');
      await _refreshData();
    } catch (_) {
      _snack('Failed to pause queue');
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final d = DateTime.tryParse(dob);
    return d == null ? null : DateTime.now().year - d.year;
  }

  String? _ageStr(String? dob) {
    final age = _calcAge(dob);
    return age == null ? null : '$age yrs';
  }

  DateTime? _instantOf(String? raw) {
    final v = raw?.trim();
    if (v == null || v.isEmpty || v.toLowerCase() == 'null') return null;
    try { return DateTime.parse(v).toUtc(); } catch (_) { return null; }
  }

  Future<void> _startSession(AppointmentList p) async {
    final pid = p.patientId ?? 0;
    final did = _doctorId;
    if (pid == 0 || did == 0) { _snack('Missing info'); return; }
    final status = p.status?.toLowerCase() ?? '';
    if (status != 'in_progress') {
      if (status == 'booked') {
        final slotStart = _instantOf(p.startTime);
        if (slotStart != null && DateTime.now().toUtc().isBefore(slotStart)) {
          _snack('Scheduled for ${_fmtTime(p.startTime)} — start once the slot begins.');
          return;
        }
      }
      try {
        final res = await ref.read(appointmentViewModelProvider.notifier).startSession(
          AppointmentRequestModel(doctorId: did, patientId: pid, appointmentId: p.appointmentId ?? 0),
        );
        if (!mounted) return;
        if (res.success != true) { _snack(res.message ?? 'Could not start session'); return; }
      } catch (e) {
        if (mounted) _snack('Failed to start session');
        return;
      }
    }
    if (!mounted) return;
    await Navigator.push(context, MaterialPageRoute(
      builder: (_) => PrescriptionScreen(
        patientId: pid, doctorId: did,
        userTypeId: p.userType ?? 1,
        appointmentId: p.appointmentId ?? 0,
        patientName: p.patientName ?? 'Patient',
        patientAge: _ageStr(p.dob),
        patientGender: p.gender,
        queueNumber: p.queueNumber,
        patientStatus: p.status ?? 'booked',
        symptoms: p.symptoms,
        clinicId: _clinicId,
      ),
    ));
    if (!mounted) return;
    _hasFetched = false;
    await _refreshData();
  }

  Future<void> _skipPatient(AppointmentList p) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).queueSkip(
        AppointmentRequestModel(
          doctorId: _doctorId, appointmentId: p.appointmentId ?? 0,
          patientId: p.patientId ?? 0, isNext: 0,
        ),
      );
      if (!mounted) return;
      _snack(res.message ?? (res.success == true ? 'Patient skipped' : 'Skip failed'));
    } catch (_) {
      if (mounted) _snack('Failed to skip');
    }
  }

  Future<void> _cancelByDoctor(AppointmentList p) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).cancelByDoctor(
        AppointmentRequestModel(doctorId: _doctorId, appointmentId: p.appointmentId ?? 0),
      );
      if (!mounted) return;
      _snack(res.message ?? (res.success == true ? 'Appointment cancelled' : 'Cancel failed'));
    } catch (_) {
      if (mounted) _snack('Failed to cancel');
    }
  }

  void _cancelConfirm(AppointmentList p) => showDialog(
    context: context,
    builder: (ctx) => Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48, height: 48,
            decoration: const BoxDecoration(color: kRedLight, shape: BoxShape.circle),
            child: const Icon(Icons.cancel_outlined, color: kRed, size: 22),
          ),
          const SizedBox(height: 12),
          const Text('Cancel Appointment',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 6),
          Text('Cancel appointment for ${p.patientName ?? 'this patient'}?',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: kTextSecondary, height: 1.5)),
          const SizedBox(height: 20),
          Row(children: [
            Expanded(child: OutlinedButton(
              onPressed: () => Navigator.pop(ctx),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: kBorder),
                foregroundColor: kTextSecondary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('No', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
            const SizedBox(width: 10),
            Expanded(child: ElevatedButton(
              onPressed: () { Navigator.pop(ctx); _cancelByDoctor(p); },
              style: ElevatedButton.styleFrom(
                backgroundColor: kRed, foregroundColor: Colors.white, elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 11),
              ),
              child: const Text('Yes, Cancel', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            )),
          ]),
        ]),
      ),
    ),
  );

  void _viewPrescription(AppointmentList p) {
    if ((p.patientId ?? 0) == 0) { _snack('Missing info'); return; }
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => DoctorPrescriptionDetailScreen(
        appointmentId: p.appointmentId ?? 0,
        patientId: p.patientId ?? 0,
        patientName: p.patientName ?? 'Patient',
        patientAge: _ageStr(p.dob),
        patientGender: p.gender,
        queueNumber: p.queueNumber,
      ),
    ));
  }

  String _initials(String name) => name
      .trim()
      .split(' ')
      .take(2)
      .map((w) => w.isNotEmpty ? w[0] : '')
      .join()
      .toUpperCase();

  QueueState _sessionQueueState(int? status) {
    switch (status) {
      case 1: return QueueState.running;
      case 2: return QueueState.paused;
      case 3: return QueueState.stopped;
      default: return QueueState.idle;
    }
  }

  AppointmentList? _findCurrentPatient(List<AppointmentList> all, int? appointmentId) {
    if (appointmentId == null || appointmentId == 0) return null;
    try { return all.firstWhere((a) => a.appointmentId == appointmentId); }
    catch (_) { return null; }
  }

  String _fmtTime(String? raw) {
    if (raw == null) return '';
    try {
      final dt = DateTime.parse(raw).toUtc();
      return DateFormat('h:mm a').format(dt);
    } catch (_) { return raw; }
  }

  String _fmtScheduleTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final parts = raw.split(':');
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts.length > 1 ? parts[1] : '0') ?? 0;
      return DateFormat('h:mm a').format(DateTime(2000, 1, 1, h, m));
    } catch (_) { return raw; }
  }

  String _bookingModeLabel(int? mode) {
    switch (mode) {
      case 2: return 'Slots';
      case 3: return 'Queue + Slots';
      default: return 'Queue';
    }
  }

  List<TimeSlotModel> _todayScheduledSlots() {
    final schedule = ref.read(doctorSettingsViewModelProvider).doctorSchedule;
    final days = schedule?.schedule;
    if (days == null || days.isEmpty) return [];
    final todayName = DateFormat('EEEE').format(DateTime.now()).toLowerCase();
    for (final d in days) {
      if ((d.day ?? '').toLowerCase() == todayName) {
        if ((d.isEnabled ?? 0) != 1) return [];
        final slots = d.slots ?? [];
        return [...slots]..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
      }
    }
    return [];
  }

  bool _shouldShowSession(dynamic session) {
    if (_isStaleQueueDate(session.queueDate as String?)) return false;
    final qs = session.queueStatus ?? 0;
    final hasSlot = session.startTime != null;
    if (qs == 3) return false;
    if (qs == 0 && !hasSlot) return false;
    return true;
  }

  bool _isStaleQueueDate(String? queueDate) {
    final d = DateTime.tryParse(queueDate ?? '');
    if (d == null) return false;
    final now = DateTime.now();
    return DateTime(d.year, d.month, d.day)
        .isBefore(DateTime(now.year, now.month, now.day));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BUILD
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final hour = DateTime.now().hour;
    final greeting = hour < 12
        ? 'Good Morning 👋'
        : hour < 17 ? 'Good Afternoon 👋' : 'Good Evening 👋';

    final vmState           = ref.watch(appointmentViewModelProvider);
    final appointmentsAsync = vmState.patientAppointmentsList;

    ref.watch(doctorSettingsViewModelProvider.select((s) => s.doctorSchedule));

    final isReceptionist = ref.watch(tokenProvider).roleId == 3;
    final doctorName = isReceptionist
        ? (ref.watch(receptionistLoginViewModelProvider).name ?? 'Receptionist')
        : ref.watch(doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'));

    return Scaffold(
      backgroundColor: kPageBg, // ← grey-50
      body: appointmentsAsync.when(
        loading: () => _buildLoadingBody(greeting, doctorName),
        error: (e, _) => _buildErrorBody(e, greeting, doctorName),
        data: (list) {
          final todayQueue     = _todayQueue(list);
          final current        = todayQueue.isNotEmpty ? todayQueue.first : null;
          final completed      = _completedToday(list);
          final skipped        = _skippedToday(list);
          final allSessions    = vmState.todayQueueResult?.value ?? [];
          final visibleSessions = allSessions.where(_shouldShowSession).toList();
          final todayActivePts = _todayActivePatients(list);

          return _buildRefreshableScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),

              // ── WALK-IN CARD (receptionist only) ───────────────────
              if (ref.watch(tokenProvider).roleId == 3)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildWalkInCard(),
                        AnimatedSize(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                          child: _walkInExpanded
                              ? Padding(
                                  padding: const EdgeInsets.only(top: 10),
                                  child: _WalkInInlinePanel(
                                    onBooked: () => setState(() => _walkInExpanded = false),
                                  ),
                                )
                              : const SizedBox.shrink(),
                        ),
                      ],
                    ),
                  ),
                ),

              // ── SESSION QUEUE CARDS / EMPTY STATE ──────────────────
              if (visibleSessions.isEmpty) ...[
                if (_todayScheduledSlots().isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildNoLiveSessions(),
                    ),
                  ),
              ] else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final session   = visibleSessions[i];
                        final sessionQs = _sessionQueueState(session.queueStatus);
                        final currentPt = _findCurrentPatient(list, session.currentServing);
                        final nextQNo   = session.currentQueueNo != null &&
                                session.currentQueueNo! < (session.totalQueue ?? 0)
                            ? session.currentQueueNo! + 1
                            : null;
                        final slotLbl = (session.startTime != null)
                            ? '${_fmtTime(session.startTime)} – ${_fmtTime(session.endTime)}'
                            : null;
                        final sessionSkipped = skipped.where((a) => a.queueId == session.queueId).length;
                        final sessionTotal   = session.totalQueue ?? 0;
                        final sessionDone    = session.completedCount ?? 0;
                        final sessionServing = (session.currentServing ?? 0) > 0 ? 1 : 0;
                        final sessionWaiting = (sessionTotal - sessionDone - sessionServing - sessionSkipped)
                            .clamp(0, sessionTotal);
                        final sessionPts = todayActivePts
                            .where((p) => p.queueId == session.queueId)
                            .toList();
                        final sessionHasIP = sessionPts.any(
                            (p) => (p.status?.toLowerCase() ?? '') == 'in_progress');
                        final sessionBooked = sessionPts
                            .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
                            .toList()
                          ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
                        final sessionNextQNo = sessionBooked.isNotEmpty
                            ? sessionBooked.first.queueNumber
                            : null;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildQueueCard(
                            current:        currentPt,
                            nextQueueNo:    nextQNo,
                            total:          sessionTotal,
                            done:           sessionDone,
                            sessionWaiting: sessionWaiting,
                            sessionSkipped: sessionSkipped,
                            queueState:     sessionQs,
                            queueId:        session.queueId,
                            slotLabel:      slotLbl,
                            isOnlySession:  i == 0,
                            sessionPts:     sessionPts,
                            sessionHasIP:   sessionHasIP,
                            sessionNextQNo: sessionNextQNo,
                          ),
                        );
                      },
                      childCount: visibleSessions.length,
                    ),
                  ),
                ),

              // ── QUICK ACTIONS ───────────────────────────────────────
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  child: _buildHomeQuickActions(),
                ),
              ),

              // ── RECENTLY SEEN ───────────────────────────────────────
              if (completed.isNotEmpty) ...[
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
                    child: _sectionHeader('Recently Seen', completed.length,
                        kGreen, kGreenLight, kGreenDark),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final p = completed.take(5).toList()[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _buildCompletedPatientCard(p),
                        );
                      },
                      childCount: completed.length > 5 ? 5 : completed.length,
                    ),
                  ),
                ),
              ],

              const SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          );
        },
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL / LOADING / ERROR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRefreshableScrollView({required List<Widget> slivers}) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _refreshData,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  Widget _buildLoadingBody(String greeting, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          ),
        ],
      );

  Widget _buildErrorBody(Object e, String greeting, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildHeader(greeting, doctorName)),
          SliverFillRemaining(
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: kRedLight, shape: BoxShape.circle,
                    border: Border.all(color: kRedBorder),
                  ),
                  child: const Icon(Icons.error_outline, color: kRed, size: 22),
                ),
                const SizedBox(height: 10),
                Text('$e', style: const TextStyle(color: kTextMuted, fontSize: 12)),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _refreshData,
                  style: TextButton.styleFrom(foregroundColor: kPrimary),
                  child: const Text('Retry'),
                ),
              ]),
            ),
          ),
        ],
      );

  // ─────────────────────────────────────────────────────────────────────────
  // HEADER  (dark teal — same solid color, no gradient)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHeader(String greeting, String doctorName) {
    final initials   = _initials(doctorName);
    final loginState = ref.watch(doctorLoginViewModelProvider);
    final clinicName = loginState.clinic_name ?? '';
    final fromCheck = loginState.phoneCheckResult.maybeWhen(
      data: (list) => list,
      orElse: () => <DoctorDetails>[],
    );
    final allClinics = fromCheck.isNotEmpty
        ? fromCheck
        : (loginState.clinicsList?.maybeWhen(
              data: (list) => list,
              orElse: () => <DoctorDetails>[],
            ) ??
            <DoctorDetails>[]);
    final multiClinic = allClinics.length > 1;
    final isReceptionist = ref.read(tokenProvider).roleId == 3;

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF9FE1CB), width: 2),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: kPrimaryDark, letterSpacing: 0.4,
                    )),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(greeting,
                        style: const TextStyle(
                          fontSize: 11, fontWeight: FontWeight.w500,
                          color: kTextSecondary, height: 1.1,
                        )),
                    const SizedBox(height: 2),
                    Text(
                      isReceptionist ? doctorName : 'Dr. $doctorName',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700,
                        color: kTextPrimary, letterSpacing: -0.3, height: 1.15,
                      ),
                    ),
                    if (clinicName.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      GestureDetector(
                        onTap: multiClinic
                            ? () => _showClinicPicker(context, allClinics)
                            : null,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kPrimary),
                            const SizedBox(width: 3),
                            Flexible(
                              child: Text(
                                clinicName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w500,
                                  color: kPrimary, height: 1.2,
                                ),
                              ),
                            ),
                            if (multiClinic) ...[
                              const SizedBox(width: 2),
                              const Icon(Icons.arrow_drop_down,
                                  size: 15, color: kPrimary),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF9FE1CB)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 5, height: 5,
                    decoration: const BoxDecoration(
                      color: kPrimary, shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    DateFormat('d MMM').format(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w600,
                      color: kPrimaryDark, letterSpacing: 0.2,
                    ),
                  ),
                ]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showClinicPicker(
      BuildContext context, List<DoctorDetails> clinics) async {
    final selected = await showModalBottomSheet<DoctorDetails>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) {
        final current = ref.read(doctorLoginViewModelProvider).clinic_id;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              Container(
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: kBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text('Select Clinic',
                    style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    )),
              ),
              const SizedBox(height: 8),
              ...clinics.map((c) {
                final isActive = c.clinicId == current;
                return ListTile(
                  leading: Icon(
                    Icons.local_hospital_outlined,
                    color: isActive ? kPrimary : kTextSecondary,
                    size: 20,
                  ),
                  title: Text(
                    c.clinicName ?? 'Clinic',
                    style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600,
                      color: isActive ? kPrimary : kTextPrimary,
                    ),
                  ),
                  subtitle: c.clinicAddress != null
                      ? Text(c.clinicAddress!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: kTextSecondary))
                      : null,
                  trailing: isActive
                      ? const Icon(Icons.check_circle,
                          color: kPrimary, size: 18)
                      : null,
                  onTap: () => Navigator.pop(context, c),
                );
              }),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (selected == null) return;
    if (selected.clinicId == ref.read(doctorLoginViewModelProvider).clinic_id) {
      return;
    }
    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .selectClinic(selected);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // QUEUE CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildQueueCard({
    required AppointmentList? current,
    required int? nextQueueNo,
    required int total,
    required int done,
    required int sessionWaiting,
    required int sessionSkipped,
    required QueueState queueState,
    int? queueId,
    String? slotLabel,
    bool isOnlySession = false,
    List<AppointmentList> sessionPts = const [],
    bool sessionHasIP = false,
    int? sessionNextQNo,
  }) {
    final isIdle    = queueState == QueueState.idle;
    final isRunning = queueState == QueueState.running;
    final isStopped = queueState == QueueState.stopped;
    final isPaused  = queueState == QueueState.paused;
    final isEmergency = ref
        .read(appointmentViewModelProvider.notifier)
        .isEmergencyPaused(queueId);

    final Color borderColor = isRunning
        ? kPrimary
        : isPaused
            ? kAmber
            : kCardBorder;
    final double borderWidth = (isRunning || isPaused) ? 2.0 : 1.5;

    // ── Compact card for idle sessions ──────────────────────────────────
    if (isIdle && !isOnlySession) {
      return Container(
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: borderColor, width: borderWidth),
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pulseDot(),
            const SizedBox(width: 5),
            _queueStateBadge(queueState),
            const Spacer(),
            if (slotLabel != null) _slotPill(slotLabel),
          ]),
          const SizedBox(height: 10),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Daily progress',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary)),
            Text('$done / $total seen',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryDark)),
          ]),
          const SizedBox(height: 5),
          _solidProgress(total == 0 ? 0 : (done / total).clamp(0.0, 1.0)),
        ]),
      );
    }

    // ── Full card ────────────────────────────────────────────────────────
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          _pulseDot(),
          const SizedBox(width: 5),
          _queueStateBadge(queueState),
          const Spacer(),
          if (slotLabel != null) _slotPill(slotLabel),
        ]),
        const SizedBox(height: 10),
        _buildSessionMiniStats(total: total, waiting: sessionWaiting, done: done),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('Daily progress',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary)),
          Text('$done / $total seen',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kPrimaryDark)),
        ]),
        const SizedBox(height: 5),
        _solidProgress(total == 0 ? 0 : (done / total).clamp(0.0, 1.0)),
        const SizedBox(height: 10),

        // ── Action buttons ─────────────────────────────────────────────
        Row(children: [
          Expanded(
            child: _actionBtn(
              label: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onTap: isRunning
                  ? () => _onQueuePause(queueId)
                  : isPaused
                      ? () => _onQueueResume(queueId)
                      : () => _onQueueStart(queueId),
              bg: isRunning ? kAmberLight : kPrimaryDark,
              fg: isRunning ? kAmberDark : Colors.white,
              border: isRunning ? kAmberBorder : kPrimaryDark,
            ),
          ),
          if (!isEmergency) ...[
            const SizedBox(width: 6),
            Expanded(
              child: Opacity(
                opacity: (isStopped || isIdle) ? 0.4 : 1.0,
                child: GestureDetector(
                  onTap: (isStopped || isIdle) ? null : () => _showCloseDialog(queueId),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: kRedLight,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: kRedBorder),
                    ),
                    alignment: Alignment.center,
                    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: const [
                      Icon(Icons.close_rounded, size: 13, color: kRedDark),
                      SizedBox(width: 4),
                      Text('Close',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRedDark)),
                    ]),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () => _showEmergencyDialog(queueId),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 11),
              decoration: BoxDecoration(
                color: kPurpleLight,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: kPurpleBorder),
              ),
              child: const Icon(Icons.warning_amber_rounded, color: kPurpleDark, size: 16),
            ),
          ),
        ]),

        // ── Patient list ───────────────────────────────────────────────
        if (sessionPts.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: kHairline),
          const SizedBox(height: 6),
          GestureDetector(
            onTap: () => setState(() {
              final key = queueId ?? 0;
              _patientsExpanded[key] = !(_patientsExpanded[key] ?? true);
            }),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                const Text('Patients',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kTextPrimary)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: kPrimaryLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('${sessionPts.length}',
                      style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kPrimaryDark)),
                ),
                const Spacer(),
                AnimatedRotation(
                  turns: (_patientsExpanded[queueId ?? 0] ?? true) ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 220),
                  child: const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: kTextSecondary),
                ),
              ]),
            ),
          ),
          if (_patientsExpanded[queueId ?? 0] ?? true)
            ...sessionPts.map((p) => Padding(
              padding: const EdgeInsets.only(top: 6),
              child: _buildActionPatientCard(p, queueState, sessionHasIP, sessionNextQNo),
            )),
        ],
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showCloseDialog(int? queueId) async {
    final vmState     = ref.read(appointmentViewModelProvider);
    final appts       = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final sessions    = vmState.todayQueueResult?.value ?? [];

    final matchingSession = sessions.where((s) => s.queueId == queueId).toList();
    final queueStartTime  = matchingSession.isEmpty
        ? null : DateTime.tryParse(matchingSession.first.startTime ?? '');

    final queuePending = appts.where((p) {
      if (p.queueId != queueId) return false;
      final st = (p.status?.toLowerCase() ?? '');
      return st == 'booked' || st == 'in_progress';
    }).length;
    final queueSkipped = appts.where((p) {
      if (p.queueId != queueId) return false;
      return (p.status?.toLowerCase() ?? '') == 'skipped';
    }).length;
    final earlierSlotPending = queueStartTime == null ? 0
        : appts.where((p) {
            if (p.bookingType != 2) return false;
            final st = (p.status?.toLowerCase() ?? '');
            if (st != 'booked' && st != 'skipped') return false;
            final pTime = DateTime.tryParse(p.startTime ?? '');
            return pTime != null && pTime.isBefore(queueStartTime);
          }).length;
    final totalCancel = queuePending + queueSkipped + earlierSlotPending;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: kRedLight, shape: BoxShape.circle,
              border: Border.all(color: kRedBorder),
            ),
            child: const Icon(Icons.close_rounded, color: kRed, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('Close Queue?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 8),
          const Text('Are you sure you want to close this queue?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.5)),
          if (totalCancel > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: kAmberLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kAmberBorder),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber_rounded, size: 16, color: kAmberDark),
                const SizedBox(width: 8),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('$totalCancel patient${totalCancel == 1 ? '' : 's'} will be cancelled',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kAmberDark)),
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (queuePending > 0) '$queuePending pending in this queue',
                      if (queueSkipped > 0) '$queueSkipped skipped in this queue',
                      if (earlierSlotPending > 0) '$earlierSlotPending from earlier slots',
                    ].join(' · '),
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kAmberDark, height: 1.3),
                  ),
                ])),
              ]),
            ),
          ],
          const SizedBox(height: 4),
        ]),
        actions: [
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('No',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kRedLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kRedBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Yes, Close',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kRedDark)),
              ),
            )),
          ]),
        ],
      ),
    );
    if (confirmed == true) await _onQueueStop(queueId);
  }

  Future<void> _showEmergencyDialog(int? queueId) async {
    if (ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId)) {
      _snack('Already emergency paused');
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: kPurpleLight, shape: BoxShape.circle,
              border: Border.all(color: kPurpleBorder),
            ),
            child: const Icon(Icons.warning_amber_rounded, color: kPurple, size: 26),
          ),
          const SizedBox(height: 14),
          const Text('Emergency Pause?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
          const SizedBox(height: 8),
          const Text('Queue is Emergency Pause. Do you want to pause immediately?',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.5)),
          const SizedBox(height: 4),
        ]),
        actions: [
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, false),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(color: const Color(0xFFF1F5F9), borderRadius: BorderRadius.circular(12)),
                alignment: Alignment.center,
                child: const Text('No',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ),
            )),
            const SizedBox(width: 10),
            Expanded(child: GestureDetector(
              onTap: () => Navigator.pop(ctx, true),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: kPurpleLight, borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPurpleBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Yes, Pause',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPurpleDark)),
              ),
            )),
          ]),
        ],
      ),
    );
    if (confirmed == true) await _onQueuePauseEmergency(queueId);
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SESSION MINI STATS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSessionMiniStats({required int total, required int waiting, required int done}) {
    return Row(children: [
      _miniStatChip(label: 'Total',   value: total,   bg: kPrimaryLight,  fg: Colors.black,  border: const Color(0xFF9FE1CB)),
      const SizedBox(width: 6),
      _miniStatChip(label: 'Waiting', value: waiting, bg: kBlueLight,     fg: Colors.black,     border: kBlueBorder),
      const SizedBox(width: 6),
      _miniStatChip(label: 'Done',    value: done,    bg: kGreenLight,    fg: Colors.black,    border: kGreenBorder),
    ]);
  }

  Widget _miniStatChip({
    required String label,
    required int value,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.fromLTRB(9, 7, 9, 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: border),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                  color: fg.withOpacity(0.75), letterSpacing: 0.2)),
          const SizedBox(height: 2),
          Text(value.toString().padLeft(2, '0'),
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: fg, height: 1, letterSpacing: -0.4)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION BUTTON
  // ─────────────────────────────────────────────────────────────────────────

  Widget _actionBtn({
    required String label,
    IconData? icon,
    required VoidCallback onTap,
    required Color bg,
    required Color fg,
    required Color border,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(11),
          border: bg == kPrimaryDark ? null : Border.all(color: border),
        ),
        alignment: Alignment.center,
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                  color: fg, letterSpacing: 0.2)),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // WALK-IN CARD  (receptionist only)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWalkInCard() {
    return GestureDetector(
      onTap: () => setState(() => _walkInExpanded = !_walkInExpanded),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLight, // solid teal-light, no gradient
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF9FE1CB)),
        ),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(children: [
          Container(
            width: 42, height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF9FE1CB)),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.person_add_rounded, size: 20, color: kPrimaryDark),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Add Walk-in Patient',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.black)),
              SizedBox(height: 2),
              Text('Book appointment for walk-in patient',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kPrimaryDark)),
            ]),
          ),
          AnimatedRotation(
            turns: _walkInExpanded ? 0.25 : 0,
            duration: const Duration(milliseconds: 200),
            child: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: kPrimaryDark),
          ),
        ]),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HOME QUICK ACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildHomeQuickActions() {
    final isReceptionist = ref.watch(tokenProvider).roleId == 3;
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 3, height: 14,
              decoration: BoxDecoration(color: kPrimary, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 7),
          const Text('Quick Actions',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                  letterSpacing: 0.2, color: kTextPrimary)),
        ]),
        const SizedBox(height: 10),
        if (isReceptionist)
          Row(children: [
            _homeActionTile(icon: Icons.calendar_today_rounded, label: 'Edit\nSchedule',
                bg: kAmberLight, fg: kAmberDark, border: kAmberBorder,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorAvailabilityPage()))),
            const SizedBox(width: 7),
            _homeActionTile(icon: Icons.people_alt_rounded, label: 'Patient\nList',
                bg: kGreenLight, fg: kGreenDark, border: kGreenBorder,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorPatientHistoryScreen()))),
            const SizedBox(width: 7),
            const Expanded(child: SizedBox()),
          ])
        else
          Row(children: [
            _homeActionTile(icon: Icons.medication_rounded, label: 'Add\nMedicine',
                bg: kPurpleLight, fg: kPurpleDark, border: kPurpleBorder,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const AddMedicinePage()))),
            const SizedBox(width: 7),
            _homeActionTile(icon: Icons.calendar_today_rounded, label: 'Edit\nSchedule',
                bg: kAmberLight, fg: kAmberDark, border: kAmberBorder,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorAvailabilityPage()))),
            const SizedBox(width: 7),
            _homeActionTile(icon: Icons.history_rounded, label: 'Patient\nHistory',
                bg: kGreenLight, fg: kGreenDark, border: kGreenBorder,
                onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const DoctorPatientHistoryScreen()))),
          ]),
      ]),
    );
  }

  Widget _homeActionTile({
    required IconData icon,
    required String label,
    required Color bg,
    required Color fg,
    required Color border,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 10),
          decoration: BoxDecoration(
            color: bg, // solid color, no gradient
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          child: Column(children: [
            Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: border),
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 16, color: fg),
            ),
            const SizedBox(height: 6),
            Text(label,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, height: 1.2,
                    fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NO LIVE SESSIONS EMPTY STATE
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildNoLiveSessions() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 14),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 48, height: 48,
          decoration: BoxDecoration(
            color: kPrimaryLight, shape: BoxShape.circle,
            border: Border.all(color: const Color(0xFF9FE1CB)),
          ),
          child: const Icon(Icons.event_busy_rounded, color: kPrimaryDark, size: 22),
        ),
        const SizedBox(height: 10),
        const Text('No Schedule for Today',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 4),
        const Text('Set your weekly availability to start accepting patients.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35)),
        const SizedBox(height: 14),
        GestureDetector(
          onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DoctorAvailabilityPage())),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: kPrimaryDark,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: const [
              Icon(Icons.calendar_today_rounded, color: Colors.white, size: 13),
              SizedBox(width: 6),
              Text('Set Schedule',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
            ]),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT CARDS
  // ─────────────────────────────────────────────────────────────────────────

  // Avatar color palettes — solid bg, no gradient
  static const List<(Color, Color, Color)> _kAvatarPalettes = [
    (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)), // teal
    (Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFF4C1D95)), // purple
    (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFF78350F)), // amber
    (Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFF7F1D1D)), // red
  ];

  Widget _buildActionPatientCard(
    AppointmentList p,
    QueueState qs,
    bool hasIP,
    int? nextBookedQNo,
  ) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final name      = p.patientName ?? 'Patient';
    final initials  = _initials(name);
    final age       = _calcAge(p.dob);
    final status    = p.status?.toLowerCase().trim() ?? '';
    final isIP      = status == 'in_progress';
    final isSkipped = status == 'skipped';
    final isBooked  = status == 'booked';
    final queueActive = qs == QueueState.running || qs == QueueState.paused;

    bool accessible = false;
    if (isIP) { accessible = true; }
    else if (isSkipped) { accessible = true; }
    else if (queueActive && isBooked) {
      accessible = !hasIP && p.queueNumber == nextBookedQNo;
    }
    final effectiveAccessible = isSkipped ? accessible : queueActive && accessible;
    final VoidCallback? effectiveSkip = isBooked && queueActive && (isReceptionist || accessible)
        ? () => _skipPatient(p) : null;

    final (avBg, avBd, avFg) = _kAvatarPalettes[(p.queueNumber ?? 0) % _kAvatarPalettes.length];

    final Color borderColor = isIP
        ? kPrimary
        : isSkipped ? kAmber : kCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: (isIP || isSkipped) ? 1.5 : 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: avBg, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: avBd),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: avFg)),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: kTextPrimary, height: 1.15),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text([if (p.gender != null) p.gender!, if (age != null) '$age yrs'].join(' · '),
                style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
            if (isIP || isSkipped) ...[
              const SizedBox(height: 3),
              _statusChip(status),
            ],
          ])),
          if (p.queueNumber != null) ...[
            const SizedBox(width: 7),
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
              decoration: BoxDecoration(
                color: avBg, borderRadius: BorderRadius.circular(9),
                border: Border.all(color: avBd),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Text('TOKEN',
                    style: TextStyle(fontSize: 8, color: kTextMuted,
                        fontWeight: FontWeight.w600, letterSpacing: 0.5)),
                const SizedBox(height: 1),
                Text((p.queueNumber ?? 0).toString().padLeft(2, '0'),
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                        color: avFg, height: 1)),
              ]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (effectiveSkip != null) ...[
            Expanded(child: GestureDetector(
              onTap: effectiveSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kRedBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Skip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
              ),
            )),
            if (!isReceptionist) const SizedBox(width: 7),
          ],
          if (!isReceptionist)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: effectiveAccessible ? () => _startSession(p) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: effectiveAccessible ? kPrimaryDark : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIP ? 'Continue' : isSkipped ? 'Recall' : 'Start Session',
                    style: TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: effectiveAccessible ? Colors.white : kTextMuted,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _buildCompletedPatientCard(AppointmentList p) {
    final name     = p.patientName ?? 'Patient';
    final initials = _initials(name);
    final age      = _calcAge(p.dob);

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: kGreenLight, borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kGreenBorder),
            ),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kGreenDark)),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                    color: kTextPrimary, height: 1.15),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 1),
            Text([if (p.gender != null) p.gender!, if (age != null) '$age yrs'].join(' · '),
                style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
          ])),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => _viewPrescription(p),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: kPurpleLight,
              borderRadius: BorderRadius.circular(9),
              border: Border.all(color: kPurpleBorder),
            ),
            alignment: Alignment.center,
            child: const Text('View Prescription',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kPurpleDark)),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // BADGES, CHIPS, HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'in_progress': bg = kPrimaryLight; fg = kPrimaryDark; dot = kPrimary; break;
      case 'skipped':     bg = kAmberLight;   fg = kAmberDark;   dot = kAmber;   break;
      case 'completed':   bg = kGreenLight;   fg = kGreenDark;   dot = kGreen;   break;
      default:            bg = kRedLight;     fg = kRedDark;     dot = kRed;
    }
    return _badgeDot(
      status == 'in_progress' ? 'In Progress' : status[0].toUpperCase() + status.substring(1),
      bg, fg, dot,
    );
  }

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running'; bg = kPrimaryLight; fg = kPrimaryDark; dot = kPrimary; break;
      case QueueState.paused:
        label = 'Paused';  bg = kAmberLight;   fg = kAmberDark;   dot = kAmber;   break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF1F5F9); fg = const Color(0xFF64748B); dot = const Color(0xFF94A3B8);
        break;
      case QueueState.idle:
        label = 'Idle'; bg = kRedLight; fg = kRedDark; dot = kRed; break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: bg, borderRadius: BorderRadius.circular(20),
      border: Border.all(color: dot.withOpacity(0.25)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 5, height: 5,
          decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
      const SizedBox(width: 4),
      Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              letterSpacing: 0.2, color: fg)),
    ]),
  );

  Widget _slotPill(String label) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F5F9),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: kCardBorder),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      const Icon(Icons.schedule_rounded, size: 9, color: kTextSecondary),
      const SizedBox(width: 3),
      Text(label,
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
              color: kTextSecondary, letterSpacing: 0.2)),
    ]),
  );

  Widget _solidProgress(double value) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Container(
      height: 7,
      color: kPrimaryLight,
      child: FractionallySizedBox(
        widthFactor: value.clamp(0.0, 1.0),
        alignment: Alignment.centerLeft,
        child: Container(color: kPrimary),
      ),
    ),
  );

  Widget _sectionHeader(String label, int count, Color accent, Color accentLight, Color accentDark) {
    return Row(children: [
      Container(width: 3, height: 14,
          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(3))),
      const SizedBox(width: 7),
      Text(label,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
              color: kTextPrimary, letterSpacing: -0.1)),
      const SizedBox(width: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(
          color: accentLight, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withOpacity(0.25)),
        ),
        child: Text('$count',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: accentDark)),
      ),
    ]);
  }

  Widget _pulseDot() => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0.4, end: 1.0),
    duration: const Duration(milliseconds: 900),
    builder: (_, v, child) => Opacity(opacity: v, child: child),
    onEnd: () => setState(() {}),
    child: Container(
      width: 7, height: 7,
      decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
    ),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN INLINE PANEL
// ─────────────────────────────────────────────────────────────────────────────

class _WalkInInlinePanel extends ConsumerStatefulWidget {
  final VoidCallback onBooked;
  const _WalkInInlinePanel({required this.onBooked});

  @override
  ConsumerState<_WalkInInlinePanel> createState() => _WalkInInlinePanelState();
}

class _WalkInInlinePanelState extends ConsumerState<_WalkInInlinePanel> {
  final _nameCtr   = TextEditingController();
  final _mobileCtr = TextEditingController();

  bool    _loading = true;
  String? _error;

  List<DoctorAvailabilityModel> _todaySessions = [];
  DoctorAvailabilityModel? _selected;

  bool    _booking  = false;
  String? _bookError;

  Patients?           _foundPatient;
  bool                _checkingMobile    = false;
  int?                _resolvedPatientId;
  int?                _familyMemberId;
  int?                _familyHeadPatientId;
  int?                _familyGenderId;
  List<FamilyMember>  _familyMembers     = [];
  bool                _loadingMembers    = false;
  bool                _addingNewMember   = false;
  final _newMemberCtr = TextEditingController();
  int  _newMemberGender = 1;

  @override
  void initState() {
    super.initState();
    _mobileCtr.addListener(_onMobileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
  }

  @override
  void dispose() {
    _mobileCtr.removeListener(_onMobileChanged);
    _nameCtr.dispose();
    _mobileCtr.dispose();
    _newMemberCtr.dispose();
    super.dispose();
  }

  ApiService? get _api {
    final dio = ref.read(dioProvider).value;
    if (dio == null) return null;
    return ApiService(dio);
  }

  void _clearPatientState() {
    _foundPatient = null; _resolvedPatientId = null;
    _familyMemberId = null; _familyHeadPatientId = null; _familyGenderId = null;
    _familyMembers = []; _loadingMembers = false; _addingNewMember = false;
    _newMemberCtr.clear(); _newMemberGender = 1;
  }

  Future<void> _loadSessions() async {
    setState(() { _loading = true; _error = null; });
    final recepState = ref.read(receptionistLoginViewModelProvider);
    final doctorId  = recepState.doctorId;
    final clinicId  = ref.read(doctorLoginViewModelProvider).clinic_id;
    final api = _api;
    if (doctorId == null || api == null) {
      setState(() { _loading = false; _error = 'Doctor not linked'; });
      return;
    }
    final dayName = const ['Monday','Tuesday','Wednesday','Thursday','Friday','Saturday','Sunday'][DateTime.now().weekday - 1];
    try {
      final schedule = await api.getDoctorSchedule(doctorId, clinicId: clinicId);
      final todaySlots = (schedule.schedule ?? [])
          .where((d) => d.day == dayName && (d.isEnabled ?? 0) == 1)
          .expand((d) => d.slots ?? [])
          .toList();
      final sessions = todaySlots
          .where((slot) {
            if (_hasSessionEndedToday(slot.endTime)) return false;
            final mode = slot.bookingMode ?? 0;
            return mode == 1 || mode == 2 || mode == 3;
          })
          .map((slot) => DoctorAvailabilityModel(
                dayOfWeek:   dayName,
                isEnabled:   true,
                slotId:      slot.slotId,
                startTime:   slot.startTime,
                endTime:     slot.endTime,
                bookingMode: slot.bookingMode,
                slotDuration: slot.slotDuration,
              ))
          .toList();
      if (!mounted) return;
      setState(() {
        _todaySessions = sessions;
        _selected = sessions.length == 1 ? sessions.first : null;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() { _loading = false; _error = 'Could not load sessions'; });
    }
  }

  void _onMobileChanged() {
    final digits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      _lookupMobile(digits);
    } else if (_foundPatient != null || _resolvedPatientId != null ||
               _familyMemberId != null || _familyHeadPatientId != null) {
      setState(() => _clearPatientState());
    }
  }

  Future<void> _lookupMobile(String mobile) async {
    final api = _api;
    if (api == null) return;
    setState(() { _checkingMobile = true; });
    try {
      final results = await api.checkPhonePatient(mobile);
      if (!mounted) return;
      if (results.isNotEmpty) {
        final p = results.first;
        setState(() { _foundPatient = p; _checkingMobile = false; _loadingMembers = true; });
        try {
          final members = p.patientId != null
              ? await api.fetchFamilyMembers(p.patientId!) : <FamilyMember>[];
          if (mounted) setState(() { _familyMembers = members; _loadingMembers = false; });
        } catch (_) {
          if (mounted) setState(() { _loadingMembers = false; });
        }
      } else {
        setState(() { _clearPatientState(); _checkingMobile = false; });
      }
    } catch (_) {
      if (mounted) setState(() { _checkingMobile = false; });
    }
  }

  String _fmtTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    DateTime? dt = DateTime.tryParse(iso);
    int h, m;
    if (dt != null) { h = dt.hour; m = dt.minute; }
    else {
      final p = iso.split(':');
      h = int.tryParse(p[0]) ?? 0;
      m = p.length > 1 ? (int.tryParse(p[1]) ?? 0) : 0;
    }
    final sf = h < 12 ? 'AM' : 'PM';
    final dh = h == 0 ? 12 : (h > 12 ? h - 12 : h);
    return '${dh.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')} $sf';
  }

  String _modeLabel(int? m) => switch (m) { 1 => 'Queue', 2 => 'Slots', 3 => 'Queue+Slots', _ => '' };

  Future<void> _book() async {
    final name   = _nameCtr.text.trim();
    final mobile = _mobileCtr.text.trim();
    if (name.isEmpty) { setState(() { _bookError = 'Patient name is required'; }); return; }
    if (mobile.length < 10) { setState(() { _bookError = 'Enter valid 10-digit mobile'; }); return; }
    if (_selected == null) { setState(() { _bookError = 'Please select a session'; }); return; }

    final recepState = ref.read(receptionistLoginViewModelProvider);
    final doctorId   = recepState.doctorId;
    final clinicId   = ref.read(doctorLoginViewModelProvider).clinic_id;
    if (doctorId == null) return;

    setState(() { _booking = true; _bookError = null; });

    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2,'0')}-${today.day.toString().padLeft(2,'0')}';
    final isNewFamily      = _familyHeadPatientId != null;
    final isExistingFamily = _familyMemberId != null;
    final isFamilyBooking  = isNewFamily || isExistingFamily;

    final body = <String, dynamic>{
      'name':             name,
      'mobile_no':        mobile,
      'doctor_id':        doctorId,
      'appointment_date': dateStr,
      'slot_id':          _selected!.slotId,
      'user_type':        isFamilyBooking ? 2 : 1,
      if (clinicId != null) 'clinic_id': clinicId,
      if (isExistingFamily) 'patient_id': _familyMemberId,
      if (isNewFamily) 'family_id': _familyHeadPatientId,
      if (isNewFamily && _familyGenderId != null) 'gender_id': _familyGenderId,
      if (!isFamilyBooking && _resolvedPatientId != null) 'patient_id': _resolvedPatientId,
    }..removeWhere((_, v) => v == null);

    try {
      final isOnline = ref.read(connectivityNotifierProvider).isOnline;
      final resp = await ref.read(receptionistLoginViewModelProvider.notifier)
          .walkInBook(body, isOnline: isOnline);
      if (!mounted) return;
      if (resp.success == true) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(resp.message ?? 'Walk-in patient booked'),
          backgroundColor: kPrimary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ));
        widget.onBooked();
      } else {
        setState(() { _bookError = resp.message ?? 'Booking failed'; });
      }
    } catch (e) {
      if (mounted) setState(() { _bookError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _booking = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bookedFor = _resolvedPatientId != null || _familyMemberId != null || _familyHeadPatientId != null
        ? _nameCtr.text : null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kCardBorder),
      ),
      padding: const EdgeInsets.all(14),
      child: _loading
          ? const Center(child: Padding(
              padding: EdgeInsets.all(16),
              child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary)))
          : _error != null
              ? _errBox(_error!)
              : _todaySessions.isEmpty
                  ? _errBox('No sessions scheduled for today')
                  : Builder(builder: (context) {
                      final liveSessions = _todaySessions
                          .where((s) => !_hasSessionEndedToday(s.endTime))
                          .toList();
                      // Auto-clear stale selection
                      if (_selected != null &&
                          !liveSessions.any((s) => s.slotId == _selected!.slotId)) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          if (mounted) setState(() => _selected = null);
                        });
                      }
                      if (liveSessions.isEmpty) {
                        return _errBox('No sessions available at this time');
                      }
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Row(children: [
                        const Icon(Icons.event_rounded, size: 14, color: kPrimary),
                        const SizedBox(width: 6),
                        Text(
                          'Today  ·  ${const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][DateTime.now().weekday - 1]}, ${DateTime.now().day} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month - 1]}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kPrimary),
                        ),
                      ]),
                      const SizedBox(height: 12),
                      if (liveSessions.length > 1) ...[
                        const Text('SELECT SESSION',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                                color: kTextMuted, letterSpacing: 0.7)),
                        const SizedBox(height: 8),
                      ],
                      Wrap(
                        spacing: 8, runSpacing: 8,
                        children: liveSessions.map((s) {
                          final isSel = _selected?.slotId == s.slotId;
                          return GestureDetector(
                            onTap: () => setState(() => _selected = s),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSel ? kPrimaryDark : kPrimaryLight,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color: isSel ? kPrimaryDark : const Color(0xFF9FE1CB)),
                              ),
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                Text('${_fmtTime(s.startTime)} – ${_fmtTime(s.endTime)}',
                                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: isSel ? Colors.white : kTextPrimary)),
                                const SizedBox(height: 2),
                                Text(_modeLabel(s.bookingMode),
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
                                        color: isSel ? Colors.white70 : kTextMuted)),
                              ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 14),
                      _inlineField(controller: _nameCtr, label: 'Patient Name',
                          icon: Icons.person_outline_rounded,
                          type: TextInputType.name, caps: TextCapitalization.words),
                      const SizedBox(height: 10),
                      _inlineField(controller: _mobileCtr, label: 'Mobile Number',
                          icon: Icons.phone_outlined, type: TextInputType.phone, maxLen: 10,
                          formatters: [FilteringTextInputFormatter.digitsOnly]),

                      if (_checkingMobile) ...[
                        const SizedBox(height: 8),
                        const Row(children: [
                          SizedBox(width: 14, height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary)),
                          SizedBox(width: 8),
                          Text('Checking...', style: TextStyle(fontSize: 12, color: kTextMuted)),
                        ]),
                      ] else if (_foundPatient != null && _resolvedPatientId == null &&
                                 _familyMemberId == null && _familyHeadPatientId == null) ...[
                        const SizedBox(height: 8),
                        Container(
                          decoration: BoxDecoration(
                            color: kPrimaryLight,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF9FE1CB)),
                          ),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
                              child: Row(children: [
                                const Icon(Icons.person_rounded, size: 14, color: kPrimaryDark),
                                const SizedBox(width: 6),
                                Text('${_foundPatient!.name}  ·  ${_foundPatient!.mobileNo ?? ''}',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                        color: kPrimaryDark)),
                              ]),
                            ),
                            const Divider(height: 1, color: kBorder),
                            InkWell(
                              onTap: () => setState(() {
                                _resolvedPatientId = _foundPatient!.patientId;
                                _nameCtr.text = _foundPatient!.name ?? _nameCtr.text;
                                _foundPatient = null; _familyMemberId = null;
                                _familyHeadPatientId = null; _familyGenderId = null;
                              }),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  const Icon(Icons.how_to_reg_rounded, size: 14, color: kPrimaryDark),
                                  const SizedBox(width: 8),
                                  Text('Book for ${_foundPatient!.name}',
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                          color: kPrimaryDark)),
                                ]),
                              ),
                            ),
                            if (_loadingMembers) ...[
                              const Divider(height: 1, color: kBorder),
                              const Padding(
                                padding: EdgeInsets.all(10),
                                child: Center(child: SizedBox(width: 14, height: 14,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: kPrimary))),
                              ),
                            ] else if (_familyMembers.isNotEmpty) ...[
                              const Divider(height: 1, color: kBorder),
                              ..._familyMembers.map((m) => Column(children: [
                                InkWell(
                                  onTap: () => setState(() {
                                    _familyMemberId = m.memberId!;
                                    _nameCtr.text = m.memberName ?? '';
                                    _foundPatient = null; _resolvedPatientId = null;
                                    _familyHeadPatientId = null; _familyGenderId = null;
                                  }),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                                    child: Row(children: [
                                      CircleAvatar(radius: 12, backgroundColor: kPrimaryLight,
                                          child: Text(m.avatarLetter,
                                              style: const TextStyle(color: kPrimaryDark, fontSize: 11,
                                                  fontWeight: FontWeight.w700))),
                                      const SizedBox(width: 8),
                                      Expanded(child: Text(m.memberName ?? '',
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                              color: kTextPrimary))),
                                      Text([m.genderName, m.relationName]
                                              .where((s) => s != null && s.isNotEmpty).join(' · '),
                                          style: const TextStyle(fontSize: 11, color: kTextMuted)),
                                    ]),
                                  ),
                                ),
                                const Divider(height: 1, color: kBorder),
                              ])),
                            ],
                            InkWell(
                              onTap: () => setState(() => _addingNewMember = !_addingNewMember),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                child: Row(children: [
                                  const Icon(Icons.person_add_alt_1_rounded, size: 14, color: kTextSecondary),
                                  const SizedBox(width: 8),
                                  const Text('Add new family member',
                                      style: TextStyle(fontSize: 12, color: kTextSecondary)),
                                  const Spacer(),
                                  Icon(_addingNewMember ? Icons.expand_less : Icons.expand_more,
                                      size: 16, color: kTextMuted),
                                ]),
                              ),
                            ),
                            if (_addingNewMember) ...[
                              const Divider(height: 1, color: kBorder),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  TextField(
                                    controller: _newMemberCtr,
                                    textCapitalization: TextCapitalization.words,
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                        color: kTextPrimary),
                                    decoration: InputDecoration(
                                      hintText: 'Family member name',
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      filled: true, fillColor: Colors.white,
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kBorder)),
                                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kBorder)),
                                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8),
                                          borderSide: const BorderSide(color: kPrimary, width: 1.5)),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(children: [
                                    _GenderPill(label: 'Male',   value: 1,
                                        selected: _newMemberGender == 1,
                                        onTap: () => setState(() => _newMemberGender = 1)),
                                    const SizedBox(width: 6),
                                    _GenderPill(label: 'Female', value: 2,
                                        selected: _newMemberGender == 2,
                                        onTap: () => setState(() => _newMemberGender = 2)),
                                    const SizedBox(width: 6),
                                    _GenderPill(label: 'Other',  value: 3,
                                        selected: _newMemberGender == 3,
                                        onTap: () => setState(() => _newMemberGender = 3)),
                                  ]),
                                  const SizedBox(height: 10),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: () {
                                        final name = _newMemberCtr.text.trim();
                                        if (name.isEmpty) return;
                                        setState(() {
                                          _familyHeadPatientId = _foundPatient!.patientId;
                                          _familyGenderId      = _newMemberGender;
                                          _nameCtr.text        = name;
                                          _foundPatient        = null;
                                          _resolvedPatientId   = null;
                                          _familyMemberId      = null;
                                          _addingNewMember     = false;
                                        });
                                      },
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: kPrimaryDark, foregroundColor: Colors.white,
                                        elevation: 0,
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                      ),
                                      child: const Text('Use this member',
                                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                    ),
                                  ),
                                ]),
                              ),
                            ],
                          ]),
                        ),
                      ] else if (bookedFor != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: kGreenLight, borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: kGreenBorder),
                          ),
                          child: Row(children: [
                            const Icon(Icons.check_circle_rounded, size: 16, color: kGreen),
                            const SizedBox(width: 8),
                            Text('Booking for $bookedFor',
                                style: const TextStyle(fontSize: 12, color: kGreenDark,
                                    fontWeight: FontWeight.w500)),
                          ]),
                        ),
                      ],

                      if (_bookError != null) ...[
                        const SizedBox(height: 10),
                        _errBox(_bookError!),
                      ],
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity, height: 44,
                        child: ElevatedButton(
                          onPressed: _booking ? null : _book,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimaryDark, foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          child: _booking
                              ? const SizedBox(width: 18, height: 18,
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                              : const Text('Book Walk-in Patient',
                                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                        ),
                      ),
                      ]);
                    }),
    );
  }

  Widget _inlineField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType type = TextInputType.text,
    TextCapitalization caps = TextCapitalization.none,
    int? maxLen,
    List<TextInputFormatter>? formatters,
  }) =>
      TextField(
        controller: controller,
        keyboardType: type,
        textCapitalization: caps,
        maxLength: maxLen,
        inputFormatters: formatters,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kTextSecondary),
          prefixIcon: Icon(icon, size: 16, color: kTextSecondary),
          counterText: '',
          filled: true, fillColor: kPageBg,
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kBorder)),
          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: kPrimary, width: 1.5)),
        ),
      );

  Widget _errBox(String msg) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: kRedLight, borderRadius: BorderRadius.circular(10),
      border: Border.all(color: kRedBorder),
    ),
    child: Text(msg, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kRedDark)),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// GENDER PILL
// ─────────────────────────────────────────────────────────────────────────────

class _GenderPill extends StatelessWidget {
  final String label;
  final int    value;
  final bool   selected;
  final VoidCallback onTap;
  const _GenderPill({required this.label, required this.value,
      required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? kPrimaryDark : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? kPrimaryDark : kBorder),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
              color: selected ? Colors.white : kTextSecondary)),
    ),
  );
}
