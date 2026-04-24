import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/add_family_member_screen.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';
import 'package:qless/presentation/shared/widgets/app_expandable_header_search.dart';

// ── Modern Teal Minimal Colour Palette ────────────────────────────────────────
const kPrimary       = Color(0xFF26C6B0);
const kPrimaryDark   = Color(0xFF2BB5A0);
const kPrimaryLight  = Color(0xFFD9F5F1);
const kBgLight       = Colors.white;

const kTextPrimary   = Color(0xFF2D3748);
const kTextSecondary = Color(0xFF718096);
const kTextMuted     = Color(0xFFA0AEC0);

const kBorder        = Color(0xFFEDF2F7);
const kDivider       = Color(0xFFE5E7EB);
const kCardBg        = Colors.white;
const kBg            = Colors.white;

const kSuccess       = Color(0xFF68D391);
const kWarning       = Color(0xFFF6AD55);
const kError         = Color(0xFFFC8181);
const kInfo          = Color(0xFF3B82F6);
const kPurple        = Color(0xFF9F7AEA);
const kIndigo        = Color(0xFF7F9CF5);

const kBlueLight     = Color(0xFFDBEAFE);
const kGreenLight    = Color(0xFFDCFCE7);
const kAmberLight    = Color(0xFFFEF3C7);
const kPurpleLight   = Color(0xFFEDE9FE);
const kRedLight      = Color(0xFFFEE2E2);

