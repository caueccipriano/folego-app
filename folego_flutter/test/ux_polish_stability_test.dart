import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:folego/core/notifications/notification_models.dart';
import 'package:folego/core/notifications/notification_service.dart';
import 'package:folego/core/utils/formatters.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/models/category_tag.dart';
import 'package:folego/data/models/financial_space.dart';
import 'package:folego/data/models/folego_snapshot.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/data/repositories/folego_repository_home.dart';
import 'package:folego/features/home/home_financial_hero.dart';
import 'package:folego/features/home/home_spending_palette.dart';
import 'package:folego/features/profile/financial_organization_data_source.dart';
import 'package:folego/features/profile/financial_organization_screen.dart';
import 'package:folego/features/profile/notification_settings_data_source.dart';
import 'package:folego/features/profile/notification_settings_screen.dart';

void main() {
  group('Financial Organization stability', () {
    testWidgets('categories render while markers are delayed', (tester) async {
      final markers = Completer<List<CategoryTag>>();
      final source = _OrganizationFake(markersLoader: () => markers.future);

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);

      expect(find.text('mercado'), findsOneWidget);
      expect(source.categoryLoads, 1);
      expect(source.markerLoads, 1);

      markers.complete(source.markers);
      await _drainAsync(tester);
    });

    testWidgets('markers render while categories are delayed', (tester) async {
      final categories = Completer<List<CategoryItem>>();
      final source = _OrganizationFake(
        categoriesLoader: () => categories.future,
      );

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);
      await _switchOrganizationTab(tester, 'Marcadores');

      expect(find.text('viagem'), findsOneWidget);
      expect(source.categoryLoads, 1);
      expect(source.markerLoads, 1);

      categories.complete(source.categories);
      await _drainAsync(tester);
    });

    testWidgets('marker error stays local and categories keep working', (
      tester,
    ) async {
      final source = _OrganizationFake(
        markersLoader: () async => throw StateError('marker failure'),
      );

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);

      expect(find.text('mercado'), findsOneWidget);
      await _switchOrganizationTab(tester, 'Marcadores');
      expect(find.text('não consegui carregar seus marcadores'), findsOneWidget);
      expect(find.text('tentar novamente'), findsOneWidget);
    });

    testWidgets('category error stays local and markers keep working', (
      tester,
    ) async {
      final source = _OrganizationFake(
        categoriesLoader: () async => throw StateError('category failure'),
      );

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);

      expect(find.text('não consegui carregar suas categorias'), findsOneWidget);
      await _switchOrganizationTab(tester, 'Marcadores');
      expect(find.text('viagem'), findsOneWidget);
    });

    testWidgets('marker retry is isolated', (tester) async {
      var attempt = 0;
      final source = _OrganizationFake(
        markersLoader: () async {
          attempt += 1;
          if (attempt == 1) throw StateError('first failure');
          return const [CategoryTag(id: 'm1', name: 'viagem', type: 'tag')];
        },
      );

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);
      await _switchOrganizationTab(tester, 'Marcadores');
      await tester.tap(find.text('tentar novamente'));
      await _drainAsync(tester);

      expect(find.text('viagem'), findsOneWidget);
      expect(source.markerLoads, 2);
      expect(source.categoryLoads, 1);
    });

    testWidgets('tab switching does not refetch either section', (tester) async {
      final source = _OrganizationFake();

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);
      await _switchOrganizationTab(tester, 'Marcadores');
      await _switchOrganizationTab(tester, 'Categorias');
      await _switchOrganizationTab(tester, 'Marcadores');

      expect(source.categoryLoads, 1);
      expect(source.markerLoads, 1);
    });

    testWidgets('category mutation reloads categories only', (tester) async {
      final source = _OrganizationFake();

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);
      await tester.tap(find.byType(Switch).first);
      await _drainAsync(tester);

      expect(source.categoryMutations, 1);
      expect(source.categoryLoads, 2);
      expect(source.markerLoads, 1);
    });

    testWidgets('marker mutation reloads markers only', (tester) async {
      final source = _OrganizationFake();

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);
      await _switchOrganizationTab(tester, 'Marcadores');
      await tester.tap(find.byType(Switch).first);
      await _drainAsync(tester);

      expect(source.markerMutations, 1);
      expect(source.markerLoads, 2);
      expect(source.categoryLoads, 1);
    });

    testWidgets('one delayed section never restores a global loading lock', (
      tester,
    ) async {
      final markers = Completer<List<CategoryTag>>();
      final source = _OrganizationFake(markersLoader: () => markers.future);

      await tester.pumpWidget(_organizationApp(source));
      await _drainAsync(tester);

      expect(find.text('mercado'), findsOneWidget);
      expect(find.text('nova categoria'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      markers.complete(source.markers);
      await _drainAsync(tester);
    });
  });

  group('Home hero canonical presentation', () {
    testWidgets('uses canonical spendablePool and dailyFolego directly', (
      tester,
    ) async {
      final snapshot = _snapshot(
        spendablePool: 600,
        dailyFolego: 47,
        daysUntilIncome: 10,
        nextIncomeDate: DateTime(2026, 9, 27),
      );

      await tester.pumpWidget(_heroApp(snapshot));

      expect(find.text(Formatters.money(600)), findsOneWidget);
      expect(
        find.text('${Formatters.money(47)} por dia até o próximo recebimento'),
        findsOneWidget,
      );
      expect(find.textContaining('${Formatters.money(60)} por dia'), findsNothing);
      expect(find.text('recebe em 10 dias · 27 set'), findsOneWidget);
    });

    test('income timing carries context for today tomorrow N days and no income', () {
      expect(
        homeIncomeTimingLabel(
          _snapshot(daysUntilIncome: 0, nextIncomeDate: DateTime(2026, 9, 17)),
        ),
        'recebimento previsto hoje',
      );
      expect(
        homeIncomeTimingLabel(
          _snapshot(daysUntilIncome: 1, nextIncomeDate: DateTime(2026, 9, 18)),
        ),
        'recebe amanhã · 18 set',
      );
      expect(
        homeIncomeTimingLabel(
          _snapshot(daysUntilIncome: 13, nextIncomeDate: DateTime(2026, 9, 30)),
        ),
        'recebe em 13 dias · 30 set',
      );
      expect(
        homeIncomeTimingLabel(
          _snapshot(daysUntilIncome: null, nextIncomeDate: null),
        ),
        isNull,
      );
    });

    testWidgets('zero spendable state is explanatory and keeps benefit context', (
      tester,
    ) async {
      await tester.pumpWidget(
        _heroApp(
          _snapshot(
            spendablePool: 0,
            dailyFolego: 0,
            daysUntilIncome: 10,
            nextIncomeDate: DateTime(2026, 9, 27),
          ),
        ),
      );

      expect(
        find.text(
          'seus compromissos já ocupam o dinheiro disponível até o próximo recebimento',
        ),
        findsOneWidget,
      );
      expect(find.textContaining('${Formatters.money(0)} por dia'), findsNothing);
      expect(find.textContaining('benefícios'), findsOneWidget);
    });

    testWidgets('explainer displays snapshot values without deriving new ones', (
      tester,
    ) async {
      await tester.pumpWidget(
        _heroApp(
          _snapshot(
            spendablePool: 600,
            dailyFolego: 47,
            liquidBalance: 1250,
            mandatoryOutflows: 650,
            budgetConfigured: true,
            monthlyBudgetPlanned: 1800,
            monthlyBudgetUsed: 700,
            economicHeadroom: 1100,
          ),
        ),
      );

      await tester.tap(find.byKey(const ValueKey('home-folego-explainer')));
      await tester.pumpAndSettle();

      expect(find.text(Formatters.money(1250)), findsOneWidget);
      expect(find.text(Formatters.money(650)), findsOneWidget);
      expect(find.text(Formatters.money(600)), findsWidgets);
      expect(find.text(Formatters.money(47)), findsOneWidget);
    });

    test('spending palette is deterministic and benefit stays excluded', () {
      final first = HomeSpendingPalette.colorFor(
        category: 'Mercado',
        categoryId: 'cat-123',
        brightness: Brightness.light,
      );
      final second = HomeSpendingPalette.colorFor(
        category: 'Nome alterado',
        categoryId: 'cat-123',
        brightness: Brightness.light,
      );
      final dark = HomeSpendingPalette.colorFor(
        category: 'Mercado',
        categoryId: 'cat-123',
        brightness: Brightness.dark,
      );

      expect(first, second);
      expect(dark, first);
      expect(homeExpenseEventTypes, isNot(contains('benefit_expense')));
      expect(
        homeExpenseEventTypes,
        containsAll(['expense', 'card_purchase', 'debt_payment']),
      );
    });

    test('home voice reflects canonical snapshot state', () {
      expect(
        homeFolegoVoiceLabel(_snapshot(spendablePool: 600)),
        'você está respirando bem até o próximo recebimento',
      );
      expect(
        homeFolegoVoiceLabel(_snapshot(spendablePool: 0, dailyFolego: 0)),
        'seu espaço está apertado agora',
      );
    });

    testWidgets('hero lays out across required responsive widths', (tester) async {
      addTearDown(() => tester.binding.setSurfaceSize(null));
      for (final width in const <double>[
        375,
        390,
        430,
        768,
        1024,
        1366,
        1440,
        1920,
      ]) {
        await tester.binding.setSurfaceSize(Size(width, 1000));
        await tester.pumpWidget(_heroApp(_snapshot()));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'width $width');
        expect(find.byKey(const ValueKey('home-spendable-pool')), findsOneWidget);
      }
    });
  });

  group('Notification settings product contract', () {
    testWidgets('unsupported loads honest copy without technical UI terms', (
      tester,
    ) async {
      final data = _NotificationDataFake();
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.unsupported,
      );

      await tester.pumpWidget(_notificationApp(data, adapter));
      await tester.pumpAndSettle();

      expect(
        find.text('seus lembretes podem ser configurados agora'),
        findsOneWidget,
      );
      expect(find.text('notificações no celular: em breve'), findsOneWidget);
      for (final forbidden in ['adapter', 'backend', 'build', 'no-op']) {
        expect(find.textContaining(forbidden), findsNothing);
      }
    });

    testWidgets('unsupported master saves intent without permission request', (
      tester,
    ) async {
      final data = _NotificationDataFake();
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.unsupported,
      );

      await tester.pumpWidget(_notificationApp(data, adapter));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notifications-master-toggle')));
      await tester.pumpAndSettle();

      expect(adapter.requestCalls, 0);
      expect(data.current.financialRemindersEnabled, isTrue);
      expect(
        find.text('pronto — seus lembretes ficaram configurados'),
        findsOneWidget,
      );
    });

    testWidgets('types and offset remain editable with master off', (
      tester,
    ) async {
      final data = _NotificationDataFake();
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.unsupported,
      );

      await tester.pumpWidget(_notificationApp(data, adapter));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notification-toggle-invoices')));
      await tester.pumpAndSettle();

      expect(data.current.invoicesEnabled, isFalse);
      expect(data.current.financialRemindersEnabled, isFalse);

      await _scrollNotifications(tester, -700);
      await tester.tap(find.text('3 dias antes'));
      await tester.pumpAndSettle();
      expect(data.current.reminderOffsetDays, 3);
    });

    testWidgets('preferred time can be saved now', (tester) async {
      final data = _NotificationDataFake();
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.unsupported,
      );

      await tester.pumpWidget(
        _notificationApp(
          data,
          adapter,
          timePicker: (_, _) async => const TimeOfDay(hour: 9, minute: 45),
        ),
      );
      await tester.pumpAndSettle();
      await _scrollNotifications(tester, -1200);
      await tester.tap(find.byKey(const ValueKey('notification-time')));
      await tester.pumpAndSettle();

      expect(data.current.preferredHour, 9);
      expect(data.current.preferredMinute, 45);
      expect(find.text('09:45'), findsOneWidget);
    });

    testWidgets('supported target asks permission and granted enables', (
      tester,
    ) async {
      final data = _NotificationDataFake();
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.notDetermined,
        requestResult: NotificationPermissionStatus.granted,
      );

      await tester.pumpWidget(_notificationApp(data, adapter));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notifications-master-toggle')));
      await tester.pumpAndSettle();

      expect(adapter.requestCalls, 1);
      expect(data.current.financialRemindersEnabled, isTrue);
    });

    testWidgets('denied permission does not enable and preserves choices', (
      tester,
    ) async {
      final initial = const NotificationPreferences(
        spaceId: 'space-1',
        invoicesEnabled: false,
        debtsEnabled: true,
        reminderOffsetDays: 3,
      );
      final data = _NotificationDataFake(initial: initial);
      final adapter = _NotificationAdapterFake(
        status: NotificationPermissionStatus.notDetermined,
        requestResult: NotificationPermissionStatus.denied,
      );

      await tester.pumpWidget(_notificationApp(data, adapter));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('notifications-master-toggle')));
      await tester.pumpAndSettle();

      expect(adapter.requestCalls, 1);
      expect(data.saveCalls, 0);
      expect(data.current.financialRemindersEnabled, isFalse);
      expect(data.current.invoicesEnabled, isFalse);
      expect(data.current.reminderOffsetDays, 3);
    });
  });
}

