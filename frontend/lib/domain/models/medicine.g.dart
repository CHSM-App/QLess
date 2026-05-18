// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'medicine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Medicine _$MedicineFromJson(Map<String, dynamic> json) => Medicine(
  medicineName: json['medicine_name'] as String?,
  doctorId: (json['doctor_id'] as num?)?.toInt(),
  medTypeId: (json['medicine_type_id'] as num?)?.toInt(),
  medicineId: (json['medicine_id'] as num?)?.toInt(),
  mobileNo: json['mobile_no'] as String?,
  strength: (json['strength'] as num?)?.toInt(),
  medTypeName: json['Medi_Type_Name'] as String?,
);

Map<String, dynamic> _$MedicineToJson(Medicine instance) => <String, dynamic>{
  'medicine_id': instance.medicineId,
  'doctor_id': instance.doctorId,
  'mobile_no': instance.mobileNo,
  'medicine_name': instance.medicineName,
  'medicine_type_id': instance.medTypeId,
  'Medi_Type_Name': instance.medTypeName,
  'strength': instance.strength,
};
