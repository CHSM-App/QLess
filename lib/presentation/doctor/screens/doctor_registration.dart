

// ─── Color Palette ───────────────────────────────────────────────────────────
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/domain/models/doctor_schedule_model.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/shared/screens/login_screen.dart';

const kPrimaryBlue  = Color(0xFF1A73E8);
const kLightBlue    = Color(0xFFE8F0FE);
const kAccentGreen  = Color(0xFF34A853);
const kRedAccent    = Color(0xFFEA4335);
const kSurface      = Color(0xFFF8F9FA);
const kCardBg       = Color(0xFFFFFFFF);
const kTextDark     = Color(0xFF1F2937);
const kTextMuted    = Color(0xFF6B7280);
const kDivider      = Color(0xFFE5E7EB);

// Schedule colours (teal palette from availability page)
const kSchedPrimary       = Color(0xFF26C6B0);
const kSchedPrimaryDark   = Color(0xFF2BB5A0);
const kSchedPrimaryLight  = Color(0xFFD9F5F1);
const kSchedError         = Color(0xFFFC8181);
const kSchedRedLight      = Color(0xFFFEE2E2);
const kSchedSuccess       = Color(0xFF68D391);
const kSchedGreenLight    = Color(0xFFDCFCE7);
const kSchedBorder        = Color(0xFFEDF2F7);
const kSchedTextPrimary   = Color(0xFF2D3748);
const kSchedTextSecondary = Color(0xFF718096);
const kSchedTextMuted     = Color(0xFFA0AEC0);

const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);

const kBorder = Color(0xFFEDF2F7);
const kBg = Color(0xFFF7F8FA);

const kSuccess = Color(0xFF68D391);
const kGreenLight = Color(0xFFDCFCE7);
const kGreenDark = Color(0xFF276749);

const kError = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);
const kRedDark = Color(0xFFC53030);

const kWarning = Color(0xFFF6AD55);
const kAmberLight = Color(0xFFFEF3C7);
const kAmberDark = Color(0xFF975A16);

