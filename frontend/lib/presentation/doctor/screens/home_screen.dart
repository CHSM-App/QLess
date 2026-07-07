
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
// const kPageBg         = Color(0xFFF8F9FB); // grey-50
const kPageBg         = Color(0xFFFAFAFA); // grey-50
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

// Desktop layout
const _kHomeWideBreak = 900.0;
const _kHomeFullBreak = 1300.0;
const _kHomeSideWidth = 260.0;

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
  bool _showWalkInForm = false;
  final Map<int, bool> _patientsExpanded = {};
  final Map<int, bool> _sessionExpanded = {};
  late final ProviderSubscription<int?> _doctorIdSub;
  ProviderSubscription<String?>? _clinicIdSub;
  final ScrollController _scrollController = ScrollController();

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
    _scrollController.dispose();
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

  bool get _isDoctorOnLeaveToday {
    final leaves = ref.read(doctorSettingsViewModelProvider).leaves;
    if (leaves.isEmpty) return false;
    final today = DateTime.now();
    final todayOnly = DateTime(today.year, today.month, today.day);
    return leaves.any((l) {
      try {
        final from = DateTime.parse(l.fromDate);
        final to = DateTime.parse(l.toDate);
        return !todayOnly.isBefore(DateTime(from.year, from.month, from.day)) &&
            !todayOnly.isAfter(DateTime(to.year, to.month, to.day));
      } catch (_) {
        return false;
      }
    });
  }

  Future<void> _loadData({bool force = false}) async {
    if (_doctorId == 0) return;
    if (_hasFetched && !force) return;
    _hasFetched = true;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId, clinicId: _clinicId);
    await Future.wait([
      ref.read(appointmentViewModelProvider.notifier).fetchPatientAppointments(_doctorId, clinicId: _clinicId),
      ref.read(doctorSettingsViewModelProvider.notifier).getDoctorSchedule(_doctorId, clinicId: _clinicId),
      ref.read(doctorSettingsViewModelProvider.notifier).getDoctorLeaves(_doctorId),
    ]);
  }

  Future<void> _refreshData() => _loadData(force: true);

  // Silent queue-status update — no loading spinner
  void _refreshQueueStatus() {
    if (_doctorId == 0) return;
    ref.read(appointmentViewModelProvider.notifier).joinClinic(_doctorId, clinicId: _clinicId);
  }

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

  List<AppointmentList> _todaySlotPatients(List<AppointmentList> all) {
    final today = DateTime.now();
    return all.where((a) {
      if (a.bookingType != 2) return false;
      final d = DateTime.tryParse(a.appointmentDate ?? '');
      if (d == null) return false;
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress' || s == 'skipped') &&
          d.year == today.year && d.month == today.month && d.day == today.day;
    }).toList()
      ..sort((a, b) => (a.startTime ?? '').compareTo(b.startTime ?? ''));
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
      _refreshQueueStatus();
    } catch (_) {
      _snack('Failed to start queue');
    }
  }

  Future<void> _onQueueResume(int? queueId) async {
    await _onQueueStart(queueId);
    if (!mounted) return;
    ref.read(doctorNavTabRequestProvider.notifier).state = kDoctorPatientListTab;
  }

  Future<void> _onQueuePause(int? queueId, {bool confirmFirst = true}) async {
    if (confirmFirst) {
      final ok = await _confirm(
        title: 'Pause Queue?',
        message: 'Waiting patients will be notified that the queue is paused. You can resume any time.',
        confirmLabel: 'Pause',
        confirmColor: kAmberDark,
      );
      if (!ok) return;
    }
    try {
      final res = await ref
          .read(appointmentViewModelProvider.notifier)
          .queuePause(AppointmentRequestModel(doctorId: _doctorId, queueId: queueId));
      _snack(res.message ?? 'Queue paused');
      _refreshQueueStatus();
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
      _refreshQueueStatus();
    } catch (_) {
      _snack('Failed to close queue');
    }
  }

  Future<void> _onToggleBookingClosed(int? queueId, bool closed) async {
    try {
      final res = await ref.read(appointmentViewModelProvider.notifier).stopBooking(
            AppointmentRequestModel(
              doctorId: _doctorId,
              queueId: queueId,
              bookingClosed: closed,
            ),
          );
      _snack(res.message ?? (closed ? 'New bookings stopped' : 'New bookings resumed'));
    } catch (_) {
      _snack('Failed to update booking status');
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
      _refreshQueueStatus();
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

  bool _shouldShowSession(dynamic session, {required bool hasBooking}) {
    if (_isStaleQueueDate(session.queueDate as String?)) return false;
    final qs = session.queueStatus ?? 0;
    final hasSlot = session.startTime != null;
    if (qs == 3) return false;
    if (qs == 0 && !hasSlot && !hasBooking) return false;
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
    final vmState           = ref.watch(appointmentViewModelProvider);
    final appointmentsAsync = vmState.patientAppointmentsList;

    ref.watch(doctorSettingsViewModelProvider.select((s) => s.doctorSchedule));

    final isReceptionist = ref.watch(tokenProvider).roleId == 3;
    final doctorName = isReceptionist
        ? (ref.watch(receptionistLoginViewModelProvider).name ?? 'Receptionist')
        : ref.watch(doctorLoginViewModelProvider.select((s) => s.name ?? 'Doctor'));

    // Pill nav (60) + its bottom padding (18) + extra clearance = 100, plus system safe area
    final safeBottom = MediaQuery.of(context).padding.bottom;
    final fabBottom  = safeBottom + 100.0;
    // List bottom padding: above FAB (56) + pill nav + gap
    final listBottom = safeBottom + 100.0 + 56.0 + 16.0;
    final isWide = MediaQuery.of(context).size.width >= _kHomeWideBreak;
    final isFullWide = MediaQuery.of(context).size.width >= _kHomeFullBreak;

    final bodyStack = Stack(
        children: [
          appointmentsAsync.when(
        loading: () => _buildLoadingBody(doctorName),
        error: (e, _) => _buildErrorBody(e, doctorName),
        data: (list) {
          final currentClinicId = _clinicId;
          final filteredList = currentClinicId == null
              ? list
              : list.where((a) => a.clinicId == currentClinicId).toList();
          final todayQueue     = _todayQueue(filteredList);
          final current        = todayQueue.isNotEmpty ? todayQueue.first : null;
          final completed      = _completedToday(filteredList);
          final skipped        = _skippedToday(filteredList);
          final allSessions    = vmState.todayQueueResult?.value ?? [];
          final activeQueueIds = filteredList.map((a) => a.queueId).whereType<int>().toSet();
          final todaySlotPts   = _todaySlotPatients(filteredList);
          final visibleSessions = allSessions
              .where((s) => _shouldShowSession(s, hasBooking: activeQueueIds.contains(s.queueId)) &&
                  (currentClinicId == null ||
                   activeQueueIds.contains(s.queueId) ||
                   todaySlotPts.any((p) {
                     final sessStart = _instantOf(s.startTime as String?);
                     final sessEnd   = _instantOf(s.endTime as String?);
                     final pt = _instantOf(p.startTime);
                     if (pt == null) return true;
                     if (sessStart != null && pt.isBefore(sessStart)) return false;
                     if (sessEnd   != null && !pt.isBefore(sessEnd))  return false;
                     return true;
                   })))
              .toList();
          final todayActivePts = _todayActivePatients(filteredList);

          // slot patients not matched to any visible session
          final matchedSlotIds = <int?>{};
          for (final s in visibleSessions) {
            final ss = _instantOf(s.startTime as String?);
            final se = _instantOf(s.endTime as String?);
            for (final p in todaySlotPts) {
              final pt = _instantOf(p.startTime);
              final inRange = pt == null ||
                  ((ss == null || !pt.isBefore(ss)) &&
                   (se == null || pt.isBefore(se)));
              if (inRange) matchedSlotIds.add(p.appointmentId);
            }
          }
          final unmatchedSlotPts = todaySlotPts
              .where((p) => !matchedSlotIds.contains(p.appointmentId))
              .toList();

          return _buildRefreshableScrollView(
            slivers: [
              // // ── SESSION QUEUE CARDS / EMPTY STATE ──────────────────
              // if (visibleSessions.isEmpty) ...[
              //   if (todaySlotPts.isNotEmpty)
              //     SliverToBoxAdapter(
              //       child: Padding(
              //         padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //         child: _buildStandaloneSlotSection(todaySlotPts),
              //       ),
              //     )
              //   else if (_todayScheduledSlots().isEmpty)
              //     SliverToBoxAdapter(
              //       child: Padding(
              //         padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //         child: _buildNoLiveSessions(),
              //       ),
              //     ),
              // ] else ...[
              // ── SESSION QUEUE CARDS / EMPTY STATE ──────────────────
              if (visibleSessions.isEmpty) ...[
                if (todaySlotPts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildStandaloneSlotSection(todaySlotPts),
                    ),
                  )
                else if (_todayScheduledSlots().isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildNoLiveSessions(),
                    ),
                  )
                else
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                      child: _buildAwaitingBookingsState(),
                    ),
                  ),
              ] else ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (_, i) {
                        final session   = visibleSessions[i];
                        final sessionQs = _sessionQueueState(session.queueStatus);
                        final slotLbl = (session.startTime != null)
                            ? '${_fmtTime(session.startTime)} – ${_fmtTime(session.endTime)}'
                            : null;
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

                        // slot patients — match by session time range
                        final sessStart = _instantOf(session.startTime as String?);
                        final sessEnd   = _instantOf(session.endTime as String?);
                        final sessionSlotPts = todaySlotPts.where((p) {
                          final pt = _instantOf(p.startTime);
                          if (pt == null) return true;
                          if (sessStart != null && pt.isBefore(sessStart)) return false;
                          if (sessEnd   != null && !pt.isBefore(sessEnd))  return false;
                          return true;
                        }).toList();

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 14),
                          child: _buildSessionAccordion(
                            sessionIndex:    i,
                            queueId:         session.queueId,
                            slotLabel:       slotLbl,
                            queueState:      sessionQs,
                            sessionPts:      sessionPts,
                            sessionHasIP:    sessionHasIP,
                            sessionNextQNo:  sessionNextQNo,
                            sessionSlotPts:  sessionSlotPts,
                            bookingClosed:   session.bookingClosed == true,
                          ),
                        );
                      },
                      childCount: visibleSessions.length,
                    ),
                  ),
                ),
                if (unmatchedSlotPts.isNotEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
                      child: _buildStandaloneSlotSection(unmatchedSlotPts),
                    ),
                  ),
              ],

              // ── QUICK ACTIONS ───────────────────────────────────────
              // SliverToBoxAdapter(
              //   child: Padding(
              //     padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              //     child: _buildHomeQuickActions(),
              //   ),
              // ),

              SliverToBoxAdapter(child: SizedBox(height: listBottom)),
            ],
          );
        },
      ),
          if (!_isDoctorOnLeaveToday && (!isWide || (!isFullWide && !_showWalkInForm)))
            Positioned(
              right: 16,
              bottom: fabBottom,
              child: FloatingActionButton(
                onPressed: () {
                  if (isWide) {
                    setState(() => _showWalkInForm = true);
                  } else {
                    showDialog(
                      context: context,
                      barrierDismissible: true,
                      builder: (_) => _WalkInDialog(
                        onBooked: () => Navigator.of(context).pop(),
                      ),
                    );
                  }
                },
                backgroundColor: kPrimaryDark,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tooltip: 'Add Walk-in Patient',
                child: const Icon(Icons.person_add_rounded),
              ),
            ),
        ],
      );

    return Scaffold(
      backgroundColor: kPageBg,
      body: Column(children: [
        _buildHeader(doctorName),
        Expanded(
          child: isWide
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (isFullWide || !_showWalkInForm) _buildOverviewSidebar(),
                    Expanded(child: bodyStack),
                    if (isFullWide || _showWalkInForm)
                      SizedBox(width: 400, child: _buildWalkInFormPane(closable: !isFullWide)),
                  ],
                )
              : bodyStack,
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP WALK-IN FORM PANE (right column, queue stays visible alongside)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildWalkInFormPane({required bool closable}) {
    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        border: Border(left: BorderSide(color: kBorder)),
      ),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
          decoration: const BoxDecoration(
            color: kCardBg,
            border: Border(bottom: BorderSide(color: kBorder)),
          ),
          child: Row(children: [
            Container(
              width: 32, height: 32,
              decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.person_add_rounded, size: 16, color: kPrimaryDark),
            ),
            const SizedBox(width: 10),
            const Text('Add Walk-in Patient',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
            if (closable) ...[
              const Spacer(),
              IconButton(
                onPressed: () => setState(() => _showWalkInForm = false),
                icon: const Icon(Icons.close_rounded, size: 20, color: kTextSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ],
          ]),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: _WalkInInlinePanel(
              onBooked: () => setState(() => _showWalkInForm = false),
            ),
          ),
        ),
      ]),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // DESKTOP OVERVIEW SIDEBAR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverviewSidebar({double width = _kHomeSideWidth}) {
    final vmState = ref.watch(appointmentViewModelProvider);
    final list = vmState.patientAppointmentsList.value ?? <AppointmentList>[];
    final currentClinicId = _clinicId;
    final filteredList = currentClinicId == null
        ? list
        : list.where((a) => a.clinicId == currentClinicId).toList();

    final allSessions = vmState.todayQueueResult?.value ?? [];
    final activeQueueIds = filteredList.map((a) => a.queueId).whereType<int>().toSet();
    final visibleSessions = allSessions
        .where((s) => _shouldShowSession(s, hasBooking: activeQueueIds.contains(s.queueId)))
        .toList();

    final compact = width < _kHomeSideWidth;

    return Container(
      width: width,
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(right: BorderSide(color: kBorder)),
      ),
      child: SingleChildScrollView(
          padding: EdgeInsets.all(compact ? 10 : 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OVERVIEW',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2, color: kTextMuted)),
            const SizedBox(height: 12),
            if (visibleSessions.isEmpty)
              _buildSessionOverviewBlock(null, filteredList, compact: compact)
            else
              for (int i = 0; i < visibleSessions.length; i++) ...[
                _buildSessionOverviewBlock(visibleSessions[i], filteredList, compact: compact),
                if (i != visibleSessions.length - 1) const SizedBox(height: 16),
              ],
          ]),
      ),
    );
  }

  Widget _buildSessionOverviewBlock(
      dynamic session, List<AppointmentList> filteredList, {required bool compact}) {
    final queueId = session?.queueId as int?;
    final scoped = queueId == null
        ? filteredList
        : filteredList.where((a) => a.queueId == queueId).toList();

    final total = _todayTotalCount(scoped);
    final waiting = scoped.where((a) {
      final s = a.status?.toLowerCase().trim() ?? '';
      return (s == 'booked' || s == 'in_progress') && _isTodayAppt(a);
    }).length;
    final completed = scoped.where((a) =>
        (a.status?.toLowerCase().trim() ?? '') == 'completed' && _isTodayAppt(a)).length;
    final skipped = scoped.where((a) =>
        (a.status?.toLowerCase().trim() ?? '') == 'skipped' && _isTodayAppt(a)).length;

    final label = session?.startTime != null
        ? '${_fmtTime(session.startTime as String?)} – ${_fmtTime(session.endTime as String?)}'
        : 'Today';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: kTextSecondary)),
      const SizedBox(height: 8),
      GridView.count(
        crossAxisCount: 2,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: compact ? 6 : 10,
        mainAxisSpacing: compact ? 6 : 10,
        childAspectRatio: compact ? 0.95 : 1.3,
        children: [
          _homeMiniStat('Total', total, kPrimary, compact: compact),
          _homeMiniStat('Waiting', waiting, kBlueDark, compact: compact),
          _homeMiniStat('Completed', completed, kGreen, compact: compact),
          _homeMiniStat('Skipped', skipped, kAmberDark, compact: compact),
        ],
      ),
    ]);
  }

  bool _isTodayAppt(AppointmentList a) {
    final d = DateTime.tryParse(a.appointmentDate ?? '');
    if (d == null) return false;
    final today = DateTime.now();
    return d.year == today.year && d.month == today.month && d.day == today.day;
  }

  Widget _homeMiniStat(String label, int value, Color color, {required bool compact}) => Container(
    padding: EdgeInsets.all(compact ? 8 : 12),
    decoration: BoxDecoration(
      color: kPageBg,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: kBorder),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$value', style: TextStyle(fontSize: compact ? 16 : 20, fontWeight: FontWeight.w800, color: color)),
        const SizedBox(height: 2),
        Text(label,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: compact ? 10 : 11, color: kTextSecondary, fontWeight: FontWeight.w600)),
      ],
    ),
  );

  // ─────────────────────────────────────────────────────────────────────────
  // SCROLL / LOADING / ERROR
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildRefreshableScrollView({required List<Widget> slivers}) {
    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _refreshData,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: slivers,
      ),
    );
  }

  Widget _buildLoadingBody(String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
          const SliverFillRemaining(
            child: Center(child: CircularProgressIndicator(color: kPrimary)),
          ),
        ],
      );

  Widget _buildErrorBody(Object e, String doctorName) =>
      _buildRefreshableScrollView(
        slivers: [
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

  Widget _buildHeader(String doctorName) {
    final initials   = _initials(doctorName);
    final loginState = ref.watch(doctorLoginViewModelProvider);
    final clinicName = loginState.clinic_name ?? '';
    // clinicsList is fetched via getDoctorClinics at login + restart → ground truth.
    // phoneCheckResult fallback covers the brief window before clinicsList loads.
    final fromClinics = loginState.clinicsList?.maybeWhen(
          data: (list) => list,
          orElse: () => <DoctorDetails>[],
        ) ??
        <DoctorDetails>[];
    final fromCheck = loginState.phoneCheckResult.maybeWhen(
      data: (list) => list,
      orElse: () => <DoctorDetails>[],
    );
    final allClinics = fromClinics.isNotEmpty ? fromClinics : fromCheck;
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
  // SESSION CARD
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSessionAccordion({
    required int sessionIndex,
    required int? queueId,
    required String? slotLabel,
    required QueueState queueState,
    required List<AppointmentList> sessionPts,
    required bool sessionHasIP,
    required int? sessionNextQNo,
    required List<AppointmentList> sessionSlotPts,
    required bool bookingClosed,
  }) {
    if (queueState == QueueState.stopped) return const SizedBox.shrink();

    final isRunning   = queueState == QueueState.running;
    final isPaused    = queueState == QueueState.paused;
    final queueActive = isRunning || isPaused;
    final isEmergency = ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId);

    // Current patient: in_progress first, then first booked by queue number
    // (only surfaced once the queue has actually been started — before that,
    // patients are shown as a plain waiting list, no "Now Serving" card)
    final ipPt = sessionPts.where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').firstOrNull;
    final bookedSorted = sessionPts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final currentPt = queueActive ? (ipPt ?? bookedSorted.firstOrNull) : null;

    // Up next = all except current, sorted by queue number
    final upNextPts = sessionPts
        .where((p) => p.appointmentId != currentPt?.appointmentId)
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));

    // Skipped patients waiting to return — pulled out of "Up next" and shown
    // first. Patients who tapped "I've Arrived" jump to the very front (they're
    // physically at the clinic right now); within each group, oldest-skipped
    // first (queue number order == skip order since skips happen in queue
    // sequence), so the doctor recalls in the right order.
    final skippedWaitingPts = upNextPts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'skipped')
        .toList()
      ..sort((a, b) {
        final arrivedCmp = (b.isArrived == true ? 1 : 0).compareTo(a.isArrived == true ? 1 : 0);
        if (arrivedCmp != 0) return arrivedCmp;
        return (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0);
      });
    final bookedUpNextPts = upNextPts
        .where((p) => (p.status?.toLowerCase() ?? '') != 'skipped')
        .toList();

    final cardBorderColor = isRunning ? kCardBorder : isPaused ? kCardBorder : kCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: kPageBg,
        borderRadius: const BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: cardBorderColor)),
        boxShadow: const [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-7, -7), blurRadius: 16, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(7, 7),  blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // ── Session header ────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 6),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: const BoxDecoration(
                color: kPageBg,
                borderRadius: BorderRadius.all(Radius.circular(9)),
                boxShadow: [
                  BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
                  BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(2, 2),  blurRadius: 5),
                ],
              ),
              child: Text('S${sessionIndex + 1}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: kPrimaryDark)),
            ),
            const SizedBox(width: 10),
            if (slotLabel != null)
              Expanded(child: Row(children: [
                const Icon(Icons.access_time_rounded, size: 13, color: kTextSecondary),
                const SizedBox(width: 4),
                Expanded(child: Text(slotLabel,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary),
                    overflow: TextOverflow.ellipsis)),
              ]))
            else
              const Expanded(child: Text('Session',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary))),
            const SizedBox(width: 8),
            isEmergency
                ? _badgeDot('Emergency', kPurpleLight, kPurpleDark, kPurple)
                : _queueStateBadge(queueState),
            const SizedBox(width: 8),
            _neuIconBtn(
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning
                  ? () => _showPauseOptionsDialog(queueId)
                  : () => _onQueueStart(queueId),
            ),
            if (!isEmergency) ...[
              const SizedBox(width: 6),
              _neuIconBtn(
                icon: Icons.stop_rounded,
                color: kRedDark,
                tooltip: 'Close queue',
                onTap: () => _showCloseDialog(queueId),
              ),
            ],
            // emergency pause button — available via pause dialog
            // const SizedBox(width: 6),
            // _neuIconBtn(
            //   icon: Icons.warning_amber_rounded,
            //   color: kPurpleDark,
            //   tooltip: 'Emergency pause',
            //   onTap: () => _showEmergencyDialog(queueId),
            // ),
          ]),
        ),

        // ── Accepting new bookings toggle (below the queue time) ────────
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _bookingToggleSwitch(
              value: !bookingClosed,
              tooltip: bookingClosed
                  ? 'New bookings stopped — tap to resume. Patients already in the queue are not affected.'
                  : 'Stop new bookings for today — patients already in the queue keep being served as usual.',
              onTap: () => _onToggleBookingClosed(queueId, !bookingClosed),
            ),
            const SizedBox(width: 6),
            Text(bookingClosed ? 'New bookings stopped' : 'Accepting new bookings',
                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                    color: bookingClosed ? kRedDark : kTextSecondary)),
          ]),
        ),

        // ── NOW SERVING ───────────────────────────────────────────────
        if (currentPt != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: _buildNowServingCard(currentPt, queueState, sessionPts.length - 1, sessionHasIP, sessionNextQNo),
          )
        else if (queueActive)
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 14, 0),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Container(
                    width: 46, height: 46,
                    decoration: const BoxDecoration(
                      color: kPageBg,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 7),
                        BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3),  blurRadius: 7),
                      ],
                    ),
                    child: const Icon(Icons.inbox_rounded, color: kTextMuted, size: 20),
                  ),
                  const SizedBox(height: 10),
                  const Text('No patients waiting',
                      style: TextStyle(color: kTextMuted, fontSize: 12, fontWeight: FontWeight.w500)),
                ]),
              ),
            ),
          ),

        // ── Skipped — waiting to return ─────────────────────────────────
        // Collapsed by default (only the highest-priority — first skipped —
        // patient shown) so a long skipped list doesn't push "Up next" down.
        if (skippedWaitingPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
            child: Row(children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 6),
              const Text('Skipped — waiting to return',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kAmberDark, letterSpacing: 0.2)),
              const Spacer(),
              Text('${skippedWaitingPts.length} waiting',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Builder(builder: (_) {
            final key = queueId ?? sessionIndex;
            final expanded = _patientsExpanded[key] ?? false;
            final visiblePts = expanded ? skippedWaitingPts : skippedWaitingPts.take(2).toList();
            final hiddenCount = skippedWaitingPts.length - visiblePts.length;
            return Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
              child: Column(children: [
                ...visiblePts.map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUpNextCard(p, queueState),
                    )),
                if (hiddenCount > 0 || expanded)
                  GestureDetector(
                    onTap: () => setState(() => _patientsExpanded[key] = !expanded),
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        expanded ? 'Show less' : '+$hiddenCount more skipped',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                            color: kAmberDark),
                      ),
                    ),
                  ),
              ]),
            );
          }),
        ],

        // ── Up next ───────────────────────────────────────────────────
        if (bookedUpNextPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 2, 14, 0),
            child: Row(children: [
              const Text('Up next',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kTextSecondary, letterSpacing: 0.2)),
              const Spacer(),
              Text('${bookedUpNextPts.length} waiting',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: bookedUpNextPts
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildUpNextCard(p, queueState),
                    ))
                .toList()),
          ),
        ] else if (skippedWaitingPts.isEmpty)
          const SizedBox(height: 14),

        // ── SLOT PATIENTS ─────────────────────────────────────────────
        if (sessionSlotPts.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 4, 14, 0),
            child: Row(children: [
              const Icon(Icons.schedule_rounded, size: 13, color: kTextSecondary),
              const SizedBox(width: 6),
              const Text('Scheduled Slots',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                      color: kTextSecondary, letterSpacing: 0.2)),
              const Spacer(),
              Text('${sessionSlotPts.length} booked',
                  style: const TextStyle(fontSize: 11, color: kTextMuted, fontWeight: FontWeight.w500)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: Column(children: sessionSlotPts
                .map((p) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _buildSlotPatientCard(p, queueState),
                    ))
                .toList()),
          ),
        ] else
          const SizedBox(height: 0),
      ]),
    );
  }

  Widget _buildStandaloneSlotSection(List<AppointmentList> patients) {
    // find schedule slot's configured time range via slotId
    final slotId = patients.first.slotId;
    String? timeRange;
    if (slotId != null) {
      final scheduleSlots = _todayScheduledSlots();
      final match = scheduleSlots.where((s) => s.slotId == slotId).firstOrNull;
      if (match != null) {
        final s = _fmtScheduleTime(match.startTime);
        final e = _fmtScheduleTime(match.endTime);
        if (s.isNotEmpty && e.isNotEmpty) { timeRange = '$s – $e'; }
        else if (s.isNotEmpty) { timeRange = s; }
      }
    }
    // fallback: first–last patient appointment times
    timeRange ??= () {
      final s = _fmtTime(patients.first.startTime);
      final e = _fmtTime(patients.last.startTime);
      if (s.isEmpty) return null;
      return (e.isNotEmpty && e != s) ? '$s – $e' : s;
    }();

    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(22)),
        border: Border.fromBorderSide(BorderSide(color: kCardBorder)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-7, -7), blurRadius: 16, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(7, 7),  blurRadius: 16, spreadRadius: 1),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(8)),
              alignment: Alignment.center,
              child: const Icon(Icons.calendar_month_rounded, size: 15, color: kBlueDark),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Slot Appointments',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: kTextPrimary)),
                if (timeRange != null) ...[
                  const SizedBox(height: 2),
                  Text(timeRange,
                      style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
                ],
              ]),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: kBlueLight, borderRadius: BorderRadius.circular(20)),
              child: Text('${patients.length}',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: kBlueDark)),
            ),
          ]),
        ),
        const Divider(height: 1, color: kCardBorder),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: patients.map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _buildSlotPatientCard(p, QueueState.idle),
            )).toList(),
          ),
        ),
      ]),
    );
  }

  Widget _buildSlotPatientCard(AppointmentList p, QueueState queueState) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final name      = p.patientName ?? 'Patient';
    final status    = p.status?.toLowerCase().trim() ?? '';
    final isIP      = status == 'in_progress';
    final isSkipped = status == 'skipped';
    final isBooked  = status == 'booked';
    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(4, 4),  blurRadius: 8, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        // slot time badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: kPageBg,
            borderRadius: BorderRadius.all(Radius.circular(9)),
            boxShadow: [
              BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3), blurRadius: 5),
              BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 5),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('TIME', style: TextStyle(fontSize: 7, color: kTextMuted,
                fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            Text(_fmtTime(p.startTime),
                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                    color: kPrimaryDark, height: 1.1)),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          if (isIP)
            _badgeDot('In Progress', kPrimaryLight, kPrimaryDark, kPrimary)
          else if (isSkipped)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Skipped earlier',
                  style: TextStyle(fontSize: 11, color: kAmberDark, fontWeight: FontWeight.w500)),
            ])
          else if (p.gender != null)
            Text(p.gender!, style: const TextStyle(fontSize: 11, color: kTextSecondary)),
        ])),
        const SizedBox(width: 10),
        // action buttons
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (isSkipped && !isReceptionist)
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 32, 173, 138),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('Recall',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            )
          else if ((isBooked || isIP) && !isReceptionist) ...[
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kPrimaryDark,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(isIP ? 'Continue' : 'Start',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 6),
            GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kRedBorder),
                ),
                child: const Text('Skip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
              ),
            ),
          ] else if (isBooked && isReceptionist)
            GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: kRedLight, borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: kRedBorder),
                ),
                child: const Text('Skip',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
              ),
            )
          else
            const Text('Waiting',
                style: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w500)),
        ]),
      ]),
    );
  }

  // Gradient pill switch — ON (accepting bookings) = teal→blue gradient with
  // the knob on the right; OFF (booking stopped) = flat grey, knob on the left.
  Widget _bookingToggleSwitch({
    required bool value,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            width: 34, height: 19,
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: value
                  ? const LinearGradient(colors: [Color(0xFF34D399), Color(0xFF3B82F6)])
                  : null,
              color: value ? null : const Color(0xFFD1D5DB),
            ),
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 15, height: 15,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: Color(0x33000000), blurRadius: 3, offset: Offset(0, 1))],
              ),
            ),
          ),
        ),
      );

  Widget _neuIconBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 32, height: 32,
            decoration: const BoxDecoration(
              color: kPageBg,
              borderRadius: BorderRadius.all(Radius.circular(9)),
              boxShadow: [
                BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 6),
                BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3),  blurRadius: 6),
              ],
            ),
            alignment: Alignment.center,
            child: Icon(icon, size: 16, color: color),
          ),
        ),
      );

  Widget _buildNowServingCard(
    AppointmentList p,
    QueueState queueState,
    int totalWaiting,
    bool hasIP,
    int? nextBookedQNo,
  ) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final name     = p.patientName ?? 'Patient';
    final status   = p.status?.toLowerCase().trim() ?? '';
    final isIP     = status == 'in_progress';
    final isBooked = status == 'booked';
    final queueActive = queueState == QueueState.running || queueState == QueueState.paused;

    bool accessible = false;
    if (isIP) {
      accessible = true;
    } else if (queueActive && isBooked) {
      accessible = !hasIP && p.queueNumber == nextBookedQNo;
    }
    final effectiveAccessible = queueActive && accessible;

    return Container(
      decoration: const BoxDecoration(
      //  color: kPrimaryDark,
          color: Color.fromARGB(255, 25, 136, 108),
        borderRadius: BorderRadius.all(Radius.circular(16)),
        boxShadow: [
          BoxShadow(color: Color(0x2E000000), offset: Offset(3, 3), blurRadius: 7),
                BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
          // BoxShadow(color: Color(0xFF0A4A35), offset: Offset(4, 4), blurRadius: 10),
          // BoxShadow(color: Color(0xFF2EC48A), offset: Offset(-3, -3), blurRadius: 8),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Text('NOW SERVING',
              style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                  letterSpacing: 1.1, color: Colors.white60)),
          const Spacer(),
          Text(
            'Token ${(p.queueNumber ?? 0).toString().padLeft(2, '0')}  •  $totalWaiting waiting',
            style: const TextStyle(fontSize: 11, color: Colors.white54, fontWeight: FontWeight.w500),
          ),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: const Color(0x14FFFFFF),
              borderRadius: const BorderRadius.all(Radius.circular(13)),
              boxShadow: const [
                BoxShadow(color: Color(0x2E000000), offset: Offset(3, 3), blurRadius: 7),
                BoxShadow(color: Color(0x0FFFFFFF), offset: Offset(-2, -2), blurRadius: 5),
              ],
            ),
            alignment: Alignment.center,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Text('TKN',
                  style: TextStyle(fontSize: 8, color: Colors.white54,
                      fontWeight: FontWeight.w700, letterSpacing: 0.6)),
              Text(
                (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800,
                    color: Colors.white, height: 1.0),
              ),
            ]),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.2),
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              if (isIP)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0x33FFFFFF),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: const Color(0x55FFFFFF)),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(width: 5, height: 5,
                        decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle)),
                    const SizedBox(width: 4),
                    const Text('In Progress',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: 0.2)),
                  ]),
                ),
              if (isIP && p.gender != null) const SizedBox(width: 6),
              if (p.gender != null)
                Text(p.gender!,
                    style: const TextStyle(fontSize: 12, color: Colors.white60,
                        fontWeight: FontWeight.w500)),
            ]),
          ])),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          if (queueActive) ...[
            Expanded(child: GestureDetector(
              onTap: () => _skipPatient(p),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.all(Radius.circular(10)),
                  border: Border.all(color: Colors.white24),
                  color: const Color(0x0FFFFFFF),
                ),
                alignment: Alignment.center,
                child: const Text('Skip',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white70)),
              ),
            )),
            if (!isReceptionist) const SizedBox(width: 10),
          ],
          if (!isReceptionist)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: effectiveAccessible ? () => _startSession(p) : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: effectiveAccessible ? Colors.white : const Color(0x26FFFFFF),
                    borderRadius: const BorderRadius.all(Radius.circular(10)),
                    boxShadow: effectiveAccessible
                        ? const [
                            BoxShadow(color: Color(0x23000000), offset: Offset(3, 3), blurRadius: 7),
                            BoxShadow(color: Color(0x80FFFFFF), offset: Offset(-2, -2), blurRadius: 5),
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIP ? 'Continue' : 'Start session',
                    style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: effectiveAccessible ? kPrimaryDark : Colors.white38,
                    ),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }

  Widget _maybeBlink(bool blink, Widget child) =>
      blink ? _ArrivedBlinkBadge(child: child) : child;

  Widget _buildUpNextCard(AppointmentList p, QueueState queueState) {
    final name          = p.patientName ?? 'Patient';
    final status        = p.status?.toLowerCase().trim() ?? '';
    final isSkipped     = status == 'skipped';
    final isBooked      = status == 'booked';
    final isArrived     = isSkipped && p.isArrived == true;
    final queueActive   = queueState == QueueState.running || queueState == QueueState.paused;
    final isReceptionist = ref.read(tokenProvider).roleId == 3;

    return Container(
      decoration: const BoxDecoration(
        color: kPageBg,
        borderRadius: BorderRadius.all(Radius.circular(13)),
        boxShadow: [
          BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-4, -4), blurRadius: 8, spreadRadius: 1),
          BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(4, 4),  blurRadius: 8, spreadRadius: 1),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: const BoxDecoration(
            color: kPageBg,
            borderRadius: BorderRadius.all(Radius.circular(9)),
            boxShadow: [
              BoxShadow(color: Color(0xFFCDD5DE), offset: Offset(3, 3), blurRadius: 5),
              BoxShadow(color: Color(0xFFFFFFFF), offset: Offset(-3, -3), blurRadius: 5),
            ],
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Text('TKN',
                style: TextStyle(fontSize: 7, color: kTextMuted,
                    fontWeight: FontWeight.w700, letterSpacing: 0.4)),
            Text(
              (p.queueNumber ?? 0).toString().padLeft(2, '0'),
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                  color: kPrimaryDark, height: 1.0),
            ),
          ]),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(name,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
          const SizedBox(height: 3),
          if (isArrived)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kRed, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Arrived at clinic — recall now',
                  style: TextStyle(fontSize: 11, color: kRedDark, fontWeight: FontWeight.w700)),
            ])
          else if (isSkipped)
            Row(mainAxisSize: MainAxisSize.min, children: [
              Container(width: 6, height: 6,
                  decoration: const BoxDecoration(color: kAmber, shape: BoxShape.circle)),
              const SizedBox(width: 4),
              const Text('Skipped earlier',
                  style: TextStyle(fontSize: 11, color: kAmberDark, fontWeight: FontWeight.w500)),
            ])
          else if (p.gender != null)
            Text(p.gender!,
                style: const TextStyle(fontSize: 11, color: kTextSecondary, fontWeight: FontWeight.w500)),
        ])),
        const SizedBox(width: 10),
        if (isSkipped && queueActive && !isReceptionist)
          _maybeBlink(
            isArrived,
            GestureDetector(
              onTap: () => _startSession(p),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 32, 173, 138),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: const Text('Recall',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          )
        else if (isBooked && queueActive && isReceptionist)
          GestureDetector(
            onTap: () => _skipPatient(p),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: kRedLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kRedBorder),
              ),
              child: const Text('Skip',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: kRedDark)),
            ),
          )
        else
          const Text('Waiting',
              style: TextStyle(fontSize: 12, color: kTextMuted, fontWeight: FontWeight.w500)),
      ]),
    );
  }

  // (kept for _HomeSessionFullscreenPage reuse via shared helpers)
  Widget _buildLiveQueueBar({
    required int? queueId,
    required QueueState queueState,
    required bool isEmergency,
    required List<AppointmentList> sessionPts,
  }) {
    if (queueState == QueueState.stopped) return const SizedBox.shrink();
    final isRunning = queueState == QueueState.running;
    final isPaused  = queueState == QueueState.paused;
    final bookingClosed = ref.watch(appointmentViewModelProvider).bookingClosed;

    final ip = sessionPts.where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress').firstOrNull;
    final booked = sessionPts.where((p) => (p.status?.toLowerCase() ?? '') == 'booked').toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current = ip ?? booked.firstOrNull;
    final next    = ip != null ? booked.firstOrNull : (booked.length > 1 ? booked[1] : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryLight),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pulseDot(),
            const SizedBox(width: 6),
            const Text('LIVE QUEUE',
                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1.1, color: kPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: kPrimaryLight, borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined, size: 10, color: kPrimaryDark),
                const SizedBox(width: 3),
                Text('${sessionPts.length}',
                    style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: kPrimaryDark)),
              ]),
            ),
            const Spacer(),
            _liveIconBtn(
              icon: isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              bg:    isRunning ? kAmberLight  : kPrimaryLight,
              border: isRunning ? kAmberBorder : const Color(0xFF9FE1CB),
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning ? () => _onQueuePause(queueId) : () => _onQueueStart(queueId),
            ),
            if (!isEmergency) ...[
              const SizedBox(width: 5),
              _liveIconBtn(
                icon: Icons.close_rounded,
                color: kRedDark, bg: kRedLight, border: kRedBorder,
                tooltip: 'Close queue',
                onTap: () => _showCloseDialog(queueId),
              ),
            ],
            const SizedBox(width: 5),
            _liveIconBtn(
              icon: Icons.warning_amber_rounded,
              color: kPurpleDark, bg: kPurpleLight, border: kPurpleBorder,
              tooltip: 'Emergency pause',
              onTap: () => _showEmergencyDialog(queueId),
            ),
            const SizedBox(width: 5),
            _liveIconBtn(
              icon: bookingClosed ? Icons.event_busy_rounded : Icons.event_available_rounded,
              color: bookingClosed ? kRedDark : kPrimaryDark,
              bg: bookingClosed ? kRedLight : kPrimaryLight,
              border: bookingClosed ? kRedBorder : const Color(0xFF9FE1CB),
              tooltip: bookingClosed
                  ? 'New bookings stopped — tap to resume accepting bookings. Patients already in the queue are not affected.'
                  : 'Stop new bookings for today — patients already in the queue keep being served as usual.',
              onTap: () => _onToggleBookingClosed(queueId, !bookingClosed),
            ),
          ]),
          // const SizedBox(height: 10),
          // Row(children: [
          //   _tokBox(label: 'CURRENT',   value: current != null ? (current.queueNumber ?? 0).toString().padLeft(2,'0') : '--', isActive: true),
          //   const SizedBox(width: 5),
          //   _tokBox(label: 'UP NEXT',   value: next != null ? (next.queueNumber ?? 0).toString().padLeft(2,'0') : '--'),
          //   const SizedBox(width: 5),
          //   _tokBox(label: 'REMAINING', value: sessionPts.length.toString().padLeft(2,'0'), isGreen: true),
          // ]),
        ]),
      ),
    );
  }

  Widget _liveIconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: bg, borderRadius: BorderRadius.circular(8),
              border: Border.all(color: border)),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );

  Widget _tokBox({required String label, required String value, bool isActive = false, bool isGreen = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive ? kPrimaryDark : isGreen ? kGreenLight : kPrimaryLighter,
            borderRadius: BorderRadius.circular(10),
            border: isActive ? null : Border.all(color: isGreen ? kGreenBorder : kPrimaryLight),
          ),
          child: Column(children: [
            Text(label, style: TextStyle(fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: .7,
                color: isActive ? Colors.white.withOpacity(0.75) : isGreen ? kGreenDark : kTextSecondary)),
            const SizedBox(height: 2),
            Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1,
                color: isActive ? Colors.white : isGreen ? kGreenDark : kTextPrimary)),
          ]),
        ),
      );

  // ─────────────────────────────────────────────────────────────────────────
  // DIALOGS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _showPauseOptionsDialog(int? queueId) async {
    await showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 48, height: 48,
              decoration: const BoxDecoration(color: kAmberLight, shape: BoxShape.circle),
              child: const Icon(Icons.pause_rounded, color: kAmberDark, size: 24),
            ),
            const SizedBox(height: 12),
            const Text('Pause Queue',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextPrimary)),
            const SizedBox(height: 6),
            const Text('Choose how you want to pause the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: kTextSecondary, height: 1.4)),
            const SizedBox(height: 20),
            // Pause
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                await _onQueuePause(queueId, confirmFirst: false);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kAmberLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kAmberBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Pause',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kAmberDark)),
              ),
            ),
            const SizedBox(height: 10),
            // Emergency Pause
            GestureDetector(
              onTap: () async {
                Navigator.of(ctx).pop();
                if (ref.read(appointmentViewModelProvider.notifier).isEmergencyPaused(queueId)) {
                  _snack('Already emergency paused');
                  return;
                }
                await _onQueuePauseEmergency(queueId);
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: kPurpleLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kPurpleBorder),
                ),
                alignment: Alignment.center,
                child: const Text('Emergency Pause',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kPurpleDark)),
              ),
            ),
            const SizedBox(height: 10),
            // Cancel
            GestureDetector(
              onTap: () => Navigator.of(ctx).pop(),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: const Text('Cancel',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextSecondary)),
              ),
            ),
          ]),
        ),
      ),
    );
  }

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
                    MaterialPageRoute(builder: (_) => DoctorAvailabilityPage(clinicId: _clinicId)))),
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
                    MaterialPageRoute(builder: (_) => DoctorAvailabilityPage(clinicId: _clinicId)))),
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
              MaterialPageRoute(builder: (_) => DoctorAvailabilityPage(clinicId: _clinicId))),
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

