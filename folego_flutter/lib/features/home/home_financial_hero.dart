import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';
import '../plan/flexible_budget_navigation_scope.dart';

String? homeIncomeTimingLabel(FolegoSnapshot snapshot) {
  final days = snapshot.daysUntilIncome;
  final date = snapshot.nextIncomeDate;

  if (days == null && date == null) return null;

  if (days == 0) return 'recebimento previsto hoje';
  if (days == 1) {
    return date == null ? 'recebe amanhã' : 'recebe amanhã · ${_shortDate(date)}';
  }
  if (days != null && days > 1) {
    final base = 'recebe em $days dias';
    return date == null ? base : '$base · ${_shortDate(date)}';
  }
  if (date != null) return 'próximo recebimento · ${_shortDate(date)}';
  return null;
}

double homeFlexibleBudgetExceeded(FolegoSnapshot snapshot) {
  final difference =
      snapshot.monthlyBudgetUsed - snapshot.monthlyBudgetPlanned;
  return difference > 0 ? difference.toDouble() : 0;
}

bool homeIsBudgetLimited(FolegoSnapshot snapshot) {
  final factor = snapshot.limitingFactor.trim().toLowerCase();
  return factor == 'budget' ||
      factor == 'economic' ||
      factor == 'both' ||
      factor == 'cash_and_budget';
}

String homeFolegoContextLabel(FolegoSnapshot snapshot) {
  final spendable = snapshot.spendablePool;
  final daily = snapshot.dailyFolego;
  final showDaily = spendable > 0 && daily != null && daily > 0;
  final hasIncomeTiming =
      snapshot.nextIncomeDate != null || snapshot.daysUntilIncome != null;
  final exceeded = homeFlexibleBudgetExceeded(snapshot);

  if (spendable <= 0) {
    return switch (snapshot.limitingFactor.trim().toLowerCase()) {
      'budget' || 'economic' => exceeded > 0
          ? 'seu orçamento flexível passou ${Formatters.money(exceeded)} · ${Formatters.money(snapshot.liquidBalance)} ainda estão em conta'
          : 'o espaço do seu orçamento para gastos flexíveis já foi usado',
      'both' || 'cash_and_budget' =>
        'seu dinheiro disponível e o orçamento para gastos flexíveis chegaram ao limite',
      _ => hasIncomeTiming
          ? 'seus compromissos já ocupam o dinheiro disponível até o próximo recebimento'
          : 'seus compromissos já ocupam o dinheiro disponível',
    };
  }

  if (showDaily) {
    return '${Formatters.money(daily)} por dia até o próximo recebimento';
  }

  if (!hasIncomeTiming) {
    return 'adicione um próximo recebimento no Plano para visualizar o prazo';
  }

  return 'valor disponível até o próximo recebimento';
}

class HomeFinancialHero extends StatelessWidget {
  const HomeFinancialHero({super.key, required this.snapshot});

