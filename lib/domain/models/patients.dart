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

  @JsonKey(name: 'address')
  final String? address;

  @JsonKey(name: 'email')
  final String? email;

  @JsonKey(name: 'Gender')
  final String? Gender;

  @JsonKey(name: 'DOB')
  final DateTime? DOB;

  @JsonKey(name: 'blood_group')
  final String? bloodGroup;

  @JsonKey(name: 'Weight')
  final double? weight;
 




  Patients({
    this.patientId,
    this.name,
    this.email,
    this.mobileNo,
    this.DOB,
    this.Gender,
    this.address,
    this.bloodGroup,
    this.weight
  });
  
  factory Patients.fromJson(Map<String, dynamic> json) =>
   _$PatientsFromJson(json);
  

  Map<String, dynamic> toJson() => _$PatientsToJson(this);

}