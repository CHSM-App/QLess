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

class DoctorHelpCenterPage extends StatefulWidget {
  const DoctorHelpCenterPage({super.key});

  @override
  State<DoctorHelpCenterPage> createState() => _DoctorHelpCenterPageState();
}

class _DoctorHelpCenterPageState extends State<DoctorHelpCenterPage> {
  final TextEditingController _searchCtrl = TextEditingController();
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
            final haystack = [
              section.title,
              section.summary,
              topic.title,
              topic.body,
              ...topic.steps,
              ...topic.tips,
            ].join(' ').toLowerCase();
            return haystack.contains(q);
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
                      _ContactStrip(
                        onOpenPrivacy: _openPrivacyPolicy,
                      ),
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
                          'Doctor Help Center',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: _textPrimary,
                          ),
                        ),
                        SizedBox(height: 1),
                        Text(
                          'Guides for every doctor workflow',
                          style: TextStyle(
                            fontSize: 12,
                            color: _textMuted,
                          ),
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
                  hintText: 'Search profile, queue, prescriptions...',
                  hintStyle: const TextStyle(
                    color: _textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
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
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
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
  const _ContactStrip({
    required this.onOpenPrivacy,
  });

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
                  'Find help for setup, queue management, patient visits, medicine, prescriptions, reviews, and account settings.',
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
              Expanded(
                child: _ActionButton(
                  icon: Icons.mail_outline_rounded,
                  label: 'support@vengurlatech.com',
                  isPrimary: true,
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
          Icon(
            icon,
            size: 16,
            color: isPrimary ? Colors.white : _textPrimary,
          ),
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
            style: const TextStyle(
              fontSize: 12,
              color: _textMuted,
              height: 1.35,
            ),
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
            decoration: const BoxDecoration(
              color: _primaryLight,
              shape: BoxShape.circle,
            ),
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
              decoration: const BoxDecoration(
                color: _primaryLight,
                shape: BoxShape.circle,
              ),
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
              'Try searching for queue, prescription, availability, profile, medicine, or login.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                color: _textMuted,
                height: 1.4,
              ),
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
    summary: 'Login, OTP, profile setup, and first-time checks',
    icon: Icons.login_rounded,
    iconColor: _primary,
    iconBg: _primaryLight,
    initiallyExpanded: true,
    topics: [
      _HelpTopic(
        title: 'Sign in as a doctor',
        body:
            'Use the doctor login flow with your registered mobile number. After OTP verification, QLess opens the doctor dashboard.',
        steps: [
          'Choose Continue as Doctor on the start screen.',
          'Enter your mobile number and request OTP.',
          'Submit the OTP. If your profile exists, you will land in the doctor app.',
        ],
        tips: [
          'If OTP login does not continue, check network connectivity and retry.',
          'Use the same mobile number used during doctor registration.',
        ],
      ),
      _HelpTopic(
        title: 'Complete your doctor profile',
        body:
            'A complete profile helps patients identify your clinic and specialty before joining the queue.',
        steps: [
          'Add name, gender, contact number, specialization, qualification, and experience.',
          'Add clinic name, clinic address, clinic contact, email, website, fee, and location.',
          'Upload doctor and clinic photos where available.',
          'Save the profile and confirm the information appears on the profile page.',
        ],
      ),
      _HelpTopic(
        title: 'Keep clinic location accurate',
        body:
            'Patients use clinic details to decide where to visit. Keep the address and map pin updated after clinic changes.',
        tips: [
          'Use a clear clinic name and full address.',
          'Update clinic contact number immediately if staff or front-desk numbers change.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Dashboard and Queue',
    summary: 'Use the home screen to monitor current patient flow',
    icon: Icons.dashboard_customize_outlined,
    iconColor: _info,
    iconBg: _infoLight,
    topics: [
      _HelpTopic(
        title: 'Understand the dashboard',
        body:
            'The doctor home screen is the operational view for active clinic work. It shows queue and appointment information tied to your doctor account.',
        tips: [
          'Refresh when you expect new bookings but do not see them yet.',
          'Use patient and appointment screens for detailed records and prescription actions.',
        ],
      ),
      _HelpTopic(
        title: 'Queue lead time',
        body:
            'Lead time controls how early patients can join the queue before their planned visit window.',
        steps: [
          'Open Profile.',
          'Go to Availability settings on the profile page.',
          'Change Queue booking lead time with the HH:MM picker.',
          'Save the change and verify the displayed value.',
        ],
        tips: [
          'Use shorter lead times for small clinics and longer lead times when registration or triage takes extra time.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Availability',
    summary: 'Configure clinic days, timings, and booking windows',
    icon: Icons.event_available_outlined,
    iconColor: _success,
    iconBg: _greenLight,
    topics: [
      _HelpTopic(
        title: 'Set consultation days and times',
        body:
            'Availability controls when patients can book appointments or join the queue for your clinic.',
        steps: [
          'Open Profile and tap Manage Availability.',
          'Select the active consultation days.',
          'Set the start and end time for each session.',
          'Save the schedule.',
        ],
        tips: [
          'Remove inactive days before holidays or planned closures.',
          'Keep timings realistic so patients are not able to book outside clinic hours.',
        ],
      ),
      _HelpTopic(
        title: 'When schedule changes do not appear',
        body:
            'Schedule data is loaded from your doctor account. If a saved change is not visible, refresh the page or reopen the doctor app.',
        tips: [
          'Confirm you are logged in with the correct doctor mobile number.',
          'Check network connectivity before saving availability changes.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Patients and Appointments',
    summary: 'Find patients, view visit context, and open prescriptions',
    icon: Icons.groups_outlined,
    iconColor: _purple,
    iconBg: _purpleLight,
    topics: [
      _HelpTopic(
        title: 'View patient list',
        body:
            'The patient list shows patients associated with your appointments and prescriptions. Use it to review patient context before writing medication.',
        steps: [
          'Open the Patients area from the doctor navigation.',
          'Search or scroll to the patient you need.',
          'Open a patient entry to view related appointment or prescription details.',
        ],
      ),
      _HelpTopic(
        title: 'Open appointment details',
        body:
            'Appointment details help you confirm patient name, clinic context, appointment status, and prescription history.',
        tips: [
          'Check patient identity before creating or updating a prescription.',
          'Use completed visits as a reference when reviewing past medication.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Prescriptions',
    summary: 'Create, save, and review patient prescriptions',
    icon: Icons.receipt_long_outlined,
    iconColor: _primary,
    iconBg: _primaryLight,
    topics: [
      _HelpTopic(
        title: 'Create a prescription',
        body:
            'Prescriptions are created from the doctor workflow for a selected patient or appointment.',
        steps: [
          'Open the patient or appointment that needs a prescription.',
          'Go to the prescription entry screen.',
          'Add medicines, dosage, timing, duration, and instructions.',
          'Review the prescription carefully before saving.',
          'Save it so the patient can access the record.',
        ],
        tips: [
          'Use clear instructions for before food, after food, and duration.',
          'Double-check similar medicine names before saving.',
        ],
      ),
      _HelpTopic(
        title: 'Prescription history',
        body:
            'Prescription history helps you review earlier treatment plans and continue follow-up care.',
        steps: [
          'Open the patient record or prescription history area.',
          'Select the prescription date or record you want to review.',
          'Use the detail screen to inspect medicine and clinic information.',
        ],
      ),
      _HelpTopic(
        title: 'Editing prescription mistakes',
        body:
            'If you notice an error after saving, create the corrected prescription as soon as possible according to your clinic process.',
        tips: [
          'Avoid reusing outdated instructions for new visits without reviewing the current complaint.',
          'Keep prescription notes concise and clinically clear.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Medicine Catalog',
    summary: 'Manage medicine entries used while prescribing',
    icon: Icons.medication_outlined,
    iconColor: _warning,
    iconBg: _amberLight,
    topics: [
      _HelpTopic(
        title: 'Add medicine',
        body:
            'The medicine screen lets you maintain medicines that can be selected during prescription entry.',
        steps: [
          'Open the Medicine tab.',
          'Tap add medicine.',
          'Enter medicine name and the required details.',
          'Save the medicine and use it while creating prescriptions.',
        ],
        tips: [
          'Use standard medicine names to avoid duplicate entries.',
          'Include form or strength in the name when it prevents confusion.',
        ],
      ),
      _HelpTopic(
        title: 'Find medicine quickly',
        body:
            'Use search in the medicine workflow when available. A clean catalog makes prescribing faster during busy clinic hours.',
        tips: [
          'Remove or stop using duplicate medicine names in daily workflow.',
          'Prefer consistent capitalization and spelling.',
        ],
      ),
    ],
  ),
  _HelpSection(
    title: 'Profile, Reviews, and Account',
    summary: 'Edit details, read reviews, privacy, and logout',
    icon: Icons.manage_accounts_outlined,
    iconColor: _error,
    iconBg: _redLight,
    topics: [
      _HelpTopic(
        title: 'Edit personal and professional details',
        body:
            'Profile keeps your public doctor and clinic information current for patients.',
        steps: [
          'Open Profile.',
          'Tap the edit icon on your profile card.',
          'Update personal, professional, clinic, photo, or location information.',
          'Save and refresh the profile page if needed.',
        ],
      ),
      _HelpTopic(
        title: 'Read patient reviews',
        body:
            'Your review count and rating are shown on the profile card. Tap the review area to inspect patient feedback.',
        tips: [
          'Use reviews to spot patient experience issues such as waiting time or communication gaps.',
          'A missing rating usually means there are no patient reviews yet.',
        ],
      ),
      _HelpTopic(
        title: 'Privacy policy and terms',
        body:
            'Privacy Policy is available from Profile support options and from this Help Center. Terms of Service is listed on the profile support card.',
      ),
      _HelpTopic(
        title: 'Logout safely',
        body:
            'Use logout when changing devices or handing the phone to another staff member.',
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
    summary: 'Common fixes for loading, saving, and account issues',
    icon: Icons.build_circle_outlined,
    iconColor: _textSecondary,
    iconBg: Color(0xFFE2E8F0),
    topics: [
      _HelpTopic(
        title: 'Profile data is missing',
        body:
            'Profile details are fetched using your logged-in doctor mobile number.',
        steps: [
          'Pull down on the profile page to refresh.',
          'Confirm the account was registered as a doctor.',
          'Log out and log in again if the wrong account is loaded.',
        ],
      ),
      _HelpTopic(
        title: 'Save button does not work',
        body:
            'Most save actions require network access and valid account data.',
        tips: [
          'Check your internet connection.',
          'Make sure required fields are filled.',
          'Retry after reopening the screen if the app was left idle.',
        ],
      ),
      _HelpTopic(
        title: 'Appointments or prescriptions are not loading',
        body:
            'Lists can appear empty when there are no records or when the request fails.',
        tips: [
          'Refresh the page first.',
          'Check whether you are logged in with the correct doctor account.',
          'Contact support if the records are still missing after retrying.',
        ],
      ),
      _HelpTopic(
        title: 'Need more help',
        body:
            'Email support@vengurlatech.com with your registered mobile number, clinic name, and a short description of the issue.',
        tips: [
          'Attach screenshots when reporting UI or data issues.',
          'Mention the screen name where the problem happened.',
        ],
      ),
    ],
  ),
];
