import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/purchase_scenario_service.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/widgets/purchase_simulator_card.dart';

class _TestRepository implements FolegoRepository {
  _TestRepository(this.identity);
  String identity;
  @override
  String? get currentUserId => identity;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ControlledService extends PurchaseScenarioService {
  _ControlledService(super.repository);
  final pending = Completer<PurchaseScenario>();
  int calls = 0;
  int? lastInstallments;
  int? lastHorizon;

  @override
  Future<PurchaseScenario> simulate({
    required String spaceId,
    required double purchaseAmount,
    required int installments,
    int horizonMonths = 12,
    DateTime? purchaseDate,
  }) {
    calls++;
    lastInstallments = installments;
    lastHorizon = horizonMonths;
    return pending.future;
  }
}

ProjectionResult _projection(double balance) => ProjectionResult.fromJson({
  'scenario': 'synthetic',
  'horizon_months': 12,
  'as_of_date': '2026-09-30',
  'has_projection_inputs': true,
  'summary': {'ending_balance': balance},
  'months': [
    {'month': '2026-09-01', 'closing_projected': balance},
  ],
});

PurchaseScenario _scenario(double balance) => PurchaseScenario(
  baseline: _projection(balance),
  withPurchase: _projection(balance - 250),
  monthlyPayment: 250,
  firstNegativeMonth: balance < 250 ? DateTime(2026, 9) : null,
);

Widget _host(_ControlledService service, String spaceId) => MaterialApp(
  home: Scaffold(
    body: SingleChildScrollView(child: PurchaseSimulatorCard(
      service: service, spaceId: spaceId, embedded: true,
    )),
  ),
);

void main() {
  testWidgets('quick options reuse one official simulation and render month detail',
      (tester) async {
    final repository = _TestRepository('fictional-A');
    final service = _ControlledService(repository);
    await tester.pumpWidget(_host(service, 'space-A'));
    await tester.tap(find.byKey(const ValueKey('purchase-option-6')));
    await tester.enterText(find.byType(TextField), '1500');
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(service.calls, 1);
    expect(service.lastInstallments, 6);
    expect(service.lastHorizon, 12);
    service.pending.complete(_scenario(1000));
    await tester.pump();
    expect(find.byKey(const ValueKey('purchase-timeline')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('late result from old space is not visible after space switch',
      (tester) async {
    final old = _ControlledService(_TestRepository('fictional-A'));
    final newer = _ControlledService(_TestRepository('fictional-B'));
    await tester.pumpWidget(_host(old, 'space-A'));
    await tester.enterText(find.byType(TextField), '1000');
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    await tester.pumpWidget(_host(newer, 'space-B'));
    old.pending.complete(_scenario(999999));
    await tester.pump();
    expect(find.byKey(const ValueKey('purchase-timeline')), findsNothing);
    expect(find.textContaining('999.999'), findsNothing);
    expect(find.text('1000'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('completed simulation clears when same repository changes identity',
      (tester) async {
    final repository = _TestRepository('fictional-A');
    final service = _ControlledService(repository);
    await tester.pumpWidget(_host(service, 'space-A'));
    await tester.enterText(find.byType(TextField), '250');
    final button = find.byType(FilledButton);
    await tester.ensureVisible(button);
    await tester.tap(button);
    service.pending.complete(_scenario(777777));
    await tester.pump();
    expect(find.byKey(const ValueKey('purchase-timeline')), findsOneWidget);
    repository.identity = 'fictional-B';
    await tester.pumpWidget(_host(service, 'space-A'));
    await tester.pump();
    expect(find.byKey(const ValueKey('purchase-timeline')), findsNothing);
    expect(find.textContaining('777.777'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
