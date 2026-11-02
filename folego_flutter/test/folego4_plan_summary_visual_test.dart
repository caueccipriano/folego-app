import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File('lib/features/plan/plan_screen_web2.dart')
      .readAsStringSync();

  test('Plan summary has two readable metrics and a separate usage badge', () {
    final summary = source
        .split('Widget _buildSummary(Brightness brightness) {')
        .last
        .split('Widget _buildCategories(Brightness brightness) {')
        .first;

    expect(summary, contains("ValueKey('plan-summary')"));
    expect(summary, contains("ValueKey('plan-summary-featured-amount')"));
    expect(summary, contains("label: 'planejado'"));
    expect(summary, contains("label: 'gastos + dívidas pagas'"));
    expect(summary, isNot(contains("label: 'consumido'")));
    expect(summary, contains("ValueKey('plan-summary-usage-percentage')"));
    expect(summary, contains("ValueKey('plan-summary-usage-progress')"));
    expect(summary, contains("_showPlanMetricExplanation('percent')"));
    expect(summary, contains('summary.usageRatio.clamp(0.0, 1.0)'));
    expect(summary, contains('Formatters.money(summary.remainingAmount.abs())'));
    expect(summary, contains('não é saldo em conta'));
  });

  test('Metric tiles do not force three minimum widths on mobile', () {
    final tile = source
        .split('class _Metric extends StatelessWidget {')
        .last
        .split('class _ScopeChoice extends StatelessWidget {')
        .first;
    expect(tile, contains('BoxConstraints(minHeight: 76)'));
    expect(tile, isNot(contains('minWidth: 118')));
    expect(tile, contains('AppTypography.money('));
    expect(tile, contains('onTap: onTap'));
  });
}
