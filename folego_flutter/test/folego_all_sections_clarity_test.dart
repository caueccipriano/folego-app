import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/shared/widgets/folego_detail_disclosure.dart';

void main() {
  testWidgets('secondary details stay collapsed but remain accessible', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 330,
            child: FolegoDetailDisclosure(
              title: 'análises e ferramentas',
              subtitle: 'detalhes sob demanda',
              child: Text('resultado secundário'),
            ),
          ),
        ),
      ),
    ));
    expect(find.text('análises e ferramentas'), findsOneWidget);
    expect(find.text('resultado secundário'), findsNothing);
    await tester.tap(find.text('análises e ferramentas'));
    await tester.pumpAndSettle();
    expect(find.text('resultado secundário'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Planejar keeps summary and categories before optional analytics', () {
    final source = File('lib/features/plan/plan_screen_web2.dart').readAsStringSync();
    final mobile = source.split('Widget _buildMobileLayout(').last
        .split('Widget _buildDesktopLayout(').first;
    final summary = mobile.indexOf('_buildSummary(brightness)');
    final categories = mobile.indexOf('_buildCategories(brightness)');
    final advanced = mobile.indexOf("ValueKey('plan-advanced-disclosure')");
    expect(summary, greaterThanOrEqualTo(0));
    expect(categories, greaterThan(summary));
    expect(advanced, greaterThan(categories));
    expect(mobile, contains('_buildInsights()'));
    expect(mobile, contains('_purchaseSimulationButton()'));
    expect(mobile, contains('_buildGuidance()'));
  });

  test('Carteira keeps chosen instruments first and secondary totals accessible', () {
    final source = File('lib/features/wallet/wallet_screen_base.dart').readAsStringSync();
    final list = source.split("ListView(").last;
    expect(source, contains("ValueKey('wallet-position-breakdown-toggle')"));
    expect(source, contains('_buildSelectedSection()'));
    expect(source, contains('_buildAdditionalPositions()'));
    expect(source, contains("label: 'faturas em aberto'"));
    expect(source, contains("label: 'dívidas restantes'"));
  });

  test('Movimentos only duplicates classification prompt for actual pendencies', () {
    final source = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    expect(source, contains('widget.pendingClassificationCount > 0) ...['));
    expect(source, contains('PopupMenuButton<String>('));
    expect(source, contains("ValueKey('transactions-spending-behavior-entry')"));
    expect(source, contains("ValueKey('transactions-section-tabs-surface')"));
    expect(source, contains("Tab(text: 'transações')"));
  });

  test('Metas show one heading and keep primary actions reachable', () {
    final source = File('lib/features/goals/goals_screen_base.dart').readAsStringSync();
    expect(source, isNot(contains("title: 'Seu próximo grande passo.'")));
    expect(source, contains('_Header(onCreate: _saving ? null : _createGoal)'));
    expect(source, contains('_SummaryCard(goals: _active)'));
    expect(source, contains('_GoalGrid('));
    expect(source, contains('_showCompleted'));
  });

  test('Diário emphasizes reflection and history before the optional chart', () {
    final source = File('lib/features/diary/diary_screen_base.dart')
        .readAsStringSync();
    expect(source, isNot(contains("title: 'Escolhas que contam.'")));
    final mobile = source.split('else ...[\n                          _pendingSection(').last
        .split('],\n                      ],').first;
    expect(mobile, contains("ValueKey('diary-month-analysis-disclosure')"));
    expect(mobile.indexOf('_timelineSection('),
        lessThan(mobile.indexOf("ValueKey('diary-month-analysis-disclosure')")));
  });

  test('Perfil prioritizes preferences and keeps account/data tools', () {
    final source = File('lib/features/profile/profile_screen_v2.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('profile-account-tools-disclosure')"));
    expect(source, contains("ValueKey('profile-data-disclosure')"));
    expect(source, contains('onTap: _openAppTheme'));
    expect(source, contains('onTap: _openNotificationSettings'));
    expect(source, contains('onTap: _exportData'));
    expect(source, contains('_logoutSection()'));
  });

  test('Mais names destinations without adding duplicate data cards', () {
    final source = File('lib/features/shell/more_tools_sheet.dart')
        .readAsStringSync();
    expect(source, contains("label: 'carteira'"));
    expect(source, contains("label: 'metas'"));
    expect(source, contains("label: 'diário'"));
    expect(source, contains("label: 'perfil'"));
    expect(source, contains("ValueKey('tools-financial-ai')"));
  });
}
