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
  Gender: json['Gender'] as String?,
  address: json['address'] as String?,
  bloodGroup: json['blood_group'] as String?,
  weight: (json['Weight'] as num?)?.toDouble(),
);

Map<String, dynamic> _$PatientsToJson(Patients instance) => <String, dynamic>{
  'patient_id': instance.patientId,
  'name': instance.name,
  'mobile_no': instance.mobileNo,
  'address': instance.address,
  'email': instance.email,
  'Gender': instance.Gender,
  'DOB': instance.DOB?.toIso8601String(),
  'blood_group': instance.bloodGroup,
  'Weight': instance.weight,
};
