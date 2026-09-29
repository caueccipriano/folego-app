import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'panorama_category_trend.dart';

/// Informational only. Comparable completed-month parent categories, never
/// implied complete bank coverage or an automatically inferred missing zero.
class PanoramaCategoryComparison extends StatelessWidget {
  const PanoramaCategoryComparison({super.key, required this.trend});

  final PanoramaCategoryTrend? trend;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => _buildContent(context, hidden),
      );

  Widget _buildContent(BuildContext context, bool hidden) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.secondaryText(brightness);
    final value = trend;
    return Container(
      key: const ValueKey('panorama-category-comparison'),
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
                size: 19,
                color: AppColors.primaryPurple(brightness),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'mudanças por categoria',
                  style: AppTypography.section(context, fontSize: 13),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            'Comparação dos últimos dois meses encerrados. '
            'Apenas categorias principais presentes em ambos.',
            style: AppTypography.body(context, fontSize: 11, color: muted),
          ),
          const SizedBox(height: 12),
          if (hidden)
            Text(
              'histórico oculto pelo modo de privacidade',
              key: const ValueKey('panorama-category-hidden'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (value == null)
            Text(
              'comparação indisponível: não foi possível confirmar ambos os meses',
              key: const ValueKey('panorama-category-unavailable'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (value.allComparableCount == 0)
            Text(
              'não há categorias principais comparáveis entre esses meses',
              key: const ValueKey('panorama-category-no-match'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (value.largestChanges.isEmpty)
            Text(
              'sem variação nas categorias registradas em ambos os meses',
              key: const ValueKey('panorama-category-no-change'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else ...[
            for (final item in value.largestChanges)
              Semantics(
                label: item.currentName,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          item.currentName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(context, fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          item.delta > 0
                              ? '${Formatters.money(item.delta.abs())} a mais'
                              : '${Formatters.money(item.delta.abs())} a menos',
                          maxLines: 1,
                          textAlign: TextAlign.right,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context, fontSize: 11, color: muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
          const SizedBox(height: 8),
          Text(
            'Considera apenas despesas registradas e categorias ainda ativas. '
            'Não inclui automaticamente movimentações ausentes de extratos.',
            style: AppTypography.body(context, fontSize: 10, color: muted),
          ),
        ],
      ),
    );
  }
}
