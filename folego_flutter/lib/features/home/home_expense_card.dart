import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/home_expense_summary.dart';
import '../../shared/widgets/category_icon_badge.dart';

class HomeExpenseCard extends StatelessWidget {
  const HomeExpenseCard({
    super.key,
    required this.breakdown,
    required this.unavailable,
  });

  final HomeExpenseBreakdown breakdown;
  final bool unavailable;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: border),
      ),
      child: unavailable
          ? _EmptyExpenses(
              message: 'não foi possível carregar seus gastos agora',
              primaryText: primaryText,
              secondaryText: secondaryText,
            )
          : breakdown.isEmpty
          ? _EmptyExpenses(
              message: 'sem gastos neste período',
              primaryText: primaryText,
              secondaryText: secondaryText,
            )
          : LayoutBuilder(
              builder: (context, constraints) {
                final horizontal = constraints.maxWidth >= 560;
                final donut = _ExpenseDonut(
                  breakdown: breakdown,
                  brightness: brightness,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                  border: border,
                );
                final legend = _ExpenseLegend(
                  breakdown: breakdown,
                  brightness: brightness,
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                );

                if (horizontal) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      donut,
                      const SizedBox(width: 28),
                      Expanded(child: legend),
                    ],
                  );
                }

                return Column(
                  children: [
                    donut,
                    const SizedBox(height: 22),
                    legend,
                  ],
                );
              },
            ),
    );
  }
}

class _EmptyExpenses extends StatelessWidget {
  const _EmptyExpenses({
    required this.message,
    required this.primaryText,
    required this.secondaryText,
  });

  final String message;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          CategoryIconBadge(
            icon: CategoryVisuals.iconFor(category: 'A classificar'),
            color: CategoryVisuals.colorFor(
              category: 'A classificar',
              brightness: Theme.of(context).brightness,
            ),
            size: 46,
            iconSize: 22,
            radius: 15,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'a Home continua leve e atualiza quando houver movimento',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _ExpenseDonut extends StatelessWidget {
  const _ExpenseDonut({
    required this.breakdown,
    required this.brightness,
    required this.primaryText,
    required this.secondaryText,
    required this.border,
  });

  final HomeExpenseBreakdown breakdown;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;
  final Color border;

  @override
  Widget build(BuildContext context) {
    final slices = breakdown.categories
        .map(
          (item) => _DonutSlice(
            share: item.share,
            color: CategoryVisuals.colorFor(
              category: item.category,
              brightness: brightness,
            ),
          ),
        )
        .toList(growable: false);

    final semantics = breakdown.categories
        .map(
          (item) =>
              '${item.category}, ${item.percentage} por cento, ${Formatters.money(item.amount)}',
        )
        .join('; ');

    return Semantics(
      label: 'Distribuição dos gastos do mês: $semantics',
      child: SizedBox(
        width: 178,
        height: 178,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
          builder: (context, progress, _) {
            return Stack(
              alignment: Alignment.center,
              children: [
                CustomPaint(
                  size: const Size.square(178),
                  painter: _DonutPainter(
                    slices: slices,
                    trackColor: border.withValues(alpha: .65),
                    progress: progress,
                  ),
                ),
                SizedBox(
                  width: 118,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'no mês',
                        style: AppTypography.label(
                          context,
                          fontSize: 10,
                          color: secondaryText,
                        ),
                      ),
                      const SizedBox(height: 5),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          Formatters.money(breakdown.total),
                          style: AppTypography.money(
                            context,
                            fontSize: 19,
                            color: primaryText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ExpenseLegend extends StatelessWidget {
  const _ExpenseLegend({
    required this.breakdown,
    required this.brightness,
    required this.primaryText,
    required this.secondaryText,
  });

  final HomeExpenseBreakdown breakdown;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var index = 0; index < breakdown.categories.length; index++) ...[
          _ExpenseLegendRow(
            item: breakdown.categories[index],
            brightness: brightness,
            primaryText: primaryText,
            secondaryText: secondaryText,
          ),
          if (index != breakdown.categories.length - 1)
            const SizedBox(height: 13),
        ],
      ],
    );
  }
}

class _ExpenseLegendRow extends StatelessWidget {
  const _ExpenseLegendRow({
    required this.item,
    required this.brightness,
    required this.primaryText,
    required this.secondaryText,
  });

  final HomeCategoryExpense item;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;

  @override
  Widget build(BuildContext context) {
    final color = CategoryVisuals.colorFor(
      category: item.category,
      brightness: brightness,
    );

    return Row(
      children: [
        CategoryIconBadge(
          icon: CategoryVisuals.iconFor(category: item.category),
          color: color,
          size: 36,
          iconSize: 18,
          radius: 12,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.category.toLowerCase(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${item.percentage}% dos gastos',
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  color: secondaryText,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            Formatters.money(item.amount),
            style: AppTypography.money(
              context,
              fontSize: 13,
              color: primaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _DonutSlice {
  const _DonutSlice({required this.share, required this.color});

  final double share;
  final Color color;
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.trackColor,
    required this.progress,
  });

  final List<_DonutSlice> slices;
  final Color trackColor;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const strokeWidth = 18.0;
    final radius = math.min(size.width, size.height) / 2 - strokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, track);

    var startAngle = -math.pi / 2;
    final gap = slices.length > 1 ? 0.025 : 0.0;

    for (final slice in slices) {
      final rawSweep = math.pi * 2 * slice.share * progress;
      final sweep = math.max(0.0, rawSweep - gap);
      if (sweep > 0) {
        final paint = Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.butt;
        canvas.drawArc(rect, startAngle, sweep, false, paint);
      }
      startAngle += rawSweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.slices != slices;
  }
}
