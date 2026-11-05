import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/app_color_tokens.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import 'home_overview_modules_settings.dart';

/// Modular overview backed by the existing real finance data. Read-only.
/// An unavailable accounts service never substitutes invented balances.
class HomeBudgetOverviewPanel extends StatefulWidget {
  const HomeBudgetOverviewPanel({
    super.key,
    required this.snapshot,
    required this.repository,
    required this.spaceId,
    required this.hidden,
    required this.onExpense,
    required this.onIncome,
    required this.onBudget,
    this.onAccounts,
  });

  final FolegoSnapshot snapshot;
  final FolegoRepository repository;
  final String spaceId;
  final bool hidden;
  final VoidCallback onExpense;
  final VoidCallback onIncome;
  final VoidCallback onBudget;
  final VoidCallback? onAccounts;

  @override
  State<HomeBudgetOverviewPanel> createState() => _HomeBudgetOverviewPanelState();
}

class _HomeBudgetOverviewPanelState extends State<HomeBudgetOverviewPanel> {
  late Future<WalletOverview> _wallet;
  HomeOverviewModulesSettings _modules = const HomeOverviewModulesSettings(
    order: HomeOverviewModulesSettings.defaultOrder,
    hidden: <String>{},
  );
  int _settingsLoadVersion = 0;
  Future<void> _queuedSave = Future<void>.value();

  static const _titles = <String, String>{
    'actions': 'Atalhos',
    'budget': 'Orçamentos',
    'accounts': 'Contas',
  };

  void _loadModules() {
    final version = ++_settingsLoadVersion;
    final spaceId = widget.spaceId;
    HomeOverviewModulesSettings.load(spaceId).then((value) {
      if (!mounted || version != _settingsLoadVersion) return;
      setState(() => _modules = value);
    }).catchError((Object _) {
      // Keep all modules available when local preferences cannot be read.
    });
  }

