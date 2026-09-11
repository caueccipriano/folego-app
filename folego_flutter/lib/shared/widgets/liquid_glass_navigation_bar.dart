import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';

class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _items = <_NavItem>[
    _NavItem(
      icon: AppIcons.home,
      label: 'Início',
    ),
    _NavItem(
      icon: AppIcons.transactions,
      label: 'Lançamentos',
    ),
    _NavItem(
      icon: AppIcons.plan,
      label: 'Plano',
    ),
    _NavItem(
      icon: AppIcons.wallet,
      label: 'Carteira',
    ),
    _NavItem(
      icon: AppIcons.profile,
      label: 'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final background = isDark
        ? AppColors.darkSurface
        : AppColors.lightSurface;

    final border = isDark
        ? AppColors.darkBorder
        : AppColors.lightBorder;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        12,
        0,
        12,
        10,
      ),

      // IMPORTANTE:
      // altura fixa para a barra NÃO ocupar a tela inteira.
      child: SizedBox(
        height: 74,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(
                  maxWidth: 520,
                ),
                child: Container(
                  width: double.infinity,
                  height: 74,
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius:
                        BorderRadius.circular(26),
                    border: Border.all(
                      color: border,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: isDark ? .22 : .07,
                        ),
                        blurRadius: 22,
                        spreadRadius: -6,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Row(
                    children: List.generate(
                      _items.length,
                      (index) {
                        return Expanded(
                          child: _Destination(
                            item: _items[index],
                            selected:
                                selectedIndex == index,
                            onTap: () {
                              onDestinationSelected(
                                index,
                              );
                            },
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Destination extends StatelessWidget {
  const _Destination({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final _NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark =
        theme.brightness == Brightness.dark;

    final activePurple = isDark
        ? AppColors.purpleDark
        : AppColors.purpleLight;

    final inactiveColor = isDark
        ? AppColors.darkSecondaryText
        : AppColors.lightSecondaryText;

    final activeForeground = isDark
        ? AppColors.darkPrimaryText
        : Colors.white;

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: Tooltip(
        message: item.label,
        waitDuration:
            const Duration(milliseconds: 600),
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(20),
          child: AnimatedContainer(
            duration:
                const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(
              horizontal: 2,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? activePurple
                  : Colors.transparent,
              borderRadius:
                  BorderRadius.circular(20),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    Icon(
                      item.icon,
                      size: 23,
                      color: selected
                          ? activeForeground
                          : inactiveColor,
                    ),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        style:
                            AppTypography.label(
                          context,
                          fontSize: 10,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: selected
                              ? activeForeground
                              : inactiveColor,
                        ),
                      ),
                    ),
                  ],
                ),

                if (selected)
                  Positioned(
                    bottom: 4,
                    child: Container(
                      width: 14,
                      height: 3,
                      decoration: BoxDecoration(
                        color: AppColors.lime,
                        borderRadius:
                            BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  const _NavItem({
    required this.icon,
    required this.label,
  });

  final IconData icon;
  final String label;
}