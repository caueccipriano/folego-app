import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_icon_catalog.dart';
import '../../core/theme/category_visuals.dart';
import '../../data/models/category_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../shared/widgets/category_icon_badge.dart';

typedef CategoryManagementLoader = Future<List<CategoryItem>> Function(
  String spaceId,
);
typedef CategoryManagementCreator = Future<String> Function({
  required String spaceId,
  required String name,
  required String kind,
  required String? parentId,
  required bool essential,
  required String colorHex,
  required String iconKey,
  required List<String> searchAliases,
});
typedef CategoryManagementUpdater = Future<void> Function({
  required String spaceId,
  required String categoryId,
  required String name,
  required bool essential,
  required String colorHex,
  required String iconKey,
  required List<String> searchAliases,
});
typedef CategoryManagementVisibility = Future<void> Function({
  required String spaceId,
  required String categoryId,
  required bool active,
});

class CategoryManagementScreen extends StatefulWidget {
  const CategoryManagementScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.initialKind = 'expense',
    this.returnCreated = false,
    this.loadOverride,
    this.createOverride,
    this.updateOverride,
    this.visibilityOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  final String initialKind;
  final bool returnCreated;

  @visibleForTesting
  final CategoryManagementLoader? loadOverride;
  @visibleForTesting
  final CategoryManagementCreator? createOverride;
  @visibleForTesting
  final CategoryManagementUpdater? updateOverride;
  @visibleForTesting
  final CategoryManagementVisibility? visibilityOverride;

