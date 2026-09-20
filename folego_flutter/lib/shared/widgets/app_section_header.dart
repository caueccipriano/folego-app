import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Título oficial de seções internas do Fôlego.
///
/// Use abaixo do cabeçalho de página para manter a mesma hierarquia entre
/// Home, Plano, Carteira e Perfil.
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                title,
                style: AppTypography.section(
                  context,
                  fontSize: 20,
                  color: primary,
                ),
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 10),
              trailing!,
            ],
          ],
        ),
        if (subtitle?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            subtitle!,
            style: AppTypography.body(
              context,
              fontSize: 12,
              color: secondary,
            ),
          ),
        ],
      ],
    );
  }
}
