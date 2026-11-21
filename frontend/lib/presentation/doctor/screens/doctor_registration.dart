import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qless/core/fcm_token.dart';
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
import 'package:qless/presentation/doctor/screens/doctor_bottom_nav.dart';
import 'package:qless/presentation/shared/providers/connectivity_notifier.dart';
import 'package:qless/presentation/shared/providers/view_model_provider.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';
import 'package:qless/presentation/shared/widgets/connectivity_error_card.dart';
import 'package:qless/presentation/shared/widgets/otp_verify_sheet.dart';

part 'doctor_registration/draft_day_selector.dart';
part 'doctor_registration/shared.dart';
part 'doctor_registration/time_range_picker_sheet.dart';
part 'doctor_registration/map_picker_screen.dart';

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
  final List<File>  _clinicPhotos = [];
  String?     _fcmToken;
  double?     _latitude;
  double?     _longitude;
  StreamSubscription<String>? _tokenRefreshSub;

  Timer?  _mobileDebounce;
  String? _mobileExistsError;
  final _otpTickets = OtpTicketCache();

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
            s.bookingMode == BookingMode.both) {
          return true;
        }
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

      // S14: prove the doctor owns this mobile before creating the account.
      // The server echoes the verified ticket back for the auto sign-in below.
      final signupTicket = await _otpTickets.obtain(
          context, ref, _contactController.text.trim());
      if (!mounted || signupTicket == null) return;

      if (_fcmToken == null) {
        try {
          _fcmToken = await getFcmTokenSafe();
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
            loginTicket: signupTicket,
          );

      final latestState = ref.read(doctorLoginViewModelProvider);
      if (latestState.error != null) {
        _showError(isConnectivityFailureMessage(latestState.error)
            ? connectivityErrorMessage
            : latestState.error!);
        return;
      }

      final returnedDoctorId = latestState.doctorId;
      final returnedClinicId = latestState.clinicId;

      if (returnedDoctorId == null || returnedDoctorId <= 0) {
        _showError('Registration failed: could not retrieve Doctor ID.');
        return;
      }

      // Doctor + clinic now exist, but the app holds no JWT yet (registration
      // runs before login). Step 3's protected endpoints (saveDoctorSchedule /
      // addQueueStartTime) would 401 without it — so authenticate the new
      // doctor now and persist the token before continuing. The signup ticket
      // is still valid (5 min), so this doesn't need a second OTP.
      final authResult = await ref.read(authViewModelProvider.notifier).login(
          TokenResponse(
              mobile: _contactController.text.trim(),
              role: 'doctor',
              loginTicket: signupTicket));
      if (authResult == null) {
        // Step 3 can't save without a session — send them to log in instead
        // of leaving them on step 2, where resubmitting would re-register.
        _showError(
            'Account created, but sign-in failed. Please log in to set your schedule.');
        if (mounted) _goToLogin();
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

    // Already signed in after step 2 — load the profile the way OTP login
    // does and go straight into the app instead of back to login.
    final vm = ref.read(doctorLoginViewModelProvider.notifier);
    await vm.checkPhoneDoctor(_contactController.text.trim());
    if (_savedDoctorId != null) await vm.getDoctorClinics(_savedDoctorId!);
    if (!mounted) return;
    if ((ref.read(doctorLoginViewModelProvider).doctorId ?? 0) <= 0) {
      return _goToLogin();
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const DoctorBottomNav()),
      (_) => false,
    );
  }

  void _goToLogin() => Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (_) => false,
      );

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final state      = ref.watch(doctorLoginViewModelProvider);
    final schedState = ref.watch(doctorSettingsViewModelProvider);
    final isLoading  = state.isLoading || schedState.isLoading;

    // Once the doctor + clinic are saved (step 3), going back would let the
    // user re-submit step 2 and create a duplicate doctor/clinic. Lock back.
    final backLocked = _step == 3;

    return PopScope(
      canPop: !backLocked,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (backLocked) {
          _showError(
              'Your clinic is registered. Please complete the schedule to finish setup.');
        }
      },
      child: Scaffold(
      backgroundColor: kBg,
      appBar: _SimpleTitleBar(
        title: 'Doctor Profile Setup',
        subtitle: 'Step $_step of 3',
        onBack: backLocked
            ? null
            : () {
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
                color: Colors.black.withValues(alpha: 0.35),
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
              border: Border.all(color: kSuccess.withValues(alpha: 0.4)),
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
                      color: kPrimary.withValues(alpha: 0.5), width: 1.4),
                  backgroundColor: kPrimaryLight.withValues(alpha: 0.4),
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

  String _fmtBlockDays(_ScheduleBlock b) {
    final indices = b.dayIndices.toList()..sort();
    return indices.map((i) => _days[i].shortName).join(', ');
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
