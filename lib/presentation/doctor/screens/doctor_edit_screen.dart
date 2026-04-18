import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder  = Color(0xFFEDF2F7);
const kDivider = Color(0xFFE5E7EB);

const kError    = Color(0xFFFC8181);
const kSuccess  = Color(0xFF68D391);
const kWarning  = Color(0xFFED8936);

// ── Card decoration ───────────────────────────────────────────────────────────
BoxDecoration _cardDec() => BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: kBorder),
      boxShadow: [
        BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4)),
      ],
    );

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
  bool _didPrefill      = false;
  bool _isSubmitting    = false;

  // ── Mobile verification state ─────────────────────────────────
  String _originalMobile = '';
  bool _isMobileChanged  = false;
  bool _isOtpSent        = false;
  bool _isVerifyingOtp   = false;
  String _otpError       = '';
  
  // ── Dummy OTP for testing (remove in production) ───────────
  String _dummyOtp       = '';  // Generated when OTP is sent

  // ── Personal ──────────────────────────────────────────────────
  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _contactCtrl = TextEditingController();
  final _qualCtrl    = TextEditingController();
  final _licenseCtrl = TextEditingController();
  final _expCtrl     = TextEditingController();
  final _feeCtrl     = TextEditingController();
  final _otpCtrl     = TextEditingController();
  String _selectedGender = 'Male';
  String _selectedSpec   = 'Cardiology';

  // ── Clinic ────────────────────────────────────────────────────
  final _clinicNameCtrl    = TextEditingController();
  final _clinicAddrCtrl    = TextEditingController();
  final _clinicContactCtrl = TextEditingController();
  final _clinicEmailCtrl   = TextEditingController();
  final _websiteCtrl       = TextEditingController();

  final _specs   = const [
    'Cardiology', 'General Physician', 'Dermatology',
    'Pediatrics', 'Orthopedics',
  ];
  final _genders = const ['Male', 'Female', 'Other'];

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _sub = ref.listenManual<DoctorLoginState>(
      doctorLoginViewModelProvider,
      (prev, next) {
        _maybeFetchProfile(next);
        _prefillFromState(next);
      },
    );
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
      _nameCtrl, _emailCtrl, _contactCtrl, _qualCtrl, _licenseCtrl,
      _expCtrl, _feeCtrl, _clinicNameCtrl, _clinicAddrCtrl,
      _clinicContactCtrl, _clinicEmailCtrl, _websiteCtrl, _otpCtrl,
    ]) { c.dispose(); }
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

    _set(_nameCtrl,    details.name ?? state.name);
    _set(_emailCtrl,   details.email ?? state.email);
    _set(_contactCtrl, details.mobile ?? state.mobile);
    _set(_qualCtrl,    details.qualification);
    _set(_licenseCtrl, details.licenseNo);
    _set(_expCtrl,     details.experience?.toString());
    _set(_feeCtrl,     details.consultationFee?.toStringAsFixed(0));

    _set(_clinicNameCtrl,    details.clinicName ?? state.clinic_name);
    _set(_clinicAddrCtrl,    details.clinicAddress);
    _set(_clinicContactCtrl, details.clinicContact);
    _set(_clinicEmailCtrl,   details.clinicEmail);
    _set(_websiteCtrl,       details.websiteName);

    // Store original mobile for comparison
    _originalMobile = (details.mobile ?? state.mobile ?? '').trim();

    _applyGender(details);
    _applySpec(details);
    if (mounted) setState(() {});
  }

  void _set(TextEditingController c, String? v) {
    final s = v?.trim();
    if (s == null || s.isEmpty) return;
    c.text = s;
  }

  void _applyGender(DoctorDetails d) {
    final id = d.genderId;
    if (id == null) return;
    _selectedGender = id == 2 ? 'Female' : id == 3 ? 'Other' : 'Male';
  }

  void _applySpec(DoctorDetails d) {
    final s = d.specialization?.trim();
    if (s != null && s.isNotEmpty && _specs.contains(s)) {
      _selectedSpec = s;
    }
  }

  // ---------------------------------------------------------------------------
  // Mobile Number Change Verification
  // ---------------------------------------------------------------------------

  void _onMobileChanged(String value) {
    final newMobile = value.trim();
    final hasChanged = newMobile != _originalMobile;
    
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
    final newMobile = _contactCtrl.text.trim();
    
    // Validation
    if (newMobile.isEmpty) {
      _snack('Please enter a mobile number', isError: true);
      return;
    }
    if (newMobile.length < 10) {
      _snack('Mobile number must be at least 10 digits', isError: true);
      return;
    }

    setState(() => _isVerifyingOtp = true);

    try {
      // ───────────────────────────────────────────────────────────
      // DUMMY OTP GENERATION FOR TESTING/DEVELOPMENT
      // In production, replace with actual backend call:
      // await ref.read(doctorLoginViewModelProvider.notifier).sendOtpToMobile(newMobile);
      // ───────────────────────────────────────────────────────────
      _dummyOtp = _generateDummyOtp();
      
      // Log dummy OTP to console for easy testing
      debugPrint('╔════════════════════════════════════════╗');
      debugPrint('║ 🔐 DEVELOPMENT MODE - DUMMY OTP      ║');
      debugPrint('╠════════════════════════════════════════╣');
      debugPrint('║ Mobile: $newMobile');
      debugPrint('║ OTP: $_dummyOtp');
      debugPrint('╚════════════════════════════════════════╝');
      
      // Simulate network delay (2 seconds)
      await Future.delayed(const Duration(seconds: 2));

      setState(() {
        _isOtpSent = true;
        _otpError = '';
      });

      _snack('OTP sent to $newMobile\n💡 Test OTP: $_dummyOtp');
    } catch (e) {
      _snack('Failed to send OTP: ${e.toString()}', isError: true);
    } finally {
      setState(() => _isVerifyingOtp = false);
    }
  }

  /// Generates a random 6-digit OTP for testing
  /// Remove this method in production
  String _generateDummyOtp() {
    final random = DateTime.now().millisecond % 1000;
    return '${(random + 111111) % 1000000}'.padLeft(6, '0');
  }

  Future<void> _verifyOtp() async {
    final otp = _otpCtrl.text.trim();
    final newMobile = _contactCtrl.text.trim();

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
      // ───────────────────────────────────────────────────────────
      // DUMMY OTP VERIFICATION FOR TESTING/DEVELOPMENT
      // In production, replace with actual backend call:
      // final isVerified = await ref.read(doctorLoginViewModelProvider.notifier)
      //     .verifyOtpForMobile(newMobile, otp);
      // ───────────────────────────────────────────────────────────
      
      // Simulate network delay (1.5 seconds)
      await Future.delayed(const Duration(milliseconds: 1500));
      
      // Check if entered OTP matches dummy OTP
      final isVerified = (otp == _dummyOtp);
      
      debugPrint('🔍 OTP Verification: Entered=$otp, Expected=$_dummyOtp, Result=${isVerified ? '✓' : '✗'}');

      if (isVerified) {
        // Update the original mobile to mark it as verified
        setState(() {
          _originalMobile = newMobile;
          _isMobileChanged = false;
          _isOtpSent = false;
          _otpError = '';
        });
        _snack('Mobile number verified successfully');
      } else {
        setState(() => _otpError = 'Invalid OTP. Please try again.');
      }
    } catch (e) {
      setState(() => _otpError = 'Verification failed: ${e.toString()}');
    } finally {
      setState(() => _isVerifyingOtp = false);
    }
  }

  void _cancelMobileChange() {
    setState(() {
      _contactCtrl.text = _originalMobile;
      _isMobileChanged = false;
      _isOtpSent = false;
      _otpCtrl.clear();
      _otpError = '';
    });
  }

  // ---------------------------------------------------------------------------
  // Save
  // ---------------------------------------------------------------------------

  Future<void> _save() async {
    // Prevent saving if mobile was changed but not verified
    if (_isMobileChanged && _isOtpSent && _originalMobile != _contactCtrl.text.trim()) {
      _snack('Please verify your new mobile number before saving', isError: true);
      return;
    }

    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    final state   = ref.read(doctorLoginViewModelProvider);
    final details = state.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    final doctor = DoctorDetails(
      doctorId:       details?.doctorId ?? state.doctorId,
      name:           _nameCtrl.text.trim(),
      email:          _emailCtrl.text.trim(),
      mobile:         _contactCtrl.text.trim(),
      qualification:  _qualCtrl.text.trim(),
      licenseNo:      _licenseCtrl.text.trim(),
      experience:     _parseInt(_expCtrl.text),
      specialization: _selectedSpec,
      roleId:         details?.roleId ?? _parseInt(state.roleId),
      clinicId:       details?.clinicId ?? state.clinic_id,
      clinicName:     _clinicNameCtrl.text.trim(),
      clinicAddress:  _clinicAddrCtrl.text.trim(),
      consultationFee:_parseDouble(_feeCtrl.text),
      websiteName:    _websiteCtrl.text.trim(),
      clinicEmail:    _clinicEmailCtrl.text.trim(),
      clinicContact:  _clinicContactCtrl.text.trim(),
      genderId:       _genderIdFor(_selectedGender),
      Token:          state.token,
    );

    await ref.read(doctorLoginViewModelProvider.notifier).addDoctorDetails(doctor);
    if (!mounted) return;
    setState(() => _isSubmitting = false);

    final after = ref.read(doctorLoginViewModelProvider);
    if (after.error != null && after.error!.isNotEmpty) {
      _snack(after.error!, isError: true);
      return;
    }

    _snack('Doctor details updated successfully');
    final mobile = after.mobile;
    if (mobile != null && mobile.trim().isNotEmpty) {
      ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
    }
    Navigator.pop(context, true);
  }

  int?    _parseInt(String? v)  => v == null ? null : int.tryParse(v.trim());
  double? _parseDouble(String? v) => v == null ? null : double.tryParse(v.trim());
  int?    _genderIdFor(String g) =>
      g.toLowerCase() == 'female' ? 2 : g.toLowerCase() == 'other' ? 3 : 1;

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(children: [
          Icon(isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
              color: Colors.white, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(msg,
              style: const TextStyle(fontSize: 13, color: Colors.white))),
        ]),
        backgroundColor: isError ? kError : kPrimary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 16),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: kPrimaryLight,
                borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 15, color: kPrimary),
          ),
        ),
        title: const Text('Edit Profile',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: kTextPrimary,
                letterSpacing: -0.2)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: kBorder),
        ),
      ),
      body: SafeArea(
        child: Column(children: [
          // Tab bar
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabCtrl,
              labelColor: kPrimary,
              unselectedLabelColor: kTextMuted,
              labelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w700),
              unselectedLabelStyle: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500),
              indicatorColor: kPrimary,
              indicatorWeight: 2,
              tabs: const [
                Tab(text: 'Personal Info'),
                Tab(text: 'Clinic Info'),
              ],
            ),
          ),
          const Divider(height: 1, color: kBorder),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildPersonalTab(),
                _buildClinicTab(),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Tab 1: Personal
  // ---------------------------------------------------------------------------

  Widget _buildPersonalTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _photoCard(isDoctor: true),
          const SizedBox(height: 14),
          _sectionLabel('Personal Details'),
          const SizedBox(height: 8),
          _buildCard([
            _field('Full Name',    _nameCtrl),
            _field('Email',        _emailCtrl,   keyboard: TextInputType.emailAddress),
            _fieldWithMobileVerification(),
            _genderTile(),
          ]),
          const SizedBox(height: 14),
          _sectionLabel('Professional Details'),
          const SizedBox(height: 8),
          _buildCard([
            _specTile(),
            _field('Qualification',        _qualCtrl),
            _field('License Number',       _licenseCtrl),
            _field('Experience (Years)',   _expCtrl,  keyboard: TextInputType.number),
            _field('Consultation Fee (₹)', _feeCtrl,  keyboard: TextInputType.number,
                showDivider: false),
          ]),
          const SizedBox(height: 18),
          _saveButton(),
          const SizedBox(height: 32),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Tab 2: Clinic
  // ---------------------------------------------------------------------------

  Widget _buildClinicTab() => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _photoCard(isDoctor: false),
          const SizedBox(height: 14),
          _sectionLabel('Clinic Details'),
          const SizedBox(height: 8),
          _buildCard([
            _field('Clinic Name',    _clinicNameCtrl),
            _field('Clinic Address', _clinicAddrCtrl,    maxLines: 3),
            _field('Clinic Contact', _clinicContactCtrl, keyboard: TextInputType.phone),
            _field('Clinic Email',   _clinicEmailCtrl,   keyboard: TextInputType.emailAddress),
            _field('Website',        _websiteCtrl,       showDivider: false),
          ]),
          const SizedBox(height: 14),
          _sectionLabel('Location'),
          const SizedBox(height: 8),
          _buildCard([_locationTile()]),
          const SizedBox(height: 18),
          _saveButton(),
          const SizedBox(height: 32),
        ]),
      );

  // ---------------------------------------------------------------------------
  // Shared sub-widgets
  // ---------------------------------------------------------------------------

  Widget _fieldWithMobileVerification() => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(
              children: [
                const Text('Contact No',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: kTextSecondary, letterSpacing: 0.2)),
                if (_isMobileChanged)
                  Container(
                    margin: const EdgeInsets.only(left: 6),
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: kWarning.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('Verification Required',
                        style: TextStyle(
                            fontSize: 9, fontWeight: FontWeight.w600,
                            color: kWarning, letterSpacing: 0.3)),
                  ),
              ],
            ),
            const SizedBox(height: 5),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: _isMobileChanged ? kWarning : kBorder,
                    width: _isMobileChanged ? 1.5 : 1),
              ),
              child: TextField(
                controller: _contactCtrl,
                keyboardType: TextInputType.phone,
                enabled: !_isOtpSent, // Disable editing after OTP is sent
                onChanged: _onMobileChanged,
                style: const TextStyle(fontSize: 13, color: kTextPrimary),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                      horizontal: 12, vertical: 10),
                ),
              ),
            ),
          ]),
        ),
        // OTP verification section
        if (_isMobileChanged)
          Column(
            children: [
              const Divider(height: 1, thickness: 1, color: kBorder,
                  indent: 12, endIndent: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Verification',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.w600,
                            color: kTextSecondary, letterSpacing: 0.2)),
                    const SizedBox(height: 8),
                    if (!_isOtpSent)
                      SizedBox(
                        width: double.infinity,
                        height: 38,
                        child: ElevatedButton.icon(
                          onPressed: _isVerifyingOtp ? null : _sendOtp,
                          icon: _isVerifyingOtp
                              ? SizedBox(
                                  width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white.withOpacity(0.8))))
                              : const Icon(Icons.mail_outline_rounded, size: 16),
                          label: Text(
                              _isVerifyingOtp ? 'Sending OTP...' : 'Send OTP'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: kPrimary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      )
                    else
                      Column(
                        children: [
                          Container(
                            decoration: BoxDecoration(
                              color: const Color(0xFFF7F8FA),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                  color: _otpError.isNotEmpty ? kError : kBorder),
                            ),
                            child: TextField(
                              controller: _otpCtrl,
                              keyboardType: TextInputType.number,
                              maxLength: 6,
                              enabled: !_isVerifyingOtp,
                              style: const TextStyle(
                                  fontSize: 13, color: kTextPrimary,
                                  letterSpacing: 2),
                              textAlign: TextAlign.center,
                              decoration: const InputDecoration(
                                hintText: '000000',
                                hintStyle: TextStyle(
                                    color: kTextMuted, letterSpacing: 2),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12, vertical: 10),
                                counterText: '',
                              ),
                            ),
                          ),
                          if (_otpError.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 6),
                              child: Row(
                                children: [
                                  const Icon(Icons.error_outline_rounded,
                                      size: 12, color: kError),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(_otpError,
                                        style: const TextStyle(
                                            fontSize: 11, color: kError)),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 8),
                          Row(children: [
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: OutlinedButton(
                                  onPressed: _cancelMobileChange,
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: kTextSecondary,
                                    side: const BorderSide(color: kBorder),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                  child: const Text('Cancel',
                                      style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600)),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: SizedBox(
                                height: 36,
                                child: ElevatedButton.icon(
                                  onPressed:
                                      _isVerifyingOtp ? null : _verifyOtp,
                                  icon: _isVerifyingOtp
                                      ? SizedBox(
                                          width: 14, height: 14,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                      Colors.white
                                                          .withOpacity(0.8))))
                                      : const Icon(Icons.check_rounded, size: 16),
                                  label: Text(
                                      _isVerifyingOtp ? 'Verifying...' : 'Verify'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: kSuccess,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(10)),
                                  ),
                                ),
                              ),
                            ),
                          ]),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          )
        else
          const Divider(height: 1, thickness: 1, color: kBorder,
              indent: 12, endIndent: 12),
      ]);

  Widget _photoCard({required bool isDoctor}) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: _cardDec(),
        child: Column(children: [
          Stack(children: [
            Container(
              width: 70, height: 70,
              decoration: BoxDecoration(
                color: kPrimaryLight,
                shape: isDoctor ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: isDoctor ? null : BorderRadius.circular(14),
                border: Border.all(color: kPrimary, width: 2),
              ),
              child: Icon(
                isDoctor ? Icons.person : Icons.local_hospital_outlined,
                size: 32, color: kPrimary,
              ),
            ),
            Positioned(
              bottom: 0, right: 0,
              child: Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                    color: kSuccess, shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2)),
                child: const Icon(Icons.edit_rounded, size: 11, color: Colors.white),
              ),
            ),
          ]),
          const SizedBox(height: 6),
          Text(
            isDoctor ? 'Tap to change photo' : 'Tap to change clinic photo',
            style: const TextStyle(fontSize: 11, color: kTextMuted),
          ),
        ]),
      );

  Widget _field(
    String label,
    TextEditingController ctrl, {
    TextInputType keyboard = TextInputType.text,
    int maxLines = 1,
    bool showDivider = true,
  }) {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: kTextSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 5),
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F8FA),
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
                    horizontal: 12, vertical: 10),
              ),
            ),
          ),
        ]),
      ),
      if (showDivider)
        const Divider(height: 1, thickness: 1, color: kBorder,
            indent: 12, endIndent: 12),
    ]);
  }

  Widget _genderTile() => Column(children: [
        const Divider(height: 1, thickness: 1, color: kBorder,
            indent: 12, endIndent: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Gender',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: kTextSecondary, letterSpacing: 0.2)),
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
                      height: 38,
                      decoration: BoxDecoration(
                        color: sel ? kPrimary : Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? kPrimary : kBorder,
                            width: sel ? 1.5 : 1),
                      ),
                      alignment: Alignment.center,
                      child: Text(g,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: sel ? Colors.white : kTextSecondary)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ]),
        ),
      ]);

  Widget _specTile() => Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Specialization',
                style: TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w600,
                    color: kTextSecondary, letterSpacing: 0.2)),
            const SizedBox(height: 5),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F8FA),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: kBorder),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedSpec,
                  isExpanded: true,
                  icon: const Icon(Icons.keyboard_arrow_down_rounded,
                      color: kTextMuted, size: 18),
                  style: const TextStyle(fontSize: 13, color: kTextPrimary),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  items: _specs.map((s) => DropdownMenuItem(
                      value: s, child: Text(s))).toList(),
                  onChanged: (v) =>
                      setState(() => _selectedSpec = v ?? _selectedSpec),
                ),
              ),
            ),
          ]),
        ),
        const Divider(height: 1, thickness: 1, color: kBorder,
            indent: 12, endIndent: 12),
      ]);

  Widget _locationTile() => Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Coordinates',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: kTextSecondary, letterSpacing: 0.2)),
          const SizedBox(height: 7),
          Row(children: [
            Expanded(
              child: Container(
                height: 40,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7F8FA),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: kBorder),
                ),
                child: const Text('18.5204, 73.8567',
                    style: TextStyle(fontSize: 13, color: kTextPrimary)),
              ),
            ),
            const SizedBox(width: 8),
            _LocBtn(icon: Icons.my_location_rounded, onTap: () {}, isCircle: true),
            const SizedBox(width: 8),
            _LocBtn(icon: Icons.map_rounded, onTap: () {}, isCircle: false),
          ]),
        ]),
      );

  Widget _saveButton() => SizedBox(
        width: double.infinity, height: 46,
        child: ElevatedButton(
          onPressed: _isSubmitting || _isMobileChanged ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            disabledBackgroundColor: kPrimaryLight,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          child: _isSubmitting
              ? const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2.5))
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Save Changes',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    if (_isMobileChanged)
                      const Text('(Verify mobile first)',
                          style: TextStyle(
                              fontSize: 9, fontWeight: FontWeight.w500,
                              color: Colors.white70)),
                  ],
                ),
        ),
      );

  Widget _buildCard(List<Widget> children) => Container(
        decoration: _cardDec(),
        child: Column(children: children),
      );

  Widget _sectionLabel(String title) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 0),
        child: Text(title.toUpperCase(),
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700,
                color: kTextMuted, letterSpacing: 1.0)),
      );
}

// ─── Location button ──────────────────────────────────────────────────────────
class _LocBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool isCircle;
  const _LocBtn({required this.icon, required this.onTap, required this.isCircle});

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(
            color: kPrimary,
            shape: isCircle ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isCircle ? null : BorderRadius.circular(10),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      );
}