// ════════════════════════════════════════════════════════════════════
//  BREAKPOINTS
// ════════════════════════════════════════════════════════════════════
const _kTabletBreak = 650.0;
const _kDesktopBreak = 1050.0;
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
  bool isExpanded;
  List<_TimeSlot> timeSlots;

  _DaySchedule({
    required this.dayName,
    required this.shortName,
    this.isEnabled = false,
    this.isExpanded = false,
    List<_TimeSlot>? timeSlots,
  }) : timeSlots = timeSlots ?? [];
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

  String  _selectedSpecialization = '';
  String? _selectedGender;
  int?    _selectedGenderId;

  File?  _doctorPhoto;
  File?  _clinicPhoto;
  String? _fcmToken;
  double? _latitude;
  double? _longitude;
  StreamSubscription<String>? _tokenRefreshSub;

  Timer?  _mobileDebounce;
  String? _mobileExistsError;

  final ImagePicker _picker = ImagePicker();

  // IDs returned from Step 2 API (clinic registration response)
  int?    _savedDoctorId;
  String? _savedClinicId;

  final List<Map<String, String>> _specializations = [
    {'value': 'general physician',     'label': 'General Physician'},
    {'value': 'cardiology',  'label': 'Cardiology'},
    {'value': 'dermatology', 'label': 'Dermatology'},
    {'value': 'pediatrics',  'label': 'Pediatrics'},
    {'value': 'orthopedics', 'label': 'Orthopedics'},
  ];

  // ── Step 3: Schedule state ────────────────────────────────────────────────
  static const _dayMeta = [
    ('Monday', 'MON'), ('Tuesday', 'TUE'), ('Wednesday', 'WED'),
    ('Thursday', 'THU'), ('Friday', 'FRI'), ('Saturday', 'SAT'),
    ('Sunday', 'SUN'),
  ];

  late List<_DaySchedule> _days;

  int  _leadHours   = 0;
  int  _leadMinutes = 0;

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

  // ── Init / Dispose ────────────────────────────────────────────────────────
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

    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   if (!mounted) return;
    //   ref.read(masterViewModelProvider.notifier).fetchGenderList();
    // });
  }


  @override
  void dispose() {
    _animController.dispose();
    _tokenRefreshSub?.cancel();
    _mobileDebounce?.cancel();
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

  // ── Image Picker – Camera + Gallery bottom sheet ──────────────────────────
  //
  // Shows a bottom sheet with two options: Camera and Gallery.
  // [isDoctorPhoto] true  → sets _doctorPhoto
  //                false → sets _clinicPhoto
  Future<void> _pickImage(bool isDoctorPhoto) async {
    final source = await _showImageSourceSheet(isDoctorPhoto);
    if (source == null) return; // user dismissed

    final XFile? image = await _picker.pickImage(
      source: source,
      imageQuality: 85, // compress slightly to keep upload size reasonable
    );

    if (image != null) {
      setState(() {
        if (isDoctorPhoto) {
          _doctorPhoto = File(image.path);
        } else {
          _clinicPhoto = File(image.path);
        }
      });
    }
  }

  /// Shows a bottom sheet and returns [ImageSource.camera] or
  /// [ImageSource.gallery], or null when the user taps outside.
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
      _showError('Location permission permanently denied. Enable it in settings.');
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
  final result = await Navigator.push<gmap.LatLng>(  // ← gmap.LatLng
    context,
    MaterialPageRoute(
      builder: (_) => _MapPickerScreen(
        initialLatLng: (_latitude != null && _longitude != null)
            ? gmap.LatLng(_latitude!, _longitude!)        // ← gmap.LatLng
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
  bool _isBlank(TextEditingController c) => c.text.trim().isEmpty;

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          const Icon(Icons.error_outline_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
              child: Text(message, style: const TextStyle(fontSize: 13))),
        ]),
        backgroundColor: kRedAccent,
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // ── Schedule helpers ──────────────────────────────────────────────────────
  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  int _modeToInt(BookingMode m) => switch (m) {
        BookingMode.queue  => 1,
        BookingMode.slots  => 2,
        BookingMode.both   => 3,
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
                          startTime:      _fmtTime(slot.startTime),
                          endTime:        _fmtTime(slot.endTime),
                          bookingMode:    _modeToInt(slot.bookingMode),
                          slotDuration:   slot.bookingMode == BookingMode.queue
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
  void _toggleDay(int i, bool v) => setState(() {
        _days[i].isEnabled  = v;
        if (!v) _days[i].isExpanded = false;
      });

  void _toggleExpand(int i) => setState(() {
        if (_days[i].isEnabled) _days[i].isExpanded = !_days[i].isExpanded;
      });

  void _addSlot(int i) => setState(() {
        _days[i].timeSlots.add(_TimeSlot(
          startTime: const TimeOfDay(hour: 9, minute: 0),
          endTime:   const TimeOfDay(hour: 12, minute: 0),
        ));
        _days[i].isExpanded = true;
      });

  void _removeSlot(int di, int si) => setState(() {
        _days[di].timeSlots.removeAt(si);
        if (_days[di].timeSlots.isEmpty) {
          _days[di].isEnabled  = false;
          _days[di].isExpanded = false;
        }
      });

  void _updateSlot(int di, int si, _TimeSlot updated) =>
      setState(() => _days[di].timeSlots[si] = updated);

  // ── Submit handler ────────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    // ── STEP 1 → STEP 2 ────────────────────────────────────────────────────
    if (_step == 1) {
      if (_isBlank(_fullNameController))
        return _showError('Full Name is required');
      if (_isBlank(_contactController))
        return _showError('Contact No is required');
      if (_contactController.text.trim().length != 10)
        return _showError('Contact No must be 10 digits');
      if (_mobileExistsError != null)
        return _showError(_mobileExistsError!);
    
      if (_selectedGenderId == null || _selectedGenderId! <= 0)
        return _showError('Gender is required');
      if (_selectedSpecialization.isEmpty)
        return _showError('Specialization is required');
      if (_isBlank(_qualificationController))
        return _showError('Qualification is required');
      if (_isBlank(_licenseController))
        return _showError('License Number is required');
      if (_isBlank(_experienceController))
        return _showError('Experience is required');
      if (int.tryParse(_experienceController.text.trim()) == null)
        return _showError('Experience must be a valid number');
      setState(() => _step = 2);
      _animateStep();
      return;
    }

    // ── STEP 2 → STEP 3: Register doctor + clinic ──────────────────────────
    if (_step == 2) {
      if (_isBlank(_clinicNameController))
        return _showError('Clinic Name is required');
      if (_isBlank(_clinicAddressController))
        return _showError('Clinic Address is required');
      if (_isBlank(_clinicContactController))
        return _showError('Clinic Contact is required');
    

      // Fetch FCM token once
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
        // image / imageUrl fields carry the local path only as fallback.
        // The actual file bytes are sent via doctorImage / clinicImage below.
        image:           _doctorPhoto?.path,
        clinicName:      _clinicNameController.text.trim(),
        clinicAddress:   _clinicAddressController.text.trim(),
        clinicContact:   _clinicContactController.text.trim(),
        clinicEmail:     _clinicEmailController.text.trim(),
        websiteName:     _clinicWebsiteController.text.trim(),
        consultationFee: _consultationFeeController.text.trim().isEmpty
            ? null
            : double.tryParse(_consultationFeeController.text.trim()),
        imageUrl:        _clinicPhoto?.path,
        latitude:        _latitude,
        longitude:       _longitude,
        roleId:          1,
        Token:           _fcmToken,
      );

      // ── API call: pass File objects so the usecase builds multipart ────────
      await ref
          .read(doctorLoginViewModelProvider.notifier)
          .addDoctorDetails(
            doctorPayload,
            doctorImage: _doctorPhoto, // null → field omitted in multipart
            clinicImage: _clinicPhoto, // null → field omitted in multipart
          );

      final latestState = ref.read(doctorLoginViewModelProvider);

      if (latestState.error != null) {
        _showError(latestState.error!);
        return;
      }

      final returnedDoctorId = latestState.doctorId;
      final returnedClinicId = latestState.clinic_id;

      if (returnedDoctorId == null || returnedDoctorId <= 0) {
        _showError('Registration failed: could not retrieve Doctor ID.');
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

    // ── STEP 3: Validate + save schedule + lead time → done ────────────────
    // Overlap check
    for (final day in _days) {
      if (!day.isEnabled) continue;
      final slots = day.timeSlots;
      for (int i = 0; i < slots.length; i++) {
        for (int j = i + 1; j < slots.length; j++) {
          final aS = slots[i].startTime.hour * 60 + slots[i].startTime.minute;
          final aE = slots[i].endTime.hour   * 60 + slots[i].endTime.minute;
          final bS = slots[j].startTime.hour * 60 + slots[j].startTime.minute;
          final bE = slots[j].endTime.hour   * 60 + slots[j].endTime.minute;
          if (aS < bE && bS < aE) {
            setState(() => day.isExpanded = true);
            _showError('${day.dayName} has overlapping time slots.');
            return;
          }
        }
      }
    }

    // Enabled days must have at least one slot
    final invalid =
        _days.where((d) => d.isEnabled && d.timeSlots.isEmpty).toList();
    if (invalid.isNotEmpty) {
      setState(() {
        for (final d in invalid) d.isExpanded = true;
      });
      _showError(
        '${invalid.map((d) => d.dayName).join(', ')} '
        '${invalid.length == 1 ? 'is' : 'are'} enabled but ha'
        '${invalid.length == 1 ? 's' : 've'} no time slots.',
      );
      return;
    }

    // Save schedule
    await ref
        .read(doctorSettingsViewModelProvider.notifier)
        .saveDoctorSchedule(_buildScheduleModel());

    // Save lead time (always, so backend can store 0 if no queue)
    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .updateLeadTime(_buildLeadTimeModel());

    final schedErr = ref.read(doctorSettingsViewModelProvider).errorMessage;
    if (schedErr.isNotEmpty) {
      _showError(schedErr);
      return;
    }

    // Extra lead-time call when queue slots exist (idempotent if already called)
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
        _showError('Schedule saved, but lead time update failed: $leadErr');
        // Non-fatal — still navigate
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
      backgroundColor: kSurface,
      appBar: _buildAppBar(),
      body: Stack(children: [
        FadeTransition(
          opacity: _fadeAnim,
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildStepIndicator(),
                const SizedBox(height: 20),
if (_step == 1) _buildStep1(),
                if (_step == 2) _buildStep2(),
                if (_step == 3) _buildStep3(),
                const SizedBox(height: 24),
                _buildCTA(),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
        if (isLoading)
          Container(
            color: Colors.black26,
            child: const Center(
              child: CircularProgressIndicator(color: kPrimaryBlue),
            ),
          ),
      ]),
    );
  }

  // ─── AppBar ───────────────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardBg,
      elevation: 0,
      surfaceTintColor: kCardBg,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(height: 0.5, color: kDivider),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: kTextDark),
        onPressed: () {
          if (_step > 1) {
            setState(() => _step -= 1);
            _animateStep();
          } else {
            Navigator.pop(context);
          }
        },
      ),
      title: const Text('Profile Setup',
          style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: kTextDark)),
      centerTitle: true,
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 16),
          padding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: kLightBlue,
              borderRadius: BorderRadius.circular(20)),
          child: Text('Step $_step of 3',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kPrimaryBlue)),
        ),
      ],
    );
  }

  // ─── Step Indicator ───────────────────────────────────────────────────────
  Widget _buildStepIndicator() {
    return Row(children: [
      _StepChip(
        label: 'Personal',
        icon: Icons.person_outline_rounded,
        state: _step == 1 ? _StepState.active : _StepState.done,
      ),
      _stepLine(_step >= 2),
      _StepChip(
        label: 'Clinic',
        icon: Icons.local_hospital_outlined,
        state: _step == 2
            ? _StepState.active
            : _step > 2
                ? _StepState.done
                : _StepState.pending,
      ),
      _stepLine(_step >= 3),
      _StepChip(
        label: 'Schedule',
        icon: Icons.calendar_month_outlined,
        state:
            _step == 3 ? _StepState.active : _StepState.pending,
      ),
    ]);
  }

  Widget _stepLine(bool active) => Expanded(
        child: Container(
          height: 2,
          margin: const EdgeInsets.symmetric(horizontal: 6),
          decoration: BoxDecoration(
            color: active ? kPrimaryBlue : kDivider,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );

  // ─── Step 1: Personal Info ────────────────────────────────────────────────
Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Doctor photo – tapping opens camera/gallery sheet
        Center(
          child: _AvatarPicker(
            photo: _doctorPhoto,
            icon: Icons.person_rounded,
            label: 'Upload Doctor Photo',
            onTap: () => _pickImage(true),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Basic Details'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildField('Full Name', _fullNameController,
              hint: 'Dr. Arjun Sharma', required: true),
          _buildField('Contact No', _contactController,
              hint: '+91 98765 43210',
              keyboard: TextInputType.phone,
              required: true,
              onChanged: _onContactChanged,
              errorText: _mobileExistsError,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(10),
              ]),
          _buildField('Email Address', _emailController,
              hint: 'doctor@email.com',
              keyboard: TextInputType.emailAddress),
          _buildGenderSection(),
        ]),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Professional Info'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildDropdown(),
          _buildField('Qualification', _qualificationController,
              hint: 'MBBS, MD...', required: true),
          Row(children: [
            Expanded(
                child: _buildField('License No', _licenseController,
                    hint: 'MCI-XXXXX', required: true)),
            const SizedBox(width: 12),
            Expanded(
                child: _buildField(
                    'Experience (yrs)', _experienceController,
                    hint: 'e.g. 8',
                    keyboard: TextInputType.number,
                    required: true)),
          ]),
        ]),
      ],
    );
  }

  // ─── Step 2: Clinic Details ───────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Clinic photo – tapping opens camera/gallery sheet
        Center(
          child: _AvatarPicker(
            photo: _clinicPhoto,
            icon: Icons.local_hospital_rounded,
            label: 'Upload Clinic Photo',
            onTap: () => _pickImage(false),
          ),
        ),
        const SizedBox(height: 24),
        const _SectionHeader(title: 'Clinic Details'),
        const SizedBox(height: 12),
        _Card(children: [
          _buildField('Clinic Name', _clinicNameController,
              hint: 'Apollo Clinic', required: true),
          _buildTextArea(
              'Clinic Address', _clinicAddressController,
              hint: '123, MG Road, Panaji, Goa', required: true),
          Row(children: [
            Expanded(
                child: _buildField('Clinic Contact',
                    _clinicContactController,
                    hint: '+91...',
                    keyboard: TextInputType.phone,
                    required: true,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(10),
                    ])),
            const SizedBox(width: 12),
            Expanded(
                child: _buildField(
                    'Clinic Email', _clinicEmailController,
                    hint: 'clinic@...',
                    keyboard: TextInputType.emailAddress)),
          ]),
          Row(children: [
            Expanded(
                child: _buildField(
                    'Website', _clinicWebsiteController,
                    hint: 'www.clinic.com')),
            const SizedBox(width: 12),
            Expanded(
                child: _buildField(
                    'Consult. Fee (₹)',
                    _consultationFeeController,
                    hint: '500',
                    keyboard: TextInputType.number)),
          ]),
        ]),
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Location'),
        const SizedBox(height: 12),
        _Card(children: [_buildLocationField()]),
      ],
    );
  }

  // ─── Step 3: Schedule ─────────────────────────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_savedDoctorId != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: kSchedPrimaryLight,
              borderRadius: BorderRadius.circular(10),
              border:
                  Border.all(color: kSchedPrimary.withOpacity(0.4)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded,
                  color: kSchedPrimary, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Profile registered! Doctor ID: $_savedDoctorId'
                  '${_savedClinicId != null ? '  •  Clinic ID: $_savedClinicId' : ''}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSchedPrimary),
                ),
              ),
            ]),
          ),

        const _SectionHeader(title: 'Weekly Schedule'),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 11, bottom: 12),
          child: Text(
            'Toggle days you are available and add time slots.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ),

        ..._days.asMap().entries.map((e) => _ScheduleDayCard(
              schedule:     e.value,
              onToggle:     (v) => _toggleDay(e.key, v),
              onTapHeader:  ()  => _toggleExpand(e.key),
              onAddSlot:    ()  => _addSlot(e.key),
              onRemoveSlot: (si) => _removeSlot(e.key, si),
              onUpdateSlot: (si, updated) =>
                  _updateSlot(e.key, si, updated),
            )),

        AnimatedSize(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeInOut,
          child: _anyQueueEnabled
              ? _buildLeadTimeSection()
              : const SizedBox.shrink(),
        ),
      ],
    );
  }

  Widget _buildLeadTimeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        const _SectionHeader(title: 'Queue Booking Lead Time'),
        const SizedBox(height: 4),
        const Padding(
          padding: EdgeInsets.only(left: 11, bottom: 12),
          child: Text(
            'How early can patients join the queue before your session starts.',
            style: TextStyle(fontSize: 12, color: kTextMuted),
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kDivider),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2))
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                    color: kSchedGreenLight,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.access_time_outlined,
                    color: kSchedSuccess, size: 20),
              ),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Lead Time',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextDark)),
                    SizedBox(height: 2),
                    Text('Hours  :  Minutes before session',
                        style:
                            TextStyle(fontSize: 11, color: kTextMuted)),
                  ],
                ),
              ),
              Column(children: [
                const Row(children: [
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
                ]),
                const SizedBox(height: 3),
                Row(children: [
                  _WheelPicker(
                    key: ValueKey('leadH_$_leadHours'),
                    value: _leadHours,
                    max: 24,
                    onChanged: (v) =>
                        setState(() => _leadHours = v),
                  ),
                  const SizedBox(width: 6),
                  const Text(':',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: kTextDark)),
                  const SizedBox(width: 6),
                  _WheelPicker(
                    key: ValueKey('leadM_$_leadMinutes'),
                    value: _leadMinutes,
                    max: 60,
                    onChanged: (v) =>
                        setState(() => _leadMinutes = v),
                  ),
                ]),
              ]),
            ],
          ),
        ),
      ],
    );
  }

  // ─── CTA Button ───────────────────────────────────────────────────────────
  Widget _buildCTA() {
    final labels = ['Continue', 'Register Clinic', 'Complete Setup'];
    final icons  = [
      Icons.arrow_forward_rounded,
      Icons.arrow_forward_rounded,
      Icons.check_circle_outline_rounded,
    ];
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton(
        onPressed: _handleSubmit,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimaryBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(labels[_step - 1],
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3)),
            const SizedBox(width: 8),
            Icon(icons[_step - 1], size: 18),
          ],
        ),
      ),
    );
  }

  // ─── Field Builders ───────────────────────────────────────────────────────
  Widget _buildField(
    String label,
    TextEditingController controller, {
    String hint = '',
    TextInputType keyboard = TextInputType.text,
    bool required = false,
    ValueChanged<String>? onChanged,
    String? errorText,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            keyboardType: keyboard,
            onChanged: onChanged,
            inputFormatters: inputFormatters,
            style:
                const TextStyle(fontSize: 14, color: kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: Color(0xFFBCC1C8), fontSize: 14),
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kDivider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: errorText != null
                      ? const BorderSide(color: kRedAccent)
                      : const BorderSide(color: kDivider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: errorText != null
                      ? const BorderSide(color: kRedAccent, width: 1.5)
                      : const BorderSide(color: kPrimaryBlue, width: 1.5)),
            ),
          ),
          if (errorText != null) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.error_outline_rounded,
                  size: 13, color: kRedAccent),
              const SizedBox(width: 4),
              Text(errorText,
                  style: const TextStyle(
                      fontSize: 11,
                      color: kRedAccent,
                      fontWeight: FontWeight.w500)),
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
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FieldLabel(label: label, required: required),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            maxLines: 3,
            style:
                const TextStyle(fontSize: 14, color: kTextDark),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(
                  color: Color(0xFFBCC1C8), fontSize: 14),
              filled: true,
              fillColor: kSurface,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12),
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kDivider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide:
                      const BorderSide(color: kDivider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(
                      color: kPrimaryBlue, width: 1.5)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _FieldLabel(label: 'Specialization', required: true),
          const SizedBox(height: 6),
          Container(
            height: 50,
            padding:
                const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: kSurface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: _selectedSpecialization.isNotEmpty
                    ? kPrimaryBlue
                    : kDivider,
                width:
                    _selectedSpecialization.isNotEmpty ? 1.5 : 1,
              ),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedSpecialization.isEmpty
                    ? null
                    : _selectedSpecialization,
                hint: const Text('Select specialization',
                    style: TextStyle(
                        color: Color(0xFFBCC1C8), fontSize: 14)),
                isExpanded: true,
                icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kTextMuted),
                style: const TextStyle(
                    fontSize: 14, color: kTextDark),
                items: _specializations
                    .map((s) => DropdownMenuItem<String>(
                          value: s['value'],
                          child: Text(s['label']!),
                        ))
                    .toList(),
                onChanged: (val) => setState(
                    () => _selectedSpecialization = val ?? ''),
              ),
            ),
          ),
        ],
      ),
    );
  }
