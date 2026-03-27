import 'package:flutter/material.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/presentation/patient/screens/add_family_member_screen.dart';


class FamilyMembersScreen extends StatefulWidget {
  const FamilyMembersScreen({super.key});

  @override
  State<FamilyMembersScreen> createState() => _FamilyMembersScreenState();
}

class _FamilyMembersScreenState extends State<FamilyMembersScreen> {
  // Sample pre-loaded data matching the screenshot
  final List<FamilyMember> _members = [
    FamilyMember(
      memberId: 1,
      memberName: 'Jivan Kudalkar',
      gender: Gender.male,
      relation: Relation.self,
      age: 41,
      dateOfBirth: '1984-03-27',
    ),
    FamilyMember(
      memberId: 2,
      memberName: 'Sukhada Kudalkar',
      gender: Gender.female,
      relation: Relation.spouse,
      age: 37,
      dateOfBirth: '1988-06-15',
    ),
    FamilyMember(
      memberId: 3,
      memberName: 'Vaidehi Kudalkar',
      gender: Gender.female,
      relation: Relation.child,
      age: 8,
      dateOfBirth: '2017-01-10',
    ),
    FamilyMember(
      memberId: 4,
      memberName: 'Shivay Kudalkar',
      gender: Gender.male,
      relation: Relation.child,
      age: 5,
      dateOfBirth: '2020-05-20',
    ),
  ];

  void _onEditMember(FamilyMember member) async {
    final updated = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => AddFamilyMemberScreen(existingMember: member),
      ),
    );
    if (updated != null) {
      setState(() {
        final index =
            _members.indexWhere((m) => m.memberId == updated.memberId);
        if (index != -1) _members[index] = updated;
      });
    }
  }

  void _onAddMember() async {
    final newMember = await Navigator.push<FamilyMember>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddFamilyMemberScreen(),
      ),
    );
    if (newMember != null) {
      setState(() {
        _members.add(newMember);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const Divider(height: 1, color: Color(0xFFE0E0E0)),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _members.length,
                separatorBuilder: (_, __) => const Divider(
                  height: 1,
                  indent: 16,
                  endIndent: 16,
                  color: Color(0xFFE0E0E0),
                ),
                itemBuilder: (context, index) {
                  final member = _members[index];
                  return _FamilyMemberTile(
                    member: member,
                    isSelf: member.relation == Relation.self,
                    onEdit: () => _onEditMember(member),
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

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Family Members',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A2E),
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: const Icon(Icons.close, color: Color(0xFF1A1A2E), size: 24),
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
        icon: const Icon(Icons.add_circle_outline, color: Color(0xFF3D5AF1)),
        label: const Text(
          'Add New Member',
          style: TextStyle(
            color: Color(0xFF3D5AF1),
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(double.infinity, 54),
          side: const BorderSide(color: Color(0xFF3D5AF1), width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

class _FamilyMemberTile extends StatelessWidget {
  final FamilyMember member;
  final bool isSelf;
  final VoidCallback onEdit;

  const _FamilyMemberTile({
    required this.member,
    required this.isSelf,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          _Avatar(letter: member.avatarLetter),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.memberName ?? '',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${member.relationLabel}  |  ${member.genderLabel}  |  ${member.age} yrs',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF8A8A9A),
                  ),
                ),
              ],
            ),
          ),
          if (!isSelf)
            GestureDetector(
              onTap: onEdit,
              child: const Text(
                'Edit',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF3D5AF1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String letter;

  const _Avatar({required this.letter});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: const BoxDecoration(
        color: Color(0xFFE8EAF6),
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Color(0xFF3D5AF1),
        ),
      ),
    );
  }
}
