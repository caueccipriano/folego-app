part of 'transactions_screen_base.dart';

class _RecurringTab extends StatelessWidget {
  const _RecurringTab({
    required this.items,
    required this.categories,
    required this.isDark,
    required this.onRefresh,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final List<RecurringItem> items;
  final List<CategoryItem> categories;
  final bool isDark;
  final Future<void> Function() onRefresh;
  final Future<void> Function(RecurringItem) onEdit;
  final Future<void> Function(RecurringItem) onRealize;
  final Future<void> Function(RecurringItem) onToggle;
  final Future<void> Function(RecurringItem) onDelete;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return AppContentContainer.list(
        fillHeight: true,
        child: RefreshIndicator(
          onRefresh: onRefresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(0, 90, 0, 120),
            children: [
              CategoryIconBadge(
                icon: CategoryVisuals.iconFor(category: 'A classificar'),
                color: CategoryVisuals.colorFor(
                  category: 'A classificar',
                  brightness: Theme.of(context).brightness,
                ),
                size: 50,
                iconSize: 25,
              ),
              const SizedBox(height: 16),
              Text(
                'Nenhuma recorrência',
                textAlign: TextAlign.center,
                style: AppTypography.section(context, fontSize: 18),
              ),
              const SizedBox(height: 8),
              Text(
                'Para criar uma, volte para a Home e registre um Gasto ou Receita escolhendo uma repetição.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .58),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return AppContentContainer.list(
      fillHeight: true,
      child: RefreshIndicator(
        onRefresh: onRefresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(0, 18, 0, 120),
          children: [
            Text(
              'Suas recorrências',
              style: AppTypography.section(context, fontSize: 18),
            ),
            const SizedBox(height: 5),
            Text(
              'Edite ou pause o que se repete no seu mês.',
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: .58),
              ),
            ),
            const SizedBox(height: 20),
            ...items.map(
              (item) => _RecurringCard(
                item: item,
                categories: categories,
                isDark: isDark,
                onEdit: () => onEdit(item),
                onRealize: () => onRealize(item),
                onToggle: () => onToggle(item),
                onDelete: () => onDelete(item),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({
    required this.item,
    required this.categories,
    required this.isDark,
    required this.onEdit,
    required this.onRealize,
    required this.onToggle,
    required this.onDelete,
  });

  final RecurringItem item;
  final List<CategoryItem> categories;
  final bool isDark;
  final VoidCallback onEdit;
  final VoidCallback onRealize;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final visual = _visualForRecurring(context);
    final amountColor = item.isIncome
        ? isDark
              ? AppPalette.lime
              : AppPalette.green
        : primaryText;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 15, 8, 15),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border),
      ),
      child: Row(
        children: [
          CategoryIconBadge(
            icon: visual.icon,
            color: visual.color,
            size: 46,
            iconSize: 23,
            radius: 15,
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.name,
                        style: AppTypography.body(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primaryText,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      Formatters.money(item.amount),
                      style: AppTypography.money(
                        context,
                        fontSize: 14,
                        color: amountColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  item.scheduleLabel,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    item.typeLabel,
                    if (item.categoryName != null) item.categoryName!,
                    if (item.accountName != null) item.accountName!,
                  ].join(' • '),
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 9),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: item.active
                        ? AppPalette.green.withValues(alpha: .13)
                        : secondaryText.withValues(alpha: .08),
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    item.active ? 'Ativa' : 'Pausada',
                    style: AppTypography.label(
                      context,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: item.active ? AppPalette.green : secondaryText,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _showRecurringActions(context),
            borderRadius: BorderRadius.circular(14),
            child: Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: secondaryText.withValues(alpha: .07),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: border),
              ),
              child: Text(
                '⋮',
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _TransactionVisual _visualForRecurring(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    if (item.isIncome) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'Receitas'),
        color: CategoryVisuals.colorFor(
          category: 'Receitas',
          brightness: brightness,
        ),
      );
    }

    final name = item.categoryName;
    if (name == null || name.trim().isEmpty) {
      return _TransactionVisual(
        icon: CategoryVisuals.iconFor(category: 'A classificar'),
        color: CategoryVisuals.colorFor(
          category: 'A classificar',
          brightness: brightness,
        ),
      );
    }

    CategoryItem? matched;
    for (final category in categories) {
      if (category.name == name) {
        matched = category;
        break;
      }
    }

    String categoryName = name;
    String? subcategory;
    if (matched?.parentId != null) {
      for (final parent in categories) {
        if (parent.id == matched!.parentId) {
          categoryName = parent.name;
          subcategory = matched.name;
          break;
        }
      }
    }

    return _TransactionVisual(
      icon: CategoryVisuals.iconFor(
        category: categoryName,
        subcategory: subcategory,
      ),
      color: CategoryVisuals.colorFor(
        category: categoryName,
        brightness: brightness,
      ),
    );
  }

  Future<void> _showRecurringActions(BuildContext context) async {
    final actions = <_SheetAction>[
      if (item.active)
        _SheetAction(
          value: 'realize',
          label: item.isIncome ? 'Marcar como recebido' : 'Marcar como pago',
        ),
      const _SheetAction(value: 'edit', label: 'Editar recorrência'),
      _SheetAction(value: 'toggle', label: item.active ? 'Pausar' : 'Reativar'),
      const _SheetAction(
        value: 'delete',
        label: 'Excluir recorrência',
        destructive: true,
      ),
    ];
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      showDragHandle: false,
      backgroundColor: Colors.transparent,
      builder: (_) => _FolegoActionSheet(title: item.name, actions: actions),
    );
    if (action == 'realize') onRealize();
    if (action == 'edit') onEdit();
    if (action == 'toggle') onToggle();
    if (action == 'delete') onDelete();
  }
}

class _FolegoActionSheet extends StatelessWidget {
  const _FolegoActionSheet({required this.title, required this.actions});
  final String title;
  final List<_SheetAction> actions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? AppColors.darkSurface : AppColors.lightSurface;
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return Center(
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 10),
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: border),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: border,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.body(
                  context,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: primaryText,
                ),
              ),
              const SizedBox(height: 14),
              ...actions.map((action) {
                final foreground = action.destructive
                    ? AppPalette.pink
                    : primaryText;
                final background = action.destructive
                    ? AppPalette.pink.withValues(alpha: .09)
                    : secondaryText.withValues(alpha: .07);
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(action.value),
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      width: double.infinity,
                      height: 50,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: background,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        action.label,
                        textAlign: TextAlign.center,
                        style: AppTypography.body(
                          context,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: foreground,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction {
  const _SheetAction({
    required this.value,
    required this.label,
    this.destructive = false,
  });
  final String value;
  final String label;
  final bool destructive;
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
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
            const Icon(Icons.cloud_off_rounded, size: 46),
            const SizedBox(height: 14),
            Text(
              'Não foi possível carregar os lançamentos.',
              textAlign: TextAlign.center,
              style: AppTypography.section(context, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.body(context, fontSize: 12),
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: onRetry,
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatDate(DateTime date) {
  final day = date.day.toString().padLeft(2, '0');
  final month = date.month.toString().padLeft(2, '0');
  return '$day/$month/${date.year}';
}
