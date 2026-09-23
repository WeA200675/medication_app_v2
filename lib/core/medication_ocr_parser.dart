import 'models.dart';

class MedicationScanResult {
  const MedicationScanResult({
    required this.medicationName,
    required this.manufacturer,
    required this.strength,
    required this.rawText,
  });

  final String medicationName;
  final String manufacturer;
  final String strength;
  final String rawText;
  bool get needsConfirmation => medicationName.isEmpty || strength.isEmpty;
}

class MedicationOcrParser {
  const MedicationOcrParser._();

  static const _manufacturers = <String>[
    'Bayer', 'Ratiopharm', 'ratiopharm', 'Hexal', 'STADA', 'Pfizer',
    'Novartis', 'Sanofi', 'Teva', 'Zentiva', 'Aliud', 'AbZ', '1A Pharma',
    'Aristo', 'Heumann', 'Viatris', 'AstraZeneca', 'Johnson',
  ];

  static MedicationScanResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map((line) => line.replaceAll(RegExp(r'[^\p{L}\p{N}%+.,/() -]', unicode: true), ' ').replaceAll(RegExp(r'\s+'), ' ').trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var manufacturer = '';
    for (final line in lines) {
      final match = RegExp(r'^(?:hersteller|manufacturer|firma)\s*[:\-]\s*(.+)$', caseSensitive: false).firstMatch(line);
      if (match != null) manufacturer = match.group(1)!.trim();
    }

    String? productLine;
    for (final line in lines) {
      if (RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:mg|g|µg|ug|ml|%)\b', caseSensitive: false).hasMatch(line) &&
          !RegExp(r'^(?:pzn|ean|charg|lot)\b', caseSensitive: false).hasMatch(line)) {
        productLine = line;
        break;
      }
    }
    productLine ??= lines.firstWhere(
      (line) => !RegExp(r'^(?:pzn|ean|charg|lot|hersteller|manufacturer|firma)\b', caseSensitive: false).hasMatch(line),
      orElse: () => '',
    );

    var name = productLine ?? '';
    final strengthMatch = RegExp(r'\b\d+(?:[.,]\d+)?\s*(?:mg|g|µg|ug|ml|%)\b', caseSensitive: false).firstMatch(name);
    final strength = strengthMatch?.group(0)?.replaceAll('ug', 'µg') ?? '';
    if (strengthMatch != null) name = name.substring(0, strengthMatch.start).trim();
    name = _removeManufacturerPrefix(name, manufacturer);
    name = name.replaceFirst(RegExp(r'^(?:medikament|präparat|name)\s*[:\-]\s*', caseSensitive: false), '').trim();

    return MedicationScanResult(
      medicationName: name,
      manufacturer: manufacturer,
      strength: strength,
      rawText: rawText,
    );
  }

  static String _removeManufacturerPrefix(String value, String manufacturer) {
    var result = value.trim();
    final candidates = <String>{if (manufacturer.isNotEmpty) manufacturer, ..._manufacturers};
    for (final candidate in candidates) {
      result = result.replaceFirst(RegExp('^\${RegExp.escape(candidate)}\\s+', caseSensitive: false), '');
    }
    return result.trim();
  }
}
