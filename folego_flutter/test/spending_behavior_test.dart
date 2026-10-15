import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/spending_behavior.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/spending_behavior_screen.dart';

class _Repository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(() async => initializeDateFormatting('pt_BR'));
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  final sample = <SpendingBehaviorEntry>[
    SpendingBehaviorEntry(
      id: 'a', description: 'Aluguel', amount: 1000,
      occurredAt: DateTime(2026, 10, 5), behavior: ExpenseBehavior.fixed,
      frequencyClass: 'recurring', necessityClass: 'need',
    ),
    SpendingBehaviorEntry(
      id: 'b', description: 'Energia elétrica', amount: 150,
      occurredAt: DateTime(2026, 10, 7), behavior: ExpenseBehavior.variable,
      frequencyClass: 'recurring',
    ),
    SpendingBehaviorEntry(
      id: 'c', description: 'Mercado', amount: 250,
      occurredAt: DateTime(2026, 10, 8), behavior: ExpenseBehavior.unclassified,
    ),
  ];

  test('totals keep unclassified values visible, no default guessing', () {
    final s = SpendingBehaviorSummary.fromEntries(sample);
    expect(s.fixed, 1000);
    expect(s.variable, 150);
    expect(s.unclassified, 250);
    expect(s.total, 1400);
    expect(s.unclassifiedCount, 1);
    expect(s.shareOf(ExpenseBehavior.fixed), closeTo(5 / 7, .00001));
    expect(SpendingBehaviorSummary.fromEntries(const []).shareOf(
      ExpenseBehavior.variable), 0);
  });

  test('schema parsing preserves separate necessity and frequency dimensions', () {
    final parsed = SpendingBehaviorEntry.fromJson({
      'id': 'x', 'description': ' CONTA DE LUZ ', 'amount': '100.10',
      'occurred_at': '2026-10-03T11:00:00Z',
      'behavior_class': 'variable',
      'necessity_class': 'need',
      'frequency_class': 'recurring',
    });
    expect(parsed.behavior, ExpenseBehavior.variable);
    expect(parsed.necessityClass, 'need');
    expect(parsed.frequencyClass, 'recurring');
    expect(parsed.amount, closeTo(100.10, .0001));
    expect(ExpenseBehavior.fromDatabase(null), ExpenseBehavior.unclassified);
    expect(parsed.withBehavior(ExpenseBehavior.fixed).necessityClass, 'need');
    expect(
      () => SpendingBehaviorEntry.fromJson({
        'id': 'x', 'description': 'bad', 'amount': double.nan,
        'occurred_at': '2026-10-03T11:00:00Z',
      }),
      throwsFormatException,
    );
  });

  testWidgets('mobile overview changes only explicitly selected type', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var data = List<SpendingBehaviorEntry>.from(sample);
    final updates = <ExpenseBehavior>[];
    await tester.pumpWidget(MaterialApp(
      home: SpendingBehaviorScreen(
        repository: _Repository(), spaceId: 'space-a',
        periodMonth: DateTime(2026, 10),
        loadOverride: (id, month) async {
          expect(id, 'space-a');
          return List<SpendingBehaviorEntry>.from(data);
        },
        saveOverride: (id, entry, behavior) async {
          expect(id, 'space-a');
          expect(entry.id, 'c');
          updates.add(behavior);
          data = data.map((item) =>
              item.id == entry.id ? item.withBehavior(behavior) : item).toList();
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('spending-behavior-total')), findsOneWidget);
    final item = find.byKey(const ValueKey('spending-entry-c'));
    await tester.scrollUntilVisible(item, 240,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(item);
    await tester.pumpAndSettle();
    expect(updates, isEmpty);
    await tester.tap(find.byKey(const ValueKey('spending-select-variable')));
    await tester.pumpAndSettle();
    expect(updates, [ExpenseBehavior.variable]);
    expect(find.text('tipo de gasto salvo.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('repo passes through current necessity/frequency/tags when saving', () {
    final repository = File('lib/data/repositories/folego_repository.dart')
        .readAsStringSync();
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(repository, contains("'p_necessity_class': current['necessity_class']"));
    expect(repository, contains("'p_frequency_class': current['frequency_class']"));
    expect(repository, contains("'p_tag_ids': tags"));
    expect(repository, contains("'p_event_id': entry.id"));
    expect(repository, contains("'status', 'confirmed'"));
    expect(plan, contains("ValueKey('plan-open-spending-behavior')"));
  });
}
