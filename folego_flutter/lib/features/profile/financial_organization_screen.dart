import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../data/models/category_item.dart';
import '../../data/models/category_tag.dart';
import '../../data/models/financial_annotation_target.dart';
import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_categories.dart';
import '../../shared/widgets/category_icon_badge.dart';

class FinancialOrganizationScreen extends StatefulWidget {
  const FinancialOrganizationScreen({
    super.key,
    required this.repository,
  });

  final FolegoRepository repository;

  @override
  State<FinancialOrganizationScreen> createState() =>
      _FinancialOrganizationScreenState();
}

class _FinancialOrganizationScreenState
    extends State<FinancialOrganizationScreen> {
  FinancialSpace? _space;
  List<CategoryItem> _categories = const [];
  List<CategoryTag> _tags = const [];
  List<FinancialAnnotationTarget> _targets = const [];

  String _categoryKind = 'expense';
  String _tagType = 'tag';
  final _annotationSearch = TextEditingController();

  bool _loading = true;
  bool _mutating = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _annotationSearch.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }

    try {
      final space = _space ?? await widget.repository.getPrimarySpace();
      final values = await Future.wait<dynamic>([
        widget.repository.listManageableCategories(space.id),
        widget.repository.listAllCategoryTags(space.id),
        widget.repository.listAnnotationTargets(space.id),
      ]);

      if (!mounted) return;
      setState(() {
        _space = space;
        _categories = values[0] as List<CategoryItem>;
        _tags = values[1] as List<CategoryTag>;
        _targets = values[2] as List<FinancialAnnotationTarget>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendlyError(error);
      });
    }
  }

  Future<void> _reload() async {
    final space = _space;
    if (space == null) return;

    try {
      final values = await Future.wait<dynamic>([
        widget.repository.listManageableCategories(space.id),
        widget.repository.listAllCategoryTags(space.id),
        widget.repository.listAnnotationTargets(space.id),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = values[0] as List<CategoryItem>;
        _tags = values[1] as List<CategoryTag>;
        _targets = values[2] as List<FinancialAnnotationTarget>;
      });
    } catch (error) {
      if (!mounted) return;
      _message(_friendlyError(error));
    }
  }

  Future<void> _runMutation(Future<void> Function() action) async {
    if (_mutating) return;
    setState(() => _mutating = true);
    try {
      await action();
    } catch (error) {
      if (mounted) _message(_friendlyError(error));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  List<CategoryItem> get _filteredCategories {
    final items = _categories
        .where((category) => category.kind == _categoryKind)
        .toList();
    items.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      final byParent = (a.parentName ?? a.name).compareTo(b.parentName ?? b.name);
      if (byParent != 0) return byParent;
      if (a.isParent != b.isParent) return a.isParent ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  List<CategoryItem> get _expenseParents {
    final items = _categories
        .where(
          (category) =>
              category.kind == 'expense' &&
              category.isParent &&
              category.active,
        )
        .toList();
    items.sort((a, b) => a.name.compareTo(b.name));
    return items;
  }

  List<CategoryTag> get _filteredTags {
    final items = _tags.where((tag) => tag.type == _tagType).toList();
    items.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.name.compareTo(b.name);
    });
    return items;
  }

  List<FinancialAnnotationTarget> get _filteredTargets {
    final query = _annotationSearch.text.trim().toLowerCase();
    final items = _targets.where((target) {
      if (query.isEmpty) return true;
      return target.title.toLowerCase().contains(query) ||
          target.typeLabel.toLowerCase().contains(query);
    }).toList();
    items.sort((a, b) {
      if (a.isRecurring != b.isRecurring) return a.isRecurring ? -1 : 1;
      if (a.date != null && b.date != null) return b.date!.compareTo(a.date!);
      return a.title.compareTo(b.title);
    });
    return items;
  }

  Future<T?> _showAdaptive<T>(Widget child, {double maxWidth = 620}) {
    if (AppBreakpoints.of(context) != AppLayoutSize.compact) {
      return showDialog<T>(
        context: context,
        useRootNavigator: true,
        builder: (dialogContext) => Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: maxWidth,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * .86,
            ),
            child: child,
          ),
        ),
      );
    }

    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(heightFactor: .90, child: child),
    );
  }

  Future<void> _createCategory() async {
    final draft = await _showAdaptive<_CategoryDraft>(
      _CategoryEditor(
        title: 'Nova categoria',
        kind: _categoryKind,
        parents: _categoryKind == 'expense' ? _expenseParents : const [],
      ),
    );
    if (draft == null || _space == null) return;

    await _runMutation(() async {
      await widget.repository.createCustomCategory(
        spaceId: _space!.id,
        name: draft.name,
        kind: _categoryKind,
        parentId: draft.parentId,
        essential: draft.essential,
        colorHex: draft.colorHex,
        searchAliases: draft.aliases,
      );
      await _reload();
      _message('Categoria criada.');
    });
  }

  Future<void> _editCategory(CategoryItem category) async {
    if (!category.isCustom || _space == null) return;
    final draft = await _showAdaptive<_CategoryDraft>(
      _CategoryEditor(
        title: 'Editar categoria',
        kind: category.kind ?? _categoryKind,
        parents: const [],
        current: category,
      ),
    );
    if (draft == null) return;

    await _runMutation(() async {
      await widget.repository.updateCustomCategoryPresentation(
        spaceId: _space!.id,
        categoryId: category.id,
        name: draft.name,
        essential: draft.essential,
        colorHex: draft.colorHex,
        searchAliases: draft.aliases,
      );
      await _reload();
      _message('Categoria atualizada.');
    });
  }

  Future<void> _setCategoryActive(CategoryItem category, bool active) async {
    if (_space == null) return;
    await _runMutation(() async {
      await widget.repository.setCategoryVisibility(
        spaceId: _space!.id,
        categoryId: category.id,
        active: active,
      );
      await _reload();
      _message(active ? 'Categoria reativada.' : 'Categoria ocultada.');
    });
  }

  Future<void> _createTag() async {
    final draft = await _showAdaptive<_TagDraft>(
      _TagEditor(
        title: 'Novo ${_tagTypeLabel(_tagType).toLowerCase()}',
        initialType: _tagType,
      ),
    );
    if (draft == null || _space == null) return;

    await _runMutation(() async {
      await widget.repository.createCategoryTag(
        spaceId: _space!.id,
        name: draft.name,
        type: draft.type,
        colorHex: draft.colorHex,
      );
      await _reload();
      _message('${_tagTypeLabel(draft.type)} criado.');
    });
  }

  Future<void> _editTag(CategoryTag tag) async {
    if (_space == null) return;
    final draft = await _showAdaptive<_TagDraft>(
      _TagEditor(
        title: 'Editar ${_tagTypeLabel(tag.type).toLowerCase()}',
        initialType: tag.type,
        current: tag,
      ),
    );
    if (draft == null) return;

    await _runMutation(() async {
      await widget.repository.updateCategoryTag(
        spaceId: _space!.id,
        tagId: tag.id,
        name: draft.name,
        type: draft.type,
        colorHex: draft.colorHex,
        active: tag.active,
      );
      await _reload();
      _message('${_tagTypeLabel(draft.type)} atualizado.');
    });
  }

  Future<void> _setTagActive(CategoryTag tag, bool active) async {
    if (_space == null) return;
    await _runMutation(() async {
      await widget.repository.setCategoryTagActive(
        spaceId: _space!.id,
        tagId: tag.id,
        active: active,
      );
      await _reload();
      _message(active ? 'Item reativado.' : 'Item ocultado.');
    });
  }

  Future<void> _editAnnotations(FinancialAnnotationTarget target) async {
    final draft = await _showAdaptive<_AnnotationDraft>(
      _AnnotationEditor(target: target, tags: _tags),
    );
    if (draft == null || _space == null) return;

    await _runMutation(() async {
      if (target.isRecurring) {
        await widget.repository.setRecurringAnnotations(
          spaceId: _space!.id,
          itemId: target.id,
          necessityClass: draft.necessityClass,
          behaviorClass: draft.behaviorClass,
          tagIds: draft.tagIds,
        );
      } else {
        await widget.repository.setEventAnnotations(
          spaceId: _space!.id,
          eventId: target.id,
          necessityClass: draft.necessityClass,
          behaviorClass: draft.behaviorClass,
          frequencyClass: draft.frequencyClass,
          tagIds: draft.tagIds,
        );
      }

      if (!mounted) return;
      setState(() {
        _targets = [
          for (final item in _targets)
            if (item.id == target.id && item.targetType == target.targetType)
              item.copyWithAnnotations(
                necessityClass: draft.necessityClass,
                behaviorClass: draft.behaviorClass,
                frequencyClass: draft.frequencyClass,
                tagIds: draft.tagIds,
              )
            else
              item,
        ];
      });
      _message('Classificação atualizada.');
    });
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _friendlyError(Object error) {
    final text = error.toString();
    if (text.contains('write_access_denied')) {
      return 'Você não tem permissão para alterar este espaço.';
    }
    if (text.contains('category_name_required')) {
      return 'Informe um nome para a categoria.';
    }
    if (text.contains('custom_category_not_found')) {
      return 'Esta categoria personalizada não está mais disponível.';
    }
    if (text.contains('invalid_parent_category')) {
      return 'Escolha uma categoria principal válida.';
    }
    return text
        .replaceFirst('Exception: ', '')
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Invalid argument(s): ', '');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Organização financeira'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Categorias'),
              Tab(text: 'Tags'),
              Tab(text: 'Atributos'),
            ],
          ),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? _LoadError(message: _error!, onRetry: _load)
                : TabBarView(
                    children: [
                      _categoriesTab(),
                      _tagsTab(),
                      _attributesTab(),
                    ],
                  ),
      ),
    );
  }

  Widget _categoriesTab() {
    final secondary = AppColors.secondaryText(Theme.of(context).brightness);
    final items = _filteredCategories;

    return AppContentContainer.dashboard(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 120),
          children: [
            Text('Sua taxonomia', style: AppTypography.section(context, fontSize: 20)),
            const SizedBox(height: 5),
            Text(
              'Ocultar não apaga histórico. Categorias próprias podem ser criadas e renomeadas.',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Despesas'),
                  selected: _categoryKind == 'expense',
                  onSelected: (_) => setState(() => _categoryKind = 'expense'),
                ),
                ChoiceChip(
                  label: const Text('Receitas'),
                  selected: _categoryKind == 'income',
                  onSelected: (_) => setState(() => _categoryKind = 'income'),
                ),
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 17),
                  label: const Text('Nova categoria'),
                  onPressed: _mutating ? null : _createCategory,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              const _EmptyCard(
                title: 'Nenhuma categoria disponível',
                subtitle: 'Crie uma categoria personalizada para começar.',
              )
            else
              for (final item in items)
                _CategoryRow(
                  category: item,
                  disabled: _mutating,
                  onEdit: item.isCustom ? () => _editCategory(item) : null,
                  onActiveChanged: (value) => _setCategoryActive(item, value),
                ),
          ],
        ),
      ),
    );
  }

  Widget _tagsTab() {
    final secondary = AppColors.secondaryText(Theme.of(context).brightness);
    final items = _filteredTags;

    return AppContentContainer.dashboard(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 120),
          children: [
            Text(
              'Tags, projetos e pessoas',
              style: AppTypography.section(context, fontSize: 20),
            ),
            const SizedBox(height: 5),
            Text(
              'Contexto sem poluir a taxonomia: viagem, reforma, pessoa, trabalho e outros projetos.',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final type in const ['tag', 'project', 'person'])
                  ChoiceChip(
                    label: Text(_tagTypeLabel(type)),
                    selected: _tagType == type,
                    onSelected: (_) => setState(() => _tagType = type),
                  ),
                ActionChip(
                  avatar: const Icon(AppIcons.add, size: 17),
                  label: Text('Novo ${_tagTypeLabel(_tagType).toLowerCase()}'),
                  onPressed: _mutating ? null : _createTag,
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (items.isEmpty)
              _EmptyCard(
                title: 'Nenhum ${_tagTypeLabel(_tagType).toLowerCase()}',
                subtitle: 'Crie um marcador para usar nos seus lançamentos.',
              )
            else
              for (final item in items)
                _TagRow(
                  tag: item,
                  disabled: _mutating,
                  onEdit: () => _editTag(item),
                  onActiveChanged: (value) => _setTagActive(item, value),
                ),
          ],
        ),
      ),
    );
  }

  Widget _attributesTab() {
    final secondary = AppColors.secondaryText(Theme.of(context).brightness);
    final items = _filteredTargets;

    return AppContentContainer.dashboard(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 20, 0, 120),
          children: [
            Text(
              'Atributos dos lançamentos',
              style: AppTypography.section(context, fontSize: 20),
            ),
            const SizedBox(height: 5),
            Text(
              'Necessidade/Desejo, Fixo/Variável e Recorrente/Pontual ficam separados da categoria.',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _annotationSearch,
              decoration: const InputDecoration(
                labelText: 'Buscar lançamento ou recorrência',
                prefixIcon: Icon(AppIcons.search),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 18),
            if (items.isEmpty)
              const _EmptyCard(
                title: 'Nada para classificar',
                subtitle: 'Lançamentos econômicos e recorrências aparecerão aqui.',
              )
            else
              for (final item in items)
                _AnnotationRow(
                  target: item,
                  tags: _tags,
                  disabled: _mutating,
                  onTap: () => _editAnnotations(item),
                ),
          ],
        ),
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.disabled,
    required this.onActiveChanged,
    this.onEdit,
  });

  final CategoryItem category;
  final bool disabled;
  final ValueChanged<bool> onActiveChanged;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final visual = CategoryVisuals.resolve(
      brightness: brightness,
      category: category.parentName ?? category.name,
      subcategory: category.parentName == null ? null : category.name,
      eventType: category.kind ?? 'expense',
      systemKey: category.systemKey,
      colorHex: category.isSystem ? null : category.colorHex,
    );

    return Opacity(
      opacity: category.active ? 1 : .58,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            CategoryIconBadge(
              icon: visual.icon,
              color: visual.color,
              size: 42,
              iconSize: 21,
              radius: 13,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.breadcrumb,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${category.isSystem ? 'Padrão' : 'Personalizada'}${category.active ? '' : ' · oculta'}',
                    style: AppTypography.body(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            if (onEdit != null)
              IconButton(
                tooltip: 'Editar',
                onPressed: disabled ? null : onEdit,
                icon: const Icon(AppIcons.edit),
              ),
            Switch(
              value: category.active,
              onChanged: disabled ? null : onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.disabled,
    required this.onEdit,
    required this.onActiveChanged,
  });

  final CategoryTag tag;
  final bool disabled;
  final VoidCallback onEdit;
  final ValueChanged<bool> onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final color = _colorFromHex(tag.colorHex) ?? AppColors.primaryPurple(brightness);

    return Opacity(
      opacity: tag.active ? 1 : .58,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: .13),
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(AppIcons.filter, size: 19, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tag.name,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${_tagTypeLabel(tag.type)}${tag.active ? '' : ' · oculto'}',
                    style: AppTypography.body(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Editar',
              onPressed: disabled ? null : onEdit,
              icon: const Icon(AppIcons.edit),
            ),
            Switch(
              value: tag.active,
              onChanged: disabled ? null : onActiveChanged,
            ),
          ],
        ),
      ),
    );
  }
}

