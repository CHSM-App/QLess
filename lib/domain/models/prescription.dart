import 'package:json_annotation/json_annotation.dart';

part 'prescription.g.dart';
@JsonSerializable()
class PrescriptionMedicineModel {
  @JsonKey(name: 'presc_med_id')
  final int? prescMedId;

  @JsonKey(name: 'prescription_id')
  final int? prescriptionId;

  @JsonKey(name: 'medicine_id')
  final int? medicineId;

  @JsonKey(name: 'medicine_type_id')
  final int? medicineTypeId;

  final String? frequency;
  final String? duration;
  final String? timing;

  @JsonKey(name: 'tablet_dosage')
  final String? tabletDosage;

  @JsonKey(name: 'syrup_dosage_ml')
  final String? syrupDosageMl;

  @JsonKey(name: 'inj_dosage')
  final String? injDosage;

  @JsonKey(name: 'inj_route')
  final String? injRoute;

  @JsonKey(name: 'drops_count')
  final String? dropsCount;

  @JsonKey(name: 'drops_application')
  final String? dropsApplication;

  @JsonKey(name: 'lotion_apply_area')
  final String? lotionApplyArea;

  @JsonKey(name: 'spray_puffs')
  final String? sprayPuffs;

  @JsonKey(name: 'spray_usage')
  final String? sprayUsage;

  const PrescriptionMedicineModel({
    this.prescMedId,
    this.prescriptionId,
    this.medicineId,
    this.medicineTypeId,
    this.frequency,
    this.duration,
    this.timing,
    this.tabletDosage,
    this.syrupDosageMl,
    this.injDosage,
    this.injRoute,
    this.dropsCount,
    this.dropsApplication,
    this.lotionApplyArea,
    this.sprayPuffs,
    this.sprayUsage,
  });
  factory PrescriptionMedicineModel.fromJson(Map<String, dynamic> json) =>
   _$PrescriptionMedicineModelFromJson(json);
  

  Map<String, dynamic> toJson() => _$PrescriptionMedicineModelToJson(this);

}

@JsonSerializable(explicitToJson: true)
class PrescriptionModel {
  @JsonKey(name: 'name')
  final String? doctorName;

  final String? qualification;

  final int? experience;

  final String? specialization;

  @JsonKey(name: 'patient_name')
  final String? patientName;

  @JsonKey(name: 'clinic_name')
  final String? clinicName;

  @JsonKey(name: 'clinic_address')
  final String? clinicAddress;

  @JsonKey(name: 'clinic_contact')
  final String? clinicContact;

  // Flat medicine fields (when API returns one row per medicine)
  @JsonKey(name: 'presc_med_id')
  final int? prescMedId;

  @JsonKey(name: 'medicine_id')
  final int? medicineId;

  @JsonKey(name: 'medicine_type_id')
  final int? medicineTypeId;

  @JsonKey(name: 'medicine_name')
  final String? medicineName;

  @JsonKey(name: 'Medi_Type_Name')
  final String? mediTypeName;

  final String? frequency;
  final String? duration;
  final String? timing;

  @JsonKey(name: 'tablet_dosage')
  final String? tabletDosage;

  @JsonKey(name: 'syrup_dosage_ml')
  final String? syrupDosageMl;

  @JsonKey(name: 'inj_dosage')
  final String? injDosage;

  @JsonKey(name: 'inj_route')
  final String? injRoute;

  @JsonKey(name: 'drops_count')
  final String? dropsCount;

  @JsonKey(name: 'drops_application')
  final String? dropsApplication;

  @JsonKey(name: 'lotion_apply_area')
  final String? lotionApplyArea;

  @JsonKey(name: 'spray_puffs')
  final String? sprayPuffs;

  @JsonKey(name: 'spray_usage')
  final String? sprayUsage;
  @JsonKey(name: 'prescription_id')
  final int? prescriptionId;

  @JsonKey(name: 'patient_id')
  final int? patientId;

  @JsonKey(name: 'doctor_id')
  final int? doctorId;

  @JsonKey(name: 'prescription_date')
  final String? prescriptionDate;

  final String? symptoms;
  final String? diagnosis;

  @JsonKey(name: 'clinical_notes')
  final String? clinicalNotes;

  @JsonKey(name: 'follow_up_date')
  final String? followUpDate;

  final String? advice;

  @JsonKey(name: 'created_at')
  final String? createdAt;

  // List of medicines — sent together in one request
  final List<PrescriptionMedicineModel>? medicines;

  const PrescriptionModel({
    this.doctorName,
    this.qualification,
    this.experience,
    this.specialization,
    this.patientName,
    this.clinicName,
    this.clinicAddress,
    this.clinicContact,
    this.prescMedId,
    this.medicineId,
    this.medicineTypeId,
    this.medicineName,
    this.mediTypeName,
    this.frequency,
    this.duration,
    this.timing,
    this.tabletDosage,
    this.syrupDosageMl,
    this.injDosage,
    this.injRoute,
    this.dropsCount,
    this.dropsApplication,
    this.lotionApplyArea,
    this.sprayPuffs,
    this.sprayUsage,
    this.prescriptionId,
    this.patientId,
    this.doctorId,
    this.prescriptionDate,
    this.symptoms,
    this.diagnosis,
    this.clinicalNotes,
    this.followUpDate,
    this.advice,
    this.createdAt,
    this.medicines,
  });

  factory PrescriptionModel.fromJson(Map<String, dynamic> json) =>
      _$PrescriptionModelFromJson(_normalizePrescriptionJson(json));

  Map<String, dynamic> toJson() => _$PrescriptionModelToJson(this);

}

Map<String, dynamic> _normalizePrescriptionJson(Map<String, dynamic> json) {
  if (json['medicines'] != null) return json;
  final alt = json['prescription_medicines'] ??
      json['prescription_medicine'] ??
      json['medicine'] ??
      json['meds'];
  if (alt == null) return json;
  final normalized = Map<String, dynamic>.from(json);
  normalized['medicines'] = alt;
  return normalized;
}
