import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/core/theme/category_icon_catalog.dart';
import 'package:folego/core/theme/category_visuals.dart';
import 'package:folego/data/models/category_item.dart';
import 'package:folego/data/repositories/folego_repository.dart';
import 'package:folego/features/profile/category_management_screen.dart';

void main() {
  test('category model keeps hierarchy, active state and persisted icon key', () {
    final item = CategoryItem.fromJson({
      'id': 'child',
      'name': 'Pedágio',
      'kind': 'expense',
      'parent_id': 'transport',
      'parent_name': 'Transporte',
      'essential': false,
      'active': false,
      'icon_key': 'transport',
      'is_system': false,
      'category_role': 'economic',
    });

    expect(item.parentId, 'transport');
    expect(item.parentName, 'Transporte');
    expect(item.isSubcategory, isTrue);
    expect(item.active, isFalse);
    expect(item.iconKey, 'transport');
    expect(item.breadcrumb, 'Transporte > Pedágio');
  });

  test('curated icon keys map to AppIcons and never persist IconData', () {
    expect(CategoryIconCatalog.choices.length, greaterThanOrEqualTo(45));
    expect(CategoryIconCatalog.iconForKey('travel'), AppIcons.categoryTravel);
    expect(CategoryIconCatalog.iconForKey('fuel'), AppIcons.transportFuel);
    expect(CategoryIconCatalog.isSupportedKey('travel'), isTrue);
    expect(CategoryIconCatalog.isSupportedKey('not-a-key'), isFalse);
    expect(
      CategoryVisuals.iconFor(category: 'Personalizada', iconKey: 'travel'),
      AppIcons.categoryTravel,
    );
  });

  testWidgets('Categories route opens as a secondary screen', (tester) async {
    _setViewport(tester, const Size(390, 844));
    final repository = _FakeRepository();

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => CategoryManagementScreen(
                    repository: repository,
                    spaceId: 'space',
                    loadOverride: (_) async => const <CategoryItem>[],
                  ),
                ),
              ),
              child: const Text('abrir categorias'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('abrir categorias'));
    await tester.pumpAndSettle();
    expect(find.text('categorias'), findsOneWidget);
    expect(find.byKey(const ValueKey('categories-mobile-layout')), findsOneWidget);
  });

  testWidgets('creates a main category with valid type and icon_key', (
    tester,
  ) async {
    final state = _CategoryHarnessState();
    await _pumpCategories(tester, state, const Size(1366, 900));

    await tester.tap(find.byKey(const ValueKey('new-category-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Viagens locais');
    await tester.tap(find.byKey(const ValueKey('category-icon-picker-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'viagem');
    await tester.pump();
    expect(find.byKey(const ValueKey('category-icon-travel')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-icon-travel')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(state.created, hasLength(1));
    expect(state.created.single.name, 'Viagens locais');
    expect(state.created.single.kind, 'expense');
    expect(state.created.single.parentId, isNull);
    expect(state.created.single.iconKey, 'travel');
    expect(find.text('Viagens locais'), findsOneWidget);
  });

  testWidgets('creates subcategory with the real parent_id', (tester) async {
    final state = _CategoryHarnessState(
      categories: const [
        CategoryItem(
          id: 'transport',
          name: 'Transporte',
          essential: false,
          kind: 'expense',
          iconKey: 'transport',
          categoryRole: 'economic',
        ),
      ],
    );
    await _pumpCategories(tester, state, const Size(1366, 900));

    await tester.tap(find.byKey(const ValueKey('new-subcategory-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Pedágio');
    await tester.tap(find.byKey(const ValueKey('category-icon-picker-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'transporte');
    await tester.pump();
    expect(find.byKey(const ValueKey('category-icon-transport')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-icon-transport')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(state.created, hasLength(1));
    expect(state.created.single.parentId, 'transport');
    expect(state.created.single.kind, 'expense');
    expect(state.created.single.iconKey, 'transport');
    expect(find.text('Pedágio'), findsOneWidget);
  });

  testWidgets('custom category can edit name and icon without changing hierarchy', (
    tester,
  ) async {
    final state = _CategoryHarnessState(
      categories: const [
        CategoryItem(
          id: 'root',
          name: 'Casa',
          essential: false,
          kind: 'expense',
          iconKey: 'home',
          categoryRole: 'economic',
        ),
        CategoryItem(
          id: 'child',
          name: 'Pequenos reparos',
          essential: false,
          kind: 'expense',
          parentId: 'root',
          parentName: 'Casa',
          iconKey: 'maintenance',
          categoryRole: 'economic',
        ),
      ],
    );
    await _pumpCategories(tester, state, const Size(1366, 900));

    await tester.tap(find.byKey(const ValueKey('edit-category-child')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, 'Reparos e serviços');
    await tester.tap(find.byKey(const ValueKey('category-icon-picker-button')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).last, 'serviços');
    await tester.pump();
    expect(find.byKey(const ValueKey('category-icon-services')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('category-icon-services')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('save-category-button')));
    await tester.pumpAndSettle();

    expect(state.updated, hasLength(1));
    expect(state.updated.single.categoryId, 'child');
    expect(state.updated.single.name, 'Reparos e serviços');
    expect(state.updated.single.iconKey, 'services');
    final edited = state.categories.firstWhere((item) => item.id == 'child');
    expect(edited.parentId, 'root');
    expect(edited.kind, 'expense');
    expect(find.text('Reparos e serviços'), findsOneWidget);
  });

  testWidgets('deactivation uses active and keeps historical category resolvable', (
    tester,
  ) async {
    final state = _CategoryHarnessState(
      categories: const [
        CategoryItem(
          id: 'legacy-custom',
          name: 'Categoria antiga',
          essential: false,
          kind: 'expense',
          iconKey: 'other',
          categoryRole: 'economic',
        ),
      ],
    );
    await _pumpCategories(tester, state, const Size(1366, 900));

    await tester.tap(find.byKey(const ValueKey('active-category-legacy-custom')));
    await tester.pumpAndSettle();

    expect(state.visibility, [const _VisibilityCall('legacy-custom', false)]);
    expect(state.categories.single.active, isFalse);
    expect(find.text('Categoria antiga'), findsOneWidget);
    expect(find.text('gasto · personalizada · desativada'), findsOneWidget);
  });

  testWidgets('system category is protected from presentation editing', (
    tester,
  ) async {
    final state = _CategoryHarnessState(
      categories: const [
        CategoryItem(
          id: 'system-food',
          name: 'Alimentação',
          essential: true,
          kind: 'expense',
          isSystem: true,
          systemKey: 'expense.food',
          categoryRole: 'economic',
        ),
      ],
    );
    await _pumpCategories(tester, state, const Size(1366, 900));

    expect(find.text('Alimentação'), findsOneWidget);
    expect(find.byTooltip('editar'), findsNothing);
  });

  for (final entry in <(Size, String)>[
    (Size(390, 844), 'categories-mobile-layout'),
    (Size(768, 900), 'categories-mobile-layout'),
    (Size(1024, 820), 'categories-desktop-layout'),
    (Size(1366, 900), 'categories-desktop-layout'),
    (Size(1440, 900), 'categories-desktop-layout'),
    (Size(1920, 1080), 'categories-desktop-layout'),
  ]) {
    testWidgets('Categories is responsive at ${entry.$1.width.toInt()} px', (
      tester,
    ) async {
      final state = _CategoryHarnessState(
        categories: const [
          CategoryItem(
            id: 'root',
            name: 'Categoria',
            essential: false,
            kind: 'expense',
            iconKey: 'other',
            categoryRole: 'economic',
          ),
        ],
      );
      await _pumpCategories(tester, state, entry.$1);

      final list = find.byKey(ValueKey(entry.$2));
      expect(list, findsOneWidget);
      expect(tester.takeException(), isNull);
      if (entry.$1.width >= 1440) {
        expect(tester.getSize(list).width, lessThanOrEqualTo(1200));
      }
    });
  }
}

Future<void> _pumpCategories(
  WidgetTester tester,
  _CategoryHarnessState state,
  Size size,
) async {
  _setViewport(tester, size);
  await tester.pumpWidget(
    MaterialApp(
      home: CategoryManagementScreen(
        repository: _FakeRepository(),
        spaceId: 'space',
        loadOverride: (_) async => List<CategoryItem>.from(state.categories),
        createOverride: ({
          required spaceId,
          required name,
          required kind,
          required parentId,
          required essential,
          required colorHex,
          required iconKey,
          required searchAliases,
        }) async {
          final id = 'created-${state.created.length + 1}';
          final parentName = parentId == null
              ? null
              : state.categories.firstWhere((item) => item.id == parentId).name;
          final call = _CreateCall(
            id: id,
            name: name,
            kind: kind,
            parentId: parentId,
            iconKey: iconKey,
          );
          state.created.add(call);
          state.categories.add(
            CategoryItem(
              id: id,
              name: name,
              essential: essential,
              kind: kind,
              parentId: parentId,
              parentName: parentName,
              colorHex: colorHex,
              iconKey: iconKey,
              searchAliases: searchAliases,
              categoryRole: 'economic',
            ),
          );
          return id;
        },
        updateOverride: ({
          required spaceId,
          required categoryId,
          required name,
          required essential,
          required colorHex,
          required iconKey,
          required searchAliases,
        }) async {
          final index = state.categories.indexWhere((item) => item.id == categoryId);
          final current = state.categories[index];
          state.updated.add(_UpdateCall(categoryId, name, iconKey));
          state.categories[index] = CategoryItem(
            id: current.id,
            name: name,
            essential: essential,
            kind: current.kind,
            parentId: current.parentId,
            parentName: current.parentName,
            active: current.active,
            isSystem: current.isSystem,
            isSelectable: current.isSelectable,
            colorHex: colorHex,
            iconKey: iconKey,
            systemKey: current.systemKey,
            categoryRole: current.categoryRole,
            searchAliases: searchAliases,
            sortOrder: current.sortOrder,
            usageCount: current.usageCount,
            lastUsedAt: current.lastUsedAt,
          );
        },
        visibilityOverride: ({
          required spaceId,
          required categoryId,
          required active,
        }) async {
          state.visibility.add(_VisibilityCall(categoryId, active));
          final index = state.categories.indexWhere((item) => item.id == categoryId);
          final current = state.categories[index];
          state.categories[index] = CategoryItem(
            id: current.id,
            name: current.name,
            essential: current.essential,
            kind: current.kind,
            parentId: current.parentId,
            parentName: current.parentName,
            active: active,
            isSystem: current.isSystem,
            isSelectable: current.isSelectable,
            colorHex: current.colorHex,
            iconKey: current.iconKey,
            systemKey: current.systemKey,
            categoryRole: current.categoryRole,
            searchAliases: current.searchAliases,
            sortOrder: current.sortOrder,
            usageCount: current.usageCount,
            lastUsedAt: current.lastUsedAt,
          );
        },
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

void _setViewport(WidgetTester tester, Size size) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

class _CategoryHarnessState {
  _CategoryHarnessState({List<CategoryItem> categories = const <CategoryItem>[]})
      : categories = List<CategoryItem>.from(categories);

  final List<CategoryItem> categories;
  final List<_CreateCall> created = <_CreateCall>[];
  final List<_UpdateCall> updated = <_UpdateCall>[];
  final List<_VisibilityCall> visibility = <_VisibilityCall>[];
}

class _CreateCall {
  const _CreateCall({
    required this.id,
    required this.name,
    required this.kind,
    required this.parentId,
    required this.iconKey,
  });

  final String id;
  final String name;
  final String kind;
  final String? parentId;
  final String iconKey;
}

class _UpdateCall {
  const _UpdateCall(this.categoryId, this.name, this.iconKey);
  final String categoryId;
  final String name;
  final String iconKey;
}

class _VisibilityCall {
  const _VisibilityCall(this.categoryId, this.active);
  final String categoryId;
  final bool active;

  @override
  bool operator ==(Object other) =>
      other is _VisibilityCall &&
      other.categoryId == categoryId &&
      other.active == active;

  @override
  int get hashCode => Object.hash(categoryId, active);
}

class _FakeRepository implements FolegoRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
