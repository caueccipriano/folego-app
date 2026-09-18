class MonthlyCardCompetence {
  const MonthlyCardCompetence({
    required this.name,
    required this.amount,
    this.cardId,
  });

  final String? cardId;
  final String name;
  final double amount;

  factory MonthlyCardCompetence.fromJson(Map<String, dynamic> json) {
    return MonthlyCardCompetence(
      cardId: json['card_id'] as String?,
      name: (json['name'] as String?)?.trim().isNotEmpty == true
          ? (json['name'] as String).trim()
          : 'Cartão',
      amount: (json['amount'] as num? ?? 0).toDouble(),
    );
  }
}

class MonthlyMoneySummary {
  const MonthlyMoneySummary({
    required this.periodMonth,
    required this.incomeAmount,
    required this.spendingAccount,
    required this.spendingCards,
    required this.spendingBenefits,
    required this.refundsAmount,
    required this.spendingNet,
    required this.incomeMinusSpending,
    required this.competenceCardsTotal,
    required this.competenceDirect,
    required this.competenceBenefits,
    required this.competenceRefunds,
    required this.competenceNet,
    required this.competenceCards,
    required this.cashInflow,
    required this.cashOutflow,
    required this.cashNet,
    required this.movementCardPayments,
    required this.movementTransfers,
    required this.movementReserveInvestment,
    required this.movementReconciliation,
  });

  final DateTime periodMonth;

  /// Real economic income for the selected competence month.
  final double incomeAmount;

  /// Purchases/spending made during the selected month, by occurrence date.
  final double spendingAccount;
  final double spendingCards;
  final double spendingBenefits;
  final double refundsAmount;
  final double spendingNet;
  final double incomeMinusSpending;

  /// Economic competence, sourced exclusively from financial_impacts.
  final double competenceCardsTotal;
  final double competenceDirect;
  final double competenceBenefits;
  final double competenceRefunds;
  final double competenceNet;
  final List<MonthlyCardCompetence> competenceCards;

  /// Cash movement is intentionally separate from income/spending semantics.
  final double cashInflow;
  final double cashOutflow;
  final double cashNet;
  final double movementCardPayments;
  final double movementTransfers;
  final double movementReserveInvestment;
  final double movementReconciliation;

  // Official money semantics used across Home, composition and Projection.
  double get realIncome => incomeAmount;
  double get spendingMade => spendingNet;
  double get accountSpending => spendingAccount;
  double get cardPurchasesMade => spendingCards;
  double get benefitSpending => spendingBenefits;
  double get refunds => refundsAmount;
  double get competenceExpenses => competenceNet;
  double get economicResult => realIncome - competenceExpenses;
  double get cardCompetence => competenceCardsTotal;
  double get cardPayments => movementCardPayments;
  double get transfersAndInvestments =>
      movementTransfers + movementReserveInvestment;
  double get reconciliationAdjustments => movementReconciliation;
  double get nonExpenseCashOutflows =>
      cardPayments + transfersAndInvestments + reconciliationAdjustments;

  factory MonthlyMoneySummary.fromJson(Map<String, dynamic> json) {
    final cardsRaw = json['competence_cards'];
    final cards = cardsRaw is List
        ? cardsRaw
              .whereType<Map>()
              .map(
                (item) => MonthlyCardCompetence.fromJson(
                  Map<String, dynamic>.from(item),
                ),
              )
              .toList(growable: false)
        : const <MonthlyCardCompetence>[];

    double number(String key) => (json[key] as num? ?? 0).toDouble();

    return MonthlyMoneySummary(
      periodMonth: DateTime.parse(json['period_month'] as String),
      incomeAmount: number('income_amount'),
      spendingAccount: number('spending_account'),
      spendingCards: number('spending_cards'),
      spendingBenefits: number('spending_benefits'),
      refundsAmount: number('refunds_amount'),
      spendingNet: number('spending_net'),
      incomeMinusSpending: number('income_minus_spending'),
      competenceCardsTotal: number('competence_cards_total'),
      competenceDirect: number('competence_direct'),
      competenceBenefits: number('competence_benefits'),
      competenceRefunds: number('competence_refunds'),
      competenceNet: number('competence_net'),
      competenceCards: cards,
      cashInflow: number('cash_inflow'),
      cashOutflow: number('cash_outflow'),
      cashNet: number('cash_net'),
      movementCardPayments: number('movement_card_payments'),
      movementTransfers: number('movement_transfers'),
      movementReserveInvestment: number('movement_reserve_investment'),
      movementReconciliation: number('movement_reconciliation'),
    );
  }
}
