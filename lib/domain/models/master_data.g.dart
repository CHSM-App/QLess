// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'master_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

MasterData _$MasterDataFromJson(Map<String, dynamic> json) => MasterData(
  genderId: (json['gender_id'] as num?)?.toInt(),
  gender: json['gender'] as String?,
  bloodGroupId: (json['blood_group_id'] as num?)?.toInt(),
  bloodGroupName: (json['blood_Group_name'] ??
          json['blood_group_name'] ??
          json['bloodGroupName'])
      as String?,
  relationId: (json['relation_id'] as num?)?.toInt(),
  relation: json['relation'] as String?,
);

Map<String, dynamic> _$MasterDataToJson(MasterData instance) =>
    <String, dynamic>{
      'gender_id': instance.genderId,
      'gender': instance.gender,
      'blood_group_id': instance.bloodGroupId,
      'blood_Group_name': instance.bloodGroupName,
      'relation_id': instance.relationId,
      'relation': instance.relation,
    };
