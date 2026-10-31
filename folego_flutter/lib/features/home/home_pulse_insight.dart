import '../../data/models/folego_snapshot.dart';
import '../../data/models/upcoming_events.dart';

enum HomePulseAction { upcoming, budget, none }

/// One contextual, evidence-based item for the Home. Never writes financial
/// data, infers payments or generates content unrelated to server values.
class HomePulseInsight {
  const HomePulseInsight({
    required this.eyebrow,
    required this.title,
    required this.description,
    required this.action,
    this.actionLabel,
    this.amount,
    this.requiresAttention = false,
    this.showCard = true,
    this.budgetPercentUsed,
  });

  final String eyebrow;
  final String title;
  final String description;
  final HomePulseAction action;
  final String? actionLabel;
  final num? amount;
  final bool requiresAttention;
  final bool showCard;
  /// Percentage from the server's current monthly budget totals; never a balance.
  final int? budgetPercentUsed;
}

/// The compact Home exposes one next step, without leaking budget usage when
/// financial values are hidden. No extra query or daily check-in is required.
String homePulseShortDetail(HomePulseInsight insight, {required bool hidden}) {
  if (insight.budgetPercentUsed != null) {
    return hidden
        ? 'revisar categorias'
        : '${insight.budgetPercentUsed}% usado · revisar categorias';
  }
  return insight.action == HomePulseAction.none
      ? insight.description
      : (insight.actionLabel ?? insight.description);
}

HomePulseInsight selectHomePulse({
  required FolegoSnapshot snapshot,
  required List<UpcomingEvent> upcoming,
  required bool upcomingAvailable,
}) {
  final asOf = DateTime(
    snapshot.asOfDate.year,
    snapshot.asOfDate.month,
    snapshot.asOfDate.day,
  );
  int daysUntil(DateTime date) =>
      DateTime(date.year, date.month, date.day).difference(asOf).inDays;

  final pendingExpenses = upcoming
      .where((item) => item.isPending && item.isExpense)
      .toList(growable: false)
    ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
  final nearest = pendingExpenses.isEmpty ? null : pendingExpenses.first;

  // Past due statuses may be stale. Ask to confirm, never assert nonpayment.
  if (nearest != null && daysUntil(nearest.dueDate) < 0) {
    return HomePulseInsight(
      eyebrow: 'merece uma conferência',
      title: 'Um vencimento passou',
      description:
          '${nearest.name} segue pendente no Fôlego. Confira se já foi pago.',
      action: HomePulseAction.upcoming,
      actionLabel: 'ver compromisso',
      amount: nearest.amount,
      requiresAttention: true,
    );
  }

  if (nearest != null && daysUntil(nearest.dueDate) <= 3) {
    final days = daysUntil(nearest.dueDate);
    final when = days == 0
        ? 'hoje'
        : days == 1
            ? 'amanhã'
            : 'em $days dias';
    return HomePulseInsight(
      eyebrow: 'seu próximo compromisso',
      title: 'Conta prevista para $when',
      description: '${nearest.name} · confira na agenda.',
      action: HomePulseAction.upcoming,
      actionLabel: 'ver compromisso',
      amount: nearest.amount,
      requiresAttention: true,
    );
  }

  if (snapshot.needsIncomeSetup) {
    return const HomePulseInsight(
      eyebrow: 'para planejar melhor',
      title: 'Próximo recebimento não informado',
      description:
          'Cadastre a previsão para calcular seus próximos dias.',
      action: HomePulseAction.none,
    );
  }

  // Never describe a zero spendable pool as a negative bank balance or a debt.
  if (snapshot.spendablePool <= 0) {
    return const HomePulseInsight(
      eyebrow: 'vale olhar seu plano',
      title: 'Não há folga para novos gastos',
      description:
          'Confira orçamento e contas. Isso não significa que sua conta bancária esteja negativa.',
      action: HomePulseAction.budget,
      actionLabel: 'rever planejamento',
      requiresAttention: true,
    );
  }

  if (nearest != null && daysUntil(nearest.dueDate) <= 7) {
    return HomePulseInsight(
      eyebrow: 'nos próximos dias',
      title: 'Próxima conta em ${daysUntil(nearest.dueDate)} dias',
      description: '${nearest.name} · valor e data na agenda.',
      action: HomePulseAction.upcoming,
      actionLabel: 'ver agenda',
      amount: nearest.amount,
    );
  }

  if (snapshot.budgetConfigured &&
      snapshot.monthlyBudgetPlanned > 0 &&
      snapshot.monthlyBudgetUsed.isFinite &&
      snapshot.monthlyBudgetUsed >= 0 &&
      snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned >= .9) {
    return HomePulseInsight(
      eyebrow: 'olho no orçamento',
      title: snapshot.monthlyBudgetUsed > snapshot.monthlyBudgetPlanned
          ? 'Orçamento passou do planejado'
          : 'Orçamento perto do limite',
      description: 'Confira as categorias antes de comprar.',
      action: HomePulseAction.budget,
      actionLabel: 'revisar categorias',
      budgetPercentUsed: (snapshot.monthlyBudgetUsed /
              snapshot.monthlyBudgetPlanned *
              100)
          .round(),
      requiresAttention: true,
    );
  }

  if (!upcomingAvailable) {
    return const HomePulseInsight(
      eyebrow: 'resumo parcial',
      title: 'Ainda não consegui consultar as próximas contas',
      description:
          'Atualize para conferir os próximos compromissos.',
      action: HomePulseAction.none,
    );
  }

  if (snapshot.nextIncomeDate != null &&
      snapshot.daysUntilIncome != null &&
      snapshot.daysUntilIncome! >= 0 &&
      snapshot.daysUntilIncome! <= 7) {
    final days = snapshot.daysUntilIncome!;
    return HomePulseInsight(
      eyebrow: 'olhando à frente',
      title: days == 0
          ? 'Recebimento previsto para hoje'
          : 'Recebimento previsto em $days dias',
      description: days == 0
          ? 'Confira o lançamento antes de contar com o valor.'
          : 'Confira quando entrar. A data é uma previsão.',
      action: HomePulseAction.none,
    );
  }

  return const HomePulseInsight(
    eyebrow: 'tudo acompanhado',
    title: 'Nada urgente identificado agora',
    description:
        'Sem contas próximas pendentes nos registros atuais.',
    action: HomePulseAction.upcoming,
    actionLabel: 'consultar agenda',
    showCard: false,
  );
}
