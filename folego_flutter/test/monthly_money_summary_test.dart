import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/monthly_money_summary.dart';

void main() {
  test('parses canonical monthly money semantics without mixing concepts', () {
    final summary = MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': 3734.22,
      'spending_account': 2165.96,
      'spending_cards': 3039.59,
      'spending_benefits': 365.30,
      'refunds_amount': 32.00,
      'spending_net': 5538.85,
      'income_minus_spending': -1804.63,
      'competence_cards_total': 3147.72,
      'competence_direct': 2165.96,
      'competence_benefits': 365.30,
      'competence_refunds': 32.00,
      'competence_net': 5646.98,
      'competence_cards': [
        {'card_id': 'amex', 'name': 'AMEX Gold', 'amount': 2711.58},
        {'card_id': 'porto', 'name': 'Porto', 'amount': 436.14},
      ],
      'cash_inflow': 5355.22,
      'cash_outflow': 7637.16,
      'cash_net': -2281.94,
      'movement_card_payments': 3225.24,
      'movement_transfers': 939.00,
      'movement_reserve_investment': 500.00,
      'movement_reconciliation': 956.96,
    });

    expect(summary.spendingNet, 5538.85);
    expect(summary.spendingCards, 3039.59);
    expect(summary.competenceCardsTotal, 3147.72);
    expect(summary.spendingCards, isNot(summary.competenceCardsTotal));
    expect(summary.refundsAmount, 32);
    expect(summary.incomeAmount, 3734.22);
    expect(summary.cashOutflow, 7637.16);
    expect(summary.movementCardPayments, 3225.24);
    expect(summary.competenceCards.map((card) => card.name), [
      'AMEX Gold',
      'Porto',
    ]);
  });

  test('keeps full purchase and installment competence as different values', () {
    final september = MonthlyMoneySummary.fromJson({
      'period_month': '2026-09-01',
      'income_amount': 0,
      'spending_account': 0,
      'spending_cards': 897.84,
      'spending_benefits': 0,
      'refunds_amount': 0,
      'spending_net': 897.84,
      'income_minus_spending': -897.84,
      'competence_cards_total': 0,
      'competence_direct': 0,
      'competence_benefits': 0,
      'competence_refunds': 0,
      'competence_net': 0,
      'competence_cards': [],
      'cash_inflow': 0,
      'cash_outflow': 0,
      'cash_net': 0,
      'movement_card_payments': 0,
      'movement_transfers': 0,
      'movement_reserve_investment': 0,
      'movement_reconciliation': 0,
    });

    final october = MonthlyMoneySummary.fromJson({
      'period_month': '2026-10-01',
      'income_amount': 0,
      'spending_account': 0,
      'spending_cards': 0,
      'spending_benefits': 0,
      'refunds_amount': 0,
      'spending_net': 0,
      'income_minus_spending': 0,
      'competence_cards_total': 149.64,
      'competence_direct': 0,
      'competence_benefits': 0,
      'competence_refunds': 0,
      'competence_net': 149.64,
      'competence_cards': [
        {'card_id': 'card', 'name': 'Cartão teste', 'amount': 149.64},
      ],
      'cash_inflow': 0,
      'cash_outflow': 0,
      'cash_net': 0,
      'movement_card_payments': 0,
      'movement_transfers': 0,
      'movement_reserve_investment': 0,
      'movement_reconciliation': 0,
    });

    expect(september.spendingCards, 897.84);
    expect(september.competenceCardsTotal, 0);
    expect(october.competenceCardsTotal, 149.64);
  });
}
