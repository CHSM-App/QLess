// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

GenderModel _$GenderModelFromJson(Map<String, dynamic> json) => GenderModel(
  genderId: (json['gender_id'] as num?)?.toInt(),
  gender: json['gender'] as String?,
);

Map<String, dynamic> _$GenderModelToJson(GenderModel instance) =>
    <String, dynamic>{
      'gender_id': instance.genderId,
      'gender': instance.gender,
    };

BloodGroupModel _$BloodGroupModelFromJson(Map<String, dynamic> json) =>
    BloodGroupModel(
      bloodGroupId: (json['blood_group_id'] as num?)?.toInt(),
      bloodGroupName: json['blood_Group_name'] as String?,
    );

Map<String, dynamic> _$BloodGroupModelToJson(BloodGroupModel instance) =>
    <String, dynamic>{
      'blood_group_id': instance.bloodGroupId,
      'blood_Group_name': instance.bloodGroupName,
    };

RelationModel _$RelationModelFromJson(Map<String, dynamic> json) =>
    RelationModel(
      relationId: (json['relation_id'] as num?)?.toInt(),
      relation: json['relation'] as String?,
    );

Map<String, dynamic> _$RelationModelToJson(RelationModel instance) =>
    <String, dynamic>{
      'relation_id': instance.relationId,
      'relation': instance.relation,
    };
