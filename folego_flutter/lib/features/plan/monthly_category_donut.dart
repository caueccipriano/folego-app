import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/budget_overview_item.dart';

/// Parent aggregates already include their children. Never sum both levels.
List<BudgetOverviewItem> monthlyCategorySlices(
  Iterable<BudgetOverviewItem> items,
) =>
    items
        .where(
          (i) => i.isParent && i.actualAmount.isFinite && i.actualAmount > 0,
        )
        .toList()
      ..sort((a, b) => b.actualAmount.compareTo(a.actualAmount));

/// Match the painted ring, excluding its center and outside area.
int? monthlyCategoryHit(Offset position, double diameter, List<double> values) {
  final delta = position - Offset(diameter / 2, diameter / 2);
  final radius = diameter / 2 - 13;
  if ((delta.distance - radius).abs() > 11) return null;
  final total = values.fold<double>(0, (sum, value) => sum + value);
  if (total <= 0 || !total.isFinite) return null;
  final angle = (math.atan2(delta.dy, delta.dx) + math.pi / 2) % (2 * math.pi);
  var end = 0.0;
  for (var index = 0; index < values.length; index++) {
    end += values[index] / total * 2 * math.pi;
    if (angle < end) return index;
  }
  return null;
}

class MonthlyCategoryDonut extends StatefulWidget {
  const MonthlyCategoryDonut({
    super.key,
    required this.items,
    required this.onCategory,
  });
  final List<BudgetOverviewItem> items;
  final ValueChanged<BudgetOverviewItem> onCategory;
  @override
  State<MonthlyCategoryDonut> createState() => _MonthlyCategoryDonutState();
}

