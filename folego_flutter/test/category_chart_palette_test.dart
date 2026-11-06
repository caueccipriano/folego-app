import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/category_chart_palette.dart';
import 'package:folego/features/home/home_spending_palette.dart';
import 'package:folego/data/models/home_expense_summary.dart';

void main() {
  const families = <String>[
    'Alimentação',
    'Contas da casa',
    'Transporte',
    'Beleza & cuidados',
    'Moradia',
    'Educação',
    'Dívidas & financiamentos',
    'Viagens',
    'Compras',
    'Saúde & bem-estar',
    'Presentes & doações',
    'Família & dependentes',
    'Lazer & entretenimento',
    'Assinaturas',
    'Seguros',
    'Financeiro & impostos',
    'Vestuário',
    'Pets',
  ];

  List<CategoryChartEntry> entries(List<String> names) =>
      names.map((name) => CategoryChartEntry(name: name)).toList();

  test('18 main categories have distinct swatches in both modes', () {
    for (final brightness in Brightness.values) {
      final palette = CategoryChartPalette.colorsFor(
        entries(families),
        brightness: brightness,
      );
      expect(palette.length, families.length);
      expect(palette.toSet().length, families.length);
      expect(palette, isNot(contains(
        brightness == Brightness.dark
            ? CategoryChartPalette.otherDark
            : CategoryChartPalette.otherLight,
      )));
    }
  });

  test('colors do not depend on the spending/ranking order', () {
    for (final brightness in Brightness.values) {
      final original = CategoryChartPalette.colorsFor(
        entries(families),
        brightness: brightness,
      );
      final reversed = CategoryChartPalette.colorsFor(
        entries(families.reversed.toList()),
        brightness: brightness,
      ).reversed.toList();
      expect(reversed, original);
    }
  });

  test('dark mode is brighter and the neutral Outros remains separate', () {
    const names = [
      CategoryChartEntry(name: 'Alimentação'),
      CategoryChartEntry(name: 'Outros', isOther: true),
      CategoryChartEntry(name: 'Transporte'),
    ];
    final light = CategoryChartPalette.colorsFor(
      names,
      brightness: Brightness.light,
    );
    final dark = CategoryChartPalette.colorsFor(
      names,
      brightness: Brightness.dark,
    );
    expect(light[0], isNot(dark[0]));
    expect(light[1], CategoryChartPalette.otherLight);
    expect(dark[1], CategoryChartPalette.otherDark);
    expect(light[0], isNot(light[2]));
    expect(dark[0], isNot(dark[2]));
  });

  test('Home chart has matching colors for the ring and its legend', () {
    const categories = <HomeCategoryExpense>[
      HomeCategoryExpense(category: 'Alimentação', amount: 60, share: .6),
      HomeCategoryExpense(category: 'Beleza & cuidados', amount: 30, share: .3),
      HomeCategoryExpense(category: 'Outros', amount: 10, share: .1, isOther: true),
    ];
    final colors = HomeSpendingPalette.colorsFor(categories, Brightness.dark);
    expect(colors.toSet().length, 3);

    final home = File('lib/features/home/home_expense_card.dart')
        .readAsStringSync();
    expect(
      RegExp(r'HomeSpendingPalette\.colorsFor\(').allMatches(home).length,
      2,
    );
    expect(home, contains('color: chartColors[index]'));
    final monthly =
        File('lib/features/plan/monthly_category_donut.dart')
            .readAsStringSync();
    expect(monthly, contains('CategoryChartPalette.colorsFor('));
    expect(monthly, contains('colors[index]'));
    expect(monthly, contains('color: categoryColor'));
  });
}
