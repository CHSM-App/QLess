import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';

abstract class FamilyRepository {

  Future<dynamic> addFamilyMember(FamilyMember member);

    Future<List<FamilyMember>> fetchFamilyMembers(int familyId);

  Future<FamilyMember> deleteFamilyMember(int memberId);
}
