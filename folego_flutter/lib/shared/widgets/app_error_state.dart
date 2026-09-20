import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Estado de erro oficial do Fôlego.
///
/// Mantém falhas recuperáveis visualmente coerentes entre as telas principais.
class AppErrorState extends StatelessWidget {
  const AppErrorState({
    super.key,
    required this.title,
    required this.onRetry,
    this.description,
    this.icon = AppIcons.warning,
  });

  final String title;
  final String? description;
  final IconData icon;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final expense = AppColors.expenseText(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(maxWidth: 520),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: expense.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(icon, size: 22, color: expense),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: primary,
            ),
          ),
          if (description?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondary,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('tentar novamente'),
          ),
        ],
      ),
    );
  }
}
