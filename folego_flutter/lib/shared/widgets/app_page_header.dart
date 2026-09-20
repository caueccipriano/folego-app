import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_typography.dart';

/// Cabeçalho oficial das telas principais do Fôlego.
///
/// Mantém título, subtítulo e ação lateral com a mesma hierarquia visual
/// entre Plano, Carteira, Lançamentos e Perfil.
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

    Widget titleRow({required bool includeTrailing}) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            leading!,
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.display(
                context,
                fontSize: 28,
                color: primary,
              ),
            ),
          ),
          if (includeTrailing && trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      );
    }

    Widget subtitleText() => Padding(
          padding: EdgeInsets.only(left: leading == null ? 0 : 56),
          child: Text(
            subtitle!,
            style: AppTypography.body(
              context,
              fontSize: 13,
              color: secondary,
            ),
          ),
        );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stackTrailing =
            trailing != null && leading != null && constraints.maxWidth < 390;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            titleRow(includeTrailing: !stackTrailing),
            if (subtitle?.trim().isNotEmpty == true) ...[
              const SizedBox(height: 5),
              subtitleText(),
            ],
            if (stackTrailing) ...[
              const SizedBox(height: 10),
              Padding(
                padding: EdgeInsets.only(left: leading == null ? 0 : 56),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: trailing!,
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
