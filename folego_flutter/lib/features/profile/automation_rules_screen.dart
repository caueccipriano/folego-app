import 'package:flutter/material.dart';

import '../../core/entitlements/feature_entitlements.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/account_item.dart';
import '../../data/models/automation_rule.dart';
import '../../data/models/category_item.dart';
import '../../data/models/credit_card_item.dart';
import '../../data/models/statement_import.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_automation.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';

class AutomationRulesScreen extends StatefulWidget {
  const AutomationRulesScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<AutomationRulesScreen> createState() => _AutomationRulesScreenState();
}

class _AutomationRulesScreenState extends State<AutomationRulesScreen> {
  List<AutomationRule> _rules = const <AutomationRule>[];
  List<CategoryItem> _categories = const <CategoryItem>[];
  List<AccountItem> _accounts = const <AccountItem>[];
  List<AccountItem> _benefits = const <AccountItem>[];
  List<CreditCardItem> _cards = const <CreditCardItem>[];
  bool _loading = true;
  String? _error;
  final TextEditingController _preview = TextEditingController();
  RealtimeRefreshBinding? _realtimeBinding;

  @override
  void initState() {
    super.initState();
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator != null) {
      _realtimeBinding = coordinator.bind(
        domain: AppRealtimeDomain.automationRules,
        onRefresh: _load,
      );
    }
    _load();
  }

  @override
  void dispose() {
    _realtimeBinding?.dispose();
    _preview.dispose();
    super.dispose();
  }

  bool get _canEdit => FeatureEntitlementsScope.of(context)
      .entitlements
      .allows(AppCapability.automationRules);

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listAutomationRules(widget.spaceId),
        widget.repository.listExpenseCategoryCatalog(widget.spaceId),
        widget.repository.listIncomeCategoryCatalog(widget.spaceId),
        widget.repository.listPaymentAccounts(widget.spaceId),
        widget.repository.listBenefitAccounts(widget.spaceId),
        widget.repository.listActiveCreditCards(widget.spaceId),
      ]);
      if (!mounted) return;
      final categories = <CategoryItem>[
        ...values[1] as List<CategoryItem>,
        ...values[2] as List<CategoryItem>,
      ];
      final seen = <String>{};
      setState(() {
        _rules = values[0] as List<AutomationRule>;
        _categories = categories
            .where((item) => item.active && item.isSelectable && seen.add(item.id))
            .toList(growable: false);
        _accounts = values[3] as List<AccountItem>;
        _benefits = values[4] as List<AccountItem>;
        _cards = values[5] as List<CreditCardItem>;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'não consegui carregar as regras de automação';
      });
    }
  }

  Future<void> _toggle(AutomationRule rule, bool active) async {
    if (!_canEdit) return;
    try {
      await widget.repository.setAutomationRuleActive(
        spaceId: widget.spaceId,
        ruleId: rule.id,
        active: active,
      );
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('não consegui atualizar essa regra')),
      );
    }
  }

  Future<void> _openForm([AutomationRule? rule]) async {
    if (!_canEdit) return;
    final draft = await showModalBottomSheet<AutomationRuleDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _AutomationRuleForm(
        initial: rule,
        categories: _categories,
        accounts: _accounts,
        benefits: _benefits,
        cards: _cards,
      ),
    );
    if (draft == null) return;
    try {
      if (rule == null) {
        await widget.repository.createAutomationRule(
          spaceId: widget.spaceId,
          draft: draft,
        );
      } else {
        await widget.repository.updateAutomationRule(
          spaceId: widget.spaceId,
          ruleId: rule.id,
          draft: draft,
        );
      }
      await _load();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('não consegui salvar essa regra')),
      );
    }
  }

  List<AutomationRule> get _previewMatches {
    final value = _preview.text.trim();
    if (value.isEmpty) return const <AutomationRule>[];
    final candidate = StatementImportCandidate(
      rowNumber: 1,
      occurredAt: DateTime.now(),
      dateOnly: true,
      amountMinor: 100,
      description: value,
      merchant: value,
      direction: StatementImportDirection.debit,
      candidateType: StatementImportCandidateType.expense,
    );
    final matches = _rules
        .where((rule) => rule.matchesCandidate(candidate))
        .toList(growable: false);
    matches.sort(compareAutomationRulesForPreview);
    return matches;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final canEdit = _canEdit;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(
        title: const Text('automações'),
        actions: [
          IconButton(
            tooltip: 'atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              key: const ValueKey('automation-add-rule'),
              onPressed: () => _openForm(),
              icon: const Icon(AppIcons.add),
              label: const Text('nova regra'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
                children: [
                  _EntitlementCard(canEdit: canEdit),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _preview,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'prévia de correspondência',
                      hintText: 'ex.: UBER TRIP',
                      prefixIcon: Icon(AppIcons.search),
                    ),
                  ),
                  if (_preview.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _previewMatches.isEmpty
                          ? 'nenhuma regra ativa corresponderia'
                          : 'regra vencedora: ${_previewMatches.first.name}',
                      style: AppTypography.body(
                        context,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                  const SizedBox(height: 22),
                  if (_error != null)
                    Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  if (_rules.isEmpty)
                    const _EmptyRules()
                  else
                    ..._rules.map(
                      (rule) => Card(
                        child: ListTile(
                          onTap: canEdit ? () => _openForm(rule) : null,
                          title: Text(rule.name),
                          subtitle: Text(
                            '${_conditionLabel(rule)}\n${_actionLabel(rule)} · ${_sourceLabel(rule)}',
                          ),
                          isThreeLine: true,
                          leading: Switch.adaptive(
                            value: rule.active,
                            onChanged: canEdit
                                ? (value) => _toggle(rule, value)
                                : null,
                          ),
                          trailing: canEdit
                              ? const Icon(AppIcons.chevronRight)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _AutomationRuleForm extends StatefulWidget {
  const _AutomationRuleForm({
    this.initial,
    required this.categories,
    required this.accounts,
    required this.benefits,
    required this.cards,
  });

  final AutomationRule? initial;
  final List<CategoryItem> categories;
  final List<AccountItem> accounts;
  final List<AccountItem> benefits;
  final List<CreditCardItem> cards;

  @override
  State<_AutomationRuleForm> createState() => _AutomationRuleFormState();
}

class _AutomationRuleFormState extends State<_AutomationRuleForm> {
  late final TextEditingController _name;
  late final TextEditingController _matchValue;
  late final TextEditingController _priority;
  late AutomationMatchField _field;
  late AutomationMatchType _type;
  late AutomationDirection _direction;
  late AutomationActionType _action;
  late AutomationExecutionMode _execution;
  late AutomationSourceScope _scope;
  String? _sourceId;
  String? _categoryId;
  String _classification = 'expense';
  String? _validation;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _matchValue = TextEditingController(text: initial?.matchValue ?? '');
    _priority = TextEditingController(text: '${initial?.priority ?? 0}');
    _field = initial?.matchField ?? AutomationMatchField.description;
    _type = initial?.matchType ?? AutomationMatchType.contains;
    _direction = initial?.direction ?? AutomationDirection.any;
    _action = initial?.actionType ?? AutomationActionType.suggestCategory;
    _execution = initial?.executionMode == AutomationExecutionMode.review
        ? AutomationExecutionMode.review
        : AutomationExecutionMode.suggest;
    _scope = initial?.sourceScope ?? AutomationSourceScope.any;
    _sourceId = switch (_scope) {
      AutomationSourceScope.account => initial?.sourceAccountId,
      AutomationSourceScope.card => initial?.sourceCardId,
      AutomationSourceScope.benefit => initial?.sourceBenefitId,
      AutomationSourceScope.any => null,
    };
    _categoryId = initial?.categoryId;
    _classification = initial?.classificationValue ?? 'expense';
  }

  @override
  void dispose() {
    _name.dispose();
    _matchValue.dispose();
    _priority.dispose();
    super.dispose();
  }

  bool get _categoryAction =>
      _action == AutomationActionType.suggestCategory ||
      _action == AutomationActionType.reviewCategory;

  List<DropdownMenuItem<String>> get _sourceItems => switch (_scope) {
        AutomationSourceScope.account => widget.accounts
            .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
            .toList(growable: false),
        AutomationSourceScope.card => widget.cards
            .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
            .toList(growable: false),
        AutomationSourceScope.benefit => widget.benefits
            .map((item) => DropdownMenuItem(value: item.id, child: Text(item.name)))
            .toList(growable: false),
        AutomationSourceScope.any => const <DropdownMenuItem<String>>[],
      };

  void _submit() {
    final name = _name.text.trim();
    final matchValue = _matchValue.text.trim();
    final priority = int.tryParse(_priority.text.trim());
    if (name.isEmpty || matchValue.isEmpty) {
      setState(() => _validation = 'preencha nome e texto de correspondência');
      return;
    }
    if (priority == null || priority < -1000 || priority > 1000) {
      setState(() => _validation = 'prioridade deve ficar entre -1000 e 1000');
      return;
    }
    if (_scope != AutomationSourceScope.any && _sourceId == null) {
      setState(() => _validation = 'escolha a origem específica');
      return;
    }
    if (_categoryAction && _categoryId == null) {
      setState(() => _validation = 'escolha uma categoria ativa');
      return;
    }

    Navigator.of(context).pop(
      AutomationRuleDraft(
        name: name,
        matchField: _field,
        matchType: _type,
        matchValue: matchValue,
        sourceScope: _scope,
        sourceAccountId:
            _scope == AutomationSourceScope.account ? _sourceId : null,
        sourceCardId: _scope == AutomationSourceScope.card ? _sourceId : null,
        sourceBenefitId:
            _scope == AutomationSourceScope.benefit ? _sourceId : null,
        direction: _direction,
        categoryId: _categoryAction ? _categoryId : null,
        classificationValue:
            _action == AutomationActionType.suggestClassification
                ? _classification
                : null,
        actionType: _action,
        executionMode: _execution,
        priority: priority,
        active: widget.initial?.active ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.initial == null ? 'nova regra' : 'editar regra',
                style: AppTypography.section(context, fontSize: 20),
              ),
              const SizedBox(height: 6),
              const Text('quando isso acontecer → faça isso'),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'nome'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationMatchField>(
                initialValue: _field,
                decoration: const InputDecoration(labelText: 'quando'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationMatchField.description,
                    child: Text('descrição'),
                  ),
                  DropdownMenuItem(
                    value: AutomationMatchField.merchant,
                    child: Text('estabelecimento'),
                  ),
                ],
                onChanged: (value) => setState(() => _field = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationMatchType>(
                initialValue: _type,
                decoration: const InputDecoration(labelText: 'comparação'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationMatchType.contains,
                    child: Text('contém'),
                  ),
                  DropdownMenuItem(
                    value: AutomationMatchType.equals,
                    child: Text('é igual a'),
                  ),
                ],
                onChanged: (value) => setState(() => _type = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _matchValue,
                decoration: const InputDecoration(labelText: 'texto a encontrar'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationSourceScope>(
                initialValue: _scope,
                decoration: const InputDecoration(labelText: 'origem'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationSourceScope.any,
                    child: Text('qualquer conta/cartão'),
                  ),
                  DropdownMenuItem(
                    value: AutomationSourceScope.account,
                    child: Text('conta específica'),
                  ),
                  DropdownMenuItem(
                    value: AutomationSourceScope.card,
                    child: Text('cartão específico'),
                  ),
                  DropdownMenuItem(
                    value: AutomationSourceScope.benefit,
                    child: Text('benefício específico'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _scope = value!;
                  _sourceId = null;
                }),
              ),
              if (_scope != AutomationSourceScope.any) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _sourceItems.any((item) => item.value == _sourceId)
                      ? _sourceId
                      : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'instrumento'),
                  items: _sourceItems,
                  onChanged: (value) => setState(() => _sourceId = value),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationDirection>(
                initialValue: _direction,
                decoration: const InputDecoration(labelText: 'direção'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationDirection.any,
                    child: Text('qualquer'),
                  ),
                  DropdownMenuItem(
                    value: AutomationDirection.debit,
                    child: Text('saída'),
                  ),
                  DropdownMenuItem(
                    value: AutomationDirection.credit,
                    child: Text('entrada'),
                  ),
                ],
                onChanged: (value) => setState(() => _direction = value!),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationActionType>(
                initialValue: _action,
                decoration: const InputDecoration(labelText: 'então'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationActionType.suggestCategory,
                    child: Text('sugerir categoria'),
                  ),
                  DropdownMenuItem(
                    value: AutomationActionType.reviewCategory,
                    child: Text('preparar categoria para revisão'),
                  ),
                  DropdownMenuItem(
                    value: AutomationActionType.suggestClassification,
                    child: Text('sugerir classificação segura'),
                  ),
                  DropdownMenuItem(
                    value: AutomationActionType.markRecognized,
                    child: Text('marcar candidato como reconhecido'),
                  ),
                ],
                onChanged: (value) => setState(() {
                  _action = value!;
                  if (!_categoryAction) _categoryId = null;
                }),
              ),
              if (_categoryAction) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue:
                      widget.categories.any((item) => item.id == _categoryId)
                          ? _categoryId
                          : null,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'categoria'),
                  items: widget.categories
                      .map(
                        (item) => DropdownMenuItem(
                          value: item.id,
                          child: Text(item.breadcrumb, overflow: TextOverflow.ellipsis),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _categoryId = value),
                ),
              ],
              if (_action == AutomationActionType.suggestClassification) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _classification,
                  decoration: const InputDecoration(labelText: 'classificação'),
                  items: const [
                    DropdownMenuItem(value: 'expense', child: Text('despesa')),
                    DropdownMenuItem(value: 'income', child: Text('receita')),
                    DropdownMenuItem(
                      value: 'card_purchase',
                      child: Text('compra no cartão'),
                    ),
                    DropdownMenuItem(
                      value: 'benefit_expense',
                      child: Text('gasto de benefício'),
                    ),
                    DropdownMenuItem(
                      value: 'benefit_credit',
                      child: Text('crédito de benefício'),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => _classification = value!),
                ),
              ],
              const SizedBox(height: 12),
              DropdownButtonFormField<AutomationExecutionMode>(
                initialValue: _execution,
                decoration: const InputDecoration(labelText: 'modo'),
                items: const [
                  DropdownMenuItem(
                    value: AutomationExecutionMode.suggest,
                    child: Text('sugerir'),
                  ),
                  DropdownMenuItem(
                    value: AutomationExecutionMode.review,
                    child: Text('preparar para revisão'),
                  ),
                ],
                onChanged: (value) => setState(() => _execution = value!),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _priority,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'prioridade',
                  helperText: 'maior prioridade vence depois de origem e match',
                ),
              ),
              if (_validation != null) ...[
                const SizedBox(height: 10),
                Text(
                  _validation!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
              const SizedBox(height: 18),
              FilledButton(
                onPressed: _submit,
                child: const Text('salvar regra'),
              ),
              const SizedBox(height: 8),
              const Text(
                'Nesta versão a regra nunca confirma nem cria um lançamento sozinha. A revisão do extrato continua obrigatória.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
}

class _EntitlementCard extends StatelessWidget {
  const _EntitlementCard({required this.canEdit});

  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(AppIcons.recurring),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    canEdit ? 'regras habilitadas para dev/teste' : 'Premium em breve',
                    style: AppTypography.section(context, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canEdit
                        ? 'o entitlement foi injetado; as regras continuam limitadas ao staging/review.'
                        : 'produção continua Free por padrão. Não há cobrança, checkout ou paywall ligados a este preview.',
                    style: AppTypography.body(
                      context,
                      color: AppColors.secondaryText(brightness),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyRules extends StatelessWidget {
  const _EmptyRules();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 30),
        child: Column(
          children: [
            Icon(AppIcons.recurring, size: 38),
            SizedBox(height: 10),
            Text('nenhuma regra criada ainda'),
          ],
        ),
      );
}

int compareAutomationRulesForPreview(AutomationRule a, AutomationRule b) {
  final source = _specificity(b.sourceScope).compareTo(_specificity(a.sourceScope));
  if (source != 0) return source;
  final exact = _exactness(b.matchType).compareTo(_exactness(a.matchType));
  if (exact != 0) return exact;
  final priority = b.priority.compareTo(a.priority);
  if (priority != 0) return priority;
  return a.id.compareTo(b.id);
}

int _specificity(AutomationSourceScope scope) =>
    scope == AutomationSourceScope.any ? 0 : 1;
int _exactness(AutomationMatchType type) =>
    type == AutomationMatchType.equals ? 1 : 0;

String _conditionLabel(AutomationRule rule) =>
    '${rule.matchField == AutomationMatchField.merchant ? 'estabelecimento' : 'descrição'} '
    '${rule.matchType == AutomationMatchType.equals ? 'é igual a' : 'contém'} “${rule.matchValue}”';

String _actionLabel(AutomationRule rule) => switch (rule.actionType) {
      AutomationActionType.suggestCategory => 'sugerir categoria',
      AutomationActionType.reviewCategory => 'preparar categoria para revisão',
      AutomationActionType.suggestClassification => 'sugerir classificação',
      AutomationActionType.markRecognized => 'marcar como reconhecido',
    };

String _sourceLabel(AutomationRule rule) => switch (rule.sourceScope) {
      AutomationSourceScope.any => 'qualquer origem',
      AutomationSourceScope.account => 'conta específica',
      AutomationSourceScope.card => 'cartão específico',
      AutomationSourceScope.benefit => 'benefício específico',
    };
