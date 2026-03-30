import 'dart:io';

import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/repository/master_repo.dart';
class MasterUsecase {
  final MasterRepo masterRepo;

  MasterUsecase(this.masterRepo);
  

  Future<List<MasterData>> fetchGenderList() {
    return masterRepo.fetchGenderList();
  }

  Future<List<MasterData>> fetchRelationList() {
    return masterRepo.fetchRelationList();
  }

  Future<List<MasterData>> fetchBloodGroupList() {
    return masterRepo.fetchBloodGroupList();
  }

}
