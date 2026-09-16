import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/category_item.dart';
import '../../data/models/credit_card_item.dart';
import '../../data/models/statement_import.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../data/repositories/folego_repository_statement_import.dart';
import '../profile/category_management_screen.dart';
import 'statement_import_parser.dart';

class StatementImportPickedFile {
  const StatementImportPickedFile({required this.name, required this.bytes});
  final String name;
  final Uint8List bytes;
}

class StatementImportBootstrap {
  const StatementImportBootstrap({
    required this.paymentAccounts,
    required this.benefitAccounts,
    required this.cards,
    required this.expenseCategories,
    required this.incomeCategories,
    required this.invoices,
  });

  final List<AccountItem> paymentAccounts;
  final List<AccountItem> benefitAccounts;
  final List<CreditCardItem> cards;
  final List<CategoryItem> expenseCategories;
  final List<CategoryItem> incomeCategories;
  final List<StatementImportInvoiceOption> invoices;
}

typedef StatementImportPicker = Future<StatementImportPickedFile?> Function();
typedef StatementImportBootstrapLoader = Future<StatementImportBootstrap> Function();
typedef StatementImportStager = Future<String> Function({
  required StatementImportFileType fileType,
  required StatementImportSourceKind sourceKind,
  required String? sourceAccountId,
  required String? sourceCardId,
  required String? sourceInstitution,
  required String fingerprint,
  required Map<String, dynamic> configuration,
  required List<StatementImportCandidate> candidates,
});
typedef StatementImportRowsLoader = Future<List<StatementImportRow>> Function(String batchId);
typedef StatementImportRowsUpdater = Future<void> Function(String batchId, List<StatementImportRow> rows);
typedef StatementImportConfirmer = Future<StatementImportResult> Function(String batchId);
typedef StatementImportCanceller = Future<void> Function(String batchId);

class StatementImportScreen extends StatefulWidget {
  const StatementImportScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.pickOverride,
    this.bootstrapOverride,
    this.stageOverride,
    this.rowsLoaderOverride,
    this.updateOverride,
    this.confirmOverride,
    this.cancelOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  @visibleForTesting
  final StatementImportPicker? pickOverride;
  @visibleForTesting
  final StatementImportBootstrapLoader? bootstrapOverride;
  @visibleForTesting
  final StatementImportStager? stageOverride;
  @visibleForTesting
  final StatementImportRowsLoader? rowsLoaderOverride;
  @visibleForTesting
  final StatementImportRowsUpdater? updateOverride;
  @visibleForTesting
  final StatementImportConfirmer? confirmOverride;
  @visibleForTesting
  final StatementImportCanceller? cancelOverride;

  @override
  State<StatementImportScreen> createState() => _StatementImportScreenState();
}

enum _ImportStep { file, destination, mapping, review, result }
enum _ReviewFilter { all, selected, duplicates, pending, errors }

class _StatementImportScreenState extends State<StatementImportScreen> {
  _ImportStep _step = _ImportStep.file;
  bool _loading = false;
  bool _bootstrapping = true;
  String? _error;

  StatementImportPickedFile? _file;
  StatementImportFileType? _fileType;
  CsvImportDocument? _csv;
  CsvImportMapping? _mapping;
  StatementImportSourceKind _sourceKind = StatementImportSourceKind.account;
  String? _sourceId;
  String? _sourceInstitution;
  String? _batchId;
  List<StatementImportRow> _rows = const <StatementImportRow>[];
  StatementImportResult? _result;

  List<AccountItem> _paymentAccounts = const <AccountItem>[];
  List<AccountItem> _benefitAccounts = const <AccountItem>[];
  List<CreditCardItem> _cards = const <CreditCardItem>[];
  List<CategoryItem> _expenseCategories = const <CategoryItem>[];
  List<CategoryItem> _incomeCategories = const <CategoryItem>[];
  List<StatementImportInvoiceOption> _invoices = const <StatementImportInvoiceOption>[];

  _ReviewFilter _reviewFilter = _ReviewFilter.all;
  final TextEditingController _search = TextEditingController();
  String? _bulkCategoryId;

