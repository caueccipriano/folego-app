part of 'transaction_import_parser.dart';

OfxStatement _parseOfx(
  Uint8List bytes, {
  required String sourceKind,
}) {
  if (bytes.isEmpty) {
    throw const ImportParseException('o arquivo OFX está vazio');
  }
  final decoded = _decodeImportText(bytes);
  final text = decoded.text.replaceAll('\u0000', '');
  if (!RegExp(r'<OFX[>\s]', caseSensitive: false).hasMatch(text)) {
    throw const ImportParseException(
      'esse arquivo não parece ser um OFX compatível',
    );
  }
  final chunks = RegExp(
    r'<STMTTRN>',
    caseSensitive: false,
  ).allMatches(text).toList();
  if (chunks.isEmpty) {
    throw const ImportParseException(
      'não encontrei transações compatíveis neste OFX',
    );
  }
  final transactions = <ImportCandidate>[];
  for (var index = 0; index < chunks.length; index++) {
    final start = chunks[index].end;
    final end = index + 1 < chunks.length
        ? chunks[index + 1].start
        : text.length;
    final block = text.substring(start, end);
    try {
      final amountRaw = _ofxTag(block, 'TRNAMT');
      final postedRaw = _ofxTag(block, 'DTPOSTED') ?? _ofxTag(block, 'DTTRAN');
      if (amountRaw == null || postedRaw == null) continue;
      final signedCents = _parseMoneyToCents(amountRaw, 'us');
      if (signedCents == 0) continue;
      final date = _parseOfxDate(postedRaw);
      final name = _ofxTag(block, 'NAME');
      final memo = _ofxTag(block, 'MEMO');
      final description = <String>{
        if (name?.trim().isNotEmpty == true) name!.trim(),
        if (memo?.trim().isNotEmpty == true) memo!.trim(),
      }.join(' · ');
      if (description.isEmpty) continue;
      final direction = signedCents < 0 ? 'debit' : 'credit';
      final trnType = _ofxTag(block, 'TRNTYPE');
      final classification = _classify(
        sourceKind: sourceKind,
        direction: direction,
        description: description,
        statementType: trnType,
      );
      final original = <String, dynamic>{
        'statement_type': trnType,
        'checknum': _ofxTag(block, 'CHECKNUM'),
      }..removeWhere((_, value) => value == null);
      transactions.add(
        ImportCandidate(
          rowNumber: index + 1,
          occurredAt: date.value,
          dateOnly: date.dateOnly,
          localDate: date.localDate,
          description: description,
          merchant: name?.trim().isEmpty == true ? null : name?.trim(),
          amountCents: signedCents.abs(),
          direction: direction,
          externalId: _ofxTag(block, 'FITID'),
          candidateType: classification.candidateType,
          finalType: classification.finalType,
          confidence: classification.confidence,
          reason: classification.reason,
          originalFields: original,
        ),
      );
    } catch (_) {
      continue;
    }
  }
  if (transactions.isEmpty) {
    throw const ImportParseException(
      'não consegui interpretar as transações deste OFX',
    );
  }
  if (transactions.length > 2000) {
    throw const ImportParseException(
      'o limite é de 2.000 linhas por importação',
    );
  }
  return OfxStatement(
    transactions: transactions,
    bankId: _ofxTag(text, 'BANKID'),
    accountId: _ofxTag(text, 'ACCTID'),
    accountType: _ofxTag(text, 'ACCTTYPE'),
    currency: _ofxTag(text, 'CURDEF'),
    start: _tryOfxDate(_ofxTag(text, 'DTSTART')),
    end: _tryOfxDate(_ofxTag(text, 'DTEND')),
    cardStatement: RegExp(
      r'<CCSTMTTRNRS>|<CCSTMTRS>',
      caseSensitive: false,
    ).hasMatch(text),
  );
}

String? _ofxTag(String text, String tag) {
  final match = RegExp(
    '<$tag>\\s*([^<\\r\\n]+)',
    caseSensitive: false,
  ).firstMatch(text);
  final value = match?.group(1)?.trim();
  return value == null || value.isEmpty ? null : value;
}

_ParsedImportDate _parseOfxDate(String raw) {
  final digits = RegExp(
    r'^(\d{4})(\d{2})(\d{2})(\d{2})?(\d{2})?(\d{2})?',
  ).firstMatch(raw.trim());
  if (digits == null) {
    throw const ImportParseException('data OFX inválida');
  }
  final year = int.parse(digits.group(1)!);
  final month = int.parse(digits.group(2)!);
  final day = int.parse(digits.group(3)!);
  if (digits.group(4) == null) {
    final value = _safeImportDate(year, month, day);
    return _ParsedImportDate(
      DateTime(year, month, day, 12),
      true,
      _importDateKey(value),
    );
  }
  final hour = int.parse(digits.group(4)!);
  final minute = int.parse(digits.group(5) ?? '00');
  final second = int.parse(digits.group(6) ?? '00');
  final offsetMatch = RegExp(
    r'\[([+-]?\d+(?:\.\d+)?):',
  ).firstMatch(raw);
  if (offsetMatch == null) {
    return _ParsedImportDate(
      DateTime(year, month, day, hour, minute, second),
      false,
      null,
    );
  }
  final offsetMinutes = (double.parse(offsetMatch.group(1)!) * 60).round();
  final utc = DateTime.utc(
    year,
    month,
    day,
    hour,
    minute,
    second,
  ).subtract(Duration(minutes: offsetMinutes));
  return _ParsedImportDate(utc, false, null);
}

DateTime? _tryOfxDate(String? raw) {
  if (raw == null) return null;
  try {
    return _parseOfxDate(raw).value;
  } catch (_) {
    return null;
  }
}