Widget _buildGenderSection() {
  return Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel(label: 'Gender', required: true),
        const SizedBox(height: 8),
        _GenderSelector(
          options: _genderOptions.map((e) => e['label'] as String).toList(),
          selected: _selectedGender,
          onChanged: (val) => setState(() {
            _selectedGender   = val;
            _selectedGenderId = _genderOptions
                .firstWhere((e) => e['label'] == val)['id'] as int;
            debugPrint('Gender: $_selectedGender | ID: $_selectedGenderId');
          }),
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
        const _FieldLabel(label: 'Clinic Location'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(
            child: Container(
              height: 50,
              alignment: Alignment.centerLeft,
              padding:
                  const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: hasLocation ? kLightBlue : kSurface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color:
                      hasLocation ? kPrimaryBlue : kDivider,
                  width: hasLocation ? 1.5 : 1,
                ),
              ),
              child: Row(children: [
                Icon(
                  hasLocation
                      ? Icons.location_on_rounded
                      : Icons.location_off_rounded,
                  size: 16,
                  color:
                      hasLocation ? kPrimaryBlue : kTextMuted,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hasLocation
                        ? '${_latitude!.toStringAsFixed(4)}, ${_longitude!.toStringAsFixed(4)}'
                        : 'No location selected',
                    style: TextStyle(
                      fontSize: 13,
                      color: hasLocation
                          ? kPrimaryBlue
                          : kTextMuted,
                      fontWeight: hasLocation
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ]),
            ),
          ),
          const SizedBox(width: 10),
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
}

// ═════════════════════════════════════════════════════════════════════════════
// IMAGE SOURCE BOTTOM SHEET
// Shows two tappable tiles: Camera and Gallery.
// Returns the chosen [ImageSource] or null if dismissed.
// ═════════════════════════════════════════════════════════════════════════════
class _ImageSourceSheet extends StatelessWidget {
  final String title;
  const _ImageSourceSheet({required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 24,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 4),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: kDivider,
                borderRadius: BorderRadius.circular(2)),
          ),

          // Title
          Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                    color: kLightBlue,
                    borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.add_photo_alternate_outlined,
                    color: kPrimaryBlue, size: 20),
              ),
              const SizedBox(width: 12),
              Column(crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                const Text('Upload Photo',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: kTextDark)),
                Text(title,
                    style: const TextStyle(
                        fontSize: 12, color: kTextMuted)),
              ]),
            ]),
          ),

          Divider(height: 1, color: kDivider),

          // Camera option
          _SourceTile(
            icon: Icons.camera_alt_rounded,
            iconColor: kPrimaryBlue,
            iconBg: kLightBlue,
            label: 'Take Photo',
            subtitle: 'Open camera and capture now',
            onTap: () => Navigator.pop(context, ImageSource.camera),
          ),

          Divider(height: 1, color: kDivider,
              indent: 68, endIndent: 20),

          // Gallery option
          _SourceTile(
            icon: Icons.photo_library_rounded,
            iconColor: kAccentGreen,
            iconBg: const Color(0xFFE6F4EA),
            label: 'Choose from Gallery',
            subtitle: 'Pick an existing photo',
            onTap: () => Navigator.pop(context, ImageSource.gallery),
          ),

          const SizedBox(height: 8),

          // Cancel
          Padding(
            padding:
                const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.pop(context),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  backgroundColor: kSurface,
                ),
                child: const Text('Cancel',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextMuted)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Single row inside the image-source sheet.
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
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 16),
            Column(crossAxisAlignment: CrossAxisAlignment.start,
                children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: kTextDark)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: kTextMuted)),
            ]),
            const Spacer(),
            const Icon(Icons.chevron_right_rounded,
                color: kTextMuted, size: 20),
          ]),
        ),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SCHEDULE DAY CARD