  @override
  void initState() {
    super.initState();
    _loadBootstrap();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _loadBootstrap() async {
    try {
      final override = widget.bootstrapOverride;
      final data = override != null ? await override() : await _defaultBootstrap();
      if (!mounted) return;
      setState(() {
        _paymentAccounts = data.paymentAccounts;
        _benefitAccounts = data.benefitAccounts;
        _cards = data.cards;
        _expenseCategories = data.expenseCategories;
        _incomeCategories = data.incomeCategories;
        _invoices = data.invoices;
        _bootstrapping = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _bootstrapping = false;
        _error = 'não consegui carregar contas, cartões e categorias';
      });
    }
  }

  Future<StatementImportBootstrap> _defaultBootstrap() async {
    final values = await Future.wait<dynamic>([
      widget.repository.listPaymentAccounts(widget.spaceId),
      widget.repository.listBenefitAccounts(widget.spaceId),
      widget.repository.listActiveCreditCards(widget.spaceId),
      widget.repository.listExpenseCategoryCatalog(widget.spaceId),
      widget.repository.listIncomeCategoryCatalog(widget.spaceId),
      widget.repository.listStatementImportInvoices(widget.spaceId),
    ]);
    return StatementImportBootstrap(
      paymentAccounts: values[0] as List<AccountItem>,
      benefitAccounts: values[1] as List<AccountItem>,
      cards: values[2] as List<CreditCardItem>,
      expenseCategories: values[3] as List<CategoryItem>,
      incomeCategories: values[4] as List<CategoryItem>,
      invoices: values[5] as List<StatementImportInvoiceOption>,
    );
  }

  Future<void> _pickFile() async {
    if (_loading) return;
    setState(() { _loading = true; _error = null; });
    try {
      final override = widget.pickOverride;
      StatementImportPickedFile? picked;
      if (override != null) {
        picked = await override();
      } else {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: const <String>['csv', 'ofx'],
          allowMultiple: false,
          withData: true,
        );
        if (result != null && result.files.isNotEmpty) {
          final platformFile = result.files.single;
          final bytes = platformFile.bytes;
          if (bytes == null) {
            throw const StatementImportParseException('não consegui ler esse arquivo neste dispositivo');
          }
          picked = StatementImportPickedFile(name: platformFile.name, bytes: bytes);
        }
      }
      if (picked == null) return;
      if (picked.bytes.length > statementImportMaxBytes) {
        throw const StatementImportParseException('o arquivo é grande demais; use até 4 MB e 2.000 lançamentos por lote');
      }
      final extension = picked.name.split('.').last.toLowerCase();
      if (extension != 'csv' && extension != 'ofx') {
        throw const StatementImportParseException('selecione um arquivo .csv ou .ofx');
      }
      final type = extension == 'ofx' ? StatementImportFileType.ofx : StatementImportFileType.csv;
      CsvImportDocument? csv;
      if (type == StatementImportFileType.csv) csv = parseCsvImport(picked.bytes);
      if (!mounted) return;
      setState(() {
        _file = picked;
        _fileType = type;
        _csv = csv;
        _mapping = csv?.suggestedMapping;
        _sourceId = null;
        _sourceInstitution = null;
        _step = _ImportStep.destination;
      });
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Object> get _sourceOptions => switch (_sourceKind) {
        StatementImportSourceKind.account => _paymentAccounts,
        StatementImportSourceKind.card => _cards,
        StatementImportSourceKind.benefit => _benefitAccounts,
      };

  String _sourceName(Object value) => switch (value) {
        AccountItem account => account.name,
        CreditCardItem card => card.name,
        _ => 'instrumento',
      };

  String _sourceIdOf(Object value) => switch (value) {
        AccountItem account => account.id,
        CreditCardItem card => card.id,
        _ => '',
      };

  void _changeSourceKind(StatementImportSourceKind value) {
    setState(() {
      _sourceKind = value;
      _sourceId = null;
      _sourceInstitution = null;
      _error = null;
    });
  }

  Future<void> _continueFromDestination() async {
    if (_sourceId == null) {
      setState(() => _error = 'selecione a conta, cartão ou benefício de destino');
      return;
    }
    if (_fileType == StatementImportFileType.csv) {
      setState(() { _step = _ImportStep.mapping; _error = null; });
      return;
    }
    await _stageOfx();
  }

  Future<void> _stageOfx() async {
    final file = _file;
    if (file == null) return;
    try {
      final doc = parseOfxImport(file.bytes, _sourceKind);
      _sourceInstitution = doc.bankId;
      await _stageCandidates(
        doc.candidates,
        configuration: <String, dynamic>{
          'ofx_currency': doc.currency,
          'ofx_bank_id': doc.bankId,
          'ofx_account_id': doc.accountId,
          'ofx_account_type': doc.accountType,
          'ofx_statement_start': doc.statementStart?.toIso8601String(),
          'ofx_statement_end': doc.statementEnd?.toIso8601String(),
          'ofx_credit_card_statement': doc.isCreditCardStatement,
        }..removeWhere((_, value) => value == null),
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    }
  }

  Future<void> _stageCsv() async {
    final csv = _csv;
    final mapping = _mapping;
    if (csv == null || mapping == null || !mapping.isComplete) {
      setState(() => _error = 'mapeie data, descrição e valor antes de continuar');
      return;
    }
    try {
      final candidates = csv.buildCandidates(mapping: mapping, sourceKind: _sourceKind);
      await _stageCandidates(
        candidates,
        configuration: <String, dynamic>{
          'delimiter': csv.delimiter == '\t' ? 'tab' : csv.delimiter,
          'has_header': csv.hasHeader,
          'encoding': csv.encoding,
          'mapping': mapping.toJson(),
        },
      );
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    }
  }

  Future<void> _stageCandidates(
    List<StatementImportCandidate> candidates, {
    required Map<String, dynamic> configuration,
  }) async {
    if (_loading || _file == null || _sourceId == null || _fileType == null) return;
    setState(() { _loading = true; _error = null; });
    try {
      final sourceAccountId = _sourceKind == StatementImportSourceKind.card ? null : _sourceId;
      final sourceCardId = _sourceKind == StatementImportSourceKind.card ? _sourceId : null;
      final override = widget.stageOverride;
      final batchId = override != null
          ? await override(
              fileType: _fileType!, sourceKind: _sourceKind,
              sourceAccountId: sourceAccountId, sourceCardId: sourceCardId,
              sourceInstitution: _sourceInstitution,
              fingerprint: statementFileFingerprint(_file!.bytes),
              configuration: configuration, candidates: candidates,
            )
          : await widget.repository.stageStatementImport(
              spaceId: widget.spaceId, filename: _file!.name,
              fileType: _fileType!, sourceKind: _sourceKind,
              sourceAccountId: sourceAccountId, sourceCardId: sourceCardId,
              sourceInstitution: _sourceInstitution,
              fileFingerprint: statementFileFingerprint(_file!.bytes),
              configuration: configuration, candidates: candidates,
            );
      final rows = await _loadRows(batchId);
      if (!mounted) return;
      setState(() { _batchId = batchId; _rows = rows; _step = _ImportStep.review; });
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<List<StatementImportRow>> _loadRows(String batchId) {
    final override = widget.rowsLoaderOverride;
    if (override != null) return override(batchId);
    return widget.repository.listStatementImportRows(spaceId: widget.spaceId, batchId: batchId);
  }

  void _replaceRow(StatementImportRow value) {
    setState(() {
      _rows = _rows.map((row) => row.id == value.id ? value : row).toList(growable: false);
    });
  }

  Future<void> _openCategoryManagement(String kind) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CategoryManagementScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          initialKind: kind,
          returnCreated: true,
        ),
      ),
    );
    if (widget.bootstrapOverride == null) {
      try {
        final expense = await widget.repository.listExpenseCategoryCatalog(widget.spaceId);
        final income = await widget.repository.listIncomeCategoryCatalog(widget.spaceId);
        if (mounted) setState(() { _expenseCategories = expense; _incomeCategories = income; });
      } catch (_) {}
    }
  }

  String? _validationError(StatementImportRow row) {
    if (!row.selected) return null;
    if (row.finalType == null) return 'escolha o tipo financeiro';
    if (row.finalType == StatementImportFinalType.transfer && row.counterpartAccountId == null) {
      return 'transferência exige a outra conta';
    }
    if (row.finalType == StatementImportFinalType.cardPayment && row.invoiceId == null) {
      return 'pagamento de cartão exige uma fatura';
    }
    if (row.finalType == StatementImportFinalType.cardPayment &&
        _sourceKind == StatementImportSourceKind.card && row.counterpartAccountId == null) {
      return 'selecione a conta que pagou a fatura';
    }
    return null;
  }

  Future<void> _confirmImport() async {
    if (_loading || _batchId == null) return;
    final invalid = _rows.where((row) => _validationError(row) != null).toList();
    if (invalid.isNotEmpty) {
      setState(() { _reviewFilter = _ReviewFilter.pending; _error = '${invalid.length} item(ns) selecionado(s) ainda precisam de revisão'; });
      return;
    }
    final included = _rows.where((row) => row.selected).toList();
    if (included.isEmpty) {
      setState(() => _error = 'selecione pelo menos um lançamento para importar');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final update = widget.updateOverride;
      if (update != null) {
        await update(_batchId!, _rows);
      } else {
        await widget.repository.updateStatementImportRows(spaceId: widget.spaceId, batchId: _batchId!, rows: _rows);
      }
      final confirm = widget.confirmOverride;
      final result = confirm != null
          ? await confirm(_batchId!)
          : await widget.repository.confirmStatementImport(spaceId: widget.spaceId, batchId: _batchId!);
      final refreshed = await _loadRows(_batchId!);
      if (!mounted) return;
      setState(() { _result = result; _rows = refreshed; _step = _ImportStep.result; });
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _cancelImport() async {
    final batchId = _batchId;
    if (batchId == null) { Navigator.of(context).pop(false); return; }
    if (_rows.any((row) => row.status == StatementImportRowStatus.imported)) {
      setState(() => _error = 'parte deste lote já virou histórico financeiro e não pode ser apagada em massa');
      return;
    }
    try {
      final cancel = widget.cancelOverride;
      if (cancel != null) {
        await cancel(batchId);
      } else {
        await widget.repository.cancelStatementImport(spaceId: widget.spaceId, batchId: batchId);
      }
      if (mounted) Navigator.of(context).pop(false);
    } catch (error) {
      if (mounted) setState(() => _error = _friendly(error));
    }
  }

  List<StatementImportRow> get _visibleRows {
    final query = _search.text.trim().toLowerCase();
    return _rows.where((row) {
      if (query.isNotEmpty && !'${row.description} ${row.merchant ?? ''}'.toLowerCase().contains(query)) return false;
      return switch (_reviewFilter) {
        _ReviewFilter.all => true,
        _ReviewFilter.selected => row.selected,
        _ReviewFilter.duplicates => row.duplicateState != StatementImportDuplicateState.unique,
        _ReviewFilter.pending => row.needsReview || _validationError(row) != null,
        _ReviewFilter.errors => row.status == StatementImportRowStatus.error,
      };
    }).toList(growable: false);
  }

  void _applyBulkCategory() {
    final categoryId = _bulkCategoryId;
    if (categoryId == null) return;
    CategoryItem? category;
    for (final item in [..._expenseCategories, ..._incomeCategories]) {
      if (item.id == categoryId) { category = item; break; }
    }
    if (category == null) return;
    setState(() {
      _rows = _rows.map((row) {
        if (!row.selected) return row;
        final kind = _categoryKind(row.finalType);
        return kind == category!.kind ? row.copyWith(categoryId: categoryId) : row;
      }).toList(growable: false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final size = AppBreakpoints.of(context);
    final desktop = size == AppLayoutSize.expanded || size == AppLayoutSize.wide;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(
        title: const Text('importar extrato'),
        actions: [if (_step != _ImportStep.result) TextButton(onPressed: _loading ? null : _cancelImport, child: const Text('cancelar'))],
      ),
      body: AppContentContainer(
        maxWidth: desktop ? AppContentWidths.dashboard : AppContentWidths.form,
        child: _bootstrapping
            ? const Center(child: CircularProgressIndicator())
            : Column(children: [
                _StepHeader(step: _step, fileType: _fileType),
                if (_error != null) ...[const SizedBox(height: 10), _MessageBox(text: _error!, error: true)],
                const SizedBox(height: 12),
                Expanded(child: _body(desktop)),
              ]),
      ),
    );
  }

  Widget _body(bool desktop) => switch (_step) {
        _ImportStep.file => _fileStep(),
        _ImportStep.destination => _destinationStep(),
        _ImportStep.mapping => _mappingStep(),
        _ImportStep.review => _reviewStep(desktop),
        _ImportStep.result => _resultStep(),
      };

  Widget _fileStep() => ListView(
        padding: const EdgeInsets.fromLTRB(0, 18, 0, 32),
        children: [
          const _IntroCard(icon: AppIcons.transactions, title: 'traga seu extrato com revisão', text: 'CSV e OFX passam por preview, deduplicação e revisão antes de qualquer lançamento financeiro.'),
          const SizedBox(height: 18),
          FilledButton.icon(key: const ValueKey('statement-import-pick-file'), onPressed: _loading ? null : _pickFile, icon: const Icon(AppIcons.add), label: Text(_loading ? 'lendo arquivo…' : 'selecionar CSV ou OFX')),
          const SizedBox(height: 10),
          const Text('limite: 4 MB e até 2.000 lançamentos por lote. o arquivo original não é enviado nem armazenado.', textAlign: TextAlign.center),
        ],
      );

  Widget _destinationStep() {
    final file = _file!;
    return ListView(padding: const EdgeInsets.fromLTRB(0, 12, 0, 32), children: [
      _IntroCard(icon: AppIcons.receipt, title: file.name, text: _fileType == StatementImportFileType.csv ? 'CSV detectado${_csv == null ? '' : ' · ${_csv!.encoding} · separador ${_csv!.delimiter == '\t' ? 'tab' : _csv!.delimiter}'}' : 'OFX detectado'),
      const SizedBox(height: 16),
      SegmentedButton<StatementImportSourceKind>(
        key: const ValueKey('statement-import-source-kind'),
        segments: const [
          ButtonSegment(value: StatementImportSourceKind.account, label: Text('conta'), icon: Icon(AppIcons.account)),
          ButtonSegment(value: StatementImportSourceKind.card, label: Text('cartão'), icon: Icon(AppIcons.creditCard)),
          ButtonSegment(value: StatementImportSourceKind.benefit, label: Text('benefício'), icon: Icon(AppIcons.benefit)),
        ],
        selected: <StatementImportSourceKind>{_sourceKind},
        onSelectionChanged: (value) => _changeSourceKind(value.first),
      ),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(
        key: ValueKey('statement-import-destination-${_sourceKind.name}'),
        initialValue: _sourceId,
        decoration: InputDecoration(labelText: _sourceKind == StatementImportSourceKind.card ? 'cartão de destino' : _sourceKind == StatementImportSourceKind.benefit ? 'benefício de destino' : 'conta de destino'),
        items: _sourceOptions.map((item) => DropdownMenuItem<String>(value: _sourceIdOf(item), child: Text(_sourceName(item)))).toList(growable: false),
        onChanged: (value) => setState(() {
          _sourceId = value;
          if (_sourceKind == StatementImportSourceKind.card && value != null) {
            for (final card in _cards) { if (card.id == value) { _sourceInstitution = card.issuer; break; } }
          }
        }),
      ),
      if (_sourceOptions.isEmpty) ...[const SizedBox(height: 12), const _MessageBox(text: 'não há instrumento ativo desse tipo. crie ou reative um na Carteira antes de importar.', error: false)],
      const SizedBox(height: 24),
      FilledButton.icon(key: const ValueKey('statement-import-destination-continue'), onPressed: _loading || _sourceOptions.isEmpty ? null : _continueFromDestination, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(AppIcons.forward), label: Text(_fileType == StatementImportFileType.csv ? 'mapear colunas' : 'revisar lançamentos')),
      TextButton(onPressed: _loading ? null : () => setState(() => _step = _ImportStep.file), child: const Text('escolher outro arquivo')),
    ]);
  }

  Widget _mappingStep() {
    final csv = _csv!;
    final mapping = _mapping ?? csv.suggestedMapping;
    return ListView(key: const ValueKey('statement-import-csv-mapping'), padding: const EdgeInsets.fromLTRB(0, 6, 0, 32), children: [
      const _IntroCard(icon: AppIcons.settings, title: 'como esse CSV está organizado?', text: 'confira o mapeamento. abaixo de cada campo mostramos valores reais do arquivo antes de criar o staging.'),
      const SizedBox(height: 14),
      _ColumnMappingField(label: 'data *', value: mapping.dateColumn, headers: csv.headers, examples: csv.examplesFor(mapping.dateColumn), onChanged: (value) => setState(() => _mapping = mapping.copyWith(dateColumn: value))),
      _ColumnMappingField(label: 'descrição *', value: mapping.descriptionColumn, headers: csv.headers, examples: csv.examplesFor(mapping.descriptionColumn), onChanged: (value) => setState(() => _mapping = mapping.copyWith(descriptionColumn: value))),
      _ColumnMappingField(label: 'valor', value: mapping.amountColumn, headers: csv.headers, examples: csv.examplesFor(mapping.amountColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearAmount: true) : mapping.copyWith(amountColumn: value))),
      Row(children: [
        Expanded(child: _ColumnMappingField(label: 'débito', value: mapping.debitColumn, headers: csv.headers, examples: csv.examplesFor(mapping.debitColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearDebit: true) : mapping.copyWith(debitColumn: value)))),
        const SizedBox(width: 10),
        Expanded(child: _ColumnMappingField(label: 'crédito', value: mapping.creditColumn, headers: csv.headers, examples: csv.examplesFor(mapping.creditColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearCredit: true) : mapping.copyWith(creditColumn: value)))),
      ]),
      const SizedBox(height: 6),
      Row(children: [
        Expanded(child: DropdownButtonFormField<CsvDecimalFormat>(initialValue: mapping.decimalFormat, decoration: const InputDecoration(labelText: 'formato decimal'), items: const [DropdownMenuItem(value: CsvDecimalFormat.auto, child: Text('detectar')), DropdownMenuItem(value: CsvDecimalFormat.brazilian, child: Text('1.234,56')), DropdownMenuItem(value: CsvDecimalFormat.american, child: Text('1,234.56'))], onChanged: (value) => setState(() => _mapping = mapping.copyWith(decimalFormat: value)))),
        const SizedBox(width: 10),
        Expanded(child: DropdownButtonFormField<CsvDateFormat>(initialValue: mapping.dateFormat, decoration: const InputDecoration(labelText: 'formato de data'), items: const [DropdownMenuItem(value: CsvDateFormat.auto, child: Text('detectar')), DropdownMenuItem(value: CsvDateFormat.dmy, child: Text('DD/MM/AAAA')), DropdownMenuItem(value: CsvDateFormat.mdy, child: Text('MM/DD/AAAA')), DropdownMenuItem(value: CsvDateFormat.iso, child: Text('AAAA-MM-DD'))], onChanged: (value) => setState(() => _mapping = mapping.copyWith(dateFormat: value)))),
      ]),
      const SizedBox(height: 12),
      ExpansionTile(title: const Text('campos opcionais'), children: [
        _ColumnMappingField(label: 'estabelecimento', value: mapping.merchantColumn, headers: csv.headers, examples: csv.examplesFor(mapping.merchantColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearMerchant: true) : mapping.copyWith(merchantColumn: value))),
        _ColumnMappingField(label: 'categoria do arquivo', value: mapping.categoryColumn, headers: csv.headers, examples: csv.examplesFor(mapping.categoryColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearCategory: true) : mapping.copyWith(categoryColumn: value))),
        _ColumnMappingField(label: 'id externo / FITID', value: mapping.externalIdColumn, headers: csv.headers, examples: csv.examplesFor(mapping.externalIdColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearExternalId: true) : mapping.copyWith(externalIdColumn: value))),
        _ColumnMappingField(label: 'documento', value: mapping.documentColumn, headers: csv.headers, examples: csv.examplesFor(mapping.documentColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearDocument: true) : mapping.copyWith(documentColumn: value))),
        _ColumnMappingField(label: 'saldo após lançamento', value: mapping.balanceColumn, headers: csv.headers, examples: csv.examplesFor(mapping.balanceColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearBalance: true) : mapping.copyWith(balanceColumn: value))),
        _ColumnMappingField(label: 'tipo do arquivo', value: mapping.typeColumn, headers: csv.headers, examples: csv.examplesFor(mapping.typeColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearType: true) : mapping.copyWith(typeColumn: value))),
        _ColumnMappingField(label: 'observação', value: mapping.noteColumn, headers: csv.headers, examples: csv.examplesFor(mapping.noteColumn), optional: true, onChanged: (value) => setState(() => _mapping = value == null ? mapping.copyWith(clearNote: true) : mapping.copyWith(noteColumn: value))),
      ]),
      const SizedBox(height: 18),
      FilledButton.icon(key: const ValueKey('statement-import-stage-csv'), onPressed: _loading ? null : _stageCsv, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(AppIcons.forward), label: const Text('gerar preview para revisão')),
    ]);
  }

  Widget _reviewStep(bool desktop) {
    final rows = _visibleRows;
    final selectedCount = _rows.where((row) => row.selected).length;
    final duplicateCount = _rows.where((row) => row.duplicateState != StatementImportDuplicateState.unique).length;
    return Column(key: ValueKey(desktop ? 'statement-import-review-desktop' : 'statement-import-review-mobile'), children: [
      Wrap(spacing: 8, runSpacing: 8, children: [_MetricChip(label: '${_rows.length} linhas'), _MetricChip(label: '$selectedCount selecionadas'), _MetricChip(label: '$duplicateCount duplicadas/possíveis')]),
      const SizedBox(height: 10),
      TextField(controller: _search, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(AppIcons.search), labelText: 'buscar neste lote')),
      const SizedBox(height: 10),
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: SegmentedButton<_ReviewFilter>(segments: const [
        ButtonSegment(value: _ReviewFilter.all, label: Text('todos')),
        ButtonSegment(value: _ReviewFilter.selected, label: Text('selecionados')),
        ButtonSegment(value: _ReviewFilter.duplicates, label: Text('duplicados')),
        ButtonSegment(value: _ReviewFilter.pending, label: Text('pendentes')),
        ButtonSegment(value: _ReviewFilter.errors, label: Text('com erro')),
      ], selected: <_ReviewFilter>{_reviewFilter}, onSelectionChanged: (value) => setState(() => _reviewFilter = value.first))),
      const SizedBox(height: 10),
      _BulkBar(categories: _expenseCategories, selectedCategoryId: _bulkCategoryId, onChanged: (value) => setState(() => _bulkCategoryId = value), onApply: _applyBulkCategory, onIncludeAll: () => setState(() => _rows = _rows.map((row) => row.copyWith(decision: row.duplicateState == StatementImportDuplicateState.exactDuplicate || row.duplicateState == StatementImportDuplicateState.alreadyImported ? StatementImportDecision.ignore : StatementImportDecision.include)).toList(growable: false)), onIgnoreSelected: () => setState(() => _rows = _rows.map((row) => row.selected ? row.copyWith(decision: StatementImportDecision.ignore) : row).toList(growable: false))),
      const SizedBox(height: 10),
      Expanded(child: rows.isEmpty ? const Center(child: Text('nenhuma linha neste filtro')) : ListView.separated(key: const ValueKey('statement-import-review-list'), itemCount: rows.length, separatorBuilder: (_, _) => const SizedBox(height: 8), itemBuilder: (_, index) => _ReviewRowCard(row: rows[index], desktop: desktop, sourceKind: _sourceKind, sourceId: _sourceId, paymentAccounts: _paymentAccounts, invoices: _invoices, expenseCategories: _expenseCategories, incomeCategories: _incomeCategories, validationError: _validationError(rows[index]), onChanged: _replaceRow, onCategoryManagement: _openCategoryManagement))),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: OutlinedButton(onPressed: _loading ? null : _cancelImport, child: const Text('cancelar importação'))),
        const SizedBox(width: 10),
        Expanded(child: FilledButton.icon(key: const ValueKey('statement-import-confirm'), onPressed: _loading ? null : _confirmImport, icon: _loading ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(AppIcons.check), label: const Text('confirmar importação'))),
      ]),
      const SizedBox(height: 12),
    ]);
  }

  Widget _resultStep() {
    final result = _result!;
    return ListView(key: const ValueKey('statement-import-result'), padding: const EdgeInsets.fromLTRB(0, 20, 0, 32), children: [
      _IntroCard(icon: result.errors == 0 ? AppIcons.check : AppIcons.warning, title: result.completed ? 'importação concluída' : 'importação parcial', text: 'cada linha foi processada de forma independente; falhas não deixam eventos financeiros incompletos.'),
      const SizedBox(height: 18),
      Wrap(spacing: 10, runSpacing: 10, children: [_ResultMetric(value: result.imported, label: 'importados'), _ResultMetric(value: result.duplicates, label: 'duplicados'), _ResultMetric(value: result.ignored, label: 'ignorados'), _ResultMetric(value: result.errors, label: 'com erro'), if (result.pending > 0) _ResultMetric(value: result.pending, label: 'pendentes')]),
      const SizedBox(height: 22),
      FilledButton.icon(key: const ValueKey('statement-import-view-transactions'), onPressed: () => Navigator.of(context).pop(true), icon: const Icon(AppIcons.transactions), label: const Text('ver lançamentos')),
      if (!result.completed) ...[const SizedBox(height: 10), OutlinedButton(onPressed: () => setState(() => _step = _ImportStep.review), child: const Text('revisar o que faltou'))],
    ]);
  }
}

