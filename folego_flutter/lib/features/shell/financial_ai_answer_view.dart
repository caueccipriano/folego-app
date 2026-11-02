import 'package:flutter/material.dart';

import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Presentation only: never calculates financial amounts or rewrites model facts.
class FinancialAiAnswerView extends StatelessWidget {
  const FinancialAiAnswerView({
    super.key,
    required this.answer,
  });

  final String answer;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lines = answer.split(RegExp(r'\n+'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);

    const metrics = <String, String>{
      'Receitas registradas': 'receitas',
      'Despesas por competência': 'despesas',
      'Resultado do mês': 'resultado',
    };
    final values = <String, String>{};
    final details = <String>[];
    for (final line in lines) {
      bool matched = false;
      for (final entry in metrics.entries) {
        if (line.startsWith('${entry.key}:')) {
          values[entry.value] = line.substring(entry.key.length + 1)
              .trim().replaceFirst(RegExp(r'\.$'), '');
          matched = true;
          break;
        }
      }
      if (!matched) details.add(line);
    }

    final isAutomatic = lines.isNotEmpty &&
        lines.first.startsWith('Resumo automático de ');
    // Keep every explanatory statement; only move the three exact aggregate
    // lines into metric cards. No regex-derived numbers or inferred categories.
    if (isAutomatic && details.isNotEmpty) details.removeAt(0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (values.isNotEmpty) ...[
          Text('seus números', style: AppTypography.cardTitle(context)),
          const SizedBox(height: 10),
          LayoutBuilder(builder: (context, constraints) {
            final itemWidth = (constraints.maxWidth - 10) / 2;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final entry in metrics.entries)
                  if (values.containsKey(entry.value))
                    SizedBox(
                      width: itemWidth,
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          borderRadius: BorderRadius.circular(AppRadii.card),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.value,
                              style: AppTypography.label(context,
                                fontSize: 12, color: scheme.onSurfaceVariant)),
                            const SizedBox(height: 8),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(values[entry.value]!,
                                style: AppTypography.money(context,
                                  fontSize: 22, color: scheme.onSurface)),
                            ),
                          ],
                        ),
                      ),
                    ),
              ],
            );
          }),
          const SizedBox(height: 16),
        ],
        if (details.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(AppRadii.card),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < details.length; i++) ...[
                  if (i > 0) const SizedBox(height: 12),
                  SelectableText(
                    details[i],
                    style: details[i].endsWith(':')
                      ? AppTypography.cardTitle(context, fontSize: 14)
                      : AppTypography.body(context,
                          fontSize: 14, color: scheme.onSurface),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