Widget _buildAwaitingBookingsState() {
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
          child: const Icon(Icons.hourglass_empty_rounded, color: kPrimaryDark, size: 22),
        ),
        const SizedBox(height: 10),
        const Text('No Appointments Yet',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: kTextPrimary)),
        const SizedBox(height: 4),
        const Text(
          'Your schedule is live for today, but no patients have booked yet.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: kTextSecondary, height: 1.35),
        ),
      ]),
    );
  }
  // ─────────────────────────────────────────────────────────────────────────
  // PATIENT CARDS
  // ─────────────────────────────────────────────────────────────────────────

  static const List<(Color, Color, Color)> _kAvatarPalettes = [
    (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)),
    (Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFF4C1D95)),
    (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFF78350F)),
    (Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFF7F1D1D)),
  ];

  Widget _buildPatientCard(
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
    // final VoidCallback? effectiveSkip = isBooked && queueActive && (isReceptionist || accessible)
    //     ? () => _skipPatient(p) : null;
    // final VoidCallback? effectiveSkip = queueActive && accessible && isBooked
    // ? () => _skipPatient(p) : null;
    final VoidCallback? effectiveSkip = isReceptionist
    ? (queueActive && isBooked ? () => _skipPatient(p) : null)
    : (queueActive && accessible && isBooked ? () => _skipPatient(p) : null);

    final (avBg, avBd, avFg) = _kAvatarPalettes[(p.queueNumber ?? 0) % _kAvatarPalettes.length];
    final Color borderColor = isIP ? kPrimary : isSkipped ? kAmber : kCardBorder;

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
          // if (!isReceptionist)
          //   Expanded(
          //     flex: 2,
          //     child: GestureDetector(
          //       onTap: effectiveAccessible ? () => _startSession(p) : null,
          if (!isReceptionist && effectiveAccessible)
  Expanded(
    flex: 2,
    child: GestureDetector(
      onTap: () => _startSession(p),
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

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Live'; bg = kPrimaryLight; fg = kPrimaryDark; dot = kPrimary; break;
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
// ARRIVED BLINK — highlights a skipped patient who tapped "I've Arrived"
// ─────────────────────────────────────────────────────────────────────────────

class _ArrivedBlinkBadge extends StatefulWidget {
  final Widget child;
  const _ArrivedBlinkBadge({required this.child});

  @override
  State<_ArrivedBlinkBadge> createState() => _ArrivedBlinkBadgeState();
}

class _ArrivedBlinkBadgeState extends State<_ArrivedBlinkBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 850))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) => Transform.scale(
        scale: 1.0 + 0.10 * _ctrl.value,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            boxShadow: [
              BoxShadow(
                color: kGreen.withOpacity(0.35 + 0.35 * _ctrl.value),
                blurRadius: 10 + 6 * _ctrl.value,
                spreadRadius: 1 + 2 * _ctrl.value,
              ),
            ],
          ),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN INLINE PANEL
