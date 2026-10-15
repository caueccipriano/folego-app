import 'package:flutter/material.dart';

import 'classification_review_overview.dart';

import '../../core/entitlements/feature_entitlements.dart';
import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/automation_rule.dart';
import '../../data/models/category_item.dart';
import '../../data/models/transaction_item.dart';
import '../../data/smart_category_suggestion.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_automation.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../../shared/widgets/category_search_picker.dart';
import '../../shared/widgets/app_loading_state.dart';

/// Restrict bulk suggestions to the same account, event type and exact
/// normalized description. Never infer an account from card/benefit entries
/// whose financial impact does not expose a source account.
List<TransactionItem> matchingClassificationCandidates(
  TransactionItem original,
  Iterable<TransactionItem> pending,
) {
  final name = normalizeAutomationText(original.description);
  if (!isSpecificAutomationDescription(name) || original.accountId == null) {
    return const <TransactionItem>[];
  }
  return pending.where((candidate) =>
      candidate.id != original.id &&
      candidate.categoryId == original.categoryId &&
      candidate.eventType == original.eventType &&
      candidate.source == original.source &&
      candidate.accountId == original.accountId &&
      normalizeAutomationText(candidate.description) == name
  ).toList(growable: false);
}

/// Suggest only reviewed exact-description rules. Never classify silently.
CategoryItem? reviewedCategorySuggestion({
  required TransactionItem item,
  required List<AutomationRule> rules,
  required List<CategoryItem> categories,
}) {
  final description = normalizeAutomationText(item.description);
  if (description.length < 4 || isGenericAutomationDescription(description)) return null;
  final kind = transactionClassificationKind(item.eventType);
  if (kind == null) return null;
  final matches = rules.where((rule) {
    if (!rule.active ||
        rule.categoryId == null ||
        rule.matchField != AutomationMatchField.description ||
        rule.matchType != AutomationMatchType.equals ||
        rule.actionType == AutomationActionType.markRecognized ||
        rule.executionMode == AutomationExecutionMode.automatic ||
        normalizeAutomationText(rule.matchValue) != description) {
      return false;
    }
    final debit = kind != 'income';
    if (rule.direction == AutomationDirection.credit && debit) {
      return false;
    }
    if (rule.direction == AutomationDirection.debit && !debit) {
      return false;
    }
    if (rule.sourceScope == AutomationSourceScope.card ||
        rule.sourceScope == AutomationSourceScope.benefit) {
      return false;
    }
    if (rule.sourceScope == AutomationSourceScope.account &&
        (item.accountId == null || rule.sourceAccountId != item.accountId)) {
      return false;
    }
    return true;
  }).toList(growable: false)
    ..sort(compareAutomationRulesForPreview);
  if (matches.isEmpty) return null;
  final chosen = matches.first;
  for (final category in categories) {
    if (category.id == chosen.categoryId) return category;
  }
  return null;
}

bool isGenericAutomationDescription(String normalized) {
  final value = normalizeAutomationText(normalized);
  // Bank-app and CSV exports often use the same generic label for
  // completely different people, purposes and categories.
  const generic = {
    'pix enviada - santander',
    'pix enviado - santander',
    'pix recebida - santander',
    'pix recebido - santander',
    'pix enviado',
    'pix recebida',
    'transferencia',
    'compra cartao',
    'compra no cartao',
    'pagamento pix',
  };
  return generic.contains(value);
}

bool isSpecificAutomationDescription(String normalized) {
  final value = normalizeAutomationText(normalized);
  return value.length >= 10 && !isGenericAutomationDescription(value);
}

