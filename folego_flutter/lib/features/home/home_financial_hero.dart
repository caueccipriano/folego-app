import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/folego_snapshot.dart';

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

class HomeFinancialHero extends StatelessWidget {
  const HomeFinancialHero({super.key, required this.snapshot});

  final FolegoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primaryPurple = AppColors.primaryPurple(brightness);
    final onPurple = brightness == Brightness.dark
        ? AppColors.iconOnPurpleDark
        : AppColors.iconOnPurpleLight;
    final timing = homeIncomeTimingLabel(snapshot);
    final spendable = snapshot.spendablePool;
    final daily = snapshot.dailyFolego;
    final showDaily = spendable > 0 && daily != null && daily! > 0;

    final contextCopy = spendable <= 0
        ? snapshot.nextIncomeDate == null && snapshot.daysUntilIncome == null
            ? 'seus compromissos já ocupam o dinheiro disponível'
            : 'seus compromissos já ocupam o dinheiro disponível até o próximo recebimento'
        : showDaily
            ? '${Formatters.money(daily!)} por dia até o próximo recebimento'
            : snapshot.nextIncomeDate == null && snapshot.daysUntilIncome == null
                ? 'adicione um próximo recebimento no Plano para visualizar o prazo'
                : 'valor disponível até o próximo recebimento';

    return Semantics(
      container: true,
      label:
          'valor disponível para gastar até o próximo recebimento: ${Formatters.money(spendable)}',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(22, 24, 22, 22),
        decoration: BoxDecoration(
          color: primaryPurple,
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'te sobra pra gastar',
              style: AppTypography.body(
                context,
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: onPurple.withValues(alpha: .84),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                Formatters.money(spendable),
                key: const ValueKey('home-spendable-pool'),
                style: AppTypography.money(
                  context,
                  fontSize: 52,
                  color: AppColors.lime,
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              contextCopy,
              key: const ValueKey('home-daily-folego-context'),
              style: AppTypography.body(
                context,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: onPurple.withValues(alpha: .94),
              ),
            ),
            if (timing != null) ...[
              const SizedBox(height: 14),
              _TimingPill(label: timing, foreground: onPurple),
            ],
            const SizedBox(height: 16),
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
                    'benefícios ficam separados',
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
                  label: const Text('como chegamos nisso?'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showExplanation(BuildContext context) async {
    final content = _FolegoExplanation(snapshot: snapshot);
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
          borderRadius: BorderRadius.circular(14),
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
  const _FolegoExplanation({required this.snapshot});

  final FolegoSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final secondary = AppColors.secondaryText(brightness);
    final timing = homeIncomeTimingLabel(snapshot);

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
            _ExplanationRow(
              label: 'compromissos até receber',
              value: Formatters.money(snapshot.mandatoryOutflowsUntilIncome),
            ),
            if (snapshot.budgetConfigured) ...[
              _ExplanationRow(
                label: 'limite de orçamento do mês',
                value: Formatters.money(snapshot.monthlyBudgetPlanned),
              ),
              _ExplanationRow(
                label: 'já usado no orçamento',
                value: Formatters.money(snapshot.monthlyBudgetUsed),
              ),
              _ExplanationRow(
                label: 'espaço disponível no orçamento',
                value: Formatters.money(snapshot.economicHeadroom),
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
            const SizedBox(height: 12),
            Text(
              'Benefícios ficam separados deste valor.',
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
      'budget' || 'economic' => 'orçamento',
      'cash' => 'dinheiro disponível',
      'both' || 'cash_and_budget' => 'dinheiro disponível e orçamento',
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