// ─────────────────────────────────────────────────────────────────────────────

// ─────────────────────────────────────────────────────────────────────────────
// WALK-IN DIALOG
// ─────────────────────────────────────────────────────────────────────────────

class _WalkInDialog extends StatelessWidget {
  final VoidCallback onBooked;
  const _WalkInDialog({required this.onBooked});

  @override
  Widget build(BuildContext context) {
    final screenH = MediaQuery.of(context).size.height;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 40),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.white,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: screenH * 0.80),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // ── Header ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 10),
            child: Row(children: [
              Container(
                width: 32, height: 32,
                decoration: const BoxDecoration(color: kPrimaryLight, shape: BoxShape.circle),
                child: const Icon(Icons.person_add_rounded, size: 16, color: kPrimaryDark),
              ),
              const SizedBox(width: 10),
              const Text('Add Walk-in Patient',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: kTextPrimary)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded, size: 20, color: kTextSecondary),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              ),
            ]),
          ),
          const Divider(height: 1, color: kBorder),
          // ── Body ─────────────────────────────────────────────────────
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: _WalkInInlinePanel(onBooked: onBooked),
            ),
          ),
        ]),
      ),
    );
  }
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

  Timer? _mobileDebounce;

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
  ProviderSubscription<String?>? _clinicIdSub;

  @override
  void initState() {
    super.initState();
    _mobileCtr.addListener(_onMobileChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSessions());
    // Clinic switch madhe walk-in sessions/queue time stale rahu naye mhanun refresh
    _clinicIdSub = ref.listenManual<String?>(
      doctorLoginViewModelProvider.select((s) => s.clinic_id),
      (prev, next) {
        if (next != prev) {
          _selected = null;
          _mobileCtr.clear();
          _nameCtr.clear();
          _clearPatientState();
          _loadSessions();
        }
      },
    );
  }

  @override
  void dispose() {
    _mobileDebounce?.cancel();
    _mobileCtr.removeListener(_onMobileChanged);
    _nameCtr.dispose();
    _mobileCtr.dispose();
    _newMemberCtr.dispose();
    _clinicIdSub?.close();
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
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final doctorId = isReceptionist
        ? ref.read(receptionistLoginViewModelProvider).doctorId
        : ref.read(doctorLoginViewModelProvider).doctorId;
    final clinicId = ref.read(doctorLoginViewModelProvider).clinic_id
        ?? (isReceptionist ? ref.read(receptionistLoginViewModelProvider).clinicId : null);
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
            return mode == 1 || mode == 3; // queue only — exclude slots-only (mode 2)
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
    _mobileDebounce?.cancel();
    final digits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
    if (digits.length == 10) {
      _mobileDebounce = Timer(const Duration(milliseconds: 800), () => _lookupMobile(digits));
    } else if (_checkingMobile || _foundPatient != null || _resolvedPatientId != null ||
               _familyMemberId != null || _familyHeadPatientId != null || _bookError != null) {
      setState(() { _checkingMobile = false; _bookError = null; _clearPatientState(); });
    }
  }

  Future<void> _lookupMobile(String mobile) async {
    final api = _api;
    if (api == null) return;
    setState(() { _checkingMobile = true; });
    try {
      final results = await api.checkPhonePatient(mobile);
      if (!mounted) return;
      // Discard if user already changed/cleared the field
      final currentDigits = _mobileCtr.text.trim().replaceAll(RegExp(r'\D'), '');
      if (currentDigits != mobile) return;
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

    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final doctorId = isReceptionist
        ? ref.read(receptionistLoginViewModelProvider).doctorId
        : ref.read(doctorLoginViewModelProvider).doctorId;
    final clinicId = ref.read(doctorLoginViewModelProvider).clinic_id
        ?? (isReceptionist ? ref.read(receptionistLoginViewModelProvider).clinicId : null);
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

    bool _didBook = false;
    String? _successMsg;
    try {
      final isOnline = ref.read(connectivityNotifierProvider).isOnline;
      final resp = await ref.read(receptionistLoginViewModelProvider.notifier)
          .walkInBook(body, isOnline: isOnline);
      if (!mounted) return;
      if (resp.success == true) {
        _didBook = true;
        _successMsg = resp.message ?? 'Walk-in patient booked';
      } else {
        setState(() { _bookError = resp.message ?? 'Booking failed'; });
      }
    } catch (e) {
      if (mounted) setState(() { _bookError = e.toString().replaceFirst('Exception: ', ''); });
    } finally {
      if (mounted) setState(() { _booking = false; });
    }
    // Call onBooked() AFTER finally so the setState above completes before
    // the parent collapses this widget (prevents deactivated-ancestor crash).
    if (_didBook && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(_successMsg!),
        backgroundColor: kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ));
      _nameCtr.clear();
      _mobileCtr.clear();
      setState(() { _clearPatientState(); _selected = _todaySessions.length == 1 ? _todaySessions.first : null; });
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
                        Expanded(
                          child: Text(
                            'Today  ·  ${const ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'][DateTime.now().weekday - 1]}, ${DateTime.now().day} ${const ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'][DateTime.now().month - 1]}',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: kPrimary),
                            overflow: TextOverflow.ellipsis,
                          ),
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
                                Expanded(
                                  child: Text('${_foundPatient!.name}  ·  ${_foundPatient!.mobileNo ?? ''}',
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                          color: kPrimaryDark)),
                                ),
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
                                  Expanded(
                                    child: Text('Book for ${_foundPatient!.name}',
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                                            color: kPrimaryDark)),
                                  ),
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

