import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/error_translator.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_goal.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_goals.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import 'goal_form_sheet.dart';
import 'goals_widgets.dart';

class GoalDetailScreen extends StatefulWidget {
  const GoalDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.goalId,
  });

  final FolegoRepository repository;
  final String spaceId;
  final String goalId;

  @override
  State<GoalDetailScreen> createState() => _GoalDetailScreenState();
}

class _GoalDetailScreenState extends State<GoalDetailScreen> {
  GoalDetails? _details;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final details = await widget.repository.getGoalDetails(
        spaceId: widget.spaceId,
        goalId: widget.goalId,
      );
      if (!mounted) return;
      setState(() {
        _details = details;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = ErrorTranslator.forDisplay(error);
      });
    }
  }

  Future<void> _editGoal() async {
    final goal = _details?.goal;
    if (goal == null || _saving) return;
    final result = await showGoalFormSheet(context, goal: goal);
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repository.updateGoal(
        spaceId: widget.spaceId,
        goalId: goal.id,
        name: result.name,
        target: result.target,
        targetDate: result.targetDate,
        icon: result.icon,
      );
      await _load();
    } catch (error) {
      if (mounted) _message(ErrorTranslator.forDisplay(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addContribution() async {
    final goal = _details?.goal;
    if (goal == null || goal.isArchived || _saving) return;
    final result = await showGoalContributionSheet(context);
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repository.addGoalContribution(
        spaceId: widget.spaceId,
        goalId: goal.id,
        amount: result.amount,
        contributedAt: result.date,
        note: result.note,
      );
      await _load();
    } catch (error) {
      if (mounted) _message(ErrorTranslator.forDisplay(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _archiveGoal() async {
    final goal = _details?.goal;
    if (goal == null || _saving) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('arquivar meta?'),
        content: const Text(
          'o histórico de aportes será preservado. A meta só sai da lista principal.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('arquivar'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    setState(() => _saving = true);
    try {
      await widget.repository.archiveGoal(
        spaceId: widget.spaceId,
        goalId: goal.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) _message(ErrorTranslator.forDisplay(error));
      if (mounted) setState(() => _saving = false);
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final layout = AppBreakpoints.of(context);
    final wide = layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    if (_loading && _details == null) {
      return ColoredBox(
        color: background,
        child: const SafeArea(
          child: AppLoadingState(label: 'organizando os detalhes da meta'),
        ),
      );
    }

    if (_error != null && _details == null) {
      return ColoredBox(
        color: background,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: AppErrorState(
                title: 'não consegui carregar esta meta',
                description: _error,
                onRetry: _load,
              ),
            ),
          ),
        ),
      );
    }

    final details = _details!;
    final goal = details.goal;
    final progress = _ProgressCard(
      goal: goal,
      saving: _saving,
      onContribution: _addContribution,
    );
    final history = _HistoryCard(contributions: details.contributions);

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 18, 0, 42),
            children: [
              AppPageHeader(
                title: goal.name,
                subtitle: 'progresso, aportes e histórico desta meta',
                leading: IconButton(
                  tooltip: 'voltar',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(AppIcons.back),
                ),
                trailing: IconButton(
                  tooltip: 'editar meta',
                  onPressed: _saving ? null : _editGoal,
                  icon: const Icon(AppIcons.edit),
                ),
              ),
              const SizedBox(height: 22),
              if (wide)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: progress),
                    const SizedBox(width: 24),
                    Expanded(flex: 6, child: history),
                  ],
                )
              else ...[
                progress,
                const SizedBox(height: 24),
                history,
              ],
              const SizedBox(height: 22),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _saving ? null : _archiveGoal,
                  icon: const Icon(AppIcons.warning, size: 17),
                  label: const Text('arquivar meta'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard({
    required this.goal,
    required this.saving,
    required this.onContribution,
  });

  final FinancialGoal goal;
  final bool saving;
  final VoidCallback onContribution;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(AppRadii.compactCard),
                ),
                child: Icon(
                  GoalIconVisuals.iconFor(goal.icon),
                  color: purple,
                  size: 25,
                ),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Text(
                  goal.isCompleted
                      ? 'meta concluída ✨'
                      : goal.isArchived
                      ? 'meta arquivada'
                      : 'seu progresso',
                  style: AppTypography.section(
                    context,
                    fontSize: 17,
                    color: primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            Formatters.money(goal.currentAmount),
            style: AppTypography.money(context, fontSize: 35, color: primary),
          ),
          const SizedBox(height: 4),
          Text(
            'de ${Formatters.money(goal.target)}',
            style: AppTypography.body(context, fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 18),
          GoalProgressBar(progress: goal.visualProgress, height: 8),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${goal.progressPercent}%',
                style: AppTypography.label(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: purple,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  goal.remaining > 0
                      ? 'faltam ${Formatters.money(goal.remaining)} pra fechar'
                      : 'alvo alcançado',
                  textAlign: TextAlign.right,
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
          if (goal.targetDate != null) ...[
            const SizedBox(height: 15),
            Row(
              children: [
                Icon(AppIcons.calendar, size: 16, color: secondary),
                const SizedBox(width: 7),
                Text(
                  'prazo ${Formatters.fullDate.format(goal.targetDate!)}',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ],
          if (!goal.isArchived) ...[
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: saving ? null : onContribution,
              icon: saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.add, size: 18),
              label: const Text('fazer aporte'),
            ),
            const SizedBox(height: 10),
            Text(
              'o aporte acompanha a meta e não movimenta sua conta automaticamente.',
              textAlign: TextAlign.center,
              style: AppTypography.label(
                context,
                fontSize: 10,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.contributions});

  final List<GoalContribution> contributions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final positive = AppColors.positiveText(brightness);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'histórico de aportes',
            style: AppTypography.section(context, fontSize: 18, color: primary),
          ),
          const SizedBox(height: 15),
          if (contributions.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'ainda não há aportes nesta meta.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: secondary,
                ),
              ),
            )
          else
            ...contributions.map(
              (contribution) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: positive.withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(AppRadii.control),
                      ),
                      child: Icon(AppIcons.add, size: 19, color: positive),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            Formatters.shortDate.format(contribution.contributedAt),
                            style: AppTypography.body(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: primary,
                            ),
                          ),
                          if (contribution.note?.isNotEmpty == true) ...[
                            const SizedBox(height: 3),
                            Text(
                              contribution.note!,
                              style: AppTypography.body(
                                context,
                                fontSize: 11,
                                color: secondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '+ ${Formatters.money(contribution.amount)}',
                      style: AppTypography.money(
                        context,
                        fontSize: 14,
                        color: positive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
