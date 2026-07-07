import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/domain/models/token_response.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';
import 'package:qless/presentation/shared/providers/viewModel_provider.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';
import 'package:qless/presentation/shared/widgets/connectivity_error_card.dart';

// ── Colour palette (matches login + patient registration) ─────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF1EA898);
const kPrimaryDarker = Color(0xFF158578);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kPrimaryGlow   = Color(0xFF4DD9C4);

const kBgSoft  = Color(0xFFF7FAFC);
const kSurface = Color(0xFFFFFFFF);
const kBg      = Color(0xFFF7FAFC);

const kTextPrimary   = Color(0xFF1A202C);
const kTextSecondary = Color(0xFF4A5568);
const kTextMuted     = Color(0xFF94A3B8);

const kBorder       = Color(0xFFF1F5F9);
const kBorderStrong = Color(0xFFE2E8F0);
const kDivider      = Color(0xFFE5E7EB);

const kError      = Color(0xFFFC8181);
const kRedLight   = Color(0xFFFEE2E2);
const kSuccess    = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kWarning    = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kPurple     = Color(0xFF9F7AEA);
const kPurpleLight= Color(0xFFEDE9FE);
const kInfo       = Color(0xFF3B82F6);
const kInfoLight  = Color(0xFFDBEAFE);

// ─── Schedule UI Models ──────────────────────────────────────────────────────
enum BookingMode { queue, slots, both }

class _TimeSlot {
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;
  int? maxQueueLength;

  _TimeSlot({
    required this.startTime,
    required this.endTime,
    this.bookingMode = BookingMode.queue,
    this.slotDurationMinutes = 15,
    this.maxQueueLength,
  });
}

class _DaySchedule {
  final String dayName;
  final String shortName;
  bool isEnabled;
  List<_TimeSlot> timeSlots;

  _DaySchedule({
    required this.dayName,
    required this.shortName,
    this.isEnabled = false,
    List<_TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? [];
}

// One "Add Slot" entry: a single Queue/Slot time range applied to whichever
// days were selected when it was added. Multiple blocks can target the same
// day (e.g. a morning Queue block and an evening Slots block on Monday).
class _ScheduleBlock {
  Set<int> dayIndices;
  TimeOfDay startTime;
  TimeOfDay endTime;
  BookingMode bookingMode;
  int slotDurationMinutes;
  int? maxQueueLength;

  _ScheduleBlock({
    required this.dayIndices,
    required this.startTime,
    required this.endTime,
    required this.bookingMode,
    required this.slotDurationMinutes,
    this.maxQueueLength,
  });
}

// ════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ════════════════════════════════════════════════════════════════════════════
class DoctorProfileSetupScreen extends ConsumerStatefulWidget {
  const DoctorProfileSetupScreen({super.key});

  @override
  ConsumerState<DoctorProfileSetupScreen> createState() =>
      _DoctorProfileSetupScreenState();
}

class _DoctorProfileSetupScreenState
    extends ConsumerState<DoctorProfileSetupScreen>
    with SingleTickerProviderStateMixin {
  int _step = 1;
  late AnimationController _animController;
  late Animation<double> _fadeAnim;

  // ── Step 1 & 2 Controllers ───────────────────────────────────────────────
  final _step1FormKey = GlobalKey<FormState>();
  final _step2FormKey = GlobalKey<FormState>();

  final _fullNameController        = TextEditingController();
  final _contactController         = TextEditingController();
  final _emailController           = TextEditingController();
  final _qualificationController   = TextEditingController();
  final _licenseController         = TextEditingController();
  final _experienceController      = TextEditingController();
  final _clinicNameController      = TextEditingController();
  final _clinicAddressController   = TextEditingController();
  final _clinicContactController   = TextEditingController();
  final _clinicEmailController     = TextEditingController();
  final _clinicWebsiteController   = TextEditingController();
  final _consultationFeeController = TextEditingController();

  final _fullNameFocus      = FocusNode();
  final _contactFocus       = FocusNode();
  final _emailFocus         = FocusNode();
  final _qualificationFocus = FocusNode();
  final _licenseFocus       = FocusNode();
  final _experienceFocus    = FocusNode();
  final _clinicNameFocus    = FocusNode();
  final _clinicAddressFocus = FocusNode();
  final _clinicContactFocus = FocusNode();
  final _clinicEmailFocus   = FocusNode();

  final _genderKey         = GlobalKey();
  final _specializationKey = GlobalKey();

  String  _selectedSpecialization = '';
  String? _selectedGender;
  int?    _selectedGenderId;

  File?       _doctorPhoto;
  List<File>  _clinicPhotos = [];
  String?     _fcmToken;
  double?     _latitude;
  double?     _longitude;
  StreamSubscription<String>? _tokenRefreshSub;

  Timer?  _mobileDebounce;
  String? _mobileExistsError;

  final ImagePicker _picker = ImagePicker();

  int?    _savedDoctorId;
  String? _savedClinicId;

  final List<Map<String, String>> _specializations = [
    {'value': 'general physician', 'label': 'General Physician'},
    {'value': 'cardiology',        'label': 'Cardiology'},
    {'value': 'dermatology',       'label': 'Dermatology'},
    {'value': 'pediatrics',        'label': 'Pediatrics'},
    {'value': 'orthopedics',       'label': 'Orthopedics'},
  ];

  // ── Step 3: Schedule state ────────────────────────────────────────────────
  static const _dayMeta = [
    ('Monday', 'MON'), ('Tuesday', 'TUE'), ('Wednesday', 'WED'),
    ('Thursday', 'THU'), ('Friday', 'FRI'), ('Saturday', 'SAT'),
    ('Sunday', 'SUN'),
  ];

  late List<_DaySchedule> _days;

  // Added schedule blocks — each is one Queue/Slot time range applied to the
  // days that were selected when it was added.
  final List<_ScheduleBlock> _blocks = [];

  // Draft: the day-group + Queue/Slot config currently being composed,
  // added to _blocks via the "Add Slot" button.
  final Set<int> _draftDays      = {};
  BookingMode _draftMode         = BookingMode.queue;
  TimeOfDay   _draftStart        = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay   _draftEnd          = const TimeOfDay(hour: 12, minute: 0);
  int         _draftSlotDuration = 15;
  int?        _draftMaxQueue;
  late final TextEditingController _draftQueueCtrl;

  int _leadHours   = 0;
  int _leadMinutes = 0;

  bool get _anyQueueEnabled {
    for (final d in _days) {
      if (!d.isEnabled) continue;
      for (final s in d.timeSlots) {
        if (s.bookingMode == BookingMode.queue ||
            s.bookingMode == BookingMode.both) return true;
      }
    }
    return false;
  }

  final List<Map<String, dynamic>> _genderOptions = const [
    {'id': 1, 'label': 'Male'},
    {'id': 2, 'label': 'Female'},
    {'id': 3, 'label': 'Other'},
  ];

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeIn);
    _animController.forward();

    _days = _dayMeta
        .map((m) => _DaySchedule(dayName: m.$1, shortName: m.$2))
        .toList();
    _draftQueueCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _animController.dispose();
    _tokenRefreshSub?.cancel();
    _mobileDebounce?.cancel();
    _draftQueueCtrl.dispose();
    _fullNameController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _qualificationController.dispose();
    _licenseController.dispose();
    _experienceController.dispose();
    _clinicNameController.dispose();
    _clinicAddressController.dispose();
    _clinicContactController.dispose();
    _clinicEmailController.dispose();
    _clinicWebsiteController.dispose();
    _consultationFeeController.dispose();
    _fullNameFocus.dispose();
    _contactFocus.dispose();
    _emailFocus.dispose();
    _qualificationFocus.dispose();
    _licenseFocus.dispose();
    _experienceFocus.dispose();
    _clinicNameFocus.dispose();
    _clinicAddressFocus.dispose();
    _clinicContactFocus.dispose();
    _clinicEmailFocus.dispose();
    super.dispose();
  }

  void _animateStep() {
    _animController.reset();
    _animController.forward();
  }

