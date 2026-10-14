import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/privacy/financial_privacy.dart';
import 'package:folego/data/models/sheet_reconciliation_audit.dart';
import 'package:folego/data/models/sheet_sync_status.dart';
import 'package:folego/features/profile/sheet_audit_screen.dart';
import 'package:folego/features/profile/sheet_sync_status_card.dart';

SheetAuditItem _entry(String id, {
  bool review = false,
  String? category,
  bool hidden = false,
  bool linked = true,
}) => SheetAuditItem(
  id: id,
  description: 'Registro fictício $id',
  amount: 27.50,
  occurredAt: DateTime.utc(2026, 10, 13),
  eventType: 'expense',
  categoryId: category,
  needsClassification: review,
  hidden: hidden,
  sheetLinked: linked,
);

void main() {
  setUp(() => FinancialPrivacy.hidden.value = false);
  tearDown(() => FinancialPrivacy.hidden.value = false);

  test('audit only trusts explicit backend flags, never a sync guess', () {
    final event = SheetAuditItem.fromJson({
      'id': 'event-1',
      'description': 'Exemplo fictício',
      'amount': 10.50,
      'occurred_at': '2026-10-13T12:00:00Z',
      'event_type': 'expense',
      'category_id': 'cat-1',
      'metadata': {
        'sheet_linked': true,
        'needs_classification': 'true',
      },
    });
    expect(event.sheetLinked, isTrue);
    expect(event.needsReview, isTrue);
    expect(event.reviewLabel, 'Conferir categoria');
    expect(_entry('x').reviewLabel,
        'Sem confirmação de retorno da planilha');
    expect(_entry('y', review: true).reviewLabel, 'Categoria pendente');
  });

  test('only explicit latest-version ACK changes the row label', () {
    final withoutReceipt = _entry('linked', category: 'cat-1');
    expect(withoutReceipt.reviewLabel, 'Sem confirmação de retorno da planilha');
    final withReceipt = withoutReceipt.withSheetAppliedAt(
      DateTime.utc(2026, 10, 14, 3, 0),
    );
    expect(withReceipt.reviewLabel, 'Aplicação confirmada pela planilha');
    // A classification still awaiting manual review is NOT reconciled.
    final manualReview = _entry('review', review: true, category: 'cat-1')
        .withSheetAppliedAt(DateTime.utc(2026, 10, 14, 3, 0));
    expect(manualReview.reviewLabel, 'Conferir categoria');
  });

  test('samples remove hidden/unlinked duplicates and prioritize reviews', () {
    final sample = mergeSheetAuditSamples(
      recent: [
        _entry('old'),
        _entry('hidden', hidden: true),
        _entry('not-linked', linked: false),
      ],
      pending: [
        _entry('urgent', review: true),
        _entry('old'),
      ],
    );
    expect(sample.map((e) => e.id), ['urgent', 'old']);
    expect(sample.first.needsReview, isTrue);
  });

  testWidgets('auditor warns about missing sheet receipts and masks money',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: SheetAuditScreen(
      spaceId: 'space-1',
      loadItems: (_) async => [
        _entry('review', review: true),
        _entry('other', category: 'category-1'),
      ],
    )));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sheet-audit-no-ack-warning')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-audit-row-review')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-audit-row-other')),
        findsNothing);
    await tester.tap(find.byKey(const ValueKey('sheet-audit-all')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-audit-row-other')),
        findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-audit-ack-summary')),
        findsOneWidget);
    expect(find.textContaining('0 aplicação(ões) confirmada(s)'),
        findsOneWidget);

    FinancialPrivacy.hidden.value = true;
    await tester.pump();
    expect(find.text('R\$ ••••'), findsNWidgets(2));
  });

  testWidgets('late previous-space data cannot leak into a new space',
      (tester) async {
    final old = Completer<List<SheetAuditItem>>();
    final current = Completer<List<SheetAuditItem>>();
    Future<List<SheetAuditItem>> loader(String id) =>
        id == 'space-a' ? old.future : current.future;
    Widget screen(String id) => MaterialApp(
      home: SheetAuditScreen(spaceId: id, loadItems: loader),
    );

    await tester.pumpWidget(screen('space-a'));
    await tester.pumpWidget(screen('space-b'));
    old.complete([_entry('from-a', review: true)]);
    await tester.pump();
    expect(find.text('Registro fictício from-a'), findsNothing);

    current.complete([_entry('from-b', review: true)]);
    await tester.pumpAndSettle();
    expect(find.text('Registro fictício from-b'), findsOneWidget);
    expect(find.text('Registro fictício from-a'), findsNothing);
  });

  testWidgets('audit link requires a configured and enabled integration',
      (tester) async {
    var opens = 0;
    Future<void> show(bool configured, bool enabled) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SheetSyncStatusCard(
            key: ValueKey('status-$configured-$enabled'),
            spaceId: 'space-a',
            loadStatus: (_) async =>
                SheetSyncStatus(configured: configured, enabled: enabled),
            onOpenAudit: () => opens++,
          ),
        ),
      ));
      await tester.pumpAndSettle();
    }

    await show(false, false);
    expect(find.byKey(const ValueKey('sheet-audit-open')), findsNothing);
    await show(true, false);
    expect(find.byKey(const ValueKey('sheet-audit-open')), findsNothing);
    await show(true, true);
    expect(find.byKey(const ValueKey('sheet-audit-open')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sheet-audit-open')));
    expect(opens, 1);
  });

  testWidgets('a failed audit query does not retain previous entries',
      (tester) async {
    var fails = false;
    await tester.pumpWidget(MaterialApp(home: SheetAuditScreen(
      spaceId: 'space-a',
      loadItems: (_) async {
        if (fails) throw StateError('secret backend detail');
        return [_entry('ready', review: true)];
      },
    )));
    await tester.pumpAndSettle();
    expect(find.text('Registro fictício ready'), findsOneWidget);

    fails = true;
    final state = find.byType(SheetAuditScreen);
    // Use the refresh gesture, which invokes the same guarded read path.
    await tester.drag(state, const Offset(0, 400));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-audit-unavailable')),
        findsOneWidget);
    expect(find.text('Registro fictício ready'), findsNothing);
    expect(find.textContaining('secret backend detail'), findsNothing);
  });
}
