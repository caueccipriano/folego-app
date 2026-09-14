import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../data/models/category_item.dart';
import '../../data/models/category_search.dart';
import 'category_icon_badge.dart';

class CategorySearchPicker extends StatefulWidget {
  const CategorySearchPicker({
    super.key,
    required this.categories,
    required this.eventType,
    this.selectedId,
    this.dialogMode = false,
  });

  final List<CategoryItem> categories;
  final String eventType;
  final String? selectedId;
  final bool dialogMode;

  @override
  State<CategorySearchPicker> createState() => _CategorySearchPickerState();
}

class _CategorySearchPickerState extends State<CategorySearchPicker> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    final results = CategorySearch.search(widget.categories, _query, limit: 60);
    final emptyQuery = _query.trim().isEmpty;

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: widget.dialogMode
            ? BorderRadius.circular(28)
            : const BorderRadius.vertical(top: Radius.circular(30)),
        border: widget.dialogMode
            ? Border.all(color: border)
            : Border(top: BorderSide(color: border)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!widget.dialogMode) ...[
                    Center(
                      child: Container(
                        width: 44,
                        height: 4,
                        decoration: BoxDecoration(
                          color: border,
                          borderRadius: BorderRadius.circular(99),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                  ],
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'categoria',
                              style: AppTypography.section(
                                context,
                                fontSize: 20,
                                color: primaryText,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              emptyQuery
                                  ? 'mais usadas e catálogo completo'
                                  : '${results.length} resultado${results.length == 1 ? '' : 's'}',
                              style: AppTypography.body(
                                context,
                                fontSize: 11,
                                color: secondaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (widget.dialogMode)
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(AppIcons.close, color: secondaryText),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _search,
                    autofocus: false,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'buscar: gas, uber, farmácia...',
                      prefixIcon: Icon(AppIcons.search, color: secondaryText),
                      suffixIcon: _query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                _search.clear();
                                setState(() => _query = '');
                              },
                              icon: Icon(AppIcons.close, color: secondaryText),
                            ),
                    ),
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: results.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          'Nenhuma categoria encontrada.',
                          textAlign: TextAlign.center,
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            color: secondaryText,
                          ),
                        ),
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                      itemCount: results.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 6),
                      itemBuilder: (context, index) {
                        final category = results[index];
                        final selected = category.id == widget.selectedId;
                        final parentName = category.parentName;
                        final visual = CategoryVisuals.resolve(
                          brightness: brightness,
                          category: parentName ?? category.name,
                          subcategory: parentName == null ? null : category.name,
                          eventType: widget.eventType,
                        );

                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => Navigator.of(context).pop(category),
                            borderRadius: BorderRadius.circular(16),
                            child: Ink(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 11,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? visual.color.withValues(alpha: .11)
                                    : surface,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: selected
                                      ? visual.color.withValues(alpha: .45)
                                      : border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  CategoryIconBadge(
                                    icon: visual.icon,
                                    color: visual.color,
                                    size: 40,
                                    iconSize: 20,
                                    radius: 13,
                                  ),
                                  const SizedBox(width: 11),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        if (parentName != null) ...[
                                          Text(
                                            parentName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppTypography.label(
                                              context,
                                              fontSize: 9,
                                              color: secondaryText,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                        ],
                                        Text(
                                          category.name,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: AppTypography.body(
                                            context,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600,
                                            color: primaryText,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (category.usageCount > 0 && emptyQuery) ...[
                                    const SizedBox(width: 8),
                                    Text(
                                      '${category.usageCount}x',
                                      style: AppTypography.label(
                                        context,
                                        fontSize: 9,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ],
                                  if (selected) ...[
                                    const SizedBox(width: 8),
                                    Icon(AppIcons.check, size: 17, color: visual.color),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
