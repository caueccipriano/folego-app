import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../data/models/statement_import.dart';

const int statementImportMaxBytes = 4 * 1024 * 1024;
const int statementImportMaxRows = 2000;

enum CsvDecimalFormat { auto, brazilian, american }
enum CsvDateFormat { auto, dmy, mdy, iso }

class StatementImportParseException implements Exception {
  const StatementImportParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CsvImportMapping {
  const CsvImportMapping({
    this.dateColumn,
    this.descriptionColumn,
    this.amountColumn,
    this.debitColumn,
    this.creditColumn,
    this.merchantColumn,
    this.categoryColumn,
    this.externalIdColumn,
    this.documentColumn,
    this.balanceColumn,
    this.typeColumn,
    this.noteColumn,
    this.decimalFormat = CsvDecimalFormat.auto,
    this.dateFormat = CsvDateFormat.auto,
  });

  final int? dateColumn;
  final int? descriptionColumn;
  final int? amountColumn;
  final int? debitColumn;
  final int? creditColumn;
  final int? merchantColumn;
  final int? categoryColumn;
  final int? externalIdColumn;
  final int? documentColumn;
  final int? balanceColumn;
  final int? typeColumn;
  final int? noteColumn;
  final CsvDecimalFormat decimalFormat;
  final CsvDateFormat dateFormat;

  bool get hasValueMapping => amountColumn != null || debitColumn != null || creditColumn != null;
  bool get isComplete => dateColumn != null && descriptionColumn != null && hasValueMapping;

  CsvImportMapping copyWith({
    int? dateColumn,
    int? descriptionColumn,
    int? amountColumn,
    int? debitColumn,
    int? creditColumn,
    int? merchantColumn,
    int? categoryColumn,
    int? externalIdColumn,
    int? documentColumn,
    int? balanceColumn,
    int? typeColumn,
    int? noteColumn,
    bool clearAmount = false,
    bool clearDebit = false,
    bool clearCredit = false,
    bool clearMerchant = false,
    bool clearCategory = false,
    bool clearExternalId = false,
    bool clearDocument = false,
    bool clearBalance = false,
    bool clearType = false,
    bool clearNote = false,
    CsvDecimalFormat? decimalFormat,
    CsvDateFormat? dateFormat,
  }) {
    return CsvImportMapping(
      dateColumn: dateColumn ?? this.dateColumn,
      descriptionColumn: descriptionColumn ?? this.descriptionColumn,
      amountColumn: clearAmount ? null : amountColumn ?? this.amountColumn,
      debitColumn: clearDebit ? null : debitColumn ?? this.debitColumn,
      creditColumn: clearCredit ? null : creditColumn ?? this.creditColumn,
      merchantColumn: clearMerchant ? null : merchantColumn ?? this.merchantColumn,
      categoryColumn: clearCategory ? null : categoryColumn ?? this.categoryColumn,
      externalIdColumn: clearExternalId ? null : externalIdColumn ?? this.externalIdColumn,
      documentColumn: clearDocument ? null : documentColumn ?? this.documentColumn,
      balanceColumn: clearBalance ? null : balanceColumn ?? this.balanceColumn,
      typeColumn: clearType ? null : typeColumn ?? this.typeColumn,
      noteColumn: clearNote ? null : noteColumn ?? this.noteColumn,
      decimalFormat: decimalFormat ?? this.decimalFormat,
      dateFormat: dateFormat ?? this.dateFormat,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date_column': dateColumn,
        'description_column': descriptionColumn,
        'amount_column': amountColumn,
        'debit_column': debitColumn,
        'credit_column': creditColumn,
        'merchant_column': merchantColumn,
        'category_column': categoryColumn,
        'external_id_column': externalIdColumn,
        'document_column': documentColumn,
        'balance_column': balanceColumn,
        'type_column': typeColumn,
        'note_column': noteColumn,
        'decimal_format': decimalFormat.name,
        'date_format': dateFormat.name,
      };
}

class CsvImportDocument {
  const CsvImportDocument({
    required this.delimiter,
    required this.hasHeader,
    required this.headers,
    required this.rows,
    required this.suggestedMapping,
    required this.encoding,
  });

  final String delimiter;
  final bool hasHeader;
  final List<String> headers;
  final List<List<String>> rows;
  final CsvImportMapping suggestedMapping;
  final String encoding;

  List<String> examplesFor(int? column, {int limit = 5}) {
    if (column == null || column < 0) return const <String>[];
    return rows
        .where((row) => column < row.length && row[column].trim().isNotEmpty)
        .map((row) => row[column].trim())
        .take(limit)
        .toList(growable: false);
  }

  List<StatementImportCandidate> buildCandidates({
    required CsvImportMapping mapping,
    required StatementImportSourceKind sourceKind,
  }) {
    if (!mapping.isComplete) {
      throw const StatementImportParseException('mapeie data, descrição e valor antes de continuar');
    }
    final result = <StatementImportCandidate>[];
    for (var index = 0; index < rows.length; index++) {
      final row = rows[index];
      if (row.every((value) => value.trim().isEmpty)) continue;
      try {
        final rawDate = _cell(row, mapping.dateColumn!);
        final parsedDate = parseCsvDate(rawDate, mapping.dateFormat);
        final description = _cell(row, mapping.descriptionColumn!).trim();
        if (description.isEmpty) throw const FormatException('description');

        final money = _moneyForRow(row, mapping);
        final merchant = _optionalCell(row, mapping.merchantColumn);
        final externalId = _optionalCell(row, mapping.externalIdColumn);
        final sourceType = _optionalCell(row, mapping.typeColumn);
        final classification = classifyStatementRow(
          sourceKind: sourceKind,
          direction: money.direction,
          description: description,
          sourceType: sourceType,
        );

        result.add(
          StatementImportCandidate(
            rowNumber: index + 1,
            occurredAt: parsedDate.value,
            dateOnly: parsedDate.dateOnly,
            localDate: parsedDate.localDate,
            amountMinor: money.amountMinor,
            description: description,
            merchant: merchant,
            direction: money.direction,
            externalId: externalId,
            candidateType: classification.candidateType,
            finalType: classification.finalType,
            confidence: classification.confidence,
            reason: classification.reason,
            originalFields: <String, dynamic>{
              if (_optionalCell(row, mapping.categoryColumn) case final value?) 'file_category': value,
              if (_optionalCell(row, mapping.documentColumn) case final value?) 'document': value,
              if (_optionalCell(row, mapping.balanceColumn) case final value?) 'balance_after': value,
              if (sourceType != null) 'statement_type': sourceType,
              if (_optionalCell(row, mapping.noteColumn) case final value?) 'note': value,
            },
          ),
        );
      } on StatementImportParseException {
        rethrow;
      } catch (_) {
        throw StatementImportParseException('não consegui entender a linha ${index + 1}; revise data, descrição e valor');
      }
      if (result.length > statementImportMaxRows) {
        throw const StatementImportParseException('o arquivo ultrapassa o limite de 2.000 linhas por importação');
      }
    }
    if (result.isEmpty) {
      throw const StatementImportParseException('o arquivo não contém lançamentos válidos');
    }
    return result;
  }

  _ParsedMoney _moneyForRow(List<String> row, CsvImportMapping mapping) {
    if (mapping.amountColumn != null) {
      final minor = parseMoneyMinor(_cell(row, mapping.amountColumn!), mapping.decimalFormat);
      if (minor == 0) throw const FormatException('zero amount');
      return _ParsedMoney(
        amountMinor: minor.abs(),
        direction: minor < 0 ? StatementImportDirection.debit : StatementImportDirection.credit,
      );
    }

    final debitText = _optionalCell(row, mapping.debitColumn);
    final creditText = _optionalCell(row, mapping.creditColumn);
    final debit = debitText == null ? 0 : parseMoneyMinor(debitText, mapping.decimalFormat).abs();
    final credit = creditText == null ? 0 : parseMoneyMinor(creditText, mapping.decimalFormat).abs();
    if (debit > 0 && credit > 0) {
      throw const StatementImportParseException('uma linha não pode ter débito e crédito ao mesmo tempo');
    }
    if (debit > 0) return _ParsedMoney(amountMinor: debit, direction: StatementImportDirection.debit);
    if (credit > 0) return _ParsedMoney(amountMinor: credit, direction: StatementImportDirection.credit);
    throw const StatementImportParseException('não consegui entender a coluna de valores');
  }
}

class OfxImportDocument {
  const OfxImportDocument({
    required this.candidates,
    required this.currency,
    required this.bankId,
    required this.accountId,
    required this.accountType,
    required this.statementStart,
    required this.statementEnd,
    required this.isCreditCardStatement,
  });

  final List<StatementImportCandidate> candidates;
  final String? currency;
  final String? bankId;
  final String? accountId;
  final String? accountType;
  final DateTime? statementStart;
  final DateTime? statementEnd;
  final bool isCreditCardStatement;
}

class StatementRowClassification {
  const StatementRowClassification(
    this.candidateType,
    this.finalType,
    this.confidence,
    this.reason,
  );

  final StatementImportCandidateType candidateType;
  final StatementImportFinalType? finalType;
  final double confidence;
  final String reason;
}

class ParsedStatementDate {
  const ParsedStatementDate(this.value, this.dateOnly, this.localDate);
  final DateTime value;
  final bool dateOnly;
  final String? localDate;
}

String statementFileFingerprint(Uint8List bytes) => sha256.convert(bytes).toString();

CsvImportDocument parseCsvImport(Uint8List bytes) {
  _guardFileSize(bytes);
  final decoded = _decodeText(bytes);
  final text = decoded.$1.replaceFirst('\ufeff', '');
  if (text.trim().isEmpty) throw const StatementImportParseException('o arquivo CSV está vazio');

  final delimiter = detectCsvDelimiter(text);
  final parsedRows = parseCsvRows(text, delimiter)
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList(growable: false);
  if (parsedRows.isEmpty) throw const StatementImportParseException('o arquivo CSV está vazio');
  if (parsedRows.length > statementImportMaxRows + 1) {
    throw const StatementImportParseException('o arquivo ultrapassa o limite de 2.000 linhas por importação');
  }

  final hasHeader = _looksLikeHeader(parsedRows);
  final width = parsedRows.map((row) => row.length).fold<int>(0, (a, b) => a > b ? a : b);
  final headers = hasHeader
      ? List<String>.generate(width, (index) {
          final value = index < parsedRows.first.length ? parsedRows.first[index].trim() : '';
          return value.isEmpty ? 'coluna ${index + 1}' : value;
        })
      : List<String>.generate(width, (index) => 'coluna ${index + 1}');
  final rows = (hasHeader ? parsedRows.skip(1) : parsedRows)
      .map((row) => List<String>.generate(width, (index) => index < row.length ? row[index] : ''))
      .toList(growable: false);
  if (rows.isEmpty) throw const StatementImportParseException('o CSV tem cabeçalho, mas não tem lançamentos');

  return CsvImportDocument(
    delimiter: delimiter,
    hasHeader: hasHeader,
    headers: headers,
    rows: rows,
    suggestedMapping: suggestCsvMapping(headers),
    encoding: decoded.$2,
  );
}

OfxImportDocument parseOfxImport(Uint8List bytes, StatementImportSourceKind sourceKind) {
  _guardFileSize(bytes);
  final decoded = _decodeText(bytes).$1.replaceFirst('\ufeff', '');
  final upper = decoded.toUpperCase();
  if (!upper.contains('<OFX') || !upper.contains('<STMTTRN')) {
    throw const StatementImportParseException('esse arquivo não parece ser um OFX compatível');
  }
  final isCard = upper.contains('<CCSTMT') || upper.contains('<CCACCTFROM>');
  if (sourceKind == StatementImportSourceKind.card && !isCard && !upper.contains('<BANKTRANLIST')) {
    throw const StatementImportParseException('não encontrei uma estrutura de transações compatível nesse OFX de cartão');
  }

  final blocks = _ofxTransactionBlocks(decoded);
  if (blocks.isEmpty) throw const StatementImportParseException('o OFX não contém lançamentos reconhecíveis');
  if (blocks.length > statementImportMaxRows) {
    throw const StatementImportParseException('o arquivo ultrapassa o limite de 2.000 linhas por importação');
  }

  final candidates = <StatementImportCandidate>[];
  for (var i = 0; i < blocks.length; i++) {
    final block = blocks[i];
    final amountText = _tag(block, 'TRNAMT');
    final posted = _tag(block, 'DTPOSTED') ?? _tag(block, 'DTUSER');
    if (amountText == null || posted == null) {
      throw StatementImportParseException('o lançamento OFX ${i + 1} não tem data ou valor');
    }
    final amountMinorSigned = _parseOfxAmount(amountText);
    if (amountMinorSigned == 0) continue;
    final direction = amountMinorSigned < 0 ? StatementImportDirection.debit : StatementImportDirection.credit;
    final name = _tag(block, 'NAME');
    final memo = _tag(block, 'MEMO');
    final description = [name, memo]
        .whereType<String>()
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .join(' — ');
    if (description.isEmpty) {
      throw StatementImportParseException('o lançamento OFX ${i + 1} não tem descrição');
    }
    final type = _tag(block, 'TRNTYPE');
    final parsedDate = parseOfxDate(posted);
    final classification = classifyStatementRow(
      sourceKind: sourceKind,
      direction: direction,
      description: description,
      sourceType: type,
    );
    candidates.add(
      StatementImportCandidate(
        rowNumber: i + 1,
        occurredAt: parsedDate.value,
        dateOnly: parsedDate.dateOnly,
        localDate: parsedDate.localDate,
        amountMinor: amountMinorSigned.abs(),
        description: description,
        merchant: name,
        direction: direction,
        externalId: _tag(block, 'FITID'),
        candidateType: classification.candidateType,
        finalType: classification.finalType,
        confidence: classification.confidence,
        reason: classification.reason,
        originalFields: <String, dynamic>{
          if (type != null) 'statement_type': type,
          if (_tag(block, 'CHECKNUM') case final value?) 'checknum': value,
        },
      ),
    );
  }
  if (candidates.isEmpty) throw const StatementImportParseException('o OFX não contém lançamentos válidos');

  DateTime? optionalDate(String tag) {
    final raw = _tag(decoded, tag);
    if (raw == null) return null;
    try {
      return parseOfxDate(raw).value;
    } catch (_) {
      return null;
    }
  }

  return OfxImportDocument(
    candidates: candidates,
    currency: _tag(decoded, 'CURDEF'),
    bankId: _tag(decoded, 'BANKID') ?? _tag(decoded, 'ORG'),
    accountId: _tag(decoded, 'ACCTID'),
    accountType: _tag(decoded, 'ACCTTYPE'),
    statementStart: optionalDate('DTSTART'),
    statementEnd: optionalDate('DTEND'),
    isCreditCardStatement: isCard,
  );
}

String detectCsvDelimiter(String text) {
  final lines = const LineSplitter()
      .convert(text)
      .where((line) => line.trim().isNotEmpty)
      .take(8)
      .toList(growable: false);
  if (lines.isEmpty) return ',';
  const candidates = <String>[',', ';', '\t'];
  String best = ',';
  var bestScore = -1;
  for (final delimiter in candidates) {
    final widths = lines.map((line) => parseCsvRows(line, delimiter).first.length).toList();
    final modeWidth = widths.fold<Map<int, int>>(<int, int>{}, (map, width) {
      map[width] = (map[width] ?? 0) + 1;
      return map;
    }).entries.reduce((a, b) => a.value >= b.value ? a : b);
    final score = modeWidth.key > 1 ? modeWidth.value * 100 + modeWidth.key : 0;
    if (score > bestScore) {
      bestScore = score;
      best = delimiter;
    }
  }
  return best;
}

List<List<String>> parseCsvRows(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var i = 0; i < text.length; i++) {
    final char = text[i];
    if (char == '"') {
      if (quoted && i + 1 < text.length && text[i + 1] == '"') {
        cell.write('"');
        i++;
      } else {
        quoted = !quoted;
      }
      continue;
    }
    if (!quoted && char == delimiter) {
      row.add(cell.toString());
      cell.clear();
      continue;
    }
    if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
      continue;
    }
    cell.write(char);
  }
  if (quoted) throw const StatementImportParseException('o CSV tem aspas abertas e não pôde ser lido');
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}

