import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/shell/more_tools_sheet.dart';

void main() {
  Future<void> pumpTools(
    WidgetTester tester, {
    required double width,
    double height = 800,
    double scale = 1,
    required List<int> actions,
  }) async {
    tester.view.physicalSize = Size(width, height);
    tester.view.devicePixelRatio = 1;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(
          size: Size(width, height),
          textScaler: TextScaler.linear(scale),
        ),
        child: Scaffold(
          body: Align(
            alignment: Alignment.bottomCenter,
            child: MoreToolsSheet(onSelected: actions.add),
          ),
        ),
      ),
    ));
  }

  testWidgets('small iPhones show readable tools in a scrollable column',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final actions = <int>[];
    await pumpTools(tester, width: 320, height: 720, actions: actions);
    expect(find.byKey(const ValueKey('tools-single-column')), findsOneWidget);
    expect(find.byKey(const ValueKey('tools-scroll-region')), findsOneWidget);
    final wallet = tester.getRect(find.byKey(const ValueKey('tools-wallet')));
    final goals = tester.getRect(find.byKey(const ValueKey('tools-goals')));
    expect(goals.top, greaterThanOrEqualTo(wallet.bottom));
    await tester.ensureVisible(find.byKey(const ValueKey('tools-financial-ai')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('tools-financial-ai')));
    expect(actions, [4]);
    expect(tester.takeException(), isNull);
  });

  testWidgets('normal phone keeps compact two-by-two tools', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTools(tester, width: 390, height: 844, actions: <int>[]);
    expect(find.byKey(const ValueKey('tools-two-columns')), findsOneWidget);
    final wallet = tester.getRect(find.byKey(const ValueKey('tools-wallet')));
    final goals = tester.getRect(find.byKey(const ValueKey('tools-goals')));
    expect(wallet.top, goals.top);
    expect(goals.left, greaterThan(wallet.right));
    expect(tester.takeException(), isNull);
  });

  testWidgets('large accessibility text expands tools to one column',
      (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpTools(
      tester, width: 390, height: 844, scale: 1.6, actions: <int>[]);
    expect(find.byKey(const ValueKey('tools-single-column')), findsOneWidget);
    final wallet = tester.getRect(find.byKey(const ValueKey('tools-wallet')));
    final goals = tester.getRect(find.byKey(const ValueKey('tools-goals')));
    expect(goals.top, greaterThanOrEqualTo(wallet.bottom));
    expect(tester.takeException(), isNull);
  });
}
