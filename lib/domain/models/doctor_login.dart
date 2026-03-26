import 'package:json_annotation/json_annotation.dart';

part 'doctor_login.g.dart';

@JsonSerializable()
class DoctorLogin {
  // Doctor fields
  @JsonKey(name: 'doctor_id')
  final int? doctorId;
  final String? name;
  final String? email;
  final String? mobile;
  final String? qualification;
  @JsonKey(name: 'license_no')
  final String? licenseNo;
  final int? experience;
  final String? specialization;
  final String? image;
    @JsonKey(name: 'role_id')
  final int? roleId;

  // Clinic fields
  @JsonKey(name: 'clinic_id')
  final String? clinicId;
  @JsonKey(name: 'clinic_name')
  final String? clinicName;
  @JsonKey(name: 'clinic_address')
  final String? clinicAddress;
  final double? latitude;
  final double? longitude;
  @JsonKey(name: 'consultation_fee')
  final double? consultationFee;
   @JsonKey(name: 'website_name')
  final String? websiteName;
   @JsonKey(name: 'clinic_email')
  final String? clinicEmail;
   @JsonKey(name: 'clinic_contact')
  final String? clinicContact;
   @JsonKey(name: 'image_url')
  final String? imageUrl;

  DoctorLogin({
    this.doctorId,
    this.name,
    this.email,
    this.mobile,
    this.qualification,
    this.licenseNo,
    this.experience,
    this.specialization,
    this.image,
    this.clinicId,
    this.clinicName,
    this.clinicAddress,
    this.latitude,
    this.longitude,
    this.consultationFee,
    this.websiteName,
    this.clinicEmail,
    this.clinicContact,
    this.imageUrl,
    this.roleId,
  });
  
  factory DoctorLogin.fromJson(Map<String, dynamic> json) =>
   _$DoctorLoginFromJson(json);
  

  Map<String, dynamic> toJson() => _$DoctorLoginToJson(this);

}