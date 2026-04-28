// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'patients.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Patients _$PatientsFromJson(Map<String, dynamic> json) => Patients(
  patientId: (json['patient_id'] as num?)?.toInt(),
  name: json['name'] as String?,
  email: json['email'] as String?,
  mobileNo: json['mobile_no'] as String?,
  DOB: json['DOB'] == null ? null : DateTime.parse(json['DOB'] as String),
  gender: json['gender'] as String?,
  address: json['Address'] as String?,
  bloodGroup: json['blood_group_name'] as String?,
  weight: json['weight'] as String?,
  roleId: (json['role_id'] as num?)?.toInt(),
  Token: json['token'] as String?,
  genderId: (json['gender_id'] as num?)?.toInt(),
  bloodGroupId: (json['blood_group_id'] as num?)?.toInt(),
  imgUrl: json['img_url'] as String?,
);

Map<String, dynamic> _$PatientsToJson(Patients instance) => <String, dynamic>{
  'patient_id': instance.patientId,
  'name': instance.name,
  'mobile_no': instance.mobileNo,
  'Address': instance.address,
  'email': instance.email,
  'gender': instance.gender,
  'DOB': instance.DOB?.toIso8601String(),
  'blood_group_name': instance.bloodGroup,
  'weight': instance.weight,
  'role_id': instance.roleId,
  'token': instance.Token,
  'gender_id': instance.genderId,
  'blood_group_id': instance.bloodGroupId,
  'img_url': instance.imgUrl,
};
