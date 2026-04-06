import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/core/network/token_provider.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/patient/screens/patient_edit_profile.dart'
    show PatientEditProfilePage;
import 'package:qless/presentation/shared/screens/continue_as.dart';

// ── Colour palette ────────────────────────────────────────────
const kPrimary  = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg       = Color(0xFFF4F6FB);
const kCardBg   = Colors.white;
const kTextDark = Color(0xFF1F2937);
const kTextMid  = Color(0xFF6B7280);
const kBorder   = Color(0xFFE5E7EB);
const kRed      = Color(0xFFEA4335);
const kGreen    = Color(0xFF34A853);
const kOrange   = Color(0xFFF59E0B);
const kPurple   = Color(0xFF8B5CF6);
const kCyan     = Color(0xFF06B6D4);

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
      ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
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
            _buildHeader(context, patientState, patientDetails),
            const SizedBox(height: 16),
            _buildEditButton(context),
            const SizedBox(height: 12),
            _buildStatsGrid(patientState, patientDetails),
            const SizedBox(height: 20),
            _buildAccountSection(context, ref),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  // ── AppBar / Header ───────────────────────────────────────────
  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: kCardBg,
      elevation: 0,
      automaticallyImplyLeading: false,
      title: const Text(
        'My Profile',
        style: TextStyle(
          color: kTextDark,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Container(color: kBorder, height: 0.5),
      ),
    );
  }

  // ── Profile avatar + name + tags ──────────────────────────────
  Widget _buildHeader(
    BuildContext context,
    PatientLoginState state,
    Patients? details,
  ) {
    final displayName = details?.name ?? state.name ?? 'Patient';
    final email = details?.email ?? state.email ?? '';
    final mobile = details?.mobileNo ?? state.mobileNo ?? '';
    final gender = _displayGender(details);
    final age = _ageFromDob(details?.DOB);
    final bloodGroup = details?.bloodGroup;
    final contactLine = _joinNonEmpty([email, mobile], separator: ' · ');
    return Container(
      width: double.infinity,
      color: kCardBg,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: kPrimaryBg,
                  border: Border.all(color: kPrimary, width: 3),
                ),
                child: const Icon(Icons.person, size: 44, color: kPrimary),
              ),
              Positioned(
                bottom: 2,
                right: 2,
                child: Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kGreen,
                    border: Border.all(color: kCardBg, width: 2.5),
                  ),
                  child: const Icon(Icons.check, size: 12, color: kCardBg),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            displayName,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 4),
          if (contactLine.isNotEmpty)
            Text(
              contactLine,
              style: const TextStyle(fontSize: 12, color: kTextMid),
            ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            children: [
              if (gender.isNotEmpty) _tag(gender, kPrimary, kPrimaryBg),
              if (age != null) _tag('Age $age', kPrimary, kPrimaryBg),
              if (bloodGroup != null && bloodGroup.trim().isNotEmpty)
                _tag('$bloodGroup Blood', kRed, const Color(0xFFFDEAEA)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _tag(String label, Color fg, Color bg) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }

  // ── Edit Profile button ───────────────────────────────────────
  Widget _buildEditButton(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: OutlinedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (_) => const PatientEditProfilePage()),
        ),
        icon: const Icon(Icons.edit_outlined, size: 16, color: kPrimary),
        label: const Text(
          'Edit Profile',
          style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: kPrimary),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 48),
          side: const BorderSide(color: kBorder),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          backgroundColor: kCardBg,
        ),
      ),
    );
  }

  // ── 6 Stats cards (white bg, coloured icon) ───────────────────
  Widget _buildStatsGrid(PatientLoginState state, Patients? details) {
    final weight = details?.weight;
    final blood = details?.bloodGroup;
    final int? familyCount = null;
    final items = [
      _StatItem(weight?.trim().isNotEmpty == true ? '$weight kg' : '58 kg',
          'Weight', Icons.monitor_weight_outlined, kPrimary, kPrimaryBg),
      _StatItem('162 cm', 'Height',  Icons.height_rounded,
          kPurple, const Color(0xFFEDE9FE)),
      _StatItem(blood?.trim().isNotEmpty == true ? blood! : 'B+',
          'Blood', Icons.bloodtype_outlined, kRed, const Color(0xFFFDEAEA)),
      _StatItem('12',     'Visits',  Icons.calendar_today_rounded,
          kGreen,  const Color(0xFFDCFCE7)),
      _StatItem(familyCount?.toString() ?? '3', 'Family',
          Icons.group_outlined, kOrange, const Color(0xFFFEF3C7)),
      _StatItem('5',      'Records', Icons.description_outlined,
          kCyan,   const Color(0xFFCFFAFE)),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 3,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
        children: items.map(_buildStatCard).toList(),
      ),
    );
  }

  Widget _buildStatCard(_StatItem item) {
    return Container(
      decoration: BoxDecoration(
        color: kCardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: kBorder, width: 0.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: item.iconBg,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(item.icon, size: 17, color: item.iconColor),
          ),
          const SizedBox(height: 8),
          Text(
            item.value,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: kTextDark,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.label,
            style: const TextStyle(fontSize: 11, color: kTextMid),
          ),
        ],
      ),
    );
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
    final filtered = values.map((v) => v.trim()).where((v) => v.isNotEmpty);
    return filtered.join(separator);
  }

  // ── Account menu list ─────────────────────────────────────────
  Widget _buildAccountSection(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            'ACCOUNT',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: kTextMid,
              letterSpacing: 1.2,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: kCardBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder, width: 0.5),
          ),
          child: Column(
            children: [
              _menuItem(
                icon: Icons.person_outline,
                iconColor: kPrimary,
                iconBg: kPrimaryBg,
                title: 'Personal Information',
                subtitle: 'Name, DOB, Gender',
              ),
              _menuItem(
                icon: Icons.location_on_outlined,
                iconColor: kOrange,
                iconBg: const Color(0xFFFEF3C7),
                title: 'Address',
                subtitle: 'Home, City, ZIP',
              ),
              _menuItem(
                icon: Icons.description_outlined,
                iconColor: kCyan,
                iconBg: const Color(0xFFCFFAFE),
                title: 'Medical Records',
                subtitle: 'Reports, Prescriptions',
              ),
              _menuItem(
                icon: Icons.group_outlined,
                iconColor: kPurple,
                iconBg: const Color(0xFFEDE9FE),
                title: 'Family Members',
                subtitle: '3 members added',
              ),
              _menuItem(
                icon: Icons.notifications_outlined,
                iconColor: kOrange,
                iconBg: const Color(0xFFFEF3C7),
                title: 'Notifications',
                subtitle: 'Alerts & reminders',
              ),
              _menuItem(
                icon: Icons.logout,
                iconColor: kRed,
                iconBg: const Color(0xFFFDEAEA),
                title: 'Log out',
                subtitle: 'Log out of account',
                titleColor: kRed,
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      title: const Text(
                        'Confirm logout',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      content: const Text(
                        'You will be signed out and returned to the Continue As screen.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            await ref.read(tokenProvider.notifier).clearTokens();
                            await ref.read(patientLoginViewModelProvider.notifier).logout();
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
                          ),
                          child: const Text('Log out'),
                        ),
                      ],
                    ),
                  );
                },
                showDivider: false,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _menuItem({
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    Color titleColor = kTextDark,
    bool showDivider = true,
    VoidCallback? onTap,
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap ?? () {},
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 13),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 18, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: titleColor)),
                      const SizedBox(height: 2),
                      Text(subtitle,
                          style: const TextStyle(
                              fontSize: 12, color: kTextMid)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right,
                    size: 18,
                    color: titleColor == kRed ? kRed : kTextMid),
              ],
            ),
          ),
        ),
        if (showDivider)
          const Divider(
              height: 1,
              thickness: 0.5,
              color: kBorder,
              indent: 14,
              endIndent: 14),
      ],
    );
  }
}

// ── Helper model ──────────────────────────────────────────────
class _StatItem {
  final String value, label;
  final IconData icon;
  final Color iconColor, iconBg;
  const _StatItem(this.value, this.label, this.icon,
      this.iconColor, this.iconBg);
}
