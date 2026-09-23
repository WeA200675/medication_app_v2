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
    '1A Pharma',
    'AbZ',
    'Aliud',
    'Aristo',
    'AstraZeneca',
    'Bayer',
    'Hexal',
    'Heumann',
    'Johnson',
    'Novartis',
    'Pfizer',
    'Ratiopharm',
    'Sanofi',
    'STADA',
    'Teva',
    'Viatris',
    'Zentiva',
  ];

  static final _strengthPattern = RegExp(
    r'\b\d+(?:[.,]\d+)?\s*(?:mg|g|µg|ug|ml|%)\b',
    caseSensitive: false,
  );

  static MedicationScanResult parse(String rawText) {
    final lines = rawText
        .split(RegExp(r'[\r\n]+'))
        .map(_normalize)
        .where((line) => line.isNotEmpty)
        .toList();

    var manufacturer = _findLabeledManufacturer(lines);
    manufacturer = manufacturer.isEmpty
        ? _findKnownManufacturer(lines)
        : manufacturer;

    final strengthMatch = _strengthPattern.firstMatch(lines.join(' '));
    final strength =
        strengthMatch?.group(0)?.replaceAll(RegExp('ug', caseSensitive: false), 'µg') ?? '';

    var medicationName = '';
    for (final line in lines) {
      final withoutStrength = line.replaceAll(_strengthPattern, '').trim();
      final cleaned = _stripManufacturer(withoutStrength, manufacturer);
      if (_isMedicationCandidate(cleaned)) {
        medicationName = cleaned;
        if (_strengthPattern.hasMatch(line)) break;
      }
    }

    return MedicationScanResult(
      medicationName: medicationName,
      manufacturer: manufacturer,
      strength: strength,
      rawText: rawText,
    );
  }

  static String _normalize(String line) => line
      .replaceAll(
        RegExp(r'[^\p{L}\p{N}%+.,/() -]', unicode: true),
        ' ',
      )
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  static String _findLabeledManufacturer(List<String> lines) {
    for (final line in lines) {
      final match = RegExp(
        r'^(?:hersteller|manufacturer|firma)\s*[:\-]\s*(.+)$',
        caseSensitive: false,
      ).firstMatch(line);
      if (match != null) return match.group(1)!.trim();
    }
    return '';
  }

  static String _findKnownManufacturer(List<String> lines) {
    for (final line in lines) {
      final lower = line.toLowerCase();
      for (final candidate in _manufacturers) {
        final name = candidate.toLowerCase();
        if (lower == name ||
            lower.startsWith('$name ') ||
            lower.startsWith('$name-') ||
            lower.contains('-$name ') ||
            lower.endsWith('-$name')) {
          return candidate;
        }
      }
    }
    return '';
  }

  static String _stripManufacturer(String value, String manufacturer) {
    var result = value
        .replaceFirst(
          RegExp(
            r'^(?:medikament|präparat|name)\s*[:\-]\s*',
            caseSensitive: false,
          ),
          '',
        )
        .trim();
    final candidates = <String>{
      if (manufacturer.isNotEmpty) manufacturer,
      ..._manufacturers,
    };
    for (final candidate in candidates) {
      final escaped = RegExp.escape(candidate);
      if (RegExp('^' + escaped + r'$', caseSensitive: false).hasMatch(result)) {
        return '';
      }
      result = result
          .replaceFirst(
            RegExp('^' + escaped + r'(?:\s+|[-–—]+)', caseSensitive: false),
            '',
          )
          .replaceFirst(
            RegExp(r'(?:\s+|[-–—]+)' + escaped + r'$', caseSensitive: false),
            '',
          )
          .trim();
    }
    return result;
  }
  static bool _isMedicationCandidate(String value) {
    if (value.isEmpty || !RegExp(r'[A-Za-zÄÖÜäöüß]{3}').hasMatch(value)) {
      return false;
    }
    if (RegExp(
      r'^(?:pzn|ean|charge|charg|lot|verwendbar|haltbar|hersteller|manufacturer|firma|tabletten?|filmtabletten?|kapseln?|lösung|packung)\b',
      caseSensitive: false,
    ).hasMatch(value)) {
      return false;
    }
    return !_manufacturers.any(
      (manufacturer) =>
          value.toLowerCase() == manufacturer.toLowerCase(),
    );
  }
}
