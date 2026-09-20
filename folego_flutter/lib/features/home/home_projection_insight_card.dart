import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/projection_model.dart';

class HomeProjectionInsightCard extends StatelessWidget {
  const HomeProjectionInsightCard({
    super.key,
    required this.projection,
    required this.unavailable,
    required this.onOpen,
  });

  final ProjectionResult? projection;
  final bool unavailable;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final value = projection;
    if (unavailable || value == null || value.months.isEmpty) {
      return const SizedBox.shrink();
    }

    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final current = value.months.first;
    final next = value.months.length > 1 ? value.months[1] : null;
    final nextDelta = next == null
        ? null
        : next.closingProjected - current.closingProjected;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: const ValueKey('home-projection-insight'),
        onTap: onOpen,
        borderRadius: BorderRadius.circular(AppRadii.card),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: border),
          ),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(AppRadii.control),
                ),
                child: Icon(AppIcons.chartLine, color: accent, size: 22),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'fechamento previsto de ${_monthName(current.month)}',
                      style: AppTypography.body(
                        context,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.money(current.closingProjected),
                      style: AppTypography.money(
                        context,
                        fontSize: 18,
                        color: current.closingProjected < 0
                            ? AppColors.expenseText(brightness)
                            : primary,
                      ),
                    ),
                    if (next != null && nextDelta != null) ...[
                      const SizedBox(height: 5),
                      Text(
                        _nextMonthCopy(next, nextDelta),
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: nextDelta < 0
                              ? AppColors.expenseText(brightness)
                              : secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                children: [
                  Text(
                    'ver projeção',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: accent,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Icon(AppIcons.chevronRight, size: 18, color: accent),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _nextMonthCopy(ProjectionMonth next, double delta) {
  final month = _monthName(next.month);
  if (delta.abs() < .01) {
    return '$month fica estável · fecha em ${Formatters.money(next.closingProjected)}';
  }
  final direction = delta > 0 ? 'melhora' : 'piora';
  return '$month $direction ${Formatters.money(delta.abs())} · fecha em ${Formatters.money(next.closingProjected)}';
}

String _monthName(DateTime value) {
  const names = [
    'janeiro',
    'fevereiro',
    'março',
    'abril',
    'maio',
    'junho',
    'julho',
    'agosto',
    'setembro',
    'outubro',
    'novembro',
    'dezembro',
  ];
  return names[value.month - 1];
}
