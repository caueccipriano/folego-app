import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/spending_behavior.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/spending_behavior_screen.dart';
import 'package:folego/features/transactions/financial_review_hub.dart';

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

  test('batch proposals need specific merchants and never guess Pix', () {
    SpendingBehaviorEntry entry(String description) => SpendingBehaviorEntry(
      id: description, description: description, amount: 30,
      occurredAt: DateTime(2026, 10, 17),
      behavior: ExpenseBehavior.unclassified,
    );
    expect(suggestExpenseBehavior(entry('Spotify')),
        ExpenseBehavior.fixed);
    expect(suggestExpenseBehavior(entry('Wellhub')),
        ExpenseBehavior.fixed);
    expect(suggestExpenseBehavior(entry('UBER * PENDING')),
        ExpenseBehavior.variable);
    expect(suggestExpenseBehavior(entry('IFD*BR JUNDIAI')),
        ExpenseBehavior.variable);
    expect(suggestExpenseBehavior(entry('PIX enviada - Santander')), isNull);
    expect(suggestExpenseBehavior(entry('AMAZON BR')), isNull);
    expect(suggestExpenseBehavior(entry('MERCADOLIVRE*ME')), isNull);
    expect(suggestExpenseBehavior(entry('Motortech')), isNull);
    expect(suggestExpenseBehavior(entry('Seguro carro talvez')), isNull);
  });

  test('review tools link from transactions and preserve read-only defaults', () {
    final source = File('lib/features/transactions/transactions_screen.dart')
        .readAsStringSync();
    final hub = File('lib/features/transactions/financial_review_hub.dart')
        .readAsStringSync();
    final detail = File('lib/features/transactions/transaction_detail_sheet_v2.dart')
        .readAsStringSync();
    expect(source, contains('transactions-review-comments'));
    expect(source, contains('transactions-review-pending'));
    expect(source, contains('transactions-review-others'));
    expect(hub, contains('financial_notes'));
    expect(hub, contains('financial_capture_inbox'));
    expect(hub, contains('classifyFinancialEvent'));
    expect(hub, contains('confirmar a categoria?'));
    expect(detail, contains('me explica este valor'));
    expect(detail, contains('não cria a mesma despesa outra vez'));
  });

  test('comments: month, category, account, type filters use linked source', () {
    final note = <String, dynamic>{
      'content': 'reembolso da mãe',
      'title': 'compra teste',
      'note_month': '2026-10',
      'target_type': 'card_purchase',
      'note_category_id': 'c1',
      'note_category_name': 'presentes',
      'note_account_id': 'a1',
      'note_account_name': 'minha conta',
    };
    expect(financialNoteMonth('2026-10-15T10:00:00Z'), '2026-10');
    expect(financialNoteMonth(null), '');
    expect(financialNoteMatchesFilters(note,
      query: 'reembolso', targetType: 'card_purchase',
      month: '2026-10', categoryId: 'c1', accountId: 'a1'), isTrue);
    expect(financialNoteMatchesFilters(note, month: '2026-09'), isFalse);
    expect(financialNoteMatchesFilters(note, categoryId: 'c2'), isFalse);
    expect(financialNoteMatchesFilters(note, accountId: 'a2'), isFalse);
    expect(financialNoteMatchesFilters(note, targetType: 'event'), isFalse);
    expect(financialNoteMatchesFilters(note, query: 'outra pessoa'), isFalse);
  });

  test('review hub includes older unclassified expense queue, not just October', () {
    final hub = File('lib/features/transactions/financial_review_hub.dart')
        .readAsStringSync();
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(hub, contains(".isFilter('behavior_class', null)"));
    expect(hub, contains("'kind': 'behavior'"));
    expect(hub, contains('comments-month-filter'));
    expect(hub, contains('comments-category-filter'));
    expect(hub, contains('comments-account-filter'));
    expect(plan, contains('plan-insight-open-transactions'));
    expect(plan, contains('_showPlanMetricExplanation'));
  });

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

  testWidgets('conflicting edit reloads rather than overwrites', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var loadCount = 0;
    var latest = List<SpendingBehaviorEntry>.from(sample);
    await tester.pumpWidget(MaterialApp(
      home: SpendingBehaviorScreen(
        repository: _Repository(),
        spaceId: 'space-a',
        periodMonth: DateTime(2026, 10),
        loadOverride: (id, month) async {
          loadCount++;
          return List<SpendingBehaviorEntry>.from(latest);
        },
        saveOverride: (id, entry, behavior) async {
          latest = latest.map((item) => item.id == entry.id
              ? item.withBehavior(ExpenseBehavior.fixed) : item).toList();
          throw StateError('classificação alterada em outra sessão; recarregue');
        },
      ),
    ));
    await tester.pumpAndSettle();

    final item = find.byKey(const ValueKey('spending-entry-c'));
    await tester.scrollUntilVisible(
      item, 240, scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(item);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('spending-select-variable')));
    await tester.pumpAndSettle();

    expect(loadCount, greaterThanOrEqualTo(2));
    expect(find.textContaining('outro dispositivo alterou este gasto'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('repo routes classification through atomic CAS with no tag writes', () {
    final source = File('lib/data/repositories/folego_repository.dart')
        .readAsStringSync();
    final method = source.split('Future<void> setSpendingBehavior({').last
        .split('  // ESPAÇO / PERFIL').first;
    final plan = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();

    expect(method, contains("'set_event_behavior_class'"));
    expect(method, contains("'p_expected_behavior_class': expected"));
    expect(method, contains("'p_behavior_class': next"));
    expect(method, contains("'p_event_id': entry.id"));
    expect(method, contains("'p_space_id': spaceId"));
    expect(method, isNot(contains("'p_tag_ids'")));
    expect(method, isNot(contains("'p_necessity_class'")));
    expect(method, isNot(contains("'p_frequency_class'")));
    expect(method, isNot(contains("'set_event_annotations'")));
    expect(plan, contains("ValueKey('plan-open-spending-behavior')"));
  });
}
