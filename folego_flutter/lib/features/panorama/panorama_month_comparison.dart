import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'panorama_month_trend.dart';

/// All-user, read-only comparison of two COMPLETE recorded economic months.
/// No percentages against zero and no misleading current-month vs full-month
/// comparisons. Formatters.money also respects global financial privacy mode.
class PanoramaMonthComparison extends StatelessWidget {
  const PanoramaMonthComparison({super.key, required this.trend});

  final PanoramaClosedMonthTrend? trend;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, _, _) => _buildCard(context),
      );

  Widget _buildCard(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final color = AppColors.primaryText(brightness);
    final muted = AppColors.secondaryText(brightness);
    final data = trend;
    return Container(
      key: const ValueKey('panorama-month-comparison'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                AppIcons.plan,
                color: AppColors.primaryPurple(brightness),
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'evolução financeira',
                  style: AppTypography.section(context, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Dois meses encerrados · movimentações registradas, '
            'não uma previsão.',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: muted,
            ),
          ),
          const SizedBox(height: 13),
          if (data == null)
            Text(
              'não foi possível confirmar os dois meses anteriores',
              key: const ValueKey('panorama-trend-unavailable'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (data.bothMonthsWithoutRecordedMovements)
            Text(
              'nenhuma movimentação registrada nos períodos consultados',
              key: const ValueKey('panorama-trend-recorded-empty'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else ...[
            Row(
              children: [
                const Expanded(flex: 3, child: SizedBox.shrink()),
                Expanded(
                  flex: 4,
                  child: Text(
                    _monthLabel(data.earlier.periodMonth),
                    textAlign: TextAlign.end,
                    style: AppTypography.body(
                      context,
                      fontSize: 11,
                      color: muted,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 4,
                  child: Text(
                    _monthLabel(data.later.periodMonth),
                    textAlign: TextAlign.end,
                    style: AppTypography.body(
                      context,
                      fontSize: 11,
                      color: muted,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _valueRow(
              context,
              label: 'receitas',
              earlier: data.earlierIncome,
              later: data.laterIncome,
              color: color,
            ),
            _valueRow(
              context,
              label: 'despesas',
              earlier: data.earlierExpenses,
              later: data.laterExpenses,
              color: color,
            ),
            Divider(color: AppColors.border(brightness)),
            _valueRow(
              context,
              label: 'resultado',
              earlier: data.earlierResult,
              later: data.laterResult,
              color: color,
            ),
            const SizedBox(height: 11),
            Text(
              _expenseChangeDescription(data),
              key: const ValueKey('panorama-trend-expense-change'),
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: muted,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Considera despesas econômicas por competência. '
              'Pagamentos de fatura e transferências não são nova despesa.',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: muted,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // A numeric month/year label is unambiguous and does not require the
  // optional intl DateFormat locale initialization in isolated PWA widgets.
  String _monthLabel(DateTime month) =>
      '${month.month.toString().padLeft(2, '0')}/${month.year}';

  Widget _valueRow(
    BuildContext context, {
    required String label,
    required double earlier,
    required double later,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: AppTypography.body(context, fontSize: 11, color: color),
            ),
          ),
          Expanded(
            flex: 4,
            child: _amount(context, earlier),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 4,
            child: _amount(context, later),
          ),
        ],
      ),
    );
  }

  Widget _amount(BuildContext context, double amount) => Semantics(
        label: Formatters.money(amount),
        child: Align(
          alignment: Alignment.centerRight,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              Formatters.money(amount),
              maxLines: 1,
              style: AppTypography.money(context, fontSize: 11),
            ),
          ),
        ),
      );

  String _expenseChangeDescription(PanoramaClosedMonthTrend trend) {
    final delta = trend.expenseChange;
    if (delta == 0) {
      return 'mesmo valor de despesas registradas nos dois meses';
    }
    final direction = delta > 0 ? 'a mais' : 'a menos';
    return '${Formatters.money(delta.abs())} de despesas registradas '
        '$direction no mês mais recente';
  }
}
