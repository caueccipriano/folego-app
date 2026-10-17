import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/wallet_detail.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/subscription_insights.dart';
import 'package:folego/features/wallet/installment_relief_card.dart';
import 'package:folego/features/wallet/balance_comparison.dart';
import 'package:folego/features/plan/purchase_comparison.dart';

RecurringItem item(String id, {String account = 'a', bool active = true}) => RecurringItem(
  id: id, spaceId: 's', name: 'Serviço teste', itemType: 'expense', amount: 10,
  frequency: 'monthly', startsOn: DateTime(2026, 1), certainty: 'confirmed',
  active: active, accountId: account,
);
WalletInstallmentPosition position(String id, {DateTime? ending, DateTime? next, bool done = false}) => WalletInstallmentPosition(
  purchaseId: id, description: 'compra', cardId: 'card', cardName: 'cartão',
  installmentAmount: 10, currentInstallment: 1, totalInstallments: 3,
  completed: done, endingOn: ending, lastInstallmentAmount: 10.01,
  nextDueDate: next,
);
void main() {
  test('relief uses actual last due month, deduplicates and excludes overdue/unknown', () {
    final eligible = position('ok', ending: DateTime(2026, 12, 15), next: DateTime(2026, 10, 20));
    final rows = installmentRelief([
      eligible, eligible,
      position('unknown', next: DateTime(2026, 10, 20)),
      position('overdue', ending: DateTime(2026, 12, 15), next: DateTime(2026, 10, 1)),
      position('paid', done: true, ending: DateTime(2026, 12, 15)),
      position('outside', ending: DateTime(2027, 4, 15), next: DateTime(2026, 10, 20)),
    ], DateTime(2026, 10, 17));
    expect(rows.length, 1);
    expect(rows.single.fromMonth, DateTime(2027, 1));
    expect(rows.single.cents, 1001);
  });
  test('missing, duplicated or paid final installment never fabricates an end date', () {
    Map<String, dynamic> purchase(List<Map<String, dynamic>> parts) => {
      'id': 'p', 'description': 'purchase', 'installments_count': 2,
      'card': {'id': 'c', 'name': 'card'}, 'card_installments': parts,
    };
    Map<String, dynamic> part(int n, {String status = 'pending'}) => {
      'installment_number': n, 'amount': 5, 'status': status,
      'invoice': {'due_date': '2026-12-10', 'status': 'open'},
    };
    expect(WalletInstallmentPosition.fromPurchaseJson(purchase([part(1)])).endingOn, isNull);
    expect(WalletInstallmentPosition.fromPurchaseJson(purchase([part(1), part(1)])).endingOn, isNull);
    expect(WalletInstallmentPosition.fromPurchaseJson(purchase([part(1), part(2, status: 'paid')])).endingOn, isNull);
    expect(WalletInstallmentPosition.fromPurchaseJson(purchase([part(1), part(2)])).endingOn, DateTime(2026, 12, 10));
  });
  test('subscription duplicates do not cross instruments or inactive items', () {
    expect(duplicateSubscriptionInsights([item('1'), item('2')]).length, 1);
    expect(duplicateSubscriptionInsights([item('1'), item('2', account: 'b')]), isEmpty);
    expect(duplicateSubscriptionInsights([item('1'), item('2', active: false)]), isEmpty);
  });
  test('price change needs distinct realized cycles for same subscription', () {
    SubscriptionCharge charge(String id, String recurring, int month, double amount) => SubscriptionCharge(
      id: id, recurringId: recurring, date: DateTime(2026, month, 1), amount: amount);
    final first = charge('a', '1', 8, 10);
    expect(changedSubscriptionInsights([item('1')], [first, first]), isEmpty);
    expect(changedSubscriptionInsights([item('1')], [first, charge('b', 'other', 9, 15)]), isEmpty);
    expect(changedSubscriptionInsights([item('1')], [first, charge('b', '1', 9, 10)]), isEmpty);
    expect(changedSubscriptionInsights([item('1')], [first, charge('b', '1', 9, 15)]).single.message, contains('aumento'));
  });
  test('comparison keeps exact cents beyond horizon including rounding and deferred cash', () {
    final options = buildPurchaseOptions(name: 'test', cashCents: 9000, installmentCents: 10001,
      payments: 3, firstPayment: DateTime(2026, 1, 31), delayMonths: 3);
    expect(purchaseCentsBeyondHorizon(options[1], DateTime(2026, 1)), 6666);
    expect(purchaseCentsBeyondHorizon(options[1], DateTime(2026, 3)), 0);
    expect(purchaseCentsBeyondHorizon(options[2], DateTime(2026, 3)), 9000);
  });
  test('manual review timestamps are namespaced by person, space and account', () {
    final key = accountReviewKey('u', 's', 'a');
    expect(accountReviewKey('v', 's', 'a'), isNot(key));
    expect(accountReviewKey('u', 't', 'a'), isNot(key));
    expect(accountReviewKey('u', 's', 'b'), isNot(key));
  });
}
