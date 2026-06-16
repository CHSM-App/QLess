// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'receptionist_model.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ReceptionistApiModel _$ReceptionistApiModelFromJson(
  Map<String, dynamic> json,
) => ReceptionistApiModel(
  recepId: (json['recep_id'] as num?)?.toInt(),
  name: json['name'] as String?,
  mobileNo: json['mobile_no'] as String?,
  email: json['email'] as String?,
  address: json['Address'] as String?,
  genderId: (json['gender_id'] as num?)?.toInt(),
  clinicId: json['clinic_id'] as String?,
  imgUrl: json['img_url'] as String?,
  activeStatus: (json['active_status'] as num?)?.toInt(),
  createdAt: json['created_at'] as String?,
  roleId: (json['role_id'] as num?)?.toInt(),
  Token: json['token'] as String?,
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  doctorMobile: json['doctor_mobile'] as String?,
);

Map<String, dynamic> _$ReceptionistApiModelToJson(
  ReceptionistApiModel instance,
) => <String, dynamic>{
  'recep_id': instance.recepId,
  'name': instance.name,
  'mobile_no': instance.mobileNo,
  'email': instance.email,
  'Address': instance.address,
  'gender_id': instance.genderId,
  'clinic_id': instance.clinicId,
  'img_url': instance.imgUrl,
  'active_status': instance.activeStatus,
  'created_at': instance.createdAt,
  'role_id': instance.roleId,
  'token': instance.Token,
  'doctor_id': instance.doctorId,
  'doctor_mobile': instance.doctorMobile,
};
