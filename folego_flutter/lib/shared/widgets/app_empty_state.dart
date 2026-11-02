import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// A neutral, accessible empty state. Empty does not mean an error.
/// The page provides its own action; this component never writes data.
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

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: Container(
        key: const ValueKey('folego-empty-state'),
        width: double.infinity,
        constraints: const BoxConstraints(maxWidth: 520),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.surface(brightness),
          borderRadius: BorderRadius.circular(AppRadii.feature),
          border: Border.all(color: AppColors.border(brightness)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withValues(alpha: .18)),
              ),
              child: Icon(icon, color: accent, size: 23,
                semanticLabel: null),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTypography.cardTitle(
                context, fontSize: 17, color: primary),
            ),
            if (description?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 8),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 380),
                child: Text(
                  description!,
                  textAlign: TextAlign.center,
                  style: AppTypography.body(
                    context, fontSize: 13, color: secondary),
                ),
              ),
            ],
            if (action != null) ...[
              const SizedBox(height: 18),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}
