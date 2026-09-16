import 'dart:convert';
import 'dart:typed_data';

import '../models/transaction_import.dart';

part 'transaction_import_csv.dart';
part 'transaction_import_ofx.dart';
part 'transaction_import_parsing_utils.dart';

class ImportParseException implements Exception {
  const ImportParseException(this.message);
  final String message;
  @override
  String toString() => message;
}

class ImportParseIssue {
  const ImportParseIssue(this.rowNumber, this.message);
  final int rowNumber;
  final String message;
}

class ImportNormalizationResult {
  const ImportNormalizationResult({
    required this.candidates,
    this.issues = const <ImportParseIssue>[],
  });
  final List<ImportCandidate> candidates;
  final List<ImportParseIssue> issues;
}

class ImportClassification {
  const ImportClassification(
    this.candidateType,
    this.finalType,
    this.confidence,
    this.reason,
  );
  final String candidateType;
  final String? finalType;
  final double confidence;
  final String reason;
}

class TransactionImportParser {
  const TransactionImportParser();

  CsvInspection inspectCsv(
    Uint8List bytes, {
    String? delimiter,
    bool? hasHeader,
  }) =>
      _inspectCsv(bytes, delimiter: delimiter, hasHeader: hasHeader);

  ImportNormalizationResult normalizeCsv({
    required CsvInspection inspection,
    required ImportCsvMapping mapping,
    required String sourceKind,
  }) =>
      _normalizeCsv(
        inspection: inspection,
        mapping: mapping,
        sourceKind: sourceKind,
      );

  OfxStatement parseOfx(
    Uint8List bytes, {
    required String sourceKind,
  }) =>
      _parseOfx(bytes, sourceKind: sourceKind);

  static String detectDelimiter(String text) => _detectDelimiter(text);

  static int parseMoneyToCents(String raw, [String format = 'auto']) =>
      _parseMoneyToCents(raw, format);

  static ImportClassification classify({
    required String sourceKind,
    required String direction,
    required String description,
    String? statementType,
  }) =>
      _classify(
        sourceKind: sourceKind,
        direction: direction,
        description: description,
        statementType: statementType,
      );
}