// ═════════════════════════════════════════════════════════════════════════════
class _ScheduleDayCard extends StatelessWidget {
  final _DaySchedule schedule;
  final ValueChanged<bool> onToggle;
  final VoidCallback onTapHeader;
  final VoidCallback onAddSlot;
  final ValueChanged<int> onRemoveSlot;
  final void Function(int, _TimeSlot) onUpdateSlot;

  const _ScheduleDayCard({
    required this.schedule,
    required this.onToggle,
    required this.onTapHeader,
    required this.onAddSlot,
    required this.onRemoveSlot,
    required this.onUpdateSlot,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: schedule.isEnabled
              ? kSchedPrimary.withOpacity(0.35)
              : kSchedBorder,
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2))
        ],
      ),
      child: Column(children: [
        _buildHeader(),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _buildExpanded(),
          crossFadeState:
              (schedule.isExpanded && schedule.isEnabled)
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 220),
          sizeCurve: Curves.easeInOut,
        ),
      ]),
    );
  }

  Widget _buildHeader() => InkWell(
        onTap: onTapHeader,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: schedule.isEnabled
                    ? kSchedPrimaryLight
                    : const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
              ),
              alignment: Alignment.center,
              child: Text(
                schedule.shortName,
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                    color: schedule.isEnabled
                        ? kSchedPrimary
                        : kSchedTextMuted),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(schedule.dayName,
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: schedule.isEnabled
                              ? kSchedTextPrimary
                              : kSchedTextMuted)),
                  Text(
                    schedule.isEnabled
                        ? (schedule.timeSlots.isEmpty
                            ? 'No slots added'
                            : '${schedule.timeSlots.length} slot${schedule.timeSlots.length > 1 ? 's' : ''}')
                        : 'Unavailable',
                    style: const TextStyle(
                        fontSize: 11, color: kSchedTextMuted),
                  ),
                ],
              ),
            ),
            if (schedule.isEnabled)
              AnimatedRotation(
                turns: schedule.isExpanded ? 0.5 : 0,
                duration: const Duration(milliseconds: 200),
                child: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kSchedTextMuted, size: 20),
              ),
            const SizedBox(width: 6),
            Transform.scale(
              scale: 0.82,
              child: Switch(
                value: schedule.isEnabled,
                onChanged: onToggle,
                activeColor: kSchedPrimary,
                materialTapTargetSize:
                    MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ]),
        ),
      );

  Widget _buildExpanded() => Container(
        decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: kSchedBorder))),
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...schedule.timeSlots.asMap().entries.map((e) =>
                  _ScheduleTimeSlotCard(
                    index:    e.key,
                    slot:     e.value,
                    allSlots: schedule.timeSlots,
                    onRemove: () => onRemoveSlot(e.key),
                    onUpdate: (u) => onUpdateSlot(e.key, u),
                  )),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onAddSlot,
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('Add Time Slot',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: kSchedPrimary,
                    side: const BorderSide(
                        color: kSchedPrimary, width: 1.5),
                    padding:
                        const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ]),
      );
}

