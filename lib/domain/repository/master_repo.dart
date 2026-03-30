
import 'dart:io';

import 'package:qless/domain/models/master_data.dart';

abstract class MasterRepo {

  Future<List<GenderModel>> fetchGenderList();
    Future<List<RelationModel>> fetchRelationList();
      Future<List<BloodGroupModel>> fetchBloodGroupList();
  

}