import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app_v2/core/medication_ocr_parser.dart';

void main() {
  test('separates a known manufacturer from product name', () {
    final result = MedicationOcrParser.parse(
      'Bayer Aspirin 500 mg\nHersteller: Bayer\nPZN 123456',
    );
    expect(result.medicationName, 'Aspirin');
    expect(result.manufacturer, 'Bayer');
    expect(result.strength, '500 mg');
  });

  test('does not save PZN as medication name', () {
    final result = MedicationOcrParser.parse('ratiopharm\nIbuprofen 400 mg\nPZN 001');
    expect(result.medicationName, 'Ibuprofen');
    expect(result.medicationName, isNot(contains('ratiopharm')));
  });
}
