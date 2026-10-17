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
import '../../shared/widgets/app_section_header.dart';
import 'goal_detail_screen.dart';
import 'goal_form_sheet.dart';
import 'goals_widgets.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  List<FinancialGoal> _goals = const [];
  bool _loading = true;
  bool _saving = false;
  bool _showCompleted = false;
  String? _error;

  List<FinancialGoal> get _active =>
      _goals.where((goal) => goal.status == GoalStatus.active).toList();

  List<FinancialGoal> get _completed =>
      _goals.where((goal) => goal.status == GoalStatus.completed).toList();

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
      final goals = await widget.repository.listGoals(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _goals = goals;
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

  Future<void> _createGoal() async {
    if (_saving) return;
    final result = await showGoalFormSheet(context);
    if (result == null || !mounted) return;

    setState(() => _saving = true);
    try {
      await widget.repository.createGoal(
        spaceId: widget.spaceId,
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

  Future<void> _openGoal(FinancialGoal goal) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => GoalDetailScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          goalId: goal.id,
        ),
      ),
    );
    if (mounted) await _load();
  }

  void _message(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final primary = AppColors.primaryText(brightness);
    final layout = AppBreakpoints.of(context);
    final columns = switch (layout) {
      AppLayoutSize.compact => 1,
      AppLayoutSize.medium => 2,
      AppLayoutSize.expanded || AppLayoutSize.wide => 3,
    };

    return ColoredBox(
      color: background,
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 48),
              children: [
                _Header(onCreate: _saving ? null : _createGoal),
                const SizedBox(height: 22),
                if (_loading && _goals.isEmpty)
                  const AppLoadingState(label: 'organizando suas metas')
                else if (_error != null && _goals.isEmpty)
                  AppErrorState(
                    title: 'não consegui carregar suas metas',
                    description: _error,
                    onRetry: _load,
                  )
                else if (_active.isEmpty && _completed.isEmpty)
                  GoalEmptyState(onCreate: _createGoal)
                else ...[
                  _SummaryCard(goals: _active),
                  const SizedBox(height: 28),
                  AppSectionHeader(
                    title: 'metas ativas',
                    subtitle: _active.isEmpty
                        ? 'nenhuma meta ativa agora'
                        : 'o que você está tornando possível',
                  ),
                  const SizedBox(height: 14),
                  if (_active.isEmpty)
                    _SmallEmpty(onCreate: _createGoal)
                  else
                    _GoalGrid(
                      goals: _active,
                      columns: columns,
                      onTap: _openGoal,
                    ),
                  if (_completed.isNotEmpty) ...[
                    const SizedBox(height: 30),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'concluídas',
                            style: AppTypography.section(
                              context,
                              fontSize: 18,
                              color: primary,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => setState(
                            () => _showCompleted = !_showCompleted,
                          ),
                          icon: Icon(
                            _showCompleted
                                ? AppIcons.chevronDown
                                : AppIcons.chevronRight,
                            size: 17,
                          ),
                          label: Text('${_completed.length}'),
                        ),
                      ],
                    ),
                    if (_showCompleted) ...[
                      const SizedBox(height: 12),
                      _GoalGrid(
                        goals: _completed,
                        columns: columns,
                        onTap: _openGoal,
                      ),
                    ],
                  ],
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.onCreate});

  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);

    return AppPageHeader(
      title: 'metas',
      subtitle: 'acumule para um objetivo sem misturar com o orçamento do mês',
      leading: IconButton(
        tooltip: 'voltar',
        onPressed: () => Navigator.of(context).maybePop(),
        icon: const Icon(AppIcons.back),
      ),
      trailing: FilledButton.icon(
        onPressed: onCreate,
        style: FilledButton.styleFrom(
          minimumSize: const Size(0, 42),
          backgroundColor: purple,
          padding: const EdgeInsets.symmetric(horizontal: 14),
        ),
        icon: const Icon(AppIcons.add, size: 18),
        label: const Text('nova meta'),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.goals});

  final List<FinancialGoal> goals;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final total = totalActiveGoalAmount(goals);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(AppIcons.goals, color: purple, size: 25),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    Formatters.money(total),
                    style: AppTypography.money(
                      context,
                      fontSize: 28,
                      color: primary,
                    ),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'guardados nas suas metas',
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: secondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: purple.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              '${goals.length} ativa${goals.length == 1 ? '' : 's'}',
              style: AppTypography.label(
                context,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: purple,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalGrid extends StatelessWidget {
  const _GoalGrid({
    required this.goals,
    required this.columns,
    required this.onTap,
  });

  final List<FinancialGoal> goals;
  final int columns;
  final ValueChanged<FinancialGoal> onTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: goals.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 190,
      ),
      itemBuilder: (context, index) {
        final goal = goals[index];
        return GoalCard(goal: goal, onTap: () => onTap(goal));
      },
    );
  }
}

class _SmallEmpty extends StatelessWidget {
  const _SmallEmpty({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return OutlinedButton.icon(
      onPressed: onCreate,
      icon: const Icon(AppIcons.add, size: 18),
      label: Text(
        'criar uma nova meta',
        style: AppTypography.button(
          context,
          color: AppColors.primaryText(brightness),
        ),
      ),
    );
  }
}
