import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/features/profile/account_deletion_error.dart';

void main() {
  test('shared owner receives a precise safe-deletion explanation', () {
    const error = FunctionException(
      status: 409,
      details: <String, dynamic>{
        'error': 'shared_space_requires_resolution',
      },
    );

    final explanation = sharedAccountDeletionErrorMessage(error);
    expect(explanation, isNotNull);
    expect(explanation, contains('espaço financeiro compartilhado'));
    expect(explanation, contains('dados das outras pessoas'));
    expect(explanation, contains('suporte'));
  });

  test('unrelated 409 responses are not mislabeled as shared-owner errors', () {
    expect(
      sharedAccountDeletionErrorMessage(
        const FunctionException(
          status: 409,
          details: <String, dynamic>{'error': 'other_conflict'},
        ),
      ),
      isNull,
    );
  });

  test('service failures retain normal error handling', () {
    expect(
      sharedAccountDeletionErrorMessage(
        const FunctionException(
          status: 503,
          details: <String, dynamic>{
            'error': 'shared_space_check_unavailable',
          },
        ),
      ),
      isNull,
    );
    expect(sharedAccountDeletionErrorMessage(StateError('offline')), isNull);
  });

  test('client shows a warning before confirming deletion', () {
    final source = File(
      'lib/features/profile/profile_screen_v2.dart',
    ).readAsStringSync();
    expect(source, contains('sharedAccountDeletionErrorMessage(error)'));
    expect(source, contains('a exclusão será bloqueada'));
    expect(source, contains('a titularidade seja resolvida'));
  });

  test('Edge preflight and database guard prevent old partial cleanup', () {
    final endpoint = File(
      '../supabase/functions/delete-account/index.ts',
    ).readAsStringSync();
    final sql = File(
      '../supabase/migrations/'
      '20260928231500_guard_shared_owner_account_deletion.sql',
    ).readAsStringSync();

    expect(endpoint, contains('accountDeletionPreflight'));
    expect(endpoint, contains('financial_spaces!inner(owner_id)'));
    expect(endpoint, contains('.neq("user_id", user.id)'));
    expect(endpoint, contains('shared_space_requires_resolution'));
    expect(endpoint, isNot(contains('.from("automation_rules")')));
    expect(sql, contains('BEFORE DELETE ON auth.users'));
    expect(sql, contains('shared_space_owner_deletion_requires_resolution'));
    expect(sql, contains('DELETE FROM public.automation_rules ar'));
  });
}
