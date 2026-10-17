import 'package:flutter/material.dart';

class CategoryIconBadge extends StatelessWidget {
  const CategoryIconBadge({
    super.key,
    required this.icon,
    required this.color,
    this.size = 46,
    this.iconSize = 22,
    this.radius = 15,
  });

  final IconData icon;
  final Color color;
  final double size;
  final double iconSize;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(icon, color: color, size: iconSize),
    );
  }
}
