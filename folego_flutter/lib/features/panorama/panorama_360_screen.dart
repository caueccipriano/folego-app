import 'package:flutter/material.dart';

import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/repositories/folego_repository.dart';
import '../goals/goals_screen.dart';
import '../plan/flexible_budget_screen.dart';
import '../transactions/transactions_screen.dart';
import 'panorama_360_data.dart';

/// Combines existing canonical sources; opening this screen writes nothing.
class Panorama360Screen extends StatefulWidget {
  const Panorama360Screen({
    super.key,
    required this.repository,
    required this.space,
    this.loadOverride,
  });

  final FolegoRepository repository;
  final FinancialSpace space;
  @visibleForTesting
  final Panorama360Loader? loadOverride;

  @override
  State<Panorama360Screen> createState() => _Panorama360ScreenState();
}

class _Panorama360ScreenState extends State<Panorama360Screen> {
  Panorama360Data? _data;
  bool _loading = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant Panorama360Screen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space.id != widget.space.id ||
        oldWidget.repository != widget.repository) {
      ++_generation;
      _data = null; // Never expose cached A data after switching to B.
      _loading = true;
      _load();
    }
  }

  Future<void> _load() async {
    final request = ++_generation;
    if (mounted) setState(() => _loading = true);
    try {
      final loader = widget.loadOverride ??
          Panorama360DataLoader(widget.repository).load;
      final data = await loader(widget.space.id);
      if (!mounted || request != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || request != _generation) return;
      setState(() {
        _data = null; // Failed queries must never masquerade as zero.
        _loading = false;
      });
    }
  }

  void _budget() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => FlexibleBudgetScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ));

  void _goals() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => GoalsScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ));

  void _transactions() => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TransactionsScreen(
          repository: widget.repository,
          space: widget.space,
        ),
      ));

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).brightness;
    final data = _data;
    return Scaffold(
      backgroundColor: AppColors.background(theme),
      appBar: AppBar(
        title: const Text('Panorama 360'),
        actions: [
          IconButton(
            key: const ValueKey('panorama-refresh'),
            tooltip: 'Atualizar panorama',
            onPressed: _loading ? null : _load,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: _loading && data == null
              ? const Center(child: CircularProgressIndicator())
              : data == null || !data.hasAnyData
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'não foi possível verificar seu panorama',
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            key: const ValueKey('panorama-retry'),
                            onPressed: _load,
                            child: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        key: const ValueKey('panorama-content'),
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(0, 12, 0, 32),
                        children: [
                          Text(
                            'a visão completa, sem misturar os números',
                            style: AppTypography.section(context, fontSize: 17),
                          ),
                          const SizedBox(height: 7),
                          Text(
                            'Somente leitura · dados do espaço selecionado. '
                            'Uma informação indisponível não é saldo zero.',
                            style: AppTypography.body(context, fontSize: 12),
                          ),
                          if (_loading) ...[
                            const SizedBox(height: 12),
                            const LinearProgressIndicator(),
                          ],
                          const SizedBox(height: 16),
                          _spendable(data.snapshot),
                          const SizedBox(height: 12),
                          _economics(data.monthlyMoney),
                          const SizedBox(height: 12),
                          _budgetCard(data),
                          const SizedBox(height: 12),
                          _goalCard(data),
                          const SizedBox(height: 12),
                          _upcomingCard(data),
                          const SizedBox(height: 14),
                          Text(
                            'Pagamentos de fatura, transferências e aportes '
                            'não entram novamente como despesas. '
                            'Uma meta registrada não comprova dinheiro investido.',
                            style: AppTypography.body(
                              context, fontSize: 11,
                              color: AppColors.secondaryText(theme),
                            ),
                          ),
                        ],
                      ),
                    ),
        ),
      ),
    );
  }

  Widget _card({
    required String title,
    required IconData icon,
    required Widget content,
    String? action,
    VoidCallback? onAction,
  }) {
    final theme = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: AppColors.surface(theme),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(theme)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, size: 19, color: AppColors.primaryPurple(theme)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  style: AppTypography.section(context, fontSize: 13)),
            ),
            if (action != null && onAction != null)
              TextButton(onPressed: onAction, child: Text(action)),
          ]),
          const SizedBox(height: 12),
          content,
        ],
      ),
    );
  }

  Widget _money(String label, num value, {bool large = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(
            child: Text(label, style: AppTypography.body(context, fontSize: 12)),
          ),
          const SizedBox(width: 9),
          Text(
            Formatters.money(value),
            style: AppTypography.money(context, fontSize: large ? 17 : 12),
          ),
        ]),
      );

  Widget _unavailable() => Text(
        'não foi possível confirmar esta informação',
        style: AppTypography.body(
          context,
          fontSize: 12,
          color: AppColors.secondaryText(Theme.of(context).brightness),
        ),
      );

  Widget _spendable(FolegoSnapshot? snapshot) => _card(
        title: 'seu dinheiro, sem ilusões',
        icon: AppIcons.wallet,
        content: snapshot == null
            ? _unavailable()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text('disponível até o próximo recebimento'),
                  const SizedBox(height: 7),
                  Text(
                    Formatters.money(snapshot.spendablePool),
                    key: const ValueKey('panorama-spendable'),
                    style: AppTypography.money(
                      context,
                      fontSize: 26,
                      color: AppColors.primaryPurple(
                        Theme.of(context).brightness,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  _money('saldo protegido', snapshot.protectedBalance),
                  _money(
                    'compromissos previstos',
                    snapshot.mandatoryOutflowsUntilIncome,
                  ),
                  if (snapshot.shortfall > 0)
                    const Text(
                      'atenção: seus compromissos superam o disponível',
                    ),
                  if (snapshot.needsIncomeSetup)
                    const Text(
                      'informe seu próximo recebimento para aprimorar o cálculo',
                    ),
                ],
              ),
      );

  Widget _economics(MonthlyMoneySummary? summary) => _card(
        title: 'resultado econômico do mês',
        icon: AppIcons.transactions,
        action: 'lançamentos',
        onAction: _transactions,
        content: summary == null
            ? _unavailable()
            : Column(
                children: [
                  _money('receitas', summary.realIncome),
                  _money(
                    'despesas por competência',
                    summary.competenceExpenses,
                  ),
                  const Divider(),
                  _money('resultado do mês', summary.economicResult, large: true),
                  Text(
                    'Os movimentos de caixa são separados das despesas.',
                    style: AppTypography.body(context, fontSize: 11),
                  ),
                ],
              ),
      );

  Widget _budgetCard(Panorama360Data data) {
    final overview = data.budgetSummary;
    final configured = data.budgets
            ?.where((item) => item.isParent)
            .any((item) => item.hasBudget) ??
        false;
    return _card(
      title: 'limites do mês',
      icon: AppIcons.plan,
      action: 'planejar',
      onAction: _budget,
      content: overview == null
          ? _unavailable()
          : !configured
              ? const Text(
                  'nenhum limite por categoria configurado',
                  key: ValueKey('panorama-budget-empty'),
                )
              : Column(children: [
                  _money('planejado', overview.plannedAmount),
                  _money('utilizado', overview.actualAmount),
                  const Divider(),
                  _money('restante', overview.remainingAmount, large: true),
                ]),
    );
  }

  Widget _goalCard(Panorama360Data data) {
    final goals = data.activeGoals;
    return _card(
      title: 'suas metas',
      icon: AppIcons.goals,
      action: 'ver metas',
      onAction: _goals,
      content: goals == null
          ? _unavailable()
          : goals.isEmpty
              ? const Text('você ainda não tem metas ativas')
              : Column(
                  children: goals.take(3).map((goal) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 13),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(goal.name, maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          const SizedBox(height: 5),
                          LinearProgressIndicator(
                            value: goal.visualProgress,
                            minHeight: 5,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            Formatters.money(goal.currentAmount) +
                                ' registrados de ' +
                                Formatters.money(goal.target),
                            style: AppTypography.body(context, fontSize: 11),
                          ),
                        ],
                      ),
                    );
                  }).toList(growable: false),
                ),
    );
  }

  Widget _upcomingCard(Panorama360Data data) {
    final upcoming = data.pendingOutflows();
    return _card(
      title: 'próximos compromissos',
      icon: AppIcons.calendar,
      action: 'ver todos',
      onAction: _transactions,
      content: upcoming == null
          ? _unavailable()
          : upcoming.isEmpty
              ? const Text('nenhuma saída pendente no período consultado')
              : Column(
                  children: upcoming.take(3).map((event) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 5),
                      child: Row(children: [
                        Expanded(
                          child: Text(
                            event.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          Formatters.money(event.amount),
                          style: AppTypography.money(context, fontSize: 12),
                        ),
                      ]),
                    );
                  }).toList(growable: false),
                ),
    );
  }
}
