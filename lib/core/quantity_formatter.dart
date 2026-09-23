String formatMedicationNumber(double value) {
  return value == value.roundToDouble()
      ? value.toInt().toString()
      : value.toString().replaceAll('.', ',');
}

String formatMedicationQuantity(double quantity, String unit) {
  final trimmedUnit = unit.trim();
  final useSingular = quantity > 0 && quantity <= 1;
  final displayedUnit = useSingular ? trimmedUnit : _pluralOf(trimmedUnit);
  return '${formatMedicationNumber(quantity)} $displayedUnit'.trim();
}

String _pluralOf(String unit) {
  switch (unit.toLowerCase()) {
    case 'tablette':
      return 'Tabletten';
    case 'kapsel':
      return 'Kapseln';
    case 'ampulle':
      return 'Ampullen';
    case 'dosis':
      return 'Dosen';
    case 'beutel':
      return 'Beutel';
    case 'tropfen':
      return 'Tropfen';
    case 'stück':
      return 'Stück';
    case 'ml':
    case 'mg':
    case 'g':
    case 'µg':
    case 'ug':
      return unit;
    default:
      return unit;
  }
}
