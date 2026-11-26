import 'package:flutter_test/flutter_test.dart';
import 'package:qless/presentation/doctor/screens/doctor_precriptionentry_screen.dart';

MedicineEntry tablet(String dosage, String duration) => MedicineEntry()
  ..dosage = dosage
  ..duration = duration;

void main() {
  test('tablets: dose per day × days, rounded up', () {
    expect(tablet('1-0-1', '5 days').suggestedQty(), '10');
    expect(tablet('½-0-½', '3').suggestedQty(), '3');
    expect(tablet('1½-0-1', '5 days').suggestedQty(), '13'); // 12.5 → 13
    expect(tablet('1-1-1', '2 weeks').suggestedQty(), '42');
    expect(tablet('0-0-1', '1 month').suggestedQty(), '30');
  });

  test('tablets without days → empty, the doctor types it', () {
    expect(tablet('1-0-1', '').suggestedQty(), '');
    expect(tablet('0-0-0', '5 days').suggestedQty(), '');
  });

  test('anything else is one unit', () {
    expect((MedicineEntry()..type = MedicineType.injections).suggestedQty(), '1');
    expect((MedicineEntry()..type = MedicineType.syrups..duration = '5 days').suggestedQty(), '1');
  });

  test('only clinic lines send qty and price; injections send given-at-clinic', () {
    final shop = MedicineEntry()..medicineId = 1..qtyGiven = '10'..unitPrice = '2';
    expect(shop.toApiModel().qtyGiven, isNull);
    expect(shop.toApiModel().source, 'outside');

    final inj = MedicineEntry()
      ..type = MedicineType.injections
      ..medicineId = 2
      ..source = 'clinic'
      ..administered = true
      ..qtyGiven = '1'
      ..unitPrice = '45.5';
    final m = inj.toApiModel();
    expect([m.source, m.administeredAtClinic, m.qtyGiven, m.unitPrice], ['clinic', true, 1.0, 45.5]);
    expect(MedicineType.consumables.typeId, 9);
  });
}