// ── Shadow helper ─────────────────────────────────────────────────────────────
BoxDecoration _cardDecoration({
  Color color = kCardBg,
  double radius = 10,
  bool elevated = true,
}) =>
    BoxDecoration(
      color: color,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(color: kBorder),
      boxShadow: elevated
          ? [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
// =============================================================================
// Screen
// =============================================================================

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() =>
      _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends ConsumerState<FamilyMembersScreen> {
  bool _didFetch       = false;
  bool _isWaitingForId = false;
  bool _idMissing      = false;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();
    Future.microtask(_ensurePatientIdAndFetch);
    Future.microtask(_ensureSelfProfile);
    _searchController.addListener(
      () => setState(() => _searchQuery = _searchController.text.toLowerCase()),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_didFetch) return;
    final loginNotifier  = ref.read(patientLoginViewModelProvider.notifier);
    final familyNotifier = ref.read(familyViewModelProvider.notifier);
    var   patientId      = ref.read(patientLoginViewModelProvider).patientId ?? 0;

    if (patientId == 0) {
      if (!_isWaitingForId) {
        setState(() { _isWaitingForId = true; _idMissing = false; });
      }
      await loginNotifier.loadFromStoragePatient();
      patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (mounted) setState(() => _isWaitingForId = false);
      if (patientId == 0) {
        if (mounted) setState(() => _idMissing = true);
        return;
      }
    }
    _didFetch = true;
    familyNotifier.fetchAllFamilyMembers(patientId);
  }

  Future<void> _ensureSelfProfile() async {
    final state = ref.read(patientLoginViewModelProvider);
    final hasSelfDetails = state.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty,
      orElse: () => false,
    );
    if (hasSelfDetails) return;
    final mobile = state.mobileNo;
    if (mobile != null && mobile.trim().isNotEmpty) {
      await ref
          .read(patientLoginViewModelProvider.notifier)
          .checkPhonePatient(mobile);
    }
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) age--;
    return age;
  }

  bool _isSelf(FamilyMember m, int patientId) {
    final relation = m.relationName?.trim().toLowerCase();
    if (relation == 'self') return true;
    final relationEmpty = relation == null || relation.isEmpty;
    return relationEmpty && patientId != 0 && m.memberId == patientId;
  }

  // Teal-centric avatar palette
  Color _avatarBg(int index) {
    const colors = [
      kPrimaryLight,
      kBlueLight,
      kGreenLight,
      kPurpleLight,
      kAmberLight,
    ];
    return colors[index % colors.length];
  }

  Color _avatarFg(int index) {
    const colors = [kPrimary, kInfo, kSuccess, kPurple, kWarning];
    return colors[index % colors.length];
  }

  // ---------------------------------------------------------------------------
  // Navigation / actions
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final patientId = ref.read(patientLoginViewModelProvider).patientId;
    if (patientId != null && patientId != 0) {
      await ref
          .read(familyViewModelProvider.notifier)
          .fetchAllFamilyMembers(patientId);
    }
  }

  void _onAddMember() async {
    final result = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(builder: (_) => const AddFamilyMemberScreen()),
    );
    if (result != null) await _refresh();
  }

  void _onEditMember(FamilyMember member) async {
    final result = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(existingMember: member),
      ),
    );
    if (result != null) await _refresh();
  }

  Future<void> _onDeleteMember(FamilyMember member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon badge
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: kRedLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.person_remove_outlined,
                    size: 22, color: kError),
              ),
              const SizedBox(height: 14),
              const Text(
                'Remove Member',
                style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: kTextPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                'Remove ${member.memberName ?? 'this member'} from your family list?',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 13, color: kTextSecondary, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(ctx, false),
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
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kError,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      child: const Text('Remove',
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

    if (confirmed == true) {
      final memberId = member.memberId;
      if (memberId == null || memberId == 0) {
        if (!mounted) return;
        _showSnack('Unable to delete: missing member id', isError: true);
        return;
      }

      final message = await ref
          .read(familyViewModelProvider.notifier)
          .deleteFamilyMember(memberId);

      final familyState = ref.read(familyViewModelProvider);
      if (familyState.isSuccess) {
        await _refresh();
        if (!mounted) return;
        _showSnack(message ?? 'Member deleted successfully');
      } else {
        if (!mounted) return;
        _showSnack(
          message ?? familyState.error ?? 'Failed to delete member',
          isError: true,
        );
      }
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Expanded(
                child: Text(msg,
                    style: const TextStyle(fontSize: 13, color: Colors.white))),
          ],
        ),
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
    ref.listen<PatientLoginState>(patientLoginViewModelProvider, (prev, next) {
      final prevId = prev?.patientId ?? 0;
      final nextId = next.patientId ?? 0;
      if (prevId == 0 && nextId != 0 && !_didFetch) {
        _ensurePatientIdAndFetch();
      }
    });

    final familyState = ref.watch(familyViewModelProvider);
    final loginState  = ref.watch(patientLoginViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: familyState.allfamilyMembers.when(
                loading: _buildLoading,
                error:   (err, _) => _buildError(err.toString()),
                data:    (members) => _buildList(loginState, members),
              ),
            ),
            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // List builder
  // ---------------------------------------------------------------------------

  Widget _buildList(PatientLoginState state, List<FamilyMember> members) {
    if (_isWaitingForId) return _buildLoading();
    if (_idMissing && (state.patientId ?? 0) == 0) {
      return _buildEmptyState(
        icon: Icons.lock_outline_rounded,
        message: 'Please login again\nto load members',
        iconColor: kWarning,
        bgColor: kAmberLight,
      );
    }

    final patientId = state.patientId ?? 0;
    final selfDetails = state.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    final rawSelfName  = selfDetails?.name ?? state.name;
    final selfName     = (rawSelfName != null && rawSelfName.trim().isNotEmpty)
        ? rawSelfName.trim()
        : 'Self';
    final selfMobile   = selfDetails?.mobileNo ?? state.mobileNo;

    final hasSelf    = members.any((m) => _isSelf(m, patientId));
    final selfMember = (!hasSelf && patientId != 0)
        ? FamilyMember(
            familyId:     patientId,
            memberId:     patientId,
            memberName:   selfName,
            relationName: 'Self',
            mobileNo:     selfMobile,
            genderName:   selfDetails?.gender,
            dob:          selfDetails?.DOB,
          )
        : null;

    final displayMembers = [
      if (selfMember != null) selfMember,
      ...members,
    ];

    final filtered = _searchQuery.isEmpty
        ? displayMembers
        : displayMembers
            .where((m) =>
                (m.memberName?.toLowerCase().contains(_searchQuery) ?? false) ||
                (m.relationName?.toLowerCase().contains(_searchQuery) ?? false))
            .toList();

    if (filtered.isEmpty) {
      return _buildEmptyState(
        icon: Icons.people_outline_rounded,
        message: _searchQuery.isEmpty
            ? 'No family members yet.\nTap + to add one.'
            : 'No results for "$_searchQuery"',
        iconColor: kPrimary,
        bgColor: kPrimaryLight,
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      strokeWidth: 2,
      onRefresh: _refresh,
      child: ListView.builder(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final member = filtered[index];
          return Padding(
        padding: const EdgeInsets.only(bottom: 7),
            child: _FamilyMemberCard(
              member:   member,
              age:      member.dob != null ? _ageFrom(member.dob!) : null,
              isSelf:   _isSelf(member, patientId),
              avatarBg: _avatarBg(index),
              avatarFg: _avatarFg(index),
              onEdit:   () => _onEditMember(member),
              onDelete: () => _onDeleteMember(member),
            ),
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI sub-widgets
  // ---------------------------------------------------------------------------
Widget _buildHeader() {
  return Container(
    color: kBg,
    padding: EdgeInsets.fromLTRB(14, MediaQuery.of(context).padding.top + 8, 14, 8),
    child: Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(
              color: kPrimaryLight,
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 13, color: kPrimary),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: AppExpandableHeaderSearch(
            controller: _searchController,
            leadingIcon: Icons.people_alt_rounded,
            title: 'Family Members',
            subtitle: 'Manage your health profiles',
            hintText: 'Search members...',
            height: 40,
            accentColor: kPrimary,
            leadingBackgroundColor: kPrimaryLight,
            titleColor: kTextPrimary,
            subtitleColor: kTextMuted,
            fieldColor: const Color(0xFFF7F8FA),

            borderColor: kBorder,
            iconColor: kTextMuted,
            textColor: kTextPrimary,
          ),
        ),
        // Container(
        //   width: 32, height: 32,
        //   decoration: BoxDecoration(
        //     gradient: const LinearGradient(
        //       colors: [kPrimary, kPrimaryDark],
        //       begin: Alignment.topLeft,
        //       end: Alignment.bottomRight,
        //     ),
        //     borderRadius: BorderRadius.circular(9),
        //   ),
        //   alignment: Alignment.center,
        //   child: Text(initials,
        //       style: const TextStyle(
        //           fontSize: 12,
        //           fontWeight: FontWeight.w700,
        //           color: Colors.white)),
        // ),
      ],
    ),
  );
}
Widget _buildAddButton() {
  return Container(
    color: kBg,
    padding: const EdgeInsets.fromLTRB(14, 6, 14, 12),
    child: SizedBox(
      width: double.infinity,
      height: 42,
      child: ElevatedButton(
        onPressed: _onAddMember,
        style: ElevatedButton.styleFrom(
          backgroundColor: kPrimary,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_rounded, size: 17),
            SizedBox(width: 5),
            Text('Add New Member',
                style: TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    ),
  );
}
Widget _buildLoading() {
  return _FamilySkeletonList();
}
Widget _buildError(String message) {
  return RefreshIndicator(
    color: kPrimary,
    strokeWidth: 2,
    onRefresh: _refresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 56, height: 56,
                    decoration: const BoxDecoration(
                        color: kRedLight, shape: BoxShape.circle),
                    child: const Icon(Icons.wifi_off_rounded,
                        size: 26, color: kError),
                  ),
                  const SizedBox(height: 12),
                  const Text('Failed to load',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: kTextPrimary)),
                  const SizedBox(height: 4),
                  Text(message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          fontSize: 12, color: kTextSecondary, height: 1.5)),
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 38,
                    child: ElevatedButton(
                      onPressed: _refresh,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: kPrimary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                      ),
                      child: const Text('Retry',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );
}

Widget _buildEmptyState({
  required IconData icon,
  required String message,
  required Color iconColor,
  required Color bgColor,
}) {
  return RefreshIndicator(
    color: kPrimary,
    strokeWidth: 2,
    onRefresh: _refresh,
    child: CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverFillRemaining(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(
                      color: bgColor, shape: BoxShape.circle),
                  child: Icon(icon, size: 28, color: iconColor),
                ),
                const SizedBox(height: 12),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                      fontSize: 13, color: kTextSecondary, height: 1.6),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
}
// =============================================================================
// Member Card
// =============================================================================
class _FamilyMemberCard extends StatelessWidget {
  final FamilyMember  member;
  final int?          age;
  final bool          isSelf;
  final Color         avatarBg;
  final Color         avatarFg;
  final VoidCallback  onEdit;
  final VoidCallback  onDelete;

  const _FamilyMemberCard({
    required this.member,
    required this.age,
    required this.isSelf,
    required this.avatarBg,
    required this.avatarFg,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final relation = member.relationName ?? '';
    final gender   = member.genderName   ?? '';
    final ageText  = age != null ? '$age yrs' : '';
    final letter   = member.avatarLetter;

    return Container(
      decoration: _cardDecoration(),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        child: Row(
          children: [
            // ── Avatar ────────────────────────────────────────
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 38, height: 38,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: avatarFg)),
                ),
                if (isSelf)
                  Positioned(
                    bottom: -2, right: -2,
                    child: Container(
                      width: 13, height: 13,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 1.5),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 7, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),

            // ── Info ──────────────────────────────────────────
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        member.memberName ?? '',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: kTextPrimary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isSelf)
                      _Badge('Self', bg: kPrimaryLight, fg: kPrimary),
                  ]),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 4,
                    runSpacing: 3,
                    children: [
                      if (relation.isNotEmpty &&
                          relation.toLowerCase() != 'self')
                        _Badge(relation, bg: kPrimaryLight, fg: kPrimary),
                      if (gender.isNotEmpty)
                        _Badge(gender,
                            bg: const Color(0xFFF0F4FF), fg: kIndigo),
                      if (ageText.isNotEmpty)
                        _Badge(ageText,
                            bg: kGreenLight,
                            fg: const Color(0xFF38A169)),
                    ],
                  ),
                ],
              ),
            ),

            // ── Actions ───────────────────────────────────────
            if (!isSelf) ...[
              const SizedBox(width: 6),
              Row(children: [
                _IconBtn(
                  icon: Icons.edit_rounded,
                  bg: kPrimaryLight, fg: kPrimary,
                  onTap: onEdit, tooltip: 'Edit',
                ),
                const SizedBox(width: 5),
                _IconBtn(
                  icon: Icons.delete_outline_rounded,
                  bg: kRedLight, fg: kError,
                  onTap: onDelete, tooltip: 'Remove',
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }
}
// =============================================================================
// Tiny reusable widgets
// =============================================================================

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;

  const _Badge(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        bg;
  final Color        fg;
  final VoidCallback onTap;
  final String       tooltip;

  const _IconBtn({
    required this.icon,
    required this.bg,
    required this.fg,
    required this.onTap,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 15, color: fg),
        ),
      ),
    );
  }
}