// ═════════════════════════════════════════════════════════════════════════════
// SCHEDULE TIME SLOT CARD
// ═════════════════════════════════════════════════════════════════════════════
class _ScheduleTimeSlotCard extends StatefulWidget {
  final int index;
  final _TimeSlot slot;
  final List<_TimeSlot> allSlots;
  final VoidCallback onRemove;
  final ValueChanged<_TimeSlot> onUpdate;

  const _ScheduleTimeSlotCard({
    required this.index,
    required this.slot,
    required this.allSlots,
    required this.onRemove,
    required this.onUpdate,
  });

  @override
  State<_ScheduleTimeSlotCard> createState() =>
      _ScheduleTimeSlotCardState();
}

class _ScheduleTimeSlotCardState
    extends State<_ScheduleTimeSlotCard> {
  late _TimeSlot _local;
  late TextEditingController _queueCtrl;

  @override
  void initState() {
    super.initState();
    _local = _TimeSlot(
      startTime:           widget.slot.startTime,
      endTime:             widget.slot.endTime,
      bookingMode:         widget.slot.bookingMode,
      slotDurationMinutes: widget.slot.slotDurationMinutes,
      maxQueueLength:      widget.slot.maxQueueLength,
    );
    _queueCtrl = TextEditingController(
        text: _local.maxQueueLength != null
            ? '${_local.maxQueueLength}'
            : '');
  }

  @override
  void dispose() {
    _queueCtrl.dispose();
    super.dispose();
  }

  void _update() => widget.onUpdate(_local);

  int _toMin(TimeOfDay t) => t.hour * 60 + t.minute;

  bool _overlaps(TimeOfDay start, TimeOfDay end) {
    final s = _toMin(start);
    final e = _toMin(end);
    for (int i = 0; i < widget.allSlots.length; i++) {
      if (i == widget.index) continue;
      final os = _toMin(widget.allSlots[i].startTime);
      final oe = _toMin(widget.allSlots[i].endTime);
      if (s < oe && os < e) return true;
    }
    return false;
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime:
          isStart ? _local.startTime : _local.endTime,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
            colorScheme: const ColorScheme.light(
                primary: kSchedPrimary)),
        child: child!,
      ),
    );
    if (picked == null) return;
    final newStart = isStart ? picked : _local.startTime;
    final newEnd   = isStart ? _local.endTime : picked;
    if (_overlaps(newStart, newEnd)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Row(children: [
            Icon(Icons.warning_amber_rounded,
                color: Colors.white, size: 15),
            SizedBox(width: 8),
            Expanded(
                child: Text(
                    'This time overlaps with another slot.',
                    style: TextStyle(
                        fontSize: 13, color: Colors.white))),
          ]),
          backgroundColor: kSchedError,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        ));
      }
      return;
    }
    setState(() =>
        isStart ? _local.startTime = picked : _local.endTime = picked);
    _update();
  }

  String _fmtTime(TimeOfDay t) {
    final h      = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final m      = t.minute.toString().padLeft(2, '0');
    final period = t.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String _modeLabel(BookingMode m) => switch (m) {
        BookingMode.queue => 'Queue',
        BookingMode.slots => 'Slots',
        BookingMode.both  => 'Both',
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: kSchedBorder),
      ),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(children: [
              Container(
                width: 20, height: 20,
                decoration: const BoxDecoration(
                    color: kSchedPrimaryLight,
                    shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Text('${widget.index + 1}',
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: kSchedPrimary)),
              ),
              const SizedBox(width: 8),
              const Text('Time Slot',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: kSchedTextPrimary)),
              const Spacer(),
              GestureDetector(
                onTap: widget.onRemove,
                child: Container(
                  width: 26, height: 26,
                  decoration: BoxDecoration(
                      color: kSchedRedLight,
                      borderRadius: BorderRadius.circular(7)),
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded,
                      size: 14, color: kSchedError),
                ),
              ),
            ]),
            const SizedBox(height: 10),

            // Time pickers
            Row(children: [
              Expanded(child: _SchedTimePicker(
                label: 'Start',
                time:  _fmtTime(_local.startTime),
                onTap: () => _pickTime(true),
              )),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8),
                child: Text('→',
                    style: TextStyle(
                        fontSize: 14, color: kSchedTextMuted)),
              ),
              Expanded(child: _SchedTimePicker(
                label: 'End',
                time:  _fmtTime(_local.endTime),
                onTap: () => _pickTime(false),
              )),
            ]),
            const SizedBox(height: 12),

            // Booking mode
            const Text('Booking Mode',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kSchedTextSecondary,
                    letterSpacing: 0.2)),
            const SizedBox(height: 6),
            Row(
              children: BookingMode.values.asMap().entries
                  .map((e) {
                final mode  = e.value;
                final isLast =
                    e.key == BookingMode.values.length - 1;
                final sel = _local.bookingMode == mode;
                return Expanded(
                  child: GestureDetector(
                    onTap: () {
                      setState(() => _local.bookingMode = mode);
                      _update();
                    },
                    child: AnimatedContainer(
                      duration:
                          const Duration(milliseconds: 140),
                      margin: EdgeInsets.only(
                          right: isLast ? 0 : 8),
                      padding: const EdgeInsets.symmetric(
                          vertical: 7),
                      decoration: BoxDecoration(
                        color: sel
                            ? kSchedPrimary
                            : Colors.white,
                        borderRadius:
                            BorderRadius.circular(8),
                        border: Border.all(
                            color: sel
                                ? kSchedPrimary
                                : kSchedBorder),
                      ),
                      alignment: Alignment.center,
                      child: Text(_modeLabel(mode),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel
                                  ? Colors.white
                                  : kSchedTextSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),

            // Max queue length
            if (_local.bookingMode == BookingMode.queue ||
                _local.bookingMode == BookingMode.both) ...[
              const SizedBox(height: 12),
              const Text('Max Queue Length',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSchedTextSecondary,
                      letterSpacing: 0.2)),
              const SizedBox(height: 6),
              Container(
                height: 40,
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border:
                        Border.all(color: kSchedBorder)),
                child: Row(children: [
                  const SizedBox(width: 10),
                  const Icon(Icons.people_alt_rounded,
                      size: 15, color: kSchedPrimary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _queueCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: kSchedTextPrimary),
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        hintText: 'e.g. 20',
                        hintStyle: TextStyle(
                            fontSize: 13,
                            color: kSchedTextMuted),
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onChanged: (val) {
                        setState(() => _local.maxQueueLength =
                            val.isEmpty
                                ? null
                                : int.tryParse(val));
                        _update();
                      },
                    ),
                  ),
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                        color: kSchedPrimaryLight,
                        borderRadius: BorderRadius.circular(6)),
                    child: const Text('patients',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: kSchedPrimary)),
                  ),
                ]),
              ),
            ],

            // Slot duration
            if (_local.bookingMode == BookingMode.slots ||
                _local.bookingMode == BookingMode.both) ...[
              const SizedBox(height: 12),
              const Text('Slot Duration',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kSchedTextSecondary,
                      letterSpacing: 0.2)),
              const SizedBox(height: 6),
              _SlotDurationPicker(
                value: _local.slotDurationMinutes,
                onChanged: (val) {
                  setState(
                      () => _local.slotDurationMinutes = val);
                  _update();
                },
              ),
            ],
          ]),
    );
  }
}