  @override
  State<CategoryManagementScreen> createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  List<CategoryItem> _categories = const <CategoryItem>[];
  late String _kind;
  bool _loading = true;
  bool _mutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind == 'income' ? 'income' : 'expense';
    _load();
  }

  Future<List<CategoryItem>> _fetch() {
    final loader = widget.loadOverride;
    if (loader != null) return loader(widget.spaceId);
    return widget.repository.listManageableCategories(widget.spaceId);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final categories = await _fetch();
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  List<CategoryItem> get _visibleCategories {
    final values = _categories.where((item) => item.kind == _kind).toList();
    values.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final order = a.sortOrder.compareTo(b.sortOrder);
      if (order != 0) return order;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return values;
  }

  List<CategoryItem> get _parentCandidates {
    final values = _visibleCategories
        .where((item) => item.parentId == null && item.active)
        .toList();
    values.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return values;
  }

  Future<String> _create(_CategoryDraft draft) async {
    final override = widget.createOverride;
    if (override != null) {
      return override(
        spaceId: widget.spaceId,
        name: draft.name,
        kind: _kind,
        parentId: draft.parentId,
        essential: draft.essential,
        colorHex: draft.colorHex,
        iconKey: draft.iconKey,
        searchAliases: draft.aliases,
      );
    }
    return widget.repository.createCustomCategory(
      spaceId: widget.spaceId,
      name: draft.name,
      kind: _kind,
      parentId: draft.parentId,
      essential: draft.essential,
      colorHex: draft.colorHex,
      iconKey: draft.iconKey,
      searchAliases: draft.aliases,
    );
  }

  Future<void> _update(CategoryItem item, _CategoryDraft draft) async {
    final override = widget.updateOverride;
    if (override != null) {
      await override(
        spaceId: widget.spaceId,
        categoryId: item.id,
        name: draft.name,
        essential: draft.essential,
        colorHex: draft.colorHex,
        iconKey: draft.iconKey,
        searchAliases: draft.aliases,
      );
      return;
    }
    await widget.repository.updateCustomCategoryPresentation(
      spaceId: widget.spaceId,
      categoryId: item.id,
      name: draft.name,
      essential: draft.essential,
      colorHex: draft.colorHex,
      iconKey: draft.iconKey,
      searchAliases: draft.aliases,
    );
  }

  Future<void> _setActive(CategoryItem item, bool active) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      final override = widget.visibilityOverride;
      if (override != null) {
        await override(
          spaceId: widget.spaceId,
          categoryId: item.id,
          active: active,
        );
      } else {
        await widget.repository.setCategoryVisibility(
          spaceId: widget.spaceId,
          categoryId: item.id,
          active: active,
        );
      }
      await _load(silent: true);
      _invalidateCategoryConsumers();
      _message(active ? 'categoria reativada' : 'categoria desativada');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _createCategory({required bool subcategory}) async {
    if (_mutating) return;
    if (subcategory && _parentCandidates.isEmpty) {
      _message('crie uma categoria principal antes da subcategoria');
      return;
    }

    final draft = await _showEditor(
      _CategoryEditor(
        title: subcategory ? 'nova subcategoria' : 'nova categoria',
        kind: _kind,
        parents: subcategory ? _parentCandidates : const <CategoryItem>[],
        requireParent: subcategory,
      ),
    );
    if (draft == null || !mounted) return;
    if (_hasDuplicate(draft.name, draft.parentId)) {
      _message('já existe uma categoria com esse nome neste nível');
      return;
    }

    setState(() => _mutating = true);
    try {
      final id = await _create(draft);
      await _load(silent: true);
      _invalidateCategoryConsumers();
      final created = _categories.cast<CategoryItem?>().firstWhere(
            (item) => item?.id == id,
            orElse: () => null,
          );
      _message(subcategory ? 'subcategoria criada' : 'categoria criada');
      if (widget.returnCreated && created != null && mounted) {
        Navigator.of(context).pop(created);
      }
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editCategory(CategoryItem item) async {
    if (_mutating || !item.isCustom) return;
    final draft = await _showEditor(
      _CategoryEditor(
        title: item.isSubcategory ? 'editar subcategoria' : 'editar categoria',
        kind: item.kind ?? _kind,
        parents: const <CategoryItem>[],
        current: item,
      ),
    );
    if (draft == null || !mounted) return;
    if (_hasDuplicate(draft.name, item.parentId, excludeId: item.id)) {
      _message('já existe uma categoria com esse nome neste nível');
      return;
    }

    setState(() => _mutating = true);
    try {
      await _update(item, draft);
      await _load(silent: true);
      _invalidateCategoryConsumers();
      _message('categoria atualizada');
    } catch (error) {
      _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  bool _hasDuplicate(String name, String? parentId, {String? excludeId}) {
    final normalized = name.trim().toLowerCase();
    return _categories.any(
      (item) =>
          item.id != excludeId &&
          item.kind == _kind &&
          item.parentId == parentId &&
          item.name.trim().toLowerCase() == normalized,
    );
  }

  Future<_CategoryDraft?> _showEditor(Widget editor) {
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    if (compact) {
      return showModalBottomSheet<_CategoryDraft>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(heightFactor: .94, child: editor),
      );
    }
    return showDialog<_CategoryDraft>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640, maxHeight: 840),
          child: editor,
        ),
      ),
    );
  }

  void _invalidateCategoryConsumers() {
    final coordinator = AppRealtimeRegistry.coordinator;
    coordinator?.invalidate(AppRealtimeDomain.plan);
    coordinator?.invalidate(AppRealtimeDomain.transactions);
  }

  void _message(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('write_access_denied')) {
      return 'você não tem permissão para alterar este espaço';
    }
    if (text.contains('invalid_parent_category')) {
      return 'escolha uma categoria principal válida';
    }
    if (text.contains('category_name_required')) {
      return 'informe um nome para a categoria';
    }
    if (text.contains('categories_icon_key_valid')) {
      return 'escolha um ícone válido';
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      appBar: AppBar(
        title: Text(
          'categorias',
          style: AppTypography.display(
            context,
            fontSize: 24,
            color: AppColors.primaryText(brightness),
          ),
        ),
      ),
      body: AppContentContainer.dashboard(
        fillHeight: true,
        child: _buildBody(brightness),
      ),
    );
  }

  Widget _buildBody(Brightness brightness) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning, size: 38),
            const SizedBox(height: 12),
            Text(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            FilledButton(onPressed: _load, child: const Text('tentar novamente')),
          ],
        ),
      );
    }

    final desktop = switch (AppBreakpoints.of(context)) {
      AppLayoutSize.expanded || AppLayoutSize.wide => true,
      _ => false,
    };
    final items = _visibleCategories;
    final ids = items.map((item) => item.id).toSet();
    final roots = items
        .where((item) => item.parentId == null || !ids.contains(item.parentId))
        .toList(growable: false);

    return RefreshIndicator(
      onRefresh: () => _load(silent: true),
      child: ListView(
        key: ValueKey(desktop ? 'categories-desktop-layout' : 'categories-mobile-layout'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(0, 22, 0, 100),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'sua organização',
                      style: AppTypography.section(context, fontSize: 21),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'desativar preserva todo o histórico; categorias novas usam a mesma taxonomia do app.',
                      style: AppTypography.body(
                        context,
                        fontSize: 12,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                ),
              ),
              if (desktop) ...[
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  key: const ValueKey('new-subcategory-button'),
                  onPressed: _mutating ? null : () => _createCategory(subcategory: true),
                  icon: const Icon(AppIcons.add, size: 17),
                  label: const Text('subcategoria'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  key: const ValueKey('new-category-button'),
                  onPressed: _mutating ? null : () => _createCategory(subcategory: false),
                  icon: const Icon(AppIcons.add, size: 17),
                  label: const Text('categoria'),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('gastos'),
                selected: _kind == 'expense',
                onSelected: (_) => setState(() => _kind = 'expense'),
              ),
              ChoiceChip(
                label: const Text('receitas'),
                selected: _kind == 'income',
                onSelected: (_) => setState(() => _kind = 'income'),
              ),
              if (!desktop)
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 16),
                  label: const Text('nova categoria'),
                  onPressed: _mutating ? null : () => _createCategory(subcategory: false),
                ),
              if (!desktop)
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 16),
                  label: const Text('nova subcategoria'),
                  onPressed: _mutating ? null : () => _createCategory(subcategory: true),
                ),
            ],
          ),
          const SizedBox(height: 20),
          if (roots.isEmpty)
            _EmptyCategories(kind: _kind)
          else
            for (final root in roots) ...[
              _CategoryGroup(
                root: root,
                children: items
                    .where((item) => item.parentId == root.id)
                    .toList(growable: false),
                desktop: desktop,
                disabled: _mutating,
                onEdit: _editCategory,
                onActiveChanged: _setActive,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }
}