Future<void> _drainAsync(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 20));
  await tester.pump();
}

Future<void> _switchOrganizationTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 350));
  await tester.pump();
}

Future<void> _scrollNotifications(WidgetTester tester, double dy) async {
  await tester.drag(
    find.byKey(const ValueKey('notification-settings-list')),
    Offset(0, dy),
  );
  await tester.pumpAndSettle();
}

Widget _organizationApp(FinancialOrganizationDataSource source) => MaterialApp(
      home: FinancialOrganizationScreen(
        repository: _TestRepositoryHolder.repository,
        dataSource: source,
      ),
    );

Widget _heroApp(FolegoSnapshot snapshot) => MaterialApp(
      theme: ThemeData.light(),
      darkTheme: ThemeData.dark(),
      home: Scaffold(
        body: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: HomeFinancialHero(snapshot: snapshot),
          ),
        ),
      ),
    );

Widget _notificationApp(
  _NotificationDataFake data,
  _NotificationAdapterFake adapter, {
  NotificationTimePicker? timePicker,
}) {
  final service = NotificationService(
    adapter: adapter,
    loadPreferences: (_) async => data.current,
    loadUpcoming: (_, _, _) async => const <NotificationUpcomingEvent>[],
  );
  return MaterialApp(
    home: NotificationSettingsScreen(
      repository: _TestRepositoryHolder.repository,
      spaceId: 'space-1',
      service: service,
      dataSource: data,
      timePicker: timePicker,
    ),
  );
}

