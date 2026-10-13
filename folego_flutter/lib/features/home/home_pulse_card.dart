import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'home_pulse_insight.dart';

/// Calm, actionable summary. There are no daily streaks or mandatory tasks.
class HomePulseCard extends StatelessWidget {
  const HomePulseCard({
    super.key,
    required this.insight,
    this.onOpenUpcoming,
    this.onOpenBudget,
  });

  final HomePulseInsight insight;
  final VoidCallback? onOpenUpcoming;
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    final VoidCallback? action = switch (insight.action) {
      HomePulseAction.upcoming => onOpenUpcoming,
      HomePulseAction.budget => onOpenBudget,
      HomePulseAction.none => null,
    };

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-pulse'),
        borderRadius: BorderRadius.circular(AppRadii.card),
        onTap: action,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.card),
            color: surface,
            border: Border.all(color: border),
          ),
          padding: const EdgeInsets.fromLTRB(16, 15, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(AppIcons.chartLine, color: purple, size: 17),
                  const SizedBox(width: 7),
                  Text(
                    'fôlego pulso',
                    style: AppTypography.label(
                      context,
                      color: purple,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'uma coisa para saber',
                    style: AppTypography.label(
                      context,
                      color: secondary,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              Text(
                insight.eyebrow,
                style: AppTypography.label(
                  context,
                  fontSize: 11,
                  color: secondary,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                insight.title,
                key: const ValueKey('home-pulse-title'),
                style: AppTypography.section(
                  context,
                  fontSize: 17,
                  color: primary,
                ),
              ),
              if (insight.amount != null) ...[
                const SizedBox(height: 8),
                Text(
                  Formatters.money(insight.amount),
                  key: const ValueKey('home-pulse-amount'),
                  style: AppTypography.money(
                    context,
                    fontSize: 21,
                    color: primary,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                insight.description,
                key: const ValueKey('home-pulse-description'),
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: secondary,
                ),
              ),
              if (action != null && insight.actionLabel != null) ...[
                const SizedBox(height: 14),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      insight.actionLabel!,
                      style: AppTypography.button(
                        context,
                        fontSize: 12,
                        color: purple,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      AppIcons.chevronRight,
                      size: 16,
                      color: purple,
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
