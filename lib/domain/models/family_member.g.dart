// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'family_member.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

FamilyMember _$FamilyMemberFromJson(Map<String, dynamic> json) => FamilyMember(
  memberId: (json['member_id'] as num?)?.toInt(),
  memberName: json['member_name'] as String?,
  gender: $enumDecodeNullable(_$GenderEnumMap, json['gender']),
  dateOfBirth: json['date_of_birth'] as String?,
  relation: $enumDecodeNullable(_$RelationEnumMap, json['relation']),
  mobileNumber: json['mobile_number'] as String?,
  age: (json['age'] as num?)?.toInt(),
);

Map<String, dynamic> _$FamilyMemberToJson(FamilyMember instance) =>
    <String, dynamic>{
      'member_id': instance.memberId,
      'member_name': instance.memberName,
      'gender': _$GenderEnumMap[instance.gender],
      'date_of_birth': instance.dateOfBirth,
      'relation': _$RelationEnumMap[instance.relation],
      'mobile_number': instance.mobileNumber,
      'age': instance.age,
    };

const _$GenderEnumMap = {
  Gender.male: 'male',
  Gender.female: 'female',
  Gender.other: 'other',
};

const _$RelationEnumMap = {
  Relation.self: 'self',
  Relation.spouse: 'spouse',
  Relation.child: 'child',
  Relation.parent: 'parent',
  Relation.sibling: 'sibling',
  Relation.other: 'other',
};
