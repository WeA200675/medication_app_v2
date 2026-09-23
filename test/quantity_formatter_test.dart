import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app_v2/core/quantity_formatter.dart';

void main() {
  test('formats singular tablet with a separating space', () {
    expect(formatMedicationQuantity(1, 'Tablette'), '1 Tablette');
  });

  test('formats plural tablets', () {
    expect(formatMedicationQuantity(2, 'Tablette'), '2 Tabletten');
    expect(formatMedicationQuantity(0, 'Tablette'), '0 Tabletten');
  });

  test('keeps fractional single tablet singular', () {
    expect(formatMedicationQuantity(.5, 'Tablette'), '0,5 Tablette');
  });

  test('does not pluralize measurement units', () {
    expect(formatMedicationQuantity(2, 'mg'), '2 mg');
  });
}