class _CategoryGroup extends StatelessWidget {
  const _CategoryGroup({
    required this.root,
    required this.children,
    required this.desktop,
    required this.disabled,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CategoryItem root;
  final List<CategoryItem> children;
  final bool desktop;
  final bool disabled;
  final ValueChanged<CategoryItem> onEdit;
  final void Function(CategoryItem, bool) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);

    if (!desktop && children.isNotEmpty) {
      return Material(
        color: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border),
        ),
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: _CategoryRow(
            item: root,
            embedded: true,
            disabled: disabled,
            onEdit: root.isCustom ? () => onEdit(root) : null,
            onActiveChanged: (value) => onActiveChanged(root, value),
          ),
          children: [
            for (final child in children)
              _CategoryRow(
                item: child,
                indented: true,
                disabled: disabled,
                onEdit: child.isCustom ? () => onEdit(child) : null,
                onActiveChanged: (value) => onActiveChanged(child, value),
              ),
          ],
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          _CategoryRow(
            item: root,
            embedded: true,
            disabled: disabled,
            onEdit: root.isCustom ? () => onEdit(root) : null,
            onActiveChanged: (value) => onActiveChanged(root, value),
          ),
          if (children.isNotEmpty) Divider(height: 12, color: border),
          for (final child in children)
            _CategoryRow(
              item: child,
              indented: true,
              embedded: true,
              disabled: disabled,
              onEdit: child.isCustom ? () => onEdit(child) : null,
              onActiveChanged: (value) => onActiveChanged(child, value),
            ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.item,
    required this.disabled,
    required this.onActiveChanged,
    this.onEdit,
    this.indented = false,
    this.embedded = false,
  });

