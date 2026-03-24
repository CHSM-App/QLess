import 'package:json_annotation/json_annotation.dart';

part 'token_response.g.dart';

@JsonSerializable()
class TokenResponse {
  final String? accessToken;
  final String? refreshToken;
  final String? mobile;
  final String? deviceDetails;
  final int? roleId;

  TokenResponse({
     this.accessToken,
     this.refreshToken,
    this.mobile,
    this.deviceDetails,
     this.roleId,

  });

  factory TokenResponse.fromJson(Map<String, dynamic> json) =>
   _$TokenResponseFromJson(json);
  

  Map<String, dynamic> toJson() => _$TokenResponseToJson(this);
}
