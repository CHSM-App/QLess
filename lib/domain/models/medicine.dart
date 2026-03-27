import 'package:json_annotation/json_annotation.dart';

part 'medicine.g.dart';

@JsonSerializable()
class Medicine {
 
  @JsonKey(name: 'medicine_id')
  final int? medicineId;

  @JsonKey(name: 'business_id')
  final int? businessId;

  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  @JsonKey(name: 'medicine_name')
  final String? medicineName;

  @JsonKey(name: 'medicine_type_id')
  final int? medTypeId;

    @JsonKey(name: 'Medi_Type_Name')
  final String? medTypeName;

    @JsonKey(name: 'strength')
  final int? strength;
 



  Medicine({
    this.medicineName,
    this.businessId,
    this.medTypeId,
    this.medicineId,
    this.mobileNo,
    this.strength,
    this.medTypeName,
  });
  
  factory Medicine.fromJson(Map<String, dynamic> json) =>
   _$MedicineFromJson(json);
  

  Map<String, dynamic> toJson() => _$MedicineToJson(this);

}