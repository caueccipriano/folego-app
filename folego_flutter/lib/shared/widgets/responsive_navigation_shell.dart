import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import 'liquid_glass_navigation_bar.dart';

/// Responsive application chrome. The content stack stays in the same branch of
/// the element tree while the sidebar appears/disappears, preserving page State
/// across window resizes.
class ResponsiveNavigationShell extends StatelessWidget {
  const ResponsiveNavigationShell({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.pages,
    this.onOpenTools,
  }) : assert(pages.length == 5);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;
  final VoidCallback? onOpenTools;

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return Scaffold(
      // Keep the mobile body and navigation in separate layout regions. This
      // prevents an oversized/transformed nav compositor layer from covering
      // the page or intercepting touches on iOS PWAs.
      extendBody: false,
      body: Row(
        children: [
          if (desktop)
            DesktopNavigationSidebar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              compact: layout == AppLayoutSize.expanded,
              onOpenTools: onOpenTools,
            ),
          Expanded(
            key: const ValueKey('shell-content'),
            child: IndexedStack(index: selectedIndex, children: pages),
          ),
        ],
      ),
      bottomNavigationBar: desktop
          ? null
          : KeyedSubtree(
              key: const ValueKey('mobile-bottom-navigation'),
              child: LiquidGlassNavigationBar(
                selectedIndex: selectedIndex,
                onDestinationSelected: onDestinationSelected,
                onOpenTools: onOpenTools,
              ),
            ),
    );
  }
}

class DesktopNavigationSidebar extends StatelessWidget {
  const DesktopNavigationSidebar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.compact,
    this.onOpenTools,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;
  final VoidCallback? onOpenTools;

  @override
  Widget build(BuildContext context) {
    final items = <_DesktopNavItem>[
      _DesktopNavItem(icon: AppIcons.home, label: 'hoje'),
      _DesktopNavItem(icon: AppIcons.transactions, label: 'movimentos'),
      _DesktopNavItem(icon: AppIcons.plan, label: 'futuro'),
    ];

    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final width = compact ? 216.0 : 248.0;
    final motionDuration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 160);

    return Material(
      key: const ValueKey('desktop-sidebar'),
      color: surface,
      child: SafeArea(
        right: false,
        child: Container(
          width: width,
          decoration: BoxDecoration(
            border: Border(right: BorderSide(color: border)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 24, 18, 18),
                child: Text(
                  'fôlego',
                  style: AppTypography.display(
                    context,
                    fontSize: 26,
                    color: primaryText,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 24),
                child: Container(
                  height: 3,
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: .24,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return Semantics(
                      selected: selectedIndex == index,
                      button: true,
                      label: item.label,
                      child: Tooltip(
                        message: item.label,
                        waitDuration: const Duration(milliseconds: 600),
                        child: InkWell(
                          key: ValueKey('desktop-nav-$index'),
                          onTap: () => onDestinationSelected(index),
                          borderRadius: BorderRadius.circular(AppRadii.control),
                          hoverColor: accent.withValues(alpha: .07),
                          focusColor: accent.withValues(alpha: .10),
                          highlightColor: accent.withValues(alpha: .10),
                          child: AnimatedContainer(
                            duration: motionDuration,
                            curve: Curves.easeOutCubic,
                            constraints: const BoxConstraints(minHeight: 52),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 13,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selectedIndex == index
                                  ? accent.withValues(alpha: .11)
                                  : AppColors.transparent,
                              borderRadius: BorderRadius.circular(
                                AppRadii.control,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 21,
                                  color: selectedIndex == index
                                      ? accent
                                      : secondaryText,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    item.label,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                      context,
                                      fontSize: 14,
                                      fontWeight: selectedIndex == index
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                      color: selectedIndex == index
                                          ? accent
                                          : primaryText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (onOpenTools != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    key: const ValueKey('desktop-tools-button'),
                    onPressed: onOpenTools,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: const Text('contas e ajustes'),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text(
                  'seu dinheiro, com respiro',
                  style: AppTypography.label(
                    context,
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem {
  const _DesktopNavItem({required this.icon, required this.label});

  final IconData icon;
  final String label;
}