abstract final class _TestRepositoryHolder {
  static final FolegoRepository repository = FolegoRepository(
    SupabaseClient(
      'https://example.supabase.co',
      'test-anon-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    ),
  );
}

FolegoSnapshot _snapshot({
  double spendablePool = 600,
  double? dailyFolego = 60,
  int? daysUntilIncome = 10,
  DateTime? nextIncomeDate,
  double liquidBalance = 1200,
  double mandatoryOutflows = 600,
  bool budgetConfigured = false,
  double monthlyBudgetPlanned = 0,
  double monthlyBudgetUsed = 0,
  double economicHeadroom = 999,
}) =>
    FolegoSnapshot(
      asOfDate: DateTime(2026, 9, 17),
      nextIncomeDate: nextIncomeDate ??
          (daysUntilIncome == null ? null : DateTime(2026, 9, 27)),
      nextIncomeAmount: 6000,
      daysUntilIncome: daysUntilIncome,
      liquidBalance: liquidBalance,
      protectedBalance: 0,
      mandatoryOutflowsUntilIncome: mandatoryOutflows,
      cashHeadroom: liquidBalance - mandatoryOutflows,
      monthlyBudgetPlanned: monthlyBudgetPlanned,
      monthlyBudgetUsed: monthlyBudgetUsed,
      economicHeadroom: economicHeadroom,
      spendablePool: spendablePool,
      dailyFolego: dailyFolego,
      shortfall: 0,
      limitingFactor: 'cash',
      status: 'ok',
      budgetConfigured: budgetConfigured,
      needsIncomeSetup: daysUntilIncome == null,
    );

class _OrganizationFake implements FinancialOrganizationDataSource {
  _OrganizationFake({this.categoriesLoader, this.markersLoader});

