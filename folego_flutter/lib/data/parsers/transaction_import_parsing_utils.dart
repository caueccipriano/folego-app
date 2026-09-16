part of 'transaction_import_parser.dart';

int _parseMoneyToCents(String raw, [String format = 'auto']) {
  var value = raw.trim();
  if (value.isEmpty) throw const ImportParseException('valor vazio');
  var negative = false;
  if (value.startsWith('(') && value.endsWith(')')) {
    negative = true;
    value = value.substring(1, value.length - 1);
  }
  value = value.replaceAll(RegExp(r'[^0-9,.\-+]'), '');
  if (value.contains('-')) negative = true;
  value = value.replaceAll(RegExp(r'[+-]'), '');
  if (value.isEmpty) throw const ImportParseException('valor inválido');

  String decimalSeparator;
  if (format == 'br') {
    decimalSeparator = ',';
  } else if (format == 'us') {
    decimalSeparator = '.';
  } else {
    final comma = value.lastIndexOf(',');
    final dot = value.lastIndexOf('.');
    if (comma >= 0 && dot >= 0) {
      decimalSeparator = comma > dot ? ',' : '.';
    } else if (comma >= 0) {
      decimalSeparator = value.length - comma - 1 <= 2 ? ',' : '.';
    } else {
      decimalSeparator = '.';
    }
  }

  final separatorIndex = value.lastIndexOf(decimalSeparator);
  String integerPart;
  String fractionPart;
  if (separatorIndex >= 0 && value.length - separatorIndex - 1 <= 2) {
    integerPart = value.substring(0, separatorIndex);
    fractionPart = value.substring(separatorIndex + 1);
  } else {
    integerPart = value;
    fractionPart = '';
  }
  integerPart = integerPart.replaceAll(RegExp(r'[,.]'), '');
  fractionPart = fractionPart.replaceAll(RegExp(r'[,.]'), '');
  if (integerPart.isEmpty) integerPart = '0';
  if (fractionPart.length == 1) fractionPart = '${fractionPart}0';
  if (fractionPart.length > 2) fractionPart = fractionPart.substring(0, 2);
  fractionPart = fractionPart.padRight(2, '0');
  final whole = int.tryParse(integerPart);
  final cents = int.tryParse(fractionPart);
  if (whole == null || cents == null) {
    throw const ImportParseException(
      'não consegui entender a coluna de valores',
    );
  }
  final result = whole * 100 + cents;
  return negative ? -result : result;
}

_ParsedImportDate _parseImportDate(String raw, [String format = 'auto']) {
  final value = raw.trim();
  if (value.isEmpty) throw const ImportParseException('data vazia');
  final looksIso = RegExp(r'^\d{4}-\d{2}-\d{2}').hasMatch(value);
  if (format == 'iso' || (format == 'auto' && looksIso)) {
    final parsed = DateTime.tryParse(value);
    if (parsed == null) throw const ImportParseException('data inválida');
    final dateOnly = !value.contains('T') && !value.contains(' ');
    return _ParsedImportDate(
      parsed,
      dateOnly,
      dateOnly ? _importDateKey(parsed) : null,
    );
  }
  final compact = RegExp(r'^(\d{4})(\d{2})(\d{2})$').firstMatch(value);
  if (compact != null) {
    final parsed = _safeImportDate(
      int.parse(compact.group(1)!),
      int.parse(compact.group(2)!),
      int.parse(compact.group(3)!),
    );
    return _ParsedImportDate(parsed, true, _importDateKey(parsed));
  }
  final match = RegExp(
    r'^(\d{1,2})[/-](\d{1,2})[/-](\d{4})',
  ).firstMatch(value);
  if (match == null) {
    throw const ImportParseException('algumas datas precisam ser revisadas');
  }
  final first = int.parse(match.group(1)!);
  final second = int.parse(match.group(2)!);
  final year = int.parse(match.group(3)!);
  final us = format == 'us';
  final parsed = _safeImportDate(
    year,
    us ? first : second,
    us ? second : first,
  );
  return _ParsedImportDate(parsed, true, _importDateKey(parsed));
}

ImportClassification _classify({
  required String sourceKind,
  required String direction,
  required String description,
  String? statementType,
}) {
  final text = '${description.toLowerCase()} ${(statementType ?? '').toLowerCase()}';
  final isDebit = direction == 'debit';
  final opening = RegExp(
    r'\b(saldo inicial|opening balance|saldo anterior)\b',
  ).hasMatch(text);
  final cardPayment = RegExp(
    r'(pagamento.{0,12}cart|pgto.{0,12}fatura|pagamento.{0,12}fatura|\bpayment\b)',
  ).hasMatch(text);
  final refund = RegExp(
    r'\b(estorno|refund|reembolso|reversal)\b',
  ).hasMatch(text);
  final ownTransfer = RegExp(
    r'(transfer.{0,18}(minha conta|entre contas|mesma titularidade)|reserva própria|own account)',
  ).hasMatch(text);

  if (opening) {
    return const ImportClassification(
      'unknown',
      null,
      .98,
      'saldo de abertura precisa de revisão e não vira receita',
    );
  }
  if (cardPayment) {
    return const ImportClassification(
      'card_payment_candidate',
      null,
      .88,
      'descrição sugere pagamento de fatura; confirme cartão/fatura',
    );
  }
  if (refund) {
    return const ImportClassification(
      'refund_candidate',
      null,
      .85,
      'possível estorno; vínculo com a compra original não foi assumido',
    );
  }
  if (sourceKind == 'benefit') {
    return ImportClassification(
      isDebit ? 'benefit_expense' : 'benefit_credit',
      isDebit ? 'benefit_expense' : 'benefit_credit',
      .98,
      'direção do lançamento no benefício',
    );
  }
  if (sourceKind == 'card') {
    if (isDebit) {
      return const ImportClassification(
        'card_purchase',
        'card_purchase',
        .96,
        'débito no extrato do cartão',
      );
    }
    return const ImportClassification(
      'unknown',
      null,
      .55,
      'crédito em cartão precisa de revisão',
    );
  }
  if (ownTransfer) {
    return const ImportClassification(
      'transfer_candidate',
      null,
      .78,
      'texto sugere transferência entre contas próprias; selecione a contraparte',
    );
  }
  if (isDebit) {
    return const ImportClassification('expense', 'expense', .92, 'débito em conta');
  }
  return const ImportClassification('income', 'income', .92, 'crédito em conta');
}

