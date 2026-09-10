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
    _GlassNavItem(Icons.home_outlined, Icons.home_rounded, 'Início'),
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
    _GlassNavItem(Icons.person_outline_rounded, Icons.person_rounded, 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final glassColor = isDark
        ? Colors.white.withValues(alpha: .07)
        : Colors.white.withValues(alpha: .22);
    final borderColor = isDark
        ? Colors.white.withValues(alpha: .16)
        : Colors.white.withValues(alpha: .42);

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isDark ? .28 : .10),
              blurRadius: 32,
              spreadRadius: 2,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(30),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 42, sigmaY: 42),
            child: Container(
              height: 76,
              decoration: BoxDecoration(
                color: glassColor,
                borderRadius: BorderRadius.circular(30),
                border: Border.all(color: borderColor),
              ),
              child: Row(
                children: List.generate(_items.length, (index) {
                  final item = _items[index];
                  final selected = selectedIndex == index;
                  return Expanded(
                    child: _Destination(
                      item: item,
                      selected: selected,
                      onTap: () => onDestinationSelected(index),
                    ),
                  );
                }),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final selectedBackground = AppPalette.primary.withValues(
      alpha: isDark ? .28 : .12,
    );
    final foreground = selected
        ? (isDark ? const Color(0xFF9FB2F2) : AppPalette.primary)
        : Theme.of(context).colorScheme.onSurface.withValues(alpha: .68);

    return Semantics(
      selected: selected,
      button: true,
      label: item.label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? selectedBackground : Colors.transparent,
            borderRadius: BorderRadius.circular(23),
            border: selected
                ? Border.all(
                    color: Colors.white.withValues(alpha: isDark ? .09 : .62),
                  )
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? item.selectedIcon : item.icon, color: foreground),
              const SizedBox(height: 3),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  item.label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 10.5,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
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
  const _GlassNavItem(this.icon, this.selectedIcon, this.label);

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}