  final Future<List<CategoryItem>> Function()? categoriesLoader;
  final Future<List<CategoryTag>> Function()? markersLoader;

  int categoryLoads = 0;
  int markerLoads = 0;
  int categoryMutations = 0;
  int markerMutations = 0;

  final categories = const <CategoryItem>[
    CategoryItem(
      id: 'c1',
      name: 'mercado',
      essential: false,
      kind: 'expense',
      isSystem: false,
      active: true,
      sortOrder: 1,
    ),
  ];

  final markers = const <CategoryTag>[
    CategoryTag(id: 'm1', name: 'viagem', type: 'tag'),
  ];

  @override
  Future<FinancialSpace> getPrimarySpace() async =>
      const FinancialSpace(id: 'space-1', name: 'Fôlego');

  @override
  Future<List<CategoryItem>> listCategories(String spaceId) async {
    categoryLoads += 1;
    final loader = categoriesLoader;
    return loader == null ? categories : loader();
  }

  @override
  Future<List<CategoryTag>> listMarkers(String spaceId) async {
    markerLoads += 1;
    final loader = markersLoader;
    return loader == null ? markers : loader();
  }

  @override
  Future<void> createCategory({
    required String spaceId,
    required String name,
    required String kind,
    String? parentId,
  }) async {
    categoryMutations += 1;
  }

