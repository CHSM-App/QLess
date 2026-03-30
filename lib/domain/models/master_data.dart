import 'package:json_annotation/json_annotation.dart';

part 'master_data.g.dart';

/// ---------------- GENDER ----------------
@JsonSerializable()
class GenderModel {
  @JsonKey(name: 'gender_id')
  final int? genderId;

  final String? gender;

  const GenderModel({
    this.genderId,
    this.gender,
  });

  factory GenderModel.fromJson(Map<String, dynamic> json) =>
      _$GenderModelFromJson(json);

  Map<String, dynamic> toJson() => _$GenderModelToJson(this);
}

/// ---------------- BLOOD GROUP ----------------
@JsonSerializable()
class BloodGroupModel {
  @JsonKey(name: 'blood_group_id')
  final int? bloodGroupId;

  @JsonKey(name: 'blood_Group_name', readValue: _readBloodGroupName)
  final String? bloodGroupName;

  const BloodGroupModel({
    this.bloodGroupId,
    this.bloodGroupName,
  });

  static Object? _readBloodGroupName(Map<dynamic, dynamic> json, String key) {
    if (json.containsKey(key)) return json[key];
    if (json.containsKey('blood_group_name')) return json['blood_group_name'];
    if (json.containsKey('bloodGroupName')) return json['bloodGroupName'];
    if (json.containsKey('blood_group')) return json['blood_group'];
    return null;
  }

  factory BloodGroupModel.fromJson(Map<String, dynamic> json) =>
      _$BloodGroupModelFromJson(json);

  Map<String, dynamic> toJson() => _$BloodGroupModelToJson(this);
}

/// ---------------- RELATION ----------------
@JsonSerializable()
class RelationModel {
  @JsonKey(name: 'relation_id')
  final int? relationId;

  final String? relation;

  const RelationModel({
    this.relationId,
    this.relation,
  });

  factory RelationModel.fromJson(Map<String, dynamic> json) =>
      _$RelationModelFromJson(json);

  Map<String, dynamic> toJson() => _$RelationModelToJson(this);
}
