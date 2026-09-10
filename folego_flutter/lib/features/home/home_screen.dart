import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/repositories/folego_repository.dart';
import '../../shared/widgets/section_card.dart';
import 'quick_register_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.space,
    required this.repository,
  });

  final FinancialSpace space;
  final FolegoRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  FolegoSnapshot? _snapshot;
  String _name = 'Você';
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final values = await Future.wait([
        widget.repository.getProfileName(),
        widget.repository.getSnapshot(widget.space.id),
      ]);
      if (!mounted) return;
      setState(() {
        _name = values[0] as String;
        _snapshot = values[1] as FolegoSnapshot;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _register() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: false,
      builder: (_) => QuickRegisterSheet(space: widget.space, repository: widget.repository),
    );
    if (saved == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _snapshot == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null && _snapshot == null) {
      return SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded, size: 44),
                const SizedBox(height: 12),
                Text(_error!, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
              ],
            ),
          ),
        ),
      );
    }

    final snapshot = _snapshot!;
    final status = _statusPresentation(snapshot.status);
    final budgetProgress = snapshot.monthlyBudgetPlanned <= 0
        ? 0.0
        : (snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned).clamp(0, 1).toDouble();

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 110),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'fôlego',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              color: AppPalette.primary,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Olá, $_name',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w900,
                              letterSpacing: -.4,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Que bom ter você por aqui!',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurface
                                  .withValues(alpha: .66),
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                IconButton(
                  onPressed: () => AppThemeController.toggle(context),
                  tooltip: Theme.of(context).brightness == Brightness.dark
                      ? 'Usar tema claro'
                      : 'Usar tema escuro',
                  icon: Icon(
                    Theme.of(context).brightness == Brightness.dark
                        ? Icons.light_mode_rounded
                        : Icons.dark_mode_rounded,
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _load,
                  tooltip: 'Atualizar',
                  icon: const Icon(Icons.refresh_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppPalette.primary, Color(0xFF4265D6)],
                ),
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: AppPalette.primary.withValues(alpha: .18),
                    blurRadius: 28,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('SEU FÔLEGO HOJE', style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .76), fontWeight: FontWeight.w800, letterSpacing: 1.1)),
                  const SizedBox(height: 14),
                  Text(
                    snapshot.dailyFolego == null ? '—' : Formatters.money(snapshot.dailyFolego),
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w900),
                  ),
                  Text('por dia', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
                  const SizedBox(height: 18),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .13), borderRadius: BorderRadius.circular(99)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(status.icon, size: 18, color: Theme.of(context).colorScheme.onPrimary),
                        const SizedBox(width: 7),
                        Text(status.label, style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontWeight: FontWeight.w800)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    snapshot.daysUntilIncome == null
                        ? 'Configure seu próximo recebimento para liberar o cálculo diário.'
                        : '${Formatters.money(snapshot.spendablePool)} até o próximo recebimento, em ${snapshot.daysUntilIncome} dia${snapshot.daysUntilIncome == 1 ? '' : 's'}.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onPrimary.withValues(alpha: .92), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: _register,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Novo lançamento'),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(child: _MetricCard(label: 'Disponível', value: Formatters.money(snapshot.liquidBalance), icon: Icons.account_balance_wallet_outlined, accent: AppPalette.primary)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Protegido', value: Formatters.money(snapshot.protectedBalance), icon: Icons.shield_outlined, accent: AppPalette.purple)),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _MetricCard(label: 'Comprometido', value: Formatters.money(snapshot.mandatoryOutflowsUntilIncome), icon: Icons.event_busy_outlined, accent: AppPalette.pink)),
                const SizedBox(width: 12),
                Expanded(child: _MetricCard(label: 'Caixa livre', value: Formatters.money(snapshot.cashHeadroom), icon: Icons.savings_outlined, accent: AppPalette.green)),
              ],
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Próximo recebimento', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                        child: Icon(Icons.south_west_rounded, color: Theme.of(context).colorScheme.primary),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(snapshot.nextIncomeDate == null ? 'Ainda não configurado' : Formatters.shortDate.format(snapshot.nextIncomeDate!), style: const TextStyle(fontWeight: FontWeight.w800)),
                            Text(snapshot.nextIncomeDate == null ? 'Adicione um recebimento recorrente' : 'Entrada confirmada'),
                          ],
                        ),
                      ),
                      Text(Formatters.money(snapshot.nextIncomeAmount), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(child: Text('Seu orçamento variável', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800))),
                      Text('${(budgetProgress * 100).round()}%', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(value: snapshot.budgetConfigured ? budgetProgress : 0, minHeight: 9),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    snapshot.budgetConfigured
                        ? '${Formatters.money(snapshot.monthlyBudgetUsed)} usados de ${Formatters.money(snapshot.monthlyBudgetPlanned)}.'
                        : 'Você ainda não configurou um orçamento variável.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SectionCard(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lightbulb_outline_rounded, color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _explanation(snapshot),
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.45, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _explanation(FolegoSnapshot s) {
    if (s.shortfall > 0) {
      return 'Faltam ${Formatters.money(s.shortfall)} para atravessar os compromissos antes do próximo recebimento. O foco agora é preservar caixa.';
    }
    if (s.limitingFactor == 'budget') {
      return 'Seu caixa permitiria mais, mas o orçamento mensal é o limite mais seguro agora.';
    }
    return 'Seu orçamento comporta o ritmo, mas os compromissos antes do próximo recebimento estão limitando o caixa disponível.';
  }

  _StatusPresentation _statusPresentation(String status) {
    switch (status) {
      case 'tranquilo':
        return const _StatusPresentation('Dentro do plano', Icons.check_circle_outline_rounded);
      case 'apertado':
        return const _StatusPresentation('Apertado', Icons.warning_amber_rounded);
      case 'segure_gastos':
        return const _StatusPresentation('Segure gastos', Icons.block_rounded);
      case 'sem_folga':
        return const _StatusPresentation('Sem folga', Icons.remove_circle_outline_rounded);
      case 'configurar_recebimento':
        return const _StatusPresentation('Configure seu recebimento', Icons.tune_rounded);
      default:
        return const _StatusPresentation('Atenção', Icons.info_outline_rounded);
    }
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SectionCard(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: isDark ? .22 : .12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 19, color: accent),
          ),
          const SizedBox(height: 10),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPresentation {
  const _StatusPresentation(this.label, this.icon);
  final String label;
  final IconData icon;
}