CsvImportMapping suggestCsvMapping(List<String> headers) {
  int? find(List<RegExp> patterns) {
    for (var i = 0; i < headers.length; i++) {
      final normalized = _normalize(headers[i]);
      if (patterns.any((pattern) => pattern.hasMatch(normalized))) return i;
    }
    return null;
  }

  return CsvImportMapping(
    dateColumn: find([RegExp(r'^data$'), RegExp(r'date'), RegExp(r'dt.*(mov|lan|post)')]),
    descriptionColumn: find([RegExp(r'descri'), RegExp(r'histor'), RegExp(r'description'), RegExp(r'memo'), RegExp(r'^name$')]),
    amountColumn: find([RegExp(r'^valor$'), RegExp(r'amount'), RegExp(r'trnamt')]),
    debitColumn: find([RegExp(r'debito'), RegExp(r'^debit$'), RegExp(r'valor.*deb')]),
    creditColumn: find([RegExp(r'credito'), RegExp(r'^credit$'), RegExp(r'valor.*cred')]),
    merchantColumn: find([RegExp(r'estabele'), RegExp(r'merchant'), RegExp(r'favorec')]),
    categoryColumn: find([RegExp(r'categoria'), RegExp(r'category')]),
    externalIdColumn: find([RegExp(r'fitid'), RegExp(r'id.*extern'), RegExp(r'transaction.*id'), RegExp(r'^id$')]),
    documentColumn: find([RegExp(r'document'), RegExp(r'checknum'), RegExp(r'numero.*doc')]),
    balanceColumn: find([RegExp(r'saldo'), RegExp(r'balance')]),
    typeColumn: find([RegExp(r'^tipo$'), RegExp(r'type'), RegExp(r'trntype')]),
    noteColumn: find([RegExp(r'observ'), RegExp(r'note')]),
  );
}

