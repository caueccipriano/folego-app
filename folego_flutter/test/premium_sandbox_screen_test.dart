import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:folego/features/premium/premium_sandbox_screen.dart';

void main() {
  Future<void> render(WidgetTester tester, Map<String, dynamic> data) async {
    await tester.pumpWidget(MaterialApp(home: PremiumSandboxScreen(
      client: SupabaseClient('https://example.supabase.co', 'test-public'),
      loadOverride: () async => data,
    )));
    await tester.pumpAndSettle();
  }

  testWidgets('unconfigured backend keeps checkout disabled', (tester) async {
    await render(tester, {'environment': 'sandbox', 'ready': false, 'status': 'none'});
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.text('nenhuma assinatura de teste confirmada'), findsOneWidget);
  });

  testWidgets('pending receipt does not become confirmed', (tester) async {
    await render(tester, {'environment': 'sandbox', 'ready': true,
      'status': 'pending_or_expired', 'paymentConfirmed': false});
    expect(find.text('pagamento pendente ou período encerrado'), findsOneWidget);
    expect(find.text('pagamento fictício confirmado pelo backend'), findsNothing);
  });

  testWidgets('confirmed sandbox receipt disables a second checkout', (tester) async {
    await render(tester, {'environment': 'sandbox', 'ready': true,
      'paymentConfirmed': true, 'paidUntil': '2026-11-14T00:00:00.000Z'});
    expect(find.text('pagamento fictício confirmado pelo backend'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
  });

  testWidgets('production response fails closed in sandbox screen', (tester) async {
    await render(tester, {'environment': 'production', 'ready': true, 'paymentConfirmed': true});
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed, isNull);
    expect(find.text('pagamento fictício confirmado pelo backend'), findsNothing);
  });
}
