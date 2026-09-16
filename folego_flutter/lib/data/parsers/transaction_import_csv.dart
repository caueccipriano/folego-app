part of 'transaction_import_parser.dart';

CsvInspection _inspectCsv(
  Uint8List bytes, {
  String? delimiter,
  bool? hasHeader,
}) {
  if (bytes.isEmpty) {
    throw const ImportParseException('o arquivo CSV está vazio');
  }
  final decoded = _decodeImportText(bytes);
  final selectedDelimiter = delimiter ?? _detectDelimiter(decoded.text);
  final parsed = _parseCsvRows(decoded.text, selectedDelimiter);
  final nonEmpty = parsed
      .where((row) => row.any((cell) => cell.trim().isNotEmpty))
      .toList();
  if (nonEmpty.isEmpty) {
    throw const ImportParseException('o arquivo CSV está vazio');
  }
  final detectedHeader = hasHeader ?? _looksLikeCsvHeader(nonEmpty.first);
  final width = nonEmpty.fold<int>(
    0,
    (max, row) => row.length > max ? row.length : max,
  );
  if (width < 2) {
    throw const ImportParseException(
      'não consegui identificar as colunas do CSV',
    );
  }
  final headers = detectedHeader
      ? List<String>.generate(width, (index) {
          final value = index < nonEmpty.first.length
              ? nonEmpty.first[index].trim()
              : '';
          return value.isEmpty ? 'coluna ${index + 1}' : value;
        })
      : List<String>.generate(width, (index) => 'coluna ${index + 1}');
  final dataRows = (detectedHeader ? nonEmpty.skip(1) : nonEmpty)
      .map(
        (row) => List<String>.generate(
          width,
          (index) => index < row.length ? row[index] : '',
        ),
      )
      .toList(growable: false);
  if (dataRows.isEmpty) {
    throw const ImportParseException('o CSV não possui linhas para importar');
  }
  return CsvInspection(
    delimiter: selectedDelimiter,
    encoding: decoded.encoding,
    hasHeader: detectedHeader,
    headers: headers,
    rows: dataRows,
    suggestedMapping: _suggestCsvMapping(headers, dataRows, detectedHeader),
  );
}

ImportNormalizationResult _normalizeCsv({
  required CsvInspection inspection,
  required ImportCsvMapping mapping,
  required String sourceKind,
}) {
  if (!mapping.isValid) {
    throw const ImportParseException(
      'mapeie data, descrição e valor antes de continuar',
    );
  }
  final candidates = <ImportCandidate>[];
  final issues = <ImportParseIssue>[];
  for (var index = 0; index < inspection.rows.length; index++) {
    final row = inspection.rows[index];
    final rowNumber = index + (inspection.hasHeader ? 2 : 1);
    try {
      final parsedDate = _parseImportDate(
        _csvCell(row, mapping.dateColumn),
        mapping.dateFormat,
      );
      final description = _csvCell(row, mapping.descriptionColumn).trim();
      if (description.isEmpty) {
        throw const ImportParseException('descrição vazia');
      }
      final signedCents = _csvSignedCents(row, mapping);
      if (signedCents == 0) {
        throw const ImportParseException('valor zero');
      }
      final direction = signedCents < 0 ? 'debit' : 'credit';
      final merchant = _optionalCsvCell(row, mapping.merchantColumn);
      final externalId = _optionalCsvCell(row, mapping.externalIdColumn);
      final fileType = _optionalCsvCell(row, mapping.typeColumn);
      final classification = _classify(
        sourceKind: sourceKind,
        direction: direction,
        description: description,
        statementType: fileType,
      );
      final original = <String, dynamic>{
        'file_category': _optionalCsvCell(row, mapping.categoryColumn),
        'document': _optionalCsvCell(row, mapping.documentColumn),
        'balance_after': _optionalCsvCell(row, mapping.balanceColumn),
        'statement_type': fileType,
        'note': _optionalCsvCell(row, mapping.noteColumn),
      }..removeWhere((_, value) => value == null);
      candidates.add(
        ImportCandidate(
          rowNumber: rowNumber,
          occurredAt: parsedDate.value,
          dateOnly: parsedDate.dateOnly,
          localDate: parsedDate.localDate,
          description: description,
          merchant: merchant,
          amountCents: signedCents.abs(),
          direction: direction,
          externalId: externalId,
          candidateType: classification.candidateType,
          finalType: classification.finalType,
          confidence: classification.confidence,
          reason: classification.reason,
          originalFields: original,
        ),
      );
    } on ImportParseException catch (error) {
      issues.add(ImportParseIssue(rowNumber, error.message));
    } catch (_) {
      issues.add(
        ImportParseIssue(rowNumber, 'não consegui interpretar esta linha'),
      );
    }
  }
  if (candidates.isEmpty) {
    throw const ImportParseException(
      'nenhuma linha válida foi encontrada no CSV',
    );
  }
  if (candidates.length > 2000) {
    throw const ImportParseException(
      'o limite é de 2.000 linhas por importação',
    );
  }
  return ImportNormalizationResult(candidates: candidates, issues: issues);
}

int _csvSignedCents(List<String> row, ImportCsvMapping mapping) {
  if (mapping.valueColumn != null) {
    return _parseMoneyToCents(
      _csvCell(row, mapping.valueColumn!),
      mapping.decimalFormat,
    );
  }
  final debitText = mapping.debitColumn == null
      ? ''
      : _csvCell(row, mapping.debitColumn!);
  final creditText = mapping.creditColumn == null
      ? ''
      : _csvCell(row, mapping.creditColumn!);
  final debit = debitText.trim().isEmpty
      ? 0
      : _parseMoneyToCents(debitText, mapping.decimalFormat).abs();
  final credit = creditText.trim().isEmpty
      ? 0
      : _parseMoneyToCents(creditText, mapping.decimalFormat).abs();
  if (debit > 0 && credit > 0) {
    throw const ImportParseException(
      'débito e crédito preenchidos na mesma linha',
    );
  }
  if (debit == 0 && credit == 0) {
    throw const ImportParseException('valor vazio');
  }
  return credit > 0 ? credit : -debit;
}

String _detectDelimiter(String text) {
  const candidates = <String>[',', ';', '\t'];
  var best = ',';
  var bestScore = -1;
  for (final delimiter in candidates) {
    final rows = _parseCsvRows(text, delimiter)
        .where((row) => row.any((cell) => cell.trim().isNotEmpty))
        .take(8)
        .toList();
    if (rows.isEmpty) continue;
    final widths = rows.map((row) => row.length).toList();
    final maxWidth = widths.reduce((a, b) => a > b ? a : b);
    final consistent = widths.where((width) => width == maxWidth).length;
    final score = maxWidth > 1 ? maxWidth * 10 + consistent : 0;
    if (score > bestScore) {
      bestScore = score;
      best = delimiter;
    }
  }
  return best;
}

List<List<String>> _parseCsvRows(String text, String delimiter) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  for (var index = 0; index < text.length; index++) {
    final char = text[index];
    if (char == '"') {
      if (quoted && index + 1 < text.length && text[index + 1] == '"') {
        cell.write('"');
        index++;
      } else {
        quoted = !quoted;
      }
    } else if (!quoted && char == delimiter) {
      row.add(cell.toString());
      cell.clear();
    } else if (!quoted && (char == '\n' || char == '\r')) {
      if (char == '\r' &&
          index + 1 < text.length &&
          text[index + 1] == '\n') {
        index++;
      }
      row.add(cell.toString());
      cell.clear();
      rows.add(row);
      row = <String>[];
    } else {
      cell.write(char);
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows;
}
