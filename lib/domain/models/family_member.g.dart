// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyMember _$FamilyMemberFromJson(Map<String, dynamic> json) => FamilyMember(
  familyId: (json['family_id'] as num?)?.toInt(),
  memberId: (json['member_id'] as num?)?.toInt(),
  memberName: json['name'] as String?,
  genderId: (json['Gender_id'] as num?)?.toInt(),
  genderName: json['Gender'] as String?,
  dob: json['DOB'] == null ? null : DateTime.parse(json['DOB'] as String),
  relationId: (json['relation_id'] as num?)?.toInt(),
  relationName: json['relation'] as String?,
  mobileNo: json['mobile_no'] as String?,
);

Map<String, dynamic> _$FamilyMemberToJson(FamilyMember instance) =>
    <String, dynamic>{
      'family_id': instance.familyId,
      'member_id': instance.memberId,
      'name': instance.memberName,
      'Gender_id': instance.genderId,
      'Gender': instance.genderName,
      'DOB': instance.dob?.toIso8601String(),
      'relation_id': instance.relationId,
      'relation': instance.relationName,
      'mobile_no': instance.mobileNo,
    };
