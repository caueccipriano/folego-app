import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_typography.dart';

/// Secondary information stays one tap away without crowding the first view.
/// Pure presentation: does not load, calculate or mutate financial records.
class FolegoDetailDisclosure extends StatelessWidget {
  const FolegoDetailDisclosure({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.icon = Icons.tune_rounded,
    this.initiallyExpanded = false,
  });

  final String title;
  final String? subtitle;
  final IconData icon;
  final Widget child;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    final tokens = FolegoColorTokens.of(context);
    return Material(
      color: tokens.superficie,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(19),
        side: BorderSide(color: tokens.borda),
      ),
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 2, 12, 13),
          iconColor: tokens.marca,
          collapsedIconColor: tokens.textoSecundario,
          textColor: tokens.textoPrincipal,
          collapsedTextColor: tokens.textoPrincipal,
          leading: Container(
            height: 34,
            width: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: tokens.marca.withValues(alpha: .085),
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 18, color: tokens.marca),
          ),
          title: Text(
            title,
            style: AppTypography.cardTitle(context,
              fontSize: 14, color: tokens.textoPrincipal),
          ),
          subtitle: subtitle == null ? null : Text(
            subtitle!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.label(context,
              fontSize: 11, color: tokens.textoSecundario),
          ),
          children: [child],
        ),
      ),
    );
  }
}
