import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/add_family_member_screen.dart';
import 'package:qless/presentation/patient/view_models/family_viewmodel.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

// ── Colour palette ────────────────────────────────────────────────
const kPrimary   = Color(0xFF1A73E8);
const kPrimaryBg = Color(0xFFE8F0FE);
const kBg        = Color(0xFFF4F6FB);
const kCardBg    = Colors.white;
const kTextDark  = Color(0xFF1F2937);
const kTextMid   = Color(0xFF6B7280);
const kBorder    = Color(0xFFE5E7EB);
const kRed       = Color(0xFFEA4335);
const kGreen     = Color(0xFF34A853);
const kOrange    = Color(0xFFF59E0B);
const kPurple    = Color(0xFF8B5CF6);
const kCyan      = Color(0xFF06B6D4);

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
    _searchController.addListener(() {
      setState(() => _searchQuery = _searchController.text.toLowerCase());
    });
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
      await ref.read(patientLoginViewModelProvider.notifier).checkPhonePatient(mobile);
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
    // Only fallback to memberId match when relation isn't set
    final relationEmpty = relation == null || relation.isEmpty;
    return relationEmpty && patientId != 0 && m.memberId == patientId;
  }

  Color _avatarBg(int index) {
    const colors = [kPrimaryBg, Color(0xFFCFFAFE), Color(0xFFDCFCE7),
                    Color(0xFFEDE9FE), Color(0xFFFEF3C7)];
    return colors[index % colors.length];
  }

  Color _avatarFg(int index) {
    const colors = [kPrimary, kCyan, kGreen, kPurple, kOrange];
    return colors[index % colors.length];
  }

  // ---------------------------------------------------------------------------
  // Navigation
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
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Remove Member',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600,
                color: kTextDark)),
        content: Text(
          'Remove ${member.memberName ?? 'this member'} from your family list?',
          style: const TextStyle(fontSize: 14, color: kTextMid),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: kTextMid)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: kRed,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final memberId = member.memberId;
      if (memberId == null || memberId == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to delete: missing member id'),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final message = await ref
          .read(familyViewModelProvider.notifier)
          .deleteFamilyMember(memberId);

      final familyState = ref.read(familyViewModelProvider);
      if (familyState.isSuccess) {
        await _refresh();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message ?? 'Member deleted successfully'),
            backgroundColor: kGreen,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message ?? familyState.error ?? 'Failed to delete member',
            ),
            backgroundColor: kRed,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
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
    final loginState = ref.watch(patientLoginViewModelProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            _buildSearchBar(),
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
        iconColor: kOrange,
      );
    }

    final patientId = state.patientId ?? 0;
    final selfDetails = state.patientPhoneCheck.maybeWhen(
      data: (list) => list.isNotEmpty ? list.first : null,
      orElse: () => null,
    );
    final rawSelfName = selfDetails?.name ?? state.name;
    final selfName = (rawSelfName != null && rawSelfName.trim().isNotEmpty)
        ? rawSelfName.trim()
        : 'You';
    final selfMobile = selfDetails?.mobileNo ?? state.mobileNo;

    final hasSelf = members.any((m) => _isSelf(m, patientId));
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

    // Filter by search
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
            ? 'No family members found'
            : 'No results for "$_searchQuery"',
        iconColor: kCyan,
      );
    }

    return RefreshIndicator(
      color: kPrimary,
      onRefresh: _refresh,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final member = filtered[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FamilyMemberCard(
              member:    member,
              age:       member.dob != null ? _ageFrom(member.dob!) : null,
              isSelf:    _isSelf(member, patientId),
              avatarBg:  _avatarBg(index),
              avatarFg:  _avatarFg(index),
              onEdit:    () => _onEditMember(member),
              onDelete:  () => _onDeleteMember(member),
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
    final name = ref.read(patientLoginViewModelProvider).name ?? 'Patient';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').take(2).map((w) => w[0].toUpperCase()).join()
        : '?';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: kPrimaryBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.arrow_back_ios_new_rounded,
                  size: 16, color: kPrimary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Family Members',
                    style: TextStyle(fontSize: 17,
                        fontWeight: FontWeight.w600, color: kTextDark)),
                const SizedBox(height: 1),
                Text('Manage your family health profiles',
                    style: const TextStyle(fontSize: 11.5, color: kTextMid)),
              ],
            ),
          ),
          CircleAvatar(
            radius: 18,
            backgroundColor: kPrimary,
            child: Text(initials,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500,
                    color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: kBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search_rounded, size: 18, color: kTextMid),
            ),
            Expanded(
              child: TextField(
                controller: _searchController,
                style: const TextStyle(fontSize: 14, color: kTextDark),
                decoration: const InputDecoration(
                  hintText: 'Search members...',
                  hintStyle: TextStyle(fontSize: 14, color: kTextMid),
                  border: InputBorder.none,
                  isDense: true,
                ),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              GestureDetector(
                onTap: () => _searchController.clear(),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.close_rounded, size: 16, color: kTextMid),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddButton() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
      child: SizedBox(
        width: double.infinity,
        height: 52,
        child: ElevatedButton.icon(
          onPressed: _onAddMember,
          style: ElevatedButton.styleFrom(
            backgroundColor: kPrimary,
            foregroundColor: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
          ),
          icon: const Icon(Icons.add_circle_outline_rounded, size: 20),
          label: const Text('Add New Member',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: kPrimary, strokeWidth: 2.5),
          SizedBox(height: 12),
          Text('Loading members...',
              style: TextStyle(fontSize: 14, color: kTextMid)),
        ],
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 40, color: kRed),
            const SizedBox(height: 10),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: kTextMid)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refresh,
              style: ElevatedButton.styleFrom(
                backgroundColor: kPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String message,
    required Color iconColor,
  }) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: iconColor),
          ),
          const SizedBox(height: 12),
          Text(message,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: kTextMid,
                  height: 1.5)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Member Card