class _ReviewRowCard extends StatelessWidget {
  const _ReviewRowCard({required this.row, required this.desktop, required this.sourceKind, required this.sourceId, required this.paymentAccounts, required this.invoices, required this.expenseCategories, required this.incomeCategories, required this.validationError, required this.onChanged, required this.onCategoryManagement});
  final StatementImportRow row;
  final bool desktop;
  final StatementImportSourceKind sourceKind;
  final String? sourceId;
  final List<AccountItem> paymentAccounts;
  final List<StatementImportInvoiceOption> invoices;
  final List<CategoryItem> expenseCategories;
  final List<CategoryItem> incomeCategories;
  final String? validationError;
  final ValueChanged<StatementImportRow> onChanged;
  final Future<void> Function(String kind) onCategoryManagement;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final kind = _categoryKind(row.finalType);
    final categories = kind == 'income' ? incomeCategories : kind == 'expense' ? expenseCategories : const <CategoryItem>[];
    final typeOptions = _allowedTypes(sourceKind);
    final duplicate = _duplicateLabel(row.duplicateState);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: AppColors.surface(brightness), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border(brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Checkbox(key: ValueKey('statement-import-include-${row.id}'), value: row.selected, onChanged: (value) => onChanged(row.copyWith(decision: value == true ? StatementImportDecision.include : StatementImportDecision.ignore))),
          if (desktop) SizedBox(width: 88, child: Text(_date(row.occurredAt))),
          Expanded(flex: 3, child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(row.description, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppTypography.body(context, fontWeight: FontWeight.w700)),
            if (!desktop) Text(_date(row.occurredAt), style: AppTypography.label(context, fontSize: 9)),
            if (row.merchant != null) Text(row.merchant!, style: AppTypography.label(context, fontSize: 9)),
            if (duplicate != null) Padding(padding: const EdgeInsets.only(top: 4), child: _DuplicateBadge(state: row.duplicateState, text: duplicate)),
            if (row.reason?.trim().isNotEmpty == true) Padding(padding: const EdgeInsets.only(top: 3), child: Text(row.reason!, style: AppTypography.label(context, fontSize: 8, color: AppColors.secondaryText(brightness)))),
          ])),
          Text(Formatters.money(row.amount.abs()), textAlign: TextAlign.end, style: AppTypography.money(context, fontSize: desktop ? 13 : 16)),
        ]),
        const SizedBox(height: 10),
        Wrap(spacing: 10, runSpacing: 10, children: [
          SizedBox(width: desktop ? 210 : 180, child: DropdownButtonFormField<StatementImportFinalType>(initialValue: row.finalType, decoration: const InputDecoration(labelText: 'tipo'), items: typeOptions.map((type) => DropdownMenuItem(value: type, child: Text(_typeLabel(type)))).toList(growable: false), onChanged: (value) => onChanged(row.copyWith(finalType: value, clearFinalType: value == null, clearCategory: _categoryKind(value) == null, clearCounterpart: value != StatementImportFinalType.transfer && value != StatementImportFinalType.cardPayment, clearInvoice: value != StatementImportFinalType.cardPayment)))),
          if (kind != null) SizedBox(width: desktop ? 280 : 240, child: DropdownButtonFormField<String>(initialValue: categories.any((item) => item.id == row.categoryId) ? row.categoryId : null, decoration: const InputDecoration(labelText: 'categoria'), items: [const DropdownMenuItem<String>(value: '', child: Text('sem categoria')), ...categories.map((category) { final visual = CategoryVisuals.resolve(brightness: brightness, category: category.parentName ?? category.name, subcategory: category.parentName == null ? null : category.name, colorHex: category.colorHex, iconKey: category.iconKey, systemKey: category.systemKey); return DropdownMenuItem<String>(value: category.id, child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(visual.icon, size: 16, color: visual.color), const SizedBox(width: 6), Flexible(child: Text(category.breadcrumb, overflow: TextOverflow.ellipsis))])); })], onChanged: (value) => onChanged(value == null || value.isEmpty ? row.copyWith(clearCategory: true) : row.copyWith(categoryId: value)))),
          if (row.finalType == StatementImportFinalType.transfer) SizedBox(width: desktop ? 260 : 240, child: DropdownButtonFormField<String>(initialValue: paymentAccounts.any((item) => item.id == row.counterpartAccountId) ? row.counterpartAccountId : null, decoration: const InputDecoration(labelText: 'outra conta'), items: paymentAccounts.where((account) => account.id != sourceId).map((account) => DropdownMenuItem(value: account.id, child: Text(account.name))).toList(growable: false), onChanged: (value) => onChanged(value == null ? row.copyWith(clearCounterpart: true) : row.copyWith(counterpartAccountId: value)))),
          if (row.finalType == StatementImportFinalType.cardPayment) ...[
            if (sourceKind == StatementImportSourceKind.card) SizedBox(width: desktop ? 260 : 240, child: DropdownButtonFormField<String>(initialValue: paymentAccounts.any((item) => item.id == row.counterpartAccountId) ? row.counterpartAccountId : null, decoration: const InputDecoration(labelText: 'conta pagadora'), items: paymentAccounts.map((account) => DropdownMenuItem(value: account.id, child: Text(account.name))).toList(growable: false), onChanged: (value) => onChanged(value == null ? row.copyWith(clearCounterpart: true) : row.copyWith(counterpartAccountId: value)))),
            SizedBox(width: desktop ? 300 : 260, child: DropdownButtonFormField<String>(initialValue: invoices.any((item) => item.id == row.invoiceId) ? row.invoiceId : null, decoration: const InputDecoration(labelText: 'fatura relacionada'), items: invoices.where((invoice) => sourceKind != StatementImportSourceKind.card || invoice.cardId == sourceId).map((invoice) => DropdownMenuItem(value: invoice.id, child: Text('${invoice.cardName} · ${invoice.dueDate == null ? 'sem vencimento' : _date(invoice.dueDate!)}'))).toList(growable: false), onChanged: (value) => onChanged(value == null ? row.copyWith(clearInvoice: true) : row.copyWith(invoiceId: value)))),
          ],
          if (kind != null) TextButton.icon(onPressed: () => onCategoryManagement(kind), icon: const Icon(AppIcons.add, size: 16), label: const Text('criar categoria')),
        ]),
        if (row.status == StatementImportRowStatus.error && row.errorText != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_friendlyServerError(row.errorText!), style: TextStyle(color: AppColors.expenseText(brightness)))),
        if (validationError != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(validationError!, style: TextStyle(color: AppColors.expenseText(brightness), fontWeight: FontWeight.w600))),
      ]),
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({required this.step, required this.fileType});
  final _ImportStep step;
  final StatementImportFileType? fileType;
  @override
  Widget build(BuildContext context) {
    final labels = <String>['arquivo', 'destino', if (fileType != StatementImportFileType.ofx) 'mapeamento', 'revisar', 'resultado'];
    final current = switch (step) { _ImportStep.file => 0, _ImportStep.destination => 1, _ImportStep.mapping => 2, _ImportStep.review => fileType == StatementImportFileType.ofx ? 2 : 3, _ImportStep.result => fileType == StatementImportFileType.ofx ? 3 : 4 };
    return Wrap(spacing: 6, runSpacing: 6, children: List.generate(labels.length, (index) => Chip(label: Text('${index + 1}. ${labels[index]}'), avatar: index < current ? const Icon(AppIcons.check, size: 15) : null, side: BorderSide.none, backgroundColor: index == current ? Theme.of(context).colorScheme.primaryContainer : null)));
  }
}

