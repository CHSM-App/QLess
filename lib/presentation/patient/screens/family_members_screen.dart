
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/providers/patient_view_model_provider.dart';
import 'package:qless/presentation/patient/screens/add_family_member_screen.dart';
import 'package:qless/presentation/patient/view_models/patient_login_viewmodel.dart';

class FamilyMembersScreen extends ConsumerStatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  ConsumerState<FamilyMembersScreen> createState() =>
      _FamilyMembersScreenState();
}

class _FamilyMembersScreenState
    extends ConsumerState<FamilyMembersScreen> {
  bool _didFetch = false;
  bool _isWaitingForId = false;
  bool _idMissing = false;

  // ---------------------------------------------------------------------------
  // Lifecycle
  // ---------------------------------------------------------------------------

  @override
  void initState() {
    super.initState();

    Future.microtask(_ensurePatientIdAndFetch);
  }

  Future<void> _ensurePatientIdAndFetch() async {
    if (_didFetch) return;
    final notifier = ref.read(patientLoginViewModelProvider.notifier);
    var patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
    if (patientId == 0) {
      if (!_isWaitingForId) {
        setState(() {
          _isWaitingForId = true;
          _idMissing = false;
        });
      }
      await notifier.loadFromStoragePatient();
      patientId = ref.read(patientLoginViewModelProvider).patientId ?? 0;
      if (mounted) {
        setState(() {
          _isWaitingForId = false;
        });
      }
      if (patientId == 0) {
        if (mounted) {
          setState(() {
            _idMissing = true;
          });
        }
        return;
      }
    }
    _didFetch = true;
    notifier.fetchAllFamilyMembers(patientId);
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  int _ageFrom(DateTime dob) {
    final now = DateTime.now();
    int age = now.year - dob.year;
    if (now.month < dob.month ||
        (now.month == dob.month && now.day < dob.day)) {
      age--;
    }
    return age;
  }

  bool _isSelf(FamilyMember m) =>
      m.relationName?.toLowerCase() == 'self' || m.relationId == 1;

  // ---------------------------------------------------------------------------
  // Navigation
  // ---------------------------------------------------------------------------

  Future<void> _refresh() async {
    final patientId =
        ref.read(patientLoginViewModelProvider).patientId;

    if (patientId != null && patientId != 0) {
      await ref
          .read(patientLoginViewModelProvider.notifier)
          .fetchAllFamilyMembers(patientId);
    }
  }

  void _onAddMember() async {
    final result = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddFamilyMemberScreen(),
      ),
    );

    if (result != null) {
      await _refresh();
    }
  }

  void _onEditMember(FamilyMember member) async {
    final result = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(existingMember: member),
      ),
    );

    if (result != null) {
      await _refresh();
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

    final state = ref.watch(patientLoginViewModelProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1),

            /// 🔥 API LIST
            Expanded(
              child: state.allfamilyMembers.when(
                loading: () => _buildLoading(),

                error: (err, _) => Center(
                  child: Text('Error: $err'),
                ),

                data: (members) {
                  final patientId = state.patientId ?? 0;
                  final selfName = state.name;
                  final selfMobile = state.mobileNo;

                  if (_isWaitingForId) {
                    return _buildLoading();
                  }
                  if (_idMissing && patientId == 0) {
                    return const Center(
                      child: Text('Please login again to load members'),
                    );
                  }

                  final selfMember = (patientId != 0 &&
                          (selfName?.trim().isNotEmpty ?? false))
                      ? FamilyMember(
                          familyId: patientId,
                          memberId: patientId,
                          memberName: selfName,
                          relationId: 1,
                          relationName: 'Self',
                          mobileNo: selfMobile,
                        )
                      : null;

                  final hasSelf = members.any((m) =>
                      (m.relationName?.toLowerCase() == 'self') ||
                      (m.relationId == 1));

                  final displayMembers = [
                    if (selfMember != null && !hasSelf) selfMember,
                    ...members,
                  ];

                  if (displayMembers.isEmpty) {
                    return const Center(
                      child: Text('No family members found'),
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView.separated(
                      itemCount: displayMembers.length,
                      separatorBuilder: (_, __) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final member = displayMembers[index];

                        return _FamilyMemberTile(
                          member: member,
                          age: member.dob != null
                              ? _ageFrom(member.dob!)
                              : null,
                          isSelf: _isSelf(member),
                          onEdit: () => _onEditMember(member),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            _buildAddButton(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Family Members',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          GestureDetector(
            onTap: () => Navigator.pop(context),
            child: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: _onAddMember,
        icon: const Icon(Icons.add),
        label: const Text('Add New Member'),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 50),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 8),
          Text('Loading family members...'),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _FamilyMemberTile extends StatelessWidget {
  final FamilyMember member;
  final int? age;
  final bool isSelf;
  final VoidCallback onEdit;

  const _FamilyMemberTile({
    required this.member,
    required this.age,
    required this.isSelf,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final relation = member.relationName ?? '';
    final gender = member.genderName ?? '';
    final ageText = age != null ? '$age yrs' : '';

    return ListTile(
      leading: CircleAvatar(
        child: Text(member.avatarLetter),
      ),
      title: Text(member.memberName ?? ''),
      subtitle: Text('$relation | $gender | $ageText'),
      trailing: TextButton(
        onPressed: onEdit,
        child: const Text('Edit'),
      ),
    );
  }
}
