import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/core/theme/category_visuals.dart';

void main() {
  group('CategoryVisuals travel and other', () {
    test('Viagens has its official travel icon and canonical name', () {
      expect(
        CategoryVisuals.iconFor(category: 'Viagens'),
        AppIcons.categoryTravel,
      );
      expect(CategoryVisuals.canonicalCategory('viagens'), 'Viagens');
    });

    test('Outros has its official neutral icon and canonical name', () {
      expect(
        CategoryVisuals.iconFor(category: 'Outros'),
        AppIcons.categoryOther,
      );
      expect(CategoryVisuals.canonicalCategory('outros'), 'Outros');
    });

    test('legacy Outros gastos resolves to Outros visuals', () {
      expect(
        CategoryVisuals.iconFor(category: 'Outros gastos'),
        AppIcons.categoryOther,
      );
      expect(CategoryVisuals.canonicalCategory('Outros gastos'), 'Outros');
    });

    test('Viagens and Outros no longer use the unclassified fallback', () {
      expect(
        CategoryVisuals.iconFor(category: 'Viagens'),
        isNot(AppIcons.categoryUnclassified),
      );
      expect(
        CategoryVisuals.iconFor(category: 'Outros'),
        isNot(AppIcons.categoryUnclassified),
      );
    });

    test('both categories have explicit dark and light colors', () {
      expect(
        CategoryVisuals.colorFor(
          category: 'Viagens',
          brightness: Brightness.dark,
        ),
        isNot(CategoryVisuals.colorFor(
          category: 'A classificar',
          brightness: Brightness.dark,
        )),
      );
      expect(
        CategoryVisuals.colorFor(
          category: 'Outros',
          brightness: Brightness.light,
        ),
        isNot(CategoryVisuals.colorFor(
          category: 'A classificar',
          brightness: Brightness.light,
        )),
      );
    });
  });
}
