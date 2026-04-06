import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/doctor_details.dart';
import 'package:qless/presentation/doctor/providers/doctor_view_model_provider.dart';
import 'package:qless/presentation/doctor/screens/doctor_availability_page.dart';
import 'package:qless/presentation/doctor/screens/doctor_edit_screen.dart';
import 'package:qless/presentation/doctor/view_models/doctor_login_viewmodel.dart';
import 'package:qless/presentation/shared/screens/continue_as.dart';
import 'package:qless/core/network/token_provider.dart';

// ─── Constants ───────────────────────────────────────────────────────────────

const kPrimaryBlue = Color(0xFF1A73E8);
const kLightBlue   = Color(0xFFE8F0FE);
const kAccentGreen = Color(0xFF34A853);
const kRedAccent   = Color(0xFFEA4335);
const kSurface     = Color(0xFFF8F9FA);
const kCardBg      = Color(0xFFFFFFFF);
const kTextDark    = Color(0xFF1F2937);
const kTextMuted   = Color(0xFF6B7280);
const kDivider     = Color(0xFFE5E7EB);

// ─── Main Page ────────────────────────────────────────────────────────────────

class DoctorSettingsPage extends ConsumerStatefulWidget {
  const DoctorSettingsPage({super.key});

  @override
  ConsumerState<DoctorSettingsPage> createState() => _DoctorSettingsPageState();
}

class _DoctorSettingsPageState extends ConsumerState<DoctorSettingsPage> {
  bool _notificationsEnabled = true;
  bool _emailAlerts = false;
  bool _smsAlerts = true;
  bool _darkMode = false;
  bool _availableForConsultation = true;
  int _selectedNavIndex = 3; // Settings tab
  bool _didFetchProfile = false;
  late final ProviderSubscription<DoctorLoginState> _doctorLoginSub;

  @override
  void initState() {
    super.initState();
    _doctorLoginSub = ref.listenManual<DoctorLoginState>(
      doctorLoginViewModelProvider,
      (prev, next) {
      if (_didFetchProfile) return;
      final mobile = next.mobile;
      if (mobile != null && mobile.trim().isNotEmpty) {
        _didFetchProfile = true;
        ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
      }
    },
    );
    Future.microtask(() {
      final mobile = ref.read(doctorLoginViewModelProvider).mobile;
      if (mobile != null && mobile.trim().isNotEmpty) {
        _didFetchProfile = true;
        ref.read(doctorLoginViewModelProvider.notifier).checkPhoneDoctor(mobile);
      }
    });
  }

  @override
  void dispose() {
    _doctorLoginSub.close();
    super.dispose();
  }

  String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return '?';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final doctorState = ref.watch(doctorLoginViewModelProvider);
    final doctorDetails = doctorState.phoneCheckResult.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    final screenWidth  = MediaQuery.of(context).size.width;
    final isTablet     = screenWidth >= 600;
    final isLargeTablet = screenWidth >= 900;

