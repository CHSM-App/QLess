class ClinicImageModel {
  final int? id;
  final String? clinicId;
  final String? imageUrl;
  final int? sortOrder;

  const ClinicImageModel({
    this.id,
    this.clinicId,
    this.imageUrl,
    this.sortOrder,
  });

  factory ClinicImageModel.fromJson(Map<String, dynamic> json) =>
      ClinicImageModel(
        id: json['id'] as int?,
        clinicId: json['clinic_id']?.toString(),
        imageUrl: json['image_url'] as String?,
        sortOrder: json['sort_order'] as int?,
      );
}
