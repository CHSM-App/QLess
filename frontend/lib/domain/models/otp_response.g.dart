// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'otp_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

OtpResponse _$OtpResponseFromJson(Map<String, dynamic> json) => OtpResponse(
  otp: json['otp'] as String?,
  mobileNo: json['mobile_no'] as String?,
  status: (json['status'] as num?)?.toInt(),
  message: json['message'] as String?,
  loginTicket: json['loginTicket'] as String?,
);

Map<String, dynamic> _$OtpResponseToJson(OtpResponse instance) =>
    <String, dynamic>{
      'otp': ?instance.otp,
      'mobile_no': ?instance.mobileNo,
      'status': ?instance.status,
      'message': ?instance.message,
      'loginTicket': ?instance.loginTicket,
    };
