import 'package:json_annotation/json_annotation.dart';
part 'receptionist_model.g.dart';

@JsonSerializable()
class ReceptionistApiModel {
  @JsonKey(name: 'recep_id')    final int?    recepId;
  @JsonKey(name: 'name')        final String? name;
  @JsonKey(name: 'mobile_no')   final String? mobileNo;
  @JsonKey(name: 'email')       final String? email;
  @JsonKey(name: 'Address')     final String? address;
  @JsonKey(name: 'gender_id')   final int?    genderId;
  @JsonKey(name: 'clinic_id')   final String? clinicId;
  @JsonKey(name: 'img_url')     final String? imgUrl;
  @JsonKey(name: 'active_status') final int?  activeStatus;
  @JsonKey(name: 'created_at')  final String? createdAt;
   
   @JsonKey(name: 'role_id')
  final int? roleId;
  @JsonKey(name: 'token')
  final String? Token;

  const ReceptionistApiModel({
    this.recepId,
    this.name,
    this.mobileNo,
    this.email,
    this.address,
    this.genderId,
    this.clinicId,
    this.imgUrl,
    this.activeStatus,
    this.createdAt,
    this.roleId,
    this.Token,
  });

  bool get isActive => activeStatus == 1;

  factory ReceptionistApiModel.fromJson(Map<String, dynamic> json) =>
      _$ReceptionistApiModelFromJson(json);

  Map<String, dynamic> toJson() => _$ReceptionistApiModelToJson(this);
}