class _ColumnMappingField extends StatelessWidget {
  const _ColumnMappingField({required this.label, required this.value, required this.headers, required this.examples, required this.onChanged, this.optional = false});
  final String label;
  final int? value;
  final List<String> headers;
  final List<String> examples;
  final ValueChanged<int?> onChanged;
  final bool optional;
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(bottom: 10), child: DropdownButtonFormField<int>(initialValue: value, decoration: InputDecoration(labelText: label, helperText: examples.isEmpty ? null : examples.take(3).join('  ·  ')), items: [if (optional) const DropdownMenuItem<int>(value: -1, child: Text('não usar')), ...List.generate(headers.length, (index) => DropdownMenuItem<int>(value: index, child: Text(headers[index], overflow: TextOverflow.ellipsis)))], onChanged: (value) => onChanged(value == -1 ? null : value)));
}

class _BulkBar extends StatelessWidget {
  const _BulkBar({required this.categories, required this.selectedCategoryId, required this.onChanged, required this.onApply, required this.onIncludeAll, required this.onIgnoreSelected});
  final List<CategoryItem> categories;
  final String? selectedCategoryId;
  final ValueChanged<String?> onChanged;
  final VoidCallback onApply;
  final VoidCallback onIncludeAll;
  final VoidCallback onIgnoreSelected;
  @override
  Widget build(BuildContext context) => Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [OutlinedButton.icon(onPressed: onIncludeAll, icon: const Icon(AppIcons.check, size: 16), label: const Text('incluir seguros')), OutlinedButton(onPressed: onIgnoreSelected, child: const Text('ignorar selecionados')), SizedBox(width: 230, child: DropdownButtonFormField<String>(initialValue: selectedCategoryId, decoration: const InputDecoration(labelText: 'categoria em lote'), items: categories.map((item) => DropdownMenuItem(value: item.id, child: Text(item.breadcrumb))).toList(growable: false), onChanged: onChanged)), FilledButton.tonal(onPressed: selectedCategoryId == null ? null : onApply, child: const Text('aplicar aos compatíveis'))]);
}

