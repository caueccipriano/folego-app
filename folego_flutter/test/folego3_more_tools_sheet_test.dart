import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/more_tools_sheet.dart';

void main() {
  testWidgets('More menu shows four concise accessible destinations', (tester) async {
    int? tapped;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MoreToolsSheet(onSelected: (value) => tapped = value)),
    ));
    expect(find.byKey(const ValueKey('tools-compact-grid')), findsOneWidget);
    for (final (index, key) in [
      (0, 'tools-wallet'),
      (1, 'tools-goals'),
      (2, 'tools-diary'),
      (3, 'tools-profile'),
    ]) {
      await tester.tap(find.byKey(ValueKey(key)));
      await tester.pump();
      expect(tapped, index);
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(ListView), findsNothing);
  });

  testWidgets('320-wide mobile menu keeps all targets visible', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MoreToolsSheet(onSelected: (_) {})),
    ));
    final keys = [
      'tools-wallet', 'tools-goals', 'tools-diary', 'tools-profile',
    ];
    for (final key in keys) {
      final rect = tester.getRect(find.byKey(ValueKey(key)));
      expect(rect.width, greaterThan(88));
      expect(rect.height, greaterThanOrEqualTo(96));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(tester.takeException(), isNull);
  });
}