    return Scaffold(
      backgroundColor: kSurface,
      // appBar: PreferredSize(
      //   preferredSize: Size.fromHeight(isTablet ? 72 : 64),
      //   child: _buildTopBar(isTablet: isTablet, doctorState: doctorState),
      // ),
      body: isLargeTablet
          ? _buildLargeTabletLayout(doctorState, doctorDetails)
          : _buildMobileLayout(isTablet, doctorState, doctorDetails),
      // bottomNavigationBar: isLargeTablet ? null : _buildBottomNav(),
    );
  }

  // ── Large Tablet (Side Rail) ──────────────────────────────────────────────

  Widget _buildLargeTabletLayout(
    DoctorLoginState doctorState,
    DoctorDetails? doctorDetails,
  ) {
    return Row(
      children: [
        // _buildSideRail(),
        Expanded(
          child: Column(
            children: [
             // _buildTopBar(isTablet: true, doctorState: doctorState),
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 3,
                      child: _buildScrollContent(
                        isTablet: true,
                        doctorState: doctorState,
                        doctorDetails: doctorDetails,
                      ),
                    ),
                    SizedBox(
                      width: 320,
                      child: _buildRightPanel(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Mobile / Tablet Layout ────────────────────────────────────────────────

  Widget _buildMobileLayout(
    bool isTablet,
    DoctorLoginState doctorState,
    DoctorDetails? doctorDetails,
  ) {
    return Column(
      children: [
     //   _buildTopBar(isTablet: isTablet, doctorState: doctorState),
        Expanded(
          child: _buildScrollContent(
            isTablet: isTablet,
            doctorState: doctorState,
            doctorDetails: doctorDetails,
          ),
        ),
      ],
    );
  }

  // ── Top Bar ───────────────────────────────────────────────────────────────


  Widget _buildAvatarChip(bool isTablet, DoctorLoginState doctorState) {
    final initials = _initials(doctorState.name);
    final displayName = doctorState.name ?? 'Doctor';
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: kLightBlue,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(initials, style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              ),
              if (isTablet) ...[
                const SizedBox(width: 8),
                Text(displayName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kPrimaryBlue)),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ── Scroll Content ────────────────────────────────────────────────────────

  Widget _buildScrollContent({
    required bool isTablet,
    required DoctorLoginState doctorState,
    DoctorDetails? doctorDetails,
  }) {
    final hPad = isTablet ? 24.0 : 16.0;
    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: hPad, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileCard(isTablet, doctorState, details: doctorDetails),
          const SizedBox(height: 20),
          _buildSectionTitle('Account'),
          _buildAccountSection(isTablet),
          const SizedBox(height: 20),
          _buildSectionTitle('Availability'),
          _buildAvailabilityCard(),
          const SizedBox(height: 20),
          _buildSectionTitle('Notifications'),
          _buildNotificationsCard(),
          const SizedBox(height: 20),
          _buildSectionTitle('Appearance'),
          _buildAppearanceCard(),
          const SizedBox(height: 20),
          _buildSectionTitle('Support'),
          _buildSupportCard(),
          const SizedBox(height: 20),
          _buildLogoutButton(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ── Profile Card ──────────────────────────────────────────────────────────

  Widget _buildProfileCard(
    bool isTablet,
    DoctorLoginState doctorState, {
    DoctorDetails? details,
  }) {
    final initials = _initials(details?.name ?? doctorState.name);
    final displayName = details?.name ?? doctorState.name ?? 'Doctor';
    final clinicName = details?.clinicName ?? doctorState.clinic_name ?? '';
    final specialization = details?.specialization ?? 'Cardiologist';
    final qualification = details?.qualification ?? 'MBBS, MD, DM';
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          // Header gradient
          Container(
            height: 80,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF1A73E8), Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              children: [
                // Avatar overlapping header
                Transform.translate(
                  offset: const Offset(0, -40),
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 3),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF42A5F5), Color(0xFF1565C0)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: kPrimaryBlue.withOpacity(0.3),
                              blurRadius: 16,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            initials,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                      ),
                      Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: kAccentGreen,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                        ),
                        child: const Icon(Icons.edit, color: Colors.white, size: 12),
                      ),
                    ],
                  ),
                ),
                Transform.translate(
                  offset: const Offset(0, -30),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            displayName,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: kTextDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: kLightBlue,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Verified', style: TextStyle(fontSize: 10, color: kPrimaryBlue, fontWeight: FontWeight.w600)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$specialization  •  $qualification',
                        style: const TextStyle(fontSize: 13, color: kTextMuted),
                      ),
                      const SizedBox(height: 4),
                      if (clinicName.isNotEmpty)
                      Text(
                        clinicName,
                        style: const TextStyle(fontSize: 13, color: kTextMuted),
                      ),
                      const SizedBox(height: 16),
                      // Stats row
                      isTablet
                          ? _buildStatsRowTablet(details)
                          : _buildStatsRowMobile(details),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(context, rootNavigator: true).push(
                              MaterialPageRoute(
                                builder: (_) => const DoctorEditProfilePage(),
                              ),
                            );
                          },
                          icon: const Icon(Icons.edit_outlined, size: 16),
                          label: const Text('Edit Profile'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: kPrimaryBlue,
                            side: const BorderSide(color: kPrimaryBlue),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRowMobile(DoctorDetails? details) {
    final exp = details?.experience?.toString();
    final expText = exp != null && exp.isNotEmpty ? '$exp yrs' : '12 yrs';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(expText, 'Experience'),
        _vDivider(),
        _statItem('4.9 ★', 'Rating'),
        _vDivider(),
        _statItem('2,340', 'Patients'),
      ],
    );
  }

  Widget _buildStatsRowTablet(DoctorDetails? details) {
    final exp = details?.experience?.toString();
    final expText = exp != null && exp.isNotEmpty ? '$exp yrs' : '12 yrs';
    final fee = details?.consultationFee?.toStringAsFixed(0);
    final feeText = fee != null && fee.isNotEmpty ? '₹$fee' : '₹800';
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _statItem(expText, 'Experience'),
        _vDivider(),
        _statItem('4.9 ★', 'Rating'),
        _vDivider(),
        _statItem('2,340', 'Patients'),
        _vDivider(),
        _statItem(feeText, 'Consultation'),
      ],
    );
  }

  Widget _statItem(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
      ],
    );
  }

  Widget _vDivider() {
    return Container(height: 32, width: 1, color: kDivider);
  }

  // ── Account Section ───────────────────────────────────────────────────────

  Widget _buildAccountSection(bool isTablet) {
    final items = [
      _SettingItem(icon: Icons.person_outline, label: 'Personal Information', subtitle: 'Name, DOB, Gender', trailing: null),
      _SettingItem(icon: Icons.medical_information_outlined, label: 'Professional Details', subtitle: 'Specialization, License', trailing: null),
      _SettingItem(icon: Icons.lock_outline, label: 'Password & Security', subtitle: 'Change password, 2FA', trailing: null),
      _SettingItem(icon: Icons.payment_outlined, label: 'Payment & Earnings', subtitle: 'Bank account, payouts', trailing: null),
    ];

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: items.asMap().entries.map((e) {
          return Column(
            children: [
              _buildNavTile(e.value),
              if (e.key < items.length - 1) const Divider(height: 1, indent: 56, color: kDivider),
            ],
          );
        }).toList(),
      ),
    );
  }

  Widget _buildNavTile(_SettingItem item) {
    return InkWell(
      onTap: () {},
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(color: kLightBlue, borderRadius: BorderRadius.circular(10)),
              child: Icon(item.icon, color: kPrimaryBlue, size: 18),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
                  if (item.subtitle != null)
                    Text(item.subtitle!, style: const TextStyle(fontSize: 12, color: kTextMuted)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: kTextMuted, size: 20),
          ],
        ),
      ),
    );
  }

  // ── Availability Card ─────────────────────────────────────────────────────

  Widget _buildAvailabilityCard() {
    return Container(
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: _availableForConsultation ? const Color(0xFFE6F4EA) : const Color(0xFFFCE8E6),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.videocam_outlined,
                  color: _availableForConsultation ? kAccentGreen : kRedAccent,
                  size: 18,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Available for Consultation', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
                    Text(
                      _availableForConsultation ? 'Patients can book appointments' : 'Currently not accepting patients',
                      style: const TextStyle(fontSize: 12, color: kTextMuted),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _availableForConsultation,
                activeColor: kAccentGreen,
                onChanged: (v) => setState(() => _availableForConsultation = v),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(height: 1, color: kDivider),
          const SizedBox(height: 16),
          const Text('Working Hours', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kTextDark)),
          const SizedBox(height: 10),
          _buildDayRow('Mon – Fri', '9:00 AM – 5:00 PM', true),
          const SizedBox(height: 6),
          _buildDayRow('Saturday', '10:00 AM – 2:00 PM', true),
          const SizedBox(height: 6),
          _buildDayRow('Sunday', 'Off', false),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DoctorAvailabilityPage()),
                );
              },
              icon: const Icon(Icons.edit_calendar_outlined, size: 14),
              label: const Text('Edit Schedule'),
              style: TextButton.styleFrom(foregroundColor: kPrimaryBlue, textStyle: const TextStyle(fontSize: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayRow(String day, String hours, bool active) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: active ? kAccentGreen : kRedAccent,
          ),
        ),
        const SizedBox(width: 10),
        SizedBox(width: 100, child: Text(day, style: const TextStyle(fontSize: 13, color: kTextDark))),
        Text(hours, style: TextStyle(fontSize: 13, color: active ? kTextDark : kTextMuted)),
      ],
    );
  }

  // ── Notifications Card ────────────────────────────────────────────────────

  Widget _buildNotificationsCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildToggleTile(
            icon: Icons.notifications_outlined,
            label: 'Push Notifications',
            subtitle: 'Appointment reminders & alerts',
            value: _notificationsEnabled,
            onChanged: (v) => setState(() => _notificationsEnabled = v),
            color: const Color(0xFFFFF3E0),
            iconColor: const Color(0xFFE65100),
          ),
          const Divider(height: 1, indent: 56, color: kDivider),
          _buildToggleTile(
            icon: Icons.email_outlined,
            label: 'Email Alerts',
            subtitle: 'Daily summaries & reports',
            value: _emailAlerts,
            onChanged: (v) => setState(() => _emailAlerts = v),
            color: kLightBlue,
            iconColor: kPrimaryBlue,
          ),
          const Divider(height: 1, indent: 56, color: kDivider),
          _buildToggleTile(
            icon: Icons.sms_outlined,
            label: 'SMS Notifications',
            subtitle: 'Critical appointment updates',
            value: _smsAlerts,
            onChanged: (v) => setState(() => _smsAlerts = v),
            color: const Color(0xFFE8F5E9),
            iconColor: kAccentGreen,
          ),
        ],
      ),
    );
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
    required Color color,
    required Color iconColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
                Text(subtitle, style: const TextStyle(fontSize: 12, color: kTextMuted)),
              ],
            ),
          ),
          Switch.adaptive(value: value, activeColor: kPrimaryBlue, onChanged: onChanged),
        ],
      ),
    );
  }

  // ── Appearance Card ───────────────────────────────────────────────────────

  Widget _buildAppearanceCard() {
    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: [
          _buildToggleTile(
            icon: Icons.dark_mode_outlined,
            label: 'Dark Mode',
            subtitle: 'Switch to dark theme',
            value: _darkMode,
            onChanged: (v) => setState(() => _darkMode = v),
            color: const Color(0xFFF3E5F5),
            iconColor: const Color(0xFF7B1FA2),
          ),
          const Divider(height: 1, indent: 56, color: kDivider),
          _buildNavTile(_SettingItem(icon: Icons.language_outlined, label: 'Language', subtitle: 'English (India)', trailing: null)),
          const Divider(height: 1, indent: 56, color: kDivider),
          _buildNavTile(_SettingItem(icon: Icons.text_fields_outlined, label: 'Text Size', subtitle: 'Medium', trailing: null)),
        ],
      ),
    );
  }

  // ── Support Card ──────────────────────────────────────────────────────────

  Widget _buildSupportCard() {
    final items = [
      _SettingItem(icon: Icons.help_outline, label: 'Help Center', subtitle: 'FAQs & documentation', trailing: null),
      _SettingItem(icon: Icons.chat_bubble_outline, label: 'Contact Support', subtitle: 'Chat, Email, Phone', trailing: null),
      _SettingItem(icon: Icons.privacy_tip_outlined, label: 'Privacy Policy', subtitle: null, trailing: null),
      _SettingItem(icon: Icons.description_outlined, label: 'Terms of Service', subtitle: null, trailing: null),
      _SettingItem(icon: Icons.info_outline, label: 'App Version', subtitle: 'v2.4.1 (Build 204)', trailing: null),
    ];

    return Container(
      decoration: _cardDecoration(),
      child: Column(
        children: items.asMap().entries.map((e) {
          return Column(
            children: [
              _buildNavTile(e.value),
              if (e.key < items.length - 1) const Divider(height: 1, indent: 56, color: kDivider),
            ],
          );
        }).toList(),
      ),
    );
  }

  // ── Logout Button ─────────────────────────────────────────────────────────

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Confirm logout', style: TextStyle(fontWeight: FontWeight.w700)),
              content: const Text('You will be signed out and returned to the Continue As screen.'),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(tokenProvider.notifier).clearTokens();
                    await ref.read(doctorLoginViewModelProvider.notifier).logout();
                    if (mounted) {
                      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const ContinueAsScreen()),
                        (_) => false,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: kRedAccent, foregroundColor: Colors.white),
                  child: const Text('Log out'),
                ),
              ],
            ),
          );
        },
        icon: const Icon(Icons.logout_rounded),
        label: const Text('Log out of account'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFCE8E6),
          foregroundColor: kRedAccent,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          padding: const EdgeInsets.symmetric(vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
        ),
      ),
    );
  }

  // ── Right Panel (Large Tablet) ────────────────────────────────────────────

  Widget _buildRightPanel() {
    return Container(
      margin: const EdgeInsets.fromLTRB(0, 20, 24, 20),
      decoration: _cardDecoration(),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Quick Stats', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: kTextDark)),
          const SizedBox(height: 16),
          _quickStatCard('Today\'s Appointments', '8', Icons.calendar_today_outlined, kPrimaryBlue),
          const SizedBox(height: 12),
          _quickStatCard('Pending Reports', '3', Icons.assignment_outlined, const Color(0xFFE65100)),
          const SizedBox(height: 12),
          _quickStatCard('New Messages', '12', Icons.message_outlined, kAccentGreen),
          const SizedBox(height: 24),
          const Text('Account Health', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: kTextDark)),
          const SizedBox(height: 12),
          _healthRow('Profile Completion', 0.85),
          const SizedBox(height: 8),
          _healthRow('Document Verification', 1.0),
          const SizedBox(height: 8),
          _healthRow('Rating Score', 0.97),
        ],
      ),
    );
  }

  Widget _quickStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kDivider),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted))),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: color)),
        ],
      ),
    );
  }

  Widget _healthRow(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(fontSize: 12, color: kTextMuted)),
            Text('${(value * 100).toInt()}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: kTextDark)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: kDivider,
            valueColor: AlwaysStoppedAnimation<Color>(value == 1.0 ? kAccentGreen : kPrimaryBlue),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  // ── Side Rail ─────────────────────────────────────────────────────────────

  Widget _buildSideRail() {
    final navItems = [
      _NavItem(icon: Icons.home_outlined, label: 'Home'),
      _NavItem(icon: Icons.calendar_month_outlined, label: 'Schedule'),
      _NavItem(icon: Icons.people_outline, label: 'Patients'),
      _NavItem(icon: Icons.settings_outlined, label: 'Settings'),
    ];

    return Container(
      width: 80,
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(right: BorderSide(color: kDivider)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 40),
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [kPrimaryBlue, Color(0xFF0D47A1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.local_hospital_rounded, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 32),
          ...navItems.asMap().entries.map((e) {
            final selected = e.key == _selectedNavIndex;
            return GestureDetector(
              onTap: () => setState(() => _selectedNavIndex = e.key),
              child: Container(
                margin: const EdgeInsets.symmetric(vertical: 4),
                width: 56,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: selected ? kLightBlue : Colors.transparent,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    Icon(e.value.icon, color: selected ? kPrimaryBlue : kTextMuted, size: 22),
                    const SizedBox(height: 4),
                    Text(
                      e.value.label,
                      style: TextStyle(fontSize: 9, color: selected ? kPrimaryBlue : kTextMuted, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
                    ),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Bottom Navigation ─────────────────────────────────────────────────────

  Widget _buildBottomNav() {
    return Container(
      decoration: const BoxDecoration(
        color: kCardBg,
        border: Border(top: BorderSide(color: kDivider)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _bottomNavItem(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
              _bottomNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month_rounded, 'Schedule'),
              _bottomNavItem(2, Icons.people_outline, Icons.people_rounded, 'Patients'),
              _bottomNavItem(3, Icons.settings_outlined, Icons.settings_rounded, 'Settings'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bottomNavItem(int index, IconData icon, IconData activeIcon, String label) {
    final selected = _selectedNavIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedNavIndex = index),
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: selected ? kLightBlue : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(selected ? activeIcon : icon, color: selected ? kPrimaryBlue : kTextMuted, size: 22),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: selected ? kPrimaryBlue : kTextMuted, fontWeight: selected ? FontWeight.w600 : FontWeight.normal),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: kCardBg,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 2)),
    ],
  );

  Widget _buildSectionTitle(String title) => Padding(
    padding: const EdgeInsets.only(left: 4, bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: kTextMuted, letterSpacing: 1.2),
    ),
  );
}

// ─── Models ───────────────────────────────────────────────────────────────────

class _SettingItem {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Widget? trailing;
  const _SettingItem({required this.icon, required this.label, this.subtitle, this.trailing});
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
