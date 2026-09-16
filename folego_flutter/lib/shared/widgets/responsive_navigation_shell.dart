import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
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
  }) : assert(pages.length == 5);

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<Widget> pages;

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return Scaffold(
      extendBody: !desktop,
      body: Row(
        children: [
          if (desktop)
            DesktopNavigationSidebar(
              selectedIndex: selectedIndex,
              onDestinationSelected: onDestinationSelected,
              compact: layout == AppLayoutSize.expanded,
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
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final bool compact;

  static const _items = <_DesktopNavItem>[
    _DesktopNavItem(icon: AppIcons.home, label: 'Início'),
    _DesktopNavItem(icon: AppIcons.transactions, label: 'Lançamentos'),
    _DesktopNavItem(icon: AppIcons.plan, label: 'Plano'),
    _DesktopNavItem(icon: AppIcons.wallet, label: 'Carteira'),
    _DesktopNavItem(icon: AppIcons.profile, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final width = compact ? 204.0 : 232.0;

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
                    fontSize: 22,
                    color: primaryText,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: _items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 5),
                  itemBuilder: (context, index) {
                    final item = _items[index];
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
                          borderRadius: BorderRadius.circular(15),
                          hoverColor: accent.withValues(alpha: .07),
                          focusColor: accent.withValues(alpha: .10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            curve: Curves.easeOutCubic,
                            minHeight: 48,
                            padding: const EdgeInsets.symmetric(horizontal: 13),
                            decoration: BoxDecoration(
                              color: selectedIndex == index
                                  ? accent.withValues(alpha: .11)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(15),
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
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTypography.body(
                                      context,
                                      fontSize: 12,
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
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                child: Text(
                  compact ? 'web' : 'seu dinheiro, sem planilha',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
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