class _AnnotationRow extends StatelessWidget {
  const _AnnotationRow({
    required this.target,
    required this.tags,
    required this.disabled,
    required this.onTap,
  });

  final FinancialAnnotationTarget target;
  final List<CategoryTag> tags;
  final bool disabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final selectedTags = <String>[
      for (final id in target.tagIds)
        for (final tag in tags)
          if (tag.id == id) tag.name,
    ];

    final detailParts = <String>[
      target.typeLabel,
      if (target.necessityClass != null) _necessityLabel(target.necessityClass),
      if (target.behaviorClass != null) _behaviorLabel(target.behaviorClass),
      if (target.frequencyClass != null) _frequencyLabel(target.frequencyClass),
      if (selectedTags.isNotEmpty)
        selectedTags.length == 1 ? selectedTags.first : '${selectedTags.length} tags',
    ];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: InkWell(
        onTap: disabled ? null : onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primaryPurple(brightness).withValues(alpha: .11),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  target.isRecurring ? AppIcons.recurring : AppIcons.receipt,
                  size: 20,
                  color: AppColors.primaryPurple(brightness),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      target.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      detailParts.join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 10,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(AppIcons.chevronRight, size: 18, color: secondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryEditor extends StatefulWidget {
  const _CategoryEditor({
    required this.title,
    required this.kind,
    required this.parents,
    this.current,
  });

  final String title;
  final String kind;
  final List<CategoryItem> parents;
  final CategoryItem? current;

  @override
  State<_CategoryEditor> createState() => _CategoryEditorState();
}

class _CategoryEditorState extends State<_CategoryEditor> {
  static const _colors = [
    '#8C8CA8',
    '#2145FF',
    '#934BFF',
    '#00BFD1',
    '#FF8738',
    '#F451B6',
    '#75A83B',
  ];

  late final TextEditingController _name;
  late final TextEditingController _aliases;
  String? _parentId;
  late bool _essential;
  late String _colorHex;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _aliases = TextEditingController(
      text: widget.current?.searchAliases.join(', ') ?? '',
    );
    _parentId = widget.current?.parentId;
    _essential = widget.current?.essential ?? false;
    _colorHex = widget.current?.colorHex ?? '#8C8CA8';
  }

  @override
  void dispose() {
    _name.dispose();
    _aliases.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final aliases = _aliases.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toSet()
        .toList(growable: false);
    Navigator.of(context).pop(
      _CategoryDraft(
        name: name,
        parentId: widget.current == null ? _parentId : widget.current!.parentId,
        essential: _essential,
        colorHex: _colorHex,
        aliases: aliases,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSurface(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          if (widget.current == null && widget.kind == 'expense') ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: _parentId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Categoria principal'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Criar como categoria principal'),
                ),
                for (final parent in widget.parents)
                  DropdownMenuItem<String?>(
                    value: parent.id,
                    child: Text(parent.name),
                  ),
              ],
              onChanged: (value) => setState(() => _parentId = value),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _aliases,
            decoration: const InputDecoration(
              labelText: 'Termos de busca',
              hintText: 'ex.: gasolina, posto, combustível',
            ),
          ),
          const SizedBox(height: 12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Necessidade por padrão'),
            subtitle: const Text('Ajuda a organizar orçamento e análise.'),
            value: _essential,
            onChanged: (value) => setState(() => _essential = value),
          ),
          const SizedBox(height: 12),
          Text('Cor', style: AppTypography.label(context, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final hex in _colors)
                ChoiceChip(
                  label: Text(hex),
                  selected: _colorHex == hex,
                  avatar: CircleAvatar(backgroundColor: _colorFromHex(hex)),
                  onSelected: (_) => setState(() => _colorHex = hex),
                ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(
            onPressed: _submit,
            child: Text(widget.current == null ? 'Criar categoria' : 'Salvar alterações'),
          ),
        ],
      ),
    );
  }
}