int parseMoneyMinor(String raw, CsvDecimalFormat format) {
  var value = raw.trim().replaceAll(RegExp(r'[^0-9,\.\-+()]'), '');
  if (value.isEmpty) throw const FormatException('money');
  var negative = value.startsWith('-') || (value.startsWith('(') && value.endsWith(')'));
  value = value.replaceAll(RegExp(r'[+\-()]'), '');
  if (value.isEmpty) throw const FormatException('money');

  String normalized;
  final comma = value.lastIndexOf(',');
  final dot = value.lastIndexOf('.');
  final effective = format == CsvDecimalFormat.auto
      ? (comma >= 0 && dot >= 0
          ? (comma > dot ? CsvDecimalFormat.brazilian : CsvDecimalFormat.american)
          : comma >= 0
              ? CsvDecimalFormat.brazilian
              : CsvDecimalFormat.american)
      : format;
  if (effective == CsvDecimalFormat.brazilian) {
    normalized = value.replaceAll('.', '').replaceAll(',', '.');
  } else {
    normalized = value.replaceAll(',', '');
  }
  final parsed = num.parse(normalized);
  final minor = (parsed * 100).round();
  return negative ? -minor : minor;
}

ParsedStatementDate parseCsvDate(String raw, CsvDateFormat format) {
  final value = raw.trim();
  if (value.isEmpty) throw const FormatException('date');
  if (format == CsvDateFormat.iso || (format == CsvDateFormat.auto && RegExp(r'^\d{4}[-/]\d{1,2}[-/]\d{1,2}').hasMatch(value))) {
    final match = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})').firstMatch(value);
    if (match == null) throw const FormatException('date');
    return _dateOnly(int.parse(match.group(1)!), int.parse(match.group(2)!), int.parse(match.group(3)!));
  }
  final match = RegExp(r'^(\d{1,2})[./-](\d{1,2})[./-](\d{2,4})').firstMatch(value);
  if (match == null) throw const FormatException('date');
  final first = int.parse(match.group(1)!);
  final second = int.parse(match.group(2)!);
  var year = int.parse(match.group(3)!);
  if (year < 100) year += year >= 70 ? 1900 : 2000;
  final useMdy = format == CsvDateFormat.mdy || (format == CsvDateFormat.auto && first <= 12 && second > 12);
  return _dateOnly(year, useMdy ? first : second, useMdy ? second : first);
}

