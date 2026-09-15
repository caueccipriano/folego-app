import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_goal.dart';
import 'goals_widgets.dart';

class GoalFormResult {
  const GoalFormResult({
    required this.name,
    required this.target,
    required this.icon,
    this.targetDate,
  });

  final String name;
  final num target;
  final DateTime? targetDate;
  final GoalIcon icon;
}

class GoalContributionFormResult {
  const GoalContributionFormResult({
    required this.amount,
    required this.date,
    this.note,
  });

  final num amount;
  final DateTime date;
  final String? note;
}

Future<GoalFormResult?> showGoalFormSheet(
  BuildContext context, {
  FinancialGoal? goal,
}) {
  return showModalBottomSheet<GoalFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => _GoalFormSheet(goal: goal),
  );
}

Future<GoalContributionFormResult?> showGoalContributionSheet(
  BuildContext context,
) {
  return showModalBottomSheet<GoalContributionFormResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    builder: (_) => const _GoalContributionSheet(),
  );
}

class _GoalFormSheet extends StatefulWidget {
  const _GoalFormSheet({this.goal});

  final FinancialGoal? goal;

  @override
  State<_GoalFormSheet> createState() => _GoalFormSheetState();
}

class _GoalFormSheetState extends State<_GoalFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _targetController;
  late GoalIcon _icon;
  DateTime? _targetDate;

  @override
  void initState() {
    super.initState();
    final goal = widget.goal;
    _nameController = TextEditingController(text: goal?.name ?? '');
    _targetController = TextEditingController(
      text: goal == null
          ? ''
          : goal.target.toStringAsFixed(2).replaceAll('.', ','),
    );
    _icon = goal?.icon ?? GoalIcon.piggyBank;
    _targetDate = goal?.targetDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final selected = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? DateTime(now.year, now.month + 1, now.day),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 20, 12, 31),
    );
    if (selected != null && mounted) {
      setState(() => _targetDate = selected);
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final target = Formatters.parseMoney(_targetController.text);

    Navigator.of(context).pop(
      GoalFormResult(
        name: _nameController.text.trim(),
        target: target,
        targetDate: _targetDate,
        icon: _icon,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final border = AppColors.border(brightness);
    final editing = widget.goal != null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  editing ? 'editar meta' : 'nova meta',
                  style: AppTypography.section(context, fontSize: 21, color: primary),
                ),
                const SizedBox(height: 6),
                Text(
                  'um objetivo pra acumular, sem mexer no seu orçamento mensal.',
                  style: AppTypography.body(context, fontSize: 12, color: secondary),
                ),
                const SizedBox(height: 22),
                TextFormField(
                  controller: _nameController,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'nome da meta'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Informe o nome da meta.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _targetController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  decoration: const InputDecoration(
                    labelText: 'valor alvo',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (Formatters.parseMoney(value ?? '') <= 0) {
                      return 'Informe um valor maior que zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                Text(
                  'prazo',
                  style: AppTypography.label(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _pickDate,
                  child: Row(
                    children: [
                      const Icon(AppIcons.calendar, size: 19),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _targetDate == null
                              ? 'sem prazo'
                              : Formatters.fullDate.format(_targetDate!),
                          textAlign: TextAlign.left,
                        ),
                      ),
                      if (_targetDate != null)
                        IconButton(
                          tooltip: 'remover prazo',
                          onPressed: () => setState(() => _targetDate = null),
                          icon: const Icon(AppIcons.close, size: 18),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'ícone',
                  style: AppTypography.label(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: GoalIcon.values.map((icon) {
                    final selected = icon == _icon;
                    return ChoiceChip(
                      selected: selected,
                      onSelected: (_) => setState(() => _icon = icon),
                      avatar: Icon(
                        GoalIconVisuals.iconFor(icon),
                        size: 18,
                        color: selected ? purple : secondary,
                      ),
                      label: Text(GoalIconVisuals.labelFor(icon)),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submit,
                  child: Text(editing ? 'salvar alterações' : 'criar meta'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoalContributionSheet extends StatefulWidget {
  const _GoalContributionSheet();

  @override
  State<_GoalContributionSheet> createState() => _GoalContributionSheetState();
}

class _GoalContributionSheetState extends State<_GoalContributionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  DateTime _date = DateTime.now();

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (selected != null && mounted) setState(() => _date = selected);
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    final amount = Formatters.parseMoney(_amountController.text);
    final note = _noteController.text.trim();

    Navigator.of(context).pop(
      GoalContributionFormResult(
        amount: amount,
        date: _date,
        note: note.isEmpty ? null : note,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        14,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: border,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  'fazer aporte',
                  style: AppTypography.section(context, fontSize: 21, color: primary),
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _amountController,
                  autofocus: true,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'valor',
                    prefixText: 'R\$ ',
                  ),
                  validator: (value) {
                    if (Formatters.parseMoney(value ?? '') <= 0) {
                      return 'Informe um valor maior que zero.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(AppIcons.calendar, size: 18),
                  label: Text(Formatters.fullDate.format(_date)),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _noteController,
                  textCapitalization: TextCapitalization.sentences,
                  maxLength: 300,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'nota (opcional)',
                  ),
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: purple.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: purple.withValues(alpha: .16)),
                  ),
                  child: Text(
                    'o aporte registra o progresso da meta. Ele não movimenta sua conta automaticamente.',
                    style: AppTypography.body(context, fontSize: 11, color: secondary),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _submit,
                  child: const Text('registrar aporte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
