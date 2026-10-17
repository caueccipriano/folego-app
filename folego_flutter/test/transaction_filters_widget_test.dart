import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/realtime/realtime_invalidation.dart';
import 'package:folego/core/realtime/realtime_session.dart';
import 'package:folego/data/models/account_item.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/credit_card_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/models/transaction_filters.dart';
import 'package:folego/data/models/transaction_item.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/transactions/transaction_filter_sheet.dart';
import 'package:folego/features/transactions/transactions_screen_base.dart';

void main() {
  const space = FinancialSpace(id: 'space-1', name: 'Pessoal');

  testWidgets('search waits 350ms and pending timer is cancelled on dispose', (
    tester,
  ) async {
    final requests = <_PageRequest>[];
    final repository = _FakeRepository();

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: _recordingLoader(requests),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(requests, hasLength(1));

    await tester.enterText(find.byType(TextField).first, 'uber');
    await tester.pump(const Duration(milliseconds: 349));
    expect(requests, hasLength(1));

    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(requests, hasLength(2));
    expect(requests.last.filters.search, 'uber');

    await tester.enterText(find.byType(TextField).first, 'pendente');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(milliseconds: 400));
    expect(requests, hasLength(2));
  });

  testWidgets('an older search response cannot replace the newest query', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final oldRequest = Completer<TransactionPage>();
    final newestRequest = Completer<TransactionPage>();

    Future<TransactionPage> loader({
      required String spaceId,
      required TransactionFilters filters,
      required TransactionCursor? cursor,
      required int pageSize,
    }) {
      if (filters.search == 'u') return oldRequest.future;
      if (filters.search == 'uber') return newestRequest.future;
      return Future.value(_emptyPage());
    }

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'u');
    await tester.pump(transactionSearchDebounce);
    await tester.pump();

    await tester.enterText(find.byType(TextField).first, 'uber');
    await tester.pump(transactionSearchDebounce);
    await tester.pump();

    newestRequest.complete(_pageWith(_transaction('new', 'Uber')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Uber'), findsOneWidget);

    oldRequest.complete(_pageWith(_transaction('old', 'Resposta antiga')));
    await tester.pump();
    await tester.pump();
    expect(find.text('Uber'), findsOneWidget);
    expect(find.text('Resposta antiga'), findsNothing);
  });

  testWidgets('filter sheet represents period, type, category, account, card and benefit', (
    tester,
  ) async {
    final options = TransactionFilterOptions(
      categories: const [
        CategoryItem(
          id: 'cat-1',
          name: 'Restaurantes',
          essential: false,
          kind: 'expense',
        ),
      ],
      accounts: const [
        AccountItem(id: 'account-1', name: 'Santander', type: 'checking'),
      ],
      cards: const [
        CreditCardItem(id: 'card-1', name: 'AMEX', active: true),
      ],
      benefits: const [
        AccountItem(id: 'benefit-1', name: 'Flash', type: 'benefit'),
      ],
    );
    final initial = TransactionFilters(
      startDate: DateTime(2026, 9, 1),
      endDate: DateTime(2026, 9, 30),
      eventTypes: const {'expense'},
      categoryId: 'cat-1',
      accountId: 'account-1',
      cardId: 'card-1',
      benefitAccountId: 'benefit-1',
    );

    await tester.pumpWidget(
      _app(TransactionFilterSheet(initial: initial, options: options)),
    );
    await tester.pump();

    expect(find.text('01/09/2026 — 30/09/2026'), findsOneWidget);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'gasto')).selected, isTrue);
    expect(find.text('Restaurantes'), findsOneWidget);
    expect(find.text('Santander'), findsOneWidget);
    expect(find.text('AMEX'), findsOneWidget);
    expect(find.text('Flash'), findsOneWidget);
  });

  testWidgets('filters apply, show a removable chip and clear', (tester) async {
    final repository = _FakeRepository();
    final requests = <_PageRequest>[];

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: _recordingLoader(requests),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('nenhum lançamento ainda'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'gasto'));
    await tester.pump();
    await tester.tap(find.text('aplicar'));
    await tester.pumpAndSettle();

    expect(find.text('filtros · 1'), findsOneWidget);
    final chipFinder = find.widgetWithText(InputChip, 'gasto');
    expect(chipFinder, findsOneWidget);
    tester.widget<InputChip>(chipFinder).onDeleted!.call();
    await tester.pumpAndSettle();
    expect(find.text('filtros'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'gasto'));
    await tester.tap(find.text('aplicar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('limpar filtros'));
    await tester.pumpAndSettle();

    expect(find.text('filtros'), findsOneWidget);
    expect(find.widgetWithText(InputChip, 'gasto'), findsNothing);
    expect(requests.last.filters.hasQuery, isFalse);
  });

  testWidgets('empty state distinguishes a filtered search', (tester) async {
    final repository = _FakeRepository();

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: _recordingLoader(<_PageRequest>[]),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'nada');
    await tester.pump(transactionSearchDebounce);
    await tester.pumpAndSettle();

    expect(find.text('nenhum lançamento por aqui'), findsOneWidget);
    expect(find.text('tente ajustar os filtros ou a busca'), findsOneWidget);
  });

  testWidgets('realtime refresh keeps the active search and reloads page one', (
    tester,
  ) async {
    final repository = _FakeRepository();
    final requests = <_PageRequest>[];
    final coordinator = RealtimeInvalidationCoordinator();
    AppRealtimeRegistry.attach(coordinator);

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: _recordingLoader(requests),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'uber');
    await tester.pump(transactionSearchDebounce);
    await tester.pumpAndSettle();
    final beforeRealtime = requests.length;
    expect(requests.last.filters.search, 'uber');

    coordinator.invalidate(AppRealtimeDomain.transactions);
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();

    expect(requests.length, greaterThan(beforeRealtime));
    expect(requests.last.filters.search, 'uber');
    expect(requests.last.cursor, isNull);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    AppRealtimeRegistry.detach(coordinator);
    coordinator.dispose();
  });

  testWidgets('next page keeps search and a new filter resets the cursor', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repository = _FakeRepository();
    final requests = <_PageRequest>[];
    final pageCursor = TransactionCursor(
      occurredAt: DateTime.utc(2026, 9, 1, 11, 11),
      id: 'cursor-50',
    );

    Future<TransactionPage> loader({
      required String spaceId,
      required TransactionFilters filters,
      required TransactionCursor? cursor,
      required int pageSize,
    }) async {
      requests.add(_PageRequest(filters, cursor));
      if (cursor != null) {
        return TransactionPage(
          items: [_transaction('next', '${filters.search} next')],
          hasMore: false,
          nextCursor: null,
        );
      }
      if (filters.search == 'uber') {
        return TransactionPage(
          items: List.generate(
            50,
            (index) => _transaction(
              'id-$index',
              'uber item ${index.toString().padLeft(2, '0')}',
              occurredAt: DateTime.utc(2026, 9, 1, 12).subtract(
                Duration(minutes: index),
              ),
            ),
          ),
          hasMore: true,
          nextCursor: pageCursor,
        );
      }
      return _emptyPage();
    }

    await tester.pumpWidget(
      _app(
        TransactionsScreenV3(
          repository: repository,
          space: space,
          optionsLoader: (_) async => TransactionFilterOptions.empty(),
          pageLoader: loader,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'uber');
    await tester.pump(transactionSearchDebounce);
    await tester.pumpAndSettle();
    expect(requests.last.cursor, isNull);

    await tester.fling(find.byType(ListView).last, const Offset(0, -5000), 5000);
    await tester.pumpAndSettle();

    final paged = requests.where((request) => request.cursor != null).toList();
    expect(paged, isNotEmpty);
    expect(paged.last.filters.search, 'uber');
    expect(paged.last.cursor?.id, 'cursor-50');
    expect(paged.last.pageSize, transactionPageSize);

    await tester.tap(find.byKey(const ValueKey('transaction-filter-button')));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilterChip, 'gasto'));
    await tester.tap(find.text('aplicar'));
    await tester.pumpAndSettle();

    expect(requests.last.cursor, isNull);
    expect(requests.last.filters.search, 'uber');
    expect(requests.last.filters.eventTypes, contains('expense'));
  });
}

