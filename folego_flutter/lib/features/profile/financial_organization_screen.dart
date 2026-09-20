import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/category_item.dart';
import '../../data/models/category_tag.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/app_empty_state.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';
import 'financial_organization_data_source.dart';

class FinancialOrganizationScreen extends StatefulWidget {
  const FinancialOrganizationScreen({
    super.key,
    required this.repository,
    this.dataSource,
  });

  final FolegoRepository repository;
  final FinancialOrganizationDataSource? dataSource;

  @override
  State<FinancialOrganizationScreen> createState() =>
      _FinancialOrganizationScreenState();
}

class _FinancialOrganizationScreenState
    extends State<FinancialOrganizationScreen> {
  static const Duration _uxTimeout = Duration(seconds: 15);

  late final FinancialOrganizationDataSource _dataSource;

  FinancialSpace? _space;
  List<CategoryItem> _categories = const [];
  List<CategoryTag> _markers = const [];
  String _categoryKind = 'expense';
  String _markerType = 'all';

  bool _spaceLoading = true;
  bool _categoriesLoading = false;
  bool _markersLoading = false;
  bool _categoryMutating = false;
  bool _markerMutating = false;

  String? _spaceError;
  String? _categoriesError;
  String? _markersError;

  @override
  void initState() {
    super.initState();
    _dataSource = widget.dataSource ??
        RepositoryFinancialOrganizationDataSource(widget.repository);
    _loadSpaceAndSections();
  }

  Future<T> _withUxTimeout<T>(Future<T> future) => future.timeout(_uxTimeout);

  Future<void> _loadSpaceAndSections() async {
    if (mounted) {
      setState(() {
        _spaceLoading = true;
        _spaceError = null;
      });
    }

    try {
      final space = _space ?? await _withUxTimeout(_dataSource.getPrimarySpace());
      if (!mounted) return;

      setState(() {
        _space = space;
        _spaceLoading = false;
      });

      // As duas seções são intencionalmente independentes. Uma chamada lenta ou
      // com erro nunca impede a outra de renderizar.
      unawaited(_loadCategories());
      unawaited(_loadMarkers());
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _spaceLoading = false;
        _spaceError = _spaceLoadError(error);
      });
    }
  }

  Future<void> _loadCategories({bool showLoading = true}) async {
    final space = _space;
    if (space == null) return;

    if (mounted) {
      setState(() {
        _categoriesLoading = showLoading || _categories.isEmpty;
        _categoriesError = null;
      });
    }

    try {
      final categories = await _withUxTimeout(
        _dataSource.listCategories(space.id),
      );
      if (!mounted) return;
      setState(() {
        _categories = categories;
        _categoriesLoading = false;
        _categoriesError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _categoriesLoading = false;
        _categoriesError = _sectionLoadError(error, 'categorias');
      });
    }
  }

  Future<void> _loadMarkers({bool showLoading = true}) async {
    final space = _space;
    if (space == null) return;

    if (mounted) {
      setState(() {
        _markersLoading = showLoading || _markers.isEmpty;
        _markersError = null;
      });
    }

    try {
      final markers = await _withUxTimeout(
        _dataSource.listMarkers(space.id),
      );
      if (!mounted) return;
      setState(() {
        _markers = markers;
        _markersLoading = false;
        _markersError = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _markersLoading = false;
        _markersError = _sectionLoadError(error, 'marcadores');
      });
    }
  }

  Future<void> _runCategoryMutation(Future<void> Function() action) async {
    if (_categoryMutating) return;
    setState(() => _categoryMutating = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _categoryMutating = false);
    }
  }

  Future<void> _runMarkerMutation(Future<void> Function() action) async {
    if (_markerMutating) return;
    setState(() => _markerMutating = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _markerMutating = false);
    }
  }

  List<CategoryItem> get _visibleCategories {
    final items = _categories
        .where((category) => category.kind == _categoryKind)
        .toList();
    items.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final byOrder = a.sortOrder.compareTo(b.sortOrder);
      if (byOrder != 0) return byOrder;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  List<CategoryItem> get _activeParents => _categories
      .where(
        (category) =>
            category.kind == _categoryKind &&
            category.isParent &&
            category.active,
      )
      .toList()
    ..sort((a, b) => a.name.compareTo(b.name));

  List<CategoryTag> get _visibleMarkers {
    final items = _markers
        .where((marker) => _markerType == 'all' || marker.type == _markerType)
        .toList();
    items.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return items;
  }

  Future<T?> _showAdaptive<T>(Widget child, {double maxWidth = 560}) {
    if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
      return showModalBottomSheet<T>(
        context: context,
        useSafeArea: true,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(heightFactor: .82, child: child),
      );
    }
    return showDialog<T>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth, maxHeight: 720),
          child: child,
        ),
      ),
    );
  }

  Future<void> _createCategory() async {
    final draft = await _showAdaptive<_CategoryDraft>(
      _CategoryEditor(kind: _categoryKind, parents: _activeParents),
    );
    if (draft == null || _space == null) return;
    await _runCategoryMutation(() async {
      await _dataSource.createCategory(
        spaceId: _space!.id,
        name: draft.name,
        kind: _categoryKind,
        parentId: draft.parentId,
      );
      await _loadCategories(showLoading: false);
      _message('categoria criada');
    });
  }

  Future<void> _editCategory(CategoryItem category) async {
    if (!category.isCustom || _space == null) return;
    final draft = await _showAdaptive<_CategoryDraft>(
      _CategoryEditor(
        kind: category.kind ?? _categoryKind,
        parents: const [],
        current: category,
      ),
    );
    if (draft == null) return;
    await _runCategoryMutation(() async {
      await _dataSource.updateCategory(
        spaceId: _space!.id,
        category: category,
        name: draft.name,
      );
      await _loadCategories(showLoading: false);
      _message('categoria atualizada');
    });
  }

  Future<void> _setCategoryActive(CategoryItem category, bool active) async {
    if (_space == null) return;
    await _runCategoryMutation(() async {
      await _dataSource.setCategoryActive(
        spaceId: _space!.id,
        categoryId: category.id,
        active: active,
      );
      await _loadCategories(showLoading: false);
      _message(active ? 'categoria reativada' : 'categoria desativada');
    });
  }

  Future<void> _createMarker() async {
    final draft = await _showAdaptive<_MarkerDraft>(const _MarkerEditor());
    if (draft == null || _space == null) return;
    await _runMarkerMutation(() async {
      await _dataSource.createMarker(
        spaceId: _space!.id,
        name: draft.name,
        type: draft.type,
      );
      await _loadMarkers(showLoading: false);
      _message('marcador criado');
    });
  }

  Future<void> _editMarker(CategoryTag marker) async {
    if (_space == null) return;
    final draft = await _showAdaptive<_MarkerDraft>(
      _MarkerEditor(current: marker),
    );
    if (draft == null) return;
    await _runMarkerMutation(() async {
      await _dataSource.updateMarker(
        spaceId: _space!.id,
        marker: marker,
        name: draft.name,
        type: draft.type,
      );
      await _loadMarkers(showLoading: false);
      _message('marcador atualizado');
    });
  }

  Future<void> _setMarkerActive(CategoryTag marker, bool active) async {
    if (_space == null) return;
    await _runMarkerMutation(() async {
      await _dataSource.setMarkerActive(
        spaceId: _space!.id,
        markerId: marker.id,
        active: active,
      );
      await _loadMarkers(showLoading: false);
      _message(active ? 'marcador reativado' : 'marcador desativado');
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final accent = AppColors.primaryPurple(brightness);
    final isDark = brightness == Brightness.dark;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background(brightness),
        body: SafeArea(
          child: Column(
            children: [
              AppContentContainer.dashboard(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20, bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppPageHeader(
                        title: 'organização',
                        subtitle: 'categorias e marcadores do seu dinheiro',
                        leading: IconButton(
                          tooltip: 'voltar',
                          onPressed: () => Navigator.of(context).maybePop(),
                          icon: const Icon(AppIcons.back),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: surface,
                          borderRadius: BorderRadius.circular(AppRadii.compactCard),
                          border: Border.all(color: border),
                        ),
                        child: TabBar(
                          dividerColor: Colors.transparent,
                          indicatorSize: TabBarIndicatorSize.tab,
                          indicator: BoxDecoration(
                            color: accent.withValues(alpha: isDark ? .18 : .10),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          labelColor: primary,
                          unselectedLabelColor: secondary,
                          labelStyle: AppTypography.label(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: primary,
                          ),
                          unselectedLabelStyle: AppTypography.label(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: secondary,
                          ),
                          tabs: const [
                            Tab(text: 'categorias'),
                            Tab(text: 'marcadores'),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: _spaceLoading && _space == null
                    ? const AppLoadingState(label: 'organizando suas categorias')
                    : _spaceError != null && _space == null
                        ? AppErrorState(
                            title: 'não consegui abrir sua organização',
                            description: _spaceError,
                            onRetry: _loadSpaceAndSections,
                          )
                        : TabBarView(
                            children: [_categoriesTab(), _markersTab()],
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _categoriesTab() {
    if (_categoriesLoading && _categories.isEmpty) {
      return const _SectionLoading(label: 'carregando categorias');
    }
    if (_categoriesError != null && _categories.isEmpty) {
      return _ErrorState(
        message: _categoriesError!,
        onRetry: _loadCategories,
      );
    }

    final brightness = Theme.of(context).brightness;
    final items = _visibleCategories;
    final ids = items.map((item) => item.id).toSet();
    final roots = items
        .where((item) => item.parentId == null || !ids.contains(item.parentId))
        .toList();
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return AppContentContainer(
      maxWidth: 1040,
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: _loadCategories,
        child: ListView(
          key: ValueKey(
            desktop
                ? 'organization-categories-desktop'
                : 'organization-categories-mobile',
          ),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 110),
          children: [
            if (_categoriesError != null) ...[
              _InlineSectionError(
                message: _categoriesError!,
                onRetry: _loadCategories,
              ),
              const SizedBox(height: 14),
            ],
            if (_categoriesLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 14),
            ],
            _Toolbar(
              title: 'categorias',
              subtitle: 'organize gastos e receitas sem perder o histórico',
              actionLabel: 'nova categoria',
              actionKey: const ValueKey('organization-new-category'),
              onAction: _categoryMutating ? null : _createCategory,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('despesas'),
                  selected: _categoryKind == 'expense',
                  onSelected: (_) => setState(() => _categoryKind = 'expense'),
                ),
                ChoiceChip(
                  label: const Text('receitas'),
                  selected: _categoryKind == 'income',
                  onSelected: (_) => setState(() => _categoryKind = 'income'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (roots.isEmpty)
              const _CompactEmpty(
                icon: AppIcons.categoryUnclassified,
                title: 'nenhuma categoria por aqui',
                text: 'as categorias que você criar vão aparecer nesta árvore',
              )
            else
              for (final root in roots) ...[
                _CategoryTreeGroup(
                  root: root,
                  children: items
                      .where((item) => item.parentId == root.id)
                      .toList(),
                  desktop: desktop,
                  busy: _categoryMutating,
                  onEdit: _editCategory,
                  onActiveChanged: _setCategoryActive,
                ),
                const SizedBox(height: 10),
              ],
            const SizedBox(height: 8),
            Text(
              'Categorias padrão são protegidas. Categorias personalizadas podem ser editadas ou desativadas.',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _markersTab() {
    if (_markersLoading && _markers.isEmpty) {
      return const _SectionLoading(label: 'carregando marcadores');
    }
    if (_markersError != null && _markers.isEmpty) {
      return _ErrorState(
        message: _markersError!,
        onRetry: _loadMarkers,
      );
    }

    final items = _visibleMarkers;
    return AppContentContainer(
      maxWidth: 1040,
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: _loadMarkers,
        child: ListView(
          key: const ValueKey('organization-markers-list'),
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 22, 0, 110),
          children: [
            if (_markersError != null) ...[
              _InlineSectionError(
                message: _markersError!,
                onRetry: _loadMarkers,
              ),
              const SizedBox(height: 14),
            ],
            if (_markersLoading) ...[
              const LinearProgressIndicator(minHeight: 2),
              const SizedBox(height: 14),
            ],
            _Toolbar(
              title: 'marcadores',
              subtitle: 'junte lançamentos por contexto sem mexer nas categorias',
              actionLabel: 'novo marcador',
              actionKey: const ValueKey('organization-new-marker'),
              onAction: _markerMutating ? null : _createMarker,
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in const [
                  ('all', 'Todos'),
                  ('tag', 'Tags'),
                  ('project', 'Projetos'),
                  ('person', 'Pessoas'),
                ])
                  ChoiceChip(
                    label: Text(option.$2),
                    selected: _markerType == option.$1,
                    onSelected: (_) => setState(() => _markerType = option.$1),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              _MarkerEmpty(onCreate: _markerMutating ? null : _createMarker)
            else
              for (final marker in items) ...[
                _MarkerRow(
                  marker: marker,
                  busy: _markerMutating,
                  onEdit: () => _editMarker(marker),
                  onActiveChanged: (active) =>
                      _setMarkerActive(marker, active),
                ),
                const SizedBox(height: 8),
              ],
          ],
        ),
      ),
    );
  }
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) => AppLoadingState(label: label);
}

class _InlineSectionError extends StatelessWidget {
  const _InlineSectionError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
        child: Row(
          children: [
            const Icon(AppIcons.warning, size: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AppTypography.body(context, fontSize: 12),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('tentar novamente')),
          ],
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.title,
    required this.subtitle,
    required this.actionLabel,
    required this.actionKey,
    required this.onAction,
  });

  final String title;
  final String subtitle;
  final String actionLabel;
  final Key actionKey;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final copy = AppSectionHeader(
      title: title,
      subtitle: subtitle,
    );
    final action = FilledButton.icon(
      key: actionKey,
      onPressed: onAction,
      icon: const Icon(AppIcons.add, size: 17),
      label: Text(actionLabel),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 620) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [copy, const SizedBox(height: 12), action],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [Expanded(child: copy), const SizedBox(width: 16), action],
        );
      },
    );
  }
}

class _CategoryTreeGroup extends StatelessWidget {
  const _CategoryTreeGroup({
    required this.root,
    required this.children,
    required this.desktop,
    required this.busy,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CategoryItem root;
  final List<CategoryItem> children;
  final bool desktop;
  final bool busy;
  final ValueChanged<CategoryItem> onEdit;
  final void Function(CategoryItem, bool) onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final decoration = BoxDecoration(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(AppRadii.card),
      border: Border.all(color: AppColors.border(brightness)),
    );
    final rootLine = _CategoryLine(
      item: root,
      busy: busy,
      onEdit: root.isCustom ? () => onEdit(root) : null,
      onActiveChanged: (value) => onActiveChanged(root, value),
    );
    if (!desktop && children.isNotEmpty) {
      return Container(
        decoration: decoration,
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 10),
          childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          title: rootLine,
          children: [
            for (final child in children)
              Padding(
                padding: const EdgeInsets.only(left: 18),
                child: _CategoryLine(
                  item: child,
                  busy: busy,
                  onEdit: child.isCustom ? () => onEdit(child) : null,
                  onActiveChanged: (value) => onActiveChanged(child, value),
                ),
              ),
          ],
        ),
      );
    }
    return Container(
      decoration: decoration,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          rootLine,
          for (final child in children)
            Padding(
              padding: const EdgeInsets.only(left: 28),
              child: _CategoryLine(
                item: child,
                busy: busy,
                onEdit: child.isCustom ? () => onEdit(child) : null,
                onActiveChanged: (value) => onActiveChanged(child, value),
              ),
            ),
        ],
      ),
    );
  }
}

class _CategoryLine extends StatelessWidget {
  const _CategoryLine({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CategoryItem item;
  final bool busy;
  final VoidCallback? onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    return Semantics(
      label: item.name,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 6),
        title: Text(
          item.name,
          style: AppTypography.body(
            context,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: item.isCustom || !item.active
            ? Wrap(
                spacing: 6,
                children: [
                  if (item.isCustom) const _SmallBadge('personalizada'),
                  if (!item.active) const _SmallBadge('desativada'),
                ],
              )
            : null,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (onEdit != null)
              IconButton(
                key: ValueKey('organization-edit-category-${item.id}'),
                tooltip: 'editar',
                onPressed: busy ? null : onEdit,
                icon: const Icon(AppIcons.edit, size: 18),
              ),
            Switch.adaptive(
              value: item.active,
              onChanged: busy ? null : onActiveChanged,
            ),
          ],
        ),
        textColor: item.active ? null : secondary,
      ),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Text(
        label,
        style: AppTypography.label(
          context,
          fontSize: 9,
          color: AppColors.secondaryText(Theme.of(context).brightness),
        ),
      );
}

class _MarkerRow extends StatelessWidget {
  const _MarkerRow({
    required this.marker,
    required this.busy,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CategoryTag marker;
  final bool busy;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: ListTile(
        minVerticalPadding: 12,
        title: Text(marker.name),
        subtitle: Text(
          '${_markerLabel(marker.type)}${marker.active ? '' : ' · desativado'}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              tooltip: 'editar marcador',
              onPressed: busy ? null : onEdit,
              icon: const Icon(AppIcons.edit, size: 18),
            ),
            Switch.adaptive(
              value: marker.active,
              onChanged: busy ? null : onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerEmpty extends StatelessWidget {
  const _MarkerEmpty({required this.onCreate});
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) => _CompactEmpty(
        icon: AppIcons.categoryUnclassified,
        title: 'nenhum marcador ainda',
        text:
            'Use marcadores para juntar gastos de uma viagem, projeto, pessoa ou contexto sem mexer nas categorias.',
        action: TextButton.icon(
          onPressed: onCreate,
          icon: const Icon(AppIcons.add, size: 17),
          label: const Text('criar marcador'),
        ),
      );
}

class _CompactEmpty extends StatelessWidget {
  const _CompactEmpty({
    required this.icon,
    required this.title,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String title;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) => AppEmptyState(
        icon: icon,
        title: title,
        description: text,
        action: action,
      );
}

class _CategoryDraft {
  const _CategoryDraft(this.name, this.parentId);
  final String name;
  final String? parentId;
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({required this.kind, required this.parents, this.current});

  final String kind;
  final List<CategoryItem> parents;
  final CategoryItem? current;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  late final TextEditingController _name;
  String? _parentId;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _parentId = widget.current?.parentId;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(AppRadii.feature),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.current == null ? 'nova categoria' : 'editar categoria',
              style: AppTypography.section(context, fontSize: 19),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'nome'),
            ),
            if (widget.current == null && widget.parents.isNotEmpty) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _parentId ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'nível'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('categoria principal'),
                  ),
                  for (final parent in widget.parents)
                    DropdownMenuItem(
                      value: parent.id,
                      child: Text('dentro de ${parent.name}'),
                    ),
                ],
                onChanged: (value) => setState(
                  () => _parentId = value?.isEmpty == true ? null : value,
                ),
              ),
            ],
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(_CategoryDraft(name, _parentId));
              },
              child: const Text('salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _MarkerDraft {
  const _MarkerDraft(this.name, this.type);
  final String name;
  final String type;
}

class _MarkerEditor extends StatefulWidget {
  const _MarkerEditor({this.current});
  final CategoryTag? current;

  @override
  State<_MarkerEditor> createState() => _MarkerEditorState();
}

class _MarkerEditorState extends State<_MarkerEditor> {
  late final TextEditingController _name;
  late String _type;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _type = widget.current?.type ?? 'tag';
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(AppRadii.feature),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.current == null ? 'novo marcador' : 'editar marcador',
              style: AppTypography.section(context, fontSize: 19),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _name,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'nome'),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'tag', label: Text('Tag')),
                ButtonSegment(value: 'project', label: Text('Projeto')),
                ButtonSegment(value: 'person', label: Text('Pessoa')),
              ],
              selected: {_type},
              onSelectionChanged: (values) => setState(() => _type = values.first),
            ),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                final name = _name.text.trim();
                if (name.isEmpty) return;
                Navigator.of(context).pop(_MarkerDraft(name, _type));
              },
              child: const Text('salvar'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) => AppErrorState(
        title: 'não consegui carregar esta área',
        description: message,
        onRetry: onRetry,
      );
}

String _markerLabel(String type) => switch (type) {
      'project' => 'Projeto',
      'person' => 'Pessoa',
      _ => 'Tag',
    };

String _spaceLoadError(Object error) {
  if (error is TimeoutException) {
    return 'a organização demorou mais que o esperado para responder';
  }
  return 'não consegui abrir sua organização agora';
}

String _sectionLoadError(Object error, String section) {
  final article = section == 'categorias' ? 'suas' : 'seus';
  if (error is TimeoutException) {
    return 'não consegui carregar $article $section agora';
  }
  return 'não consegui carregar $article $section';
}

String _friendlyError(Object error) {
  final text = error.toString();
  if (text.contains('write_access_denied')) {
    return 'você não tem permissão para alterar este espaço';
  }
  if (text.contains('category_name_required')) {
    return 'informe um nome para a categoria';
  }
  return 'não deu pra salvar agora. tente novamente em alguns segundos';
}