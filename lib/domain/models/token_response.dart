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

  TokenResponse({
     this.accessToken,
     this.refreshToken,
    this.mobile,
    this.deviceDetails,
     this.roleId,
     this.role,
     this.firebaseToken

  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) =>
   _$TokenResponseFromJson(json);
  

  Map<String, dynamic> toJson() => _$TokenResponseToJson(this);
}
