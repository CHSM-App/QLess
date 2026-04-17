import 'package:json_annotation/json_annotation.dart';

part 'doctor_details.g.dart';

int? _intFromJson(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double? _doubleFromJson(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

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

  @JsonKey(fromJson: _doubleFromJson)
  final double? latitude;

  @JsonKey(fromJson: _doubleFromJson)
  final double? longitude;

  @JsonKey(name: 'consultation_fee', fromJson: _doubleFromJson)
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

  // Queue config
  @JsonKey(name: 'q_start_before', fromJson: _intFromJson)
  final int? leadTime;

  @JsonKey(name: 'q_start_section', fromJson: _intFromJson)
  final int? qStartSection;

  // 🔥 Queue status (from APPLY query)
  @JsonKey(name: 'queue_length', fromJson: _intFromJson)
  final int? queueLength;

  @JsonKey(name: 'is_queue_available', fromJson: _intFromJson)
  final int? isQueueAvailable;
  @JsonKey(name: 'is_slot_available', fromJson: _intFromJson)
  final int? isSlotAvailable;

  @JsonKey(name: 'is_booking_started', fromJson: _intFromJson)
  final int? isBookingStarted;

  @JsonKey(name: 'current_queue_length', fromJson: _intFromJson)
  final int? currentQueueLength;

  @JsonKey(name: 'max_queue_length', fromJson: _intFromJson)
  final int? maxQueueLength;

  @JsonKey(name: 'is_queue_full', fromJson: _intFromJson)
  final int? isQueueFull;

  @JsonKey(name: 'booking_start_time')
  final String? bookingStartTime;

  @JsonKey(name: 'is_recently_visited', fromJson: _intFromJson)
  final int? isRecentlyVisited;

  DoctorDetails({
    this.doctorId,
    this.name,
    this.email,
    this.mobile,
    this.qualification,
    this.licenseNo,
    this.experience,
    this.specialization,
    this.image,
    this.roleId,
    this.Token,
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
    this.genderId,
    this.leadTime,
    this.qStartSection,
    this.queueLength,
    this.isQueueAvailable,
    this.isSlotAvailable,
    this.isBookingStarted,
    this.currentQueueLength,
    this.maxQueueLength,
    this.isQueueFull,
    this.bookingStartTime,
    this.isRecentlyVisited,
  });

  factory DoctorDetails.fromJson(Map<String, dynamic> json) =>
      _$DoctorDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$DoctorDetailsToJson(this);
}