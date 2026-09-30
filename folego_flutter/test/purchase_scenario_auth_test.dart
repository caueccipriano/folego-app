import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/intelligence/purchase_scenario_service.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/data/repositories/folego_repository.dart';

class _ControlledRepo implements FolegoRepository {
  String identity = 'fictional-A';
  final first = Completer<ProjectionResult>();
  final second = Completer<ProjectionResult>();
  int requests = 0;

  @override
  String? get currentUserId => identity;

  @override
  Future<ProjectionResult> getProjection({
    required String spaceId,
    int horizonMonths = 12,
    List<ProjectionAdjustment> adjustments = const [],
    Set<String> disabledVariableIncomeKeys = const {},
  }) {
    requests++;
    return adjustments.isEmpty ? first.future : second.future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProjectionResult _valid() => ProjectionResult.fromJson({
  'scenario': 'fictional',
  'horizon_months': 12,
  'as_of_date': '2026-09-30',
  'has_projection_inputs': true,
  'months': [{'month': '2026-09-01', 'closing_projected': 1000}],
});

void main() {
  test('account switch after first projection cancels before second request or quota', () async {
    final repo = _ControlledRepo();
    final future = PurchaseScenarioService(repo).simulate(
      spaceId: 'fictional-space', purchaseAmount: 350, installments: 3,
    );
    expect(repo.requests, 1);
    repo.identity = 'fictional-B';
    repo.first.complete(_valid());
    await expectLater(future, throwsA(isA<StateError>()));
    expect(repo.requests, 1);
    // Supabase is NOT initialized in this test: any quota call would throw.
  });

  test('account switch during second projection cancels before quota', () async {
    final repo = _ControlledRepo();
    final future = PurchaseScenarioService(repo).simulate(
      spaceId: 'fictional-space', purchaseAmount: 350, installments: 3,
    );
    repo.first.complete(_valid());
    await Future<void>.delayed(Duration.zero);
    expect(repo.requests, 2);
    repo.identity = 'fictional-B';
    repo.second.complete(_valid());
    await expectLater(future, throwsA(isA<StateError>()));
    expect(repo.requests, 2);
  });
}