  // ── Mobile existence check ────────────────────────────────────────────────
  void _onContactChanged(String value) {
    _mobileDebounce?.cancel();
    final trimmed = value.trim();
    if (trimmed.length < 10) {
      if (_mobileExistsError != null) setState(() => _mobileExistsError = null);
      return;
    }
    _mobileDebounce = Timer(const Duration(milliseconds: 800), () async {
      if (ref.read(connectivityNotifierProvider).isOffline) {
        if (_mobileExistsError != null && mounted) {
          setState(() => _mobileExistsError = null);
        }
        return;
      }

      final result = await ref
          .read(doctorLoginViewModelProvider.notifier)
          .mobileExistDoctor(trimmed);
      if (!mounted) return;
      setState(() {
        _mobileExistsError =
            result.isNotEmpty ? 'Mobile number already registered.' : null;
      });
    });
  }

  // ── Image picker ──────────────────────────────────────────────────────────
  Future<void> _pickImage(bool isDoctorPhoto) async {
    if (!isDoctorPhoto && _clinicPhotos.length >= 5) {
      _showError('Maximum 5 clinic photos allowed.');
      return;
    }

    final source = await _showImageSourceSheet(isDoctorPhoto);
    if (source == null) return;

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );

    if (image != null) {
      setState(() {
        if (isDoctorPhoto) {
          _doctorPhoto = File(image.path);
        } else {
          _clinicPhotos.add(File(image.path));
        }
      });
    }
  }

  Future<ImageSource?> _showImageSourceSheet(bool isDoctorPhoto) {
    final title = isDoctorPhoto ? 'Doctor Photo' : 'Clinic Photo';
    return showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _ImageSourceSheet(title: title),
    );
  }

  // ── Location ──────────────────────────────────────────────────────────────
  Future<void> _getCurrentLocation() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        _showError('Location permission denied');
        return;
      }
    }
    if (permission == LocationPermission.deniedForever) {
      _showError(
          'Location permission permanently denied. Enable it in settings.');
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.high),
      );
      setState(() {
        _latitude  = position.latitude;
        _longitude = position.longitude;
      });
    } catch (_) {
      _showError('Failed to get location');
    }
  }

  Future<void> _selectFromMap() async {
    final result = await Navigator.push<gmap.LatLng>(
      context,
      MaterialPageRoute(
        builder: (_) => _MapPickerScreen(
          initialLatLng: (_latitude != null && _longitude != null)
              ? gmap.LatLng(_latitude!, _longitude!)
              : const gmap.LatLng(15.9073, 73.6990),
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _latitude  = result.latitude;
        _longitude = result.longitude;
      });
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  bool _isValidEmail(String email) =>
      RegExp(r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$')
          .hasMatch(email.trim());

  void _scrollToKey(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
        alignment: 0.15,
      );
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded,
              color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message,
                  style: const TextStyle(
                      fontSize: 13.5, fontWeight: FontWeight.w600))),
        ]),
        backgroundColor: kTextPrimary,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Schedule helpers ──────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  String _fmtTimeDisplay(TimeOfDay t) {
    final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  int _modeToInt(BookingMode m) => switch (m) {
        BookingMode.queue => 1,
        BookingMode.slots => 2,
        BookingMode.both  => 3,
      };

  DoctorScheduleModel _buildScheduleModel() {
    final doctorId = _savedDoctorId ?? 0;
    return DoctorScheduleModel(
      doctorId: doctorId,
      schedule: _days
          .map((day) => DayScheduleModel(
                day:       day.dayName,
                isEnabled: day.isEnabled ? 1 : 0,
                slots: day.timeSlots
                    .map((slot) => TimeSlotModel(
                          startTime:    _fmtTime(slot.startTime),
                          endTime:      _fmtTime(slot.endTime),
                          bookingMode:  _modeToInt(slot.bookingMode),
                          slotDuration: slot.bookingMode == BookingMode.queue
                              ? null
                              : slot.slotDurationMinutes,
                          maxQueueLength: slot.maxQueueLength,
                        ))
                    .toList(),
              ))
          .toList(),
    );
  }

  DoctorDetails _buildLeadTimeModel() {
    final doctorId        = _savedDoctorId ?? 0;
    final leadTimeMinutes = _leadHours * 60 + _leadMinutes;
    return DoctorDetails(
      doctorId: doctorId,
      leadTime: _anyQueueEnabled ? leadTimeMinutes : null,
    );
  }

  // ── Schedule mutations ────────────────────────────────────────────────────

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  // Rebuilds _days from _blocks: a day is Off (no slots) unless at least one
  // block includes it, in which case it gets every block's slot that
  // includes that day.
  void _rebuildDaysFromBlocks() {
    for (int i = 0; i < _days.length; i++) {
      final slots = _blocks
          .where((b) => b.dayIndices.contains(i))
          .map((b) => _TimeSlot(
                startTime: b.startTime,
                endTime: b.endTime,
                bookingMode: b.bookingMode,
                slotDurationMinutes: b.slotDurationMinutes,
                maxQueueLength: b.maxQueueLength,
              ))
          .toList();
      _days[i].timeSlots = slots;
      _days[i].isEnabled = slots.isNotEmpty;
    }
  }

  void _toggleDraftDay(int i) => setState(() {
        if (_draftDays.contains(i)) {
          _draftDays.remove(i);
        } else {
          _draftDays.add(i);
        }
      });

  Future<void> _pickDraftTimeRange() async {
    final result = await showModalBottomSheet<(TimeOfDay, TimeOfDay)>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _TimeRangePickerSheet(
        initialStart: _draftStart,
        initialEnd: _draftEnd,
      ),
    );
    if (result == null) return;
    setState(() {
      _draftStart = result.$1;
      _draftEnd   = result.$2;
    });
  }

  void _setDraftMode(BookingMode m) => setState(() => _draftMode = m);

  void _setDraftSlotDuration(int mins) =>
      setState(() => _draftSlotDuration = mins);

  void _setDraftMaxQueue(String val) => setState(
      () => _draftMaxQueue = val.isEmpty ? null : int.tryParse(val));

  // Commits the current draft as a new block. Day selection is kept as-is
  // (not cleared) so adding a second slot — e.g. Queue in the morning and
  // Slots in the evening — for the same days doesn't require reselecting them.
  void _addDraftAsBlock() {
    if (_draftDays.isEmpty) {
      _showError('Select at least one day for this slot.');
      return;
    }
    final draftS = _toMin(_draftStart);
    final draftE = _toMin(_draftEnd);
    for (final b in _blocks) {
      if (!b.dayIndices.any(_draftDays.contains)) continue;
      final bs = _toMin(b.startTime);
      final be = _toMin(b.endTime);
      if (draftS < be && bs < draftE) {
        final clashDays = b.dayIndices
            .where(_draftDays.contains)
            .map((i) => _days[i].shortName)
            .join(', ');
        _showError('This time overlaps with an existing slot on $clashDays.');
        return;
      }
    }
    setState(() {
      _blocks.add(_ScheduleBlock(
        dayIndices: Set.of(_draftDays),
        startTime: _draftStart,
        endTime: _draftEnd,
        bookingMode: _draftMode,
        slotDurationMinutes: _draftSlotDuration,
        maxQueueLength: _draftMaxQueue,
      ));
      _rebuildDaysFromBlocks();
    });
  }

  void _removeBlock(int index) => setState(() {
        _blocks.removeAt(index);
        _rebuildDaysFromBlocks();
      });

  // ── Submit handler ────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_step == 1) {
      // Run the form validator first so every invalid field shows its
      // red border / "required" error text, then focus/scroll to the
      // first offending one below.
      final step1Valid = _step1FormKey.currentState?.validate() ?? false;

      if (_fullNameController.text.trim().isEmpty) {
        _fullNameFocus.requestFocus();
        return _showError('Full name is required');
      }
      final contact = _contactController.text.trim();
      if (contact.isEmpty || contact.length != 10) {
        _contactFocus.requestFocus();
        return _showError(contact.isEmpty
            ? 'Contact No is required'
            : 'Enter a valid 10-digit number');
      }
      if (_emailController.text.trim().isNotEmpty &&
          !_isValidEmail(_emailController.text)) {
        _emailFocus.requestFocus();
        return _showError('Enter a valid email address');
      }
      if (_selectedGenderId == null || _selectedGenderId! <= 0) {
        _scrollToKey(_genderKey);
        return _showError('Gender is required');
      }
      if (_selectedSpecialization.isEmpty) {
        _scrollToKey(_specializationKey);
        return _showError('Specialization is required');
      }
      if (_qualificationController.text.trim().isEmpty) {
        _qualificationFocus.requestFocus();
        return _showError('Qualification is required');
      }
      if (_licenseController.text.trim().isEmpty) {
        _licenseFocus.requestFocus();
        return _showError('License No is required');
      }
      if (_experienceController.text.trim().isEmpty ||
          int.tryParse(_experienceController.text.trim()) == null) {
        _experienceFocus.requestFocus();
        return _showError(_experienceController.text.trim().isEmpty
            ? 'Experience is required'
            : 'Enter a valid number');
      }

      if (!step1Valid) return;

      if (_mobileExistsError != null) {
        _contactFocus.requestFocus();
        return _showError(_mobileExistsError!);
      }
      if (ref.read(connectivityNotifierProvider).isOffline) {
        return _showError(connectivityErrorMessage);
      }

      _mobileDebounce?.cancel();
      final mobileCheck = await ref
          .read(doctorLoginViewModelProvider.notifier)
          .mobileExistDoctor(_contactController.text.trim());
      if (!mounted) return;
      if (mobileCheck.isNotEmpty) {
        setState(() => _mobileExistsError = 'Mobile number already registered.');
        _contactFocus.requestFocus();
        return _showError('Mobile number already registered.');
      }
      setState(() => _mobileExistsError = null);

      setState(() => _step = 2);
      _animateStep();
      return;
    }

    if (_step == 2) {
      final step2Valid = _step2FormKey.currentState?.validate() ?? false;

      if (_clinicNameController.text.trim().isEmpty) {
        _clinicNameFocus.requestFocus();
        return _showError('Clinic name is required');
      }
      if (_clinicAddressController.text.trim().isEmpty) {
        _clinicAddressFocus.requestFocus();
        return _showError('Clinic address is required');
      }
      if (_clinicContactController.text.trim().isEmpty) {
        _clinicContactFocus.requestFocus();
        return _showError('Clinic contact is required');
      }
      if (_clinicEmailController.text.trim().isNotEmpty &&
          !_isValidEmail(_clinicEmailController.text)) {
        _clinicEmailFocus.requestFocus();
        return _showError('Enter a valid email');
      }

      if (!step2Valid) return;

      if (ref.read(connectivityNotifierProvider).isOffline) {
        return _showError(connectivityErrorMessage);
      }

      if (_fcmToken == null) {
        try {
          _fcmToken = await FirebaseMessaging.instance.getToken();
        } catch (e) {
          debugPrint('FCM token error: $e');
        }
      }

      final doctorPayload = DoctorDetails(
        name:            _fullNameController.text.trim(),
        mobile:          _contactController.text.trim(),
        email:           _emailController.text.trim(),
        genderId:        _selectedGenderId,
        specialization:  _selectedSpecialization,
        qualification:   _qualificationController.text.trim(),
        licenseNo:       _licenseController.text.trim(),
        experience:      int.tryParse(_experienceController.text.trim()),
        image:           _doctorPhoto?.path,
        clinicName:      _clinicNameController.text.trim(),
        clinicAddress:   _clinicAddressController.text.trim(),
        clinicContact:   _clinicContactController.text.trim(),
        clinicEmail:     _clinicEmailController.text.trim(),
        websiteName:     _clinicWebsiteController.text.trim(),
        consultationFee: _consultationFeeController.text.trim().isEmpty
            ? null
            : double.tryParse(_consultationFeeController.text.trim()),
        imageUrl: _clinicPhotos.isNotEmpty ? _clinicPhotos.first.path : null,
        latitude:  _latitude,
        longitude: _longitude,
        roleId:    1,
        Token:     _fcmToken,
      );

      await ref
          .read(doctorLoginViewModelProvider.notifier)
          .addDoctorDetails(
            doctorPayload,
            doctorImage: _doctorPhoto,
            clinicImages: _clinicPhotos.isNotEmpty ? _clinicPhotos : null,
          );

      final latestState = ref.read(doctorLoginViewModelProvider);
      if (latestState.error != null) {
        _showError(isConnectivityFailureMessage(latestState.error)
            ? connectivityErrorMessage
            : latestState.error!);
        return;
      }

      final returnedDoctorId = latestState.doctorId;
      final returnedClinicId = latestState.clinic_id;

      if (returnedDoctorId == null || returnedDoctorId <= 0) {
        _showError('Registration failed: could not retrieve Doctor ID.');
        return;
      }

      // Doctor + clinic now exist, but the app holds no JWT yet (registration
      // runs before login). Step 3's protected endpoints (saveDoctorSchedule /
      // addQueueStartTime) would 401 without it — so authenticate the new
      // doctor now and persist the token before continuing.
      final authResult = await ref
          .read(authViewModelProvider.notifier)
          .login(TokenResponse(
              mobile: _contactController.text.trim(), role: 'doctor'));
      if (authResult == null) {
        _showError(
            'Account created, but sign-in failed. Please log in to set your schedule.');
        return;
      }

      setState(() {
        _savedDoctorId = returnedDoctorId;
        _savedClinicId = returnedClinicId;
        _step          = 3;
      });
      _animateStep();
      return;
    }

    // STEP 3
    final hasAnySchedule =
        _days.any((d) => d.isEnabled && d.timeSlots.isNotEmpty);
    if (!hasAnySchedule) {
      _showError('Please select at least one working day and set its schedule.');
      return;
    }

    if (ref.read(connectivityNotifierProvider).isOffline) {
      return _showError(connectivityErrorMessage);
    }

    await ref
        .read(doctorSettingsViewModelProvider.notifier)
        .saveDoctorSchedule(_buildScheduleModel(), clinicId: _savedClinicId);

    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .updateLeadTime(_buildLeadTimeModel());

    final schedErr = ref.read(doctorSettingsViewModelProvider).errorMessage;
    if (schedErr.isNotEmpty) {
      _showError(isConnectivityFailureMessage(schedErr)
          ? connectivityErrorMessage
          : schedErr);
      return;
    }

    if (_anyQueueEnabled && _savedDoctorId != null) {
      final leadTimeMinutes = _leadHours * 60 + _leadMinutes;
      await ref
          .read(doctorLoginViewModelProvider.notifier)
          .updateLeadTime(DoctorDetails(
            doctorId: _savedDoctorId,
            leadTime: leadTimeMinutes,
          ));

      final leadErr = ref.read(doctorLoginViewModelProvider).error;
      if (leadErr != null) {
        _showError(isConnectivityFailureMessage(leadErr)
            ? connectivityErrorMessage
            : 'Schedule saved, but lead time update failed: $leadErr');
      }
    }

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state      = ref.watch(doctorLoginViewModelProvider);
    final schedState = ref.watch(doctorSettingsViewModelProvider);
    final isLoading  = state.isLoading || schedState.isLoading;

    return Scaffold(
      backgroundColor: kBg,
      appBar: _SimpleTitleBar(
        title: 'Doctor Profile Setup',
        subtitle: 'Step $_step of 3',
        onBack: () {
          if (_step > 1) {
            setState(() => _step -= 1);
            _animateStep();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        child: Stack(
          children: [
            FadeTransition(
              opacity: _fadeAnim,
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _StepProgressBar(currentStep: _step),
                    const SizedBox(height: 22),
                    const ConnectivityErrorCard(),
                    if (_step == 1) _buildStep1(),
                    if (_step == 2) _buildStep2(),
                    if (_step == 3) _buildStep3(),
                    const SizedBox(height: 26),
                    _PrimaryButton(
                      label: _step == 1
                          ? 'Continue'
                          : _step == 2
                              ? 'Register Clinic'
                              : 'Complete Setup',
                      icon: _step == 3
                          ? Icons.check_circle_outline_rounded
                          : Icons.arrow_forward_rounded,
                      onPressed: _handleSubmit,
                    ),
                    const SizedBox(height: 16),
                    const _SecureFooter(),
                  ],
                ),
              ),
            ),
            if (isLoading)
              Container(
                color: Colors.black.withOpacity(0.35),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const SizedBox(
                      width: 30,
                      height: 30,
                      child: CircularProgressIndicator(
                          color: kPrimary, strokeWidth: 2.6),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ─── Step 1: Personal & Professional Info ─────────────────────────────────
  Widget _buildStep1() {
    return Form(
      key: _step1FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Basic Details card
          _SectionCard(
            icon: Icons.person_outline_rounded,
            iconBg: kPrimaryLight,
            iconColor: kPrimaryDark,
            title: 'Basic Details',
            subtitle: 'Your personal information',
            children: [
              _buildField('Full Name', _fullNameController,
                  hint: 'Dr. Arjun Sharma',
                  required: true,
                  focusNode: _fullNameFocus,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Full name is required'
                      : null),
              _buildField('Contact No', _contactController,
                  hint: '9876543210',
                  keyboard: TextInputType.phone,
                  required: true,
                  focusNode: _contactFocus,
                  onChanged: _onContactChanged,
                  errorText: _mobileExistsError,
                  prefixWidget: const _PhonePrefix(),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Contact No is required';
                    if (v.trim().length != 10) return 'Enter a valid 10-digit number';
                    return null;
                  }),
              _buildField('Email Address', _emailController,
                  hint: 'doctor@email.com',
                  icon: Icons.email_outlined,
                  keyboard: TextInputType.emailAddress,
                  focusNode: _emailFocus,
                  validator: (v) {
                    if (v != null && v.trim().isNotEmpty && !_isValidEmail(v)) {
                      return 'Enter a valid email address';
                    }
                    return null;
                  }),
              Container(
                key: _genderKey,
                child: const _FieldLabel(label: 'Gender', required: true),
              ),
              const SizedBox(height: 10),
              _GenderSelector(
                options: _genderOptions
                    .map((e) => e['label'] as String)
                    .toList(),
                selected: _selectedGender,
                onChanged: (val) => setState(() {
                  _selectedGender = val;
                  _selectedGenderId = _genderOptions
                      .firstWhere((e) => e['label'] == val)['id'] as int;
                }),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Professional Info card
          _SectionCard(
            icon: Icons.workspace_premium_outlined,
            iconBg: kInfoLight,
            iconColor: kInfo,
            title: 'Professional Info',
            subtitle: 'Your credentials and expertise',
            children: [
              _buildSpecializationDropdown(),
              _buildField('Qualification', _qualificationController,
                  hint: 'MBBS, MD...',
                  icon: Icons.school_outlined,
                  required: true,
                  focusNode: _qualificationFocus,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Qualification is required'
                      : null),
              Row(
                children: [
                  Expanded(
                    child: _buildField('License No', _licenseController,
                        hint: 'MCI-XXXXX',
                        icon: Icons.badge_outlined,
                        required: true,
                        focusNode: _licenseFocus,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'License No is required'
                            : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                        'Experience (yrs)', _experienceController,
                        hint: 'e.g. 8',
                        icon: Icons.work_history_outlined,
                        keyboard: TextInputType.number,
                        required: true,
                        focusNode: _experienceFocus,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Experience is required';
                          if (int.tryParse(v.trim()) == null) return 'Enter a valid number';
                          return null;
                        }),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Step 2: Clinic Details ───────────────────────────────────────────────
  Widget _buildStep2() {
    return Form(
      key: _step2FormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clinic photos
          _ClinicPhotoGrid(
            photos: _clinicPhotos,
            onAdd: () => _pickImage(false),
            onRemove: (i) => setState(() => _clinicPhotos.removeAt(i)),
            onPreview: (i) => _previewClinicPhoto(_clinicPhotos[i]),
          ),
          const SizedBox(height: 18),

          // Clinic Details card
          _SectionCard(
            icon: Icons.local_hospital_outlined,
            iconBg: kPrimaryLight,
            iconColor: kPrimaryDark,
            title: 'Clinic Details',
            subtitle: 'Where your patients can find you',
            children: [
              _buildField('Clinic Name', _clinicNameController,
                  hint: 'Apollo Clinic',
                  icon: Icons.business_outlined,
                  required: true,
                  focusNode: _clinicNameFocus,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Clinic name is required'
                      : null),
              _buildTextArea(
                  'Clinic Address', _clinicAddressController,
                  hint: '123, MG Road, Panaji, Goa',
                  required: true,
                  focusNode: _clinicAddressFocus,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Clinic address is required'
                      : null),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                        'Clinic Contact', _clinicContactController,
                        hint: '9876543210',
                        keyboard: TextInputType.phone,
                        required: true,
                        icon: Icons.phone_outlined,
                        focusNode: _clinicContactFocus,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Clinic contact is required'
                            : null),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                        'Clinic Email', _clinicEmailController,
                        hint: 'clinic@...',
                        icon: Icons.email_outlined,
                        keyboard: TextInputType.emailAddress,
                        focusNode: _clinicEmailFocus,
                        validator: (v) {
                          if (v != null && v.trim().isNotEmpty && !_isValidEmail(v)) {
                            return 'Enter a valid email';
                          }
                          return null;
                        }),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: _buildField(
                        'Website', _clinicWebsiteController,
                        hint: 'www.clinic.com',
                        icon: Icons.language_outlined),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildField(
                        'Fee (₹)', _consultationFeeController,
                        hint: '500',
                        icon: Icons.currency_rupee_rounded,
                        keyboard: TextInputType.number),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Location card
          _SectionCard(
            icon: Icons.location_on_outlined,
            iconBg: kAmberLight,
            iconColor: kWarning,
            title: 'Clinic Location',
            subtitle: 'Pin your clinic on the map',
            children: [_buildLocationField()],
          ),
        ],
      ),
    );
  }

  // ─── Step 3: Schedule ─────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedDoctorId != null) ...[
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: kGreenLight,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: kSuccess.withOpacity(0.4)),
            ),
            child: Row(children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.check_circle_rounded,
                    color: kSuccess, size: 18),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Profile Registered!',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF15803D),
                      ),
                    ),
                    // Text(
                    //   'Doctor ID: $_savedDoctorId'
                    //   '${_savedClinicId != null ? '  •  Clinic: $_savedClinicId' : ''}',
                    //   style: const TextStyle(
                    //     fontSize: 11,
                    //     color: Color(0xFF166534),
                    //     fontWeight: FontWeight.w500,
                    //   ),
                    // ),
                  ],
                ),
              ),
            ]),
          ),
          const SizedBox(height: 18),
        ],

        _SectionCard(
          icon: Icons.calendar_month_outlined,
          iconBg: kPrimaryLight,
          iconColor: kPrimaryDark,
          title: 'Weekly Schedule',
          subtitle: 'Pick days, set Queue/Slot timing, then Add Slot',
          children: [
            if (_blocks.isNotEmpty) ...[
              ..._blocks.asMap().entries.map(
                    (e) => _buildBlockSummaryCard(e.key, e.value),
                  ),
              const SizedBox(height: 4),
              const Divider(height: 24, color: kDivider),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Days for this slot',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: kTextSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                if (_draftDays.isNotEmpty)
                  GestureDetector(
                    onTap: () => setState(_draftDays.clear),
                    child: const Text(
                      'Clear days',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDark,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _buildDraftDaySelector(),
            const SizedBox(height: 16),
            _buildDraftScheduleConfig(),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _addDraftAsBlock,
                icon: const Icon(Icons.add_rounded, size: 17),
                label: const Text(
                  'Add Slot',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kPrimaryDark,
                  side: BorderSide(
                      color: kPrimary.withOpacity(0.5), width: 1.4),
                  backgroundColor: kPrimaryLight.withOpacity(0.4),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(11)),
                ),
              ),
            ),
            if (_blocks.isEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: kBgSoft,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorderStrong),
                ),
                child: const Text(
                  'Select days, set the Queue/Slot timing, then tap "Add '
                  'Slot" to apply it to those days. Days you never add a '
                  'slot for stay Off.',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: kTextSecondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),

        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _anyQueueEnabled
              ? Padding(
                  padding: const EdgeInsets.only(top: 18),
                  child: _SectionCard(
                    icon: Icons.access_time_rounded,
                    iconBg: kAmberLight,
                    iconColor: kWarning,
                    title: 'Queue Lead Time',
                    subtitle:
                        'How early patients can join the queue',
                    children: [_buildLeadTimeRow()],
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildDraftDaySelector() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _days.asMap().entries.map((e) {
        final i = e.key;
        final day = e.value;
        final sel = _draftDays.contains(i);
        return GestureDetector(
          onTap: () => _toggleDraftDay(i),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              gradient: sel
                  ? const LinearGradient(colors: [kPrimary, kPrimaryDark])
                  : null,
              color: sel ? null : kBgSoft,
              borderRadius: BorderRadius.circular(11),
              border: Border.all(color: sel ? kPrimary : kBorderStrong),
            ),
            child: Column(
              children: [
                Text(
                  day.shortName,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: sel ? Colors.white : kTextSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  day.isEnabled ? 'Set' : 'Off',
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w700,
                    color: sel ? Colors.white70 : kTextMuted,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  String _fmtBlockDays(_ScheduleBlock b) {
    final indices = b.dayIndices.toList()..sort();
    return indices.map((i) => _days[i].shortName).join(', ');
  }

  Widget _buildBlockSummaryCard(int index, _ScheduleBlock block) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kPrimary.withOpacity(0.45), width: 1.4),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(10),
            ),
            alignment: Alignment.center,
            child: Icon(_modeIcon(block.bookingMode),
                size: 16, color: kPrimaryDark),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _fmtBlockDays(block),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_fmtTimeDisplay(block.startTime)} - '
                  '${_fmtTimeDisplay(block.endTime)}  •  '
                  '${_modeLabel(block.bookingMode)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: kPrimaryDark,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => _removeBlock(index),
            child: Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: kRedLight,
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.close_rounded, size: 14, color: kError),
            ),
          ),
        ],
      ),
    );
  }

  String _modeLabel(BookingMode m) => switch (m) {
        BookingMode.queue => 'Queue',
        BookingMode.slots => 'Slots',
        BookingMode.both  => 'Both',
      };

  IconData _modeIcon(BookingMode m) => switch (m) {
        BookingMode.queue => Icons.queue_rounded,
        BookingMode.slots => Icons.event_available_rounded,
        BookingMode.both  => Icons.all_inclusive_rounded,
      };

  Widget _buildDraftScheduleConfig() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBgSoft,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: kBorderStrong),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TimeRangePicker(
            start: _fmtTimeDisplay(_draftStart),
            end: _fmtTimeDisplay(_draftEnd),
            onTap: _pickDraftTimeRange,
          ),
          const SizedBox(height: 12),
          const Text(
            'Booking Mode',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: BookingMode.values.asMap().entries.map((e) {
              final mode = e.value;
              final isLast = e.key == BookingMode.values.length - 1;
              final sel = _draftMode == mode;
              return Expanded(
                child: GestureDetector(
                  onTap: () => _setDraftMode(mode),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    margin: EdgeInsets.only(right: isLast ? 0 : 7),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    decoration: BoxDecoration(
                      gradient: sel
                          ? const LinearGradient(
                              colors: [kPrimary, kPrimaryDark])
                          : null,
                      color: sel ? null : Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: sel ? kPrimary : kBorderStrong),
                      boxShadow: sel
                          ? [
                              BoxShadow(
                                color: kPrimary.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_modeIcon(mode),
                            size: 13,
                            color: sel ? Colors.white : kTextSecondary),
                        const SizedBox(width: 4),
                        Text(
                          _modeLabel(mode),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: sel ? Colors.white : kTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          if (_draftMode == BookingMode.queue ||
              _draftMode == BookingMode.both) ...[
            const SizedBox(height: 12),
            const Text(
              'Max Queue Length',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            Container(
              height: 42,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorderStrong),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 11),
                  const Icon(Icons.people_alt_rounded,
                      size: 16, color: kPrimaryDark),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _draftQueueCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1A1D2E)),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'e.g. 20',
                        hintStyle:
                            TextStyle(fontSize: 13.5, color: kTextMuted),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: _setDraftMaxQueue,
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                        color: kPrimaryLight,
                        borderRadius: BorderRadius.circular(7)),
                    child: const Text(
                      'patients',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (_draftMode == BookingMode.slots ||
              _draftMode == BookingMode.both) ...[
            const SizedBox(height: 12),
            const Text(
              'Slot Duration',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: kTextSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 7),
            _SlotDurationPicker(
              value: _draftSlotDuration,
              onChanged: _setDraftSlotDuration,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLeadTimeRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: kAmberLight,
            borderRadius: BorderRadius.circular(11),
          ),
          child: const Icon(Icons.timer_outlined,
              color: kWarning, size: 22),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lead Time',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: kTextPrimary,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Hours : Minutes',
                style: TextStyle(fontSize: 11, color: kTextMuted),
              ),
            ],
          ),
        ),
        Column(
          children: [
            const Row(
              children: [
                SizedBox(
                    width: 50,
                    child: Center(
                        child: Text('HH',
                            style: TextStyle(
                                fontSize: 10, color: kTextMuted)))),
                SizedBox(width: 12),
                SizedBox(
                    width: 50,
                    child: Center(
                        child: Text('MM',
                            style: TextStyle(
                                fontSize: 10, color: kTextMuted)))),
              ],
            ),
            const SizedBox(height: 3),
            Row(
              children: [
                _WheelPicker(
                  key: ValueKey('leadH_$_leadHours'),
                  value: _leadHours,
                  max: 24,
                  onChanged: (v) => setState(() => _leadHours = v),
                ),
                const SizedBox(width: 6),
                const Text(':',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: kTextPrimary,
                    )),
                const SizedBox(width: 6),
                _WheelPicker(
                  key: ValueKey('leadM_$_leadMinutes'),
                  value: _leadMinutes,
                  max: 60,
                  onChanged: (v) => setState(() => _leadMinutes = v),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  // ─── Field Builders ───────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    IconData? icon,
    ValueChanged<String>? onChanged,
    String? errorText,
    Widget? prefixWidget,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            keyboardType: keyboard,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            validator: validator,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
              prefixIcon: prefixWidget ??
                  (icon != null
                      ? Icon(icon, color: kTextMuted, size: 19)
                      : null),
              filled: true,
              fillColor: kBgSoft,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: kError)
                    : const BorderSide(color: kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: errorText != null
                    ? const BorderSide(color: kError, width: 1.6)
                    : const BorderSide(color: kPrimary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError, width: 1.6),
              ),
              errorStyle: const TextStyle(
                  fontSize: 9.5, color: kError, fontWeight: FontWeight.w600),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 6),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 13, color: kError),
              const SizedBox(width: 5),
              Expanded(
                child: Text(errorText,
                    style: const TextStyle(
                        fontSize: 9.5,
                        color: kError,
                        fontWeight: FontWeight.w600)),
              ),
            ]),
          ],
        ],
      ),
    );
  }

  Widget _buildTextArea(
    String label,
    TextEditingController controller, {
    String hint = '',
    bool required = false,
    String? Function(String?)? validator,
    FocusNode? focusNode,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 8),
          TextFormField(
            controller: controller,
            focusNode: focusNode,
            maxLines: 3,
            validator: validator,
            style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF1A1D2E),
                fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: kTextMuted, fontSize: 13.5),
              filled: true,
              fillColor: kBgSoft,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kBorderStrong),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kPrimary, width: 1.6),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: kError, width: 1.6),
              ),
              errorStyle: const TextStyle(
                  fontSize: 9.5, color: kError, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecializationDropdown() {
    return Padding(
      key: _specializationKey,
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(label: 'Specialization', required: true),
          const SizedBox(height: 8),
          Container(
            height: 50,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: kBgSoft,
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: _selectedSpecialization.isNotEmpty
                    ? kPrimary
                    : kBorderStrong,
                width: _selectedSpecialization.isNotEmpty ? 1.6 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(Icons.medical_services_outlined,
                    color:
                        _selectedSpecialization.isNotEmpty
                            ? kPrimaryDark
                            : kTextMuted,
                    size: 19),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedSpecialization.isEmpty
                          ? null
                          : _selectedSpecialization,
                      hint: const Text('Select specialization',
                          style: TextStyle(
                              color: kTextMuted, fontSize: 13.5)),
                      isExpanded: true,
                      icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: kTextMuted),
                      style: const TextStyle(
                          fontSize: 14,
                          color: kTextPrimary,
                          fontWeight: FontWeight.w600),
                      items: _specializations
                          .map((s) => DropdownMenuItem<String>(
                                value: s['value'],
                                child: Text(s['label']!),
                              ))
                          .toList(),
                      onChanged: (val) => setState(() =>
                          _selectedSpecialization = val ?? ''),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationField() {
    final hasLocation = _latitude != null && _longitude != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: Container(
              height: 50,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: hasLocation ? kPrimaryLight : kBgSoft,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                  color: hasLocation ? kPrimary : kBorderStrong,
                  width: hasLocation ? 1.6 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 17,
                  color: hasLocation ? kPrimaryDark : kTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                        : 'No location selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasLocation ? kPrimaryDarker : kTextMuted,
                      fontWeight: hasLocation
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.my_location_rounded,
            tooltip: 'Use GPS',
            onTap: _getCurrentLocation,
          ),
          const SizedBox(width: 8),
          _LocationButton(
            icon: Icons.map_outlined,
            tooltip: 'Pick on map',
            onTap: _selectFromMap,
          ),
        ]),
      ],
    );
  }

  void _previewClinicPhoto(File photo) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(children: [
          InteractiveViewer(
            child: Center(child: Image.file(photo, fit: BoxFit.contain)),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(18)),
                child: const Icon(Icons.close_rounded,
                    color: Colors.white, size: 18),
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SIMPLE TITLE BAR
// ═════════════════════════════════════════════════════════════════════════════
class _SimpleTitleBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final String subtitle;
  final VoidCallback onBack;

  const _SimpleTitleBar({
    required this.title,
    required this.subtitle,
    required this.onBack,
  });

  @override
  Size get preferredSize => const Size.fromHeight(74);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kSurface,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Container(
          height: 74,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
          decoration: const BoxDecoration(
            color: kSurface,
            border: Border(bottom: BorderSide(color: kBorder, width: 1)),
          ),
          child: Row(
            children: [
              Material(
                color: kBgSoft,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                  side: const BorderSide(color: kBorderStrong, width: 0.5),
                ),
                child: InkWell(
                  onTap: onBack,
                  borderRadius: BorderRadius.circular(11),
                  child: const SizedBox(
                    width: 38,
                    height: 38,
                    child: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 16,
                      color: kTextPrimary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.medical_services_outlined,
                        size: 11, color: kPrimaryDarker),
                    SizedBox(width: 5),
                    Text(
                      'Doctor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: kPrimaryDarker,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// STEP PROGRESS BAR
// ═════════════════════════════════════════════════════════════════════════════
class _StepProgressBar extends StatelessWidget {
  final int currentStep;
  const _StepProgressBar({required this.currentStep});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _StepDot(
            number: 1,
            label: 'Personal',
            state: currentStep == 1
                ? _StepDotState.active
                : _StepDotState.done,
          ),
          _stepLine(currentStep >= 2),
          _StepDot(
            number: 2,
            label: 'Clinic',
            state: currentStep == 2
                ? _StepDotState.active
                : currentStep > 2
                    ? _StepDotState.done
                    : _StepDotState.pending,
          ),
          _stepLine(currentStep >= 3),
          _StepDot(
            number: 3,
            label: 'Schedule',
            state: currentStep == 3
                ? _StepDotState.active
                : _StepDotState.pending,
          ),
        ],
      ),
    );
  }

  Widget _stepLine(bool active) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: active ? kPrimary : kBorderStrong,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}

enum _StepDotState { active, done, pending }

class _StepDot extends StatelessWidget {
  final int number;
  final String label;
  final _StepDotState state;

  const _StepDot({
    required this.number,
    required this.label,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    Color circleBg;
    Color circleFg;
    Color labelColor;
    Widget content;

    switch (state) {
      case _StepDotState.active:
        circleBg = kPrimary;
        circleFg = Colors.white;
        labelColor = kPrimaryDarker;
        content = Text(
          '$number',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: circleFg),
        );
      case _StepDotState.done:
        circleBg = kPrimaryLight;
        circleFg = kPrimaryDark;
        labelColor = kPrimaryDark;
        content = const Icon(Icons.check_rounded, size: 14, color: kPrimaryDark);
      case _StepDotState.pending:
        circleBg = kBgSoft;
        circleFg = kTextMuted;
        labelColor = kTextMuted;
        content = Text(
          '$number',
          style: TextStyle(
              fontSize: 12, fontWeight: FontWeight.w700, color: circleFg),
        );
    }

    final isActive = state == _StepDotState.active;

    return Column(
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: isActive ? 30 : 26,
          height: isActive ? 30 : 26,
          decoration: BoxDecoration(
            color: circleBg,
            shape: BoxShape.circle,
            border: state == _StepDotState.pending
                ? Border.all(color: kBorderStrong, width: 1)
                : null,
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          alignment: Alignment.center,
          child: content,
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight:
                isActive ? FontWeight.w800 : FontWeight.w700,
            color: labelColor,
          ),
        ),
      ],
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// SECTION CARD
// ═════════════════════════════════════════════════════════════════════════════
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String title;
  final String subtitle;
  final List<Widget> children;

  const _SectionCard({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Icon(icon, color: iconColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            letterSpacing: -0.3,
                          )),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: kTextSecondary,
                            fontWeight: FontWeight.w500,
                          )),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(color: kBorder, height: 22, thickness: 1),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// PRIMARY BUTTON (gradient CTA)
// ═════════════════════════════════════════════════════════════════════════════
class _PrimaryButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  const _PrimaryButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [kPrimary, kPrimaryDark],
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: kPrimary.withOpacity(0.35),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(icon, color: Colors.white, size: 19),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// DOCTOR AVATAR PICKER
// ═════════════════════════════════════════════════════════════════════════════
class _DoctorAvatarPicker extends StatelessWidget {
  final File? photo;
  final VoidCallback onTap;
  const _DoctorAvatarPicker({required this.photo, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 104,
                height: 104,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: photo == null
                      ? const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [kPrimaryLight, Colors.white],
                        )
                      : null,
                  color: photo != null ? Colors.white : null,
                  border: Border.all(
                    color: photo != null ? kPrimary : kBorderStrong,
                    width: photo != null ? 2.5 : 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.18),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: photo != null
                    ? ClipOval(
                        child: Image.file(photo!,
                            fit: BoxFit.cover, width: 104, height: 104),
                      )
                    : const Icon(Icons.medical_services_outlined,
                        size: 42, color: kPrimaryDark),
              ),
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryDark],
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2.5),
                  boxShadow: [
                    BoxShadow(
                      color: kPrimary.withOpacity(0.35),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(Icons.camera_alt_rounded,
                    color: Colors.white, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            photo != null ? 'Change Photo' : 'Upload Doctor Photo',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: photo != null ? kPrimaryDark : kTextPrimary,
              letterSpacing: -0.1,
            ),
          ),
          const SizedBox(height: 2),
          const Text(
            'Tap to add or change',
            style: TextStyle(
                fontSize: 11,
                color: kTextMuted,
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// CLINIC PHOTO GRID
// ═════════════════════════════════════════════════════════════════════════════
class _ClinicPhotoGrid extends StatelessWidget {
  final List<File> photos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final ValueChanged<int> onPreview;

  const _ClinicPhotoGrid({
    required this.photos,
    required this.onAdd,
    required this.onRemove,
    required this.onPreview,
  });

  @override
  Widget build(BuildContext context) {
    final canAdd = photos.length < 5;
    return Container(
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: kBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: kTextPrimary.withOpacity(0.04),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: kPurpleLight,
                  borderRadius: BorderRadius.circular(11),
                ),
                child: const Icon(Icons.photo_library_outlined,
                    color: kPurple, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Clinic Photos',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: kTextPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    Text(
                      'Showcase your space (${photos.length}/5)',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: kTextSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(color: kBorder, height: 22, thickness: 1),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              ...List.generate(
                photos.length,
                (i) => _PhotoThumb(
                  file: photos[i],
                  onRemove: () => onRemove(i),
                  onTap: () => onPreview(i),
                ),
              ),
              if (canAdd)
                GestureDetector(
                  onTap: onAdd,
                  child: Container(
                    width: 86,
                    height: 86,
                    decoration: BoxDecoration(
                      color: kPrimaryLight.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: kPrimary.withOpacity(0.4),
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: const [
                        Icon(Icons.add_photo_alternate_outlined,
                            color: kPrimaryDark, size: 28),
                        SizedBox(height: 4),
                        Text('Add',
                            style: TextStyle(
                                fontSize: 11.5,
                                color: kPrimaryDarker,
                                fontWeight: FontWeight.w700)),
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

class _PhotoThumb extends StatelessWidget {
  final File file;
  final VoidCallback onRemove;
  final VoidCallback onTap;

  const _PhotoThumb({
    required this.file,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 86,
        height: 86,
        child: Stack(
          children: [
            GestureDetector(
              onTap: onTap,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: Image.file(file,
                    width: 86, height: 86, fit: BoxFit.cover),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: kTextPrimary.withOpacity(0.85),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Icon(Icons.close_rounded,
                      color: Colors.white, size: 13),
                ),
              ),
            ),
          ],
        ),
      );
}

// Single tappable field showing the whole Start→End range; opens
// _TimeRangePickerSheet so both ends are picked together in one step.
class _TimeRangePicker extends StatelessWidget {
  final String start, end;
  final VoidCallback onTap;
  const _TimeRangePicker(
      {required this.start, required this.end, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: kBorderStrong),
          ),
          child: Row(
            children: [
              const Icon(Icons.access_time_rounded,
                  size: 15, color: kPrimaryDark),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$start  →  $end',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: kTextPrimary,
                  ),
                ),
              ),
              const Icon(Icons.keyboard_arrow_down_rounded,
                  size: 18, color: kTextMuted),
            ],
          ),
        ),
      );
}

// Bottom sheet letting the user set Start and End together, in one step,
// via two side-by-side time wheels. Confirms with a single "Done" tap.
class _TimeRangePickerSheet extends StatefulWidget {
  final TimeOfDay initialStart;
  final TimeOfDay initialEnd;
  const _TimeRangePickerSheet(
      {required this.initialStart, required this.initialEnd});

  @override
  State<_TimeRangePickerSheet> createState() => _TimeRangePickerSheetState();
}

class _TimeRangePickerSheetState extends State<_TimeRangePickerSheet> {
  late TimeOfDay _start = widget.initialStart;
  late TimeOfDay _end   = widget.initialEnd;

  DateTime _toDateTime(TimeOfDay t) => DateTime(2024, 1, 1, t.hour, t.minute);

  bool get _isValid =>
      (_start.hour * 60 + _start.minute) < (_end.hour * 60 + _end.minute);

  Widget _buildWheel(String label, TimeOfDay value, ValueChanged<TimeOfDay> onChange) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: kTextSecondary,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 160,
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.time,
              use24hFormat: false,
              initialDateTime: _toDateTime(value),
              onDateTimeChanged: (dt) =>
                  onChange(TimeOfDay(hour: dt.hour, minute: dt.minute)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.all(12),
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: kBorderStrong,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const Text(
              'Select Time Range',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: kTextPrimary,
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                _buildWheel('Start', _start, (v) => setState(() => _start = v)),
                _buildWheel('End', _end, (v) => setState(() => _end = v)),
              ],
            ),
            if (!_isValid) ...[
              const SizedBox(height: 8),
              const Text(
                'End time must be after start time.',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kError,
                ),
              ),
            ],
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isValid
                    ? () => Navigator.pop(context, (_start, _end))
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kPrimary,
                  disabledBackgroundColor: kBorderStrong,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotDurationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  static const _opts = [10, 15, 20, 30, 45, 60];
  const _SlotDurationPicker(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7,
        runSpacing: 7,
        children: _opts.map((min) {
          final sel = value == min;
          return GestureDetector(
            onTap: () => onChanged(min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                  horizontal: 13, vertical: 7),
              decoration: BoxDecoration(
                gradient: sel
                    ? const LinearGradient(
                        colors: [kPrimary, kPrimaryDark],
                      )
                    : null,
                color: sel ? null : Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                    color: sel ? kPrimary : kBorderStrong),
              ),
              child: Text(
                '${min}m',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: sel ? Colors.white : kTextSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      );
}

// ─── Wheel Picker ─────────────────────────────────────────────────────────
class _WheelPicker extends StatefulWidget {
  final int value, max;
  final ValueChanged<int> onChanged;
  const _WheelPicker(
      {super.key,
      required this.value,
      required this.max,
      required this.onChanged});

  @override
  State<_WheelPicker> createState() => _WheelPickerState();
}

class _WheelPickerState extends State<_WheelPicker> {
  late final FixedExtentScrollController _ctrl;
  late int _cur;

  @override
  void initState() {
    super.initState();
    _cur = widget.value.clamp(0, widget.max - 1);
    _ctrl = FixedExtentScrollController(initialItem: _cur);
  }

  @override
  void didUpdateWidget(covariant _WheelPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final target = widget.value.clamp(0, widget.max - 1);
      final delta = (target - _cur).abs();
      if (delta <= 3) {
        _ctrl.animateToItem(target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOutCubic);
      } else {
        _ctrl.jumpToItem(target);
      }
      _cur = target;
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 50,
        height: 50,
        child: ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.white,
              Colors.white,
              Colors.transparent
            ],
            stops: [0.0, 0.25, 0.75, 1.0],
          ).createShader(bounds),
          blendMode: BlendMode.dstIn,
          child: ListWheelScrollView.useDelegate(
            itemExtent: 30,
            diameterRatio: 2.0,
            perspective: 0.002,
            physics: const FixedExtentScrollPhysics(),
            controller: _ctrl,
            onSelectedItemChanged: (i) {
              HapticFeedback.selectionClick();
              setState(() => _cur = i);
              widget.onChanged(i);
            },
            childDelegate: ListWheelChildBuilderDelegate(
              childCount: widget.max,
              builder: (_, i) {
                final sel = i == _cur;
                return Center(
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 160),
                    style: TextStyle(
                      fontSize: sel ? 17 : 12,
                      fontWeight:
                          sel ? FontWeight.w800 : FontWeight.w500,
                      color: sel ? kPrimaryDark : kTextMuted,
                    ),
                    child: Text(i.toString().padLeft(2, '0')),
                  ),
                );
              },
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═════════════════════════════════════════════════════════════════════════════
class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel({required this.label, this.required = false});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w500,
              color: kTextPrimary,
              letterSpacing: 0.1,
            ),
          ),
          if (required) ...[
            const SizedBox(width: 3),
            const Text('*',
                style: TextStyle(
                    color: kError,
                    fontSize: 13,
                    fontWeight: FontWeight.w800)),
          ],
        ],
      );
}

class _PhonePrefix extends StatelessWidget {
  const _PhonePrefix();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('🇮🇳', style: TextStyle(fontSize: 16)),
          SizedBox(width: 6),
          Text(
            '+91',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w700,
              color: kTextPrimary,
            ),
          ),
          SizedBox(width: 8),
          SizedBox(
            height: 22,
            child: VerticalDivider(
                color: kBorderStrong, width: 1, thickness: 1),
          ),
          SizedBox(width: 2),
        ],
      ),
    );
  }
}

