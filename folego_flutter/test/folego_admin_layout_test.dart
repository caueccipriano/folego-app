import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/features/profile/folego_admin_screen.dart';

void main() {
  final client = SupabaseClient('https://example.supabase.co', 'example-anon-key');

  Map<String, dynamic> synthetic() => {
    'metrics': {
      'registered': 6,
      'confirmed': 5,
      'logged_in_30d': 3,
      'users_with_transactions_30d': 2,
      'completed_intro': 4,
      'users_with_account': 4,
      'users_with_transactions': 3,
      'lifetime_premium': 5,
      'feedback_count': 1,
      'sandbox_subscription_records': 0,
      'production_subscription_records': 0,
    },
    'users': [
      {
        'name': 'Ana',
        'email': 'ana@example.test',
        'created_at': '2026-10-01T10:00:00Z',
        'last_login': '2026-10-14T10:00:00Z',
        'email_confirmed': true,
        'lifetime_premium': true,
      },
      {
        'name': 'Bia',
        'email': 'bia@example.test',
        'email_confirmed': false,
        'lifetime_premium': false,
      },
    ],
    'feedback': [
      {'kind': 'idea', 'message': 'gostei da tela inicial',
       'name': 'Ana', 'created_at': '2026-10-14T10:00:00Z'},
    ],
  };

  testWidgets('admin overview separates usage from subscription records',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FolegoAdminScreen(
      client: client,
      loadDashboard: () async => synthetic(),
    )));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('folego-admin-dashboard')), findsOneWidget);
    expect(find.text('seu produto, de perto.'), findsOneWidget);
    expect(find.text('cadastrados'), findsOneWidget);
    expect(find.text('jornada dos usuários'), findsOneWidget);
    expect(find.text('Asaas produção · registros'), findsOneWidget);
    expect(find.textContaining('registros de assinatura não comprovam'),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin user search and feedback stay in distinct tabs',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FolegoAdminScreen(
      client: client,
      loadDashboard: () async => synthetic(),
    )));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('admin-tab-1')));
    await tester.pumpAndSettle();
    expect(find.text('Ana'), findsOneWidget);
    expect(find.text('Bia'), findsOneWidget);

    await tester.enterText(
        find.byKey(const ValueKey('admin-user-search')), 'bia');
    await tester.pumpAndSettle();
    expect(find.text('Bia'), findsOneWidget);
    expect(find.text('Ana'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('admin-tab-2')));
    await tester.pumpAndSettle();
    expect(find.text('gostei da tela inicial'), findsOneWidget);
    expect(find.text('Asaas produção · registros'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin denied RPC never renders private cached data',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: FolegoAdminScreen(
      client: client,
      loadDashboard: () async => throw Exception('not authorized'),
    )));
    await tester.pumpAndSettle();
    expect(find.textContaining('não foi possível consultar o painel'),
        findsOneWidget);
    expect(find.byKey(const ValueKey('admin-user-search')), findsNothing);
    expect(find.text('cadastrados'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
