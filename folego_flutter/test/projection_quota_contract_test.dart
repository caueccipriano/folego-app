import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/models/projection_model.dart';

Map<String, dynamic> _projectionResponse({bool? serverMetered}) => {
  'scenario': 'current',
  'horizon_months': 12,
  'as_of_date': '2026-09-28',
  'opening_balance': 100,
  'has_projection_inputs': true,
  if (serverMetered != null)
    'simulation_quota_enforced': serverMetered,
  'summary': <String, dynamic>{},
  'months': <Object>[],
  'variable_incomes': <Object>[],
};

void main() {
  test('new backend confirms that it already metered a scenario', () {
    final result = ProjectionResult.fromJson(
      _projectionResponse(serverMetered: true),
    );
    expect(result.serverQuotaEnforced, isTrue);
    expect(result.hasProjectionInputs, isTrue);
  });

  test('legacy backend keeps the client quota fallback active', () {
    final result = ProjectionResult.fromJson(_projectionResponse());
    expect(result.serverQuotaEnforced, isFalse);
    expect(
      ProjectionResult.fromJson(
        _projectionResponse(serverMetered: false),
      ).serverQuotaEnforced,
      isFalse,
    );
  });

  test('simulator cannot debit again if backend already charged', () {
    final source = File(
      'lib/core/intelligence/purchase_scenario_service.dart',
    ).readAsStringSync();

    final guard = source.indexOf('if (!withPurchase.serverQuotaEnforced)');
    final legacyQuota = source.indexOf("rpc('consume_free_simulation')");
    expect(guard, greaterThanOrEqualTo(0));
    expect(legacyQuota, greaterThan(guard));
    expect(source, contains('free_simulation_limit_reached'));
    expect(source, contains('on PostgrestException catch (error)'));
  });

  test('server migration gates adjusted RPC before returning results', () {
    final migration = File(
      '../supabase/migrations/20260928174200_atomic_projection_quota.sql',
    ).readAsStringSync();

    expect(migration, contains('private.get_projection_core'));
    expect(migration, contains('REVOKE ALL ON FUNCTION private.get_projection_core'));
    expect(migration, contains("coalesce(cardinality(p_disabled_variable_income_keys), 0) > 0"));
    expect(migration, contains("v_result ->> 'has_projection_inputs'"));
    expect(migration, contains('public.consume_free_simulation()'));
    expect(migration, contains('free_simulation_limit_reached'));
    expect(migration, contains("'{simulation_quota_enforced}'"));

    final debit = migration.indexOf(
      'SELECT quota.allowed, quota.remaining INTO v_allowed, v_remaining',
    );
    final compute = migration.indexOf('v_result := private.get_projection_core(');
    final result = migration.indexOf("'{simulation_quota_enforced}'");
    expect(debit, greaterThanOrEqualTo(0));
    expect(compute, greaterThan(debit));
    expect(result, greaterThan(compute));
    expect(migration, contains('SET used = used - 1'));
    expect(migration, contains('ELSIF v_remaining >= 0'));
    expect(migration, contains('simulation_quota_refund_failed'));
  });
}
