import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/notifications/notification_models.dart';

void main() {
  Map<String, dynamic> event({String kind = 'newTransaction'}) => {
    'id': 7,
    'kind': kind,
    'title': 'novo lançamento',
    'body': 'Mercado Pago',
    'route': '/transactions/event-a',
    'stable_key': 'newTx:event-a',
    'delivered_at': '2026-10-16T10:32:00-03:00',
    'payload': {'event_id': 'event-a', 'amount': 56.01},
  };
  test(
    'stable key and read state retain transaction identity across refresh',
    () {
      final unread = NotificationHistoryItem.fromJson(event());
      final read = NotificationHistoryItem.fromJson({
        ...event(),
        'seen_at': '2026-10-16T14:00:00Z',
      });
      expect(unread.isUnread, isTrue);
      expect(read.isUnread, isFalse);
      expect(unread.readKey, read.readKey);
      expect(read.payload['event_id'], 'event-a');
      expect(read.deliveredAt.toUtc(), DateTime.utc(2026, 10, 16, 13, 32));
    },
  );
  test(
    'receipt is review evidence and never classified as a confirmed event',
    () {
      final receipt = NotificationHistoryItem.fromJson({
        ...event(kind: 'captureNeedsReview'),
        'route': '/captures/receipt-a',
        'payload': {
          'capture_id': 'receipt-a',
          'review_reason': 'amount_mismatch',
        },
      });
      expect(receipt.needsReview, isTrue);
      expect(receipt.payload.containsKey('event_id'), isFalse);
      expect(
        NotificationHistoryItem.fromJson(event(kind: 'transactionNeedsReview'))
            .needsReview,
        isTrue,
      );
      expect(NotificationHistoryItem.fromJson(event()).needsReview, isFalse);
    },
  );
  test('legacy history gets a read key without changing its id', () {
    final legacy = event()..remove('stable_key');
    expect(NotificationHistoryItem.fromJson(legacy).readKey, 'legacy:7');
    expect(
      NotificationHistoryItem.fromJson({...legacy, 'stable_key': ''}).readKey,
      'legacy:7',
    );
  });
  test(
    'in-app preference defaults on and round trips independently of push',
    () {
      const initial = NotificationPreferences(spaceId: 'space-a');
      expect(initial.transactionActivityEnabled, isTrue);
      expect(initial.financialRemindersEnabled, isFalse);
      final json = initial
          .copyWith(transactionActivityEnabled: false)
          .toUpsertJson('user-a');
      expect(
        NotificationPreferences.fromJson(
          json,
          fallbackSpaceId: 'space-a',
        ).transactionActivityEnabled,
        isFalse,
      );
    },
  );
}
