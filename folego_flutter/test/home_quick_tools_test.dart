import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/home_quick_tools.dart';

void main() {
  testWidgets('search and pending review stay one tap away', (tester) async {
    var searches = 0;
    var reviews = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeQuickTools(
          onSearch: () => searches++,
          onPending: () => reviews++,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('home-global-search')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-pending-center')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-income-setup')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('home-global-search')));
    await tester.tap(find.byKey(const ValueKey('home-pending-center')));
    expect(searches, 1);
    expect(reviews, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('optional setup remains reachable and compact on a phone',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var calls = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HomeQuickTools(
          onSearch: () {},
          onPending: () {},
          onSetup: () => calls++,
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('home-income-setup')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('home-income-setup')));
    expect(calls, 1);
    expect(tester.takeException(), isNull);
  });
}
