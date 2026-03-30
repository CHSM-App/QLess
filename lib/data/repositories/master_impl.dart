import 'dart:io';

import 'package:qless/data/api/api_service.dart';
import 'package:qless/domain/models/master_data.dart';
import 'package:qless/domain/repository/master_repo.dart';


class MasterImpl implements MasterRepo {
  final ApiService apiService;

  MasterImpl(this.apiService);

  @override
  Future<List<GenderModel>> fetchGenderList() {
    return apiService.fetchGenderList();
  }

  @override
  Future<List<RelationModel>> fetchRelationList() {
    return apiService.fetchRelationList();
  }

  @override
  Future<List<BloodGroupModel>> fetchBloodGroupList() {
    return apiService.fetchBloodGroupList();
  }


}
