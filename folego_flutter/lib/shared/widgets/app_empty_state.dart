import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Estado vazio oficial do Fôlego para listas e seções sem conteúdo.
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.accentColor,
    this.action,
  });

  final IconData icon;
  final String title;
  final String? description;
  final Color? accentColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = accentColor ?? AppColors.primaryPurple(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 26),
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
              color: accent.withValues(alpha: .11),
              borderRadius: BorderRadius.circular(AppRadii.control),
            ),
            child: Icon(icon, color: accent, size: 22),
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
            const SizedBox(height: 5),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondary,
              ),
            ),
          ],
          if (action != null) ...[
            const SizedBox(height: 15),
            action!,
          ],
        ],
      ),
    );
  }
}