/// Very conservative, read-only suggestions learned from *two or more*
/// already categorized events with the same account, source, event type and
/// exact normalized description. Conflicting historical categories reject
/// the suggestion. Does not mutate any transaction.
Map<String, String> historicalCategorySuggestions({
  required Iterable<TransactionItem> pending,
  required Iterable<TransactionItem> history,
  required Iterable<CategoryItem> categories,
}) {
  final allowed = categories
      .where((category) =>
          category.active &&
          category.isSelectable &&
          (category.categoryRole == null ||
              category.categoryRole == 'economic'))
      .map((category) => category.id)
      .toSet();

  final grouped = <String, List<String>>{};
  String? key(TransactionItem item) {
    if ((item.eventType != 'income' && item.eventType != 'expense') ||
        item.accountId == null) {
      return null;
    }
    final description = normalizeAutomationText(item.description);
    if (!isSpecificAutomationDescription(description)) {
      return null;
    }
    return '${item.accountId}|${item.eventType}|${item.source}|$description';
  }

  for (final item in history) {
    if (item.status != 'confirmed' ||
        item.categoryId == null ||
        !allowed.contains(item.categoryId)) {
      continue;
    }
    final k = key(item);
    if (k != null) {
      grouped.putIfAbsent(k, () => []).add(item.categoryId!);
    }
  }

  final suggestions = <String, String>{};
  for (final item in pending) {
    if (item.categoryId != null && allowed.contains(item.categoryId)) {
      continue;
    }
    final k = key(item);
    if (k == null) {
      continue;
    }
    final categoriesSeen = grouped[k] ?? const <String>[];
    if (categoriesSeen.length < 2 ||
        categoriesSeen.any((id) => id != categoriesSeen.first)) {
      continue;
    }
    suggestions[item.id] = categoriesSeen.first;
  }
  return suggestions;
}

/// User-approved, account-scoped automatic rule candidate. Existing data are
/// evidence only; nothing is classified or enabled without consent.
class AutopilotRuleProposal {
  const AutopilotRuleProposal({
    required this.accountId,
    required this.accountName,
    required this.description,
    required this.eventType,
    required this.categoryId,
    required this.categoryName,
    required this.sampleCount,
  });

  final String accountId;
  final String? accountName;
  final String description;
  final String eventType;
  final String categoryId;
  final String categoryName;
  final int sampleCount;
}

List<AutopilotRuleProposal> safeAutopilotRuleProposals({
  required Iterable<TransactionItem> history,
  required Iterable<CategoryItem> categories,
  required Iterable<AutomationRule> existingRules,
}) {
  final allowed = <String, CategoryItem>{
    for (final c in categories)
      if (c.active && c.isSelectable && c.categoryRole == 'economic')
        c.id: c,
  };
  final groups = <String, List<TransactionItem>>{};
  for (final item in history) {
    final category = allowed[item.categoryId];
    final name = normalizeAutomationText(item.description);
    if (item.status != 'confirmed' ||
        item.source != 'sheet-sync' ||
        (item.eventType != 'income' && item.eventType != 'expense') ||
        item.accountId == null ||
        category == null ||
        category.kind != item.eventType ||
        !isSpecificAutomationDescription(name)) {
      continue;
    }
    final key = '${item.accountId}|${item.eventType}|$name';
    groups.putIfAbsent(key, () => []).add(item);
  }

  final proposals = <AutopilotRuleProposal>[];
  for (final rows in groups.values) {
    if (rows.length < 3) {
      continue;
    }
    final first = rows.first;
    if (rows.any((row) => row.categoryId != first.categoryId)) {
      continue;
    }
    final direction = first.eventType == 'income'
        ? AutomationDirection.credit
        : AutomationDirection.debit;
    final normalized = normalizeAutomationText(first.description);
    final existing = existingRules.any((rule) =>
        rule.active &&
        rule.matchField == AutomationMatchField.description &&
        rule.matchType == AutomationMatchType.equals &&
        rule.sourceScope == AutomationSourceScope.account &&
        rule.sourceAccountId == first.accountId &&
        rule.direction == direction &&
        normalizeAutomationText(rule.matchValue) == normalized);
    if (existing) {
      continue;
    }
    proposals.add(AutopilotRuleProposal(
      accountId: first.accountId!,
      accountName: first.accountName,
      description: first.description,
      eventType: first.eventType,
      categoryId: first.categoryId!,
      categoryName: allowed[first.categoryId]!.breadcrumb,
      sampleCount: rows.length,
    ));
  }
  proposals.sort((a,b) {
    final count=b.sampleCount.compareTo(a.sampleCount);
    return count != 0 ? count : a.description.compareTo(b.description);
  });
  return proposals;
}

/// Context for a decision, never a guessed category. Bank push notifications
/// may contain only a generic account label and no counterparty.
String? classificationEvidenceHint(TransactionItem item) {
  if (isGenericAutomationDescription(item.description)) {
    return 'O aviso do banco não identifica quem enviou ou recebeu. '
        'Confira a contraparte no extrato antes de escolher a categoria.';
  }
  if (item.eventType == 'card_purchase' && item.source == 'sheet-sync') {
    return 'Confirme o estabelecimento ou o motivo da compra na fatura. '
        'O nome apresentado pode não identificar o produto ou serviço.';
  }
  return null;
}