  final FolegoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < AppBreakpoints.medium;
        return _buildHero(context, compact: compact);
      },
    );
  }

  Widget _buildHero(BuildContext context, {required bool compact}) {
    final brightness = Theme.of(context).brightness;
    final primaryPurple = AppColors.primaryPurple(brightness);
    final onPurple = brightness == Brightness.dark
        ? AppColors.iconOnPurpleDark
        : AppColors.iconOnPurpleLight;
    final timing = homeIncomeTimingLabel(snapshot);
    final spendable = snapshot.spendablePool;
    final contextCopy = homeFolegoContextLabel(snapshot);
    final budgetNavigation = FlexibleBudgetNavigationScope.maybeOf(context);
    final showBudgetAction =
        spendable <= 0 && homeIsBudgetLimited(snapshot) && budgetNavigation != null;

    return Semantics(
      container: true,
      label:
          'valor disponível para gastar até o próximo recebimento: ${Formatters.money(spendable)}',
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.fromLTRB(
          compact ? 18 : 22,
          compact ? 20 : 24,
          compact ? 18 : 22,
          compact ? 18 : 22,
        ),
        decoration: BoxDecoration(
          color: primaryPurple,
          borderRadius: BorderRadius.circular(compact ? AppRadii.feature : AppRadii.sheet),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'quanto você pode gastar',
              style: AppTypography.body(
                context,
                fontSize: compact ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: onPurple.withValues(alpha: .84),
              ),
            ),
            SizedBox(height: compact ? 6 : 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.money(spendable),
                key: const ValueKey('home-spendable-pool'),
                style: AppTypography.money(
                  context,
                  fontSize: compact ? 44 : 52,
                  color: AppColors.lime,
                ),
              ),
            ),
            SizedBox(height: compact ? 8 : 10),
            Text(
              contextCopy,
              key: const ValueKey('home-daily-folego-context'),
              style: AppTypography.body(
                context,
                fontSize: compact ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: onPurple.withValues(alpha: .94),
              ),
            ),
            if (showBudgetAction) ...[
              const SizedBox(height: 4),
              TextButton.icon(
                key: const ValueKey('home-open-flex-budget'),
                style: TextButton.styleFrom(
                  foregroundColor: onPurple,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 34),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: budgetNavigation.open,
                icon: const Icon(AppIcons.chevronRight, size: 16),
                iconAlignment: IconAlignment.end,
                label: const Text('ver onde passei do limite'),
              ),
            ],
            if (timing != null) ...[
              SizedBox(height: compact ? 12 : 14),
              _TimingPill(label: timing, foreground: onPurple),
            ],
            SizedBox(height: compact ? 14 : 16),
            if (compact)
              Row(
                children: [
                  Icon(
                    AppIcons.benefit,
                    size: 16,
                    color: onPurple.withValues(alpha: .74),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'benefícios não entram neste valor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.label(
                        context,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: onPurple.withValues(alpha: .78),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    key: const ValueKey('home-folego-explainer'),
                    style: TextButton.styleFrom(
                      foregroundColor: onPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 6),
                      minimumSize: const Size(0, 34),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => _showExplanation(context),
                    icon: const Icon(AppIcons.info, size: 15),
                    label: const Text('como funciona'),
                  ),
                ],
              )
            else
              Row(
                children: [
                  Icon(
                    AppIcons.benefit,
                    size: 16,
                    color: onPurple.withValues(alpha: .74),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      'benefícios não entram neste valor',
                      style: AppTypography.label(
                        context,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: onPurple.withValues(alpha: .78),
                      ),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('home-folego-explainer'),
                    style: TextButton.styleFrom(
                      foregroundColor: onPurple,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    onPressed: () => _showExplanation(context),
                    icon: const Icon(AppIcons.info, size: 16),
                    label: const Text('como funciona'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExplanation(BuildContext context) async {
    final budgetNavigation = FlexibleBudgetNavigationScope.maybeOf(context);
    final content = _FolegoExplanation(
      snapshot: snapshot,
      onOpenBudget: budgetNavigation?.onOpen,
    );
    if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
      await showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => content,
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520, maxHeight: 680),
          child: content,
        ),
      ),
    );
  }
}

class _TimingPill extends StatelessWidget {
  const _TimingPill({required this.label, required this.foreground});

  final String label;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
        key: const ValueKey('home-income-timing'),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.darkBackground.withValues(alpha: .14),
          borderRadius: BorderRadius.circular(AppRadii.control),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              AppIcons.calendar,
              size: 17,
              color: foreground.withValues(alpha: .88),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground.withValues(alpha: .90),
                ),
              ),
            ),
          ],
        ),
      );
}

class _FolegoExplanation extends StatelessWidget {
  const _FolegoExplanation({
    required this.snapshot,
    this.onOpenBudget,
  });