// ─────────────────────────────────────────────────────────────────────────────
// HOME SESSION FULLSCREEN PAGE
// ─────────────────────────────────────────────────────────────────────────────

class _HomeSessionFullscreenPage extends ConsumerStatefulWidget {
  final int sessionIndex;
  final String? slotLabel;
  final QueueState queueState;
  final List<AppointmentList> sessionPts;
  final bool sessionHasIP;
  final bool isEmergency;
  final int? sessionNextQNo;
  final VoidCallback onQueueStart;
  final VoidCallback onQueuePause;
  final VoidCallback onQueueStop;
  final VoidCallback onQueueEmergency;
  final Function(AppointmentList) onStartSession;
  final Function(AppointmentList) onSkip;
  final Function(AppointmentList) onCancel;
  final Function(AppointmentList) onPrescription;

  const _HomeSessionFullscreenPage({
    required this.sessionIndex,
    this.slotLabel,
    required this.queueState,
    required this.sessionPts,
    required this.sessionHasIP,
    required this.isEmergency,
    this.sessionNextQNo,
    required this.onQueueStart,
    required this.onQueuePause,
    required this.onQueueStop,
    required this.onQueueEmergency,
    required this.onStartSession,
    required this.onSkip,
    required this.onCancel,
    required this.onPrescription,
  });