// ---------------------------------------------------------------------------

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
    final relation  = member.relationName ?? '';
    final gender    = member.genderName   ?? '';
    final ageText   = age != null ? '$age yrs' : '';
    final letter    = member.avatarLetter;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            // ── Avatar ──
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: avatarBg,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  alignment: Alignment.center,
                  child: Text(letter,
                      style: TextStyle(fontSize: 16,
                          fontWeight: FontWeight.w600, color: avatarFg)),
                ),
                if (isSelf)
                  Positioned(
                    bottom: -3,
                    right: -3,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: kPrimary,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.check_rounded,
                          size: 9, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),

            // ── Info ──
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(member.memberName ?? '',
                      style: const TextStyle(fontSize: 15,
                          fontWeight: FontWeight.w500, color: kTextDark),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 5,
                    runSpacing: 4,
                    children: [

                  
                     if (relation.isNotEmpty)
                        _Badge(relation, bg: kPrimaryBg, fg: kPrimary),
                      if (gender.isNotEmpty)
                        _Badge(gender, bg: kBg, fg: kTextMid),
                      if (ageText.isNotEmpty)
                        _Badge(ageText,
                            bg: const Color(0xFFCFFAFE),
                            fg: const Color(0xFF0891B2)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),

            // ── Actions ──
            if (!isSelf)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _IconBtn(
                    icon:    Icons.edit_outlined,
                    bg:      kPrimaryBg,
                    fg:      kPrimary,
                    onTap:   onEdit,
                    tooltip: 'Edit',
                  ),
                  const SizedBox(width: 6),
                  _IconBtn(
                    icon:    Icons.delete_outline_rounded,
                    bg:      const Color(0xFFFEE2E2),
                    fg:      kRed,
                    onTap:   onDelete,
                    tooltip: 'Remove',
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tiny reusable widgets
// ---------------------------------------------------------------------------

class _Badge extends StatelessWidget {
  final String label;
  final Color  bg;
  final Color  fg;
  const _Badge(this.label, {required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11,
              fontWeight: FontWeight.w500, color: fg)),
    );
  }
}

class _IconBtn extends StatelessWidget {
  final IconData     icon;
  final Color        bg;
  final Color        fg;
  final VoidCallback onTap;
  final String       tooltip;
  const _IconBtn({required this.icon, required this.bg, required this.fg,
      required this.onTap, required this.tooltip});

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
          child: Icon(icon, size: 16, color: fg),
        ),
      ),
    );
  }
}