  final FolegoSnapshot snapshot;
  final VoidCallback? onOpenBudget;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final timing = homeIncomeTimingLabel(snapshot);
    final exceeded = homeFlexibleBudgetExceeded(snapshot);

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'como chegamos nisso?',
                    style: AppTypography.section(context, fontSize: 20),
                  ),
                ),
                IconButton(
                  tooltip: 'fechar',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Aqui você vê os valores que já vieram do seu resumo financeiro. O app não refaz a conta nesta tela.',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 18),
            _ExplanationRow(
              label: 'dinheiro disponível',
              value: Formatters.money(snapshot.liquidBalance),
            ),
            if (snapshot.protectedBalance > 0)
              _ExplanationRow(
                label: 'dinheiro protegido',
                value: Formatters.money(snapshot.protectedBalance),
              ),
            _ExplanationRow(
              label: 'compromissos até receber',
              value: Formatters.money(snapshot.mandatoryOutflowsUntilIncome),
            ),
            if (snapshot.budgetConfigured) ...[
              _ExplanationRow(
                label: 'orçamento para gastos flexíveis',
                value: Formatters.money(snapshot.monthlyBudgetPlanned),
              ),
              _ExplanationRow(
                label: 'gastos flexíveis no mês',
                value: Formatters.money(snapshot.monthlyBudgetUsed),
              ),
              _ExplanationRow(
                label: 'ainda disponível para gastos flexíveis',
                value: Formatters.money(snapshot.economicHeadroom),
              ),
              if (exceeded > 0)
                _ExplanationRow(
                  label: 'orçamento flexível excedido',
                  value: Formatters.money(exceeded),
                  emphasized: true,
                ),
            ],
            _ExplanationRow(
              label: 'o que limita seu Fôlego agora',
              value: _limitingFactorLabel(snapshot.limitingFactor),
            ),
            if (timing != null)
              _ExplanationRow(
                label: 'próximo recebimento',
                value: snapshot.nextIncomeAmount > 0
                    ? '$timing · ${Formatters.money(snapshot.nextIncomeAmount)}'
                    : timing,
              ),
            const Divider(height: 28),
            _ExplanationRow(
              label: 'te sobra pra gastar',
              value: Formatters.money(snapshot.spendablePool),
              emphasized: true,
            ),
            if (snapshot.dailyFolego != null && snapshot.dailyFolego! > 0)
              _ExplanationRow(
                label: 'fôlego por dia',
                value: Formatters.money(snapshot.dailyFolego!),
                emphasized: true,
              ),
            if (snapshot.budgetConfigured && onOpenBudget != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('home-explainer-open-flex-budget'),
                onPressed: () {
                  Navigator.of(context).pop();
                  onOpenBudget!();
                },
                icon: const Icon(AppIcons.plan, size: 18),
                label: Text(exceeded > 0
                    ? 'ver onde passei do limite'
                    : 'abrir orçamento flexível'),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              'Reservas, investimentos protegidos e benefícios ficam separados do valor para gastar.',
              style: AppTypography.label(
                context,
                fontSize: 11,
                color: secondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExplanationRow extends StatelessWidget {
  const _ExplanationRow({
    required this.label,
    required this.value,
    this.emphasized = false,
  });

  final String label;
  final String value;
  final bool emphasized;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 7),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                label,
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  fontWeight: emphasized ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Flexible(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: emphasized
                    ? AppTypography.money(context, fontSize: 13)
                    : AppTypography.body(
                        context,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
              ),
            ),
          ],
        ),
      );
}

String _limitingFactorLabel(String factor) => switch (factor.trim().toLowerCase()) {
      'budget' || 'economic' => 'orçamento para gastos flexíveis',
      'cash' => 'dinheiro disponível',
      'both' || 'cash_and_budget' =>
        'dinheiro disponível e orçamento para gastos flexíveis',
      _ => 'seu resumo financeiro',
    };

String _shortDate(DateTime date) {
  const months = <String>[
    'jan',
    'fev',
    'mar',
    'abr',
    'mai',
    'jun',
    'jul',
    'ago',
    'set',
    'out',
    'nov',
    'dez',
  ];
  return '${date.day} ${months[date.month - 1]}';
}
