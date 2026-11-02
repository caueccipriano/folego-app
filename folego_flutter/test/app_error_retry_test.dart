import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/app_error_state.dart';

void main() {
  Widget screen(Future<void> Function() retry, {Brightness mode = Brightness.light}) =>
      MaterialApp(
        theme: ThemeData(brightness: mode),
        home: Scaffold(body: SingleChildScrollView(
          child: AppErrorState(
            title: 'não foi possível atualizar a carteira',
            description: 'Confira os dados mais tarde ou tente novamente.',
            onRetry: retry,
          ),
        )),
      );

  testWidgets('double tap does not start duplicate requests', (tester) async {
    final pending = Completer<void>();
    var attempts = 0;
    await tester.pumpWidget(screen(() {
      attempts++;
      return pending.future;
    }));
    final button = find.byKey(const ValueKey('folego-error-retry'));
    await tester.tap(button);
    await tester.pump();
    expect(attempts, 1);
    expect(find.text('atualizando...'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    // Even if a second click is attempted, the widget cannot start a second call.
    await tester.tap(button);
    await tester.pump();
    expect(attempts, 1);
    pending.complete();
    await tester.pump();
    expect(find.text('tentar novamente'), findsOneWidget);
    expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed retry shows friendly message and can be repeated',
      (tester) async {
    var attempts = 0;
    await tester.pumpWidget(screen(() async {
      attempts++;
      throw StateError('private database details should never appear');
    }));
    final button = find.byKey(const ValueKey('folego-error-retry'));
    await tester.tap(button);
    await tester.pump();
    expect(find.byKey(const ValueKey('folego-retry-feedback')),
      findsOneWidget);
    expect(find.textContaining('private database'), findsNothing);
    await tester.tap(button);
    await tester.pump();
    expect(attempts, 2);
    expect(tester.takeException(), isNull);
  });

  for (final brightness in Brightness.values) {
    testWidgets('retry remains usable on small iPhone in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var attempts = 0;
      await tester.pumpWidget(screen(() async { attempts++; },
        mode: brightness));
      final button = find.byKey(const ValueKey('folego-error-retry'));
      expect(tester.getSize(button).height, greaterThanOrEqualTo(44));
      await tester.tap(button);
      await tester.pump();
      expect(attempts, 1);
      expect(tester.takeException(), isNull);
    });
  }
}