// ─── Schedule helpers ──────────────────────────────────────────────────────
class _SchedTimePicker extends StatelessWidget {
  final String label, time;
  final VoidCallback onTap;
  const _SchedTimePicker(
      {required this.label, required this.time, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(
              horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kSchedBorder)),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: kSchedTextMuted,
                        letterSpacing: 0.3)),
                const SizedBox(height: 2),
                Row(children: [
                  const Icon(Icons.access_time_rounded,
                      size: 12, color: kSchedPrimary),
                  const SizedBox(width: 4),
                  Text(time,
                      style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: kSchedTextPrimary)),
                ]),
              ]),
        ),
      );
}

class _SlotDurationPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;
  static const _opts = [10, 15, 20, 30, 45, 60];
  const _SlotDurationPicker(
      {required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Wrap(
        spacing: 7, runSpacing: 7,
        children: _opts.map((min) {
          final sel = value == min;
          return GestureDetector(
            onTap: () => onChanged(min),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(
                  horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: sel ? kSchedPrimary : Colors.white,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                    color:
                        sel ? kSchedPrimary : kSchedBorder),
              ),
              child: Text('${min}m',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sel
                          ? Colors.white
                          : kSchedTextSecondary)),
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
    _cur  = widget.value.clamp(0, widget.max - 1);
    _ctrl = FixedExtentScrollController(initialItem: _cur);
  }

  @override
  void didUpdateWidget(covariant _WheelPicker old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      final target = widget.value.clamp(0, widget.max - 1);
      final delta  = (target - _cur).abs();
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
        width: 50, height: 50,
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
                      fontSize:
                          sel ? 16 : 12,
                      fontWeight: sel
                          ? FontWeight.w700
                          : FontWeight.w400,
                      color: sel
                          ? kSchedPrimary
                          : kSchedTextMuted,
                    ),
                    child: Text(
                        i.toString().padLeft(2, '0')),
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

class _Card extends StatelessWidget {
  final List<Widget> children;
  const _Card({required this.children});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 2),
        decoration: BoxDecoration(
          color: kCardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kDivider),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      );
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) => Row(children: [
        Container(
            width: 3, height: 14,
            decoration: BoxDecoration(
                color: kPrimaryBlue,
                borderRadius: BorderRadius.circular(2))),
        const SizedBox(width: 8),
        Text(title,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kTextDark,
                letterSpacing: 0.3)),
      ]);
}

