import 'package:json_annotation/json_annotation.dart';

part 'token_response.g.dart';

@JsonSerializable()
class TokenResponse {
  final String? accessToken;
  final String? refreshToken;
  final String? mobile;
  final String? deviceDetails;
  final int? roleId;
  final String? role;
  final String? firebaseToken;

  /// Proof of OTP from /verify-otp — required by /Createlogin for real users.
  final String? loginTicket;

  /// Demo/review accounts skip the SMS OTP and present the fixed demo code
  /// instead; the server checks it against its own demo-number ranges.
  final String? otp;

  TokenResponse({
     this.accessToken,
     this.refreshToken,
    this.mobile,
    this.deviceDetails,
     this.roleId,
     this.role,
     this.firebaseToken,
     this.loginTicket,
     this.otp,
  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) =>
   _$TokenResponseFromJson(json);
  

  Map<String, dynamic> toJson() => _$TokenResponseToJson(this);
}
