// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'token_response.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

TokenResponse _$TokenResponseFromJson(Map<String, dynamic> json) =>
    TokenResponse(
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      mobile: json['mobile'] as String?,
      deviceDetails: json['deviceDetails'] as String?,
      roleId: (json['roleId'] as num?)?.toInt(),
      role: json['role'] as String?,
    );

Map<String, dynamic> _$TokenResponseToJson(TokenResponse instance) =>
    <String, dynamic>{
      'accessToken': instance.accessToken,
      'refreshToken': instance.refreshToken,
      'mobile': instance.mobile,
      'deviceDetails': instance.deviceDetails,
      'roleId': instance.roleId,
      'role': instance.role,
    };
