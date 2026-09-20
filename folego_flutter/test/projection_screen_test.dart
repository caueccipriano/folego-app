import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_theme.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/projection_model.dart';
import 'package:folego/data/models/recurring_item.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/plan/projection_screen.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
  });

  for (final mode in <ThemeMode>[ThemeMode.light, ThemeMode.dark]) {
    testWidgets('projection renders core mobile hierarchy in $mode', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: mode,
          home: ProjectionScreen(
            repository: _ProjectionRepository(),
            spaceId: 'space',
            onBack: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('projeção'), findsWidgets);
      expect(find.text('atual'), findsOneWidget);
      expect(find.text('seu futuro financeiro'), findsOneWidget);
      expect(find.text('12 meses'), findsOneWidget);
      expect(find.byKey(const ValueKey('projection-hero')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('projection-simulate-change')),
        findsOneWidget,
      );

      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('desktop category view exposes month matrix', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProjectionScreen(
          repository: _ProjectionRepository(),
          spaceId: 'space',
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('categorias'));
    await tester.pumpAndSettle();

    expect(find.byType(DataTable), findsOneWidget);
    expect(find.text('Alimentação'), findsWidgets);
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('SET'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(DataTable),
        matching: find.text('OUT'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('simulation sheet states that it does not create a launch', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: ProjectionScreen(
          repository: _ProjectionRepository(),
          spaceId: 'space',
          onBack: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('projection-simulate-change')),
    );
    await tester.pumpAndSettle();

    expect(find.text('simular mudança'), findsNWidgets(2));
    expect(
      find.text(
        'nada aqui vira lançamento. primeiro você vê o efeito no futuro',
      ),
      findsOneWidget,
    );
    expect(find.text('novo carro'), findsOneWidget);
    expect(find.text('novo salário'), findsOneWidget);
    expect(find.text('cancelar assinatura'), findsOneWidget);
    expect(find.text('reduzir categoria'), findsOneWidget);
  });
}

class _ProjectionRepository implements FolegoRepository {
  @override
  Future<ProjectionResult> getProjection({
    required String spaceId,
    int horizonMonths = 12,
    List<ProjectionAdjustment> adjustments = const [],
    Set<String> disabledVariableIncomeKeys = const {},
  }) async {
    final delta = adjustments.isEmpty ? 0.0 : 1200.0;
    return _projection(horizonMonths, delta);
  }

  @override
  Future<List<RecurringItem>> listRecurringItems(String spaceId) async =>
      const [];

  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async =>
      const [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ProjectionResult _projection(int horizon, double delta) {
  final months = <ProjectionMonth>[
    ProjectionMonth(
      month: DateTime(2026, 9),
      openingBalance: 1000,
      guaranteedIncome: 5000,
      variableIncome: 0,
      income: 5000,
      directExpenses: 3000,
      recurringExpenses: 500,
      cardInstallments: 700,
      debts: 200,
      reserveTransfers: 300,
      investments: 0,
      otherInflows: 0,
      otherOutflows: 0,
      plannedMovements: 0,
      benefitExpenses: 100,
      netChange: 300,
      closingBalance: 1300 + delta,
      closingProjected: 1300 + delta,
      realizedToDate: 1000,
      stillExpected: 300,
      categories: const [
        ProjectionCategory(name: 'Alimentação', amount: 800),
        ProjectionCategory(name: 'Assinaturas', amount: 99),
      ],
    ),
    ProjectionMonth(
      month: DateTime(2026, 10),
      openingBalance: 1300 + delta,
      guaranteedIncome: 5000,
      variableIncome: 0,
      income: 5000,
      directExpenses: 2800,
      recurringExpenses: 500,
      cardInstallments: 600,
      debts: 200,
      reserveTransfers: 300,
      investments: 0,
      otherInflows: 0,
      otherOutflows: 0,
      plannedMovements: 0,
      benefitExpenses: 100,
      netChange: 600,
      closingBalance: 1900 + delta,
      closingProjected: 1900 + delta,
      categories: const [
        ProjectionCategory(name: 'Alimentação', amount: 750),
      ],
    ),
  ];

  return ProjectionResult(
    scenario: 'current',
    horizonMonths: horizon,
    asOfDate: DateTime(2026, 9, 17),
    openingBalance: 1000,
    hasProjectionInputs: true,
    summary: ProjectionSummary(
      endingBalance: 1900 + delta,
      minimumBalance: 1300 + delta,
      maximumBalance: 1900 + delta,
      projectedSavings: 600,
    ),
    months: months,
    variableIncomes: const [],
  );
}
