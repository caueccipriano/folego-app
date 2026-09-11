import 'package:intl/intl.dart';

abstract final class Formatters {
  static final currency = NumberFormat.currency(locale: 'pt_BR', symbol: 'R\$');

  static final shortDate = DateFormat('dd MMM', 'pt_BR');
  static final fullDate = DateFormat('dd/MM/yyyy', 'pt_BR');

  static String money(num? value) => currency.format(value ?? 0);

  static num parseMoney(String raw) {
    var value = raw.trim().replaceAll('R\$', '').replaceAll(' ', '');
    if (value.contains(',')) {
      value = value.replaceAll('.', '').replaceAll(',', '.');
    }
    return num.tryParse(value) ?? 0;
  }
}
