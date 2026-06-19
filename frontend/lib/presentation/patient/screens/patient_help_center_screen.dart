import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

const _primary = Color(0xFF26C6B0);
const _primaryDark = Color(0xFF2BB5A0);
const _primaryLight = Color(0xFFD9F5F1);
const _primaryLighter = Color(0xFFF2FCFA);
const _textPrimary = Color(0xFF2D3748);
const _textSecondary = Color(0xFF718096);
const _textMuted = Color(0xFFA0AEC0);
const _border = Color(0xFFEDF2F7);
const _divider = Color(0xFFE5E7EB);
const _error = Color(0xFFFC8181);
const _redLight = Color(0xFFFEE2E2);
const _success = Color(0xFF68D391);
const _greenLight = Color(0xFFDCFCE7);
const _warning = Color(0xFFF6AD55);
const _amberLight = Color(0xFFFEF3C7);
const _purple = Color(0xFF9F7AEA);
const _purpleLight = Color(0xFFEDE9FE);
const _info = Color(0xFF3B82F6);
const _infoLight = Color(0xFFDBEAFE);

class PatientHelpCenterPage extends StatefulWidget {
  const PatientHelpCenterPage({super.key});

  @override
  State<PatientHelpCenterPage> createState() => _PatientHelpCenterPageState();
}

class _PatientHelpCenterPageState extends State<PatientHelpCenterPage> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<_HelpSection> get _filteredSections {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return _helpSections;

    return _helpSections
        .map((section) {
          final topics = section.topics.where((topic) {
            final text = [
              section.title,
              section.summary,
              topic.title,
              topic.body,
              ...topic.steps,
              ...topic.tips,
            ].join(' ').toLowerCase();
            return text.contains(q);
          }).toList();
          return section.copyWith(topics: topics);
        })
        .where((section) => section.topics.isNotEmpty)
        .toList();
  }

  Future<void> _openPrivacyPolicy() async {
    final uri = Uri.parse('https://qless.vengurlatech.com/login/privacy');
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final sections = _filteredSections;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _HelpHeader(
            searchCtrl: _searchCtrl,
            onBack: () => Navigator.pop(context),
            onChanged: (value) => setState(() => _query = value),
            onClear: _query.isEmpty
                ? null
                : () {
                    _searchCtrl.clear();
                    setState(() => _query = '');
                  },
          ),
          Expanded(
            child: sections.isEmpty
                ? _EmptyHelpSearch(query: _query)
                : ListView(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 28),
                    children: [
                      _ContactStrip(onOpenPrivacy: _openPrivacyPolicy),
                      const SizedBox(height: 14),
                      ...sections.map(_HelpSectionCard.new),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _HelpHeader extends StatelessWidget {
  const _HelpHeader({
    required this.searchCtrl,
    required this.onBack,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController searchCtrl;
  final VoidCallback onBack;
  final ValueChanged<String> onChanged;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _border, width: 1)),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
          child: Column(
            children: [
              Row(
                children: [
                  InkWell(
                    onTap: onBack,
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: _primaryLight,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _primary.withOpacity(0.2)),
                      ),
                      child: const Icon(
                        Icons.arrow_back_rounded,
                        color: _primary,
                        size: 18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Patient Help Center',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Guides for appointments and health records',
                          style: TextStyle(fontSize: 12, color: _textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: searchCtrl,
                onChanged: onChanged,
                textInputAction: TextInputAction.search,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF1A1D2E)),
                decoration: InputDecoration(
                  hintText: 'Search booking, family, prescription...',
                  hintStyle:
                      const TextStyle(color: _textMuted, fontSize: 12, fontWeight: FontWeight.w500),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    size: 18,
                    color: _textMuted,
                  ),
                  suffixIcon: onClear == null
                      ? null
                      : IconButton(
                          onPressed: onClear,
                          icon: const Icon(
                            Icons.close_rounded,
                            size: 17,
                            color: _textMuted,
                          ),
                        ),
                  filled: true,
                  fillColor: const Color(0xFFF7F8FA),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: _primary),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ContactStrip extends StatelessWidget {
  const _ContactStrip({required this.onOpenPrivacy});

  final VoidCallback onOpenPrivacy;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _primaryLighter,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _primaryLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.support_agent_rounded, color: _primary, size: 20),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Find help for booking doctors, managing appointments, family members, prescriptions, reviews, and account settings.',
                  style: TextStyle(
                    color: _textSecondary,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: _ActionButton(
                  icon: Icons.mail_outline_rounded,
                  label: 'support@vengurlatech.com',
                  isPrimary: true,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.privacy_tip_outlined,
                  label: 'Privacy',
                  onTap: onOpenPrivacy,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    this.onTap,
    this.isPrimary = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool isPrimary;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: isPrimary ? _primary : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isPrimary ? _primary : _border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 16, color: isPrimary ? Colors.white : _textPrimary),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: isPrimary ? Colors.white : _textPrimary,
              ),
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return child;

    return SizedBox(
      height: 40,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: child,
        ),
      ),
    );
  }
}

class _HelpSectionCard extends StatelessWidget {
  const _HelpSectionCard(this.section);

  final _HelpSection section;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: section.initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: section.iconBg,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(section.icon, color: section.iconColor, size: 18),
          ),
          title: Text(
            section.title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
          ),
          subtitle: Text(
            section.summary,
            style:
                const TextStyle(fontSize: 12, color: _textMuted, height: 1.35),
          ),
          iconColor: _primary,
          collapsedIconColor: _textMuted,
          children: [
            const Divider(height: 1, color: _divider),
            const SizedBox(height: 10),
            ...section.topics.map(_HelpTopicTile.new),
          ],
        ),
      ),
    );
  }
}

