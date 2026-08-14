import 'package:json_annotation/json_annotation.dart';

part 'otp_response.g.dart';

@JsonSerializable(includeIfNull: false)
class OtpResponse {

  @JsonKey(name: 'otp')
  final String? otp;

  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  @JsonKey(name: 'status')
  final int? status;

  @JsonKey(name: 'message')
  final String? message;

  /// Short-lived proof that this mobile passed OTP. Handed straight back to
  /// /Createlogin, which refuses to issue a session without it.
  @JsonKey(name: 'loginTicket')
  final String? loginTicket;

  OtpResponse({
    this.otp,
    this.mobileNo,
    this.status,
    this.message,
    this.loginTicket,
  });

  /// 🔹 From JSON
  factory OtpResponse.fromJson(Map<String, dynamic> json) =>
      _$OtpResponseFromJson(json);

  /// 🔹 To JSON
  Map<String, dynamic> toJson() => _$OtpResponseToJson(this);
}