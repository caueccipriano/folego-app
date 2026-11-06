import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../shared/widgets/folego_glass_surface.dart';

/// Two quick routes remain directly reachable, with a single calm surface
/// instead of independent buttons competing with the financial headline.
class HomeQuickTools extends StatelessWidget {
  const HomeQuickTools({
    super.key,
    required this.onSearch,
    required this.onPending,
    this.onSetup,
    this.onAskAi,
  });

  final VoidCallback onSearch;
  final VoidCallback onPending;
  final VoidCallback? onSetup;
  final VoidCallback? onAskAi;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        FolegoGlassSurface(
          radius: 18,
          prominent: true,
          elevated: false,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                key: const ValueKey('home-global-search'),
                onPressed: onSearch,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                ),
                icon: const Icon(AppIcons.search, size: 18),
                label: const Text('buscar'),
              ),
              SizedBox(
                width: 1,
                height: 23,
                child: ColoredBox(color: scheme.outlineVariant),
              ),
              TextButton.icon(
                key: const ValueKey('home-pending-center'),
                onPressed: onPending,
                style: TextButton.styleFrom(
                  foregroundColor: scheme.onSurface,
                  minimumSize: const Size(0, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 13),
                ),
                icon: const Icon(AppIcons.transactions, size: 18),
                label: const Text('resolver'),
              ),
            ],
          ),
        ),
        if (onAskAi != null)
          OutlinedButton.icon(
            key: const ValueKey('home-ai-shortcut'),
            onPressed: onAskAi,
            icon: const Icon(Icons.auto_awesome_outlined, size: 18),
            label: const Text('perguntar à IA'),
          ),
        if (onSetup != null)
          OutlinedButton.icon(
            key: const ValueKey('home-income-setup'),
            onPressed: onSetup,
            icon: const Icon(Icons.route_outlined, size: 18),
            label: const Text('começar do meu jeito'),
          ),
      ],
    );
  }
}
