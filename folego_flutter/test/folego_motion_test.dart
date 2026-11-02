import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/folego_motion.dart';
import 'package:folego/features/goals/goals_widgets.dart';
import 'package:folego/features/shell/more_tools_sheet.dart';

void main() {
  testWidgets('normal motion enables progress tween', (tester) async {
    Duration? duration;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Builder(builder: (context) {
        duration = FolegoMotion.duration(context, milliseconds: 360);
        return const GoalProgressBar(progress: .65);
      })),
    ));
    expect(duration, const Duration(milliseconds: 360));
    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  for (final reduced in [true, false]) {
    testWidgets('goal progress respects reduced motion: $reduced',
        (tester) async {
      Duration? duration;
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: Builder(builder: (context) {
              duration = FolegoMotion.duration(context, milliseconds: 420);
              return const GoalProgressBar(progress: .72);
            }),
          ),
        ),
      ));
      expect(duration,
        reduced ? Duration.zero : const Duration(milliseconds: 420));
      expect(find.byType(TweenAnimationBuilder<double>),
        reduced ? findsNothing : findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('accessibility navigation also disables motion',
      (tester) async {
    bool? enabled;
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: const MediaQueryData(accessibleNavigation: true),
        child: Scaffold(body: Builder(
          builder: (context) {
            enabled = FolegoMotion.enabled(context);
            return const GoalProgressBar(progress: .3);
          },
        )),
      ),
    ));
    expect(enabled, false);
    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
  });

  for (final reduced in [true, false]) {
    testWidgets('tool tile feedback follows motion preference: $reduced',
        (tester) async {
      final selected = <int>[];
      await tester.pumpWidget(MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: reduced),
          child: Scaffold(
            body: MoreToolsSheet(onSelected: selected.add),
          ),
        ),
      ));
      final tile = find.byKey(const ValueKey('tools-wallet'));
      expect(tile, findsOneWidget);
      final hold = await tester.startGesture(tester.getCenter(tile));
      await tester.pump();
      final scale = tester.widget<AnimatedScale>(
        find.byKey(const ValueKey('tool-scale-contas e cartões')));
      expect(scale.scale, reduced ? 1 : .975);
      expect(scale.duration,
        reduced ? Duration.zero : const Duration(milliseconds: 130));
      await hold.up();
      await tester.pumpAndSettle();
      expect(selected, [0]);
      expect(tester.takeException(), isNull);
    });
  }
}
