import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_typography.dart';
import 'package:folego/features/shell/more_tools_sheet.dart';
import 'package:folego/shared/widgets/folego_glass_surface.dart';

void _expectAa(Color text, Color background, String description) {
  final ratio = FolegoColorTokens.contrastRatio(text, background);
  expect(ratio, greaterThanOrEqualTo(4.5),
      reason: '$description has ${ratio.toStringAsFixed(2)}:1 (requires 4.5:1)');
}

void main() {
  test('all selected palettes keep normal text readable in both modes', () {
    for (final palette in FolegoColorTokens.catalog) {
      for (final mode in [Brightness.light, Brightness.dark]) {
        final tokens = FolegoColorTokens.fromId(palette.id, mode);
        for (final item in <(String, Color)>[
          ('primary', tokens.textoPrincipal),
          ('secondary', tokens.textoSecundario),
          ('brand', tokens.marca),
        ]) {
          _expectAa(item.$2, tokens.superficie,
              '${palette.id} $mode ${item.$1} on card');
          _expectAa(item.$2, tokens.fundo,
              '${palette.id} $mode ${item.$1} on background');
        }
        _expectAa(tokens.marcaHeroSobre, tokens.marcaHero,
            '${palette.id} $mode hero label');
        _expectAa(tokens.acaoHero, tokens.marcaHero,
            '${palette.id} $mode hero amount');
        _expectAa(tokens.acaoSobre, tokens.acao,
            '${palette.id} $mode action button');
      }
    }
  });

  test('display, card titles, labels and monetary values follow one font contract', () {
    final base = ThemeData.light().textTheme;
    final theme = AppTypography.textTheme(base,
        primaryText: Colors.black, secondaryText: Colors.black);
    expect(theme.displayLarge!.fontFamily, 'Unbounded');
    expect(theme.headlineMedium!.fontFamily, 'Unbounded');
    expect(theme.titleLarge!.fontFamily, 'Manrope');
    expect(theme.bodyMedium!.fontFamily, 'Manrope');
    expect(theme.labelMedium!.fontFamily, 'Manrope');
  });

  testWidgets('amount typography is Manrope with tabular figures', (tester) async {
    late TextStyle amount;
    late TextStyle card;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        amount = AppTypography.money(context, fontSize: 17);
        card = AppTypography.cardTitle(context, fontSize: 14);
        return const Text('estilos');
      })),
    ));
    expect(amount.fontFamily, 'Manrope');
    expect(amount.fontSize, 17);
    expect(amount.fontFeatures, isNotEmpty);
    expect(card.fontFamily, 'Manrope');
    expect(card.fontWeight, FontWeight.w700);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('floating cards keep readable titles and no overflow at $width',
        (tester) async {
      tester.view.physicalSize = Size(width, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final destinations = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Align(
          alignment: Alignment.bottomCenter,
          child: MoreToolsSheet(onSelected: destinations.add),
        )),
      ));
      final title = tester.widget<Text>(find.text('contas e cartões'));
      expect(title.style!.fontFamily, 'Manrope');
      expect(title.style!.fontSize, 14);
      final caption = tester.widget<Text>(find.text('faturas e dívidas'));
      expect(caption.style!.fontSize, greaterThanOrEqualTo(12));
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('metas'));
      await tester.pump();
      expect(destinations, [1]);
    });
  }

  testWidgets('glass card primary text has AA contrast against its palette',
      (tester) async {
    for (final palette in FolegoColorTokens.catalog) {
      for (final mode in [Brightness.light, Brightness.dark]) {
        final colors = FolegoColorTokens.fromId(palette.id, mode);
        late BoxDecoration decoration;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: mode, extensions: [colors]),
          home: Scaffold(body: Builder(builder: (context) {
            decoration = FolegoGlassSurface.decorationFor(context,
                prominent: true);
            return const Text('card');
          })),
        ));
        for (final bg in (decoration.gradient! as LinearGradient).colors) {
          _expectAa(colors.textoPrincipal, bg,
              '${palette.id} $mode primary on prominent glass');
        }
      }
    }
  });
}