class _MonthlyCategoryDonutState extends State<MonthlyCategoryDonut> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: FinancialPrivacy.hidden,
    builder: (context, hidden, _) {
      final brightness = Theme.of(context).brightness;
      final rows = monthlyCategorySlices(widget.items);
      final total = rows.fold<double>(0, (sum, row) => sum + row.actualAmount);
      final credits = widget.items
          .where(
            (i) => i.isParent && i.actualAmount.isFinite && i.actualAmount < 0,
          )
          .fold<double>(0, (sum, row) => sum - row.actualAmount);
      final visible = _expanded ? rows : rows.take(5).toList();
      final colors = rows
          .map(
            (i) => CategoryVisuals.colorFor(
              category: i.categoryName,
              brightness: brightness,
            ),
          )
          .toList();
      return Material(
        key: const ValueKey('monthly-category-donut'),
        color: AppColors.surface(brightness),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.feature),
          side: BorderSide(color: AppColors.border(brightness)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'seu mês por categoria',
                style: AppTypography.section(context, fontSize: 17),
              ),
              const SizedBox(height: 8),
              Text(
                'Veja como os gastos se distribuem neste mês.',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
              const SizedBox(height: 16),
              if (hidden)
                Text(
                  'gráfico e proporções ocultos pelo modo de privacidade',
                  key: const ValueKey('category-donut-hidden'),
                  style: AppTypography.body(context, fontSize: 12),
                )
              else if (rows.isEmpty)
                Text(
                  'ainda não há gastos positivos por categoria neste mês',
                  style: AppTypography.body(context, fontSize: 12),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final diameter = math.min(200.0, constraints.maxWidth);
                    return Center(
                      child: Semantics(
                        label: 'Distribuição dos gastos por categoria; valores na lista abaixo',
                        child: SizedBox.square(
                          dimension: diameter,
                          child: GestureDetector(
                            onTapUp: (event) {
                              final index = monthlyCategoryHit(
                                event.localPosition,
                                diameter,
                                rows.map((i) => i.actualAmount).toList(),
                              );
                              if (index != null) widget.onCategory(rows[index]);
                            },
                            child: CustomPaint(
                              key: const ValueKey('category-donut-paint'),
                              painter: _CategoryDonutPainter(
                                values: rows
                                    .map((i) => i.actualAmount)
                                    .toList(),
                                colors: colors,
                                track: AppColors.border(brightness),
                              ),
                              child: Center(
                                child: SizedBox(
                                  key: const ValueKey('category-donut-center'),
                                  width: diameter * .60,
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          Formatters.money(total),
                                          maxLines: 1,
                                          style: AppTypography.money(
                                            context,
                                            fontSize: 20,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'neste gráfico',
                                        textAlign: TextAlign.center,
                                        style: AppTypography.body(
                                          context,
                                          fontSize: 11,
                                          color: AppColors.secondaryText(
                                            brightness,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              if (rows.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Toque em uma categoria para ver os lançamentos.',
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              for (final row in visible)
                _categoryRow(context, row, total, hidden, brightness),
              if (rows.length > 5)
                TextButton(
                  onPressed: () => setState(() => _expanded = !_expanded),
                  child: Text(
                    _expanded
                        ? 'mostrar menos'
                        : 'ver todas as ${rows.length} categorias',
                  ),
                ),
              if (credits > 0) ...[
                const SizedBox(height: 8),
                Text(
                  'Há ${Formatters.money(credits)} em créditos líquidos fora do gráfico.',
                  style: AppTypography.body(context, fontSize: 11),
                ),
              ],
              const SizedBox(height: 8),
              ExpansionTile(
                key: const ValueKey('category-donut-explanation'),
                tilePadding: EdgeInsets.zero,
                childrenPadding: const EdgeInsets.only(bottom: 12),
                dense: true,
                shape: const Border(),
                collapsedShape: const Border(),
                title: Text(
                  'Como esse gráfico é calculado',
                  style: AppTypography.body(context, fontSize: 12),
                ),
                children: [
                  Text(
                    'Parcelas entram no mês do Plano. Pagar a fatura não conta como outra compra. '
                    'O gráfico reúne os valores líquidos positivos de todas as categorias, incluindo estornos, '
                    'mesmo quando a lista está resumida. Categorias com créditos líquidos ficam de fora; '
                    'por isso o valor no centro pode diferir do gasto líquido do Plano. '
                    'Não representa saídas bancárias nem saldo disponível.',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: AppColors.secondaryText(brightness),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );

  Widget _categoryRow(
    BuildContext context,
    BudgetOverviewItem row,
    double total,
    bool hidden,
    Brightness brightness,
  ) => InkWell(
    key: ValueKey('category-donut-${row.categoryId}'),
    borderRadius: BorderRadius.circular(AppRadii.control),
    onTap: () => widget.onCategory(row),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: CategoryVisuals.colorFor(
                category: row.categoryName,
                brightness: brightness,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 260 ||
                    MediaQuery.textScalerOf(context).scale(13) > 17;
                final name = Text(
                  row.categoryName,
                  style: AppTypography.body(context, fontSize: 13),
                );
                final amount = Text(
                  Formatters.money(row.actualAmount),
                  style: AppTypography.money(context, fontSize: 13),
                );
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (stacked) ...[
                      name,
                      const SizedBox(height: 4),
                      amount,
                    ] else
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: name),
                          const SizedBox(width: 12),
                          amount,
                        ],
                      ),
                    const SizedBox(height: 3),
                    Text(
                      hidden
                          ? 'proporção oculta'
                          : '${(row.actualAmount / total * 100).toStringAsFixed(1).replaceAll('.', ',')}% do gráfico',
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(width: 6),
          Icon(
            Icons.chevron_right_rounded,
            size: 18,
            color: AppColors.secondaryText(brightness),
          ),
        ],
      ),
    ),
  );
}

class _CategoryDonutPainter extends CustomPainter {
  const _CategoryDonutPainter({
    required this.values,
    required this.colors,
    required this.track,
  });
  final List<double> values;
  final List<Color> colors;
  final Color track;
  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: math.min(size.width, size.height) / 2 - 13,
    );
    final brush = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..color = track;
    canvas.drawArc(rect, 0, 2 * math.pi, false, brush);
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return;
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi;
      brush.color = colors[i];
      canvas.drawArc(rect, start, sweep, false, brush);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _CategoryDonutPainter oldDelegate) =>
      track != oldDelegate.track ||
      !listEquals(values, oldDelegate.values) ||
      !listEquals(colors, oldDelegate.colors);
}
