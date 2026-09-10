import 'dart:ui';

import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class LiquidGlassNavigationBar extends StatelessWidget {
  const LiquidGlassNavigationBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  static const _items = <_GlassNavItem>[
    _GlassNavItem(
      Icons.home_outlined,
      Icons.home_rounded,
      'Início',
    ),
    _GlassNavItem(
      Icons.receipt_long_outlined,
      Icons.receipt_long_rounded,
      'Lançamentos',
    ),
    _GlassNavItem(
      Icons.calendar_month_outlined,
      Icons.calendar_month_rounded,
      'Plano',
    ),
    _GlassNavItem(
      Icons.account_balance_wallet_outlined,
      Icons.account_balance_wallet_rounded,
      'Carteira',
    ),
    _GlassNavItem(
      Icons.person_outline_rounded,
      Icons.person_rounded,
      'Perfil',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final borderColor = isDark
        ? Colors.white.withValues(alpha: .18)
        : Colors.white.withValues(alpha: .72);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(
        14,
        0,
        14,
        10,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(
                alpha: isDark ? .38 : .10,
              ),
              blurRadius: 34,
              spreadRadius: -4,
              offset: const Offset(0, 14),
            ),
            BoxShadow(
              color: Colors.white.withValues(
                alpha: isDark ? .04 : .45,
              ),
              blurRadius: 12,
              spreadRadius: -5,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(32),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: 34,
              sigmaY: 34,
            ),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(32),
                border: Border.all(
                  color: borderColor,
                  width: 1.1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: isDark
                      ? [
                          Colors.white.withValues(
                            alpha: .105,
                          ),
                          Colors.white.withValues(
                            alpha: .035,
                          ),
                        ]
                      : [
                          Colors.white.withValues(
                            alpha: .30,
                          ),
                          Colors.white.withValues(
                            alpha: .10,
                          ),
                        ],
                ),
              ),
              child: Stack(
                children: [
                  // brilho interno superior do vidro
                  Positioned(
                    top: 1,
                    left: 24,
                    right: 24,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white
                                .withValues(alpha: 0),
                            Colors.white.withValues(
                              alpha: isDark
                                  ? .24
                                  : .85,
                            ),
                            Colors.white
                                .withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),

                  Row(
                    children: List.generate(
                      _items.length,
                      (index) {
                        final item = _items[index];
                        final selected =
                            selectedIndex == index;

                        return Expanded(
                          child: _Destination(
                            item: item,
                            selected: selected,
                            onTap: () =>
                                onDestinationSelected(
                              index,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
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

  final _GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    final foreground = selected
        ? Colors.white
        : isDark
            ? Colors.white.withValues(alpha: .76)
            : const Color(0xFF35333A)
                .withValues(alpha: .78);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          margin: const EdgeInsets.symmetric(
            horizontal: 3,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: selected
                ? LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AppPalette.purpleLight
                          .withValues(alpha: .96),
                      AppPalette.purple
                          .withValues(alpha: .84),
                    ],
                  )
                : null,
            border: selected
                ? Border.all(
                    color: Colors.white.withValues(
                      alpha: isDark ? .20 : .52,
                    ),
                    width: 1,
                  )
                : null,
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppPalette.purple
                          .withValues(alpha: .30),
                      blurRadius: 18,
                      spreadRadius: -4,
                      offset: const Offset(0, 6),
                    ),
                    BoxShadow(
                      color: Colors.white.withValues(
                        alpha: .16,
                      ),
                      blurRadius: 7,
                      spreadRadius: -4,
                      offset: const Offset(0, -2),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                selected
                    ? item.selectedIcon
                    : item.icon,
                color: foreground,
                size: 24,
              ),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    height: 1,
                    fontWeight: selected
                        ? FontWeight.w800
                        : FontWeight.w600,
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

class _GlassNavItem {
  const _GlassNavItem(
    this.icon,
    this.selectedIcon,
    this.label,
  );

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}