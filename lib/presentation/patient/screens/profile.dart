import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/screens/family_members_screen.dart';
import 'package:qless/presentation/patient/screens/patient_prescription_list.dart';
import 'package:qless/presentation/patient/screens/patient_edit_profile.dart'
    show PatientEditProfilePage;
import 'package:qless/presentation/shared/screens/continue_as.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary      = Color(0xFF26C6B0);
const kPrimaryDark  = Color(0xFF2BB5A0);
const kPrimaryLight = Color(0xFFD9F5F1);

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder   = Color(0xFFEDF2F7);
const kDivider  = Color(0xFFE5E7EB);

const kError    = Color(0xFFFC8181);
const kRedLight = Color(0xFFFEE2E2);

const kSuccess      = Color(0xFF68D391);
const kGreenLight   = Color(0xFFDCFCE7);

const kWarning      = Color(0xFFF6AD55);
const kAmberLight   = Color(0xFFFEF3C7);

const kPurple       = Color(0xFF9F7AEA);
const kPurpleLight  = Color(0xFFEDE9FE);

const kInfo         = Color(0xFF3B82F6);
const kInfoLight    = Color(0xFFDBEAFE);

const kIndigo       = Color(0xFF7F9CF5);
const kIndigoLight  = Color(0xFFE0E7FF);

// =============================================================================
// Screen
// =============================================================================

class PatientProfilePage extends ConsumerStatefulWidget {
  const PatientProfilePage({super.key});

  @override
  ConsumerState<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends ConsumerState<PatientProfilePage> {
  late final ProviderSubscription<PatientLoginState> _sub;
  bool _didFetchProfile = false;

  @override
  void initState() {
    super.initState();
    _sub = ref.listenManual<PatientLoginState>(
      patientLoginViewModelProvider,
      (prev, next) => _maybeFetchProfile(next),
    );
    Future.microtask(() {
      _maybeFetchProfile(ref.read(patientLoginViewModelProvider));
    });
  }

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }

  void _maybeFetchProfile(PatientLoginState state) {
    if (_didFetchProfile) return;
    final mobile = state.mobileNo;
    if (mobile != null && mobile.trim().isNotEmpty) {
      _didFetchProfile = true;
      ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
    }
  }