class _LocationButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  const _LocationButton(
      {required this.icon,
      required this.tooltip,
      required this.onTap});

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(13),
            child: Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(
                    color: kPrimary.withOpacity(0.3), width: 1),
              ),
              child: Icon(icon, color: kPrimaryDark, size: 20),
            ),
          ),
        ),
      );
}

class _GenderSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _GenderSelector(
      {required this.options,
      required this.selected,
      required this.onChanged});

  static const _iconMap = {
    'male': Icons.male_rounded,
    'female': Icons.female_rounded,
    'other': Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) => Row(
        children: List.generate(options.length, (i) {
          final label = options[i];
          final icon = _iconMap[label.toLowerCase()] ??
              Icons.person_outline_rounded;
          final isSelected = selected == label;
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: i < options.length - 1 ? 7 : 0),
              child: GestureDetector(
                onTap: () => onChanged(label),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  height: 56,
                  decoration: BoxDecoration(
                    color: isSelected ? kPrimaryLight : kBgSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected ? kPrimary : kBorderStrong,
                      width: isSelected ? 1.8 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: kPrimary.withOpacity(0.18),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : [],
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? kPrimaryDarker : kTextSecondary,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: isSelected
                              ? kPrimaryDarker
                              : kTextSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      );
}

class _SecureFooter extends StatelessWidget {
  const _SecureFooter();

  @override
  Widget build(BuildContext context) => const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: kTextMuted),
          SizedBox(width: 6),
          Text(
            'Your data is protected and encrypted',
            style: TextStyle(
              fontSize: 11.5,
              color: kTextMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// IMAGE SOURCE BOTTOM SHEET
// ═════════════════════════════════════════════════════════════════════════════
class _ImageSourceSheet extends StatelessWidget {
  final String title;
  const _ImageSourceSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 28,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 44,
            height: 4,
            decoration: BoxDecoration(
                color: kBorderStrong,
                borderRadius: BorderRadius.circular(2)),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(11)),
                  child: const Icon(Icons.add_photo_alternate_outlined,
                      color: kPrimaryDark, size: 20),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Upload Photo',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: kTextPrimary,
                            letterSpacing: -0.3)),
                    const SizedBox(height: 1),
                    Text(title,
                        style: const TextStyle(
                            fontSize: 12, color: kTextSecondary)),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: _SourceTile(
                    icon: Icons.camera_alt_rounded,
                    iconColor: kPrimary,
                    iconBg: kPrimaryLight,
                    label: 'Camera',
                    subtitle: 'Take photo',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceTile(
                    icon: Icons.photo_library_rounded,
                    iconColor: kPurple,
                    iconBg: kPurpleLight,
                    label: 'Gallery',
                    subtitle: 'Pick photo',
                    onTap: () =>
                        Navigator.pop(context, ImageSource.gallery),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: kBgSoft,
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: kTextSecondary)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor, iconBg;
  final String label, subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 18),
            decoration: BoxDecoration(
                color: iconBg.withOpacity(0.5),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: iconBg)),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle),
                  child: Icon(icon, color: iconColor, size: 26),
                ),
                const SizedBox(height: 10),
                Text(label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: iconColor)),
                const SizedBox(height: 2),
                Text(subtitle,
                    style: const TextStyle(
                        fontSize: 11, color: kTextSecondary)),
              ],
            ),
          ),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// MAP PICKER SCREEN