  final CategoryItem item;
  final bool disabled;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback? onEdit;
  final bool indented;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final visual = CategoryVisuals.resolve(
      brightness: brightness,
      category: item.parentName ?? item.name,
      subcategory: item.parentName == null ? null : item.name,
      eventType: item.kind,
      systemKey: item.systemKey,
      colorHex: item.isSystem ? null : item.colorHex,
      iconKey: item.isSystem ? null : item.iconKey,
    );

    return Opacity(
      opacity: item.active ? 1 : .55,
      child: Padding(
        padding: EdgeInsets.fromLTRB(indented ? 22 : 6, 7, 4, 7),
        child: Row(
          children: [
            CategoryIconBadge(
              icon: visual.icon,
              color: visual.color,
              size: indented ? 36 : 42,
              iconSize: indented ? 18 : 21,
              radius: 12,
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    [
                      item.kind == 'income' ? 'receita' : 'gasto',
                      item.isSystem ? 'padrão' : 'personalizada',
                      item.active ? 'ativa' : 'desativada',
                    ].join(' · '),
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'editar',
                onPressed: disabled ? null : onEdit,
                icon: const Icon(AppIcons.edit, size: 18),
              ),
            Switch.adaptive(
              value: item.active,
              onChanged: disabled ? null : onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyCategories extends StatelessWidget {
  const _EmptyCategories({required this.kind});
  final String kind;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          const Icon(AppIcons.categoryUnclassified, size: 34),
          const SizedBox(height: 10),
          Text(
            kind == 'income' ? 'nenhuma categoria de receita' : 'nenhuma categoria de gasto',
            style: AppTypography.section(context, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.title,
    required this.kind,
    required this.parents,
    this.requireParent = false,
    this.current,
  });

  final String title;
  final String kind;
  final List<CategoryItem> parents;
  final bool requireParent;
  final CategoryItem? current;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  static const _colors = <String>[
    '#8C8CA8', '#2145FF', '#934BFF', '#00BFD1', '#FF8738', '#F451B6', '#75A83B',
  ];

  late final TextEditingController _name;
  late final TextEditingController _aliases;
  String? _parentId;
  late bool _essential;
  late String _colorHex;
  late String _iconKey;
  String? _validation;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _aliases = TextEditingController(
      text: widget.current?.searchAliases.join(', ') ?? '',
    );
    _parentId = widget.current?.parentId ??
        (widget.requireParent && widget.parents.isNotEmpty
            ? widget.parents.first.id
            : null);
    _essential = widget.current?.essential ?? false;
    _colorHex = widget.current?.colorHex ?? '#8C8CA8';
    _iconKey = CategoryIconCatalog.isSupportedKey(widget.current?.iconKey)
        ? widget.current!.iconKey!
        : widget.kind == 'income'
            ? 'income'
            : 'other';
  }

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  Future<void> _pickIcon() async {
    final selected = await showDialog<String>(
      context: context,
      builder: (_) => CategoryIconPicker(selectedKey: _iconKey),
    );
    if (selected != null && mounted) setState(() => _iconKey = selected);
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _validation = 'informe um nome');
      return;
    }
    if (widget.requireParent && _parentId == null) {
      setState(() => _validation = 'escolha a categoria principal');
      return;
    }
    final aliases = _aliases.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.of(context).pop(
      _CategoryDraft(
        name: name,
        parentId: widget.current?.parentId ?? _parentId,
        essential: _essential,
        colorHex: _colorHex,
        iconKey: _iconKey,
        aliases: aliases,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final selectedIcon = CategoryIconCatalog.iconForKey(_iconKey);

    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(28),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.title, style: AppTypography.section(context, fontSize: 20)),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: border),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    InputDecorator(
                      decoration: const InputDecoration(labelText: 'tipo'),
                      child: Text(widget.kind == 'income' ? 'receita' : 'gasto'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _name,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(labelText: 'nome'),
                    ),
                    if (widget.requireParent && widget.current == null) ...[
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _parentId,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'categoria principal'),
                        items: [
                          for (final parent in widget.parents)
                            DropdownMenuItem(value: parent.id, child: Text(parent.name)),
                        ],
                        onChanged: (value) => setState(() => _parentId = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      key: const ValueKey('category-icon-picker-button'),
                      onPressed: _pickIcon,
                      icon: Icon(selectedIcon, size: 20),
                      label: Text(
                        CategoryIconCatalog.choices
                            .firstWhere((choice) => choice.key == _iconKey)
                            .label,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _aliases,
                      decoration: const InputDecoration(
                        labelText: 'termos de busca',
                        hintText: 'ex.: gasolina, posto, combustível',
                      ),
                    ),
                    if (widget.kind == 'expense') ...[
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('necessidade por padrão'),
                        subtitle: const Text('mantém a classificação usada pelo planejamento atual'),
                        value: _essential,
                        onChanged: (value) => setState(() => _essential = value),
                      ),
                    ],
                    const SizedBox(height: 12),
                    Text('cor', style: AppTypography.label(context, fontSize: 11, color: secondary)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final hex in _colors)
                          ChoiceChip(
                            label: Text(hex),
                            selected: _colorHex == hex,
                            avatar: CircleAvatar(backgroundColor: _hexColor(hex)),
                            onSelected: (_) => setState(() => _colorHex = hex),
                          ),
                      ],
                    ),
                    if (_validation != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _validation!,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: AppColors.expenseText(brightness),
                        ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    FilledButton(
                      key: const ValueKey('save-category-button'),
                      onPressed: _submit,
                      child: Text(widget.current == null ? 'criar' : 'salvar alterações'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CategoryIconPicker extends StatefulWidget {
  const CategoryIconPicker({super.key, required this.selectedKey});
  final String selectedKey;

  @override
  State<CategoryIconPicker> createState() => _CategoryIconPickerState();
}

class _CategoryIconPickerState extends State<CategoryIconPicker> {
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
    final choices = CategoryIconCatalog.search(_query);
    final width = MediaQuery.sizeOf(context).width;
    final columns = width >= 1024 ? 6 : width >= 600 ? 5 : 4;

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 680),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('escolha um ícone', style: AppTypography.section(context, fontSize: 20)),
              const SizedBox(height: 12),
              TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'buscar ícone',
                  prefixIcon: Icon(AppIcons.search),
                ),
                onChanged: (value) => setState(() => _query = value),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: GridView.builder(
                  key: const ValueKey('category-icon-grid'),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: columns,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: .95,
                  ),
                  itemCount: choices.length,
                  itemBuilder: (context, index) {
                    final choice = choices[index];
                    final selected = choice.key == widget.selectedKey;
                    final accent = AppColors.primaryPurple(brightness);
                    return Material(
                      color: selected
                          ? accent.withValues(alpha: .10)
                          : AppColors.surface(brightness),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: selected ? accent : AppColors.border(brightness),
                        ),
                      ),
                      child: InkWell(
                        key: ValueKey('category-icon-${choice.key}'),
                        onTap: () => Navigator.of(context).pop(choice.key),
                        borderRadius: BorderRadius.circular(16),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(choice.icon, size: 24, color: selected ? accent : null),
                              const SizedBox(height: 7),
                              Text(
                                choice.label,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: AppTypography.label(context, fontSize: 9),
                              ),
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
      ),
    );
  }
}

class _CategoryDraft {
  const _CategoryDraft({
    required this.name,
    required this.parentId,
    required this.essential,
    required this.colorHex,
    required this.iconKey,
    required this.aliases,
  });

  final String name;
  final String? parentId;
  final bool essential;
  final String colorHex;
  final String iconKey;
  final List<String> aliases;
}

Color _hexColor(String value) {
  final normalized = value.replaceAll('#', '');
  final parsed = int.tryParse(normalized, radix: 16) ?? 0x8C8CA8;
  return Color(0xFF000000 | parsed);
}
