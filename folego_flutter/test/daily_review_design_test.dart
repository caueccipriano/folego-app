import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/daily_review_card.dart';

void main() {
  Widget homePrompt({
    required bool completed,
    required int pending,
    required VoidCallback onTap,
    Brightness brightness = Brightness.light,
    int? days,
  }) {
    return MaterialApp(
      theme: ThemeData(brightness: brightness),
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320,
            child: DailyReviewPrompt(
              complete: completed,
              pending: pending,
              days: days ?? (completed ? 3 : 0),
              loading: false,
              pace: const {'status': 'review_needed'},
              onTap: onTap,
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('check-in stays compact with many unclassified transactions', (tester) async {
    var tapped = false;
    await tester.pumpWidget(homePrompt(
      completed: false, pending: 34, onTap: () => tapped = true,
    ));
    await tester.pumpAndSettle();

    expect(find.text('seu check-in'), findsOneWidget);
    expect(find.textContaining('duas conferências rápidas'), findsOneWidget);
    expect(find.byType(Card), findsNothing);
    expect(tester.getSize(find.byKey(const ValueKey('home-daily-review-prompt'))).height, lessThan(100));
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('home-daily-review-prompt')));
    expect(tapped, isTrue);
  });

  testWidgets('completed check-in respects dark mode and short action copy', (tester) async {
    await tester.pumpWidget(homePrompt(
      completed: true, pending: 0, onTap: () {},
      brightness: Brightness.dark,
    ));
    await tester.pumpAndSettle();
    expect(find.text('check-in concluído'), findsOneWidget);
    expect(find.text('ver'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('encourages habit using real weekly review days', (tester) async {
    await tester.pumpWidget(homePrompt(
      completed: false, pending: 34, days: 4, onTap: () {},
    ));
    await tester.pumpAndSettle();
    expect(find.textContaining('4 dos últimos 7 dias revisados'), findsOneWidget);
  });

  test('spending pace copy does not claim risk when classification is pending', () {
    expect(
      dailyReviewPaceMessage(const {'status': 'review_needed'}),
      contains('classificar'),
    );
    expect(
      dailyReviewPaceMessage(const {'status': 'at_risk',
        'average_per_day': 28,
        'daily_limit': 17,
      }),
      contains('limite'),
    );
  });
}
