import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';

/// Secondary destinations in one calm, two-by-two mobile menu.
/// All actions remain explicit navigation, with no financial writes.
class MoreToolsSheet extends StatelessWidget {
  const MoreToolsSheet({super.key, required this.onSelected});

  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final space = MediaQuery.sizeOf(context).width;
    final pad = space < 355 ? 12.0 : 18.0;

    return Padding(
      padding: EdgeInsets.fromLTRB(pad, 4, pad, 18),
      child: Column(
        key: const ValueKey('tools-compact-grid'),
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
            child: Row(children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('mais', style: AppTypography.section(context,
                      fontSize: 20, color: scheme.onSurface)),
                    const SizedBox(height: 3),
                    Text('suas ferramentas, em um lugar',
                      style: AppTypography.body(context, fontSize: 12,
                        color: scheme.onSurfaceVariant)),
                  ],
                ),
              ),
              Icon(Icons.apps_rounded, color: scheme.onSurfaceVariant,
                size: 22),
            ]),
          ),
          Row(children: [
            Expanded(child: _ToolTile(
              tileKey: const ValueKey('tools-wallet'),
              label: 'contas e cartões',
              caption: 'faturas e dívidas',
              icon: Icons.account_balance_wallet_outlined,
              onTap: () => onSelected(0))),
            const SizedBox(width: 10),
            Expanded(child: _ToolTile(
              tileKey: const ValueKey('tools-goals'),
              label: 'metas',
              caption: 'guardar e realizar',
              icon: Icons.flag_outlined,
              onTap: () => onSelected(1))),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: _ToolTile(
              tileKey: const ValueKey('tools-diary'),
              label: 'diário',
              caption: 'anotações financeiras',
              icon: Icons.auto_stories_outlined,
              onTap: () => onSelected(2))),
            const SizedBox(width: 10),
            Expanded(child: _ToolTile(
              tileKey: const ValueKey('tools-profile'),
              label: 'configurações',
              caption: 'perfil e automações',
              icon: Icons.settings_outlined,
              onTap: () => onSelected(3))),
          ]),
        ],
      ),
    );
  }
}

class _ToolTile extends StatelessWidget {
  const _ToolTile({
    required this.tileKey,
    required this.label,
    required this.caption,
    required this.icon,
    required this.onTap,
  });

  final Key tileKey;
  final String label;
  final String caption;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surfaceContainerLow,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: tileKey,
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 108),
          padding: const EdgeInsets.fromLTRB(13, 12, 9, 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 23, color: scheme.primary),
              const Spacer(),
              Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.body(context, fontSize: 13,
                  fontWeight: FontWeight.w700, color: scheme.onSurface)),
              const SizedBox(height: 3),
              Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: AppTypography.label(context, fontSize: 10,
                  color: scheme.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}
