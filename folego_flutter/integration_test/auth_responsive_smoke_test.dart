import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:folego/core/layout/app_breakpoints.dart';
import 'package:folego/features/auth/auth_widgets.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpHarness(
    WidgetTester tester, {
    required Size size,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: _AuthIntegrationHarness(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('compact auth controls stay usable at 390x844', (tester) async {
    await pumpHarness(tester, size: const Size(390, 844));

    expect(AppBreakpoints.fromWidth(390), AppLayoutSize.compact);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(find.text('Criar conta'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Criar conta'));
    await tester.pumpAndSettle();

    expect(find.text('Criar conta'), findsOneWidget);
    expect(find.text('Já tenho conta'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('auth controls stay usable at 1440x900', (tester) async {
    await pumpHarness(tester, size: const Size(1440, 900));

    expect(AppBreakpoints.fromWidth(1440), AppLayoutSize.wide);
    expect(find.text('E-mail'), findsOneWidget);
    expect(find.text('Senha'), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _AuthIntegrationHarness extends StatefulWidget {
  const _AuthIntegrationHarness();

  @override
  State<_AuthIntegrationHarness> createState() => _AuthIntegrationHarnessState();
}

class _AuthIntegrationHarnessState extends State<_AuthIntegrationHarness> {
  final email = TextEditingController();
  final password = TextEditingController();
  bool signUp = false;
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AuthTextField(
                    controller: email,
                    label: 'E-mail',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AuthTextField(
                    controller: password,
                    label: 'Senha',
                    obscureText: obscure,
                    onToggleObscure: () => setState(() => obscure = !obscure),
                  ),
                  const SizedBox(height: 16),
                  AuthSubmitButton(
                    label: signUp ? 'Criar conta' : 'Entrar',
                    loading: false,
                    onPressed: () {},
                  ),
                  const SizedBox(height: 8),
                  AuthModeSwitch(
                    isSignUp: signUp,
                    onPressed: () => setState(() => signUp = !signUp),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
