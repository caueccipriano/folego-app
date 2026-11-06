import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:folego/core/theme/app_color_tokens.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/shared/widgets/liquid_glass_navigation_bar.dart';
import 'package:folego/shared/widgets/signature_feature_hero.dart';

void main() {
  for (final width in [320.0, 390.0]) {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      testWidgets('Fluxo native dock remains tappable on $width $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppColorSelection.choose('fluxo');
        addTearDown(() => AppColorSelection.choose('fluxo'));

        int? openedTab;
        var toolsOpened = false;
        await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light() : AppTheme.dark(),
          home: Scaffold(
            body: const Center(child: Text('conteúdo')),
            bottomNavigationBar: LiquidGlassNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: (index) => openedTab = index,
              onOpenTools: () => toolsOpened = true,
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byKey(const ValueKey('flow-native-nav-surface')),
            findsOneWidget);
        expect(find.text('planejar'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('mobile-nav-destination-2')));
        expect(openedTab, 2);
        await tester.tap(find.byKey(const ValueKey('mobile-tools-button')));
        expect(toolsOpened, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Fluxo section header stays readable on $width $brightness',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        AppColorSelection.choose('fluxo');
        addTearDown(() => AppColorSelection.choose('fluxo'));

        var tapped = false;
        await tester.pumpWidget(MaterialApp(
          theme: brightness == Brightness.light
              ? AppTheme.light() : AppTheme.dark(),
          home: Scaffold(
            body: SafeArea(child: SignatureFeatureHero(
              title: 'movimentos',
              eyebrow: 'Seu dinheiro',
              subtitle: 'Histórico e categorias',
              icon: Icons.receipt_long_outlined,
              compact: true,
              trailing: IconButton(
                tooltip: 'filtrar movimentos',
                onPressed: () => tapped = true,
                icon: const Icon(Icons.filter_list_rounded),
              ),
            )),
          ),
        ));
        await tester.pumpAndSettle();
        expect(find.text('movimentos'), findsOneWidget);
        await tester.tap(find.byTooltip('filtrar movimentos'));
        expect(tapped, isTrue);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('other palettes keep their existing glass dock',
      (tester) async {
    AppColorSelection.choose('folego');
    addTearDown(() => AppColorSelection.choose('fluxo'));
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        bottomNavigationBar: LiquidGlassNavigationBar(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
        ),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('flow-native-nav-surface')),
        findsNothing);
    expect(find.byKey(const ValueKey('mobile-nav-destination-0')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