class _DuplicateBadge extends StatelessWidget {
  const _DuplicateBadge({required this.state, required this.text});
  final StatementImportDuplicateState state;
  final String text;
  @override
  Widget build(BuildContext context) {
    final exact = state == StatementImportDuplicateState.exactDuplicate || state == StatementImportDuplicateState.alreadyImported;
    final color = exact ? Theme.of(context).colorScheme.error : Theme.of(context).colorScheme.tertiary;
    return DecoratedBox(decoration: BoxDecoration(color: color.withValues(alpha: .10), borderRadius: BorderRadius.circular(999)), child: Padding(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3), child: Text(text, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color))));
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({required this.icon, required this.title, required this.text});
  final IconData icon;
  final String title;
  final String text;
  @override
  Widget build(BuildContext context) { final brightness = Theme.of(context).brightness; return Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(color: AppColors.surface(brightness), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border(brightness))), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(icon, size: 24), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.section(context, fontSize: 17)), const SizedBox(height: 4), Text(text, style: AppTypography.body(context, fontSize: 11, color: AppColors.secondaryText(brightness)))]))])); }
}

class _MessageBox extends StatelessWidget {
  const _MessageBox({required this.text, required this.error});
  final String text;
  final bool error;
  @override
  Widget build(BuildContext context) { final brightness = Theme.of(context).brightness; final color = error ? AppColors.expenseText(brightness) : AppColors.secondaryText(brightness); return Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: color.withValues(alpha: .08), borderRadius: BorderRadius.circular(14)), child: Text(text, style: TextStyle(color: color))); }
}

