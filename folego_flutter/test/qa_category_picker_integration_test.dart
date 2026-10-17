import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('importer reuses the canonical searchable category field', () {
    final source = File(
      'lib/features/transactions/statement_import_screen.dart',
    ).readAsStringSync();

    expect(
      source,
      contains("import '../../shared/widgets/category_search_field.dart';"),
    );
    expect(
      RegExp(r'CategorySearchField\(').allMatches(source).length,
      greaterThanOrEqualTo(2),
    );
    expect(source, contains("label: 'categoria em lote'"));
    expect(source, contains("label: 'categoria'"));
    expect(
      source,
      isNot(contains("decoration: const InputDecoration(labelText: 'categoria')")),
    );
  });
}
