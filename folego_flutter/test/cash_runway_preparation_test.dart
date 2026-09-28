import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/cash_runway_preparation.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';

UpcomingFinancialEvent event(String key, String date, String direction,
    double amount, {bool overdue = false, bool realized = false}) => UpcomingFinancialEvent.fromJson({
  'event_key': key, 'source': 'recurring', 'source_id': key,
  'title': key, 'due_date': date, 'direction': direction,
  'amount': amount, 'overdue': overdue, 'realized': realized,
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
  test('duplicate overdue records count as one obligation', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('old-bill', '2026-09-24', 'outflow', 100, overdue: true),
        event('old-bill', '2026-09-24', 'outflow', 100, overdue: true),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.excludedOverdueCount, 1);
    expect(result.guidanceNeedsReview, isTrue);
  });
  test('pauses spending guidance when overdue obligations are excluded', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('overdue', '2026-09-24', 'outflow', 300, overdue: true),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.excludedOverdueCount, 1);
    expect(result.guidanceNeedsReview, isTrue);
    expect(result.runway!.balanceAtPayday, 500);
  });
  test('unpaid past-due obligation is flagged despite stale overdue flag', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('past-due', '2026-09-25', 'outflow', 80),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.excludedOverdueCount, 1);
    expect(result.guidanceNeedsReview, isTrue);
  });
  test('paid overdue obligation no longer blocks guidance', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('paid', '2026-09-24', 'outflow', 80,
            overdue: true, realized: true),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.excludedOverdueCount, 0);
    expect(result.guidanceNeedsReview, isFalse);
  });
  test('unpaid upcoming obligation remains in forecast', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [
        event('bill', '2026-09-28', 'outflow', 150),
        event('income', '2026-09-30', 'income', 2000),
      ],
    );
    expect(result.excludedOverdueCount, 0);
    expect(result.runway!.balanceAtPayday, 350);
    expect(result.guidanceNeedsReview, isFalse);
  });
  test('pauses guidance when financial agenda reaches its result cap', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27),
      agenda: [event('income', '2026-09-30', 'income', 2000)],
      agendaMayBeTruncated: true,
    );
    expect(result.agendaMayBeTruncated, isTrue);
    expect(result.guidanceNeedsReview, isTrue);
  });
  test('does not invent a payday when agenda lacks dated income', () {
    final result = CashRunwayPreparation.fromOfficialData(
      wallet: wallet, asOf: DateTime(2026, 9, 27), agenda: [],
    );
    expect(result.runway, isNull);
    expect(result.nextIncomeDate, isNull);
  });
}
