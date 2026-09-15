import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/transaction_reflection.dart';

void main() {
  TransactionReflection reflection(ReflectionType type, {String? note}) {
    return TransactionReflection(
      id: 'reflection-${type.persistedValue}',
      spaceId: 'space-1',
      eventId: 'event-${type.persistedValue}',
      type: type,
      note: note,
      createdAt: DateTime(2026, 9, 1),
      updatedAt: DateTime(2026, 9, 1),
    );
  }

  DiaryEntry entry({
    required String id,
    required String type,
    required double amount,
    TransactionReflection? reflectionValue,
    String description = 'Gasto',
    DateTime? occurredAt,
  }) {
    return DiaryEntry(
      eventId: id,
      eventType: type,
      description: description,
      amount: amount,
      occurredAt: occurredAt ?? DateTime(2026, 9, 10),
      categoryName: 'Restaurantes',
      reflection: reflectionValue,
    );
  }

  group('ReflectionType', () {
    test('parses only stable persisted values', () {
      expect(ReflectionType.tryParse('necessary'), ReflectionType.necessary);
      expect(ReflectionType.tryParse('want'), ReflectionType.want);
      expect(
        ReflectionType.tryParse('self_investment'),
        ReflectionType.selfInvestment,
      );
      expect(ReflectionType.tryParse('necessário'), isNull);
      expect(ReflectionType.tryParse('bad'), isNull);
    });
  });

  group('Diary eligibility', () {
    test('eligible real expenses are accepted', () {
      expect(isDiaryEligibleEventType('expense'), isTrue);
      expect(isDiaryEligibleEventType('card_purchase'), isTrue);
      expect(isDiaryEligibleEventType('benefit_expense'), isTrue);
    });

    test('non-expenses are rejected', () {
      expect(isDiaryEligibleEventType('income'), isFalse);
      expect(isDiaryEligibleEventType('transfer'), isFalse);
      expect(isDiaryEligibleEventType('card_payment'), isFalse);
      expect(isDiaryEligibleEventType('opening_balance'), isFalse);
      expect(isDiaryEligibleEventType('benefit_credit'), isFalse);
      expect(isDiaryEligibleEventType('refund'), isFalse);
      expect(isDiaryEligibleEventType('adjustment'), isFalse);
    });
  });

  group('Diary summary', () {
    test('calculates 60/30/10 by amount, not count', () {
      final entries = [
        entry(
          id: 'n',
          type: 'expense',
          amount: 600,
          reflectionValue: reflection(ReflectionType.necessary),
        ),
        entry(
          id: 'w',
          type: 'card_purchase',
          amount: 300,
          reflectionValue: reflection(ReflectionType.want),
        ),
        entry(
          id: 's',
          type: 'benefit_expense',
          amount: 100,
          reflectionValue: reflection(ReflectionType.selfInvestment),
        ),
      ];
      final summary = DiarySummary.fromEntries(entries);

      expect(summary.totalReflected, 1000);
      expect(summary.percentage(ReflectionType.necessary), closeTo(.60, .0001));
      expect(summary.percentage(ReflectionType.want), closeTo(.30, .0001));
      expect(
        summary.percentage(ReflectionType.selfInvestment),
        closeTo(.10, .0001),
      );
      expect(summary.largestType, ReflectionType.necessary);
      expect(summary.insight, contains('necessária'));
    });

    test('zero summary is safe and deterministic', () {
      final summary = DiarySummary.fromEntries(const []);
      expect(summary.totalReflected, 0);
      expect(summary.percentage(ReflectionType.want), 0);
      expect(summary.largestType, isNull);
      expect(summary.insight, contains('ganhar contexto'));
    });

    test('want and self investment insights are deterministic', () {
      final wantSummary = DiarySummary.fromEntries([
        entry(
          id: 'w',
          type: 'expense',
          amount: 40,
          reflectionValue: reflection(ReflectionType.want),
        ),
      ]);
      expect(wantSummary.insight, contains('100%'));
      expect(wantSummary.insight, contains('vontade'));

      final selfSummary = DiarySummary.fromEntries([
        entry(
          id: 's',
          type: 'expense',
          amount: 22,
          reflectionValue: reflection(ReflectionType.selfInvestment),
        ),
      ]);
      expect(selfSummary.insight, contains('investimento em você'));
    });
  });

  group('Diary presentation', () {
    test('optional note remains nullable', () {
      final parsed = TransactionReflection.fromJson({
        'id': 'r1',
        'space_id': 's1',
        'event_id': 'e1',
        'reflection_type': 'necessary',
        'note': null,
        'created_at': '2026-09-01T10:00:00Z',
        'updated_at': '2026-09-01T10:00:00Z',
      });
      expect(parsed.note, isNull);
    });

    test('timeline excludes entries without reflection', () {
      final reflected = entry(
        id: 'reflected',
        type: 'expense',
        amount: 10,
        reflectionValue: reflection(ReflectionType.want),
      );
      final pending = entry(
        id: 'pending',
        type: 'expense',
        amount: 20,
      );
      expect(reflectedTimeline([pending, reflected]), [reflected]);
      expect(pendingReflectionEntries([pending, reflected]), [pending]);
    });

    test('import suffix is removed only for display', () {
      const stored = 'PIX enviado - Giovani [extrato 5]';
      expect(diaryDisplayDescription(stored), 'PIX enviado - Giovani');
      expect(stored, contains('[extrato 5]'));
    });
  });
}
