import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/shared/widgets/signature_feature_hero.dart';

void main() {
  for (final palette in FolegoColorTokens.catalog) {
    for (final brightness in Brightness.values) {
      testWidgets('cabeçalho consistente e clicável: ${palette.id} ${brightness.name}',
          (tester) async {
        final old = AppColorSelection.selected.value;
        AppColorSelection.choose(palette.id);
        addTearDown(() => AppColorSelection.choose(old));

        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var taps = 0;
        final tokens = FolegoColorTokens.fromId(palette.id, brightness);

        await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.dark
              ? AppTheme.dark() : AppTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: SingleChildScrollView(
                  child: SignatureFeatureHero(
                    title: 'meus movimentos',
                    eyebrow: 'um lugar só',
                    subtitle: 'Organize os registros e compromissos.',
                    icon: Icons.receipt_outlined,
                    compact: true,
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      IconButton(
                        key: const ValueKey('feature-head-action'),
                        tooltip: 'importar',
                        onPressed: () => taps++,
                        icon: const Icon(Icons.add_rounded)),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        final finder = find.byKey(const ValueKey('signature-feature-hero'));
        expect(finder, findsOneWidget);
        final hero = tester.widget<AnimatedContainer>(finder);
        final decoration = hero.decoration! as BoxDecoration;
        expect(decoration.color, tokens.superficie);
        expect(decoration.gradient, palette.id == 'ink' ? isNull : isNotNull);
        expect(find.text('meus movimentos'), findsOneWidget);
        expect(find.text('Organize os registros e compromissos.'), findsOneWidget);
        expect(tester.getRect(finder).right, lessThanOrEqualTo(308));
        await tester.tap(find.byKey(const ValueKey('feature-head-action')));
        await tester.pump();
        expect(taps, 1);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