Widget _app(Widget home) => MaterialApp(home: home);

TransactionPageLoader _recordingLoader(List<_PageRequest> requests) {
  return ({
    required String spaceId,
    required TransactionFilters filters,
    required TransactionCursor? cursor,
    required int pageSize,
  }) async {
    requests.add(_PageRequest(filters, cursor, pageSize));
    return _emptyPage();
  };
}

TransactionPage _emptyPage() => const TransactionPage(
  items: <TransactionItem>[],
  hasMore: false,
  nextCursor: null,
);

TransactionPage _pageWith(TransactionItem item) => TransactionPage(
  items: [item],
  hasMore: false,
  nextCursor: null,
);

TransactionItem _transaction(
  String id,
  String description, {
  DateTime? occurredAt,
}) {
  return TransactionItem(
    id: id,
    eventType: 'expense',
    description: description,
    amount: 10,
    occurredAt: occurredAt ?? DateTime.utc(2026, 9, 15, 12),
    status: 'confirmed',
    source: 'test',
  );
}

class _PageRequest {
  const _PageRequest(this.filters, this.cursor, [this.pageSize = transactionPageSize]);
  final TransactionFilters filters;
  final TransactionCursor? cursor;
  final int pageSize;
}

class _FakeRepository implements FolegoRepository {
  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async {
    return const <RecurringItem>[];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
