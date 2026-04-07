import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/repository/family_repo.dart';

class FamilyUsecase {
  final FamilyRepository familyRepository;

  FamilyUsecase(this.familyRepository);


    Future<dynamic> addFamilyMember(FamilyMember member) {
    return familyRepository.addFamilyMember(member);
  }

    Future<List<FamilyMember>> fetchFamilyMembers(int familyId) {
    return familyRepository.fetchFamilyMembers(familyId);
  }

  Future<FamilyMember> deleteFamilyMember(int memberId) {
    return familyRepository.deleteFamilyMember(memberId);
  }
}
