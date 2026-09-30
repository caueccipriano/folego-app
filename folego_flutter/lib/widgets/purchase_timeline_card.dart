import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/intelligence/purchase_timeline.dart';

/// Optional disclosure within an existing simulation result.
/// Every value comes from the same two official projection calls already made.
class PurchaseTimelineCard extends StatelessWidget {
  const PurchaseTimelineCard({
    super.key,
    required this.months,
  });

  final List<PurchaseTimelineMonth> months;

  @override
  Widget build(BuildContext context) {
    if (months.isEmpty) return const SizedBox.shrink();
    final english = Localizations.localeOf(context).languageCode == 'en';
    final money = NumberFormat.currency(
      locale: english ? 'en_US' : 'pt_BR',
      symbol: english ? r'$' : r'R$',
    );
    final maximumDifference = months.fold<double>(
      0, (previous, month) => math.max(previous, month.difference.abs()),
    );
    final scheme = Theme.of(context).colorScheme;

    return ExpansionTile(
      key: const ValueKey('purchase-timeline'),
      title: Text(
        english ? 'See month-by-month impact' : 'Ver impacto mês a mês',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Text(
        english ? 'Compared with your current projection' :
          'Comparado com sua projeção atual, sem nova simulação',
        style: Theme.of(context).textTheme.bodySmall,
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(bottom: 8),
      children: [
        for (final month in months) ...[
          Semantics(
            container: true,
            label: '${DateFormat('MM/yyyy').format(month.month)}: '
                '${english ? 'current' : 'atual'} ${money.format(month.baselineBalance)}; '
                '${english ? 'with purchase' : 'com compra'} ${money.format(month.purchaseBalance)}; '
                '${english ? 'difference' : 'diferença'} ${money.format(month.difference)}',
            child: ExcludeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(DateFormat('MM/yyyy').format(month.month),
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Row(children: [
                      Expanded(child: _ValuePair(
                        label: english ? 'Current' : 'Atual',
                        value: money.format(month.baselineBalance),
                      )),
                      const SizedBox(width: 12),
                      Expanded(child: _ValuePair(
                        label: english ? 'With purchase' : 'Com a compra',
                        value: money.format(month.purchaseBalance),
                      )),
                    ]),
                    const SizedBox(height: 7),
                    Text(
                      '${english ? 'Difference' : 'Diferença'}: '
                      '${month.difference >= 0 ? '+' : ''}${money.format(month.difference)}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: month.isNegative ? scheme.error : scheme.onSurfaceVariant,
                      ),
                    ),
                    if (maximumDifference > 0) ...[
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (month.difference.abs() / maximumDifference).clamp(0.0, 1.0),
                        minHeight: 4,
                        color: month.isNegative ? scheme.error : scheme.primary,
                        backgroundColor: scheme.surfaceContainerHighest,
                      ),
                    ],
                    if (month.isNegative)
                      Text(english ? 'Negative projected balance' : 'Saldo projetado negativo',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: scheme.error),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            english
              ? 'Bar length compares the magnitude of the difference, not the balance. Estimates only.'
              : 'A barra compara o tamanho da diferença, não o saldo. Valores estimados.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

class _ValuePair extends StatelessWidget {
  const _ValuePair({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      const SizedBox(height: 2),
      Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        fontWeight: FontWeight.w700,
      )),
    ],
  );
}