  void _changeModules(HomeOverviewModulesSettings next, StateSetter refresh) {
    ++_settingsLoadVersion;
    setState(() => _modules = next);
    refresh(() {});
    final spaceId = widget.spaceId;
    // Serialize preference writes so repeated taps cannot restore old order.
    _queuedSave = _queuedSave.then((_) => next.save(spaceId))
        .catchError((Object _) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(content: Text(
          'Não foi possível salvar a organização neste dispositivo.',
        )),
      );
    });
  }

  Future<void> _organizeModules() async {
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, refresh) => SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 8, 18, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('organizar visão geral',
                  style: AppTypography.section(sheetContext, fontSize: 20)),
                const SizedBox(height: 5),
                Text(
                  'Escolha o que aparece e a ordem. Seu valor disponível '
                  'continua sempre visível.',
                  style: AppTypography.body(sheetContext, fontSize: 12),
                ),
                const SizedBox(height: 14),
                for (var i = 0; i < _modules.order.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      Switch.adaptive(
                        key: ValueKey('overview-visible-${_modules.order[i]}'),
                        value: _modules.isVisible(_modules.order[i]),
                        onChanged: (show) => _changeModules(
                          _modules.withVisibility(_modules.order[i], show),
                          refresh,
                        ),
                      ),
                      Expanded(child: Text(
                        _titles[_modules.order[i]] ?? _modules.order[i],
                        style: AppTypography.body(sheetContext,
                            fontSize: 13, fontWeight: FontWeight.w600),
                      )),
                      IconButton(
                        key: ValueKey('overview-up-${_modules.order[i]}'),
                        tooltip: 'mover para cima',
                        onPressed: i == 0 ? null : () => _changeModules(
                          _modules.move(_modules.order[i], -1), refresh,
                        ),
                        icon: const Icon(Icons.arrow_upward_rounded, size: 19),
                      ),
                      IconButton(
                        key: ValueKey('overview-down-${_modules.order[i]}'),
                        tooltip: 'mover para baixo',
                        onPressed: i == _modules.order.length - 1
                            ? null : () => _changeModules(
                                _modules.move(_modules.order[i], 1), refresh,
                              ),
                        icon: const Icon(Icons.arrow_downward_rounded, size: 19),
                      ),
                    ]),
                  ),
                const SizedBox(height: 8),
                Row(children: [
                  TextButton(
                    key: const ValueKey('overview-restore-defaults'),
                    onPressed: () => _changeModules(
                      const HomeOverviewModulesSettings(
                        order: HomeOverviewModulesSettings.defaultOrder,
                        hidden: <String>{},
                      ),
                      refresh,
                    ),
                    child: const Text('restaurar padrão'),
                  ),
                  const Spacer(),
                  SizedBox(
                    width: 120,
                    child: FilledButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('concluir'),
                    ),
                  ),
                ]),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _fetch();
    _loadModules();
  }

  @override
  void didUpdateWidget(covariant HomeBudgetOverviewPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.repository != widget.repository) {
      _fetch();
    }
    if (oldWidget.spaceId != widget.spaceId) {
      _modules = const HomeOverviewModulesSettings(
        order: HomeOverviewModulesSettings.defaultOrder,
        hidden: <String>{},
      );
      _loadModules();
    }
  }

  void _fetch() {
    _wallet = widget.repository.getWalletOverview(spaceId: widget.spaceId);
  }

  String _money(num amount) =>
      widget.hidden ? '••••' : Formatters.money(amount);

  @override
  Widget build(BuildContext context) {
    final colors = FolegoColorTokens.of(context);
    final snapshot = widget.snapshot;
    final planned = snapshot.monthlyBudgetPlanned;
    final used = snapshot.monthlyBudgetUsed;
    final budgetReady = snapshot.budgetConfigured && planned > 0;
    final remaining = planned - used;
    final fraction = budgetReady ? (used / planned).clamp(0.0, 1.0).toDouble() : 0.0;

    Widget metric(String title, String value, {Color? tone}) {
      return Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, maxLines: 2, style: AppTypography.label(context,
                fontSize: 11, color: colors.textoSecundario)),
            const SizedBox(height: 5),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value, style: AppTypography.money(
                  context, fontSize: 18, color: tone ?? colors.textoPrincipal)),
            ),
          ],
        ),
      );
    }

    Widget heading(String title, String subtitle, {VoidCallback? onTap}) =>
      Row(
        children: [
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.section(
                  context, fontSize: 18, color: colors.textoPrincipal)),
              const SizedBox(height: 3),
              Text(subtitle, style: AppTypography.label(
                  context, fontSize: 11, color: colors.textoSecundario)),
            ],
          )),
          if (onTap != null)
            IconButton(
              tooltip: 'ver detalhes',
              onPressed: onTap,
              icon: Icon(AppIcons.chevronRight,
                  size: 19, color: colors.textoSecundario),
            ),
        ],
      );

    Widget surface(Widget child) => Container(
      decoration: BoxDecoration(
        color: colors.superficie,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.borda),
      ),
      padding: const EdgeInsets.all(16),
      child: child,
    );

    Widget shortcut(String label, IconData icon, VoidCallback onTap, String key) {
      return Expanded(child: Material(
        color: colors.superficie,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey(key),
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            height: 78,
            decoration: BoxDecoration(
              border: Border.all(color: colors.borda),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: colors.marca, size: 22),
                const SizedBox(height: 6),
                Text(label, style: AppTypography.label(context,
                    fontSize: 11, color: colors.textoPrincipal)),
              ],
            ),
          ),
        ),
      ));
    }

    final sectionWidgets = <String, Widget>{
      'actions': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        heading('atalhos', 'registre com poucos toques'),
        const SizedBox(height: 10),
        Row(children: [
          shortcut('gasto', AppIcons.expense, widget.onExpense,
              'budget-flow-register-expense'),
          const SizedBox(width: 8),
          shortcut('receita', AppIcons.income, widget.onIncome,
              'budget-flow-register-income'),
          const SizedBox(width: 8),
          shortcut('orçamento', AppIcons.plan, widget.onBudget,
              'budget-flow-open-budget'),
        ]),
        ],
      ),
      'budget': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        heading('orçamentos', 'planejado e disponível por mês',
            onTap: widget.onBudget),
        const SizedBox(height: 10),
        Material(
          color: colors.superficie,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            key: const ValueKey('budget-flow-budget-card'),
            onTap: widget.onBudget,
            borderRadius: BorderRadius.circular(20),
            child: surface(Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(children: [
                  metric('planejado', budgetReady
                      ? _money(planned) : 'não configurado'),
                  const SizedBox(width: 12),
                  metric('disponível no limite', budgetReady
                      ? _money(remaining) : 'definir',
                      tone: widget.hidden ? null : (remaining < 0 ? colors.estourado : null)),
                ]),
                if (budgetReady && !widget.hidden) ...[
                  const SizedBox(height: 13),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: fraction,
                      minHeight: 7,
                      color: remaining < 0 ? colors.estourado : colors.marca,
                      backgroundColor: colors.borda,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(widget.hidden
                      ? 'utilização oculta'
                      : 'usado no mês: ${_money(used)}',
                      style: AppTypography.label(context,
                          fontSize: 11, color: colors.textoSecundario)),
                ],
              ],
            )),
          ),
        ),
        ],
      ),
      'accounts': Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
        heading('contas', 'saldos bancários, não o fôlego disponível',
            onTap: widget.onAccounts),
        const SizedBox(height: 10),
        FutureBuilder<WalletOverview>(
          future: _wallet,
          builder: (context, result) {
            if (result.connectionState != ConnectionState.done) {
              return const Padding(
                padding: EdgeInsets.all(18),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            if (result.hasError) {
              return OutlinedButton.icon(
                onPressed: () => setState(_fetch),
                icon: const Icon(AppIcons.refresh),
                label: const Text('tentar carregar contas'),
              );
            }
            final accounts = result.data?.paymentAccounts ??
                const <WalletAccount>[];
            if (accounts.isEmpty) {
              return Text('nenhuma conta cadastrada',
                  style: AppTypography.body(context,
                      fontSize: 12, color: colors.textoSecundario));
            }
            return Column(
              key: const ValueKey('budget-flow-accounts'),
              children: [
                for (final account in accounts.take(4)) ...[
                  Material(
                    color: colors.superficie,
                    borderRadius: BorderRadius.circular(16),
                    child: InkWell(
                      onTap: widget.onAccounts,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: colors.borda),
                        ),
                        child: Row(children: [
                          Icon(AppIcons.account, color: colors.marca, size: 22),
                          const SizedBox(width: 12),
                          Expanded(child: Text(account.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.cardTitle(context,
                                fontSize: 13))),
                          const SizedBox(width: 8),
                          Text(_money(account.balance),
                              style: AppTypography.money(
                                  context, fontSize: 13)),
                          if (widget.onAccounts != null) ...[
                            const SizedBox(width: 5),
                            Icon(AppIcons.chevronRight,
                                color: colors.textoSecundario, size: 16),
                          ],
                        ]),
                      ),
                    ),
                  ),
                  const SizedBox(height: 7),
                ],
                if (accounts.length > 4)
                  TextButton(onPressed: widget.onAccounts,
                      child: const Text('ver todas as contas')),
              ],
            );
          },
        ),
        ],
      ),
    };

    return Column(
      key: const ValueKey('budget-flow-overview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Expanded(child: Text('visão geral', style: AppTypography.section(
              context, fontSize: 22, color: colors.textoPrincipal))),
          IconButton(
            key: const ValueKey('budget-flow-organize'),
            tooltip: 'organizar painel',
            onPressed: _organizeModules,
            icon: Icon(Icons.tune_rounded,
                color: colors.textoSecundario, size: 19),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: colors.marca.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(99),
            ),
            child: Text('este mês', style: AppTypography.label(
                context, fontSize: 11, color: colors.marca)),
          ),
        ]),
        const SizedBox(height: 6),
        Text('Seu dinheiro em um só lugar',
            style: AppTypography.body(context,
                fontSize: 12, color: colors.textoSecundario)),
        const SizedBox(height: 16),
        surface(Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('DISPONÍVEL ATÉ RECEBER',
                style: AppTypography.label(context,
                    fontSize: 11, color: colors.textoSecundario)),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(_money(snapshot.spendablePool),
                  key: const ValueKey('budget-flow-spendable'),
                  style: AppTypography.money(context,
                      fontSize: 32, color: colors.textoPrincipal)),
            ),
            const SizedBox(height: 13),
            Divider(height: 1, color: colors.borda),
            const SizedBox(height: 13),
            Row(children: [
              metric('por dia', snapshot.dailyFolego == null
                  ? 'a definir' : _money(snapshot.dailyFolego!)),
              const SizedBox(width: 14),
              metric('próximo salário', snapshot.daysUntilIncome == null
                  ? 'a definir'
                  : '${snapshot.daysUntilIncome} dias'),
            ]),
          ],
        )),
        for (final section in _modules.order)
          if (_modules.isVisible(section)) ...[
            const SizedBox(height: 18),
            KeyedSubtree(
              key: ValueKey('overview-section-$section'),
              child: sectionWidgets[section]!,
            ),
          ],
      ],
    );
  }
}
