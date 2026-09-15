import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_goal.dart';

abstract final class GoalIconVisuals {
  static IconData iconFor(GoalIcon icon) {
    return switch (icon) {
      GoalIcon.plane => AppIcons.categoryTravel,
      GoalIcon.deviceLaptop => AppIcons.shoppingElectronics,
      GoalIcon.car => AppIcons.categoryTransport,
      GoalIcon.home => AppIcons.categoryHousing,
      GoalIcon.gift => AppIcons.categoryGifts,
      GoalIcon.piggyBank => AppIcons.savingsGoal,
    };
  }

  static String labelFor(GoalIcon icon) {
    return switch (icon) {
      GoalIcon.plane => 'viagem',
      GoalIcon.deviceLaptop => 'notebook',
      GoalIcon.car => 'carro',
      GoalIcon.home => 'casa',
      GoalIcon.gift => 'presente',
      GoalIcon.piggyBank => 'guardar',
    };
  }
}

class GoalProgressBar extends StatelessWidget {
  const GoalProgressBar({
    super.key,
    required this.progress,
    this.animate = true,
    this.height = 7,
  });

  final double progress;
  final bool animate;
  final double height;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final track = AppColors.border(brightness).withValues(alpha: .75);
    final target = progress.clamp(0.0, 1.0).toDouble();

    Widget bar(double value) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: track),
              FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: value,
                child: ColoredBox(color: purple),
              ),
            ],
          ),
        ),
      );
    }

    if (!animate) return bar(target);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: target),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) => bar(value),
    );
  }
}

class GoalCard extends StatelessWidget {
  const GoalCard({
    super.key,
    required this.goal,
    required this.onTap,
  });

  final FinancialGoal goal;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final completed = goal.isCompleted;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Ink(
          padding: const EdgeInsets.all(17),
          decoration: BoxDecoration(
            color: completed ? surface.withValues(alpha: .72) : surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: completed
                          ? border.withValues(alpha: .55)
                          : purple.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      completed
                          ? AppIcons.check
                          : GoalIconVisuals.iconFor(goal.icon),
                      size: 22,
                      color: completed ? secondary : purple,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          goal.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _deadlineLabel(goal),
                          style: AppTypography.label(
                            context,
                            fontSize: 11,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(AppIcons.chevronRight, size: 18, color: secondary),
                ],
              ),
              const Spacer(),
              Text(
                '${Formatters.money(goal.currentAmount)} de ${Formatters.money(goal.target)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.money(
                  context,
                  fontSize: 15,
                  color: primary,
                ),
              ),
              const SizedBox(height: 11),
              GoalProgressBar(progress: goal.visualProgress),
              const SizedBox(height: 9),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  '${goal.progressPercent}%',
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: completed ? secondary : purple,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String _deadlineLabel(FinancialGoal goal) {
    if (goal.isCompleted && goal.completedAt != null) {
      return 'concluída em ${DateFormat('MMM/yyyy', 'pt_BR').format(goal.completedAt!)}';
    }
    if (goal.targetDate == null) return 'sem prazo';
    return 'até ${DateFormat('MMM/yyyy', 'pt_BR').format(goal.targetDate!)}';
  }
}

class GoalEmptyState extends StatelessWidget {
  const GoalEmptyState({super.key, required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: purple.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(AppIcons.goals, color: purple, size: 27),
          ),
          const SizedBox(height: 17),
          Text(
            'o que você quer tornar possível?',
            textAlign: TextAlign.center,
            style: AppTypography.section(context, fontSize: 19, color: primary),
          ),
          const SizedBox(height: 7),
          Text(
            'crie uma meta e acompanhe o que você já conseguiu acumular.',
            textAlign: TextAlign.center,
            style: AppTypography.body(context, fontSize: 12, color: secondary),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(AppIcons.add, size: 18),
            label: const Text('criar primeira meta'),
          ),
        ],
      ),
    );
  }
}
