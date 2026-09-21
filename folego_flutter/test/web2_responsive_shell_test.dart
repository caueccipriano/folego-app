import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/core/ui/app_snackbars.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/models/monthly_money_summary.dart';
import 'package:folego/data/models/transaction_page.dart';
import 'package:folego/data/models/upcoming_events.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/home/home_screen_base.dart' as home;
import 'package:folego/l10n/app_localizations.dart';
import 'package:folego/shared/widgets/responsive_navigation_shell.dart';

void main() {
  testWidgets('320px keeps every mobile navigation target tappable', (tester) async {
    await _pumpShell(tester, const Size(320, 700));

    final nav = find.byKey(const ValueKey('mobile-liquid-nav'));
    expect(nav, findsOneWidget);
    final navRect = tester.getRect(nav);

    for (var index = 0; index < 5; index++) {
      final target = find.byKey(ValueKey('mobile-nav-destination-$index'));
      final rect = tester.getRect(target);
      expect(rect.width, greaterThanOrEqualTo(44));
      expect(rect.height, greaterThanOrEqualTo(44));
      expect(navRect.contains(rect.center), isTrue);
      await tester.tapAt(rect.center);
      await tester.pump();
      expect(find.byKey(ValueKey('page-$index')), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('width below 600 keeps bottom navigation', (tester) async {
    await _pumpShell(tester, const Size(390, 844));
    expect(find.byKey(const ValueKey('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
  });

  testWidgets('mobile liquid nav stays pinned to the bottom and isolated from the body', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    final navRect = tester.getRect(
      find.byKey(const ValueKey('mobile-liquid-nav')),
    );
    final contentRect = tester.getRect(
      find.byKey(const ValueKey('shell-content')),
    );

    expect(navRect.height, lessThanOrEqualTo(90));
    expect(navRect.top, greaterThan(740));
    expect(navRect.bottom, closeTo(844, 1));
    expect(contentRect.bottom, lessThanOrEqualTo(navRect.top + 1));
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('mobile navigation maps every destination to the correct page', (tester) async {
    await _pumpShell(tester, const Size(390, 844));

    final destinations = <({IconData icon, int page})>[
      (icon: AppIcons.transactions, page: 1),
      (icon: AppIcons.plan, page: 2),
      (icon: AppIcons.wallet, page: 3),
      (icon: AppIcons.profile, page: 4),
      (icon: AppIcons.home, page: 0),
    ];

    for (final destination in destinations) {
      final target = find.byKey(
        ValueKey('mobile-nav-destination-${destination.page}'),
      );
      final targetRect = tester.getRect(target);
      final navRect = tester.getRect(
        find.byKey(const ValueKey('mobile-liquid-nav')),
      );

      expect(navRect.contains(targetRect.center), isTrue);
      await tester.tapAt(targetRect.center);
      await tester.pump();
      expect(
        find.byKey(ValueKey('page-${destination.page}')),
        findsOneWidget,
      );
    }
  });

  testWidgets('768 stays in compact navigation mode', (tester) async {
    await _pumpShell(tester, const Size(768, 900));
    expect(find.byKey(const ValueKey('mobile-bottom-navigation')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsNothing);
  });

  testWidgets('1024 and above uses sidebar without bottom navigation', (tester) async {
    await _pumpShell(tester, const Size(1024, 820));
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('mobile-bottom-navigation')), findsNothing);
  });

  testWidgets('desktop sidebar keeps selected tab', (tester) async {
    await _pumpShell(tester, const Size(1366, 820));
    await tester.tap(find.byKey(const ValueKey('desktop-nav-2')));
    await tester.pump();
    expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
  });

  testWidgets('resize preserves selected tab', (tester) async {
    final counts = List<int>.filled(5, 0);
    await _pumpShell(tester, const Size(390, 844), initCounts: counts);
    await tester.tap(find.byIcon(AppIcons.plan));
    await tester.pump();
    expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
    tester.view.physicalSize = const Size(1366, 820);
    await tester.pump();
    expect(find.byKey(const ValueKey('desktop-sidebar')), findsOneWidget);
    expect(find.byKey(const ValueKey('page-2')), findsOneWidget);
  });

  testWidgets('resize does not recreate shell page states', (tester) async {
    final counts = List<int>.filled(5, 0);
    await _pumpShell(tester, const Size(390, 844), initCounts: counts);
    expect(counts, everyElement(1));
    tester.view.physicalSize = const Size(1440, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(768, 900);
    await tester.pump();
    tester.view.physicalSize = const Size(1920, 1080);
    await tester.pump();
    expect(counts, everyElement(1));
  });

  testWidgets('Home shows a retry state instead of a blank page when snapshot fails', (tester) async {
    _setViewport(tester, const Size(390, 844));
    await tester.pumpWidget(_app(home.HomeScreen(
      space: const FinancialSpace(id: 'space', name: 'Casa'),
      repository: _HomeSnapshotFailureRepository(),
    )));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('não consegui carregar seu resumo financeiro'),
      findsOneWidget,
    );
    expect(find.text('tentar novamente'), findsOneWidget);
  });

  testWidgets('Home desktop uses dashboard columns instead of a mobile stack', (tester) async {
    _setViewport(tester, const Size(1366, 900));
    await tester.pumpWidget(_app(home.HomeScreen(
      space: const FinancialSpace(id: 'space', name: 'Casa'),
      repository: _HomeRepository(),
    )));
    await tester.pump();
    await tester.pump();
    final hero = tester.getTopLeft(find.text('te sobra pra gastar'));
    final action = tester.getTopLeft(find.text('gasto'));
    final expenses = tester.getTopLeft(find.text('seu mês até agora'));
    final upcoming = tester.getTopLeft(find.text('próximos dias'));
    expect(action.dx, greaterThan(hero.dx));
    expect((action.dy - hero.dy).abs(), lessThan(140));
    expect(upcoming.dx, greaterThan(expenses.dx));
    expect((upcoming.dy - expenses.dy).abs(), lessThan(140));
  });

  testWidgets('desktop snackbar is floating and width constrained', (tester) async {
    _setViewport(tester, const Size(1366, 820));
    await tester.pumpWidget(_app(Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => AppSnackbars.show(context, 'salvo'),
          child: const Text('mostrar'),
        ),
      ),
    )));
    await tester.tap(find.text('mostrar'));
    await tester.pump();
    final snackbar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackbar.behavior, SnackBarBehavior.floating);
    expect(snackbar.width, AppSnackbars.desktopWidth);
    expect(snackbar.width, inInclusiveRange(360, 440));
  });
}

Future<void> _pumpShell(WidgetTester tester, Size size, {List<int>? initCounts}) async {
  _setViewport(tester, size);
  await tester.pumpWidget(_app(_ShellHarness(initCounts: initCounts ?? List<int>.filled(5, 0))));
  await tester.pump();
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Widget _app(Widget home) => MaterialApp(
  locale: const Locale('pt', 'BR'),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: home,
);

class _ShellHarness extends StatefulWidget {
  const _ShellHarness({required this.initCounts});
  final List<int> initCounts;
  @override
  State<_ShellHarness> createState() => _ShellHarnessState();
}

class _ShellHarnessState extends State<_ShellHarness> {
  int index = 0;
  @override
  Widget build(BuildContext context) => ResponsiveNavigationShell(
    selectedIndex: index,
    onDestinationSelected: (value) => setState(() => index = value),
    pages: List.generate(5, (page) => _ProbePage(
      key: ValueKey('probe-$page'),
      index: page,
      onInit: () => widget.initCounts[page] += 1,
    )),
  );
}

class _ProbePage extends StatefulWidget {
  const _ProbePage({super.key, required this.index, required this.onInit});
  final int index;
  final VoidCallback onInit;
  @override
  State<_ProbePage> createState() => _ProbePageState();
}

class _ProbePageState extends State<_ProbePage> {
  @override
  void initState() { super.initState(); widget.onInit(); }
  @override
  Widget build(BuildContext context) => Center(
    child: Text('page ${widget.index}', key: ValueKey('page-${widget.index}')),
  );
}

class _HomeSnapshotFailureRepository extends _HomeRepository {
  @override
  Future<FolegoSnapshot> getSnapshot(
    String spaceId, {
    DateTime? asOfDate,
  }) async {
    throw Exception('snapshot unavailable');
  }
}

class _HomeRepository implements FolegoRepository {
  @override
  Future<FolegoSnapshot> getSnapshot(String spaceId, {DateTime? asOfDate}) async => FolegoSnapshot(
    asOfDate: DateTime(2026, 9, 16),
    nextIncomeDate: DateTime(2026, 9, 30),
    nextIncomeAmount: 6000,
    daysUntilIncome: 14,
    liquidBalance: 4000,
    protectedBalance: 500,
    mandatoryOutflowsUntilIncome: 1200,
    cashHeadroom: 2300,
    monthlyBudgetPlanned: 2500,
    monthlyBudgetUsed: 900,
    economicHeadroom: 1600,
    spendablePool: 1600,
    dailyFolego: 114,
    shortfall: 0,
    limitingFactor: 'budget',
    status: 'ok',
    budgetConfigured: true,
    needsIncomeSetup: false,
  );
  @override
  Future<String> getProfileName() async => 'Cauê';

  @override
  Future<MonthlyMoneySummary> getMonthlyMoneySummary({
    required String spaceId,
    DateTime? periodMonth,
  }) async => MonthlyMoneySummary(
    periodMonth: DateTime(2026, 9),
    incomeAmount: 5000,
    spendingAccount: 900,
    spendingCards: 500,
    spendingBenefits: 100,
    refundsAmount: 50,
    spendingNet: 1450,
    incomeMinusSpending: 3550,
    competenceCardsTotal: 250,
    competenceDirect: 900,
    competenceBenefits: 100,
    competenceRefunds: 50,
    competenceNet: 1200,
    competenceCards: const [
      MonthlyCardCompetence(
        cardId: 'card',
        name: 'Cartão',
        amount: 250,
      ),
    ],
    cashInflow: 5000,
    cashOutflow: 1800,
    cashNet: 3200,
    movementCardPayments: 300,
    movementTransfers: 100,
    movementReserveInvestment: 50,
    movementReconciliation: 0,
  );
  @override
  Future<TransactionPage> getTransactionsPage(String spaceId, {TransactionCursor? cursor, int pageSize = transactionPageSize}) async => const TransactionPage(items: [], hasMore: false, nextCursor: null);
  @override
  Future<List<CategoryItem>> listExpenseCategories(String spaceId) async => [];
  @override
  Future<List<CategoryItem>> listIncomeCategories(String spaceId) async => [];
  @override
  Future<List<UpcomingEvent>> getUpcomingEvents(String spaceId, {DateTime? from, int days = 30}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
