import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:folego/core/theme/app_icons.dart';
import 'package:folego/core/theme/category_visuals.dart';

void main() {
  group('CategoryVisuals universal taxonomy', () {
    test('all universal parent categories have explicit icons', () {
      final expected = <String, IconData>{
        'Moradia': AppIcons.categoryHousing,
        'Contas da casa': AppIcons.categoryHouseholdBills,
        'Alimentação': AppIcons.categoryFood,
        'Transporte': AppIcons.categoryTransport,
        'Saúde & bem-estar': AppIcons.categoryHealth,
        'Educação': AppIcons.categoryEducation,
        'Compras': AppIcons.categoryShopping,
        'Assinaturas': AppIcons.categorySubscriptions,
        'Lazer & entretenimento': AppIcons.categoryLeisure,
        'Beleza & cuidados': AppIcons.categoryBeauty,
        'Família & dependentes': AppIcons.categoryFamily,
        'Pets': AppIcons.categoryPets,
        'Viagens': AppIcons.categoryTravel,
        'Presentes & doações': AppIcons.categoryGifts,
        'Seguros': AppIcons.categoryInsurance,
        'Financeiro & impostos': AppIcons.categoryFinance,
        'Dívidas & financiamentos': AppIcons.categoryDebt,
        'Outros gastos': AppIcons.categoryOther,
      };

      for (final entry in expected.entries) {
        expect(CategoryVisuals.iconFor(category: entry.key), entry.value,
            reason: entry.key);
      }
    });

    test('ambiguous subcategories use their parent family', () {
      expect(
        CategoryVisuals.iconFor(
          category: 'Transporte',
          subcategory: 'Manutenção do veículo',
        ),
        AppIcons.transportMaintenance,
      );
      expect(
        CategoryVisuals.iconFor(
          category: 'Moradia',
          subcategory: 'Manutenção / reparos',
        ),
        AppIcons.housingMaintenance,
      );
      expect(
        CategoryVisuals.iconFor(
          category: 'Pets',
          subcategory: 'Acessórios',
        ),
        AppIcons.shoppingOther,
      );
      expect(
        CategoryVisuals.iconFor(
          category: 'Compras',
          subcategory: 'Acessórios',
        ),
        AppIcons.clothingAccessories,
      );
    });

    test('system keys resolve missing universal semantics', () {
      expect(
        CategoryVisuals.iconFor(
          category: 'Saúde & bem-estar',
          subcategory: 'Plano de saúde',
          systemKey: 'expense.health.plan',
        ),
        AppIcons.categoryInsurance,
      );
      expect(
        CategoryVisuals.iconFor(
          category: 'Viagens',
          subcategory: 'Hospedagem',
          systemKey: 'expense.travel.lodging',
        ),
        AppIcons.categoryHousing,
      );
      expect(
        CategoryVisuals.iconFor(
          category: 'Receitas',
          subcategory: 'Salário',
          eventType: 'income',
          systemKey: 'income.salary',
        ),
        AppIcons.cash,
      );
    });

    test('custom category color is honored', () {
      expect(
        CategoryVisuals.colorFor(
          category: 'Minha categoria',
          brightness: Brightness.dark,
          colorHex: '#123456',
        ),
        const Color(0xFF123456),
      );
    });

    test('invalid custom color falls back safely', () {
      expect(
        CategoryVisuals.colorFor(
          category: 'Minha categoria',
          brightness: Brightness.dark,
          colorHex: 'not-a-color',
        ),
        CategoryVisuals.colorFor(
          category: 'Minha categoria',
          brightness: Brightness.dark,
        ),
      );
    });
  });
}