ParsedStatementDate parseOfxDate(String raw) {
  final value = raw.trim();
  final match = RegExp(r'^(\d{4})(\d{2})(\d{2})(?:(\d{2})(\d{2})(\d{2}))?(?:\.\d+)?(?:\[([+-]?\d+(?:\.\d+)?):[^\]]+\])?').firstMatch(value);
  if (match == null) throw const StatementImportParseException('algumas datas do OFX precisam ser revisadas');
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final hour = int.tryParse(match.group(4) ?? '') ?? 12;
  final minute = int.tryParse(match.group(5) ?? '') ?? 0;
  final second = int.tryParse(match.group(6) ?? '') ?? 0;
  final offsetText = match.group(7);
  if (offsetText == null) return _dateOnly(year, month, day);
  final offsetMinutes = (double.parse(offsetText) * 60).round();
  final utc = DateTime.utc(year, month, day, hour, minute, second).subtract(Duration(minutes: offsetMinutes));
  return ParsedStatementDate(utc, false, null);
}

StatementRowClassification classifyStatementRow({
  required StatementImportSourceKind sourceKind,
  required StatementImportDirection direction,
  required String description,
  String? sourceType,
}) {
  final text = _normalize('$description ${sourceType ?? ''}');
  final opening = RegExp(r'(saldo inicial|saldo anterior|opening balance|beginning balance)').hasMatch(text);
  if (opening) {
    return const StatementRowClassification(StatementImportCandidateType.unknown, null, .99, 'saldo de abertura precisa de revisão e nunca vira receita automaticamente');
  }
  final cardPayment = RegExp(r'(pagamento.*cart|pgto.*(fat|cart)|pag.*fatura|card payment|payment thank)').hasMatch(text);
  if (cardPayment) {
    return const StatementRowClassification(StatementImportCandidateType.cardPaymentCandidate, null, .90, 'parece pagamento de cartão; associe a uma fatura antes de importar');
  }
  final refund = RegExp(r'(estorno|refund|reversal|chargeback|reembolso)').hasMatch(text);
  if (refund) {
    return const StatementRowClassification(StatementImportCandidateType.refundCandidate, null, .88, 'parece estorno/reembolso; o vínculo original precisa ser revisado');
  }
  final transfer = RegExp(r'(transferencia entre contas|transf.*propria|resgate.*invest|aplicacao.*invest)').hasMatch(text);
  if (transfer) {
    return const StatementRowClassification(StatementImportCandidateType.transferCandidate, null, .82, 'parece movimentação entre contas próprias; confirme a contraparte');
  }

  switch (sourceKind) {
    case StatementImportSourceKind.card:
      if (direction == StatementImportDirection.debit) {
        return const StatementRowClassification(StatementImportCandidateType.cardPurchase, StatementImportFinalType.cardPurchase, .92, 'débito em extrato de cartão');
      }
      return const StatementRowClassification(StatementImportCandidateType.refundCandidate, null, .60, 'crédito em cartão pode ser pagamento, ajuste ou estorno');
    case StatementImportSourceKind.benefit:
      if (direction == StatementImportDirection.debit) {
        return const StatementRowClassification(StatementImportCandidateType.benefitExpense, StatementImportFinalType.benefitExpense, .95, 'débito em benefício');
      }
      return const StatementRowClassification(StatementImportCandidateType.benefitCredit, StatementImportFinalType.benefitCredit, .95, 'crédito em benefício');
    case StatementImportSourceKind.account:
      if (direction == StatementImportDirection.debit) {
        return const StatementRowClassification(StatementImportCandidateType.expense, StatementImportFinalType.expense, .85, 'débito em conta bancária');
      }
      return const StatementRowClassification(StatementImportCandidateType.income, StatementImportFinalType.income, .78, 'crédito em conta bancária');
  }
}

