import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/folego_motion.dart';
import 'package:folego/shared/widgets/responsive_navigation_shell.dart';

class _ShellForTest extends StatefulWidget {
  const _ShellForTest({required this.mountCounts});
  final List<int> mountCounts;
  @override
  State<_ShellForTest> createState() => _ShellForTestState();
}

class _ShellForTestState extends State<_ShellForTest> {
  var selected = 0;
  @override
  Widget build(BuildContext context) => ResponsiveNavigationShell(
    selectedIndex: selected,
    onDestinationSelected: (value) => setState(() => selected = value),
    pages: List.generate(5, (i) => _PageForTest(
      key: ValueKey('persistent-page-$i'),
      index: i,
      onMount: () => widget.mountCounts[i]++,
    )),
  );
}

class _PageForTest extends StatefulWidget {
  const _PageForTest({
    super.key,
    required this.index,
    required this.onMount,
  });
  final int index;
  final VoidCallback onMount;
  @override
  State<_PageForTest> createState() => _PageForTestState();
}

class _PageForTestState extends State<_PageForTest> {
  @override
  void initState() {
    super.initState();
    widget.onMount();
  }
  @override
  Widget build(BuildContext context) => Center(
    child: Text('test page ${widget.index}'),
  );
}

void main() {
  for (final reduced in [false, true]) {
    testWidgets('tab fade preserves every mounted page: reduced=$reduced',
        (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final counts = List<int>.filled(5, 0);
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: _ShellForTest(mountCounts: counts),
        ),
      ));
      expect(counts, everyElement(1));
      expect(find.byType(IndexedStack), findsOneWidget);

      await tester.tap(find.byKey(
        const ValueKey('mobile-nav-destination-1')));
      await tester.pump();
      final animation = tester.widget<AnimatedOpacity>(
        find.byKey(const ValueKey('shell-page-transition-1')));
      expect(animation.opacity, 1);
      expect(animation.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 150));
      expect(find.text('test page 1'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(counts, everyElement(1));

      await tester.tap(find.byKey(
        const ValueKey('mobile-nav-destination-0')));
      await tester.pumpAndSettle();
      expect(find.text('test page 0'), findsOneWidget);
      expect(counts, everyElement(1));
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accessible navigation disables tab and sheet motion',
      (tester) async {
    Duration? tabDuration;
    AnimationStyle? sheet;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: Builder(builder: (context) {
          tabDuration = FolegoMotion.duration(context, milliseconds: 150);
          sheet = FolegoMotion.sheetStyle(context);
          return const Scaffold(body: Text('ready'));
        }),
      ),
    ));
    expect(tabDuration, Duration.zero);
    expect(sheet!.duration, Duration.zero);
    expect(sheet!.reverseDuration, Duration.zero);
  });

  testWidgets('sheet uses a compact native entrance and exit',
      (tester) async {
    AnimationStyle? sheet;
    await tester.pumpWidget(MaterialApp(
      home: Builder(builder: (context) {
        sheet = FolegoMotion.sheetStyle(context);
        return const Scaffold(body: Text('ready'));
      }),
    ));
    expect(sheet!.duration, const Duration(milliseconds: 220));
    expect(sheet!.reverseDuration, const Duration(milliseconds: 170));
  });
}
