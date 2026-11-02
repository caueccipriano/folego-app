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
    // Preserve the exact backend facts; visual grouping never recomputes totals.
    if (isAutomatic && details.isNotEmpty) details.removeAt(0);
    final general = <String>[];
    final comparison = <String>[];
    final caveats = <String>[];
    String? nextAction;
    var comparing = false;
    for (final line in details) {
      if (isAutomatic && line.startsWith('Uma coisa para revisar:')) {
        nextAction = line;
        comparing = false;
      } else if (isAutomatic &&
          line.startsWith('Comparação parcial das categorias')) {
        comparing = true;
        comparison.add(line);
      } else if (isAutomatic && line.startsWith('Valores baseados')) {
        comparing = false;
        caveats.add(line);
      } else if (comparing) {
        comparison.add(line);
      } else {
        general.add(line);
      }
    }

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
        if (general.isNotEmpty) _DetailSection(lines: general),
        if (comparison.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(title: 'comparação', lines: comparison),
        ],
        if (nextAction != null) ...[
          const SizedBox(height: 12),
          _DetailSection(
            title: 'próximo passo',
            lines: [nextAction],
            emphasized: true,
          ),
        ],
        if (caveats.isNotEmpty) ...[
          const SizedBox(height: 12),
          _DetailSection(title: 'sobre os dados', lines: caveats),
        ],
      ],
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.lines, this.title, this.emphasized = false});
  final List<String> lines;
  final String? title;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: emphasized
            ? Color.alphaBlend(scheme.primary.withValues(alpha: .065),
                scheme.surface)
            : scheme.surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: emphasized
            ? scheme.primary.withValues(alpha: .24)
            : scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(title!, style: AppTypography.cardTitle(context, fontSize: 15)),
            const SizedBox(height: 9),
          ],
          for (var i = 0; i < lines.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            SelectableText(
              lines[i],
              style: lines[i].endsWith(':')
                  ? AppTypography.cardTitle(context, fontSize: 14)
                  : AppTypography.body(context,
                      fontSize: 14, color: scheme.onSurface),
            ),
          ],
        ],
      ),
    );
  }
}