class TransactionClassificationInbox extends StatefulWidget {
  const TransactionClassificationInbox({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.initialItems,
    this.batchSize,
  });

  final FolegoRepository repository;
  final String spaceId;
  final List<TransactionItem> initialItems;
  final int? batchSize;

  @override
  State<TransactionClassificationInbox> createState() =>
      _TransactionClassificationInboxState();
}

class _TransactionClassificationInboxState
    extends State<TransactionClassificationInbox> {
  late List<TransactionItem> _items;
  List<CategoryItem> _expenseCategories = const [];
  List<CategoryItem> _incomeCategories = const [];
  List<AutomationRule> _reviewRules = const [];
  List<TransactionItem> _knownHistory = const [];
  bool _applyingSuggestions = false;
  bool _creatingAutomaticRule = false;
  String? _savingEventId;
  bool _loading = true;
  bool _refreshing = false;
  bool _changed = false;
  bool _suggestionsOnly = false;
  int _batchDone = 0;
  int _batchTarget = 0;
  bool get _batchFinished =>
      widget.batchSize != null && _batchDone >= _batchTarget;
  String? _error;

  bool get _automationEnabled =>
      FeatureEntitlementsScope.of(context).entitlements
          .allows(AppCapability.automationRules);

  @override
  void initState() {
    super.initState();
    _items = List<TransactionItem>.from(widget.initialItems);
    _batchTarget = widget.batchSize == null
        ? _items.length
        : (_items.length < widget.batchSize!
              ? _items.length
              : widget.batchSize!);
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listExpenseCategoryCatalog(widget.spaceId),
        widget.repository.listIncomeCategoryCatalog(widget.spaceId),
        widget.repository.listAutomationRules(widget.spaceId)
            .catchError((_) => <AutomationRule>[]),
        widget.repository
            .getTransactionsPage(widget.spaceId, pageSize: 400)
            .then((page) => page.items)
            .catchError((_) => <TransactionItem>[]),
      ]);
      if (!mounted) return;
      setState(() {
        _expenseCategories = _selectable(values[0] as List<CategoryItem>);
        _incomeCategories = _selectable(values[1] as List<CategoryItem>);
        _reviewRules = values[2] as List<AutomationRule>;
        _knownHistory = values[3] as List<TransactionItem>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(error);
      });
    }
  }

  Map<String, String> get _readySuggestions =>
      historicalCategorySuggestions(
        pending: _items,
        history: _knownHistory,
        categories: [..._expenseCategories, ..._incomeCategories],
      );

  Future<void> _applyReviewedSuggestions() async {
    if (_savingEventId != null || _loading || _applyingSuggestions) return;
    final proposed = _readySuggestions;
    if (proposed.isEmpty) return;

    final availableCategories = <String, CategoryItem>{
      for (final item in [..._expenseCategories, ..._incomeCategories])
        item.id: item,
    };
    final proposedLines = _items
        .where((item) => proposed.containsKey(item.id))
        .toList(growable: false);

    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('conferir categorias sugeridas'),
        content: SizedBox(
          width: 450,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Estas sugestões são baseadas em pelo menos duas '
                  'classificações anteriores idênticas na mesma conta. '
                  'Revise antes de aplicar. Nenhum valor será alterado.',
                ),
                const SizedBox(height: 12),
                for (final item in proposedLines.take(15))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      '${item.description} → '
                      '${availableCategories[proposed[item.id]]?.breadcrumb ?? "?"}',
                      maxLines: 3,
                    ),
                  ),
                if (proposedLines.length > 15)
                  Text('e mais ${proposedLines.length - 15} sugestões'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('revisar manualmente'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('confirmar ${proposedLines.length} categoria(s)'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() {
      _applyingSuggestions = true;
      _error = null;
    });

    var applied = 0;
    var failed = false;
    try {
      // Re-read current pending state, avoiding assumptions after another
      // session or a sheet-sync run has updated a row meanwhile.
      final stillPending = await widget.repository
          .listPendingTransactionClassifications(widget.spaceId);
      if (!mounted) return;
      final currentIds = stillPending
          .where((item) => item.categoryId == null)
          .map((item) => item.id)
          .toSet();
      for (final item in proposedLines) {
        if (!mounted) break;
        if (!currentIds.contains(item.id)) continue;
        final categoryId = proposed[item.id];
        if (categoryId == null) continue;
        try {
          await widget.repository.classifyFinancialEvent(
            spaceId: widget.spaceId,
            eventId: item.id,
            categoryId: categoryId,
          );
          applied++;
        } catch (_) {
          failed = true;
          break;
        }
      }
      if (!mounted) return;
      await _refresh();
      if (!mounted) return;
      setState(() {
        _changed = _changed || applied > 0;
        _batchDone += applied;
        if (widget.batchSize != null) {
          _batchTarget = _batchDone + (_items.length < widget.batchSize!
              ? _items.length
              : widget.batchSize!);
        }
        if (failed) {
          _error = '$applied sugestões aplicadas. '
              'Uma classificação falhou; as demais ficaram pendentes.';
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('$applied categorias confirmadas e aplicadas'),
      ));
    } catch (_) {
      if (mounted) {
        setState(() =>
            _error = 'Não foi possível atualizar as pendências. '
                'Nada foi aplicado automaticamente.');
      }
    } finally {
      if (mounted) setState(() => _applyingSuggestions = false);
    }
  }

  Future<void> _activateAutopilotRule(AutopilotRuleProposal proposal) async {
    if (_creatingAutomaticRule || !_automationEnabled) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('ativar classificação automática?'),
        content: Text(
          'Para futuras movimentações, o Fôlego poderá aplicar '
          '"${proposal.categoryName}" quando encontrar a descrição '
          'exatamente igual a "${proposal.description}", na mesma conta. '
          'Foram encontradas ${proposal.sampleCount} classificações '
          'anteriores concordantes.\n\n'
          'PIX genéricos e compras diferentes continuarão em revisão. '
          'Você pode desativar a regra depois. Saldos, valores e '
          'pagamentos não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('ativar esta regra'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    setState(() => _creatingAutomaticRule = true);
    try {
      // Recheck catalog + examples immediately before enabling a rule.
      final history = await widget.repository.getTransactionsPage(
        widget.spaceId, pageSize: 400,
      );
      final eligible = safeAutopilotRuleProposals(
        history: history.items,
        categories: [..._expenseCategories, ..._incomeCategories],
        existingRules: _reviewRules,
      );
      final normalized = normalizeAutomationText(proposal.description);
      final trusted = eligible.any((candidate) =>
          candidate.accountId == proposal.accountId &&
          candidate.categoryId == proposal.categoryId &&
          candidate.eventType == proposal.eventType &&
          normalizeAutomationText(candidate.description) == normalized);
      if (!trusted) {
        if (mounted) {
          setState(() => _error =
              'O histórico mudou. Atualize antes de ativar a regra.');
        }
        return;
      }
      final created = await widget.repository.createAutomationRule(
        spaceId: widget.spaceId,
        draft: AutomationRuleDraft(
          name: 'autopilot: ${_shortLabel(proposal.description)}',
          matchField: AutomationMatchField.description,
          matchType: AutomationMatchType.equals,
          matchValue: proposal.description,
          sourceScope: AutomationSourceScope.account,
          sourceAccountId: proposal.accountId,
          direction: proposal.eventType == 'income'
              ? AutomationDirection.credit
              : AutomationDirection.debit,
          categoryId: proposal.categoryId,
          actionType: AutomationActionType.reviewCategory,
          executionMode: AutomationExecutionMode.automatic,
        ),
      );
      if (!mounted) return;
      setState(() => _reviewRules = [..._reviewRules, created]);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Regra ativada. Aplicação na próxima conferência.'),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível ativar a regra. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _creatingAutomaticRule = false);
    }
  }

  List<CategoryItem> _selectable(List<CategoryItem> values) {
    return values
        .where(
          (item) =>
              item.active &&
              item.isSelectable &&
              (item.categoryRole == null || item.categoryRole == 'economic'),
        )
        .toList(growable: false);
  }

  Future<void> _refresh() async {
    if (_refreshing) return;
    setState(() => _refreshing = true);
    try {
      final items = await widget.repository
          .listPendingTransactionClassifications(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _items = items;
        _refreshing = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _refreshing = false;
        _error = _friendly(error);
      });
    }
  }

  SmartCategorySuggestion? _suggestionForItem(TransactionItem item) {
    final kind = transactionClassificationKind(item.eventType);
    if (kind == null) return null;
    final categories = kind == 'income'
        ? _incomeCategories : _expenseCategories;
    if (_automationEnabled) {
      final reviewed = reviewedCategorySuggestion(
        item: item,
        rules: _reviewRules,
        categories: categories,
      );
      if (reviewed != null) {
        return SmartCategorySuggestion(
          category: reviewed,
          reason: 'regra revisada anteriormente',
          evidenceCount: 0,
        );
      }
    }
    return suggestSmartCategory(
      description: item.description,
      eventType: item.eventType,
      history: _knownHistory,
      categories: categories,
    );
  }

  Future<void> _chooseCategory(TransactionItem item) async {
    if (_savingEventId != null || _loading) return;
    final kind = transactionClassificationKind(item.eventType);
    if (kind == null) return;

    final categories = kind == 'income'
        ? _incomeCategories
        : _expenseCategories;
    if (categories.isEmpty) {
      setState(
        () => _error = 'nenhuma categoria disponível para este lançamento',
      );
      return;
    }

    final suggestion = _suggestionForItem(item);
    CategoryItem? selected;
    if (suggestion != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('categoria sugerida'),
          content: Text(
            'O FÔLEGO sugere ${suggestion.category.breadcrumb} '
            '(${suggestion.reason}). Aplicar a este lançamento? '
            'Você pode escolher outra categoria.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('escolher outra'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('confirmar categoria'),
            ),
          ],
        ),
      );
      if (!mounted) return;
      if (confirmed == true) selected = suggestion.category;
    }
    selected ??= await _showCategoryPicker(
      categories: categories,
      selectedId: suggestion?.category.id ?? item.categoryId,
      eventType: kind,
    );
    if (selected == null || !mounted) return;

    await _saveSelectedCategory(item, selected);
  }

  Future<void> _acceptCategorySuggestion(
    TransactionItem item,
    SmartCategorySuggestion suggestion,
  ) async {
    if (_savingEventId != null || _loading || _applyingSuggestions) return;
    // An explicit tap is required. Never run classifications while building.
    await _saveSelectedCategory(item, suggestion.category, showOffers: false);
  }

  Future<void> _saveSelectedCategory(
    TransactionItem item,
    CategoryItem selected, {
    bool showOffers = true,
  }) async {
    if (_savingEventId != null || !_items.any((row) => row.id == item.id)) {
      return;
    }
    setState(() {
      _savingEventId = item.id;
      _error = null;
    });

    try {
      await widget.repository.classifyFinancialEvent(
        spaceId: widget.spaceId,
        eventId: item.id,
        categoryId: selected.id,
      );
      if (!mounted) return;
      setState(() {
        _items.removeWhere((candidate) => candidate.id == item.id);
        _savingEventId = null;
        _changed = true;
        _batchDone++;
      });

      final remaining = _batchTarget - _batchDone;
      final matches = showOffers
          ? matchingClassificationCandidates(item, _items)
              .take(remaining > 4 ? 4 : (remaining < 0 ? 0 : remaining))
              .toList(growable: false)
          : const <TransactionItem>[];
      final grouped = matches.isEmpty
          ? 0
          : await _offerMatchBatch(matches, selected);
      if (!mounted) return;
      final ruleCreated = showOffers
          ? await _offerAlwaysCategorize(item, selected)
          : false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ruleCreated
                ? 'categoria salva${grouped > 0 ? " em mais $grouped" : ""} e regra criada para as próximas revisões.'
                : 'classificado em ${selected.breadcrumb}${grouped > 0 ? " + $grouped semelhante(s)" : ""}',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _savingEventId = null;
        _error = _friendly(error);
      });
    }
  }

  Future<int> _offerMatchBatch(
    List<TransactionItem> matches,
    CategoryItem category,
  ) async {
    if (matches.isEmpty) return 0;
    final count = matches.length;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('aplicar a lançamentos iguais?'),
        content: Text(
          'Encontrei $count lançamento${count == 1 ? "" : "s"} da mesma conta, '
          'tipo e descrição. Quer classificá-${count == 1 ? "lo" : "los"} '
          'também como ${category.breadcrumb}? '
          'Os valores e datas não serão alterados.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('deixar para depois'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text('aplicar a $count'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return 0;

    var applied = 0;
    for (final duplicate in matches) {
      if (!mounted) break;
      setState(() => _savingEventId = duplicate.id);
      try {
        await widget.repository.classifyFinancialEvent(
          spaceId: widget.spaceId,
          eventId: duplicate.id,
          categoryId: category.id,
        );
        if (!mounted) break;
        setState(() {
          _items.removeWhere((row) => row.id == duplicate.id);
          _changed = true;
          _batchDone++;
          applied++;
        });
      } catch (_) {
        if (mounted) {
          setState(() => _error =
              '$applied lançamento(s) adicionais classificados; houve uma '
              'falha no próximo. Os restantes foram preservados.');
        }
        break;
      } finally {
        if (mounted) setState(() => _savingEventId = null);
      }
    }
    return applied;
  }

  Future<bool> _offerAlwaysCategorize(
    TransactionItem item,
    CategoryItem category,
  ) async {
    if (!_automationEnabled) return false;
    final description = item.description.trim();
    final simpleAccountEvent =
        (item.eventType == 'expense' || item.eventType == 'income') &&
        item.accountId != null;
    if (description.length < 4 || !simpleAccountEvent) return false;
    final direction = transactionClassificationKind(item.eventType) == 'income'
        ? AutomationDirection.credit
        : AutomationDirection.debit;
    final existing = _reviewRules.any((rule) =>
        rule.active &&
        rule.matchField == AutomationMatchField.description &&
        rule.matchType == AutomationMatchType.equals &&
        rule.sourceScope == AutomationSourceScope.account &&
        rule.sourceAccountId == item.accountId &&
        rule.direction == direction &&
        rule.categoryId == category.id &&
        normalizeAutomationText(rule.matchValue) ==
            normalizeAutomationText(description));
    if (existing) return false;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('lembrar esta categoria?'),
        content: Text(
          'Quando aparecer uma descrição idêntica a “${_shortLabel(description)}”, sugerir ${category.breadcrumb}?\n\nVocê continua confirmando a classificação; valores e datas não são alterados.' ,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('agora não'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('criar regra'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return false;

    try {
      final created = await widget.repository.createAutomationRule(
        spaceId: widget.spaceId,
        draft: AutomationRuleDraft(
          name: 'sempre: ${_shortLabel(description)}',
          matchField: AutomationMatchField.description,
          matchType: AutomationMatchType.equals,
          matchValue: description,
          sourceScope: AutomationSourceScope.account,
          sourceAccountId: item.accountId,
          direction: direction,
          categoryId: category.id,
          actionType: AutomationActionType.reviewCategory,
          executionMode: AutomationExecutionMode.review,
        ),
      );
      if (mounted) {
        setState(() => _reviewRules = [..._reviewRules, created]);
      }
      return true;
    } catch (error) {
      if (!mounted) return false;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'a categoria foi salva, mas a regra não: ${_friendly(error)}',
          ),
        ),
      );
      return false;
    }
  }

  String _shortLabel(String value) {
    final compact = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    return compact.length <= 36 ? compact : '${compact.substring(0, 33)}…';
  }

  Future<CategoryItem?> _showCategoryPicker({
    required List<CategoryItem> categories,
    required String? selectedId,
    required String eventType,
  }) {
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    if (!compact) {
      return showDialog<CategoryItem>(
        context: context,
        builder: (_) => Dialog(
          backgroundColor: Colors.transparent,
          child: SizedBox(
            width: 520,
            height: MediaQuery.sizeOf(context).height * .8,
            child: CategorySearchPicker(
              categories: categories,
              selectedId: selectedId,
              eventType: eventType,
              dialogMode: true,
            ),
          ),
        ),
      );
    }

    return showModalBottomSheet<CategoryItem>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .86,
        child: CategorySearchPicker(
          categories: categories,
          selectedId: selectedId,
          eventType: eventType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final visibleItems = _suggestionsOnly
        ? _items.where((item) => _suggestionForItem(item) != null).toList()
        : _items;
    final remainingInBatch = _batchTarget - _batchDone;
    final displayedItems = widget.batchSize == null
        ? visibleItems
        : visibleItems.take(remainingInBatch < 0 ? 0 : remainingInBatch).toList();

    return Material(
      color: background,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 10, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'classificar lançamentos',
                          style: AppTypography.section(
                            context,
                            fontSize: 21,
                            color: primaryText,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _items.isEmpty
                              ? 'tudo em dia por aqui'
                              : widget.batchSize != null
                              ? '$_batchDone/$_batchTarget neste lote • ${_items.length} pendentes no total'
                              : ClassificationReviewOverview.fromItems(
                                  _items,
                                ).description,
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'atualizar',
                    onPressed: _refreshing ? null : _refresh,
                    icon: _refreshing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Icon(AppIcons.refresh, color: secondaryText),
                  ),
                  IconButton(
                    tooltip: 'fechar',
                    onPressed: () => Navigator.of(context).pop(_changed),
                    icon: Icon(AppIcons.close, color: secondaryText),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            if (!_loading && _items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 2),
                child: Row(
                  children: [
                    ChoiceChip(
                      key: const ValueKey('classification-filter-all'),
                      label: Text('todos (${_items.length})'),
                      selected: !_suggestionsOnly,
                      onSelected: (_) => setState(() => _suggestionsOnly = false),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      key: const ValueKey('classification-filter-suggested'),
                      label: Text(
                        'com sugestão (${_items.where((i) => _suggestionForItem(i) != null).length})',
                      ),
                      selected: _suggestionsOnly,
                      onSelected: (_) => setState(() => _suggestionsOnly = true),
                    ),
                  ],
                ),
              ),
            if (!_loading && _automationEnabled &&
                safeAutopilotRuleProposals(
                  history: _knownHistory,
                  categories: [..._expenseCategories, ..._incomeCategories],
                  existingRules: _reviewRules,
                ).isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: ExpansionTile(
                  key: const ValueKey('autopilot-trusted-rules'),
                  title: const Text('ensinar o Autopilot'),
                  subtitle: const Text(
                    'padrões confiáveis para classificar compras futuras',
                  ),
                  children: [
                    for (final proposal in safeAutopilotRuleProposals(
                      history: _knownHistory,
                      categories: [..._expenseCategories, ..._incomeCategories],
                      existingRules: _reviewRules,
                    ).take(8))
                      ListTile(
                        title: Text(proposal.description, maxLines: 2),
                        subtitle: Text(
                          '${proposal.sampleCount} exemplos · '
                          '${proposal.categoryName}',
                          maxLines: 2,
                        ),
                        trailing: OutlinedButton(
                          onPressed: _creatingAutomaticRule
                              ? null
                              : () => _activateAutopilotRule(proposal),
                          child: const Text('ativar'),
                        ),
                      ),
                    if (_creatingAutomaticRule) const LinearProgressIndicator(),
                  ],
                ),
              ),
            if (!_loading && !_applyingSuggestions &&
                _readySuggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: OutlinedButton.icon(
                  key: const ValueKey('classification-reviewed-suggestions'),
                  onPressed: _applyReviewedSuggestions,
                  icon: const Icon(AppIcons.check, size: 18),
                  label: Text(
                    '${_readySuggestions.length} sugestões prontas para conferir',
                  ),
                ),
              ),
            if (_applyingSuggestions)
              const LinearProgressIndicator(),
            if (_error != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .08),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: purple.withValues(alpha: .25)),
                ),
                child: Text(
                  _error!,
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: primaryText,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const AppLoadingState(label: 'organizando classificações')
                  : _items.isEmpty
                  ? _EmptyClassificationState(
                      surface: surface,
                      border: border,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      purple: purple,
                    )
                  : _suggestionsOnly && displayedItems.isEmpty
                  ? Center(
                      child: Text(
                        'sem sugestões seguras. veja todos para classificar manualmente.',
                        textAlign: TextAlign.center,
                        style: AppTypography.body(context, fontSize: 12),
                      ),
                    )
                  : _batchFinished
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('Lote concluído ✓'),
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => setState(() {
                              _batchDone = 0;
                              _batchTarget = _items.length < widget.batchSize!
                                  ? _items.length
                                  : widget.batchSize!;
                            }),
                            child: const Text('Resolver mais 5'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(context).pop(_changed),
                            child: const Text('Continuar depois'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _refresh,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 110),
                        itemCount: displayedItems.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 9),
                        itemBuilder: (context, index) {
                          final item = displayedItems[index];
                          final suggestion = _suggestionForItem(item);
                          return _ClassificationCard(
                            item: item,
                            suggestion: suggestion,
                            saving: _savingEventId == item.id,
                            onTap: () => _chooseCategory(item),
                            onAcceptSuggestion: suggestion == null
                                ? null
                                : () => _acceptCategorySuggestion(item, suggestion),
                          );
                        },
                      ),
                    ),
            ),
            if (_items.isNotEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
                decoration: BoxDecoration(
                  color: surface,
                  border: Border(top: BorderSide(color: border)),
                ),
                child: Text(
                  'Classificar não altera valor, data, saldo ou parcela. Se a planilha estiver conectada, a categoria poderá ser enviada na próxima sincronização; confira o status em Perfil.',
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _friendly(Object error) {
    final text = error.toString();
    if (text.contains('classification_failed')) {
      return 'não foi possível concluir a classificação';
    }
    if (text.contains('event_not_classifiable')) {
      return 'esse tipo de lançamento não usa categoria econômica';
    }
    if (text.contains('category_kind_mismatch')) {
      return 'essa categoria não corresponde ao tipo do lançamento';
    }
    if (text.contains('category_not_selectable')) {
      return 'escolha uma categoria ativa e selecionável';
    }
    return text.replaceFirst('Exception: ', '').replaceFirst('Bad state: ', '');
  }
}

class _ClassificationCard extends StatelessWidget {
  const _ClassificationCard({
    required this.item,
    required this.suggestion,
    required this.onAcceptSuggestion,
    required this.saving,
    required this.onTap,
  });

  final TransactionItem item;
  final SmartCategorySuggestion? suggestion;
  final VoidCallback? onAcceptSuggestion;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final kind = transactionClassificationKind(item.eventType);
    final positive = kind == 'income';
    final evidenceHint = classificationEvidenceHint(item);
    final amountColor = positive
        ? AppColors.positiveText(brightness)
        : AppColors.expenseText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: saving ? null : onTap,
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.compactCard),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(
                  AppIcons.categoryUnclassified,
                  size: 21,
                  color: purple,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            financialDisplayDescription(item.description),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(
                              context,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${positive ? '+' : '−'} ${Formatters.money(item.amount.abs())}',
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: amountColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 7),
                    Wrap(
                      spacing: 7,
                      runSpacing: 5,
                      children: [
                        _MetaText(_eventLabel(item.eventType)),
                        _MetaText(_dateTime(item.occurredAt)),
                        if (item.accountName != null &&
                            item.accountName!.trim().isNotEmpty)
                          _MetaText(item.accountName!),
                      ],
                    ),
                    if (evidenceHint != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        evidenceHint,
                        key: ValueKey('classification-evidence:${item.id}'),
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    ],
                    if (suggestion != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'sugestão: ${suggestion!.category.breadcrumb} · '
                        '${suggestion!.reason}',
                        key: ValueKey('classification-smart-suggestion:${item.id}'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: OutlinedButton.icon(
                          key: ValueKey('classification-accept-suggestion:${item.id}'),
                          onPressed: saving ? null : onAcceptSuggestion,
                          icon: const Icon(AppIcons.check, size: 15),
                          label: const Text('aceitar sugestão'),
                        ),
                      ),
                    ],
                    const SizedBox(height: 9),
                    Row(
                      children: [
                        Text(
                          'escolher categoria',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: purple,
                          ),
                        ),
                        const Spacer(),
                        if (saving)
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          Icon(
                            AppIcons.chevronRight,
                            size: 17,
                            color: secondaryText,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _eventLabel(String eventType) {
    switch (eventType) {
      case 'income':
        return 'entrada';
      case 'benefit_credit':
        return 'crédito de benefício';
      case 'reimbursement':
        return 'reembolso';
      case 'card_purchase':
        return 'cartão';
      case 'benefit_expense':
        return 'benefício';
      case 'refund':
        return 'estorno';
      case 'debt_payment':
        return 'dívida';
      default:
        return 'saída';
    }
  }

  static String _dateTime(DateTime value) {
    final local = value.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/${local.year} · $hour:$minute';
  }
}

class _MetaText extends StatelessWidget {
  const _MetaText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final color = AppColors.secondaryText(Theme.of(context).brightness);
    return Text(
      text,
      style: AppTypography.label(context, fontSize: 9, color: color),
    );
  }
}

class _EmptyClassificationState extends StatelessWidget {
  const _EmptyClassificationState({
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.purple,
  });

  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final Color purple;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 420),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadii.compactCard),
                ),
                child: Icon(AppIcons.check, color: purple, size: 25),
              ),
              const SizedBox(height: 14),
              Text(
                'tudo classificado',
                style: AppTypography.section(
                  context,
                  fontSize: 18,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Quando a planilha enviar um lançamento sem categoria, ele aparece aqui para você decidir.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