class _MetricChip extends StatelessWidget { const _MetricChip({required this.label}); final String label; @override Widget build(BuildContext context) => Chip(label: Text(label)); }
class _ResultMetric extends StatelessWidget { const _ResultMetric({required this.value, required this.label}); final int value; final String label; @override Widget build(BuildContext context) { final brightness = Theme.of(context).brightness; return Container(width: 150, padding: const EdgeInsets.all(16), decoration: BoxDecoration(color: AppColors.surface(brightness), borderRadius: BorderRadius.circular(18), border: Border.all(color: AppColors.border(brightness))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('$value', style: AppTypography.money(context, fontSize: 26)), Text(label, style: AppTypography.label(context, fontSize: 9))])); } }

List<StatementImportFinalType> _allowedTypes(StatementImportSourceKind kind) => switch (kind) { StatementImportSourceKind.account => const [StatementImportFinalType.expense, StatementImportFinalType.income, StatementImportFinalType.transfer, StatementImportFinalType.cardPayment], StatementImportSourceKind.card => const [StatementImportFinalType.cardPurchase, StatementImportFinalType.cardPayment], StatementImportSourceKind.benefit => const [StatementImportFinalType.benefitExpense, StatementImportFinalType.benefitCredit] };
String? _categoryKind(StatementImportFinalType? type) => switch (type) { StatementImportFinalType.income || StatementImportFinalType.benefitCredit => 'income', StatementImportFinalType.expense || StatementImportFinalType.cardPurchase || StatementImportFinalType.benefitExpense => 'expense', _ => null };
String _typeLabel(StatementImportFinalType type) => switch (type) { StatementImportFinalType.expense => 'despesa', StatementImportFinalType.income => 'receita', StatementImportFinalType.cardPurchase => 'compra no cartão', StatementImportFinalType.benefitExpense => 'gasto de benefício', StatementImportFinalType.benefitCredit => 'crédito de benefício', StatementImportFinalType.transfer => 'transferência', StatementImportFinalType.cardPayment => 'pagamento de fatura' };
String? _duplicateLabel(StatementImportDuplicateState state) => switch (state) { StatementImportDuplicateState.exactDuplicate => 'duplicata exata · ignorada por padrão', StatementImportDuplicateState.alreadyImported => 'já importado · ignorado por padrão', StatementImportDuplicateState.possibleDuplicate => 'possível duplicata · revisar', StatementImportDuplicateState.unique => null };
String _date(DateTime value) => '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
String _friendly(Object error) { if (error is StatementImportParseException) return error.message; return _friendlyServerError(error.toString().replaceFirst('Exception: ', '')); }
String _friendlyServerError(String value) { if (value.contains('import_row_limit_exceeded')) return 'o arquivo ultrapassa o limite de 2.000 linhas'; if (value.contains('import_payload_too_large')) return 'o lote ficou grande demais para processar com segurança'; if (value.contains('invalid_import_source')) return 'a conta/cartão escolhido não é válido para este espaço'; if (value.contains('import_type_requires_review')) return 'alguns itens ainda precisam de um tipo financeiro seguro'; if (value.contains('transfer_requires_counterpart')) return 'transferência precisa da outra conta'; if (value.contains('card_payment_requires_invoice')) return 'pagamento de cartão precisa da fatura relacionada'; if (value.contains('benefit_cannot_pay_card')) return 'benefício não pode ser usado para pagar fatura'; if (value.contains('invalid_category')) return 'uma categoria precisa ser revisada'; return value.replaceAll('PostgrestException(message: ', '').split(', code:').first; }
