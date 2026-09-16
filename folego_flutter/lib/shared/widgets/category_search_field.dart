import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_icons.dart';
import '../../data/models/category_item.dart';
import 'category_search_picker.dart';

class CategorySearchField extends StatelessWidget {
  const CategorySearchField({
    super.key,
    required this.categories,
    required this.eventType,
    required this.label,
    required this.onChanged,
    this.selectedId,
    this.emptyLabel = 'sem categoria',
    this.allowClear = false,
  });

  final List<CategoryItem> categories;
  final String eventType;
  final String label;
  final String? selectedId;
  final String emptyLabel;
  final bool allowClear;
  final ValueChanged<String?> onChanged;

  CategoryItem? get _selected {
    final id = selectedId;
    if (id == null) return null;
    for (final category in categories) {
      if (category.id == id) return category;
    }
    return null;
  }

  Future<void> _openPicker(BuildContext context) async {
    if (categories.isEmpty) return;
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    final selected = compact
        ? await showModalBottomSheet<CategoryItem>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: .84,
              child: CategorySearchPicker(
                categories: categories,
                eventType: eventType,
                selectedId: selectedId,
              ),
            ),
          )
        : await showDialog<CategoryItem>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: SizedBox(
                width: 620,
                height: MediaQuery.sizeOf(dialogContext).height * .72,
                child: CategorySearchPicker(
                  categories: categories,
                  eventType: eventType,
                  selectedId: selectedId,
                  dialogMode: true,
                ),
              ),
            ),
          );
    if (selected != null) onChanged(selected.id);
  }

  @override
  Widget build(BuildContext context) {
    final selected = _selected;
    return Semantics(
      button: true,
      label: '$label, ${selected?.breadcrumb ?? emptyLabel}',
      child: InkWell(
        key: ValueKey('category-search-field-$label'),
        onTap: categories.isEmpty ? null : () => _openPicker(context),
        borderRadius: BorderRadius.circular(16),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: allowClear && selected != null
                ? IconButton(
                    tooltip: 'remover categoria',
                    onPressed: () => onChanged(null),
                    icon: const Icon(AppIcons.close, size: 18),
                  )
                : const Icon(AppIcons.search, size: 18),
          ),
          child: Text(
            selected?.breadcrumb ?? emptyLabel,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
