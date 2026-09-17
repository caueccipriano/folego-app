import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/features/transactions/subscriptions_tab.dart';

RecurringItem _item({
  String id = 'rec-1',
  String name = 'Serviço fictício',
  String frequency = 'monthly',
  double amount = 120,
  int? dayOfMonth = 10,
  int? monthOfYear,
  String itemType = 'expense',
  bool active = true,
}) {
  return RecurringItem(
    id: id,
    spaceId: 'space-1',
    name: name,
    itemType: itemType,
    amount: amount,
    frequency: frequency,
    startsOn: DateTime(2026, 1, 1),
    dayOfMonth: dayOfMonth,
    monthOfYear: monthOfYear,
    certainty: 'confirmed',
    active: active,
    categoryName: 'Software',
    accountName: 'Conta teste',
  );
}

void main() {
  group('QA subscriptions consolidation', () {
    test('monthly and annual values preserve deterministic monthly equivalent', () {
      expect(subscriptionMonthlyEquivalent(_item()), 120);
      expect(
        subscriptionMonthlyEquivalent(
          _item(frequency: 'yearly', amount: 1200, monthOfYear: 9),
        ),
        100,
      );
      expect(subscriptionFrequencyLabel(_item()), 'mensal');
      expect(
        subscriptionFrequencyLabel(
          _item(frequency: 'yearly', monthOfYear: 9),
        ),
        'anual',
      );
    });

    test('subscription model stays on canonical recurring_items table', () {
      final migration = File(
        '../supabase/migrations/20260916192434_add_recurring_subscription_kind.sql',
      ).readAsStringSync();
      final repository = File(
        'lib/data/repositories/folego_repository_subscriptions.dart',
      ).readAsStringSync();

      expect(migration, contains('alter table public.recurring_items'));
      expect(migration, contains('recurrence_kind'));
      expect(migration, isNot(contains('create table public.subscriptions')));
      expect(repository, contains(".from('recurring_items')"));
      expect(repository, contains(".eq('recurrence_kind', 'subscription')"));
    });

    test('subscriptions tab keeps explicit end-service disclaimer and recurring edit', () {
      final source = File(
        'lib/features/transactions/subscriptions_tab.dart',
      ).readAsStringSync();
      final transactions = File(
        'lib/features/transactions/transactions_screen_base.dart',
      ).readAsStringSync();

      expect(source, contains('Isso não cancela o serviço com o fornecedor.'));
      expect(source, contains('marcar como encerrada'));
      expect(source, contains('mover para recorrências'));
      expect(source, contains('onEdit'));
      expect(transactions, contains('TabController(length: 3'));
      expect(transactions, contains("Tab(text: 'Assinaturas')"));
      expect(transactions, contains('_subscriptionIds'));
    });

    testWidgets('subscriptions empty state is responsive on mobile and desktop', (
      tester,
    ) async {
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      Future<void> pumpAt(Size size) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = size;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: SubscriptionsTab(
                items: const [],
                recurringCandidates: const [],
                cardNames: const {},
                onRefresh: () async {},
                onEdit: (_) async {},
                onEnd: (_) async {},
                onClassify: (_) async {},
                onMoveToRecurring: (_) async {},
              ),
            ),
          ),
        );
        await tester.pump();
      }

      await pumpAt(const Size(390, 844));
      expect(find.byKey(const ValueKey('subscriptions-mobile-layout')), findsOneWidget);
      expect(find.text('nenhuma assinatura ainda'), findsOneWidget);

      await pumpAt(const Size(1366, 900));
      expect(find.byKey(const ValueKey('subscriptions-desktop-layout')), findsOneWidget);
      expect(find.text('nenhuma assinatura ainda'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
