import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/app_empty_state.dart';
import 'package:folego/shared/widgets/app_loading_state.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [320.0, 390.0, 768.0]) {
      testWidgets('empty card is readable and action stays operable '
          '$brightness at $width', (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var tapped = 0;
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: Scaffold(
            body: SingleChildScrollView(
              child: AppEmptyState(
                icon: Icons.savings_outlined,
                title: 'seu espaço para começar',
                description: 'adicione uma meta quando quiser.',
                action: FilledButton(
                  onPressed: () => tapped++,
                  child: const Text('criar meta'),
                ),
              ),
            ),
          ),
        ));
        expect(find.byKey(const ValueKey('folego-empty-state')),
          findsOneWidget);
        expect(find.text('adicione uma meta quando quiser.'), findsOneWidget);
        await tester.tap(find.text('criar meta'));
        expect(tapped, 1);
        expect(tester.takeException(), isNull);
      });

      testWidgets('loading placeholder has no invented financial amounts '
          '$brightness at $width', (tester) async {
        tester.view.physicalSize = Size(width, 760);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
          theme: ThemeData(brightness: brightness),
          home: const Scaffold(
            body: AppLoadingState(label: 'organizando seu planejamento'),
          ),
        ));
        expect(find.byKey(const ValueKey('folego-loading-skeleton')),
          findsOneWidget);
        expect(find.text('organizando seu planejamento'), findsOneWidget);
        expect(find.textContaining('R\$'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('compact loading remains within a short section',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320, height: 90,
          child: AppLoadingState(
            label: 'organizando suas parcelas', compact: true),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('folego-loading-skeleton')),
      findsNothing);
    expect(find.text('organizando suas parcelas'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading adapts to a height-constrained screen',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: SizedBox(
          width: 320, height: 155,
          child: AppLoadingState(label: 'carregando lançamentos'),
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('folego-loading-skeleton')),
      findsNothing);
    expect(find.text('carregando lançamentos'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