class _TagEditor extends StatefulWidget {
  const _TagEditor({
    required this.title,
    required this.initialType,
    this.current,
  });

  final String title;
  final String initialType;
  final CategoryTag? current;

  @override
  State<_TagEditor> createState() => _TagEditorState();
}

class _TagEditorState extends State<_TagEditor> {
  static const _colors = [
    '#2145FF',
    '#934BFF',
    '#00BFD1',
    '#FF8738',
    '#F451B6',
    '#75A83B',
  ];

  late final TextEditingController _name;
  late String _type;
  String? _colorHex;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.current?.name ?? '');
    _type = widget.current?.type ?? widget.initialType;
    _colorHex = widget.current?.colorHex;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    Navigator.of(context).pop(
      _TagDraft(name: name, type: _type, colorHex: _colorHex),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _EditorSurface(
      title: widget.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Nome'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Tipo'),
            items: const [
              DropdownMenuItem(value: 'tag', child: Text('Tag')),
              DropdownMenuItem(value: 'project', child: Text('Projeto')),
              DropdownMenuItem(value: 'person', child: Text('Pessoa')),
            ],
            onChanged: (value) {
              if (value != null) setState(() => _type = value);
            },
          ),
          const SizedBox(height: 16),
          Text('Cor opcional', style: AppTypography.label(context, fontSize: 11)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Automática'),
                selected: _colorHex == null,
                onSelected: (_) => setState(() => _colorHex = null),
              ),
              for (final hex in _colors)
                ChoiceChip(
                  label: Text(hex),
                  selected: _colorHex == hex,
                  avatar: CircleAvatar(backgroundColor: _colorFromHex(hex)),
                  onSelected: (_) => setState(() => _colorHex = hex),
                ),
            ],
          ),
          const SizedBox(height: 22),
          FilledButton(onPressed: _submit, child: const Text('Salvar')),
        ],
      ),
    );
  }
}