// =============================================================================
//  SKELETON SHIMMER
// =============================================================================
class _FamilySkeletonList extends StatefulWidget {
  const _FamilySkeletonList();
  @override
  State<_FamilySkeletonList> createState() => _FamilySkeletonListState();
}

class _FamilySkeletonListState extends State<_FamilySkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1300))
      ..repeat();
    _anim = Tween<double>(begin: -2.0, end: 2.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _anim,
        builder: (_, __) => ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          itemCount: 5,
          itemBuilder: (_, __) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FamilySkeletonCard(phase: _anim.value),
          ),
        ),
      );
}

class _FamilySkeletonCard extends StatelessWidget {
  final double phase;
  const _FamilySkeletonCard({required this.phase});

  Widget _bar({double? width, required double height, double radius = 6}) =>
      Container(
        width: width,
        height: height,
        margin: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          gradient: LinearGradient(
            begin: Alignment(phase - 1, 0),
            end: Alignment(phase + 1, 0),
            colors: const [
              Color(0xFFEDF2F7),
              Color(0xFFE2E8F0),
              Color(0xFFCBD5E0),
              Color(0xFFE2E8F0),
              Color(0xFFEDF2F7),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Container(
        decoration: _cardDecoration(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
              // Avatar skeleton
              Container(
                width: 46, height: 46,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    begin: Alignment(phase - 1, 0),
                    end: Alignment(phase + 1, 0),
                    colors: const [
                      Color(0xFFEDF2F7),
                      Color(0xFFCBD5E0),
                      Color(0xFFEDF2F7),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Info skeleton
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name row
                    Row(children: [
                      _bar(width: 120, height: 14),
                      const Spacer(),
                      _bar(width: 34, height: 20, radius: 8), // "You" badge
                    ]),
                    // Badges row
                    Row(children: [
                      _bar(width: 55, height: 20, radius: 8),
                      const SizedBox(width: 5),
                      _bar(width: 44, height: 20, radius: 8),
                      const SizedBox(width: 5),
                      _bar(width: 48, height: 20, radius: 8),
                    ]),
                  ],
                ),
              ),

              // Action buttons skeleton
              const SizedBox(width: 8),
              Column(children: [
                _bar(width: 32, height: 32, radius: 10),
                const SizedBox(height: 6),
                _bar(width: 32, height: 32, radius: 10),
              ]),
            ],
          ),
        ),
      );
}
