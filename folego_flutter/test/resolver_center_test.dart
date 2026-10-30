import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/home_quick_tools.dart';
import 'package:folego/features/transactions/resolver_queue.dart';

Map<String, dynamic> task(String kind, String id, {String? date}) => {
  'id': id,
  'kind': kind,
  'description': 'Item $id',
  'occurred_at': date ?? '2026-10-20',
};

void main() {
  test('resolver merges existing four queues without double-counting events', () {
    final merged = mergeResolverTasks(
      pending: [
        task('behavior', 'same'),
        task('classification', 'same'),
        task('capture', 'receipt-1'),
        task('behavior', 'other-event'),
      ],
      other: [
        task('whatever', 'same'),
        task('whatever', 'other-event'),
        task('whatever', 'unique-other'),
      ],
    );
    expect(merged.length, 4);
    expect(merged.map((row) => row['kind']).toList(),
      ['capture', 'classification', 'other', 'other']);
    expect(merged.where((row) => row['id'] == 'same'), hasLength(1));
  });

  test('resolver retains capture id even when a financial event shares id', () {
    final merged = mergeResolverTasks(
      pending: [
        task('capture', 'shared-id'),
        task('classification', 'shared-id'),
      ],
      other: [],
    );
    expect(merged, hasLength(2));
    expect(merged.first['kind'], 'capture');
  });

  test('resolver lists latest records within their priority group', () {
    final merged = mergeResolverTasks(
      pending: [
        task('classification', 'old', date: '2026-09-01'),
        task('classification', 'new', date: '2026-10-20'),
        task('unknown', 'ignore'),
        task('behavior', 'without-id')..remove('id'),
      ],
      other: [],
    );
    expect(merged.map((row) => row['id']).toList(), ['new', 'old']);
  });

  test('read-only action descriptions do not imply automatic financial changes', () {
    expect(resolverTaskAction('classification'), 'organizar categoria');
    expect(resolverTaskAction('capture'), 'conferir comprovante');
    expect(resolverTaskAction('other'), 'revisar categoria');
    expect(resolverTaskAction('behavior'), 'conferir lançamento');
    expect(resolverTabIndex, 3);
    expect(mergeResolverTasks(pending: [], other: []), isEmpty);
  });

  testWidgets('home gives one-tap Resolver access without a third shortcut',
      (tester) async {
    var opens = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: HomeQuickTools(
        onSearch: () {},
        onPending: () => opens++,
      )),
    ));
    expect(find.text('resolver'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-pending-center')));
    expect(opens, 1);
    expect(find.byKey(const ValueKey('home-income-setup')), findsNothing);
  });

  test('central uses existing read-only queries and explicit review screens', () {
    final hub = File('lib/features/transactions/financial_review_hub.dart')
        .readAsStringSync();
    final home = File('lib/features/home/home_screen_base.dart')
        .readAsStringSync();
    expect(hub, contains('mergeResolverTasks(pending: queues[0], other: queues[1])'));
    expect(hub, contains('initiallyExpanded: false'));
    expect(hub, contains("ValueKey('resolver-center')"));
    expect(hub, contains("ValueKey('resolver-empty')"));
    expect(hub, contains('_reviewOther(row)'));
    expect(hub, contains('_openPending(row)'));
    expect(hub, contains('FinancialPrivacy.hidden'));
    expect(hub, contains('snapshot.connectionState != ConnectionState.done'));
    expect(home, contains('initialTab: resolverTabIndex'));
  });
}
