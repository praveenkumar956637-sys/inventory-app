class Formatters {
  Formatters._();

  static const List<String> _months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  /// 12500 -> ₹12,500    1250000.5 -> ₹12,50,000.50 (Indian grouping).
  /// Decimals are shown only when they are not .00.
  static String rupees(double amount) {
    final bool negative = amount < 0;
    final String fixed = amount.abs().toStringAsFixed(2);
    final List<String> parts = fixed.split('.');
    final String whole = parts[0];
    final String decimals = parts[1];

    String grouped = whole;
    if (whole.length > 3) {
      final String lastThree = whole.substring(whole.length - 3);
      String rest = whole.substring(0, whole.length - 3);
      final List<String> chunks = <String>[];
      while (rest.length > 2) {
        chunks.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) chunks.insert(0, rest);
      grouped = '${chunks.join(',')},$lastThree';
    }

    final String text = decimals == '00' ? grouped : '$grouped.$decimals';
    return '${negative ? '-' : ''}₹$text';
  }

  /// 12 Oct 2026
  static String date(DateTime value) {
    return '${value.day} ${_months[value.month - 1]} ${value.year}';
  }

  /// 9:05 PM
  static String time(DateTime value) {
    final int hour = value.hour % 12 == 0 ? 12 : value.hour % 12;
    final String minute = value.minute.toString().padLeft(2, '0');
    final String period = value.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
