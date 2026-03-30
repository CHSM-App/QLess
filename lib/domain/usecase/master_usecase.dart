import 'dart:io';

import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/repository/master_repo.dart';
class MasterUsecase {
  final MasterRepo masterRepo;

  MasterUsecase(this.masterRepo);
  

  Future<List<GenderModel>> fetchGenderList() {
    return masterRepo.fetchGenderList();
  }

  Future<List<RelationModel>> fetchRelationList() {
    return masterRepo.fetchRelationList();
  }

  Future<List<BloodGroupModel>> fetchBloodGroupList() {
    return masterRepo.fetchBloodGroupList();
  }

}
