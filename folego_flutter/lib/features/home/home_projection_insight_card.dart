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
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(AppRadii.card),
            border: Border.all(color: border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(AppIcons.chartLine, color: accent, size: 17),
                        const SizedBox(width: 7),
                        Text(
                          'projeção',
                          style: AppTypography.label(
                            context,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: accent,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'mantendo o ritmo atual, ${_monthName(current.month)} fecha em',
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: secondary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      Formatters.money(current.closingProjected),
                      style: AppTypography.money(
                        context,
                        fontSize: 21,
                        color: current.closingProjected < 0
                            ? AppColors.expenseText(brightness)
                            : primary,
                      ),
                    ),
                    if (next != null && nextDelta != null) ...[
                      const SizedBox(height: 6),
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
              const SizedBox(width: 10),
              Padding(
                padding: const EdgeInsets.only(top: 20),
                child: Icon(
                  AppIcons.chevronRight,
                  size: 20,
                  color: secondary,
                ),
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
    return '$month segue estável · ${Formatters.money(next.closingProjected)}';
  }
  final direction = delta > 0 ? 'ganha' : 'perde';
  return '$month $direction ${Formatters.money(delta.abs())} de fôlego · fecha em ${Formatters.money(next.closingProjected)}';
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
