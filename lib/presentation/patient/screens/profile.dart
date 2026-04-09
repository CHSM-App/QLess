import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/screens/patient_edit_profile.dart'
    show PatientEditProfilePage;
import 'package:qless/presentation/shared/screens/continue_as.dart';

// ── Colour palette ─────────────────────────────────────────────
const kPrimary    = Color(0xFF1A73E8);
const kPrimaryBg  = Color(0xFFE8F0FE);
const kPrimaryText= Color(0xFF1558A8);
const kBg         = Color(0xFFF7F8FA);
const kCardBg     = Colors.white;
const kTextDark   = Color(0xFF111827);
const kTextMid    = Color(0xFF6B7280);
const kTextLight  = Color(0xFF9CA3AF);
const kBorder     = Color(0xFFE5E7EB);
const kRed        = Color(0xFFDC2626);
const kRedBg      = Color(0xFFFEF2F2);
const kRedText    = Color(0xFFA02B2B);
const kRedBadgeBg = Color(0xFFFDEBEB);
const kGreen      = Color(0xFF1E7D3A);
const kGreenBg    = Color(0xFFE6F4EA);
const kOrange     = Color(0xFFC2620A);
const kOrangeBg   = Color(0xFFFFF7ED);
const kPurple     = Color(0xFF7C3AED);
const kPurpleBg   = Color(0xFFF5F3FF);
const kCyan       = Color(0xFF0891B2);
const kCyanBg     = Color(0xFFEFF9F6);

class PatientProfilePage extends ConsumerStatefulWidget {
  const PatientProfilePage({super.key});

  @override
  ConsumerState<PatientProfilePage> createState() =>
      _PatientProfilePageState();
}

class _PatientProfilePageState extends ConsumerState<PatientProfilePage> {
  late final ProviderSubscription<PatientLoginState> _patientLoginSub;
  bool _didFetchProfile = false;