  @override
  Future<void> updateCategory({
    required String spaceId,
    required CategoryItem category,
    required String name,
  }) async {
    categoryMutations += 1;
  }

  @override
  Future<void> setCategoryActive({
    required String spaceId,
    required String categoryId,
    required bool active,
  }) async {
    categoryMutations += 1;
  }

  @override
  Future<void> createMarker({
    required String spaceId,
    required String name,
    required String type,
  }) async {
    markerMutations += 1;
  }

  @override
  Future<void> updateMarker({
    required String spaceId,
    required CategoryTag marker,
    required String name,
    required String type,
  }) async {
    markerMutations += 1;
  }

  @override
  Future<void> setMarkerActive({
    required String spaceId,
    required String markerId,
    required bool active,
  }) async {
    markerMutations += 1;
  }
}

class _NotificationDataFake implements NotificationSettingsDataSource {
  _NotificationDataFake({NotificationPreferences? initial})
      : current = initial ?? const NotificationPreferences(spaceId: 'space-1');

  NotificationPreferences current;
  int saveCalls = 0;

  @override
  Future<NotificationPreferences> load(String spaceId) async => current;

  @override
  Future<NotificationPreferences> save(
    NotificationPreferences preferences,
  ) async {
    saveCalls += 1;
    current = preferences;
    return current;
  }
}

class _NotificationAdapterFake implements NotificationSchedulerAdapter {
  _NotificationAdapterFake({
    required this.status,
    NotificationPermissionStatus? requestResult,
  }) : requestResult = requestResult ?? status;

  NotificationPermissionStatus status;
  final NotificationPermissionStatus requestResult;
  int requestCalls = 0;

  @override
  Future<NotificationPermissionStatus> getPermissionStatus() async => status;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCalls += 1;
    status = requestResult;
    return requestResult;
  }

  @override
  Future<List<FinancialNotificationIntent>> pendingForSpace(String spaceId) async =>
      const <FinancialNotificationIntent>[];

  @override
  Future<void> schedule(FinancialNotificationIntent intent) async {}

  @override
  Future<void> cancel(String stableKey) async {}

  @override
  Future<void> cancelForEntity({
    required String spaceId,
    required String entityType,
    required String entityId,
  }) async {}

  @override
  Future<void> clearForSpace(String spaceId) async {}

  @override
  Future<void> clearAll() async {}
}
