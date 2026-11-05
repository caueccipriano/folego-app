import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
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
