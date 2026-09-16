import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
    this.includeAll = false,
    this.onSelected,
  });

  final List<CategoryItem> categories;
  final String eventType;
  final String? selectedId;
  final bool dialogMode;
  final bool includeAll;
  final ValueChanged<CategoryItem?>? onSelected;

  @override
  State<CategorySearchPicker> createState() => _CategorySearchPickerState();
}

class _CategorySearchPickerState extends State<CategorySearchPicker> {
  final _search = TextEditingController();
  final _focusNode = FocusNode();
  String _query = '';
  int _highlightedIndex = 0;

  @override
  void dispose() {
    _search.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<CategoryItem> get _results {
    if (_query.trim().isNotEmpty) {
      return CategorySearch.search(widget.categories, _query, limit: 80);
    }

    final selectable = widget.categories.where((item) => item.isSelectable).toList();
    final ids = selectable.map((item) => item.id).toSet();
    final roots = selectable
        .where((item) => item.parentId == null || !ids.contains(item.parentId))
        .toList();
    roots.sort(_treeCompare);

    final ordered = <CategoryItem>[];
    for (final root in roots) {
      ordered.add(root);
      final children = selectable.where((item) => item.parentId == root.id).toList()
        ..sort(_treeCompare);
      ordered.addAll(children);
    }

    final orderedIds = ordered.map((item) => item.id).toSet();
    final orphans = selectable.where((item) => !orderedIds.contains(item.id)).toList()
      ..sort(_treeCompare);
    ordered.addAll(orphans);
    return ordered;
  }

  int _treeCompare(CategoryItem a, CategoryItem b) {
    final byOrder = a.sortOrder.compareTo(b.sortOrder);
    if (byOrder != 0) return byOrder;
    return CategorySearch.normalize(a.name).compareTo(CategorySearch.normalize(b.name));
  }

  void _select(CategoryItem? item) {
    final callback = widget.onSelected;
    if (callback != null) {
      callback(item);
      return;
    }
    if (item != null) Navigator.of(context).pop(item);
  }

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    final results = _results;
    final offset = widget.includeAll ? 1 : 0;
    final count = results.length + offset;
    if (count == 0) return KeyEventResult.ignored;

    if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
      setState(() => _highlightedIndex = (_highlightedIndex + 1) % count);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
      setState(() => _highlightedIndex = (_highlightedIndex - 1 + count) % count);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.enter) {
      if (widget.includeAll && _highlightedIndex == 0) {
        _select(null);
      } else {
        final index = _highlightedIndex - offset;
        if (index >= 0 && index < results.length) _select(results[index]);
      }
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      Navigator.of(context).maybePop();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final results = _results;
    final emptyQuery = _query.trim().isEmpty;

    return Focus(
      focusNode: _focusNode,
      onKeyEvent: _onKeyEvent,
      child: Container(
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
                                    ? 'categorias e subcategorias'
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
                            tooltip: 'fechar',
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(AppIcons.close, color: secondaryText),
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('category-search-field'),
                      controller: _search,
                      autofocus: widget.dialogMode,
                      textInputAction: TextInputAction.search,
                      decoration: InputDecoration(
                        hintText: 'buscar categoria ou subcategoria',
                        prefixIcon: Icon(AppIcons.search, color: secondaryText),
                        suffixIcon: _query.isEmpty
                            ? null
                            : IconButton(
                                tooltip: 'limpar busca',
                                onPressed: () {
                                  _search.clear();
                                  setState(() {
                                    _query = '';
                                    _highlightedIndex = 0;
                                  });
                                },
                                icon: Icon(AppIcons.close, color: secondaryText),
                              ),
                      ),
                      onChanged: (value) => setState(() {
                        _query = value;
                        _highlightedIndex = 0;
                      }),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: border),
              Expanded(
                child: results.isEmpty && !widget.includeAll
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'nenhuma categoria encontrada',
                            textAlign: TextAlign.center,
                            style: AppTypography.body(
                              context,
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ),
                      )
                    : ListView(
                        key: const ValueKey('category-search-results'),
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 20),
                        children: [
                          if (widget.includeAll) ...[
                            _AllCategoryRow(
                              selected: widget.selectedId == null,
                              highlighted: _highlightedIndex == 0,
                              onTap: () => _select(null),
                            ),
                            const SizedBox(height: 6),
                          ],
                          for (var index = 0; index < results.length; index++) ...[
                            _CategoryResultRow(
                              category: results[index],
                              eventType: widget.eventType,
                              selected: results[index].id == widget.selectedId,
                              highlighted:
                                  _highlightedIndex == index + (widget.includeAll ? 1 : 0),
                              indented: emptyQuery && results[index].parentId != null,
                              surface: surface,
                              border: border,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              onTap: () => _select(results[index]),
                            ),
                            if (index != results.length - 1) const SizedBox(height: 6),
                          ],
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllCategoryRow extends StatelessWidget {
  const _AllCategoryRow({
    required this.selected,
    required this.highlighted,
    required this.onTap,
  });

  final bool selected;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    final purple = AppColors.primaryPurple(brightness);
    return Semantics(
      button: true,
      selected: selected,
      label: 'todas as categorias',
      child: InkWell(
        key: const ValueKey('category-all-option'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
          decoration: BoxDecoration(
            color: selected || highlighted
                ? purple.withValues(alpha: .10)
                : AppColors.surface(brightness),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: selected ? purple.withValues(alpha: .45) : border),
          ),
          child: Row(
            children: [
              const Icon(AppIcons.categoryUnclassified, size: 20),
              const SizedBox(width: 12),
              const Expanded(child: Text('todas as categorias')),
              if (selected) Icon(AppIcons.check, size: 17, color: purple),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryResultRow extends StatelessWidget {
  const _CategoryResultRow({
    required this.category,
    required this.eventType,
    required this.selected,
    required this.highlighted,
    required this.indented,
    required this.surface,
    required this.border,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
  });

  final CategoryItem category;
  final String eventType;
  final bool selected;
  final bool highlighted;
  final bool indented;
  final Color surface;
  final Color border;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final parentName = category.parentName;
    final visual = CategoryVisuals.resolve(
      brightness: Theme.of(context).brightness,
      category: parentName ?? category.name,
      subcategory: parentName == null ? null : category.name,
      eventType: eventType,
      systemKey: category.systemKey,
      colorHex: category.isSystem ? null : category.colorHex,
      iconKey: category.isSystem ? null : category.iconKey,
    );

    return Padding(
      padding: EdgeInsets.only(left: indented ? 20 : 0),
      child: Semantics(
        button: true,
        selected: selected,
        label: category.breadcrumb,
        child: InkWell(
          key: ValueKey('category-option-${category.id}'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: selected || highlighted
                  ? visual.color.withValues(alpha: .11)
                  : surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? visual.color.withValues(alpha: .45) : border,
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
                      if (!indented && parentName != null) ...[
                        const SizedBox(height: 2),
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
                      ],
                    ],
                  ),
                ),
                if (selected) ...[
                  const SizedBox(width: 8),
                  Icon(AppIcons.check, size: 17, color: visual.color),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
