import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/intelligence/financial_insights_service.dart';
import '../core/intelligence/weekly_report_builder.dart';
import '../core/intelligence/budget_pace.dart';
import '../core/intelligence/financial_radar.dart';
import '../core/intelligence/cash_runway_preparation.dart';
import 'runway_what_if_card.dart';
import '../data/models/budget_overview_item.dart';

class WeeklyInsightsCard extends StatefulWidget {
  const WeeklyInsightsCard({super.key, required this.service, required this.spaceId});
  final FinancialInsightsService service;
  final String spaceId;
  @override
  State<WeeklyInsightsCard> createState() => _WeeklyInsightsCardState();
}

class _WeeklyInsightsCardState extends State<WeeklyInsightsCard> {
  late Future<CurrentProgressReport> _report;
  late Future<FlexibleBudgetOverview> _budget;
  late Future<FinancialRadar> _radar;
  late Future<CashRunwayPreparation> _runway;
  late Future<List<RepeatedExpense>> _repeated;
  @override
  void initState() { super.initState(); _load(); }
  @override
  void didUpdateWidget(covariant WeeklyInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        !identical(oldWidget.service.repository, widget.service.repository)) _load();
  }
  void _load() {
    final now = DateTime.now();
    _report = widget.service.currentProgress(spaceId: widget.spaceId, asOf: now);
    _budget = widget.service.flexibleBudget(spaceId: widget.spaceId, asOf: now);
    _radar = widget.service.radar(spaceId: widget.spaceId);
    _runway = widget.service.cashRunway(spaceId: widget.spaceId, asOf: now);
    _repeated = widget.service.repeatedPurchases(spaceId: widget.spaceId, asOf: now);
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<CurrentProgressReport>(
    future: _report,
    builder: (context, snapshot) {
      final en = Localizations.localeOf(context).languageCode == 'en';
      if (!snapshot.hasData) {
        return Card(child: ListTile(
          title: Text(snapshot.hasError
              ? (en ? 'Insights unavailable' : 'Insights indisponíveis')
              : (en ? 'Preparing your insights…' : 'Preparando seus insights…')),
          trailing: snapshot.hasError
              ? IconButton(
                  tooltip: en ? 'Retry' : 'Tentar novamente',
                  icon: const Icon(Icons.refresh),
                  onPressed: () => setState(_load),
                )
              : const SizedBox(width: 24, height: 24, child: CircularProgressIndicator()),
        ));
      }
      final report = snapshot.data!;
      final money = NumberFormat.currency(
        locale: en ? 'en_US' : 'pt_BR', symbol: en ? r'$' : r'R$',
      );
      final percent = NumberFormat.decimalPatternDigits(
        locale: en ? 'en_US' : 'pt_BR', decimalDigits: 1,
      );
      final change = report.weekExpenses - report.previousWeekExpenses;
      final increasing = change > 0;
      final category = report.categoryChanges.where((item) => item.difference > 0);
      final mainCategory = category.isEmpty ? null : category.first;
      final tips = <String>[];
      if (mainCategory != null) {
        tips.add(en
            ? '${mainCategory.name} accounts for ${money.format(mainCategory.difference)} of the increase. Review recent purchases in this category.'
            : '${mainCategory.name} representa ${money.format(mainCategory.difference)} do aumento. Confira as compras recentes nessa categoria.');
      }
      if (report.previousWeekExpenses > 0 && increasing) {
        tips.add(en
            ? 'Spending rose ${percent.format(change / report.previousWeekExpenses * 100)}% compared with the same days last week.'
            : 'Seus gastos subiram ${percent.format(change / report.previousWeekExpenses * 100)}% em relação aos mesmos dias da semana passada.');
      } else if (report.previousWeekExpenses > 0 && change < 0) {
        tips.add(en
            ? 'You spent ${money.format(-change)} less than at this point last week.'
            : 'Você gastou ${money.format(-change)} a menos que neste ponto da semana passada.');
      } else if (report.previousWeekExpenses == 0) {
        tips.add(en
            ? 'There are no expenses in the comparable period last week. Keep logging transactions for better insights.'
            : 'Não há despesas no período equivalente da semana passada. Continue registrando lançamentos para melhorar os insights.');
      }
      return Card(
        clipBehavior: Clip.antiAlias,
        child: ExpansionTile(
          key: ValueKey('weekly-insights-${widget.spaceId}'),
          initiallyExpanded: false,
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Text(en ? 'Your money this week' : 'Seu dinheiro nesta semana',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 16, runSpacing: 8, children: [
              _Metric(label: en ? 'Income' : 'Receitas', value: money.format(report.weekIncome)),
              _Metric(label: en ? 'Spending' : 'Despesas', value: money.format(report.weekExpenses)),
            ]),
          ),
          children: [
          Row(
            children: [
              Expanded(
                child: Text(en ? 'Monday through today · same weekdays last week'
                    : 'De segunda até hoje · mesmos dias da semana passada',
                    style: Theme.of(context).textTheme.bodySmall),
              ),
              IconButton(
                tooltip: en ? 'Refresh insights' : 'Atualizar insights',
                icon: const Icon(Icons.refresh, size: 20),
                onPressed: () => setState(_load),
              ),
            ],
          ),
          if (report.weekIncome == 0 && report.weekExpenses == 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(en
                  ? 'No income or spending recorded so far this week.'
                  : 'Nenhuma receita ou despesa registrada nesta semana até agora.',
                  style: Theme.of(context).textTheme.bodySmall),
            ),
          const SizedBox(height: 12),
          Text(en ? 'Last week (same days): ${money.format(report.previousWeekExpenses)}'
              : 'Semana passada (mesmos dias): ${money.format(report.previousWeekExpenses)}'),
          const Divider(height: 26),
          Text(en ? 'This month so far' : 'Seu mês até agora',
              style: Theme.of(context).textTheme.titleSmall),
          Text(money.format(report.monthExpenses),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          Text(report.previousMonthComparable
              ? (en
                  ? 'Previous month, same period: ${money.format(report.previousMonthExpenses)}'
                  : 'Mês anterior, mesmo período: ${money.format(report.previousMonthExpenses)}')
              : (en
                  ? 'The previous month has fewer days; no equivalent comparison is available.'
                  : 'O mês anterior tem menos dias; não há comparação equivalente.'),
              style: Theme.of(context).textTheme.bodySmall),
          const Divider(height: 26),
          Text(en ? 'Insights and next steps' : 'Insights e próximos passos',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          for (final tip in tips.take(2))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.lightbulb_outline, size: 19),
                const SizedBox(width: 8),
                Expanded(child: Text(tip)),
              ]),
            ),
          FutureBuilder<List<RepeatedExpense>>(
            future: _repeated,
            builder: (context, repeatedSnapshot) {
              if (!repeatedSnapshot.hasData ||
                  repeatedSnapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              final repeated = repeatedSnapshot.data!.take(2);
              return Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(en ? 'Repeated purchases to review' : 'Compras repetidas para revisar',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    for (final item in repeated)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        minLeadingWidth: 26,
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.repeat, size: 20),
                        title: Text(item.description,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                        subtitle: Text(en
                            ? '${item.occurrences} purchases this month · ${money.format(item.total)}'
                            : '${item.occurrences} compras neste mês · ${money.format(item.total)}'),
                      ),
                    Text(en
                        ? 'These may be intentional. Repeated purchases are not necessarily subscriptions.'
                        : 'Essas compras podem ser intencionais. Repetição não significa assinatura.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          ),
          FutureBuilder<FlexibleBudgetOverview>(
            future: _budget,
            builder: (context, budgetSnapshot) {
              if (!budgetSnapshot.hasData) {
                if (budgetSnapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(en
                        ? 'Budget guidance is temporarily unavailable.'
                        : 'As orientações do orçamento estão indisponíveis no momento.',
                        style: Theme.of(context).textTheme.bodySmall),
                  );
                }
                return const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                );
              }
              final budget = budgetSnapshot.data!;
              if (!budget.configured || budget.limitAmount <= 0) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(en
                      ? 'Set a flexible spending limit to see how much you can still spend.'
                      : 'Defina seu teto de gastos flexíveis para saber quanto ainda pode gastar.'),
                );
              }
              final pace = BudgetPace.forDate(
                used: budget.usedAmount,
                limit: budget.limitAmount,
                asOf: DateTime.now(),
              );
              final daysLeft = DateTime(
                DateTime.now().year, DateTime.now().month + 1, 0,
              ).day - DateTime.now().day + 1;
              final daily = budget.remainingAmount > 0
                  ? budget.remainingAmount / daysLeft : 0.0;
              return Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(en ? 'Your flexible budget' : 'Seu orçamento flexível',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 6),
                    LinearProgressIndicator(
                      value: budget.usageRatio.clamp(0.0, 1.0),
                      minHeight: 7,
                    ),
                    const SizedBox(height: 8),
                    Text(en
                        ? '${money.format(budget.usedAmount)} used of ${money.format(budget.limitAmount)}'
                        : '${money.format(budget.usedAmount)} utilizados de ${money.format(budget.limitAmount)}'),
                    const SizedBox(height: 4),
                    Text(budget.isExceeded
                        ? (en
                            ? 'You exceeded your flexible limit by ${money.format(budget.exceededAmount)}. Consider pausing optional purchases.'
                            : 'Você ultrapassou seu teto flexível em ${money.format(budget.exceededAmount)}. Considere adiar compras opcionais.')
                        : (en
                            ? '${money.format(budget.remainingAmount)} left · about ${money.format(daily)} per remaining day, including today.'
                            : 'Restam ${money.format(budget.remainingAmount)} · cerca de ${money.format(daily)} por dia restante, incluindo hoje.')),
                    const SizedBox(height: 4),
                    if (pace.canEstimate) ...[
                      const SizedBox(height: 10),
                      Text(en ? 'At your current pace' : 'No seu ritmo atual',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                      Text(en
                          ? 'Estimated month-end flexible spending: ${money.format(pace.projectedMonthSpending)}'
                          : 'Estimativa de gastos flexíveis até o fim do mês: ${money.format(pace.projectedMonthSpending)}'),
                      Text(pace.projectedOverLimit
                          ? (en
                              ? 'That is ${money.format(pace.projectedDifference)} above your limit. Review optional spending to adjust course.'
                              : 'Isso representa ${money.format(pace.projectedDifference)} acima do limite. Reveja gastos opcionais para ajustar o ritmo.')
                          : (en
                              ? 'At this pace, spending stays within the configured flexible limit.'
                              : 'Nesse ritmo, os gastos ficam dentro do limite flexível configurado.')),
                      Text(en
                          ? 'Method: spending so far ÷ elapsed calendar days × days in month. This is a simple estimate, not a prediction.'
                          : 'Cálculo: gastos até agora ÷ dias corridos × dias do mês. É uma estimativa simples, não uma previsão.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ] else if (DateTime.now().day < 7) ...[
                      const SizedBox(height: 8),
                      Text(en
                          ? 'Spending pace will appear after the first seven days of the month.'
                          : 'O ritmo de gastos aparecerá após os primeiros sete dias do mês.',
                          style: Theme.of(context).textTheme.bodySmall),
                    ],
                    Text(en
                        ? 'This guidance covers flexible spending only, not your total available bank balance.'
                        : 'Este cálculo considera apenas gastos flexíveis, não o saldo disponível nas suas contas.',
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              );
            },
          ),
          FutureBuilder<CashRunwayPreparation>(
            future: _runway,
            builder: (context, runwaySnapshot) {
              if (!runwaySnapshot.hasData) {
                if (runwaySnapshot.hasError) {
                  return Text(en
                      ? 'Cash runway is unavailable. Check your accounts and agenda.'
                      : 'Disponibilidade indisponível. Confira suas contas e agenda.');
                }
                return const LinearProgressIndicator();
              }
              final preparation = runwaySnapshot.data!;
              final runway = preparation.runway;
              final nextIncome = preparation.nextIncomeDate;
              if (runway == null || nextIncome == null) {
                return Text(en
                    ? 'Add your next dated income to unlock your cash runway.'
                    : 'Cadastre a data do próximo recebimento para calcular seu dinheiro disponível.');
              }
              final date = DateFormat.yMd(en ? 'en_US' : 'pt_BR');
              return ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(en ? 'Money until your next income' : 'Dinheiro até o próximo recebimento'),
                subtitle: Text(en
                    ? 'Next income: ${date.format(nextIncome)}'
                    : 'Próxima entrada: ${date.format(nextIncome)}'),
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(preparation.guidanceNeedsReview
                        ? (en ? 'Provisional balance before income' : 'Saldo provisório antes do recebimento')
                        : (en ? 'Estimated balance before income' : 'Saldo estimado antes do recebimento')),
                    trailing: Text(money.format(runway.balanceAtPayday)),
                  ),
                  if (runway.days.isNotEmpty && !preparation.guidanceNeedsReview)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(en ? 'Daily spending reference'
                          : 'Referência diária de gastos'),
                      trailing: Text(money.format(runway.discretionaryDailyReference)),
                    ),
                  if (preparation.guidanceNeedsReview)
                    Text(en
                        ? 'Daily spending guidance is paused until overdue items or incomplete agenda data are reviewed.'
                        : 'A orientação diária está suspensa até revisar contas vencidas ou dados incompletos da agenda.'),
                  if (preparation.agendaMayBeTruncated)
                    Text(en
                        ? 'Your agenda reached the 200-event limit. This estimate may omit scheduled items.'
                        : 'Sua agenda atingiu o limite de 200 eventos. Esta estimativa pode não incluir todos os compromissos.'),
                  if (runway.days.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(en ? 'Daily balance calendar' : 'Calendário de saldos',
                        style: Theme.of(context).textTheme.titleSmall),
                    for (final day in runway.days.take(14))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(date.format(day.date)),
                        subtitle: Text(en
                            ? '${day.events.length} scheduled events'
                            : '${day.events.length} eventos previstos'),
                        trailing: Text(
                          money.format(day.closingBalance),
                          style: TextStyle(
                            color: day.closingBalance < 0
                                ? Theme.of(context).colorScheme.error
                                : null,
                            fontWeight: day.closingBalance < 0
                                ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    if (runway.days.length > 14)
                      Text(en
                          ? 'Showing the first 14 days; totals include the full period.'
                          : 'Exibindo os primeiros 14 dias; os totais incluem todo o período.'),
                  ],
                  RunwayWhatIfCard(preparation: preparation),
                  if (runway.firstNegativeDay != null)
                    Text(en
                        ? 'Possible shortfall from ${date.format(runway.firstNegativeDay!)}.'
                        : 'Possível falta de saldo a partir de ${date.format(runway.firstNegativeDay!)}.'),
                  if (preparation.excludedOverdueCount > 0)
                    Text(en
                        ? '${preparation.excludedOverdueCount} overdue obligations excluded; review before relying on this estimate.'
                        : '${preparation.excludedOverdueCount} contas vencidas não incluídas; revise antes de usar esta estimativa.'),
                  Text(en
                      ? 'Based on available cash accounts and dated unpaid agenda events. Does not include benefits, unregistered expenses or an unconfigured protected reserve. Verify your balances.'
                      : 'Considera contas disponíveis e eventos pendentes com data na agenda. Não inclui benefícios, gastos não cadastrados nem reserva protegida não configurada. Confira seus saldos.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
          ),
          FutureBuilder<FinancialRadar>(
            future: _radar,
            builder: (context, radarSnapshot) {
              if (!radarSnapshot.hasData) {
                if (radarSnapshot.hasError) {
                  return Text(en
                      ? 'Future balance is temporarily unavailable.'
                      : 'O saldo futuro está indisponível no momento.');
                }
                return const LinearProgressIndicator();
              }
              final radar = radarSnapshot.data!;
              if (!radar.hasReliableInputs) {
                return Text(en
                    ? 'Complete your financial projection to see upcoming monthly risks.'
                    : 'Complete sua projeção financeira para visualizar os riscos dos próximos meses.');
              }
              final monthFormat = DateFormat.yMMMM(en ? 'en_US' : 'pt_BR');
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 26),
                  Text(en ? 'Upcoming months radar' : 'Radar dos próximos meses',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  for (final month in radar.months.take(3))
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(monthFormat.format(month.month),
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w600)),
                              Text(en ? 'Projected month-end balance' : 'Saldo ao fim do mês',
                                style: Theme.of(context).textTheme.bodySmall),
                            ],
                          )),
                          const SizedBox(width: 8),
                          Text(money.format(month.closingProjected),
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                    ),
                  if (radar.firstNegativeMonth != null)
                    Text(en
                        ? 'Attention: the projection shows a negative balance in ${monthFormat.format(radar.firstNegativeMonth!)}.'
                        : 'Atenção: a projeção indica saldo negativo em ${monthFormat.format(radar.firstNegativeMonth!)}.'),
                  Text(en
                      ? 'Monthly projection only. It does not identify the exact day of a shortfall.'
                      : 'Projeção mensal: não identifica o dia exato de uma possível falta de dinheiro.',
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(en
              ? 'Based on recorded transactions, not a prediction or financial advice.'
              : 'Com base nos lançamentos registrados; não é previsão nem aconselhamento financeiro.',
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ));
    },
  );
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label, style: Theme.of(context).textTheme.bodySmall),
      Text(value, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
    ],
  );
}
