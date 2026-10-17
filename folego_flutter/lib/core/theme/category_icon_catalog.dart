import 'package:flutter/widgets.dart';

import 'app_icons.dart';

class CategoryIconChoice {
  const CategoryIconChoice({
    required this.key,
    required this.label,
    required this.icon,
    this.keywords = const <String>[],
  });

  final String key;
  final String label;
  final IconData icon;
  final List<String> keywords;

  bool matches(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return true;
    return key.contains(normalized) ||
        label.toLowerCase().contains(normalized) ||
        keywords.any((value) => value.toLowerCase().contains(normalized));
  }
}

/// Curated, serializable icon catalog for user-managed categories.
///
/// Persistence always uses [CategoryIconChoice.key]. IconData never leaves the
/// presentation layer.
abstract final class CategoryIconCatalog {
  static const List<CategoryIconChoice> choices = <CategoryIconChoice>[
    CategoryIconChoice(key: 'food', label: 'Comida', icon: AppIcons.categoryFood, keywords: ['alimentação']),
    CategoryIconChoice(key: 'groceries', label: 'Mercado', icon: AppIcons.foodSupermarket, keywords: ['supermercado']),
    CategoryIconChoice(key: 'restaurant', label: 'Restaurante', icon: AppIcons.foodRestaurant),
    CategoryIconChoice(key: 'delivery', label: 'Delivery', icon: AppIcons.foodDelivery),
    CategoryIconChoice(key: 'coffee', label: 'Café', icon: AppIcons.foodCafe),
    CategoryIconChoice(key: 'transport', label: 'Transporte', icon: AppIcons.categoryTransport),
    CategoryIconChoice(key: 'fuel', label: 'Combustível', icon: AppIcons.transportFuel),
    CategoryIconChoice(key: 'ride', label: 'Carro / app', icon: AppIcons.transportRide, keywords: ['uber', 'táxi']),
    CategoryIconChoice(key: 'bus', label: 'Transporte público', icon: AppIcons.transportPublic),
    CategoryIconChoice(key: 'parking', label: 'Estacionamento', icon: AppIcons.transportParking),
    CategoryIconChoice(key: 'home', label: 'Casa', icon: AppIcons.categoryHousing, keywords: ['moradia']),
    CategoryIconChoice(key: 'rent', label: 'Aluguel', icon: AppIcons.housingRent),
    CategoryIconChoice(key: 'building', label: 'Condomínio', icon: AppIcons.housingCondo),
    CategoryIconChoice(key: 'maintenance', label: 'Manutenção', icon: AppIcons.housingMaintenance),
    CategoryIconChoice(key: 'furniture', label: 'Móveis', icon: AppIcons.housingFurniture),
    CategoryIconChoice(key: 'bills', label: 'Contas da casa', icon: AppIcons.categoryHouseholdBills),
    CategoryIconChoice(key: 'energy', label: 'Energia', icon: AppIcons.billsEnergy),
    CategoryIconChoice(key: 'water', label: 'Água', icon: AppIcons.billsWater),
    CategoryIconChoice(key: 'internet', label: 'Internet', icon: AppIcons.billsInternet),
    CategoryIconChoice(key: 'phone', label: 'Telefone', icon: AppIcons.billsPhone),
    CategoryIconChoice(key: 'shopping', label: 'Compras', icon: AppIcons.categoryShopping),
    CategoryIconChoice(key: 'clothing', label: 'Roupas', icon: AppIcons.categoryClothing),
    CategoryIconChoice(key: 'electronics', label: 'Eletrônicos', icon: AppIcons.shoppingElectronics),
    CategoryIconChoice(key: 'marketplace', label: 'Marketplace', icon: AppIcons.shoppingMarketplace),
    CategoryIconChoice(key: 'leisure', label: 'Lazer', icon: AppIcons.categoryLeisure),
    CategoryIconChoice(key: 'cinema', label: 'Cinema', icon: AppIcons.leisureCinema),
    CategoryIconChoice(key: 'event', label: 'Eventos', icon: AppIcons.leisureEvent),
    CategoryIconChoice(key: 'games', label: 'Jogos', icon: AppIcons.leisureGames),
    CategoryIconChoice(key: 'health', label: 'Saúde', icon: AppIcons.categoryHealth),
    CategoryIconChoice(key: 'pharmacy', label: 'Farmácia', icon: AppIcons.healthPharmacy),
    CategoryIconChoice(key: 'doctor', label: 'Consulta', icon: AppIcons.healthConsultation),
    CategoryIconChoice(key: 'fitness', label: 'Academia', icon: AppIcons.healthGym),
    CategoryIconChoice(key: 'education', label: 'Educação', icon: AppIcons.categoryEducation),
    CategoryIconChoice(key: 'course', label: 'Curso', icon: AppIcons.educationCourse),
    CategoryIconChoice(key: 'books', label: 'Livros', icon: AppIcons.educationBooks),
    CategoryIconChoice(key: 'work', label: 'Trabalho', icon: AppIcons.journal),
    CategoryIconChoice(key: 'finance', label: 'Finanças', icon: AppIcons.categoryFinance),
    CategoryIconChoice(key: 'bank', label: 'Banco', icon: AppIcons.account),
    CategoryIconChoice(key: 'cash', label: 'Dinheiro', icon: AppIcons.cash),
    CategoryIconChoice(key: 'debt', label: 'Dívida', icon: AppIcons.categoryDebt),
    CategoryIconChoice(key: 'subscription', label: 'Assinatura', icon: AppIcons.categorySubscriptions),
    CategoryIconChoice(key: 'travel', label: 'Viagem', icon: AppIcons.categoryTravel),
    CategoryIconChoice(key: 'pets', label: 'Pets', icon: AppIcons.categoryPets),
    CategoryIconChoice(key: 'gift', label: 'Presentes', icon: AppIcons.categoryGifts),
    CategoryIconChoice(key: 'family', label: 'Família', icon: AppIcons.categoryFamily),
    CategoryIconChoice(key: 'beauty', label: 'Beleza', icon: AppIcons.categoryBeauty),
    CategoryIconChoice(key: 'insurance', label: 'Seguro', icon: AppIcons.categoryInsurance),
    CategoryIconChoice(key: 'services', label: 'Serviços', icon: AppIcons.housingMaintenance),
    CategoryIconChoice(key: 'income', label: 'Receita', icon: AppIcons.income),
    CategoryIconChoice(key: 'other', label: 'Outros', icon: AppIcons.categoryOther),
  ];

  static IconData iconForKey(String? key) =>
      tryIconForKey(key) ?? AppIcons.categoryOther;

  static IconData? tryIconForKey(String? key) {
    if (key == null || key.trim().isEmpty) return null;
    for (final choice in choices) {
      if (choice.key == key) return choice.icon;
    }
    return null;
  }

  static bool isSupportedKey(String? key) => tryIconForKey(key) != null;

  static List<CategoryIconChoice> search(String query) => choices
      .where((choice) => choice.matches(query))
      .toList(growable: false);
}
