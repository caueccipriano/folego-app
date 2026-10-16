import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

class DiaryReviewCard extends StatelessWidget {
  const DiaryReviewCard({
    super.key,
    required this.reviewed,
    required this.total,
    required this.onReview,
    required this.onTransactions,
  });
  final int reviewed;
  final int total;
  final VoidCallback? onReview;
  final VoidCallback onTransactions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      key: const ValueKey('diary-minute-review'),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.feature),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '1 minuto para entender uma escolha',
            style: AppTypography.section(context, fontSize: 18),
          ),
          const SizedBox(height: 9),
          Text(
            total == 0
                ? 'Seu mês ainda não tem gastos para refletir. Depois de registrar um, volte aqui para contar o que ele significou.'
                : onReview == null
                ? 'Você refletiu sobre todos os gastos disponíveis deste mês. Releia suas notas: o que vale repetir e o que prefere mudar?'
                : 'Escolha um gasto: foi necessário, uma vontade ou investimento em você? Se quiser, anote o que vale repetir ou fazer diferente. Sem julgamento.',
            style: AppTypography.body(context, fontSize: 13),
          ),
          if (total > 0) ...[
            const SizedBox(height: 13),
            Text(
              '$reviewed de $total gastos com reflexão neste mês',
              style: AppTypography.body(context, fontSize: 12),
            ),
            const SizedBox(height: 7),
            LinearProgressIndicator(
              value: (reviewed / total).clamp(0.0, 1.0),
              color: AppColors.primaryPurple(brightness),
              backgroundColor: AppColors.border(brightness),
            ),
          ],
          const SizedBox(height: 13),
          if (onReview != null)
            FilledButton(
              key: const ValueKey('diary-review-one'),
              onPressed: onReview,
              child: const Text('revisar 1 gasto'),
            )
          else if (total == 0)
            OutlinedButton(
              onPressed: onTransactions,
              child: const Text('abrir lançamentos'),
            ),
          const SizedBox(height: 5),
          Text(
            'Reflexão é diferente de categoria e de fixo/variável. Ela registra sua percepção; não altera o valor do gasto.',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
}
