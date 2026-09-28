import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/cash_runway_preparation.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';

UpcomingFinancialEvent event(String key, String date, String direction,
    double amount, {bool overdue = false}) => UpcomingFinancialEvent.fromJson({
  'event_key': key, 'source': 'recurring', 'source_id': key,
  'title': key, 'due_date': date, 'direction': direction,
  'amount': amount, 'overdue': overdue, 'realized': false,
  'cash_obligation': true,
});

void main() {
  final wallet = WalletOverview.fromJson({
    'accounts': [
      {'id': 'bank', 'name': 'Bank', 'type': 'checking',
       'available_for_spending': true, 'balance': 500},
      {'id': 'benefit', 'name': 'Meal', 'type': 'benefit',
       'available_for_spending': true, 'balance': 300},
      {'id': 'locked', 'name': 'Locked', 'type': 'savings',
       'available_for_spending': false, 'balance': 700},
    ],
  });
  test('uses only available cash and avoids duplicate agenda events', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('bill', '2026-09-28', 'outflow', 100),
        event('bill', '2026-09-28', 'outflow', 100),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.openingBalance, 500);
    expect(result.nextIncomeDate, DateTime(2026, 9, 30));
    expect(result.runway!.balanceAtPayday, 400);
  });
  test('does not invent a payday when agenda lacks dated income', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27), agenda: [],
    );
    expect(result.runway, isNull);
    expect(result.nextIncomeDate, isNull);
  });
}
