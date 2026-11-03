import 'package:intl/intl.dart';

String formatCurrency(num value) {
  final formatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 2,
  );
  return formatter.format(value);
}

/// Presentation helper for signed member balances (positive = debt,
/// negative = member credit). Returns the label to display, the formatted
/// magnitude, and whether the balance is a credit; the signed value itself
/// must stay untouched in models and API payloads.
({String label, String amount, bool isCredit}) formatSignedBalance(
  num value, {
  required String debtLabel,
  required String creditLabel,
}) {
  final isCredit = value < 0;
  return (
    label: isCredit ? creditLabel : debtLabel,
    amount: formatCurrency(value.abs()),
    isCredit: isCredit,
  );
}
