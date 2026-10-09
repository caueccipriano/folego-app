import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/daily_review_card.dart';

Map<String, dynamic> _review({
  bool complete = false,
  int pending = 0,
}) => {
  'today': '2026-10-09',
  'pending_count': pending,
  'completed_days': const <String>[],
  'review': {
    'completed_at': complete ? '2026-10-09T19:00:00' : null,
    'movements_checked': complete,
    'commitments_checked': complete,
    'no_movements': false,
  },
};

void main() {
  final client = SupabaseClient(
    'https://example.supabase.co',
    'test-placeholder-anon-key',
  );
  tearDownAll(client.dispose);

  Widget app({
    required DailyReviewLoader loader,
    DailyReviewSaver? saver,
    Object? refreshToken,
  }) => MaterialApp(
    home: Scaffold(
      body: SizedBox(
        width: 375,
        child: DailyReviewCard(
          space: const FinancialSpace(id: 'space-1', name: 'teste'),
          repository: FolegoRepository(client),
          refreshToken: refreshToken,
          reviewLoader: loader,
          reviewSaver: saver,
        ),
      ),
    ),
  );

  testWidgets('older network reply cannot undo the newest review', (tester) async {
    final old = Completer<Map<String, dynamic>>();
    final recent = Completer<Map<String, dynamic>>();
    var loads = 0;
    Future<Map<String, dynamic>> loader(String _) {
      loads++;
      return loads == 1 ? old.future : recent.future;
    }

    await tester.pumpWidget(app(loader: loader, refreshToken: 1));
    await tester.pump();
    await tester.pumpWidget(app(loader: loader, refreshToken: 2));
    recent.complete(_review(complete: true));
    await tester.pumpAndSettle();
    expect(find.text('check-in concluído'), findsOneWidget);

    old.complete(_review(pending: 18));
    await tester.pumpAndSettle();
    expect(find.text('check-in concluído'), findsOneWidget);
    expect(find.text('seu check-in'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late save never pops Home after check-in is dismissed', (tester) async {
    final save = Completer<void>();
    var saveCalled = false;
    await tester.pumpWidget(app(
      loader: (_) async => _review(),
      saver: ({
        required spaceId,
        required movementsChecked,
        required commitmentsChecked,
        required noMovements,
        required complete,
        required snooze,
      }) {
        saveCalled = true;
        return save.future;
      },
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('home-daily-review-prompt')));
    await tester.pumpAndSettle();
    expect(find.text('lembrar daqui a 30 minutos'), findsOneWidget);

    await tester.tap(find.text('lembrar daqui a 30 minutos'));
    await tester.pump();
    expect(saveCalled, isTrue);

    await tester.tap(find.byTooltip('fechar revisão'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-daily-review-prompt')), findsOneWidget);

    save.complete();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('home-daily-review-prompt')), findsOneWidget);
    expect(find.text('seu check-in'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