class _AnnotationEditor extends StatefulWidget {
  const _AnnotationEditor({required this.target, required this.tags});

  final FinancialAnnotationTarget target;
  final List<CategoryTag> tags;

  @override
  State<_AnnotationEditor> createState() => _AnnotationEditorState();
}

class _AnnotationEditorState extends State<_AnnotationEditor> {
  String? _necessity;
  String? _behavior;
  String? _frequency;
  late final Set<String> _tagIds;

  @override
  void initState() {
    super.initState();
    _necessity = widget.target.necessityClass;
    _behavior = widget.target.behaviorClass;
    _frequency = widget.target.isRecurring ? 'recurring' : widget.target.frequencyClass;
    _tagIds = widget.target.tagIds.toSet();
  }

  void _submit() {
    Navigator.of(context).pop(
      _AnnotationDraft(
        necessityClass: _necessity,
        behaviorClass: _behavior,
        frequencyClass: widget.target.isRecurring ? 'recurring' : _frequency,
        tagIds: _tagIds.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visibleTags = widget.tags
        .where((tag) => tag.active || _tagIds.contains(tag.id))
        .toList();

    return _EditorSurface(
      title: 'Organizar lançamento',
      subtitle: widget.target.title,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String?>(
            initialValue: _necessity,
            decoration: const InputDecoration(labelText: 'Necessidade'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('Não definido')),
              DropdownMenuItem<String?>(value: 'need', child: Text('Necessidade')),
              DropdownMenuItem<String?>(value: 'want', child: Text('Desejo')),
            ],
            onChanged: (value) => setState(() => _necessity = value),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _behavior,
            decoration: const InputDecoration(labelText: 'Comportamento'),
            items: const [
              DropdownMenuItem<String?>(value: null, child: Text('Não definido')),
              DropdownMenuItem<String?>(value: 'fixed', child: Text('Fixo')),
              DropdownMenuItem<String?>(value: 'variable', child: Text('Variável')),
            ],
            onChanged: (value) => setState(() => _behavior = value),
          ),
          const SizedBox(height: 12),
          if (widget.target.isRecurring)
            const InputDecorator(
              decoration: InputDecoration(labelText: 'Frequência'),
              child: Text('Recorrente'),
            )
          else
            DropdownButtonFormField<String?>(
              initialValue: _frequency,
              decoration: const InputDecoration(labelText: 'Frequência'),
              items: const [
                DropdownMenuItem<String?>(value: null, child: Text('Não definido')),
                DropdownMenuItem<String?>(value: 'recurring', child: Text('Recorrente')),
                DropdownMenuItem<String?>(value: 'one_off', child: Text('Pontual')),
              ],
              onChanged: (value) => setState(() => _frequency = value),
            ),
          const SizedBox(height: 18),
          Text('Tags e projetos', style: AppTypography.label(context, fontSize: 11)),
          const SizedBox(height: 8),
          if (visibleTags.isEmpty)
            const Text('Nenhum marcador cadastrado.')
          else
            for (final type in const ['project', 'tag', 'person'])
              if (visibleTags.any((tag) => tag.type == type)) ...[
                Text(_tagTypeLabel(type), style: AppTypography.label(context, fontSize: 10)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    for (final tag in visibleTags.where((tag) => tag.type == type))
                      FilterChip(
                        label: Text('${tag.name}${tag.active ? '' : ' · oculto'}'),
                        selected: _tagIds.contains(tag.id),
                        onSelected: (selected) {
                          setState(() {
                            selected ? _tagIds.add(tag.id) : _tagIds.remove(tag.id);
                          });
                        },
                      ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
          const SizedBox(height: 10),
          FilledButton(onPressed: _submit, child: const Text('Salvar classificação')),
        ],
      ),
    );
  }
}

class _EditorSurface extends StatelessWidget {
  const _EditorSurface({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);

    return Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: border),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: AppTypography.section(context, fontSize: 20)),
                        if (subtitle != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            subtitle!,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.body(context, fontSize: 11, color: secondary),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(AppIcons.close, color: secondary),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              child,
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
    required this.aliases,
  });

