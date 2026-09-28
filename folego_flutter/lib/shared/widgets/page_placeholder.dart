import 'package:flutter/material.dart';

import 'app_empty_state.dart';
import 'app_page_header.dart';

/// Placeholder consistente com as demais páginas e seus estados vazios.
class PagePlaceholder extends StatelessWidget {
  const PagePlaceholder({
    super.key,
    required this.title,
    required this.description,
    required this.icon,
  });

  final String title;
  final String description;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          AppPageHeader(title: title),
          const SizedBox(height: 24),
          AppEmptyState(
            icon: icon,
            title: title,
            description: description,
          ),
        ],
      ),
    );
  }
}