class _HelpTopicTile extends StatelessWidget {
  const _HelpTopicTile(this.topic);

  final _HelpTopic topic;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            topic.title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          if (topic.body.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              topic.body,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                height: 1.45,
              ),
            ),
          ],
          if (topic.steps.isNotEmpty) ...[
            const SizedBox(height: 9),
            ...topic.steps.asMap().entries.map((entry) {
              return _StepLine(index: entry.key + 1, text: entry.value);
            }),
          ],
          if (topic.tips.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...topic.tips.map((tip) => _TipLine(text: tip)),
          ],
        ],
      ),
    );
  }
}

class _StepLine extends StatelessWidget {
  const _StepLine({required this.index, required this.text});

  final int index;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration:
                const BoxDecoration(color: _primaryLight, shape: BoxShape.circle),
            child: Text(
              '$index',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _primaryDark,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  const _TipLine({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline_rounded,
              size: 15, color: _success),
          const SizedBox(width: 7),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 12,
                color: _textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHelpSearch extends StatelessWidget {
  const _EmptyHelpSearch({required this.query});

  final String query;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 54,
              height: 54,
              decoration:
                  const BoxDecoration(color: _primaryLight, shape: BoxShape.circle),
              child: const Icon(Icons.search_off_rounded,
                  color: _primary, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              'No help topics found for "$query"',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Try searching for appointment, doctor, prescription, family, review, or profile.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: _textMuted, height: 1.4),
            ),
          ],
        ),
      ),
    );
  }
}

class _HelpSection {
  const _HelpSection({
    required this.title,
    required this.summary,
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.topics,
    this.initiallyExpanded = false,
  });

  final String title;
  final String summary;
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final List<_HelpTopic> topics;
  final bool initiallyExpanded;

  _HelpSection copyWith({required List<_HelpTopic> topics}) {
    return _HelpSection(
      title: title,
      summary: summary,
      icon: icon,
      iconColor: iconColor,
      iconBg: iconBg,
      topics: topics,
      initiallyExpanded: true,
    );
  }
}

