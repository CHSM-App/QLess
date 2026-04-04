import 'package:qless/core/storage/token_storage.dart';
import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/family_member.dart';
import 'package:qless/domain/models/patients.dart';
import 'package:qless/domain/repository/family_repo.dart';
import 'package:qless/domain/repository/patient_login_repo.dart';

class FamilyImpl implements FamilyRepository {
  final ApiService apiService;

  FamilyImpl(this.apiService);



    @override
  Future<dynamic> addFamilyMember(FamilyMember member) {
    return apiService.addFamilyMember(member);
  }
  
  @override
   Future<List<FamilyMember>> fetchFamilyMembers(int familyId) {
    return apiService.fetchFamilyMembers(familyId);
  }

  @override
  Future<FamilyMember> deleteFamilyMember(int memberId) {
    return apiService.deleteFamilyMember(memberId);
  }
}
