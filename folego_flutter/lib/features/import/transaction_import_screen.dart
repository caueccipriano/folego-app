import 'dart:async';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/transaction_import.dart';
import '../../data/parsers/transaction_import_parser.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_transaction_import.dart';
import '../../shared/widgets/category_search_picker.dart';

class TransactionImportScreen extends StatefulWidget {
  const TransactionImportScreen({super.key, required this.repository, required this.spaceId});
  final FolegoRepository repository;
  final String spaceId;

  @override
  State<TransactionImportScreen> createState() => _TransactionImportScreenState();
}

class _TransactionImportScreenState extends State<TransactionImportScreen> {
  static const _maxRawBytes = 5 * 1024 * 1024;
  final _parser = const TransactionImportParser();
  final _search = TextEditingController();

  int _step = 0;
  bool _busy = false;
  String? _error;
  Uint8List? _bytes;
  String? _filename;
  String? _fileType;
  String? _fingerprint;
  CsvInspection? _csv;
  ImportCsvMapping? _mapping;
  List<ImportParseIssue> _parseIssues = const [];
  List<ImportSourceOption> _sources = const [];
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];
  List<ImportInvoiceOption> _invoices = const [];
  String _sourceKind = 'account';
  String? _sourceId;
  String? _batchId;
  List<ImportRow> _rows = const [];
  Set<String> _bulk = <String>{};
  String _filter = 'all';
  String _query = '';
  ImportConfirmationResult? _result;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCatalogs());
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadCatalogs() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listImportSources(widget.spaceId),
        widget.repository.listExpenseCategoryCatalog(widget.spaceId),
        widget.repository.listIncomeCategoryCatalog(widget.spaceId),
        widget.repository.listImportInvoiceOptions(widget.spaceId),
      ]);
      if (!mounted) return;
      setState(() {
        _sources = values[0] as List<ImportSourceOption>;
        _expenseCategories = values[1] as List<CategoryItem>;
        _incomeCategories = values[2] as List<CategoryItem>;
        _invoices = values[3] as List<ImportInvoiceOption>;
        _ensureSource();
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'não consegui carregar contas e cartões');
    }
  }

  void _ensureSource() {
    final options = _sources.where((item) => item.kind == _sourceKind).toList();
    if (_sourceId == null || !options.any((item) => item.id == _sourceId)) {
      _sourceId = options.isEmpty ? null : options.first.id;
    }
  }

  Future<void> _pickFile() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'ofx'],
        allowMultiple: false,
        withData: true,
      );
      if (result == null || result.files.isEmpty) return;
      final file = result.files.single;
      final bytes = file.bytes;
      if (bytes == null) throw const ImportParseException('não consegui ler esse arquivo');
      if (bytes.lengthInBytes > _maxRawBytes) {
        throw const ImportParseException('o arquivo deve ter no máximo 5 MB');
      }
      final type = (file.extension ?? '').toLowerCase();
      if (type != 'csv' && type != 'ofx') {
        throw const ImportParseException('escolha um arquivo CSV ou OFX');
      }
      CsvInspection? csv;
      ImportCsvMapping? mapping;
      var sourceKind = _sourceKind;
      if (type == 'csv') {
        csv = _parser.inspectCsv(bytes);
        mapping = csv.suggestedMapping;
      } else if (_parser.parseOfx(bytes, sourceKind: 'account').cardStatement) {
        sourceKind = 'card';
      }
      if (!mounted) return;
      setState(() {
        _bytes = bytes;
        _filename = file.name;
        _fileType = type;
        _fingerprint = sha256.convert(bytes).toString();
        _csv = csv;
        _mapping = mapping;
        _sourceKind = sourceKind;
        _sourceId = null;
        _ensureSource();
        _step = 1;
      });
    } on ImportParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'não consegui abrir esse arquivo');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reinspect({String? delimiter, bool? header}) async {
    final bytes = _bytes;
    if (bytes == null) return;
    try {
      final csv = _parser.inspectCsv(bytes, delimiter: delimiter, hasHeader: header);
      setState(() { _csv = csv; _mapping = csv.suggestedMapping; _error = null; });
    } on ImportParseException catch (e) {
      setState(() => _error = e.message);
    }
  }

  Future<void> _nextDestination() async {
    if (_sourceId == null) {
      setState(() => _error = 'selecione a conta ou cartão de destino');
      return;
    }
    if (_fileType == 'csv') {
      setState(() { _step = 2; _error = null; });
    } else {
      await _stage();
    }
  }

  Future<void> _stage() async {
    final bytes = _bytes;
    final sourceId = _sourceId;
    if (bytes == null || sourceId == null || _filename == null || _fileType == null) return;
    setState(() { _busy = true; _error = null; });
    try {
      late List<ImportCandidate> candidates;
      late Map<String, dynamic> config;
      if (_fileType == 'csv') {
        if (_csv == null || _mapping?.isValid != true) {
          throw const ImportParseException('mapeie data, descrição e valor antes de continuar');
        }
        final normalized = _parser.normalizeCsv(
          inspection: _csv!,
          mapping: _mapping!,
          sourceKind: _sourceKind,
        );
        candidates = normalized.candidates;
        _parseIssues = normalized.issues;
        config = {
          'delimiter': _csv!.delimiter == '\t' ? 'tab' : _csv!.delimiter,
          'encoding': _csv!.encoding,
          'has_header': _csv!.hasHeader,
          'date_format': _mapping!.dateFormat,
          'decimal_format': _mapping!.decimalFormat,
        };
      } else {
        final ofx = _parser.parseOfx(bytes, sourceKind: _sourceKind);
        candidates = ofx.transactions;
        config = {
          'currency': ofx.currency,
          'bank_id': ofx.bankId,
          'statement_account_id': ofx.accountId,
          'statement_account_type': ofx.accountType,
          'card_statement': ofx.cardStatement,
        }..removeWhere((_, value) => value == null);
      }
      final source = _sources.firstWhere((item) => item.id == sourceId);
      final batchId = await widget.repository.stageTransactionImport(
        spaceId: widget.spaceId,
        filename: _filename!,
        fileType: _fileType!,
        sourceKind: _sourceKind,
        sourceAccountId: _sourceKind == 'card' ? null : sourceId,
        sourceCardId: _sourceKind == 'card' ? sourceId : null,
        sourceInstitution: source.institution,
        fileFingerprint: _fingerprint,
        configuration: config,
        candidates: candidates,
      );
      final rows = await widget.repository.listImportRows(spaceId: widget.spaceId, batchId: batchId);
      if (!mounted) return;
      setState(() {
        _batchId = batchId;
        _rows = rows;
        _bytes = null;
        _step = 3;
      });
    } on ImportParseException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _replace(ImportRow next) => setState(() {
        _rows = [for (final row in _rows) if (row.id == next.id) next else row];
      });

  Future<CategoryItem?> _pickCategory(String kind, String? selectedId) {
    final categories = kind == 'income' ? _incomeCategories : _expenseCategories;
    if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
      return showModalBottomSheet<CategoryItem>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: .88,
          child: CategorySearchPicker(
            categories: categories,
            eventType: kind,
            selectedId: selectedId,
          ),
        ),
      );
    }
    return showDialog<CategoryItem>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: SizedBox(
          width: 620,
          height: 720,
          child: CategorySearchPicker(
            categories: categories,
            eventType: kind,
            selectedId: selectedId,
            dialogMode: true,
          ),
        ),
      ),
    );
  }

  Future<void> _bulkCategory() async {
    final selected = _rows.where((row) => _bulk.contains(row.id)).toList();
    final kinds = selected.map((row) => _categoryKind(row.finalType)).whereType<String>().toSet();
    if (kinds.length != 1) {
      setState(() => _error = 'selecione linhas do mesmo tipo para categoria em lote');
      return;
    }
    final category = await _pickCategory(kinds.single, null);
    if (category == null) return;
    setState(() {
      _rows = [
        for (final row in _rows)
          if (_bulk.contains(row.id) && _categoryKind(row.finalType) == kinds.single)
            row.copyWith(categoryId: category.id)
          else row,
      ];
    });
  }

  String? _validateReview() {
    final included = _rows.where((row) => row.included).toList();
    if (included.isEmpty) return 'selecione pelo menos um lançamento';
    for (final row in included) {
      if (row.finalType == null) return 'alguns itens ainda precisam de um tipo financeiro';
      if (row.finalType == 'transfer' && row.counterpartAccountId == null) {
        return 'toda transferência precisa da outra conta';
      }
      if (row.finalType == 'card_payment' && row.invoiceId == null) {
        return 'todo pagamento de fatura precisa de uma fatura';
      }
      if (row.finalType == 'card_payment' && _sourceKind == 'card' && row.counterpartAccountId == null) {
        return 'informe a conta pagadora do pagamento de fatura';
      }
    }
    if (_rows.any((row) => row.userDecision == 'review')) {
      return 'há itens pendentes: marque para importar ou ignorar';
    }
    return null;
  }

  Future<void> _prepareConfirmation() async {
    final validation = _validateReview();
    if (validation != null) { setState(() => _error = validation); return; }
    setState(() { _busy = true; _error = null; });
    try {
      await widget.repository.updateImportRowsReview(
        spaceId: widget.spaceId,
        batchId: _batchId!,
        rows: _rows,
      );
      if (mounted) setState(() => _step = 4);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _confirm() async {
    setState(() { _busy = true; _error = null; });
    try {
      final result = await widget.repository.confirmTransactionImport(
        spaceId: widget.spaceId,
        batchId: _batchId!,
      );
      if (!mounted) return;
      setState(() { _result = result; _step = 5; });
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancel() async {
    if (_batchId == null) { Navigator.of(context).pop(false); return; }
    try {
      await widget.repository.cancelTransactionImport(spaceId: widget.spaceId, batchId: _batchId!);
      if (mounted) Navigator.of(context).pop(false);
    } catch (e) {
      if (mounted) setState(() => _error = _friendly(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop = layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    return Scaffold(
      appBar: AppBar(
        title: const Text('importar extrato'),
        leading: IconButton(onPressed: _busy ? null : _cancel, icon: const Icon(AppIcons.back)),
      ),
      body: AppContentContainer(
        maxWidth: desktop ? AppContentWidths.dashboard : AppContentWidths.form,
        fillHeight: true,
        child: Column(
          children: [
            _steps(),
            if (_error != null) Padding(
              padding: const EdgeInsets.only(top: 8),
              child: MaterialBanner(
                content: Text(_error!),
                actions: [TextButton(onPressed: () => setState(() => _error = null), child: const Text('fechar'))],
              ),
            ),
            Expanded(child: _stepBody(desktop)),
          ],
        ),
      ),
    );
  }

  Widget _steps() {
    final labels = _fileType == 'csv'
        ? const ['arquivo', 'destino', 'mapeamento', 'revisar', 'confirmar', 'resultado']
        : const ['arquivo', 'destino', 'revisar', 'confirmar', 'resultado'];
    final current = _fileType == 'csv' || _step <= 1 ? _step : _step - 1;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < labels.length; i++) Padding(
          padding: const EdgeInsets.only(right: 6, top: 8),
          child: Chip(
            avatar: Icon(i < current ? AppIcons.check : AppIcons.forward, size: 14),
            label: Text(labels[i]),
            backgroundColor: i == current ? Theme.of(context).colorScheme.primaryContainer : null,
          ),
        ),
      ]),
    );
  }

  Widget _stepBody(bool desktop) => switch (_step) {
        0 => _fileStep(),
        1 => _destinationStep(),
        2 => _mappingStep(),
        3 => _reviewStep(desktop),
        4 => _confirmStep(),
        5 => _resultStep(),
        _ => _fileStep(),
      };

  Widget _fileStep() => ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
        _panel('1. arquivo', 'CSV ou OFX · até 5 MB · máximo de 2.000 linhas', [
          const Text('O arquivo é lido no dispositivo e não altera saldos antes da confirmação.'),
          const SizedBox(height: 16),
          FilledButton.icon(
            key: const ValueKey('import-pick-file'),
            onPressed: _busy ? null : _pickFile,
            icon: const Icon(AppIcons.receipt),
            label: const Text('escolher CSV ou OFX'),
          ),
          const SizedBox(height: 10),
          const Text('OFX 1.x (SGML) e 2.x (XML) são aceitos quando contêm STMTTRN compatível.'),
        ]),
      ]);

  Widget _destinationStep() {
    final options = _sources.where((item) => item.kind == _sourceKind).toList();
    return ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
      _panel('2. destino', _filename ?? '', [
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(value: 'account', label: Text('conta')),
            ButtonSegment(value: 'card', label: Text('cartão')),
            ButtonSegment(value: 'benefit', label: Text('benefício')),
          ],
          selected: {_sourceKind},
          onSelectionChanged: (value) => setState(() { _sourceKind = value.single; _sourceId = null; _ensureSource(); }),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: options.any((item) => item.id == _sourceId) ? _sourceId : null,
          decoration: const InputDecoration(labelText: 'instrumento'),
          items: [for (final item in options) DropdownMenuItem(value: item.id, child: Text(item.name))],
          onChanged: (value) => setState(() => _sourceId = value),
        ),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('import-destination-continue'),
          onPressed: _busy ? null : _nextDestination,
          child: Text(_fileType == 'csv' ? 'mapear CSV' : 'preparar revisão'),
        ),
      ]),
    ]);
  }

  Widget _mappingStep() {
    final csv = _csv;
    if (csv == null) return const Center(child: Text('CSV indisponível'));
    return ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
      _panel('3. mapeamento CSV', '${csv.encoding} · ${csv.rows.length} linhas', [
        Wrap(spacing: 8, children: [
          for (final delimiter in const [',', ';', '\t']) ChoiceChip(
            label: Text(delimiter == '\t' ? 'tab' : delimiter),
            selected: csv.delimiter == delimiter,
            onSelected: (_) => _reinspect(delimiter: delimiter, header: csv.hasHeader),
          ),
        ]),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('primeira linha é cabeçalho'),
          value: csv.hasHeader,
          onChanged: (value) => _reinspect(delimiter: csv.delimiter, header: value),
        ),
        _mapField('data *', csv, _mapping?.dateColumn, true, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(dateColumn: v ?? 0)),
        _mapField('descrição *', csv, _mapping?.descriptionColumn, true, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(descriptionColumn: v ?? 0)),
        _mapField('valor', csv, _mapping?.valueColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(valueColumn: v, clearValueColumn: v == null, clearDebitColumn: v != null, clearCreditColumn: v != null)),
        if (_mapping?.valueColumn == null) ...[
          _mapField('débito', csv, _mapping?.debitColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(debitColumn: v, clearDebitColumn: v == null)),
          _mapField('crédito', csv, _mapping?.creditColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(creditColumn: v, clearCreditColumn: v == null)),
        ],
        _mapField('estabelecimento', csv, _mapping?.merchantColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(merchantColumn: v, clearMerchantColumn: v == null)),
        _mapField('categoria do arquivo', csv, _mapping?.categoryColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(categoryColumn: v, clearCategoryColumn: v == null)),
        _mapField('id externo / FITID', csv, _mapping?.externalIdColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(externalIdColumn: v, clearExternalIdColumn: v == null)),
        _mapField('documento', csv, _mapping?.documentColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(documentColumn: v, clearDocumentColumn: v == null)),
        _mapField('saldo após lançamento', csv, _mapping?.balanceColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(balanceColumn: v, clearBalanceColumn: v == null)),
        _mapField('tipo', csv, _mapping?.typeColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(typeColumn: v, clearTypeColumn: v == null)),
        _mapField('observação', csv, _mapping?.noteColumn, false, (v) => _mapping = (_mapping ?? _blankMapping()).copyWith(noteColumn: v, clearNoteColumn: v == null)),
        Row(children: [
          Expanded(child: DropdownButtonFormField<String>(
            value: _mapping?.dateFormat ?? 'auto',
            decoration: const InputDecoration(labelText: 'data'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('detectar')),
              DropdownMenuItem(value: 'br', child: Text('DD/MM/AAAA')),
              DropdownMenuItem(value: 'us', child: Text('MM/DD/AAAA')),
              DropdownMenuItem(value: 'iso', child: Text('AAAA-MM-DD')),
            ],
            onChanged: (v) => setState(() => _mapping = (_mapping ?? _blankMapping()).copyWith(dateFormat: v)),
          )),
          const SizedBox(width: 10),
          Expanded(child: DropdownButtonFormField<String>(
            value: _mapping?.decimalFormat ?? 'auto',
            decoration: const InputDecoration(labelText: 'decimal'),
            items: const [
              DropdownMenuItem(value: 'auto', child: Text('detectar')),
              DropdownMenuItem(value: 'br', child: Text('1.234,56')),
              DropdownMenuItem(value: 'us', child: Text('1,234.56')),
            ],
            onChanged: (v) => setState(() => _mapping = (_mapping ?? _blankMapping()).copyWith(decimalFormat: v)),
          )),
        ]),
        const SizedBox(height: 16),
        FilledButton(
          key: const ValueKey('import-mapping-continue'),
          onPressed: _busy ? null : _stage,
          child: const Text('preparar revisão'),
        ),
      ]),
    ]);
  }

  ImportCsvMapping _blankMapping() => const ImportCsvMapping(dateColumn: 0, descriptionColumn: 0);

  Widget _mapField(String label, CsvInspection csv, int? value, bool requiredField, ValueChanged<int?> changed) {
    final examples = csv.examplesFor(value);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        DropdownButtonFormField<int?>(
          value: value,
          decoration: InputDecoration(labelText: label),
          items: [
            if (!requiredField) const DropdownMenuItem<int?>(value: null, child: Text('não usar')),
            for (var i = 0; i < csv.headers.length; i++) DropdownMenuItem<int?>(value: i, child: Text(csv.headers[i])),
          ],
          onChanged: (v) => setState(() => changed(v)),
        ),
        if (examples.isNotEmpty) Text(examples.map((v) => '“$v”').join(' · '), maxLines: 2, overflow: TextOverflow.ellipsis),
      ]),
    );
  }

  Widget _reviewStep(bool desktop) {
    final visible = _visibleRows();
    return Column(children: [
      if (_parseIssues.isNotEmpty) Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Text('${_parseIssues.length} linha(s) inválida(s) ficaram fora do lote.'),
      ),
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(children: [
          TextField(controller: _search, decoration: const InputDecoration(prefixIcon: Icon(AppIcons.search), hintText: 'buscar neste lote'), onChanged: (v) => setState(() => _query = v)),
          const SizedBox(height: 7),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
            for (final item in const [('all','todos'),('selected','selecionados'),('duplicates','duplicados'),('pending','pendentes'),('errors','com erro')]) Padding(
              padding: const EdgeInsets.only(right: 6),
              child: ChoiceChip(label: Text(item.$2), selected: _filter == item.$1, onSelected: (_) => setState(() => _filter = item.$1)),
            ),
          ])),
          if (_bulk.isNotEmpty) Row(children: [
            Text('${_bulk.length} selecionado(s)'),
            const Spacer(),
            TextButton(onPressed: _bulkCategory, child: const Text('categoria em lote')),
            TextButton(onPressed: () => _bulkDecision('include'), child: const Text('incluir')),
            TextButton(onPressed: () => _bulkDecision('ignore'), child: const Text('ignorar')),
          ]),
        ]),
      ),
      Expanded(child: visible.isEmpty
          ? const Center(child: Text('nenhuma linha neste filtro'))
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 90),
              itemCount: visible.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _reviewRow(visible[i], dense: desktop),
            )),
      SafeArea(top: false, child: Row(children: [
        Expanded(child: OutlinedButton(onPressed: _busy ? null : _cancel, child: const Text('cancelar'))),
        const SizedBox(width: 8),
        Expanded(child: FilledButton(key: const ValueKey('import-review-continue'), onPressed: _busy ? null : _prepareConfirmation, child: const Text('revisão concluída'))),
      ])),
    ]);
  }

  void _bulkDecision(String decision) => setState(() {
        _rows = [for (final row in _rows) _bulk.contains(row.id) ? row.copyWith(userDecision: decision) : row];
      });

  Widget _reviewRow(ImportRow row, {required bool dense}) {
    final duplicate = switch (row.duplicateState) {
      'already_imported' => 'já importado',
      'exact_duplicate' => 'duplicata exata',
      'possible_duplicate' => 'possível duplicata',
      _ => null,
    };
    return Card(
      key: ValueKey('import-row-${row.id}'),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(dense ? 10 : 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Checkbox(value: row.included, onChanged: (v) => _replace(row.copyWith(userDecision: v == true ? 'include' : 'ignore'))),
            Checkbox(
              value: _bulk.contains(row.id),
              onChanged: (v) => setState(() {
                if (v == true) { _bulk.add(row.id); } else { _bulk.remove(row.id); }
              }),
            ),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(row.description, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text('${_date(row.occurredAt)} · ${row.direction == 'debit' ? 'saída' : 'entrada'}'),
            ])),
            Text(Formatters.money(row.amount), style: const TextStyle(fontWeight: FontWeight.w800)),
          ]),
          if (duplicate != null || row.reason != null || row.errorText != null) Wrap(spacing: 6, children: [
            if (duplicate != null) Chip(key: ValueKey('duplicate-${row.id}'), label: Text(duplicate)),
            if (row.reason != null) Chip(label: Text(row.reason!)),
            if (row.errorText != null) Chip(label: Text(row.errorText!)),
          ]),
          Wrap(spacing: 8, runSpacing: 8, children: [
            SizedBox(width: 220, child: DropdownButtonFormField<String>(
              value: _types().any((item) => item.$1 == row.finalType) ? row.finalType : null,
              decoration: const InputDecoration(labelText: 'tipo financeiro'),
              items: [for (final item in _types()) DropdownMenuItem(value: item.$1, child: Text(item.$2))],
              onChanged: (v) => _replace(row.copyWith(
                finalType: v,
                clearFinalType: v == null,
                clearCategoryId: _categoryKind(v) == null,
                clearCounterpartAccountId: v != 'transfer' && v != 'card_payment',
                clearInvoiceId: v != 'card_payment',
                userDecision: v == null ? 'review' : row.userDecision,
              )),
            )),
            if (_categoryKind(row.finalType) != null) OutlinedButton.icon(
              onPressed: () async {
                final c = await _pickCategory(_categoryKind(row.finalType)!, row.categoryId);
                if (c != null) _replace(row.copyWith(categoryId: c.id));
              },
              icon: const Icon(AppIcons.categoryUnclassified, size: 16),
              label: Text(_categoryName(row.categoryId) ?? 'categoria'),
            ),
            if (row.finalType == 'transfer') _accountDropdown(row, 'outra conta'),
            if (row.finalType == 'card_payment') ...[
              _invoiceDropdown(row),
              if (_sourceKind == 'card') _accountDropdown(row, 'conta pagadora'),
            ],
          ]),
        ]),
      ),
    );
  }

  Widget _accountDropdown(ImportRow row, String label) {
    final options = _sources.where((item) => item.kind == 'account' && item.id != _sourceId).toList();
    return SizedBox(width: 220, child: DropdownButtonFormField<String>(
      value: options.any((item) => item.id == row.counterpartAccountId) ? row.counterpartAccountId : null,
      decoration: InputDecoration(labelText: label),
      items: [for (final item in options) DropdownMenuItem(value: item.id, child: Text(item.name))],
      onChanged: (v) => _replace(row.copyWith(counterpartAccountId: v, clearCounterpartAccountId: v == null)),
    ));
  }

  Widget _invoiceDropdown(ImportRow row) {
    final options = _sourceKind == 'card' ? _invoices.where((i) => i.cardId == _sourceId).toList() : _invoices;
    return SizedBox(width: 250, child: DropdownButtonFormField<String>(
      value: options.any((i) => i.id == row.invoiceId) ? row.invoiceId : null,
      decoration: const InputDecoration(labelText: 'fatura'),
      items: [for (final i in options) DropdownMenuItem(value: i.id, child: Text('${_cardName(i.cardId)} · ${_date(i.dueDate)}'))],
      onChanged: (v) => _replace(row.copyWith(invoiceId: v, clearInvoiceId: v == null)),
    ));
  }

  Widget _confirmStep() {
    final included = _rows.where((row) => row.included).length;
    final ignored = _rows.where((row) => row.userDecision == 'ignore').length;
    final duplicates = _rows.where((row) => row.duplicateState != 'unique').length;
    return ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
      _panel('5. confirmar', 'nada foi lançado no ledger até agora', [
        _summary('importar', included), _summary('ignorar', ignored), _summary('duplicados sinalizados', duplicates),
        const SizedBox(height: 12),
        const Text('Cada linha será processada atomicamente pelos contratos financeiros canônicos.'),
        const SizedBox(height: 16),
        FilledButton(key: const ValueKey('import-confirm'), onPressed: _busy ? null : _confirm, child: const Text('confirmar e importar')),
        TextButton(onPressed: _busy ? null : () => setState(() => _step = 3), child: const Text('voltar para revisão')),
      ]),
    ]);
  }

  Widget _resultStep() {
    final result = _result!;
    return ListView(padding: const EdgeInsets.symmetric(vertical: 24), children: [
      _panel('6. resultado', result.status == 'completed' ? 'importação concluída' : 'importação parcial', [
        _summary('importados', result.imported), _summary('ignorados', result.ignored), _summary('duplicados', result.duplicates), _summary('com erro', result.errors),
        if (result.pending > 0) _summary('pendentes', result.pending),
        const SizedBox(height: 16),
        FilledButton(key: const ValueKey('import-see-transactions'), onPressed: () => Navigator.of(context).pop(true), child: const Text('ver lançamentos')),
      ]),
    ]);
  }

  Widget _panel(String title, String subtitle, List<Widget> children) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            if (subtitle.isNotEmpty) Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ...children,
          ]),
        ),
      );

  Widget _summary(String label, int value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(children: [Expanded(child: Text(label)), Text('$value', style: const TextStyle(fontWeight: FontWeight.w800))]),
      );

  List<ImportRow> _visibleRows() => _rows.where((row) {
        final filter = switch (_filter) {
          'selected' => row.included,
          'duplicates' => row.duplicateState != 'unique',
          'pending' => row.needsReview,
          'errors' => row.status == 'error',
          _ => true,
        };
        final query = _query.trim().toLowerCase();
        return filter && (query.isEmpty || row.description.toLowerCase().contains(query) || (row.merchant?.toLowerCase().contains(query) ?? false));
      }).toList();

  List<(String, String)> _types() => switch (_sourceKind) {
        'card' => const [('card_purchase', 'compra no cartão'), ('card_payment', 'pagamento de fatura')],
        'benefit' => const [('benefit_expense', 'gasto de benefício'), ('benefit_credit', 'crédito de benefício')],
        _ => const [('expense', 'despesa'), ('income', 'receita'), ('transfer', 'transferência'), ('card_payment', 'pagamento de fatura')],
      };

  String? _categoryKind(String? type) => switch (type) {
        'income' || 'benefit_credit' => 'income',
        'expense' || 'card_purchase' || 'benefit_expense' => 'expense',
        _ => null,
      };

  String? _categoryName(String? id) {
    if (id == null) return null;
    for (final item in [..._expenseCategories, ..._incomeCategories]) {
      if (item.id == id) return item.breadcrumb;
    }
    return null;
  }

  String _cardName(String id) {
    for (final item in _sources) {
      if (item.kind == 'card' && item.id == id) return item.name;
    }
    return 'Cartão';
  }

  String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('import_row_limit_exceeded')) return 'o limite é de 2.000 linhas por importação';
    if (text.contains('import_payload_too_large')) return 'o lote ficou grande demais para importar de uma vez';
    if (text.contains('invalid_import_source')) return 'essa conta ou cartão não pode receber a importação';
    if (text.contains('import_type_requires_review')) return 'alguns itens ainda precisam ser revisados';
    return 'não consegui concluir esta etapa da importação';
  }
}