void _guardFileSize(Uint8List bytes) {
  if (bytes.isEmpty) throw const StatementImportParseException('o arquivo está vazio');
  if (bytes.length > statementImportMaxBytes) {
    throw const StatementImportParseException('o arquivo é grande demais; use até 4 MB e 2.000 lançamentos por lote');
  }
}

(String, String) _decodeText(Uint8List bytes) {
  try {
    return (utf8.decode(bytes, allowMalformed: false), 'utf-8');
  } catch (_) {
    return (latin1.decode(bytes, allowInvalid: true), 'latin-1');
  }
}

bool _looksLikeHeader(List<List<String>> rows) {
  if (rows.length < 2) return true;
  const tokens = <String>['data', 'date', 'descr', 'histor', 'valor', 'amount', 'debito', 'credito', 'merchant', 'fitid', 'saldo', 'tipo'];
  final first = rows.first.map(_normalize).toList();
  final hits = first.where((cell) => tokens.any(cell.contains)).length;
  if (hits >= 2) return true;
  final firstNumeric = first.where((cell) => RegExp(r'^[-+]?\d+[,.]?\d*$').hasMatch(cell)).length;
  final secondNumeric = rows[1].map((cell) => cell.trim()).where((cell) => RegExp(r'^[-+]?\d+[,.]?\d*$').hasMatch(cell)).length;
  return firstNumeric == 0 && secondNumeric > 0;
}