  final String name;
  final String? parentId;
  final bool essential;
  final String colorHex;
  final List<String> aliases;
}

class _TagDraft {
  const _TagDraft({
    required this.name,
    required this.type,
    required this.colorHex,
  });

  final String name;
  final String type;
  final String? colorHex;
}

class _AnnotationDraft {
  const _AnnotationDraft({
    required this.necessityClass,
    required this.behaviorClass,
    required this.frequencyClass,
    required this.tagIds,
  });

  final String? necessityClass;
  final String? behaviorClass;
  final String? frequencyClass;
  final List<String> tagIds;
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(title, style: AppTypography.body(context, fontSize: 13, fontWeight: FontWeight.w700)),
          const SizedBox(height: 5),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: AppTypography.body(context, fontSize: 11, color: secondary),
          ),
        ],
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(AppIcons.warning, size: 42),
            const SizedBox(height: 12),
            Text(
              'Não foi possível carregar sua organização financeira.',
              textAlign: TextAlign.center,
              style: AppTypography.section(context, fontSize: 16),
            ),
            const SizedBox(height: 7),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Tentar novamente')),
          ],
        ),
      ),
    );
  }
}

String _tagTypeLabel(String type) {
  switch (type) {
    case 'project':
      return 'Projeto';
    case 'person':
      return 'Pessoa';
    default:
      return 'Tag';
  }
}

String _necessityLabel(String? value) => value == 'need' ? 'Necessidade' : 'Desejo';

String _behaviorLabel(String? value) => value == 'fixed' ? 'Fixo' : 'Variável';

String _frequencyLabel(String? value) => value == 'recurring' ? 'Recorrente' : 'Pontual';

Color? _colorFromHex(String? value) {
  if (value == null) return null;
  final raw = value.replaceAll('#', '').trim();
  if (raw.length != 6) return null;
  final parsed = int.tryParse(raw, radix: 16);
  if (parsed == null) return null;
  return Color(0xFF000000 | parsed);
}
