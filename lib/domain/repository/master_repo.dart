
import 'dart:io';

import 'package:qless/domain/models/master_data.dart';

abstract class MasterRepo {

  Future<List<MasterData>> fetchGenderList();
    Future<List<MasterData>> fetchRelationList();
      Future<List<MasterData>> fetchBloodGroupList();
  

}