  @override
  void initState() {
    super.initState();
    _patientLoginSub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) => _maybeFetchProfile(next),
    );
    Future.microtask(() {
      final state = ref.read(patientLoginViewModelProvider);
      _maybeFetchProfile(state);
    });
  }

  @override
  void dispose() {
    _patientLoginSub.close();
    super.dispose();
  }

  void _maybeFetchProfile(PatientLoginState state) {
    if (_didFetchProfile) return;
    final mobile = state.mobileNo;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _didFetchProfile = true;
      ref
          .read(patientLoginViewModelProvider.notifier)
          .checkPhonePatient(mobile);
    }
  }

  @override
  Widget build(BuildContext context) {
    final patientState = ref.watch(patientLoginViewModelProvider);
    final patientDetails = patientState.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: kBg,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        child: Column(
          children: [
            _buildProfileCard(patientState, patientDetails),
            const SizedBox(height: 12),
            _buildStatsRow(patientDetails),
            const SizedBox(height: 12),
            _buildEditButton(context),
            const SizedBox(height: 16),
            _buildAccountSection(context, ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardBg,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text(
        'My Profile',
        style: TextStyle(
          color: kTextDark,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(0.5),
        child: Container(color: kBorder, height: 0.5),
      ),
    );
  }

  // ── Profile Card ───────────────────────────────────────────────
  Widget _buildProfileCard(PatientLoginState state, Patients? details) {
    final displayName = details?.name ?? state.name ?? 'Patient';
    final email       = details?.email ?? state.email ?? '';
    final mobile      = details?.mobileNo ?? state.mobileNo ?? '';
    final gender      = _displayGender(details);
    final age         = _ageFromDob(details?.DOB);
    final bloodGroup  = details?.bloodGroup;
    final dob         = _formatDob(details?.DOB);
    final weight      = details?.weight;
    final initials    = _initials(displayName);
    final contactLine = _joinNonEmpty([email, mobile], separator: ' · ');

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Initials avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimaryBg,
                  border: Border.all(color: kPrimary, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: kPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: kTextDark,
                      ),
                    ),
                    if (contactLine.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        contactLine,
                        style: const TextStyle(
                            fontSize: 12, color: kTextMid),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (gender.isNotEmpty)
                          _badge(gender, kPrimaryText, kPrimaryBg),
                        if (age != null)
                          _badge('Age $age', kPrimaryText, kPrimaryBg),
                        if (bloodGroup != null &&
                            bloodGroup.trim().isNotEmpty)
                          _badge(
                              '$bloodGroup Blood', kRedText, kRedBadgeBg),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const _Divider(),

          // Info rows
          _infoRow(Icons.calendar_today_rounded, kPrimary, kPrimaryBg,
              'Date of birth', dob ?? '—'),
          const SizedBox(height: 10),
          _infoRow(Icons.location_on_outlined, kGreen, kGreenBg,
              'Address', 'Savantavadi, Maharashtra'),
          const SizedBox(height: 10),
          _infoRow(Icons.monitor_weight_outlined, kOrange, kOrangeBg,
              'Weight · Height',
              '${weight?.trim().isNotEmpty == true ? '$weight kg' : '58 kg'} · 162 cm'),
        ],
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style:
            TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  Widget _infoRow(IconData icon, Color iconColor, Color iconBg,
      String label, String value) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(7),
          ),
          child: Icon(icon, size: 13, color: iconColor),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style:
                    const TextStyle(fontSize: 11, color: kTextMid)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextDark)),
          ],
        ),
      ],
    );
  }

  // ── Stats Row ──────────────────────────────────────────────────
  Widget _buildStatsRow(Patients? details) {
    final blood = details?.bloodGroup;

    final stats = [
      _StatItem('12',   'Visits',  kPrimary),
      _StatItem('3',    'Family',  kPurple),
      _StatItem(blood?.trim().isNotEmpty == true ? blood! : '5',
                'Records', kCyan),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: stats
            .map(
              (s) => Expanded(
                child: Container(
                  margin: EdgeInsets.only(
                      right: s == stats.last ? 0 : 8),
                  decoration: BoxDecoration(
                    color: kCardBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder, width: 0.5),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      Text(
                        s.value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.color,
                        ),
                      ),
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.symmetric(vertical: 5),
                        decoration: BoxDecoration(
                          color: s.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      Text(
                        s.label,
                        style: const TextStyle(
                            fontSize: 10, color: kTextLight),
                      ),
                    ],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  // ── Edit Button ────────────────────────────────────────────────
  Widget _buildEditButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PatientEditProfilePage()),
        ),
        icon: const Icon(Icons.edit_outlined, size: 14, color: kPrimary),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: kPrimary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 44),
          side: const BorderSide(color: kPrimary, width: 1.5),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: kCardBg,
        ),
      ),
    );
  }

  // ── Account Section ────────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 14, bottom: 8),
          child: Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextLight,
              letterSpacing: 0.8,
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            children: [
              _menuRow(
                icon: Icons.person_outline,
                iconColor: kPrimary,
                iconBg: kPrimaryBg,
                title: 'Personal information',
                subtitle: 'Name, DOB, gender',
              ),
              _menuRow(
                icon: Icons.location_on_outlined,
                iconColor: kOrange,
                iconBg: kOrangeBg,
                title: 'Address',
                subtitle: 'Home, city, ZIP',
              ),
              _menuRow(
                icon: Icons.description_outlined,
                iconColor: kCyan,
                iconBg: kCyanBg,
                title: 'Medical records',
                subtitle: 'Reports, prescriptions',
              ),
              _menuRow(
                icon: Icons.group_outlined,
                iconColor: kPurple,
                iconBg: kPurpleBg,
                title: 'Family members',
                subtitle: '3 members added',
              ),
              _menuRow(
                icon: Icons.notifications_outlined,
                iconColor: kOrange,
                iconBg: kOrangeBg,
                title: 'Notifications',
                subtitle: 'Alerts & reminders',
              ),
              _menuRow(
                icon: Icons.logout_rounded,
                iconColor: kRed,
                iconBg: kRedBg,
                title: 'Log out',
                subtitle: 'Sign out of account',
                titleColor: kRed,
                chevronColor: const Color(0xFFFCA5A5),
                showDivider: false,
                onTap: () => _showLogoutDialog(context, ref),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuRow({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Color titleColor = kTextDark,
    Color chevronColor = kTextLight,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(icon, size: 15, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: titleColor),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: const TextStyle(
                            fontSize: 11, color: kTextLight),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 16, color: chevronColor),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
              height: 0.5,
              thickness: 0.5,
              color: kBorder,
              indent: 14,
              endIndent: 14),
      ],
    );
  }

  // ── Logout Dialog ──────────────────────────────────────────────
  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: const Text('Confirm logout',
            style: TextStyle(fontWeight: FontWeight.w700)),
        content: const Text(
            'You will be signed out and returned to the start screen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              await ref.read(tokenProvider.notifier).clearTokens();
              await ref
                  .read(patientLoginViewModelProvider.notifier)
                  .logout();
              if (!context.mounted) return;
              Navigator.of(context, rootNavigator: true)
                  .pushAndRemoveUntil(
                MaterialPageRoute(
                    builder: (_) => const ContinueAsScreen()),
                (_) => false,
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Log out'),
          ),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────
  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? _formatDob(DateTime? dob) {
    if (dob == null) return null;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${dob.day} ${months[dob.month - 1]} ${dob.year}';
  }

  int? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hasHadBirthday = (now.month > dob.month) ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hasHadBirthday) age -= 1;
    return age >= 0 ? age : null;
  }

  String _displayGender(Patients? details) {
    final g = details?.gender?.trim();
    if (g != null && g.isNotEmpty) return g;
    final id = details?.genderId;
    if (id == null) return '';
    if (id == 2) return 'Female';
    if (id == 3) return 'Other';
    return 'Male';
  }

  String _joinNonEmpty(List<String> values, {String separator = ' '}) {
    return values
        .map((v) => v.trim())
        .where((v) => v.isNotEmpty)
        .join(separator);
  }
}

// ── Shared divider ─────────────────────────────────────────────
class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Divider(height: 0.5, thickness: 0.5, color: kBorder),
    );
  }
}

// ── Stat item model ────────────────────────────────────────────
class _StatItem {
  final String value, label;
  final Color color;
  const _StatItem(this.value, this.label, this.color);
}