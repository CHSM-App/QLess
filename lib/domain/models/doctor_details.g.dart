// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'doctor_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

DoctorDetails _$DoctorDetailsFromJson(Map<String, dynamic> json) =>
    DoctorDetails(
      queueLength: (json['queue_length'] as num?)?.toInt(),
      doctorId: (json['doctor_id'] as num?)?.toInt(),
      name: json['name'] as String?,
      email: json['email'] as String?,
      mobile: json['mobile'] as String?,
      qualification: json['qualification'] as String?,
      licenseNo: json['license_no'] as String?,
      experience: (json['experience'] as num?)?.toInt(),
      specialization: json['specialization'] as String?,
      image: json['image'] as String?,
      clinicId: json['clinic_id'] as String?,
      clinicName: json['clinic_name'] as String?,
      clinicAddress: json['clinic_address'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      consultationFee: (json['consultation_fee'] as num?)?.toDouble(),
      websiteName: json['website_name'] as String?,
      clinicEmail: json['clinic_email'] as String?,
      clinicContact: json['clinic_contact'] as String?,
      imageUrl: json['image_url'] as String?,
      roleId: (json['role_id'] as num?)?.toInt(),
      Token: json['token'] as String?,
      genderId: (json['gender_id'] as num?)?.toInt(),
      leadTime: (json['q_start_time'] as num?)?.toInt(),
    );

Map<String, dynamic> _$DoctorDetailsToJson(DoctorDetails instance) =>
    <String, dynamic>{
      'doctor_id': instance.doctorId,
      'name': instance.name,
      'email': instance.email,
      'mobile': instance.mobile,
      'qualification': instance.qualification,
      'license_no': instance.licenseNo,
      'experience': instance.experience,
      'specialization': instance.specialization,
      'image': instance.image,
      'role_id': instance.roleId,
      'token': instance.Token,
      'clinic_id': instance.clinicId,
      'clinic_name': instance.clinicName,
      'clinic_address': instance.clinicAddress,
      'latitude': instance.latitude,
      'longitude': instance.longitude,
      'consultation_fee': instance.consultationFee,
      'website_name': instance.websiteName,
      'clinic_email': instance.clinicEmail,
      'clinic_contact': instance.clinicContact,
      'image_url': instance.imageUrl,
      'gender_id': instance.genderId,
      'q_start_time': instance.leadTime,
      'queue_length': instance.queueLength,
    };
