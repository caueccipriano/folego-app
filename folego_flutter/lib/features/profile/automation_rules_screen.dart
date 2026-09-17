import 'package:flutter/material.dart';

import '../../core/entitlements/feature_entitlements.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/automation_rule.dart';
import '../../data/models/statement_import.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_automation.dart';

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
  bool _loading = true;
  String? _error;
  final TextEditingController _preview = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _preview.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final rules = await widget.repository.listAutomationRules(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _rules = rules;
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

  bool get _canEdit => FeatureEntitlementsScope.of(context)
      .entitlements
      .allows(AppCapability.automationRules);

  Future<void> _toggle(AutomationRule rule, bool active) async {
    if (!_canEdit) return;
    setState(() {
      _rules = _rules
          .map(
            (item) => item.id == rule.id
                ? AutomationRule(
                    id: item.id,
                    spaceId: item.spaceId,
                    name: item.name,
                    active: active,
                    matchField: item.matchField,
                    matchType: item.matchType,
                    matchValue: item.matchValue,
                    sourceScope: item.sourceScope,
                    sourceAccountId: item.sourceAccountId,
                    sourceCardId: item.sourceCardId,
                    sourceBenefitId: item.sourceBenefitId,
                    direction: item.direction,
                    categoryId: item.categoryId,
                    classificationValue: item.classificationValue,
                    actionType: item.actionType,
                    executionMode: item.executionMode,
                    priority: item.priority,
                  )
                : item,
          )
          .toList(growable: false);
    });
    try {
      await widget.repository.setAutomationRuleActive(
        spaceId: widget.spaceId,
        ruleId: rule.id,
        active: active,
      );
    } catch (_) {
      await _load();
    }
  }

  Future<void> _openForm([AutomationRule? rule]) async {
    if (!_canEdit) return;
    final draft = await showModalBottomSheet<AutomationRuleDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AutomationRuleForm(initial: rule),
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

  Future<void> _delete(AutomationRule rule) async {
    if (!_canEdit) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('excluir regra?'),
        content: Text('“${rule.name}” deixa de ser aplicada em novos extratos.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('excluir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await widget.repository.deleteAutomationRule(
      spaceId: widget.spaceId,
      ruleId: rule.id,
    );
    await _load();
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
    return _rules
        .where((rule) => rule.matchesCandidate(candidate))
        .toList(growable: false);
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
                      hintText: 'ex.: café do centro',
                      prefixIcon: Icon(AppIcons.search),
                    ),
                  ),
                  if (_preview.text.trim().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(
                      _previewMatches.isEmpty
                          ? 'nenhuma regra ativa corresponderia'
                          : '${_previewMatches.length} regra(s) corresponderiam: ${_previewMatches.map((item) => item.name).join(', ')}',
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
                          title: Text(rule.name),
                          subtitle: Text(
                            '${rule.matchField.dbKey} ${rule.matchType.dbKey} “${rule.matchValue}”\n${_actionLabel(rule)}',
                          ),
                          isThreeLine: true,
                          leading: Switch.adaptive(
                            value: rule.active,
                            onChanged: canEdit
                                ? (value) => _toggle(rule, value)
                                : null,
                          ),
                          trailing: canEdit
                              ? PopupMenuButton<String>(
                                  onSelected: (value) {
                                    if (value == 'edit') _openForm(rule);
                                    if (value == 'delete') _delete(rule);
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'edit',
                                      child: Text('editar'),
                                    ),
                                    PopupMenuItem(
                                      value: 'delete',
                                      child: Text('excluir'),
                                    ),
                                  ],
                                )
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
                    canEdit ? 'regras habilitadas' : 'modo de prévia',
                    style: AppTypography.section(context, fontSize: 15),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    canEdit
                        ? 'as regras só preparam sugestões ou revisão do extrato; nenhum lançamento é criado automaticamente.'
                        : 'você pode inspecionar correspondências. edição de regras depende do entitlement de automações; não há cobrança ligada a este build.',
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

class _AutomationRuleForm extends StatefulWidget {
  const _AutomationRuleForm({this.initial});
  final AutomationRule? initial;

  @override
  State<_AutomationRuleForm> createState() => _AutomationRuleFormState();
}

class _AutomationRuleFormState extends State<_AutomationRuleForm> {
  late final TextEditingController _name;
  late final TextEditingController _matchValue;
  late AutomationMatchField _field;
  late AutomationMatchType _type;
  late AutomationDirection _direction;
  late AutomationActionType _action;
  late AutomationExecutionMode _execution;
  String _classification = 'expense';

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    _name = TextEditingController(text: initial?.name ?? '');
    _matchValue = TextEditingController(text: initial?.matchValue ?? '');
    _field = initial?.matchField ?? AutomationMatchField.description;
    _type = initial?.matchType ?? AutomationMatchType.contains;
    _direction = initial?.direction ?? AutomationDirection.any;
    _action = initial?.actionType == AutomationActionType.markRecognized
        ? AutomationActionType.markRecognized
        : AutomationActionType.suggestClassification;
    _execution = initial?.executionMode == AutomationExecutionMode.review
        ? AutomationExecutionMode.review
        : AutomationExecutionMode.suggest;
    _classification = initial?.classificationValue ?? 'expense';
  }

  @override
  void dispose() {
    _name.dispose();
    _matchValue.dispose();
    super.dispose();
  }

  void _submit() {
    if (_name.text.trim().isEmpty || _matchValue.text.trim().isEmpty) return;
    Navigator.of(context).pop(
      AutomationRuleDraft(
        name: _name.text,
        matchField: _field,
        matchType: _type,
        matchValue: _matchValue.text,
        direction: _direction,
        actionType: _action,
        classificationValue:
            _action == AutomationActionType.suggestClassification
                ? _classification
                : null,
        executionMode: _execution,
        priority: widget.initial?.priority ?? 0,
        active: widget.initial?.active ?? true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
        child: Padding(
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
                const SizedBox(height: 16),
                TextField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'nome'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AutomationMatchField>(
                  initialValue: _field,
                  decoration: const InputDecoration(labelText: 'campo'),
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
                  decoration: const InputDecoration(labelText: 'ação'),
                  items: const [
                    DropdownMenuItem(
                      value: AutomationActionType.suggestClassification,
                      child: Text('sugerir classificação'),
                    ),
                    DropdownMenuItem(
                      value: AutomationActionType.markRecognized,
                      child: Text('marcar como reconhecido'),
                    ),
                  ],
                  onChanged: (value) => setState(() => _action = value!),
                ),
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
                        child: Text('gasto em benefício'),
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
                SegmentedButton<AutomationExecutionMode>(
                  segments: const [
                    ButtonSegment(
                      value: AutomationExecutionMode.suggest,
                      label: Text('só sugerir'),
                    ),
                    ButtonSegment(
                      value: AutomationExecutionMode.review,
                      label: Text('preencher revisão'),
                    ),
                  ],
                  selected: <AutomationExecutionMode>{_execution},
                  onSelectionChanged: (value) =>
                      setState(() => _execution = value.first),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('salvar regra'),
                ),
              ],
            ),
          ),
        ),
      );
}

String _actionLabel(AutomationRule rule) => switch (rule.actionType) {
      AutomationActionType.suggestClassification =>
        'sugere ${rule.classificationValue ?? 'classificação'} · ${rule.executionMode.dbKey}',
      AutomationActionType.markRecognized => 'marca como reconhecido',
      AutomationActionType.suggestCategory => 'sugere categoria',
      AutomationActionType.reviewCategory => 'preenche categoria na revisão',
    };
