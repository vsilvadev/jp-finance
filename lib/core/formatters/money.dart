String yen(int amount) {
  final digits = amount.abs().toString();
  final grouped = digits.replaceAllMapped(
    RegExp(r'(?<=\d)(?=(\d{3})+$)'),
    (_) => '.',
  );
  return '${amount < 0 ? '−' : ''}¥$grouped';
}

String shortDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}';