String _cell(List<String> row, int index) {
  if (index < 0 || index >= row.length) throw const FormatException('column');
  return row[index];
}

String? _optionalCell(List<String> row, int? index) {
  if (index == null || index < 0 || index >= row.length) return null;
  final value = row[index].trim();
  return value.isEmpty ? null : value;
}

ParsedStatementDate _dateOnly(int year, int month, int day) {
  final date = DateTime(year, month, day, 12);
  if (date.year != year || date.month != month || date.day != day) throw const FormatException('date');
  String two(int value) => value.toString().padLeft(2, '0');
  return ParsedStatementDate(date, true, '$year-${two(month)}-${two(day)}');
}

int _parseOfxAmount(String raw) {
  final normalized = raw.trim().replaceAll(',', '.');
  final value = num.parse(normalized);
  return (value * 100).round();
}

List<String> _ofxTransactionBlocks(String text) {
  final matches = RegExp(r'<STMTTRN\b[^>]*>(.*?)(?=</STMTTRN\s*>|<STMTTRN\b|</BANKTRANLIST|</CCSTMTTRNRS|$)', caseSensitive: false, dotAll: true).allMatches(text);
  return matches.map((match) => match.group(1) ?? '').where((block) => block.trim().isNotEmpty).toList(growable: false);
}

String? _tag(String text, String name) {
  final escaped = RegExp.escape(name);
  final xml = RegExp('<$escaped\\b[^>]*>\\s*(.*?)\\s*</$escaped\\s*>', caseSensitive: false, dotAll: true).firstMatch(text);
  if (xml != null) return _cleanTagValue(xml.group(1));
  final sgml = RegExp('<$escaped\\b[^>]*>\\s*([^<\\r\\n]+)', caseSensitive: false).firstMatch(text);
  return _cleanTagValue(sgml?.group(1));
}

String? _cleanTagValue(String? value) {
  final trimmed = value?.replaceAll(RegExp(r'\s+'), ' ').trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

String _normalize(String value) {
  var result = value.toLowerCase().trim();
  const from = 'áàãâäéèêëíìîïóòõôöúùûüç';
  const to = 'aaaaaeeeeiiiiooooouuuuc';
  for (var i = 0; i < from.length; i++) {
    result = result.replaceAll(from[i], to[i]);
  }
  return result.replaceAll(RegExp(r'\s+'), ' ');
}

class _ParsedMoney {
  const _ParsedMoney({required this.amountMinor, required this.direction});
  final int amountMinor;
  final StatementImportDirection direction;
}
