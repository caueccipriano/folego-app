import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/more_tools_sheet.dart';
import 'package:folego/shared/widgets/folego_glass_surface.dart';
import 'package:folego/shared/widgets/liquid_glass_navigation_bar.dart';

void main() {
  for (final brightness in [Brightness.light, Brightness.dark]) {
    testWidgets('frosted surface renders in $brightness', (tester) async {
      BoxDecoration? decoration;
      await tester.pumpWidget(MaterialApp(
        theme: ThemeData(brightness: brightness),
        home: Scaffold(body: Builder(builder: (context) {
          decoration = FolegoGlassSurface.decorationFor(context, radius: 23);
          return const FolegoGlassSurface(
            child: SizedBox(width: 130, height: 50, child: Text('fôlego')),
          );
        })),
      ));
      expect(decoration!.gradient, isA<LinearGradient>());
      expect(decoration!.borderRadius, BorderRadius.circular(23));
      expect(decoration!.boxShadow, isNotEmpty);
      final strong = FolegoGlassSurface.decorationFor(
        tester.element(find.text('fôlego')), radius: 23, prominent: true);
      final regularColors = (decoration!.gradient! as LinearGradient).colors;
      final strongColors = (strong.gradient! as LinearGradient).colors;
      // The user should actually see a stronger tone and a lifted capsule.
      expect(strongColors.length, greaterThan(regularColors.length));
      expect(strongColors.first, isNot(strongColors.last));
      expect(strong.boxShadow!.first.blurRadius,
          greaterThan(decoration!.boxShadow!.first.blurRadius));
      expect(find.text('fôlego'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('high contrast uses opaque accessible fallback', (tester) async {
    BoxDecoration? decoration;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: Scaffold(body: Builder(builder: (context) {
          decoration = FolegoGlassSurface.decorationFor(context);
          return const FolegoGlassSurface(child: Text('visível'));
        })),
      ),
    ));
    expect(decoration!.gradient, isNull);
    expect(decoration!.color, isNotNull);
    final highContrastGlass = FolegoGlassSurface.decorationFor(
      tester.element(find.text('visível')), prominent: true);
    expect(highContrastGlass.gradient, isNull);
    expect(highContrastGlass.color, isNotNull);
    expect(find.text('visível'), findsOneWidget);
  });

  for (final width in [320.0, 390.0]) {
    testWidgets('dock fits $width and keeps all four hit targets', (tester) async {
      tester.view.physicalSize = Size(width, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final taps = <int>[];
      var toolsTaps = 0;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: Column(children: [
            const Spacer(),
            LiquidGlassNavigationBar(
              selectedIndex: 0,
              onDestinationSelected: taps.add,
              onOpenTools: () => toolsTaps++,
            ),
          ]),
        ),
      ));
      expect(find.byType(FolegoGlassSurface), findsOneWidget);
      expect(tester.widget<FolegoGlassSurface>(
        find.byType(FolegoGlassSurface)).prominent, isTrue);
      expect(find.byKey(const ValueKey('mobile-liquid-nav')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('mobile-nav-destination-1')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('mobile-tools-button')));
      await tester.pump();
      expect(taps, [1]);
      expect(toolsTaps, 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('floating tools still open their original destinations',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final tapped = <int>[];
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Align(
        alignment: Alignment.bottomCenter,
        child: MoreToolsSheet(onSelected: tapped.add),
      )),
    ));
    expect(find.byType(FolegoGlassSurface), findsNWidgets(5));
    expect(find.byKey(const ValueKey('tools-compact-grid')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('tools-wallet')));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('tools-goals')));
    await tester.pump();
    expect(tapped, [0, 1]);
    expect(tester.takeException(), isNull);
  });
}
