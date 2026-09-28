import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/financial_insights_service.dart';
import 'package:folego/data/models/upcoming_financial_event.dart';
import 'package:folego/data/models/wallet_overview.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/data/repositories/folego_repository_agenda.dart';

class _WalletRepository implements FolegoRepository {
  @override
  Future<WalletOverview> getWalletOverview({required String spaceId}) async =>
      WalletOverview.fromJson({
        'accounts': [
          {'id': 'bank', 'name': 'Bank', 'type': 'checking',
           'available_for_spending': true, 'balance': 500},
        ],
      });

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

UpcomingFinancialEvent _event(String key, String date, String direction,
    double amount) => UpcomingFinancialEvent.fromJson({
  'event_key': key, 'source': 'recurring', 'source_id': key,
  'title': key, 'due_date': date, 'direction': direction,
  'amount': amount, 'overdue': false, 'realized': false,
  'cash_obligation': true,
});

void main() {
  tearDown(() => debugFinancialAgendaLoader = null);

  test('cash runway requests disjoint history and future windows', () async {
    final windows = <(DateTime?, DateTime?, int)>[];
    debugFinancialAgendaLoader = ({
      required spaceId, startDate, endDate, required limit,
    }) async {
      expect(spaceId, 'test-space');
      windows.add((startDate, endDate, limit));
      if (startDate == DateTime(2026, 9, 28)) {
        return [
          _event('bill', '2026-09-29', 'outflow', 150),
          _event('income', '2026-10-01', 'income', 2000),
        ];
      }
      return [_event('old', '2026-09-26', 'outflow', 80)];
    };
    final result = await FinancialInsightsService(_WalletRepository()).cashRunway(
      spaceId: 'test-space', asOf: DateTime(2026, 9, 28),
    );
    expect(windows, hasLength(2));
    expect(windows, contains((DateTime(2026, 8, 29), DateTime(2026, 9, 27), 200)));
    expect(windows, contains((DateTime(2026, 9, 28), DateTime(2026, 11, 29), 200)));
    expect(result.openingBalance, 500);
    expect(result.excludedOverdueCount, 1);
    expect(result.guidanceNeedsReview, isTrue);
    expect(result.runway!.balanceAtPayday, 350);
  });

  test('either agenda window reaching cap marks forecast provisional', () async {
    debugFinancialAgendaLoader = ({
      required spaceId, startDate, endDate, required limit,
    }) async {
      if (startDate == DateTime(2026, 9, 28)) {
        return [_event('income', '2026-10-01', 'income', 2000)];
      }
      return List.generate(200, (index) =>
        _event('old-$index', '2026-09-26', 'outflow', 1));
    };
    final result = await FinancialInsightsService(_WalletRepository()).cashRunway(
      spaceId: 'test-space', asOf: DateTime(2026, 9, 28),
    );
    expect(result.agendaMayBeTruncated, isTrue);
    expect(result.guidanceNeedsReview, isTrue);
  });
}
