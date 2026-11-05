import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/shared/widgets/signature_feature_hero.dart';
import 'package:folego/data/models/financial_goal.dart';
import 'package:folego/features/goals/goals_widgets.dart';
import 'package:folego/shared/widgets/folego_ambient_backdrop.dart';
import 'package:folego/shared/widgets/folego_glass_surface.dart';

void main() {
  test('Fluxo palette uses accessible neutral surfaces in both themes', () {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      final tokens = FolegoColorTokens.fromId('fluxo', brightness);
      expect(FolegoColorTokens.contrastRatio(
        tokens.textoPrincipal, tokens.superficie), greaterThanOrEqualTo(4.5));
      expect(FolegoColorTokens.contrastRatio(
        tokens.textoSecundario, tokens.superficie), greaterThanOrEqualTo(4.5));
      expect(FolegoColorTokens.contrastRatio(
        tokens.marca, tokens.superficie), greaterThanOrEqualTo(4.5));
      expect(FolegoColorTokens.contrastRatio(
        tokens.marca, tokens.fundo), greaterThanOrEqualTo(4.5));
    }
  });

  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('Fluxo goal cards use flat surfaces and keep tap in $brightness',
        (tester) async {
      final previous = AppColorSelection.selected.value;
      AppColorSelection.choose('fluxo');
      addTearDown(() => AppColorSelection.choose(previous));
      final tokens = FolegoColorTokens.fromId('fluxo', brightness);
      var taps = 0;
      final goal = FinancialGoal(
        id: 'design-check',
        spaceId: 's',
        name: 'Reserva de emergência',
        target: 20000,
        targetDate: DateTime(2027, 12),
        icon: GoalIcon.piggyBank,
        status: GoalStatus.active,
        currentAmount: 1500,
        createdAt: DateTime(2026, 11),
        updatedAt: DateTime(2026, 11),
      );

      await tester.pumpWidget(MaterialApp(
        theme: brightness == Brightness.dark ? AppTheme.dark() : AppTheme.light(),
        home: Scaffold(body: SizedBox(
          width: 350,
          height: 190,
          child: GoalCard(goal: goal, onTap: () => taps++),
        )),
      ));
      await tester.pumpAndSettle();
      final ink = tester.widget<Ink>(find.byType(Ink).first);
      final decoration = ink.decoration! as BoxDecoration;
      expect(decoration.color, tokens.superficie);
      expect(decoration.gradient, isNull);
      expect(find.text('Reserva de emergência'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Reserva de emergência'));
      expect(taps, 1);
    });
  }

  testWidgets('Fluxo headers keep navigation while removing decoration', (tester) async {
    final previous = AppColorSelection.selected.value;
    AppColorSelection.choose('fluxo');
    addTearDown(() => AppColorSelection.choose(previous));

    final tokens = FolegoColorTokens.fromId('fluxo', Brightness.light);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(
        body: SignatureFeatureHero(
          title: 'movimentos',
          eyebrow: 'extrato',
          subtitle: 'seus lançamentos',
          icon: Icons.swap_horiz_rounded,
          compact: true,
        ),
      ),
    ));

    final hero = tester.widget<Container>(
      find.byKey(const ValueKey('signature-feature-hero')),
    );
    expect((hero.decoration! as BoxDecoration).color, tokens.fundo);
    expect(find.text('movimentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Fluxo cards stay neutral and readable', (tester) async {
    final previous = AppColorSelection.selected.value;
    AppColorSelection.choose('fluxo');
    addTearDown(() => AppColorSelection.choose(previous));

    final tokens = FolegoColorTokens.fromId('fluxo', Brightness.light);
    late BoxDecoration decoration;
    await tester.pumpWidget(MaterialApp(
      theme: ThemeData(brightness: Brightness.light, extensions: [tokens]),
      home: Scaffold(body: Builder(builder: (context) {
        decoration = FolegoGlassSurface.decorationFor(context);
        return const FolegoAmbientBackdrop(
          child: FolegoGlassSurface(child: Text('Disponível hoje')),
        );
      })),
    ));

    final gradient = decoration.gradient! as LinearGradient;
    expect(gradient.colors, everyElement(tokens.superficie));
    expect(find.text('Disponível hoje'), findsOneWidget);
    expect(find.byKey(const ValueKey('folego-ambient-backdrop')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
