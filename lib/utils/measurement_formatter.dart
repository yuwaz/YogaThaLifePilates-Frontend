String formatMeasurementNum(num? value) {
  if (value == null) return '-';
  final doubleVal = value.toDouble();
  if (doubleVal.truncateToDouble() == doubleVal) {
    return doubleVal.toInt().toString();
  }
  // Format up to 2 decimal places and trim trailing zeros
  final formatted = doubleVal.toStringAsFixed(2);
  return formatted.replaceAll(RegExp(r'\.?0+$'), '');
}

String getMeasurementUnit(String fieldKey) {
  final key = fieldKey.trim().toLowerCase();
  switch (key) {
    case 'height':
    case 'boy':
      return 'cm';
    case 'weight':
    case 'kilo':
      return 'kg';
    case 'bodyfatpercentage':
    case 'bodyfat':
    case 'yag orani':
    case 'yağ oranı':
    case 'yag_orani':
      return '%';
    case 'waist':
    case 'bel':
    case 'hip':
    case 'kalca':
    case 'kalça':
    case 'chest':
    case 'gogus':
    case 'göğüs':
    case 'arm':
    case 'kol':
    case 'leg':
    case 'bacak':
    case 'shoulder':
    case 'omuz':
      return 'cm';
    default:
      return 'cm';
  }
}

String formatMeasurementValue(num? value, String fieldKey) {
  if (value == null) return '-';
  final formattedNum = formatMeasurementNum(value);
  final unit = getMeasurementUnit(fieldKey);
  return '$formattedNum $unit';
}

String formatSignedMeasurementChange(num? value, String fieldKey) {
  if (value == null) return '-';
  final doubleVal = value.toDouble();
  if (doubleVal == 0) return '0';
  final formattedNum = formatMeasurementNum(doubleVal.abs());
  final unit = getMeasurementUnit(fieldKey);
  final sign = doubleVal > 0 ? '+' : '-';
  return '$sign$formattedNum $unit';
}
