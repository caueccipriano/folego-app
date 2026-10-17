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
  });

  final String eyebrow;
  final String title;
  final String description;
  final HomePulseAction action;
  final String? actionLabel;
  final num? amount;
  final bool requiresAttention;
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
      title: 'Um compromisso passou do vencimento',
      description:
          '${nearest.name} está marcado como pendente. Confira se já foi pago.',
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
      title: 'Você tem uma conta prevista para $when',
      description: '${nearest.name} · confira o valor e a situação na agenda.',
      action: HomePulseAction.upcoming,
      actionLabel: 'ver compromisso',
      amount: nearest.amount,
      requiresAttention: true,
    );
  }

  if (snapshot.needsIncomeSetup) {
    return const HomePulseInsight(
      eyebrow: 'para planejar melhor',
      title: 'Seu próximo recebimento ainda não está definido',
      description:
          'Com a previsão de entrada atualizada, o Fôlego consegue calcular '
          'melhor seus próximos dias.',
      action: HomePulseAction.none,
    );
  }

  // Never describe a zero spendable pool as a negative bank balance or a debt.
  if (snapshot.spendablePool <= 0) {
    return const HomePulseInsight(
      eyebrow: 'vale olhar seu plano',
      title: 'Não há folga prevista para novos gastos',
      description:
          'Confira seu orçamento e compromissos antes de assumir novas despesas. '
          'Isso não significa que sua conta bancária esteja negativa.',
      action: HomePulseAction.budget,
      actionLabel: 'rever planejamento',
      requiresAttention: true,
    );
  }

  if (nearest != null && daysUntil(nearest.dueDate) <= 7) {
    return HomePulseInsight(
      eyebrow: 'nos próximos dias',
      title: 'Um compromisso está chegando',
      description: '${nearest.name} · previsto para ${daysUntil(nearest.dueDate)} '
          'dias. Veja os detalhes antes de pagar.',
      action: HomePulseAction.upcoming,
      actionLabel: 'ver agenda',
      amount: nearest.amount,
    );
  }

  if (snapshot.budgetConfigured &&
      snapshot.monthlyBudgetPlanned > 0 &&
      snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned >= .9) {
    return const HomePulseInsight(
      eyebrow: 'olho no orçamento',
      title: 'Seu orçamento flexível está perto do limite',
      description:
          'Vale conferir as categorias antes de planejar outra compra.',
      action: HomePulseAction.budget,
      actionLabel: 'ver meu orçamento',
      requiresAttention: true,
    );
  }

  if (!upcomingAvailable) {
    return const HomePulseInsight(
      eyebrow: 'resumo parcial',
      title: 'Ainda não consegui consultar as próximas contas',
      description:
          'Seu saldo está disponível acima. Atualize a página para '
          'conferir os compromissos mais recentes.',
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
          ? 'Seu recebimento está previsto para hoje'
          : 'Seu próximo recebimento está chegando',
      description: days == 0
          ? 'Confira o lançamento antes de contar com o valor.'
          : 'Faltam $days dias pela previsão atual. Confira quando entrar.',
      action: HomePulseAction.none,
    );
  }

  return const HomePulseInsight(
    eyebrow: 'tudo acompanhado',
    title: 'Nada urgente identificado agora',
    description:
        'O resumo não mostra compromissos próximos marcados como pendentes. '
        'O Fôlego continua acompanhando as próximas datas.',
    action: HomePulseAction.upcoming,
    actionLabel: 'consultar agenda',
  );
}
