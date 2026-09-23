import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app_v2/core/medication_ocr_parser.dart';

void main() {
  test('separates a known manufacturer prefix from product name', () {
    final result = MedicationOcrParser.parse(
      'Bayer Aspirin 500 mg\nHersteller: Bayer\nPZN 123456',
    );
    expect(result.medicationName, 'Aspirin');
    expect(result.manufacturer, 'Bayer');
    expect(result.strength, '500 mg');
  });

  test('separates a manufacturer suffix from product name', () {
    final result = MedicationOcrParser.parse(
      'Ibuprofen-ratiopharm 400 mg\nPZN 001',
    );
    expect(result.medicationName, 'Ibuprofen');
    expect(result.manufacturer, 'Ratiopharm');
    expect(result.strength, '400 mg');
  });

  test('never promotes a standalone manufacturer to medication name', () {
    final result = MedicationOcrParser.parse('ratiopharm\n500mg\nPZN 001');
    expect(result.medicationName, isEmpty);
    expect(result.manufacturer, 'Ratiopharm');
    expect(result.strength, '500mg');
    expect(result.needsConfirmation, isTrue);
  });

  test('uses product line while keeping standalone manufacturer separate', () {
    final result = MedicationOcrParser.parse(
      'ratiopharm\nIbuprofen 400 mg\nPZN 001',
    );
    expect(result.medicationName, 'Ibuprofen');
    expect(result.manufacturer, 'Ratiopharm');
  });
}
