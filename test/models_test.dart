import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app_v2/core/models.dart';

void main() {
  test('reach uses the configured decimal dose', () {
    const medication = Medication(id: '1', name: 'Test', dose: .5, unit: 'Tablette', time: '08:00', stock: 7, minimumStock: 2);
    expect(medication.estimatedDays, 14);
    expect(medication.needsRefill, isFalse);
  });

  test('minimum stock triggers refill at the threshold', () {
    const medication = Medication(id: '1', name: 'Test', dose: 1, unit: 'Tablette', time: '08:00', stock: 7, minimumStock: 7);
    expect(medication.needsRefill, isTrue);
  });
}