  // ---------------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final state   = ref.watch(patientLoginViewModelProvider);
    final details = state.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 100),
        child: Column(
          children: [
            _buildProfileCard(state, details),
            const SizedBox(height: 10),
            _buildStatsRow(details),
            const SizedBox(height: 10),
            _buildEditButton(context),
            const SizedBox(height: 14),
            _buildAccountSection(context, ref, state, details),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // AppBar
  // ---------------------------------------------------------------------------

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      automaticallyImplyLeading: false,
      centerTitle: true,
      title: const Text(
        'My Profile',
        style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: kTextPrimary,
            letterSpacing: -0.2),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorder, height: 1),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Profile Card
  // ---------------------------------------------------------------------------

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
      margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar + name row
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Gradient avatar
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [kPrimary, kPrimaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                alignment: Alignment.center,
                child: Text(
                  initials,
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary),
                    ),
                    if (contactLine.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(contactLine,
                          style: const TextStyle(
                              fontSize: 11, color: kTextMuted)),
                    ],
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 5,
                      runSpacing: 4,
                      children: [
                        if (gender.isNotEmpty)
                          _badge(gender, kPrimary, kPrimaryLight),
                        if (age != null)
                          _badge('$age yrs', kPrimary, kPrimaryLight),
                        if (bloodGroup != null && bloodGroup.trim().isNotEmpty)
                          _badge('$bloodGroup', kError, kRedLight),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          const _Divider(),

          // Info rows — compact 3-column grid
          Row(
            children: [
              Expanded(
                child: _infoTile(
                  Icons.calendar_today_rounded,
                  kPrimary,
                  kPrimaryLight,
                  'Date of Birth',
                  dob ?? '—',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  Icons.monitor_weight_outlined,
                  kWarning,
                  kAmberLight,
                  'Weight',
                  weight?.trim().isNotEmpty == true
                      ? '${weight!.trim()} kg'
                      : '58 kg',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _infoTile(
                  Icons.location_on_outlined,
                  const Color(0xFF38A169),
                  kGreenLight,
                  'Location',
                  'Maharashtra',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _badge(String label, Color fg, Color bg) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
        child: Text(label,
            style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
      );

  Widget _infoTile(
      IconData icon, Color iconFg, Color iconBg, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: iconBg.withOpacity(0.35),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: iconBg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 14, color: iconFg),
          const SizedBox(height: 5),
          Text(label,
              style: const TextStyle(fontSize: 10, color: kTextMuted)),
          const SizedBox(height: 1),
          Text(value,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: kTextPrimary),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Stats Row
  // ---------------------------------------------------------------------------

  Widget _buildStatsRow(Patients? details) {
    final blood = details?.bloodGroup;
    final stats = [
      _StatItem('12', 'Visits',  kPrimary,  kPrimaryLight),
      _StatItem('3',  'Family',  kPurple,   kPurpleLight),
      _StatItem(
        blood?.trim().isNotEmpty == true ? blood! : '5',
        'Records',
        kInfo,
        kInfoLight,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: stats.asMap().entries.map((e) {
          final i = e.key;
          final s = e.value;
          return Expanded(
            child: Container(
              margin: EdgeInsets.only(right: i < stats.length - 1 ? 8 : 0),
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: s.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: s.color.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  Text(s.value,
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: s.color)),
                  const SizedBox(height: 3),
                  Text(s.label,
                      style: const TextStyle(
                          fontSize: 11, color: kTextMuted)),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Edit Button
  // ---------------------------------------------------------------------------

  Widget _buildEditButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PatientEditProfilePage()),
        ),
        icon: const Icon(Icons.edit_outlined, size: 14, color: kPrimary),
        label: const Text('Edit Profile',
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: kPrimary)),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 42),
          side: const BorderSide(color: kPrimary, width: 1.5),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Account Section
  // ---------------------------------------------------------------------------

  Widget _buildAccountSection(
    BuildContext context,
    WidgetRef ref,
    PatientLoginState state,
    Patients? details,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            'ACCOUNT',
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: kTextMuted,
                letterSpacing: 1),
          ),
        ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: kBorder),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            children: [
              _menuRow(
                icon: Icons.person_outline_rounded,
                iconFg: kPrimary,
                iconBg: kPrimaryLight,
                title: 'Personal Information',
                subtitle: 'Name, DOB, gender',
                onTap: () =>
                    _showPersonalInfoSheet(context, state, details),
              ),
              _menuRow(
                icon: Icons.description_outlined,
                iconFg: kInfo,
                iconBg: kInfoLight,
                title: 'Medical Records',
                subtitle: 'Reports, prescriptions',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) =>
                          const PatientPrescriptionListScreen()),
                ),
              ),
              _menuRow(
                icon: Icons.group_outlined,
                iconFg: kPurple,
                iconBg: kPurpleLight,
                title: 'Family Members',
                subtitle: '3 members added',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => const FamilyMembersScreen()),
                ),
              ),
              _menuRow(
                icon: Icons.notifications_outlined,
                iconFg: kWarning,
                iconBg: kAmberLight,
                title: 'Notifications',
                subtitle: 'Alerts & reminders',
              ),
              _menuRow(
                icon: Icons.logout_rounded,
                iconFg: kError,
                iconBg: kRedLight,
                title: 'Log Out',
                subtitle: 'Sign out of account',
                titleColor: kError,
                chevronColor: kError.withOpacity(0.4),
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
    required Color iconFg,
    required Color iconBg,
    required String title,
    required String subtitle,
    Color titleColor = kTextPrimary,
    Color chevronColor = kTextMuted,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          borderRadius: BorderRadius.circular(14),
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 16, color: iconFg),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: titleColor)),
                      const SizedBox(height: 1),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 11, color: kTextMuted)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded,
                    size: 17, color: chevronColor),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              thickness: 1,
              color: kBorder,
              indent: 14,
              endIndent: 14),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Logout Dialog
  // ---------------------------------------------------------------------------

  void _showLogoutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
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
                    color: kRedLight, shape: BoxShape.circle),
                child: const Icon(Icons.logout_rounded,
                    size: 22, color: kError),
              ),
              const SizedBox(height: 12),
              const Text('Log Out?',
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: kTextPrimary)),
              const SizedBox(height: 6),
              const Text(
                'You will be signed out and returned to the start screen.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 13, color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: kBorder),
                        foregroundColor: kTextSecondary,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        Navigator.pop(context);
                        await ref
                            .read(tokenProvider.notifier)
                            .clearTokens();
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
                        backgroundColor: kError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Log Out',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Personal Info Sheet
  // ---------------------------------------------------------------------------

  void _showPersonalInfoSheet(
      BuildContext context, PatientLoginState state, Patients? details) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PersonalInfoSheet(
        name:       details?.name ?? state.name ?? '—',
        mobile:     details?.mobileNo ?? state.mobileNo ?? '—',
        email:      details?.email ?? state.email ?? '—',
        gender:     _displayGender(details).isNotEmpty
            ? _displayGender(details)
            : '—',
        dob:        _formatDob(details?.DOB) ?? '—',
        age:        _ageFromDob(details?.DOB)?.toString() ?? '—',
        bloodGroup: (details?.bloodGroup?.trim().isNotEmpty == true)
            ? details!.bloodGroup!
            : '—',
        weight:     (details?.weight?.trim().isNotEmpty == true)
            ? '${details!.weight!.trim()} kg'
            : '—',
        address:    (details?.address?.trim().isNotEmpty == true)
            ? details!.address!
            : '—',
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return 'P';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  String? _formatDob(DateTime? dob) {
    if (dob == null) return null;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${dob.day} ${months[dob.month - 1]} ${dob.year}';
  }

  int? _ageFromDob(DateTime? dob) {
    if (dob == null) return null;
    final now = DateTime.now();
    var age = now.year - dob.year;
    final hadBirthday = now.month > dob.month ||
        (now.month == dob.month && now.day >= dob.day);
    if (!hadBirthday) age--;
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

  String _joinNonEmpty(List<String> values, {String separator = ' '}) =>
      values.map((v) => v.trim()).where((v) => v.isNotEmpty).join(separator);
}

// =============================================================================
// Shared divider
// =============================================================================

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Divider(height: 1, thickness: 1, color: kBorder),
      );
}