  @override
  ConsumerState<_HomeSessionFullscreenPage> createState() =>
      _HomeSessionFullscreenPageState();
}

class _HomeSessionFullscreenPageState
    extends ConsumerState<_HomeSessionFullscreenPage> {
  static const List<(Color, Color, Color)> _kAvatarPalettes = [
    (Color(0xFFE1F5EE), Color(0xFF9FE1CB), Color(0xFF085041)),
    (Color(0xFFEDE9FE), Color(0xFFDDD6FE), Color(0xFF4C1D95)),
    (Color(0xFFFEF3C7), Color(0xFFFDE68A), Color(0xFF78350F)),
    (Color(0xFFFEE2E2), Color(0xFFFECACA), Color(0xFF7F1D1D)),
  ];

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, parts[0].length.clamp(0, 2)).toUpperCase();
    }
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  int? _calcAge(String? dob) {
    if (dob == null) return null;
    final bd = DateTime.tryParse(dob);
    if (bd == null) return null;
    final now = DateTime.now();
    int age = now.year - bd.year;
    if (now.month < bd.month || (now.month == bd.month && now.day < bd.day)) {
      age--;
    }
    return age;
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.slotLabel ?? 'Session ${widget.sessionIndex + 1}';
    final pts = widget.sessionPts;
    final waiting = pts
        .where((p) => ['booked', 'in_progress', 'skipped']
            .contains(p.status?.toLowerCase()))
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final completed = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'completed')
        .toList();

    return Scaffold(
      backgroundColor: kPageBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Compact header ─────────────────────────────────────────
            Container(
              color: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Row(children: [
                IconButton(
                  icon: const Icon(Icons.close_fullscreen_rounded, size: 18),
                  onPressed: () => Navigator.pop(context),
                  color: kTextSecondary,
                  padding: const EdgeInsets.all(8),
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(width: 4),
                Expanded(
                    child: Text(title,
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary),
                        overflow: TextOverflow.ellipsis)),
                const SizedBox(width: 8),
                _queueStateBadge(widget.queueState),
                const SizedBox(width: 12),
              ]),
            ),
            const Divider(height: 1, color: kBorder),
            // ── Scrollable body ────────────────────────────────────────
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  _buildLiveQueueBar(),
                  if (waiting.isEmpty && completed.isEmpty)
                    _buildEmptyState()
                  else ...[
                    if (waiting.isNotEmpty) ...[
                      _sectionLabel('Waiting', waiting.length, kPrimary,
                          kPrimaryLight, kPrimaryDark),
                      const SizedBox(height: 8),
                      ...waiting.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildPatientCard(p),
                          )),
                    ],
                    if (completed.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      _sectionLabel('Completed', completed.length, kGreen,
                          kGreenLight, kGreenDark),
                      const SizedBox(height: 8),
                      ...completed.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: _buildCompletedCard(p),
                          )),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLiveQueueBar() {
    if (widget.queueState == QueueState.stopped) return const SizedBox.shrink();
    final isRunning = widget.queueState == QueueState.running;
    final isPaused = widget.queueState == QueueState.paused;
    final pts = widget.sessionPts;
    final ip = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'in_progress')
        .firstOrNull;
    final booked = pts
        .where((p) => (p.status?.toLowerCase() ?? '') == 'booked')
        .toList()
      ..sort((a, b) => (a.queueNumber ?? 0).compareTo(b.queueNumber ?? 0));
    final current = ip ?? booked.firstOrNull;
    final next = ip != null
        ? booked.firstOrNull
        : (booked.length > 1 ? booked[1] : null);

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          color: kPrimaryLighter,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kPrimaryLight),
        ),
        padding: const EdgeInsets.all(11),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _pulseDot(),
            const SizedBox(width: 6),
            const Text('LIVE QUEUE',
                style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                    color: kPrimary)),
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.people_alt_outlined,
                    size: 10, color: kPrimaryDark),
                const SizedBox(width: 3),
                Text('${pts.length}',
                    style: const TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDark)),
              ]),
            ),
            const Spacer(),
            _liveIconBtn(
              icon: isRunning
                  ? Icons.pause_rounded
                  : Icons.play_arrow_rounded,
              color: isRunning ? kAmberDark : kPrimaryDark,
              bg: isRunning ? kAmberLight : kPrimaryLight,
              border: isRunning ? kAmberBorder : const Color(0xFF9FE1CB),
              tooltip: isRunning ? 'Pause' : isPaused ? 'Resume' : 'Start',
              onTap: isRunning ? widget.onQueuePause : widget.onQueueStart,
            ),
            if (!widget.isEmergency) ...[
              const SizedBox(width: 5),
              _liveIconBtn(
                icon: Icons.close_rounded,
                color: kRedDark,
                bg: kRedLight,
                border: kRedBorder,
                tooltip: 'Close queue',
                onTap: widget.onQueueStop,
              ),
            ],
            const SizedBox(width: 5),
            _liveIconBtn(
              icon: Icons.warning_amber_rounded,
              color: kPurpleDark,
              bg: kPurpleLight,
              border: kPurpleBorder,
              tooltip: 'Emergency pause',
              onTap: widget.onQueueEmergency,
            ),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            _tokBox(
                label: 'CURRENT',
                value: current != null
                    ? (current.queueNumber ?? 0).toString().padLeft(2, '0')
                    : '--',
                isActive: true),
            const SizedBox(width: 5),
            _tokBox(
                label: 'UP NEXT',
                value: next != null
                    ? (next.queueNumber ?? 0).toString().padLeft(2, '0')
                    : '--'),
            const SizedBox(width: 5),
            _tokBox(
                label: 'REMAINING',
                value: pts.length.toString().padLeft(2, '0'),
                isGreen: true),
          ]),
        ]),
      ),
    );
  }

  Widget _buildPatientCard(AppointmentList p) {
    final isReceptionist = ref.read(tokenProvider).roleId == 3;
    final qs = widget.queueState;
    final hasIP = widget.sessionHasIP;
    final nextBookedQNo = widget.sessionNextQNo;
    final name = p.patientName ?? 'Patient';
    final initials = _initials(name);
    final age = _calcAge(p.dob);
    final status = p.status?.toLowerCase().trim() ?? '';
    final isIP = status == 'in_progress';
    final isSkipped = status == 'skipped';
    final isBooked = status == 'booked';
    final queueActive = qs == QueueState.running || qs == QueueState.paused;

    bool accessible = false;
    if (isIP) {
      accessible = true;
    } else if (isSkipped) {
      accessible = true;
    } else if (queueActive && isBooked) {
      accessible = !hasIP && p.queueNumber == nextBookedQNo;
    }
    final effectiveAccessible = isSkipped ? accessible : queueActive && accessible;
    final VoidCallback? effectiveSkip =
        isBooked && queueActive && (isReceptionist || accessible)
            ? () => widget.onSkip(p)
            : null;

    final (avBg, avBd, avFg) =
        _kAvatarPalettes[(p.queueNumber ?? 0) % _kAvatarPalettes.length];
    final Color borderColor =
        isIP ? kPrimary : isSkipped ? kAmber : kCardBorder;

    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: borderColor, width: (isIP || isSkipped) ? 1.5 : 1.0),
      ),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: avBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: avBd)),
            alignment: Alignment.center,
            child: Text(initials,
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: avFg)),
          ),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                        height: 1.15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                    [
                      if (p.gender != null) p.gender!,
                      if (age != null) '$age yrs'
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500)),
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
                  color: avBg,
                  borderRadius: BorderRadius.circular(9),
                  border: Border.all(color: avBd)),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('TOKEN',
                        style: TextStyle(
                            fontSize: 8,
                            color: kTextMuted,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 1),
                    Text(
                        (p.queueNumber ?? 0).toString().padLeft(2, '0'),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: avFg,
                            height: 1)),
                  ]),
            ),
          ],
        ]),
        const SizedBox(height: 8),
        Row(children: [
          if (effectiveSkip != null) ...[
            Expanded(
                child: GestureDetector(
              onTap: effectiveSkip,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                    color: kRedLight,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: kRedBorder)),
                alignment: Alignment.center,
                child: const Text('Skip',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: kRedDark)),
              ),
            )),
            if (!isReceptionist) const SizedBox(width: 7),
          ],
          if (!isReceptionist)
            Expanded(
              flex: 2,
              child: GestureDetector(
                onTap: effectiveAccessible
                    ? () => widget.onStartSession(p)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: effectiveAccessible
                        ? kPrimaryDark
                        : const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    isIP
                        ? 'Continue'
                        : isSkipped
                            ? 'Recall'
                            : 'Start Session',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
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

  Widget _buildCompletedCard(AppointmentList p) {
    final name = p.patientName ?? 'Patient';
    final initials = _initials(name);
    final age = _calcAge(p.dob);
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
            width: 36,
            height: 36,
            decoration: BoxDecoration(
                color: kGreenLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kGreenBorder)),
            alignment: Alignment.center,
            child: Text(initials,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kGreenDark)),
          ),
          const SizedBox(width: 9),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: kTextPrimary,
                        height: 1.15),
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(
                    [
                      if (p.gender != null) p.gender!,
                      if (age != null) '$age yrs'
                    ].join(' · '),
                    style: const TextStyle(
                        fontSize: 11,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500)),
              ])),
        ]),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () => widget.onPrescription(p),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
                color: kPurpleLight,
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: kPurpleBorder)),
            alignment: Alignment.center,
            child: const Text('View Prescription',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: kPurpleDark)),
          ),
        ),
      ]),
    );
  }

  Widget _buildEmptyState() => Container(
        padding: const EdgeInsets.symmetric(vertical: 36),
        alignment: Alignment.center,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: kPrimaryLight,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF9FE1CB))),
            child:
                const Icon(Icons.inbox_rounded, color: kPrimaryDark, size: 22),
          ),
          const SizedBox(height: 10),
          const Text('No patients today',
              style: TextStyle(
                  color: kTextMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w500)),
        ]),
      );

  Widget _sectionLabel(String label, int count, Color accent, Color accentLight,
          Color accentDark) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Row(children: [
          Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                  color: accent, borderRadius: BorderRadius.circular(3))),
          const SizedBox(width: 7),
          Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary)),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: accentLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.25))),
            child: Text('$count',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: accentDark)),
          ),
        ]),
      );

  Widget _queueStateBadge(QueueState state) {
    late String label;
    late Color bg, fg, dot;
    switch (state) {
      case QueueState.running:
        label = 'Running';
        bg = kPrimaryLight;
        fg = kPrimaryDark;
        dot = kPrimary;
        break;
      case QueueState.paused:
        label = 'Paused';
        bg = kAmberLight;
        fg = kAmberDark;
        dot = kAmber;
        break;
      case QueueState.stopped:
        label = 'Closed';
        bg = const Color(0xFFF1F5F9);
        fg = const Color(0xFF64748B);
        dot = const Color(0xFF94A3B8);
        break;
      case QueueState.idle:
        label = 'Idle';
        bg = kRedLight;
        fg = kRedDark;
        dot = kRed;
        break;
    }
    return _badgeDot(label, bg, fg, dot);
  }

  Widget _statusChip(String status) {
    Color bg, fg, dot;
    switch (status.toLowerCase()) {
      case 'in_progress':
        bg = kPrimaryLight;
        fg = kPrimaryDark;
        dot = kPrimary;
        break;
      case 'skipped':
        bg = kAmberLight;
        fg = kAmberDark;
        dot = kAmber;
        break;
      case 'completed':
        bg = kGreenLight;
        fg = kGreenDark;
        dot = kGreen;
        break;
      default:
        bg = kRedLight;
        fg = kRedDark;
        dot = kRed;
    }
    return _badgeDot(
      status == 'in_progress'
          ? 'In Progress'
          : status[0].toUpperCase() + status.substring(1),
      bg,
      fg,
      dot,
    );
  }

  Widget _badgeDot(String label, Color bg, Color fg, Color dot) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: dot.withOpacity(0.25))),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: dot, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.2,
                  color: fg)),
        ]),
      );

  Widget _liveIconBtn({
    required IconData icon,
    required Color color,
    required Color bg,
    required Color border,
    required String tooltip,
    required VoidCallback onTap,
  }) =>
      Tooltip(
        message: tooltip,
        preferBelow: false,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: border)),
            alignment: Alignment.center,
            child: Icon(icon, size: 15, color: color),
          ),
        ),
      );

  Widget _tokBox(
          {required String label,
          required String value,
          bool isActive = false,
          bool isGreen = false}) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          decoration: BoxDecoration(
            color: isActive
                ? kPrimaryDark
                : isGreen
                    ? kGreenLight
                    : kPrimaryLighter,
            borderRadius: BorderRadius.circular(10),
            border: isActive
                ? null
                : Border.all(
                    color: isGreen ? kGreenBorder : kPrimaryLight),
          ),
          child: Column(children: [
            Text(label,
                style: TextStyle(
                    fontSize: 7.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: .7,
                    color: isActive
                        ? Colors.white.withOpacity(0.75)
                        : isGreen
                            ? kGreenDark
                            : kTextSecondary)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1,
                    color: isActive
                        ? Colors.white
                        : isGreen
                            ? kGreenDark
                            : kTextPrimary)),
          ]),
        ),
      );

  Widget _pulseDot() => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0.4, end: 1.0),
        duration: const Duration(milliseconds: 900),
        builder: (_, v, child) => Opacity(opacity: v, child: child),
        onEnd: () => setState(() {}),
        child: Container(
          width: 7,
          height: 7,
          decoration: const BoxDecoration(color: kPrimary, shape: BoxShape.circle),
        ),
      );
}
