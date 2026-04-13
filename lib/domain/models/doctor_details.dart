import 'package:json_annotation/json_annotation.dart';

part 'doctor_details.g.dart';

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

int? _intToJson(int? value) => value;

@JsonSerializable()
class DoctorDetails {
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
  @JsonKey(name: 'token')
  final String? Token;
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
  @JsonKey(name: 'gender_id')
  final int? genderId;

  @JsonKey(name: 'q_start_before', fromJson: _intFromJson, toJson: _intToJson)
  final int? leadTime;

  @JsonKey(name: 'q_start_time', includeFromJson: false, includeToJson: true)
  final int? queueStartBefore;

  @JsonKey(name: 'queue_length')
  final int? queueLength;

  DoctorDetails({
    this.queueLength,
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
    this.Token,
    this.genderId,
    this.leadTime,
    this.queueStartBefore,
  });

  factory DoctorDetails.fromJson(Map<String, dynamic> json) =>
      _$DoctorDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$DoctorDetailsToJson(this);
}
