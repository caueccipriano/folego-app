import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/home_expense_summary.dart';
import '../../shared/widgets/category_icon_badge.dart';
import 'home_expense_navigation_scope.dart';
import 'home_spending_palette.dart';

class HomeExpenseCard extends StatefulWidget {
  const HomeExpenseCard({
    super.key,
    required this.breakdown,
    required this.unavailable,
    this.onCategoryTap,
    this.onTotalTap,
  });

  final HomeExpenseBreakdown breakdown;
  final bool unavailable;
  final ValueChanged<HomeCategoryExpense>? onCategoryTap;
  final VoidCallback? onTotalTap;

  @override
  State<HomeExpenseCard> createState() => _HomeExpenseCardState();
}

class _HomeExpenseCardState extends State<HomeExpenseCard> {
  int? _highlightedIndex;

  void _openCategory(HomeCategoryExpense item) {
    final callback = widget.onCategoryTap;
    if (callback != null) {
      callback(item);
      return;
    }
    if (item.categoryId != null) {
      HomeExpenseNavigationScope.maybeOf(context)
          ?.onOpenExpenses(item.categoryId);
    }
  }

  void _openTotal() {
    final callback = widget.onTotalTap;
    if (callback != null) {
      callback();
      return;
    }
    HomeExpenseNavigationScope.maybeOf(context)?.onOpenExpenses(null);
  }

