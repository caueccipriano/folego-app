import 'package:flutter_test/flutter_test.dart';
import 'package:folego_flutter/data/models/category_item.dart';
import 'package:folego_flutter/data/models/category_search.dart';

void main() {
  CategoryItem item({
    required String id,
    required String name,
    String? parentId,
    String? parentName,
    List<String> aliases = const [],
    int usage = 0,
  }) {
    return CategoryItem(
      id: id,
      name: name,
      essential: false,
      kind: 'expense',
      parentId: parentId,
      parentName: parentName,
      searchAliases: aliases,
      usageCount: usage,
    );
  }

  test('breadcrumb diferencia subcategorias ambíguas', () {
    final housing = item(
      id: '1',
      name: 'Manutenção / reparos',
      parentId: 'housing',
      parentName: 'Moradia',
    );
    final car = item(
      id: '2',
      name: 'Manutenção do veículo',
      parentId: 'transport',
      parentName: 'Transporte',
    );

    expect(housing.breadcrumb, 'Moradia > Manutenção / reparos');
    expect(car.breadcrumb, 'Transporte > Manutenção do veículo');
  });

  test('busca por gas encontra combustível via alias', () {
    final fuel = item(
      id: 'fuel',
      name: 'Combustível',
      parentId: 'transport',
      parentName: 'Transporte',
      aliases: const ['gas', 'gasolina', 'posto'],
    );

    expect(CategorySearch.search([fuel], 'gas').single.id, 'fuel');
  });

  test('busca por uber encontra Transporte > Uber / Táxi', () {
    final ride = item(
      id: 'ride',
      name: 'Uber / Táxi',
      parentId: 'transport',
      parentName: 'Transporte',
      aliases: const ['uber', 'taxi'],
    );

    expect(CategorySearch.search([ride], 'uber').single.breadcrumb,
        'Transporte > Uber / Táxi');
  });

  test('busca por farm ignora acento', () {
    final pharmacy = item(
      id: 'pharmacy',
      name: 'Farmácia',
      parentId: 'health',
      parentName: 'Saúde & bem-estar',
      aliases: const ['farmacia', 'remedio'],
    );

    expect(CategorySearch.search([pharmacy], 'farm').single.id, 'pharmacy');
  });

  test('sem busca prioriza categorias mais usadas', () {
    final first = item(id: 'a', name: 'A', usage: 2);
    final second = item(id: 'b', name: 'B', usage: 9);

    expect(CategorySearch.search([first, second], '').first.id, 'b');
  });

  test('parsing tolera resposta antiga sem metadados', () {
    final parsed = CategoryItem.fromJson({
      'id': 'legacy',
      'name': 'Moradia',
      'essential': true,
      'parent_id': null,
    });

    expect(parsed.isSystem, isFalse);
    expect(parsed.isSelectable, isTrue);
    expect(parsed.searchAliases, isEmpty);
    expect(parsed.breadcrumb, 'Moradia');
  });
}
