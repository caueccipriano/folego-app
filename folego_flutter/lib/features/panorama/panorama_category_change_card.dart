import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'panorama_category_changes.dart';

/// Explanations based only on two complete months of recorded parent
/// categories. No AI calls, personal judgement or implied bank sync.
class PanoramaCategoryChangeCard extends StatelessWidget {
  const PanoramaCategoryChangeCard({
    super.key,
    required this.comparison,
  });

  final PanoramaCategoryChanges? comparison;

  String _month(DateTime value) =>
      '${value.month.toString().padLeft(2, '0')}/${value.year}';

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => _buildContent(context, hidden),
      );

  Widget _buildContent(BuildContext context, bool hidden) {
    final brightness = Theme.of(context).brightness;
    final muted = AppColors.secondaryText(brightness);
    final data = comparison;
    return Container(
      key: const ValueKey('panorama-category-changes'),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'o que mudou por categoria',
            style: AppTypography.section(context, fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            data == null
                ? 'Comparamos somente meses completos quando houver dados.'
                : 'Categorias registradas em ${_month(data.earlierMonth)} '
                    'e ${_month(data.laterMonth)}.',
            style: AppTypography.body(context, fontSize: 11, color: muted),
          ),
          const SizedBox(height: 12),
          if (data == null)
            Text(
              'não foi possível confirmar os dois meses anteriores',
              key: const ValueKey('category-changes-unavailable'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (data.commonCategories == 0)
            Text(
              'não há categorias comparáveis nos dois períodos',
              key: const ValueKey('category-changes-no-common'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else if (data.changes.isEmpty)
            Text(
              'categorias comparáveis sem mudanças registradas',
              key: const ValueKey('category-changes-unchanged'),
              style: AppTypography.body(context, fontSize: 12, color: muted),
            )
          else ...[
            for (final change in data.changes) ...[
              Semantics(
                container: true,
                label: hidden
                    ? '${change.categoryName}: valores ocultos'
                    : '${change.categoryName}: despesas registradas '
                        '${change.increased ? 'aumentaram' : 'diminuíram'}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          change.categoryName,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          hidden
                              ? 'valores ocultos'
                              : '${change.increased ? 'aumentou' : 'diminuiu'} '
                                  '${Formatters.money(change.difference.abs())}',
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
                ),
              ),
            ],
            const SizedBox(height: 7),
            Text(
              'Mostra apenas categorias presentes nos dois meses. '
              'Novas categorias, recategorizações e importações '
              'incompletas podem alterar a comparação. '
              'Não representa todos os gastos sem conferir os lançamentos.',
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
}