// ═════════════════════════════════════════════════════════════════════════════
class _MapPickerScreen extends StatefulWidget {
  final gmap.LatLng initialLatLng;
  const _MapPickerScreen({required this.initialLatLng});

  @override
  State<_MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<_MapPickerScreen> {
  late gmap.LatLng _selected;
  gmap.GoogleMapController? _mapController;

  final _searchCtrl = TextEditingController();
  final _focusNode = FocusNode();

  static const _apiKey = 'AIzaSyDTRL5VzQ9UAwsCB9uCbSNj5wZasYHjFKA';

  List<Map<String, dynamic>> _predictions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialLatLng;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _focusNode.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _predictions = [];
        _showSuggestions = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeComponent(query)}'
        '&components=country:in'
        '&language=en'
        '&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions = List<Map<String, dynamic>>.from(data['predictions']);
          _showSuggestions = _predictions.isNotEmpty;
        });
      } else {
        setState(() {
          _predictions = [];
          _showSuggestions = false;
        });
      }
    } catch (e) {
      debugPrint('Places search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    _focusNode.unfocus();
    setState(() => _showSuggestions = false);
    _searchCtrl.text = prediction['description'] ?? '';
    try {
      final placeId = prediction['place_id'];
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId&fields=geometry&key=$_apiKey',
      );
      final response = await http.get(url);
      final data = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final loc = data['result']['geometry']['location'];
        final latLng = gmap.LatLng(loc['lat'], loc['lng']);
        setState(() => _selected = latLng);
        _mapController?.animateCamera(
          gmap.CameraUpdate.newCameraPosition(
            gmap.CameraPosition(target: latLng, zoom: 15),
          ),
        );
      }
    } catch (e) {
      debugPrint('Place detail error: $e');
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _predictions = [];
      _showSuggestions = false;
    });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: kBg,
        appBar: _SimpleTitleBar(
          title: 'Select Location',
          subtitle: 'Pin your clinic on the map',
          onBack: () => Navigator.pop(context),
        ),
        body: Stack(
          children: [
            gmap.GoogleMap(
              initialCameraPosition:
                  gmap.CameraPosition(target: _selected, zoom: 14),
              onMapCreated: (ctrl) => _mapController = ctrl,
              onTap: (latLng) {
                _focusNode.unfocus();
                setState(() {
                  _selected = latLng;
                  _showSuggestions = false;
                });
              },
              markers: {
                gmap.Marker(
                  markerId: const gmap.MarkerId('selected'),
                  position: _selected,
                ),
              },
              myLocationEnabled: true,
              myLocationButtonEnabled: true,
              zoomControlsEnabled: true,
            ),
            // Search
            Positioned(
              top: 12,
              left: 12,
              right: 12,
              child: Column(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x18000000),
                            blurRadius: 14,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
                      decoration: InputDecoration(
                        hintText: 'Search for a place...',
                        hintStyle: const TextStyle(
                            fontSize: 14, color: kTextMuted),
                        prefixIcon: _isSearching
                            ? const Padding(
                                padding: EdgeInsets.all(12),
                                child: SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: kPrimary)),
                              )
                            : const Icon(Icons.search_rounded,
                                color: kPrimaryDark, size: 20),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.close_rounded,
                                    color: kTextMuted, size: 18),
                                onPressed: _clearSearch,
                              )
                            : null,
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                      ),
                    ),
                  ),
                  if (_showSuggestions)
                    Container(
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x18000000),
                              blurRadius: 14,
                              offset: Offset(0, 4)),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: _predictions.length,
                          separatorBuilder: (_, __) =>
                              const Divider(height: 1, color: kBorder),
                          itemBuilder: (_, i) {
                            final p = _predictions[i];
                            final mainText = p['structured_formatting']
                                    ?['main_text'] ??
                                p['description'] ??
                                '';
                            final secondText = p['structured_formatting']
                                    ?['secondary_text'] ??
                                '';
                            return InkWell(
                              onTap: () => _selectPrediction(p),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 12),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 32,
                                      height: 32,
                                      decoration: BoxDecoration(
                                        color: kPrimaryLight,
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                          Icons.location_on_rounded,
                                          color: kPrimaryDark,
                                          size: 16),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(mainText,
                                              style: const TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w700,
                                                  color: kTextPrimary),
                                              maxLines: 1,
                                              overflow:
                                                  TextOverflow.ellipsis),
                                          if (secondText.isNotEmpty) ...[
                                            const SizedBox(height: 2),
                                            Text(secondText,
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color: kTextSecondary),
                                                maxLines: 1,
                                                overflow:
                                                    TextOverflow.ellipsis),
                                          ],
                                        ],
                                      ),
                                    ),
                                    const Icon(
                                        Icons.north_west_rounded,
                                        size: 14,
                                        color: kTextMuted),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                ],
              ),
            ),
            // Bottom coordinates + confirm
            Positioned(
              bottom: 24,
              left: 16,
              right: 16,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: kPrimary.withOpacity(0.3)),
                      boxShadow: const [
                        BoxShadow(
                            color: Color(0x14000000),
                            blurRadius: 16,
                            offset: Offset(0, 4)),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: const BoxDecoration(
                              color: kPrimaryLight,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.location_on_rounded,
                              color: kPrimaryDark, size: 20),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Selected coordinates',
                                style: TextStyle(
                                    fontSize: 11, color: kTextSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selected.latitude.toStringAsFixed(6)}, '
                                '${_selected.longitude.toStringAsFixed(6)}',
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: kTextPrimary),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  _PrimaryButton(
                    label: 'Confirm Location',
                    icon: Icons.check_rounded,
                    onPressed: () => Navigator.pop(context, _selected),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}