  Future<void> _activateCategory(HomeCategoryExpense item) async {
    if (!item.isOther) {
      _openCategory(item);
      return;
    }

    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    final content = _OtherBreakdown(
      item: item,
      onCategoryTap: (category) {
        Navigator.of(context).pop();
        _openCategory(category);
      },
    );

    if (compact) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        builder: (_) => content,
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (_) => Dialog(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520, maxHeight: 620),
            child: content,
          ),
        ),
      );
    }
  }

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
      child: widget.unavailable
          ? _EmptyExpenses(
              message: 'não foi possível carregar seus gastos agora',
              primaryText: primaryText,
              secondaryText: secondaryText,
            )
          : widget.breakdown.isEmpty
              ? _EmptyExpenses(
                  message: 'sem gastos neste período',
                  primaryText: primaryText,
                  secondaryText: secondaryText,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final horizontal = constraints.maxWidth >= 560;
                    final donut = _ExpenseDonut(
                      breakdown: widget.breakdown,
                      brightness: brightness,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      border: border,
                      highlightedIndex: _highlightedIndex,
                      onHoverIndex: (index) {
                        if (_highlightedIndex == index) return;
                        setState(() => _highlightedIndex = index);
                      },
                      onCategoryTap: (index) =>
                          _activateCategory(widget.breakdown.categories[index]),
                      onTotalTap: _openTotal,
                    );
                    final legend = _ExpenseLegend(
                      breakdown: widget.breakdown,
                      brightness: brightness,
                      primaryText: primaryText,
                      secondaryText: secondaryText,
                      highlightedIndex: _highlightedIndex,
                      onHoverIndex: (index) {
                        if (_highlightedIndex == index) return;
                        setState(() => _highlightedIndex = index);
                      },
                      onTap: _activateCategory,
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
    required this.highlightedIndex,
    required this.onHoverIndex,
    required this.onCategoryTap,
    required this.onTotalTap,
  });

  final HomeExpenseBreakdown breakdown;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;
  final Color border;
  final int? highlightedIndex;
  final ValueChanged<int?> onHoverIndex;
  final ValueChanged<int> onCategoryTap;
  final VoidCallback onTotalTap;

  int? _sliceIndex(Offset position) {
    const center = Offset(89, 89);
    final delta = position - center;
    final distance = delta.distance;
    if (distance < 57 || distance > 92) return null;

    var angle = math.atan2(delta.dy, delta.dx) + math.pi / 2;
    if (angle < 0) angle += math.pi * 2;
    final ratio = angle / (math.pi * 2);
    var cumulative = 0.0;
    for (var index = 0; index < breakdown.categories.length; index++) {
      cumulative += breakdown.categories[index].share;
      if (ratio <= cumulative) return index;
    }
    return breakdown.categories.isEmpty ? null : breakdown.categories.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final slices = breakdown.categories
        .map(
          (item) => _DonutSlice(
            share: item.share,
            color: HomeSpendingPalette.colorFor(
              category: item.category,
              categoryId: item.categoryId,
              isOther: item.isOther,
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
      hint: 'toque em uma fatia para ver os lançamentos',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onHover: (event) => onHoverIndex(_sliceIndex(event.localPosition)),
        onExit: (_) => onHoverIndex(null),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final index = _sliceIndex(details.localPosition);
            if (index == null) {
              onTotalTap();
            } else {
              onCategoryTap(index);
            }
          },
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
                        highlightedIndex: highlightedIndex,
                      ),
                    ),
                    IgnorePointer(
                      child: SizedBox(
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
                    ),
                  ],
                );
              },
            ),
          ),
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
    required this.highlightedIndex,
    required this.onHoverIndex,
    required this.onTap,
  });

  final HomeExpenseBreakdown breakdown;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;
  final int? highlightedIndex;
  final ValueChanged<int?> onHoverIndex;
  final ValueChanged<HomeCategoryExpense> onTap;

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
            highlighted: highlightedIndex == index,
            onHover: (hovering) => onHoverIndex(hovering ? index : null),
            onTap: () => onTap(breakdown.categories[index]),
          ),
          if (index != breakdown.categories.length - 1)
            const SizedBox(height: 7),
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
    required this.highlighted,
    required this.onHover,
    required this.onTap,
  });

  final HomeCategoryExpense item;
  final Brightness brightness;
  final Color primaryText;
  final Color secondaryText;
  final bool highlighted;
  final ValueChanged<bool> onHover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = HomeSpendingPalette.colorFor(
      category: item.category,
      categoryId: item.categoryId,
      isOther: item.isOther,
      brightness: brightness,
    );

    return Semantics(
      button: true,
      label:
          '${item.category}, ${Formatters.money(item.amount)}, ${item.percentage}% dos gastos',
      child: Tooltip(
        message:
            '${item.category} · ${Formatters.money(item.amount)} · ${item.percentage}%',
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => onHover(true),
          onExit: (_) => onHover(false),
          child: Material(
            color: highlighted
                ? color.withValues(alpha: .08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
                child: Row(
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
                    Text(
                      Formatters.money(item.amount),
                      style: AppTypography.money(
                        context,
                        fontSize: 13,
                        color: primaryText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtherBreakdown extends StatelessWidget {
  const _OtherBreakdown({required this.item, required this.onCategoryTap});

  final HomeCategoryExpense item;
  final ValueChanged<HomeCategoryExpense> onCategoryTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 8, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'outros gastos',
                    style: AppTypography.section(context, fontSize: 18),
                  ),
                ),
                IconButton(
                  tooltip: 'fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Text(
              '“Outros” junta categorias menores só para deixar o gráfico legível. Escolha uma categoria para ver os lançamentos reais.',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 18),
              itemCount: item.groupedCategories.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, index) {
                final category = item.groupedCategories[index];
                return ListTile(
                  onTap: category.categoryId == null
                      ? null
                      : () => onCategoryTap(category),
                  title: Text(category.category),
                  trailing: Text(
                    Formatters.money(category.amount),
                    style: AppTypography.money(context, fontSize: 12),
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
    required this.highlightedIndex,
  });

  final List<_DonutSlice> slices;
  final Color trackColor;
  final double progress;
  final int? highlightedIndex;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const baseStrokeWidth = 18.0;
    final radius = math.min(size.width, size.height) / 2 - baseStrokeWidth / 2;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final track = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = baseStrokeWidth;
    canvas.drawCircle(center, radius, track);

    var startAngle = -math.pi / 2;
    final gap = slices.length > 1 ? 0.025 : 0.0;

    for (var index = 0; index < slices.length; index++) {
      final slice = slices[index];
      final rawSweep = math.pi * 2 * slice.share * progress;
      final sweep = math.max(0.0, rawSweep - gap);
      if (sweep > 0) {
        final paint = Paint()
          ..color = slice.color
          ..style = PaintingStyle.stroke
          ..strokeWidth = highlightedIndex == index ? 22 : baseStrokeWidth
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
        oldDelegate.slices != slices ||
        oldDelegate.highlightedIndex != highlightedIndex;
  }
}
