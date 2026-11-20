import 'package:json_annotation/json_annotation.dart';

part 'medicine.g.dart';

@JsonSerializable()
class Medicine {
 
  @JsonKey(name: 'medicine_id')
  final int? medicineId;

  @JsonKey(name: 'doctor_id')
  final int? doctorId;

  @JsonKey(name: 'mobile_no')
  final String? mobileNo;

  @JsonKey(name: 'medicine_name')
  final String? medicineName;

  @JsonKey(name: 'medicine_type_id')
  final int? medTypeId;

    @JsonKey(name: 'Medi_Type_Name')
  final String? medTypeName;

    @JsonKey(name: 'strength')
  final String? strength;

  @JsonKey(name: 'brand_name')
  final String? brandName;

  @JsonKey(name: 'components')
  final String? components;


  Medicine({
    this.medicineName,
    this.doctorId,
    this.medTypeId,
    this.medicineId,
    this.mobileNo,
    this.strength,
    this.medTypeName,
    this.brandName,
    this.components,
  });
  
  /// "Paracetamol 500mg · Crocin" — empty parts are left out.
  String get displayName {
    final name = [medicineName, strength]
        .where((s) => s != null && s.isNotEmpty)
        .join(' ');
    final brand = brandName ?? '';
    return brand.isEmpty ? name : '$name · $brand';
  }

  factory Medicine.fromJson(Map<String, dynamic> json) =>
   _$MedicineFromJson(json);
  

  Map<String, dynamic> toJson() => _$MedicineToJson(this);

}