class _FieldLabel extends StatelessWidget {
  final String label;
  final bool required;
  const _FieldLabel(
      {required this.label, this.required = false});

  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: kTextMuted)),
        if (required) ...[
          const SizedBox(width: 3),
          const Text('*',
              style: TextStyle(
                  color: kRedAccent,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ]);
}

class _AvatarPicker extends StatelessWidget {
  final File? photo;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _AvatarPicker({
    required this.photo,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) =>
      Column(children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 88, height: 88,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kLightBlue,
              border:
                  Border.all(color: kPrimaryBlue, width: 2),
            ),
            child: photo != null
                ? ClipOval(
                    child: Image.file(photo!,
                        fit: BoxFit.cover))
                : Stack(
                    alignment: Alignment.center,
                    children: [
                      Icon(icon, size: 42, color: kPrimaryBlue),
                      Positioned(
                        bottom: 6, right: 6,
                        child: Container(
                          width: 22, height: 22,
                          decoration: const BoxDecoration(
                              color: kPrimaryBlue,
                              shape: BoxShape.circle),
                          child: const Icon(Icons.add_rounded,
                              color: Colors.white, size: 14),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: kPrimaryBlue,
                fontWeight: FontWeight.w500)),
      ]);
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
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 50, height: 50,
            decoration: BoxDecoration(
              color: kLightBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: kPrimaryBlue.withOpacity(0.3)),
            ),
            child: Icon(icon, color: kPrimaryBlue, size: 20),
          ),
        ),
      );
}

// ─── Step Chip ────────────────────────────────────────────────────────────────
enum _StepState { active, done, pending }

class _StepChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final _StepState state;

  const _StepChip(
      {required this.label,
      required this.icon,
      required this.state});

  @override
  Widget build(BuildContext context) {
    Color bg, fg, border;
    IconData displayIcon;

    switch (state) {
      case _StepState.active:
        bg = kLightBlue;
        fg = kPrimaryBlue;
        border = kPrimaryBlue;
        displayIcon = icon;
      case _StepState.done:
        bg = const Color(0xFFE6F4EA);
        fg = kAccentGreen;
        border = kAccentGreen;
        displayIcon = Icons.check_rounded;
      case _StepState.pending:
        bg = kSurface;
        fg = kTextMuted;
        border = kDivider;
        displayIcon = icon;
    }

    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
            color: bg,
            shape: BoxShape.circle,
            border: Border.all(color: border, width: 1.5)),
        child:
            Icon(displayIcon, size: 13, color: fg),
      ),
      const SizedBox(width: 5),
      Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: state == _StepState.pending
                  ? FontWeight.normal
                  : FontWeight.w600,
              color: fg)),
    ]);
  }
}

// ─── Gender Selector ──────────────────────────────────────────────────────────
class _GenderSelector extends StatelessWidget {
  final List<String> options;
  final String? selected;
  final ValueChanged<String> onChanged;

  const _GenderSelector(
      {required this.options,
      required this.selected,
      required this.onChanged});

  static const _iconMap = {
    'male':   Icons.male_rounded,
    'female': Icons.female_rounded,
    'other':  Icons.transgender_rounded,
  };

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          children: List.generate(options.length, (i) {
            final label      = options[i];
            final icon       = _iconMap[label.toLowerCase()] ??
                Icons.person_outline_rounded;
            final isSelected = selected == label;
            return Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                    right: i < options.length - 1 ? 8 : 0),
                child: GestureDetector(
                  onTap: () => onChanged(label),
                  child: AnimatedContainer(
                    duration:
                        const Duration(milliseconds: 200),
                    height: 44,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? kLightBlue
                          : kSurface,
                      borderRadius:
                          BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected
                            ? kPrimaryBlue
                            : kDivider,
                        width: isSelected ? 1.5 : 1,
                      ),
                    ),
                    child: Row(
                        mainAxisAlignment:
                            MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 16,
                              color: isSelected
                                  ? kPrimaryBlue
                                  : kTextMuted),
                          const SizedBox(width: 5),
                          Text(label,
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: isSelected
                                      ? FontWeight.w600
                                      : FontWeight.w400,
                                  color: isSelected
                                      ? kPrimaryBlue
                                      : kTextMuted)),
                        ]),
                  ),
                ),
              ),
            );
          }),
        ),
      );
}

