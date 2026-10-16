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
                'Como os gastos do orçamento se distribuem no mês selecionado. '
                'Parcelas contam no mês do Plano; pagar a fatura não soma outra compra.',
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
                Center(
                  child: Semantics(
                    label: 'Distribuição dos gastos por categoria; valores na lista abaixo',
                    child: SizedBox(
                      width: 200,
                      height: 200,
                      child: CustomPaint(
                        key: const ValueKey('category-donut-paint'),
                        painter: _CategoryDonutPainter(
                          values: rows.map((i) => i.actualAmount).toList(),
                          colors: colors,
                          track: AppColors.border(brightness),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                Formatters.money(total),
                                style: AppTypography.money(
                                  context,
                                  fontSize: 17,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'nas categorias acima de zero',
                                textAlign: TextAlign.center,
                                style: AppTypography.body(
                                  context,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              for (final row in visible)
                ListTile(
                  key: ValueKey('category-donut-${row.categoryId}'),
                  contentPadding: EdgeInsets.zero,
                  onTap: () => widget.onCategory(row),
                  leading: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: CategoryVisuals.colorFor(
                        category: row.categoryName,
                        brightness: brightness,
                      ),
                    ),
                  ),
                  title: Text(
                    row.categoryName,
                    style: AppTypography.body(context, fontSize: 13),
                  ),
                  subtitle: Text(
                    hidden
                        ? 'proporção oculta'
                        : '${(row.actualAmount / total * 100).toStringAsFixed(1).replaceAll('.', ',')}% · ver lançamentos',
                    style: AppTypography.body(context, fontSize: 11),
                  ),
                  trailing: Text(
                    Formatters.money(row.actualAmount),
                    style: AppTypography.money(context, fontSize: 13),
                  ),
                ),
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
                  'Categorias com créditos líquidos: ${Formatters.money(credits)}. '
                  'Elas ficam fora da rosca; por isso o centro pode diferir do gasto líquido total do Plano.',
                  style: AppTypography.body(context, fontSize: 11),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                'A rosca inclui todas as categorias positivas, mesmo quando a lista está resumida. '
                'Valores líquidos por categoria, incluindo estornos. Não representa saídas bancárias nem saldo disponível.',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ),
        ),
      );
    },
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