_DecodedImportText _decodeImportText(Uint8List bytes) {
  try {
    var text = utf8.decode(bytes, allowMalformed: false);
    if (text.startsWith('\ufeff')) text = text.substring(1);
    return _DecodedImportText(text, 'UTF-8');
  } on FormatException {
    return _DecodedImportText(latin1.decode(bytes), 'Latin-1');
  }
}

bool _looksLikeCsvHeader(List<String> row) {
  const tokens = <String>{
    'data', 'date', 'descricao', 'historico', 'valor', 'amount',
    'debito', 'credito', 'merchant', 'estabelecimento', 'fitid', 'id',
  };
  return row.map(_normalizeImportHeader).any(tokens.contains);
}

ImportCsvMapping? _suggestCsvMapping(
  List<String> headers,
  List<List<String>> rows,
  bool hasHeader,
) {
  int? find(Set<String> names) {
    for (var index = 0; index < headers.length; index++) {
      if (names.contains(_normalizeImportHeader(headers[index]))) return index;
    }
    return null;
  }

  var date = find({'data', 'date', 'dtposted', 'datatransacao', 'data lancamento'});
  var description = find({
    'descricao', 'historico', 'lancamento', 'memo', 'name',
  });
  var value = find({'valor', 'amount', 'trnamt', 'montante'});
  final debit = find({'debito', 'saida'});
  final credit = find({'credito', 'entrada'});

  if (!hasHeader && rows.isNotEmpty) {
    for (var column = 0; column < headers.length; column++) {
      final samples = rows
          .take(5)
          .where((row) => column < row.length)
          .map((row) => row[column])
          .toList();
      if (date == null &&
          samples.where((value) {
                try {
                  _parseImportDate(value);
                  return true;
                } catch (_) {
                  return false;
                }
              }).length >=
              2) {
        date = column;
        continue;
      }
      if (value == null &&
          samples.where((value) {
                try {
                  _parseMoneyToCents(value);
                  return true;
                } catch (_) {
                  return false;
                }
              }).length >=
              2) {
        value = column;
      }
    }
    if (description == null) {
      for (var index = 0; index < headers.length; index++) {
        if (index != date && index != value) {
          description = index;
          break;
        }
      }
    }
  }

  if (date == null ||
      description == null ||
      (value == null && (debit == null || credit == null))) {
    return null;
  }
  return ImportCsvMapping(
    dateColumn: date,
    descriptionColumn: description,
    valueColumn: value,
    debitColumn: value == null ? debit : null,
    creditColumn: value == null ? credit : null,
    merchantColumn: find({'merchant', 'estabelecimento', 'favorecido'}),
    categoryColumn: find({'categoria', 'category'}),
    externalIdColumn: find({'fitid', 'id', 'transactionid', 'id externo'}),
    documentColumn: find({'documento', 'document', 'checknum'}),
    balanceColumn: find({'saldo', 'balance'}),
    typeColumn: find({'tipo', 'type', 'trntype'}),
    noteColumn: find({'observacao', 'nota', 'note'}),
  );
}

String _normalizeImportHeader(String value) => value
    .trim()
    .toLowerCase()
    .replaceAll('á', 'a')
    .replaceAll('à', 'a')
    .replaceAll('ã', 'a')
    .replaceAll('â', 'a')
    .replaceAll('é', 'e')
    .replaceAll('ê', 'e')
    .replaceAll('í', 'i')
    .replaceAll('ó', 'o')
    .replaceAll('ô', 'o')
    .replaceAll('õ', 'o')
    .replaceAll('ú', 'u')
    .replaceAll('ç', 'c')
    .replaceAll(RegExp(r'[_\-]+'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ');

String _csvCell(List<String> row, int column) =>
    column < 0 || column >= row.length ? '' : row[column];

String? _optionalCsvCell(List<String> row, int? column) {
  if (column == null) return null;
  final value = _csvCell(row, column).trim();
  return value.isEmpty ? null : value;
}

DateTime _safeImportDate(int year, int month, int day) {
  if (month < 1 || month > 12 || day < 1 || day > 31) {
    throw const ImportParseException('data inválida');
  }
  final parsed = DateTime(year, month, day, 12);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw const ImportParseException('data inválida');
  }
  return parsed;
}

String _importDateKey(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

class _DecodedImportText {
  const _DecodedImportText(this.text, this.encoding);
  final String text;
  final String encoding;
}

class _ParsedImportDate {
  const _ParsedImportDate(this.value, this.dateOnly, this.localDate);
  final DateTime value;
  final bool dateOnly;
  final String? localDate;
}
