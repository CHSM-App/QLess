// One medicine the clinic keeps in stock — a row of GET /doctor/stock/:clinic_id.
// balance may be negative: medicine given before the purchase was entered.
class ClinicStockItem {
  final int medicineId;
  final String? medicineName;
  final String? unit;
  final double? reorderLevel;
  final double? salePrice;
  final double balance;
  final bool isLow;

  const ClinicStockItem({
    required this.medicineId,
    this.medicineName,
    this.unit,
    this.reorderLevel,
    this.salePrice,
    this.balance = 0,
    this.isLow = false,
  });

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory ClinicStockItem.fromJson(Map<String, dynamic> json) => ClinicStockItem(
        medicineId:   (json['medicine_id'] as num).toInt(),
        medicineName: json['medicine_name'] as String?,
        unit:         json['unit'] as String?,
        reorderLevel: _num(json['reorder_level']),
        salePrice:    _num(json['sale_price']),
        balance:      _num(json['balance']) ?? 0,
        isLow:        json['is_low'] == 1 || json['is_low'] == true,
      );
}
