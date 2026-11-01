import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/shared/widgets/activity_inbox_bell.dart';

class _StubRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _bell(int unread, {VoidCallback? onOpen}) => MaterialApp(
  home: Scaffold(
    body: ActivityInboxBell(
      repository: _StubRepository(),
      spaceId: 'test-space',
      authenticatedUserId: () => 'test-user',
      unreadLoader: (_) async => unread,
      onOpen: (_) async => onOpen?.call(),
    ),
  ),
);

void main() {
  testWidgets('without unread notifications the badge stays hidden', (tester) async {
    await tester.pumpWidget(_bell(0));
    await tester.pump();
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isFalse);
    expect(find.byTooltip('notificações · 0 não lidas'), findsOneWidget);
  });

  testWidgets('small unread counts remain informative', (tester) async {
    await tester.pumpWidget(_bell(7));
    await tester.pump();
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(badge.label, isA<Text>());
    expect((badge.label! as Text).data, '7');
    expect(find.byTooltip('notificações · 7 não lidas'), findsOneWidget);
  });

  testWidgets('large backlog is a dot, not a noisy 99+ badge', (tester) async {
    var opened = 0;
    await tester.pumpWidget(_bell(99, onOpen: () => opened++));
    await tester.pump();
    final badge = tester.widget<Badge>(find.byType(Badge));
    expect(badge.isLabelVisible, isTrue);
    expect(badge.label, isNull);
    expect(find.text('99+'), findsNothing);
    expect(find.byTooltip('notificações · 99 não lidas'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('activity-inbox-bell')));
    await tester.pump();
    expect(opened, 1);
  });
}