class _HelpTopic {
  const _HelpTopic({
    required this.title,
    this.body = '',
    this.steps = const [],
    this.tips = const [],
  });

  final String title;
  final String body;
  final List<String> steps;
  final List<String> tips;
}

const _helpSections = [
  _HelpSection(
    title: 'Getting Started',
    summary: 'Login, OTP, profile setup, and dashboard basics',
    icon: Icons.login_rounded,
    iconColor: _primary,
    iconBg: _primaryLight,
    initiallyExpanded: true,
    topics: [
      _HelpTopic(
        title: 'Sign in as a patient',
        body:
            'Use your registered mobile number to sign in. OTP verification opens the patient app with home, appointments, doctors, and profile tabs.',
        steps: [
          'Choose Continue as Patient on the start screen.',
          'Enter your mobile number and request OTP.',
          'Submit the OTP to open your patient account.',
        ],
        tips: [
          'Use the same mobile number that you used during registration.',
          'If OTP verification fails, check network connectivity and retry.',
        ],
      ),
      _HelpTopic(
        title: 'Complete your profile',
        body:
            'A complete profile helps clinics identify you correctly and keeps prescriptions linked to the right patient.',
        steps: [
          'Open Profile.',
          'Tap the edit icon on the profile card.',
          'Update name, date of birth, gender, blood group, weight, address, email, and mobile details.',
          'Save and refresh the profile if the new data does not appear immediately.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Find and Book Doctors',
    summary: 'Search doctors, view profiles, favorite doctors, and book visits',
    icon: Icons.medical_services_outlined,
    iconColor: _info,
    iconBg: _infoLight,
    topics: [
      _HelpTopic(
        title: 'Search for doctors',
        body:
            'Use the doctor explore and search screens to find doctors by clinic, specialization, or visible profile details.',
        steps: [
          'Open the doctor search or explore area.',
          'Search by doctor name, clinic, location, or specialization.',
          'Open a doctor profile to review clinic details, experience, fee, rating, and reviews.',
        ],
      ),
      _HelpTopic(
        title: 'Book an appointment',
        body:
            'Appointments are created from the doctor booking page using the selected patient or family member.',
        steps: [
          'Open a doctor profile or booking screen.',
          'Choose the patient or family member for the visit.',
          'Select the available date and time.',
          'Confirm the booking and check it in Appointments.',
        ],
        tips: [
          'Confirm clinic location and consultation fee before booking.',
          'Use the correct family member so prescriptions are saved to the right record.',
        ],
      ),
      _HelpTopic(
        title: 'Favorite doctors',
        body:
            'Favorite doctors make it easier to return to clinics you visit often.',
        tips: [
          'Tap the favorite icon on supported doctor pages.',
          'Favorites are tied to your patient account.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Appointments',
    summary: 'View, cancel, reschedule, and review visits',
    icon: Icons.event_note_outlined,
    iconColor: _success,
    iconBg: _greenLight,
    topics: [
      _HelpTopic(
        title: 'View appointments',
        body:
            'The Appointments tab shows upcoming, active, completed, and cancelled appointment records.',
        tips: [
          'Pull down to refresh if a new booking is not visible.',
          'Use search and filters when your appointment list is long.',
        ],
      ),
      _HelpTopic(
        title: 'Cancel or reschedule',
        body:
            'Cancel and reschedule actions appear only when the appointment status allows them.',
        steps: [
          'Open Appointments.',
          'Find the upcoming appointment.',
          'Use Cancel or Reschedule when the button is available.',
          'Refresh the list after confirmation.',
        ],
      ),
      _HelpTopic(
        title: 'Review a completed visit',
        body:
            'After a completed appointment, you can submit a rating and comment for the doctor.',
        steps: [
          'Open the completed appointment.',
          'Tap Review when available.',
          'Choose a rating, add a useful comment, and submit.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Prescriptions and Records',
    summary: 'Read prescriptions, filter records, and open PDFs',
    icon: Icons.description_outlined,
    iconColor: _primary,
    iconBg: _primaryLight,
    topics: [
      _HelpTopic(
        title: 'View prescriptions',
        body:
            'Medical Records in Profile opens your prescription list. Prescriptions can also be opened from completed appointments.',
        steps: [
          'Open Profile and tap Medical Records.',
          'Use search, filters, date filters, or family member filters.',
          'Tap a prescription to view doctor, clinic, medicines, dosage, and instructions.',
        ],
      ),
      _HelpTopic(
        title: 'Open or print prescription PDF',
        body:
            'Prescription detail pages include a PDF view for sharing or printing when supported by the device.',
        tips: [
          'Check that the prescription belongs to the right patient or family member.',
          'If a prescription is missing, refresh the list or open it from the related appointment.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Family Members',
    summary: 'Add family profiles and book appointments for them',
    icon: Icons.group_outlined,
    iconColor: _purple,
    iconBg: _purpleLight,
    topics: [
      _HelpTopic(
        title: 'Add a family member',
        body:
            'Family members let you manage appointments and records for dependents from your account.',
        steps: [
          'Open Profile.',
          'Tap Family Members.',
          'Add the member details and save.',
          'Use that member while booking appointments or filtering prescriptions.',
        ],
      ),
      _HelpTopic(
        title: 'Delete or update family data',
        body:
            'Keep family member details accurate so clinics can identify the correct patient.',
        tips: [
          'Review date of birth, gender, and contact details before booking.',
          'Remove family members that should no longer be managed from your account.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Profile and Account',
    summary: 'Personal details, privacy policy, and logout',
    icon: Icons.manage_accounts_outlined,
    iconColor: _warning,
    iconBg: _amberLight,
    topics: [
      _HelpTopic(
        title: 'Understand profile stats',
        body:
            'Profile stats summarize completed visits, family members, and prescription records linked to your patient account.',
      ),
      _HelpTopic(
        title: 'Privacy policy',
        body:
            'Use Privacy Policy in Profile or this Help Center to read how QLess handles data.',
      ),
      _HelpTopic(
        title: 'Logout safely',
        body:
            'Use logout when changing devices or sharing your phone with someone else.',
        steps: [
          'Open Profile.',
          'Tap Log Out.',
          'Confirm the dialog to clear the session and return to the start screen.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Troubleshooting',
    summary: 'Common fixes for loading, booking, and missing records',
    icon: Icons.build_circle_outlined,
    iconColor: _error,
    iconBg: _redLight,
    topics: [
      _HelpTopic(
        title: 'Appointment is not visible',
        body:
            'Appointments load from your patient account and may need a refresh after booking, cancelling, or rescheduling.',
        tips: [
          'Pull down on Appointments to refresh.',
          'Confirm you booked with the correct patient account or family member.',
          'Check your internet connection and retry.',
        ],
      ),
      _HelpTopic(
        title: 'Prescription is missing',
        body:
            'A prescription appears after the clinic has saved it for your completed appointment.',
        tips: [
          'Open the related completed appointment and tap View Prescription.',
          'Refresh Medical Records.',
          'Ask the clinic to confirm the prescription was saved.',
        ],
      ),
      _HelpTopic(
        title: 'Profile data looks wrong',
        body:
            'Profile data is fetched from your registered patient mobile number.',
        steps: [
          'Pull down on Profile to refresh.',
          'Edit the profile if a field is outdated.',
          'Log out and sign in again if the wrong account is loaded.',
        ],
      ),
      _HelpTopic(
        title: 'Need more help',
        body:
            'Email support@vengurlatech.com with your registered mobile number, patient name, and a short description of the issue.',
        tips: [
          'Mention the screen where the problem happened.',
          'Add appointment date or doctor name when reporting booking issues.',
        ],
      ),
    ],
  ),
];
