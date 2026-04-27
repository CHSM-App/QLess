
import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart' as gmap;
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';

// ════════════════════════════════════════════════════════════════════
//  DESIGN TOKENS — exact match with PatientListScreen
// ════════════════════════════════════════════════════════════════════
const kPrimary = Color(0xFF26C6B0);
const kPrimaryDark = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);
const kPrimaryLighter = Color(0xFFF2FCFA);

const kTextPrimary = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted = Color(0xFFA0AEC0);

const kBorder = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);
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

// ════════════════════════════════════════════════════════════════════
//  DOCTOR EDIT PROFILE PAGE
// ════════════════════════════════════════════════════════════════════
class DoctorEditProfilePage extends ConsumerStatefulWidget {
  const DoctorEditProfilePage({super.key});

  @override
  ConsumerState<DoctorEditProfilePage> createState() =>
      _DoctorEditProfilePageState();
}

class _DoctorEditProfilePageState extends ConsumerState<DoctorEditProfilePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  late final ProviderSubscription<DoctorLoginState> _sub;

  bool _didFetchProfile = false;
  bool _didPrefill = false;
  bool _isSubmitting = false;

  // ── Mobile verification ──────────────────────────────────────────
  String _originalMobile = '';
  bool _isMobileChanged = false;
  bool _isOtpSent = false;
  bool _isVerifyingOtp = false;
  String _otpError = '';
  String _dummyOtp = '';

  // Add these state variables alongside existing ones
  double? _latitude;
  double? _longitude;
  bool _isLoadingLocation = false;

  // ── Personal ────────────────────────────────────────────────────
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _qualCtrl = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _expCtrl = TextEditingController();
  final _feeCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedSpec = 'Cardiology';

  // ── Clinic ──────────────────────────────────────────────────────
  final _clinicNameCtrl = TextEditingController();
  final _clinicAddrCtrl = TextEditingController();
  final _clinicContactCtrl = TextEditingController();
  final _clinicEmailCtrl = TextEditingController();
  final _websiteCtrl = TextEditingController();
  // Add these alongside existing state variables
  File? _doctorImage;
  File? _clinicImage;
  String? _doctorNetworkImage;
  String? _clinicNetworkImage;
  final ImagePicker _picker = ImagePicker();

  final _specs = const [
    'Cardiology',
    'General Physician',
    'Dermatology',
    'Pediatrics',
    'Orthopedics',
  ];
  final _genders = const ['Male', 'Female', 'Other'];

  // ── Lifecycle ────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _sub = ref.listenManual<DoctorLoginState>(doctorLoginViewModelProvider, (
      _,
      next,
    ) {
      _maybeFetchProfile(next);
      _prefillFromState(next);
    });
    Future.microtask(() {
      final state = ref.read(doctorLoginViewModelProvider);
      _maybeFetchProfile(state);
      _prefillFromState(state);
    });
  }

  @override
  void dispose() {
    _sub.close();
    _tabCtrl.dispose();
    for (final c in [
      _nameCtrl,
      _emailCtrl,
      _contactCtrl,
      _qualCtrl,
      _licenseCtrl,
      _expCtrl,
      _feeCtrl,
      _clinicNameCtrl,
      _clinicAddrCtrl,
      _clinicContactCtrl,
      _clinicEmailCtrl,
      _websiteCtrl,
      _otpCtrl,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  void _maybeFetchProfile(DoctorLoginState state) {
    if (_didFetchProfile) return;
    final mobile = state.mobile;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _didFetchProfile = true;
      ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
    }
  }

  void _prefillFromState(DoctorLoginState state) {
    if (_didPrefill) return;
    final details = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    if (details == null) return;
    _didPrefill = true;

    _set(_nameCtrl, details.name ?? state.name);
    _set(_emailCtrl, details.email ?? state.email);
    _set(_contactCtrl, details.mobile ?? state.mobile);
    _set(_qualCtrl, details.qualification);
    _set(_licenseCtrl, details.licenseNo);
    _set(_expCtrl, details.experience?.toString());
    _set(_feeCtrl, details.consultationFee?.toStringAsFixed(0));
    _set(_clinicNameCtrl, details.clinicName ?? state.clinic_name);
    _set(_clinicAddrCtrl, details.clinicAddress);
    _set(_clinicContactCtrl, details.clinicContact);
    _set(_clinicEmailCtrl, details.clinicEmail);
    _set(_websiteCtrl, details.websiteName);
    // after existing _set(...) calls:
    if (details.latitude != null) _latitude = details.latitude;
    if (details.longitude != null) _longitude = details.longitude;
    _doctorNetworkImage = details.image ?? details.image;
    _clinicNetworkImage = details.imageUrl ?? details.imageUrl;

    _originalMobile = (details.mobile ?? state.mobile ?? '').trim();
    _applyGender(details);
    _applySpec(details);
    if (mounted) setState(() {});
  }

  Future<void> _pickImage({required bool isDoctor}) async {
    final current = isDoctor ? _doctorImage : _clinicImage;
    final hasNetwork = isDoctor
        ? (_doctorNetworkImage != null && _doctorNetworkImage!.isNotEmpty)
        : (_clinicNetworkImage != null && _clinicNetworkImage!.isNotEmpty);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: kBorder,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                isDoctor ? 'Doctor Photo' : 'Clinic Photo',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Choose how to set the profile picture',
                style: TextStyle(fontSize: 12, color: kTextMuted),
              ),
              const SizedBox(height: 16),
              _sourceOption(
                icon: Icons.camera_alt_outlined,
                iconBg: kPrimaryLight,
                iconFg: kPrimary,
                label: 'Take a Photo',
                subtitle: 'Use your camera',
                onTap: () async {
                  Navigator.pop(ctx);
                  final xfile = await _picker.pickImage(
                    source: ImageSource.camera,
                    imageQuality: 80,
                  );
                  if (xfile != null) {
                    setState(() {
                      if (isDoctor)
                        _doctorImage = File(xfile.path);
                      else
                        _clinicImage = File(xfile.path);
                    });
                  }
                },
              ),
              const SizedBox(height: 10),
              _sourceOption(
                icon: Icons.photo_library_outlined,
                iconBg: const Color(0xFFEDE9FE),
                iconFg: const Color(0xFF9F7AEA),
                label: 'Choose from Gallery',
                subtitle: 'Pick from your photos',
                onTap: () async {
                  Navigator.pop(ctx);
                  final xfile = await _picker.pickImage(
                    source: ImageSource.gallery,
                    imageQuality: 80,
                  );
                  if (xfile != null) {
                    setState(() {
                      if (isDoctor)
                        _doctorImage = File(xfile.path);
                      else
                        _clinicImage = File(xfile.path);
                    });
                  }
                },
              ),
              if (current != null || hasNetwork) ...[
                const SizedBox(height: 10),
                _sourceOption(
                  icon: Icons.delete_outline_rounded,
                  iconBg: const Color(0xFFFEE2E2),
                  iconFg: const Color(0xFFFC8181),
                  label: 'Remove Photo',
                  subtitle: 'Reset to default avatar',
                  onTap: () {
                    Navigator.pop(ctx);
                    setState(() {
                      if (isDoctor) {
                        _doctorImage = null;
                        _doctorNetworkImage = null;
                      } else {
                        _clinicImage = null;
                        _clinicNetworkImage = null;
                      }
                    });
                  },
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sourceOption({
    required IconData icon,
    required Color iconBg,
    required Color iconFg,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 18, color: iconFg),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: kTextPrimary,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(fontSize: 11, color: kTextMuted),
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: kTextMuted,
            ),
          ],
        ),
      ),
    );
  }

  void _set(TextEditingController c, String? v) {
    final s = v?.trim();
    if (s == null || s.isEmpty) return;
    c.text = s;
  }

  void _applyGender(DoctorDetails d) {
    final id = d.genderId;
    if (id == null) return;
    _selectedGender = id == 2
        ? 'Female'
        : id == 3
        ? 'Other'
        : 'Male';
  }

  void _applySpec(DoctorDetails d) {
    final s = d.specialization?.trim().toLowerCase();
    if (s == null || s.isEmpty) return;

    // Map API values → display values
    const specMap = {
      'general': 'General Physician',
      'general physician': 'General Physician',
      'cardiology': 'Cardiology',
      'dermatology': 'Dermatology',
      'pediatrics': 'Pediatrics',
      'orthopedics': 'Orthopedics',
    };

    final mapped = specMap[s];
    if (mapped != null && _specs.contains(mapped)) {
      setState(() => _selectedSpec = mapped);
    }
  }

  // ── Mobile verification ──────────────────────────────────────────
  void _onMobileChanged(String value) {
    final hasChanged = value.trim() != _originalMobile;
    setState(() {
      _isMobileChanged = hasChanged;
      if (!hasChanged) {
        _isOtpSent = false;
        _otpCtrl.clear();
        _otpError = '';
      }
    });
  }

  Future<void> _sendOtp() async {
    final m = _contactCtrl.text.trim();
    if (m.isEmpty || m.length < 10) {
      _showSnack('Enter a valid 10-digit mobile number', isError: true);
      return;
    }
    setState(() => _isVerifyingOtp = true);
    try {
      _dummyOtp = ((DateTime.now().millisecond % 1000) + 111111)
          .toString()
          .substring(0, 6);
      debugPrint('DEV OTP for $m → $_dummyOtp');
      await Future.delayed(const Duration(seconds: 2));
      setState(() {
        _isOtpSent = true;
        _otpError = '';
      });
      _showSnack('OTP sent to $m  •  Test OTP: $_dummyOtp');
    } catch (e) {
      _showSnack('Failed to send OTP: $e', isError: true);
    } finally {
      setState(() => _isVerifyingOtp = false);
    }
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    if (otp.isEmpty) {
      setState(() => _otpError = 'Please enter OTP');
      return;
    }
    if (otp.length < 4) {
      setState(() => _otpError = 'OTP must be at least 4 digits');
      return;
    }
    setState(() => _isVerifyingOtp = true);
    try {
      await Future.delayed(const Duration(milliseconds: 1500));
      if (otp == _dummyOtp) {
        setState(() {
          _originalMobile = _contactCtrl.text.trim();
          _isMobileChanged = false;
          _isOtpSent = false;
          _otpError = '';
        });
        _otpCtrl.clear();
        _showSnack('Mobile number verified successfully');
      } else {
        setState(() => _otpError = 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _otpError = 'Verification failed: $e');
    } finally {
      setState(() => _isVerifyingOtp = false);
    }
  }

  void _cancelMobileChange() => setState(() {
    _contactCtrl.text = _originalMobile;
    _isMobileChanged = false;
    _isOtpSent = false;
    _otpError = '';
    _otpCtrl.clear();
  });

  Future<void> _getCurrentLocation() async {
    setState(() => _isLoadingLocation = true);
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnack('Location permission denied', isError: true);
          return;
        }
      }
      if (permission == LocationPermission.deniedForever) {
        _showSnack(
          'Location permission permanently denied. Enable it in settings.',
          isError: true,
        );
        return;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      setState(() {
        _latitude = position.latitude;
        _longitude = position.longitude;
      });
      _showSnack('Location updated successfully');
    } catch (e) {
      _showSnack('Failed to get location: $e', isError: true);
    } finally {
      setState(() => _isLoadingLocation = false);
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



  // ── Save ─────────────────────────────────────────────────────────
  Future<void> _save() async {
    if (_isMobileChanged) {
      _showSnack(
        'Please verify your new mobile number before saving',
        isError: true,
      );
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final state = ref.read(doctorLoginViewModelProvider);
    final details = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    final doctor = DoctorDetails(
      doctorId: details?.doctorId ?? state.doctorId,
      name: _nameCtrl.text.trim(),
      email: _emailCtrl.text.trim(),
      mobile: _contactCtrl.text.trim(),
      qualification: _qualCtrl.text.trim(),
      licenseNo: _licenseCtrl.text.trim(),
      experience: _parseInt(_expCtrl.text),
      specialization: _selectedSpec,
      roleId: details?.roleId ?? _parseInt(state.roleId),
      clinicId: details?.clinicId ?? state.clinic_id,
      clinicName: _clinicNameCtrl.text.trim(),
      clinicAddress: _clinicAddrCtrl.text.trim(),
      consultationFee: _parseDouble(_feeCtrl.text),
      websiteName: _websiteCtrl.text.trim(),
      clinicEmail: _clinicEmailCtrl.text.trim(),
      clinicContact: _clinicContactCtrl.text.trim(),
      genderId: _genderId(_selectedGender),
      Token: state.token,
      latitude: _latitude,
      longitude: _longitude,
    );
    debugPrint('doctorId: ${details?.doctorId}');
    debugPrint('name: ${_nameCtrl.text}');
    debugPrint('email: ${_emailCtrl.text}');
    debugPrint('mobile: ${_contactCtrl.text}');
    debugPrint('roleId: ${details?.roleId}');
    debugPrint('clinicId: ${details?.clinicId}');
    debugPrint('genderId: ${_genderId(_selectedGender)}');
    debugPrint('fee: ${_feeCtrl.text}');
    debugPrint('exp: ${_expCtrl.text}');
    debugPrint('clinicImage: $_clinicImage');

    await ref
        .read(doctorLoginViewModelProvider.notifier)
        .addDoctorDetails(
          doctor,
          doctorImage: _doctorImage, // ← add
          clinicImage: _clinicImage, // ← add
        );
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final after = ref.read(doctorLoginViewModelProvider);
    if (after.error != null && after.error!.isNotEmpty) {
      _showSnack(after.error!, isError: true);
      return;
    }
    _showSnack('Profile updated successfully');
    final m = after.mobile;
    if (m != null && m.trim().isNotEmpty) {
      await ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(m);
    }
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  int? _parseInt(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return int.tryParse(v.trim());
  }

  double? _parseDouble(String? v) {
    if (v == null || v.trim().isEmpty) return null;
    return double.tryParse(v.trim().replaceAll(',', ''));
  }

  int? _genderId(String g) => g.toLowerCase() == 'female'
      ? 2
      : g.toLowerCase() == 'other'
      ? 3
      : 1;

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 14,
            ),
            const SizedBox(width: 7),
            Expanded(
              child: Text(
                msg,
                style: const TextStyle(fontSize: 13, color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double get _width => MediaQuery.of(context).size.width;
  bool get _isDesktop => _width >= _kDesktopBreak;
  bool get _isTablet => _width >= _kTabletBreak;

  // ── Build ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Column(
        children: [
          _buildHeader(),
          _buildTabBar(),
          Expanded(
            child: _isDesktop
                ? _buildDesktopBody()
                : TabBarView(
                    controller: _tabCtrl,
                    children: [_personalTab(), _clinicTab()],
                  ),
          ),
        ],
      ),
    );
  }

  // ── Header — exact PatientListScreen style ────────────────────────
  Widget _buildHeader() => Container(
    decoration: const BoxDecoration(
      color: Colors.white,
      border: Border(bottom: BorderSide(color: kBorder, width: 1)),
    ),
    child: SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: kTextPrimary,
                  size: 15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kPrimary.withOpacity(0.2)),
              ),
              child: const Icon(
                Icons.person_outline_rounded,
                color: kPrimary,
                size: 17,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Edit Profile',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary,
                    ),
                  ),
                  SizedBox(height: 1),
                  Text(
                    'Update your personal & clinic info',
                    style: TextStyle(fontSize: 11, color: kTextSecondary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  // ── Tab bar ───────────────────────────────────────────────────────
  Widget _buildTabBar() => Container(
    color: Colors.white,
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF0F5F3),
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabCtrl,
              labelColor: kPrimaryDark,
              unselectedLabelColor: kTextSecondary,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.07),
                    blurRadius: 6,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              indicatorPadding: const EdgeInsets.all(3),
              indicatorSize: TabBarIndicatorSize.tab,
              labelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
              dividerColor: Colors.transparent,
              tabs: const [
                Tab(text: 'Personal Info'),
                Tab(text: 'Clinic Info'),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: kBorder),
      ],
    ),
  );

  // ── Desktop: side-by-side ─────────────────────────────────────────
  Widget _buildDesktopBody() => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(child: _personalTab()),
      Container(width: 1, color: kBorder),
      Expanded(child: _clinicTab()),
    ],
  );

  // ── Personal tab ─────────────────────────────────────────────────
  Widget _personalTab() => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      _isTablet ? 20 : 14,
      14,
      _isTablet ? 20 : 14,
      24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatarCard(isDoctor: true),
        _gap(12),
        _sectionLabel('Personal Details'),
        _gap(6),
        _card([
          _field('Full Name', _nameCtrl),
          _field('Email', _emailCtrl, keyboard: TextInputType.emailAddress),
          _mobileVerificationField(),
          _genderRow(),
        ]),
        _gap(12),
        _sectionLabel('Professional Details'),
        _gap(6),
        _card([
          _specDropdown(),
          _field('Qualification', _qualCtrl),
          _field('License Number', _licenseCtrl),
          _field(
            'Experience (Years)',
            _expCtrl,
            keyboard: TextInputType.number,
          ),
          _field(
            'Consultation Fee (₹)',
            _feeCtrl,
            keyboard: TextInputType.number,
            showDivider: false,
          ),
        ]),
        _gap(14),
        _saveBtn(),
      ],
    ),
  );

  // ── Clinic tab ────────────────────────────────────────────────────
  Widget _clinicTab() => SingleChildScrollView(
    padding: EdgeInsets.fromLTRB(
      _isTablet ? 20 : 14,
      14,
      _isTablet ? 20 : 14,
      24,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _avatarCard(isDoctor: false),
        _gap(12),
        _sectionLabel('Clinic Details'),
        _gap(6),
        _card([
          _field('Clinic Name', _clinicNameCtrl),
          _field('Clinic Address', _clinicAddrCtrl, maxLines: 2),
          _field(
            'Contact Number',
            _clinicContactCtrl,
            keyboard: TextInputType.phone,
          ),
          _field(
            'Clinic Email',
            _clinicEmailCtrl,
            keyboard: TextInputType.emailAddress,
          ),
          _field('Website URL', _websiteCtrl, showDivider: false),
        ]),
        _gap(12),
        _sectionLabel('Location'),
        _gap(6),
        _card([_locationTile()]),
        _gap(14),
        _saveBtn(),
      ],
    ),
  );

  // ── Widgets ───────────────────────────────────────────────────────
  Widget _avatarCard({required bool isDoctor}) {
    final localFile = isDoctor ? _doctorImage : _clinicImage;
    final networkUrl = isDoctor ? _doctorNetworkImage : _clinicNetworkImage;
    final hasImage =
        localFile != null || (networkUrl != null && networkUrl.isNotEmpty);

    ImageProvider? imageProvider;
    if (localFile != null) {
      imageProvider = FileImage(localFile);
    } else if (networkUrl != null && networkUrl.isNotEmpty) {
      imageProvider = NetworkImage(networkUrl);
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x08000000),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 62,
                height: 62,
                decoration: BoxDecoration(
                  color: kPrimaryLight,
                  shape: isDoctor ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isDoctor ? null : BorderRadius.circular(14),
                  border: Border.all(color: kPrimary, width: 1.8),
                  image: imageProvider != null
                      ? DecorationImage(
                          image: imageProvider,
                          fit: BoxFit.cover,
                          onError: (_, __) {},
                        )
                      : null,
                ),
                child: !hasImage
                    ? Icon(
                        isDoctor
                            ? Icons.person_rounded
                            : Icons.local_hospital_outlined,
                        size: 28,
                        color: kPrimary,
                      )
                    : null,
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _pickImage(isDoctor: isDoctor),
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: kPrimary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.edit_rounded,
                      size: 10,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            hasImage
                ? (localFile != null ? 'Photo selected' : 'Tap to change photo')
                : (isDoctor
                      ? 'Tap to change photo'
                      : 'Tap to change clinic photo'),
            style: TextStyle(
              fontSize: 11,
              color: localFile != null ? kSuccess : kTextMuted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool showDivider = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: kTextSecondary,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(height: 5),
              Container(
                decoration: BoxDecoration(
                  color: kBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: TextField(
                  controller: ctrl,
                  keyboardType: keyboard,
                  maxLines: maxLines,
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
      ],
    );
  }

  // ── Mobile + OTP verification field ─────────────────────────────
  Widget _mobileVerificationField() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text(
                  'Contact No',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: kTextSecondary,
                    letterSpacing: 0.2,
                  ),
                ),
                if (_isMobileChanged) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: kAmberLight,
                      borderRadius: BorderRadius.circular(5),
                      border: Border.all(color: kWarning.withOpacity(0.4)),
                    ),
                    child: const Text(
                      'Verification required',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: kAmberDark,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: _isMobileChanged ? kWarning : kBorder,
                  width: _isMobileChanged ? 1.5 : 1,
                ),
              ),
              child: TextField(
                controller: _contactCtrl,
                keyboardType: TextInputType.phone,
                enabled: !_isOtpSent,
                onChanged: _onMobileChanged,
                style: const TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      if (_isMobileChanged) ...[
        const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // label row
              Row(
                children: [
                  Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: kAmberLight,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.lock_outline_rounded,
                      size: 10,
                      color: kAmberDark,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'OTP Verification',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: kTextSecondary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!_isOtpSent)
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: ElevatedButton.icon(
                    onPressed: _isVerifyingOtp ? null : _sendOtp,
                    icon: _isVerifyingOtp
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send_rounded, size: 14),
                    label: Text(
                      _isVerifyingOtp ? 'Sending…' : 'Send OTP',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: kPrimary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                )
              else ...[
                Container(
                  decoration: BoxDecoration(
                    color: kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _otpError.isNotEmpty ? kError : kBorder,
                    ),
                  ),
                  child: TextField(
                    controller: _otpCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    enabled: !_isVerifyingOtp,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      color: kTextPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 6,
                    ),
                    decoration: const InputDecoration(
                      hintText: '• • • • • •',
                      hintStyle: TextStyle(
                        color: kTextMuted,
                        letterSpacing: 4,
                        fontSize: 13,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
                if (_otpError.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 12,
                        color: kError,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _otpError,
                          style: const TextStyle(fontSize: 11, color: kError),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: OutlinedButton(
                          onPressed: _cancelMobileChange,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kTextSecondary,
                            side: const BorderSide(color: kBorder),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SizedBox(
                        height: 36,
                        child: ElevatedButton.icon(
                          onPressed: _isVerifyingOtp ? null : _verifyOtp,
                          icon: _isVerifyingOtp
                              ? const SizedBox(
                                  width: 13,
                                  height: 13,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.check_rounded, size: 14),
                          label: Text(
                            _isVerifyingOtp ? 'Verifying…' : 'Verify',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kSuccess,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ] else
        const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
    ],
  );

  // ── Gender row ────────────────────────────────────────────────────
  Widget _genderRow() => Padding(
    padding: const EdgeInsets.fromLTRB(12, 9, 12, 12),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Gender',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: kTextSecondary,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 7),
        Row(
          children: _genders.map((g) {
            final sel = _selectedGender == g;
            final isLast = g == _genders.last;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _selectedGender = g),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  margin: EdgeInsets.only(right: isLast ? 0 : 8),
                  height: 36,
                  decoration: BoxDecoration(
                    gradient: sel
                        ? const LinearGradient(
                            colors: [Color(0xFF4DD9C8), Color(0xFF2BB5A0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: sel ? null : Colors.white,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: sel ? kPrimary : kBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    g,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: sel ? Colors.white : kTextSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    ),
  );

  // ── Specialization dropdown ───────────────────────────────────────
  Widget _specDropdown() => Column(
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specialization',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextSecondary,
                letterSpacing: 0.2,
              ),
            ),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: kBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSpec,
                  isExpanded: true,
                  icon: const Icon(
                    Icons.keyboard_arrow_down_rounded,
                    color: kTextMuted,
                    size: 17,
                  ),
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  items: _specs
                      .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedSpec = v ?? _selectedSpec),
                ),
              ),
            ),
          ],
        ),
      ),
      const Divider(height: 1, color: kBorder, indent: 12, endIndent: 12),
    ],
  );

  Widget _locationTile() {
    final hasLocation = _latitude != null && _longitude != null;
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Coordinates',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextSecondary,
              letterSpacing: 0.2,
            ),
          ),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 38,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: hasLocation ? kPrimaryLighter : kBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasLocation ? kPrimary : kBorder,
                      width: hasLocation ? 1.5 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        hasLocation
                            ? Icons.location_on_rounded
                            : Icons.location_off_rounded,
                        size: 14,
                        color: hasLocation ? kPrimary : kTextMuted,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          hasLocation
                              ? '${_latitude!.toStringAsFixed(6)}, ${_longitude!.toStringAsFixed(6)}'
                              : 'No location selected',
                          style: TextStyle(
                            fontSize: 12,
                            color: hasLocation ? kPrimary : kTextMuted,
                            fontWeight: hasLocation
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // GPS button
              _isLoadingLocation
                  ? Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : _locBtn(
                      Icons.my_location_rounded,
                      _getCurrentLocation,
                      circle: true,
                    ),
              const SizedBox(width: 8),
              // Map picker button
              _locBtn(Icons.map_rounded, _selectFromMap, circle: false),
            ],
          ),
        ],
      ),
    );
  }

  Widget _locBtn(IconData icon, VoidCallback onTap, {required bool circle}) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: kPrimary,
            shape: circle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: circle ? null : BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 17),
        ),
      );

  // ── Save button ───────────────────────────────────────────────────
  Widget _saveBtn() => SizedBox(
    width: double.infinity,
    height: 44,
    child: ElevatedButton(
      onPressed: (_isSubmitting || _isMobileChanged) ? null : _save,
      style: ElevatedButton.styleFrom(
        backgroundColor: kPrimary,
        disabledBackgroundColor: kPrimaryLight,
        foregroundColor: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: _isSubmitting
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                color: Colors.white,
                strokeWidth: 2,
              ),
            )
          : Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Save Changes',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                if (_isMobileChanged)
                  const Text(
                    'Verify mobile number first',
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white70,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
    ),
  );

  // ── Section label — matches PatientListScreen _SectionHeader style ─
  Widget _sectionLabel(String title) => Row(
    children: [
      Container(
        width: 3,
        height: 14,
        decoration: BoxDecoration(
          color: kPrimary,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
      const SizedBox(width: 7),
      Text(
        title.toUpperCase(),
        style: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: kTextMuted,
          letterSpacing: 1.0,
        ),
      ),
    ],
  );

  // ── Card wrapper ──────────────────────────────────────────────────
  Widget _card(List<Widget> children) => Container(
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
      boxShadow: const [
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Column(children: children),
  );

  Widget _gap(double h) => SizedBox(height: h);
}

// ═══════════════════════════════════════════════════════════
//  MAP PICKER SCREEN  (same as registration screen)
// ═══════════════════════════════════════════════════════════


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