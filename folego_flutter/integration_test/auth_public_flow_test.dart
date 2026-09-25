import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/features/auth/auth_screen.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpAuthAt(
    WidgetTester tester, {
    required Size size,
  }) async {
    SharedPreferences.setMockInitialValues({});
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(() {
      tester.view.resetDevicePixelRatio();
      tester.view.resetPhysicalSize();
    });

    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_folego_integration_test',
    );
    addTearDown(client.dispose);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: AuthScreen(client: client),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Future<void> exercisePublicAuthFlow(WidgetTester tester) async {
    expect(find.text('Bom te ver de novo.'), findsOneWidget);
    expect(find.text('Esqueci minha senha'), findsOneWidget);

    await tester.tap(find.text('Criar conta').last);
    await tester.pumpAndSettle();
    expect(find.text('Crie seu espaço.'), findsOneWidget);
    expect(find.text('Confirmar e-mail'), findsOneWidget);
    expect(find.text('Confirmar senha'), findsOneWidget);

    await tester.tap(find.text('Entrar').last);
    await tester.pumpAndSettle();
    expect(find.text('Bom te ver de novo.'), findsOneWidget);

    await tester.tap(find.text('Esqueci minha senha'));
    await tester.pumpAndSettle();
    expect(find.text('Recupere seu acesso.'), findsOneWidget);
    expect(find.text('Enviar instruções'), findsOneWidget);

    await tester.tap(find.text('Voltar para entrar'));
    await tester.pumpAndSettle();
    expect(find.text('Bom te ver de novo.'), findsOneWidget);

    expect(tester.takeException(), isNull);
  }

  testWidgets('public auth flow survives iPhone-sized viewport', (tester) async {
    await pumpAuthAt(tester, size: const Size(393, 852));
    await exercisePublicAuthFlow(tester);
  });

  testWidgets('public auth flow survives compact Android viewport', (tester) async {
    await pumpAuthAt(tester, size: const Size(360, 800));
    await exercisePublicAuthFlow(tester);
  });
}
