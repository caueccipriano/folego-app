import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/l10n/app_localizations.dart';

import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/features/auth/auth_widgets.dart';

void main() {
  testWidgets('troca entre login e cadastro dispara callback', (tester) async {
    var switched = false;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AuthModeSwitch(
            isSignUp: false,
            onPressed: () => switched = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('Criar conta'));
    expect(switched, isTrue);
  });

  testWidgets('campo de senha alterna mostrar e ocultar', (tester) async {
    final controller = TextEditingController(text: 'segredo');
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: _PasswordHarness(controller: controller),
        ),
      ),
    );

    expect(find.byIcon(AppIcons.eye), findsOneWidget);
    await tester.tap(find.byIcon(AppIcons.eye));
    await tester.pump();
    expect(find.byIcon(AppIcons.eyeOff), findsOneWidget);
  });

  testWidgets(
    'submit fica bloqueado e mantém feedback durante loading',
    (tester) async {
      var calls = 0;
      await tester.pumpWidget(
        MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: AuthSubmitButton(
              label: 'Entrando...',
              loading: true,
              onPressed: () => calls++,
            ),
          ),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.tap(find.byType(FilledButton));
      await tester.pump();
      expect(calls, 0);
      expect(find.text('Entrando...'), findsOneWidget);
    },
  );
}

class _PasswordHarness extends StatefulWidget {
  const _PasswordHarness({required this.controller});

  final TextEditingController controller;

  @override
  State<_PasswordHarness> createState() => _PasswordHarnessState();
}

class _PasswordHarnessState extends State<_PasswordHarness> {
  bool obscure = true;

  @override
  Widget build(BuildContext context) {
    return AuthTextField(
      controller: widget.controller,
      label: 'Senha',
      obscureText: obscure,
      onToggleObscure: () => setState(() => obscure = !obscure),
    );
  }
}
