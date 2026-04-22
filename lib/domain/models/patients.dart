import 'package:json_annotation/json_annotation.dart';

part 'patients.g.dart';

@JsonSerializable()
class Patients {
 
  @JsonKey(name: 'patient_id')
  final int? patientId;

  @JsonKey(name: 'name')
  final String? name;

  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  @JsonKey(name: 'Address')
  final String? address;

  @JsonKey(name: 'email')
  final String? email;

  @JsonKey(name: 'gender')
  final String? gender;

  @JsonKey(name: 'DOB')
  final DateTime? DOB;

  @JsonKey(name: 'blood_group')
  final String? bloodGroup;

  @JsonKey(name: 'weight')
  final String? weight;
 
   @JsonKey(name: 'role_id')
  final int? roleId;
  @JsonKey(name: 'token')
  final String? Token;
 
  @JsonKey(name: 'gender_id')
  final int? genderId;

  @JsonKey(name: 'blood_group_id')
  final int? bloodGroupId;
    @JsonKey(name: 'img_url')
  final String? imgUrl;



  Patients({
    this.patientId,
    this.name,
    this.email,
    this.mobileNo,
    this.DOB,
    this.gender,
    this.address,
    this.bloodGroup,
    this.weight,
    this.roleId,
    this.Token,
    this.genderId,
    this.bloodGroupId,
    this.imgUrl,
  });
  
  factory Patients.fromJson(Map<String, dynamic> json) =>
   _$PatientsFromJson(json);
  

  Map<String, dynamic> toJson() => _$PatientsToJson(this);

}
