import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Consistent hierarchy for secondary sections across the Fôlego app.
/// The section action moves below the descriptive copy on narrow screens.
class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final largerText = MediaQuery.textScalerOf(context).scale(16) > 19.2;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackAction = trailing != null &&
            (constraints.maxWidth < 400 ||
                (largerText && constraints.maxWidth < 600));

        final heading = Semantics(
          header: true,
          child: Text(
            title,
            maxLines: largerText ? 3 : 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.section(
              context,
              fontSize: 18,
              color: primary,
            ),
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (stackAction)
              heading
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: heading),
                  if (trailing != null) ...[
                    const SizedBox(width: 10),
                    trailing!,
                  ],
                ],
              ),
            if (subtitle?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 5),
              Text(
                subtitle!,
                maxLines: largerText ? 5 : 3,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: 13,
                  color: secondary,
                ),
              ),
            ],
            if (stackAction) ...[
              const SizedBox(height: 8),
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