// ─── Inline States ────────────────────────────────────────────────────────────
class _InlineLoading extends StatelessWidget {
  const _InlineLoading();
  @override
  Widget build(BuildContext context) => const SizedBox(
        height: 44,
        child: Center(
          child: SizedBox(
              width: 18, height: 18,
              child: CircularProgressIndicator(
                  strokeWidth: 2, color: kPrimaryBlue)),
        ),
      );
}

class _InlineError extends StatelessWidget {
  final String text;
  const _InlineError({required this.text});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFFEF2F2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFECACA)),
        ),
        child: Row(children: [
          const Icon(Icons.error_outline_rounded,
              size: 18, color: kRedAccent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFB91C1C)))),
        ]),
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
  final _focusNode  = FocusNode();

  static const _apiKey = 'AIzaSyDTRL5VzQ9UAwsCB9uCbSNj5wZasYHjFKA';

  List<Map<String, dynamic>> _predictions = [];
  bool _showSuggestions = false;
  bool _isSearching     = false;

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
      setState(() { _predictions = []; _showSuggestions = false; });
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
      final data     = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        setState(() {
          _predictions     = List<Map<String, dynamic>>.from(data['predictions']);
          _showSuggestions = _predictions.isNotEmpty;
        });
      } else {
        debugPrint('Places API status: ${data['status']}');
        setState(() { _predictions = []; _showSuggestions = false; });
      }
    } catch (e) {
      debugPrint('Places search error: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  Future<void> _selectPrediction(Map<String, dynamic> prediction) async {
    _focusNode.unfocus();
    setState(() { _showSuggestions = false; });
    _searchCtrl.text = prediction['description'] ?? '';

    try {
      final placeId = prediction['place_id'];
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/details/json'
        '?place_id=$placeId'
        '&fields=geometry'
        '&key=$_apiKey',
      );
      final response = await http.get(url);
      final data     = jsonDecode(response.body);
      if (data['status'] == 'OK') {
        final loc    = data['result']['geometry']['location'];
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
    setState(() { _predictions = []; _showSuggestions = false; });
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: kBg,
    appBar: AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      surfaceTintColor: Colors.white,
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(height: 0.5, color: kBorder),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            size: 18, color: kTextPrimary),
        onPressed: () => Navigator.pop(context),
      ),
      title: const Text('Select Location',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
              color: kTextPrimary)),
      centerTitle: true,
      actions: [
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: TextButton(
            onPressed: () => Navigator.pop(context, _selected),
            style: TextButton.styleFrom(
              backgroundColor: kPrimary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            ),
            child: const Text('Confirm',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
          ),
        ),
      ],
    ),
    body: Stack(children: [

      // ── Google Map ──────────────────────────────────────────────
      gmap.GoogleMap(
        initialCameraPosition:
            gmap.CameraPosition(target: _selected, zoom: 14),
        onMapCreated: (ctrl) => _mapController = ctrl,
        onTap: (gmap.LatLng latLng) {
          _focusNode.unfocus();
          setState(() {
            _selected        = latLng;
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

      // ── Search bar + suggestions ────────────────────────────────
      Positioned(
        top: 12, left: 12, right: 12,
        child: Column(children: [
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(color: Color(0x18000000),
                    blurRadius: 12, offset: Offset(0, 3)),
              ],
            ),
            child: TextField(
              controller: _searchCtrl,
              focusNode:  _focusNode,
              onChanged:  _onSearchChanged,
              style: const TextStyle(fontSize: 14, color: kTextPrimary),
              decoration: InputDecoration(
                hintText: 'Search for a place...',
                hintStyle: const TextStyle(fontSize: 14, color: kTextMuted),
                prefixIcon: _isSearching
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox(width: 18, height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: kPrimary)),
                      )
                    : const Icon(Icons.search_rounded, color: kPrimary, size: 20),
                suffixIcon: _searchCtrl.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: kTextMuted, size: 18),
                        onPressed: _clearSearch,
                      )
                    : null,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
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
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(color: Color(0x18000000),
                      blurRadius: 12, offset: Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  padding: EdgeInsets.zero,
                  itemCount: _predictions.length,
                  separatorBuilder: (_, __) =>
                      const Divider(height: 1, color: kBorder),
                  itemBuilder: (_, i) {
                    final p           = _predictions[i];
                    final mainText    = p['structured_formatting']?['main_text'] ?? p['description'] ?? '';
                    final secondText  = p['structured_formatting']?['secondary_text'] ?? '';
                    return InkWell(
                      onTap: () => _selectPrediction(p),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: kPrimaryLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.location_on_rounded,
                                color: kPrimary, size: 16),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(mainText,
                                    style: const TextStyle(fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                        color: kTextPrimary),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis),
                                if (secondText.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(secondText,
                                      style: const TextStyle(
                                          fontSize: 11, color: kTextSecondary),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis),
                                ],
                              ],
                            ),
                          ),
                          const Icon(Icons.north_west_rounded,
                              size: 14, color: kTextMuted),
                        ]),
                      ),
                    );
                  },
                ),
              ),
            ),
        ]),
      ),

      // ── Bottom coordinates card ─────────────────────────────────
      Positioned(
        bottom: 24, left: 16, right: 16,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kPrimary.withOpacity(0.3)),
            boxShadow: const [
              BoxShadow(color: Color(0x14000000),
                  blurRadius: 16, offset: Offset(0, 4)),
            ],
          ),
          child: Row(children: [
            Container(
              width: 36, height: 36,
              decoration: const BoxDecoration(
                  color: kPrimaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.location_on_rounded,
                  color: kPrimary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected coordinates',
                      style: TextStyle(fontSize: 11, color: kTextSecondary)),
                  const SizedBox(height: 2),
                  Text(
                    '${_selected.latitude.toStringAsFixed(6)}, '
                    '${_selected.longitude.toStringAsFixed(6)}',
                    style: const TextStyle(fontSize: 13,
                        fontWeight: FontWeight.w600, color: kTextPrimary),
                  ),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => _mapController?.animateCamera(
                gmap.CameraUpdate.newCameraPosition(
                  gmap.CameraPosition(target: _selected, zoom: 15),
                ),
              ),
              child: Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.center_focus_strong_rounded,
                    color: kPrimary, size: 17),
              ),
            ),
          ]),
        ),
      ),
    ]),
  );
} 