// =============================================================================
// Personal Info Bottom Sheet
// =============================================================================

class _PersonalInfoSheet extends StatelessWidget {
  const _PersonalInfoSheet({
    required this.name,
    required this.mobile,
    required this.email,
    required this.gender,
    required this.dob,
    required this.age,
    required this.bloodGroup,
    required this.weight,
    required this.address,
  });

  final String name, mobile, email, gender, dob, age, bloodGroup, weight, address;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: kBorder, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 14),

          // Sheet header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                      color: kPrimaryLight,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.person_outline_rounded,
                      size: 17, color: kPrimary),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Personal Information',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: kTextPrimary)),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: kBorder)),
                    child: const Icon(Icons.close_rounded,
                        size: 15, color: kTextMuted),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: kBorder),
          const SizedBox(height: 4),

          _row(Icons.person_rounded,          kPrimary,  kPrimaryLight, 'Name',         name),
          _row(Icons.phone_outlined,           const Color(0xFF38A169), kGreenLight, 'Mobile',       mobile),
          _row(Icons.email_outlined,           kInfo,     kInfoLight,    'Email',         email),
          _row(Icons.wc_outlined,              kPurple,   kPurpleLight,  'Gender',        gender),
          _row(Icons.calendar_today_rounded,   kPrimary,  kPrimaryLight, 'Date of Birth', dob),
          _row(Icons.cake_outlined,            kWarning,  kAmberLight,   'Age',           age),
          _row(Icons.bloodtype_outlined,       kError,    kRedLight,     'Blood Group',   bloodGroup),
          _row(Icons.monitor_weight_outlined,  kWarning,  kAmberLight,   'Weight',        weight),
          _row(Icons.location_on_outlined,     const Color(0xFF38A169), kGreenLight, 'Address', address,
              isLast: true),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _row(IconData icon, Color fg, Color bg, String label, String value,
      {bool isLast = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                    color: bg, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 14, color: fg),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontSize: 11, color: kTextMuted)),
                    const SizedBox(height: 2),
                    Text(value,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: kTextPrimary)),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Divider(
              height: 1,
              thickness: 1,
              color: kBorder,
              indent: 16,
              endIndent: 16),
      ],
    );
  }
}

// =============================================================================
// Stat item model
// =============================================================================

class _StatItem {
  final String value, label;
  final Color color, bgColor;
  const _StatItem(this.value, this.label, this.color, this.bgColor);
}