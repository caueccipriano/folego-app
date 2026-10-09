import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Shared page heading for Plano, Carteira, Lançamentos and Perfil.
/// Keeps the main title legible when actions and larger accessibility text
/// compete for the limited width of a small iPhone.
class AppPageHeader extends StatelessWidget {
  const AppPageHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final largerText = MediaQuery.textScalerOf(context).scale(16) > 19.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Use the *actual component width*, not the device width: headers
        // also render inside narrower content columns and bottom sheets.
        final compact = constraints.maxWidth < 600;
        final stackAction = trailing != null &&
            (constraints.maxWidth < 440 ||
                (largerText && constraints.maxWidth < 680));
        final leadingIndent = leading == null ? 0.0 : (compact ? 52.0 : 56.0);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (leading != null) ...[
                  leading!,
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      title,
                      maxLines: largerText ? 3 : 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.display(
                        context,
                        fontSize: compact ? 26 : 28,
                        color: primary,
                      ),
                    ),
                  ),
                ),
                if (!stackAction && trailing != null) ...[
                  const SizedBox(width: 12),
                  trailing!,
                ],
              ],
            ),
            if (subtitle?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 6),
              Padding(
                padding: EdgeInsets.only(left: leadingIndent),
                child: Text(
                  subtitle!,
                  style: AppTypography.body(
                    context,
                    fontSize: compact ? 13 : 14,
                    color: secondary,
                  ),
                ),
              ),
            ],
            if (stackAction) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: trailing!,
              ),
            ],
          ],
        );
      },
    );
  }
}
