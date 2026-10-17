import 'package:flutter/material.dart';

import 'app_icons.dart';
import 'category_visuals_v2.dart' as legacy;

class CategoryVisualData {
  const CategoryVisualData({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Camada visual final da taxonomia universal do Fôlego.
///
/// Regras:
/// - categoria principal define a cor da família;
/// - subcategoria recebe glyph semântico próprio, mas herda a cor da família;
/// - system_key é a fonte mais estável para diferenciar nomes ambíguos;
/// - categorias personalizadas podem fornecer colorHex sem criar mapas locais;
/// - nomes legados continuam caindo na resolução v2 para compatibilidade.
abstract final class CategoryVisuals {
  static CategoryVisualData resolve({
    required Brightness brightness,
    String? category,
    String? subcategory,
    String? eventType,
    String? systemKey,
    String? colorHex,
  }) {
    final categoryName = category == null || category.trim().isEmpty
        ? 'A classificar'
        : category.trim();

    return CategoryVisualData(
      icon: iconFor(
        category: categoryName,
        subcategory: subcategory,
        eventType: eventType,
        systemKey: systemKey,
      ),
      color: colorFor(
        category: categoryName,
        brightness: brightness,
        eventType: eventType,
        colorHex: colorHex,
      ),
    );
  }

  static IconData iconFor({
    String? category,
    String? subcategory,
    String? eventType,
    String? systemKey,
  }) {
    final bySystemKey = _iconForSystemKey(systemKey);
    if (bySystemKey != null) return bySystemKey;

    final parent = _normalize(category);
    final child = _normalize(subcategory);

    if (child != null) {
      final byHierarchy = _iconForStandardSubcategory(parent, child);
      if (byHierarchy != null) return byHierarchy;

      if (parent == 'receitas' || eventType == 'income') {
        return legacy.CategoryVisuals.iconFor(
          category: subcategory,
          eventType: 'income',
        );
      }
    }

    return legacy.CategoryVisuals.iconFor(
      category: category,
      subcategory: subcategory,
      eventType: eventType,
    );
  }

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? eventType,
    String? colorHex,
  }) {
    final custom = _parseHexColor(colorHex);
    if (custom != null) return custom;

    return legacy.CategoryVisuals.colorFor(
      category: category,
      brightness: brightness,
      eventType: eventType,
    );
  }

  static String canonicalCategory(String value) {
    final normalized = _normalize(value);
    if (normalized == 'outros' || normalized == 'outros gastos') {
      return 'Outros';
    }
    return legacy.CategoryVisuals.canonicalCategory(value);
  }

  static String canonicalSubcategory(String value) =>
      legacy.CategoryVisuals.canonicalSubcategory(value);

  static IconData? _iconForSystemKey(String? rawKey) {
    final key = rawKey?.trim();
    if (key == null || key.isEmpty) return null;

    switch (key) {
      case 'expense.housing':
        return AppIcons.categoryHousing;
      case 'expense.housing.rent':
        return AppIcons.housingRent;
      case 'expense.housing.mortgage':
        return AppIcons.debtFinancing;
      case 'expense.housing.condo':
        return AppIcons.housingCondo;
      case 'expense.housing.property_tax':
        return AppIcons.financeTax;
      case 'expense.housing.maintenance':
        return AppIcons.housingMaintenance;
      case 'expense.housing.furniture':
        return AppIcons.housingFurniture;
      case 'expense.housing.domestic_services':
        return AppIcons.housingMaintenance;

      case 'expense.household':
        return AppIcons.categoryHouseholdBills;
      case 'expense.household.water':
        return AppIcons.billsWater;
      case 'expense.household.energy':
        return AppIcons.billsEnergy;
      case 'expense.household.gas':
        return AppIcons.billsGas;
      case 'expense.household.internet':
        return AppIcons.billsInternet;
      case 'expense.household.phone':
        return AppIcons.billsPhone;

      case 'expense.food':
        return AppIcons.categoryFood;
      case 'expense.food.groceries':
        return AppIcons.foodSupermarket;
      case 'expense.food.restaurant':
        return AppIcons.foodRestaurant;
      case 'expense.food.delivery':
        return AppIcons.foodDelivery;
      case 'expense.food.cafe':
      case 'expense.food.bars':
        return AppIcons.foodCafe;

      case 'expense.transport':
        return AppIcons.categoryTransport;
      case 'expense.transport.fuel':
        return AppIcons.transportFuel;
      case 'expense.transport.ride':
        return AppIcons.transportRide;
      case 'expense.transport.public':
        return AppIcons.transportPublic;
      case 'expense.transport.parking_toll':
        return AppIcons.transportParking;
      case 'expense.transport.maintenance':
        return AppIcons.transportMaintenance;
      case 'expense.transport.vehicle_tax':
        return AppIcons.financeTax;
      case 'expense.transport.rental':
        return AppIcons.categoryTransport;

      case 'expense.health':
        return AppIcons.categoryHealth;
      case 'expense.health.plan':
        return AppIcons.categoryInsurance;
      case 'expense.health.consultation':
      case 'expense.health.dental':
        return AppIcons.healthConsultation;
      case 'expense.health.exams':
        return AppIcons.healthExams;
      case 'expense.health.pharmacy':
      case 'expense.health.supplements':
        return AppIcons.healthPharmacy;
      case 'expense.health.therapy':
        return AppIcons.healthTherapy;
      case 'expense.health.fitness':
        return AppIcons.healthGym;

      case 'expense.education':
        return AppIcons.categoryEducation;
      case 'expense.education.school':
        return AppIcons.educationCollege;
      case 'expense.education.courses':
      case 'expense.education.certifications':
        return AppIcons.educationCourse;
      case 'expense.education.books':
      case 'expense.education.languages':
        return AppIcons.educationBooks;

      case 'expense.shopping':
        return AppIcons.categoryShopping;
      case 'expense.shopping.clothes':
        return AppIcons.clothingClothes;
      case 'expense.shopping.shoes':
        return AppIcons.clothingShoes;
      case 'expense.shopping.accessories':
        return AppIcons.clothingAccessories;
      case 'expense.shopping.electronics':
        return AppIcons.shoppingElectronics;
      case 'expense.shopping.home':
        return AppIcons.shoppingHome;
      case 'expense.shopping.marketplace':
        return AppIcons.shoppingMarketplace;
      case 'expense.shopping.online':
        return AppIcons.shoppingOnline;
      case 'expense.shopping.other':
        return AppIcons.shoppingOther;

      case 'expense.subscriptions':
        return AppIcons.categorySubscriptions;
      case 'expense.subscriptions.streaming':
        return AppIcons.subscriptionStreaming;
      case 'expense.subscriptions.music':
        return AppIcons.subscriptionMusic;
      case 'expense.subscriptions.apps':
        return AppIcons.subscriptionApps;
      case 'expense.subscriptions.software':
        return AppIcons.subscriptionSoftware;
      case 'expense.subscriptions.cloud':
      case 'expense.subscriptions.content':
      case 'expense.subscriptions.other':
        return AppIcons.subscriptionOther;

      case 'expense.leisure':
        return AppIcons.categoryLeisure;
      case 'expense.leisure.cinema':
        return AppIcons.leisureCinema;
      case 'expense.leisure.events':
      case 'expense.leisure.parties':
        return AppIcons.leisureEvent;
      case 'expense.leisure.games':
        return AppIcons.leisureGames;
      case 'expense.leisure.hobbies':
        return AppIcons.leisureHobby;
      case 'expense.leisure.outings':
        return AppIcons.leisureOuting;

      case 'expense.beauty':
        return AppIcons.categoryBeauty;
      case 'expense.beauty.hair':
        return AppIcons.beautyHair;
      case 'expense.beauty.aesthetics':
        return AppIcons.beautyAesthetics;
      case 'expense.beauty.cosmetics':
        return AppIcons.beautyCosmetics;
      case 'expense.beauty.personal':
      case 'expense.beauty.laundry':
        return AppIcons.beautyPersonalCare;

      case 'expense.family':
      case 'expense.family.children':
      case 'expense.family.nanny':
      case 'expense.family.alimony':
      case 'expense.family.elderly':
      case 'expense.family.other':
        return AppIcons.categoryFamily;
      case 'expense.family.school':
        return AppIcons.educationCollege;
      case 'expense.family.support':
        return AppIcons.giftsDonation;

      case 'expense.pets':
      case 'expense.pets.food':
      case 'expense.pets.other':
        return AppIcons.categoryPets;
      case 'expense.pets.vet':
        return AppIcons.healthConsultation;
      case 'expense.pets.medicine':
        return AppIcons.healthPharmacy;
      case 'expense.pets.grooming':
        return AppIcons.beautyHair;
      case 'expense.pets.accessories':
        return AppIcons.shoppingOther;

      case 'expense.travel':
      case 'expense.travel.tickets':
      case 'expense.travel.other':
        return AppIcons.categoryTravel;
      case 'expense.travel.lodging':
        return AppIcons.categoryHousing;
      case 'expense.travel.local_transport':
        return AppIcons.categoryTransport;
      case 'expense.travel.food':
        return AppIcons.categoryFood;
      case 'expense.travel.attractions':
        return AppIcons.leisureOuting;
      case 'expense.travel.insurance':
        return AppIcons.categoryInsurance;
      case 'expense.travel.fees':
        return AppIcons.financeTax;

      case 'expense.gifts':
        return AppIcons.categoryGifts;
      case 'expense.gifts.presents':
        return AppIcons.giftsPresent;
      case 'expense.gifts.celebrations':
        return AppIcons.giftsCelebration;
      case 'expense.gifts.donations':
        return AppIcons.giftsDonation;

      case 'expense.insurance':
      case 'expense.insurance.life':
      case 'expense.insurance.other':
        return AppIcons.categoryInsurance;
      case 'expense.insurance.auto':
        return AppIcons.categoryTransport;
      case 'expense.insurance.home':
        return AppIcons.categoryHousing;
      case 'expense.insurance.health':
        return AppIcons.categoryHealth;
      case 'expense.insurance.electronics':
        return AppIcons.shoppingElectronics;
      case 'expense.insurance.travel':
        return AppIcons.categoryTravel;

      case 'expense.finance':
        return AppIcons.categoryFinance;
      case 'expense.finance.bank_fees':
      case 'expense.finance.accounting':
        return AppIcons.financeBankFee;
      case 'expense.finance.interest':
        return AppIcons.financeInterest;
      case 'expense.finance.taxes':
      case 'expense.finance.iof_fees':
      case 'expense.finance.fines':
        return AppIcons.financeTax;
      case 'expense.finance.other':
        return AppIcons.financeAdjustment;

      case 'expense.debt':
        return AppIcons.categoryDebt;
      case 'expense.debt.loans':
        return AppIcons.debtLoan;
      case 'expense.debt.financing':
        return AppIcons.debtFinancing;
      case 'expense.debt.agreements':
        return AppIcons.debtAgreement;
      case 'expense.debt.installments':
        return AppIcons.debtInstallment;

      case 'expense.other':
      case 'expense.other.other':
        return AppIcons.categoryOther;

      case 'income.root':
        return AppIcons.income;
      case 'income.salary':
        return AppIcons.cash;
      case 'income.salary_advance':
        return AppIcons.debtInstallment;
      case 'income.freelance':
        return AppIcons.journal;
      case 'income.commissions':
        return AppIcons.financeInterest;
      case 'income.bonus':
        return AppIcons.achievements;
      case 'income.sale':
        return AppIcons.categoryShopping;
      case 'income.rent':
        return AppIcons.categoryHousing;
      case 'income.investment_returns':
        return AppIcons.categoryFinance;
      case 'income.gift':
        return AppIcons.giftsPresent;
      case 'income.reimbursement':
        return AppIcons.financeAdjustment;
      case 'income.other':
        return AppIcons.income;
    }

    return null;
  }

  static IconData? _iconForStandardSubcategory(
    String? parent,
    String child,
  ) {
    switch (parent) {
      case 'moradia':
        return switch (child) {
          'aluguel' => AppIcons.housingRent,
          'financiamento imobiliario' => AppIcons.debtFinancing,
          'condominio' => AppIcons.housingCondo,
          'iptu' => AppIcons.financeTax,
          'manutencao / reparos' => AppIcons.housingMaintenance,
          'moveis / decoracao' => AppIcons.housingFurniture,
          'servicos domesticos' => AppIcons.housingMaintenance,
          _ => null,
        };
      case 'contas da casa':
        return switch (child) {
          'agua' => AppIcons.billsWater,
          'energia' => AppIcons.billsEnergy,
          'gas' => AppIcons.billsGas,
          'internet' => AppIcons.billsInternet,
          'telefone' => AppIcons.billsPhone,
          _ => null,
        };
      case 'alimentacao':
        return switch (child) {
          'supermercado' => AppIcons.foodSupermarket,
          'restaurantes' => AppIcons.foodRestaurant,
          'delivery' => AppIcons.foodDelivery,
          'cafe / lanche' || 'bares' => AppIcons.foodCafe,
          _ => null,
        };
      case 'transporte':
        return switch (child) {
          'combustivel' => AppIcons.transportFuel,
          'uber / taxi' => AppIcons.transportRide,
          'transporte publico' => AppIcons.transportPublic,
          'estacionamento / pedagio' => AppIcons.transportParking,
          'manutencao do veiculo' => AppIcons.transportMaintenance,
          'ipva / licenciamento' => AppIcons.financeTax,
          'aluguel de veiculo' => AppIcons.categoryTransport,
          _ => null,
        };
      case 'saude & bem-estar':
        return switch (child) {
          'plano de saude' => AppIcons.categoryInsurance,
          'consultas' || 'odontologia' => AppIcons.healthConsultation,
          'exames' => AppIcons.healthExams,
          'farmacia' || 'suplementos' => AppIcons.healthPharmacy,
          'terapia' => AppIcons.healthTherapy,
          'academia / bem-estar' => AppIcons.healthGym,
          _ => null,
        };
      case 'educacao':
        return switch (child) {
          'escola / faculdade' => AppIcons.educationCollege,
          'cursos' || 'certificacoes' => AppIcons.educationCourse,
          'livros / material' || 'idiomas' => AppIcons.educationBooks,
          _ => null,
        };
      case 'compras':
        return switch (child) {
          'roupas' => AppIcons.clothingClothes,
          'calcados' => AppIcons.clothingShoes,
          'acessorios' => AppIcons.clothingAccessories,
          'eletronicos' => AppIcons.shoppingElectronics,
          'casa / decoracao' => AppIcons.shoppingHome,
          'marketplace' => AppIcons.shoppingMarketplace,
          'compras online' => AppIcons.shoppingOnline,
          'outros produtos' => AppIcons.shoppingOther,
          _ => null,
        };
      case 'assinaturas':
        return switch (child) {
          'streaming' => AppIcons.subscriptionStreaming,
          'musica' => AppIcons.subscriptionMusic,
          'apps' => AppIcons.subscriptionApps,
          'software' => AppIcons.subscriptionSoftware,
          'nuvem / armazenamento' ||
          'noticias / conteudo' ||
          'outros servicos digitais' => AppIcons.subscriptionOther,
          _ => null,
        };
      case 'lazer & entretenimento':
        return switch (child) {
          'cinema' => AppIcons.leisureCinema,
          'eventos / shows' || 'baladas / festas' => AppIcons.leisureEvent,
          'jogos' => AppIcons.leisureGames,
          'hobbies' => AppIcons.leisureHobby,
          'passeios' => AppIcons.leisureOuting,
          _ => null,
        };
      case 'beleza & cuidados':
        return switch (child) {
          'cabelo / barbearia' => AppIcons.beautyHair,
          'estetica' => AppIcons.beautyAesthetics,
          'cosmeticos' => AppIcons.beautyCosmetics,
          'cuidados pessoais' || 'lavanderia' => AppIcons.beautyPersonalCare,
          _ => null,
        };
      case 'familia & dependentes':
        return switch (child) {
          'escola / creche' => AppIcons.educationCollege,
          'apoio familiar' => AppIcons.giftsDonation,
          _ => AppIcons.categoryFamily,
        };
      case 'pets':
        return switch (child) {
          'veterinario' => AppIcons.healthConsultation,
          'medicamentos' => AppIcons.healthPharmacy,
          'banho / tosa' => AppIcons.beautyHair,
          'acessorios' => AppIcons.shoppingOther,
          _ => AppIcons.categoryPets,
        };
      case 'viagens':
        return switch (child) {
          'hospedagem' => AppIcons.categoryHousing,
          'transporte local' => AppIcons.categoryTransport,
          'alimentacao em viagem' => AppIcons.categoryFood,
          'passeios / atracoes' => AppIcons.leisureOuting,
          'seguro viagem' => AppIcons.categoryInsurance,
          'taxas' => AppIcons.financeTax,
          _ => AppIcons.categoryTravel,
        };
      case 'presentes & doacoes':
        return switch (child) {
          'presentes' => AppIcons.giftsPresent,
          'datas comemorativas' => AppIcons.giftsCelebration,
          'doacoes' => AppIcons.giftsDonation,
          _ => null,
        };
      case 'seguros':
        return switch (child) {
          'auto' => AppIcons.categoryTransport,
          'residencial' => AppIcons.categoryHousing,
          'saude' => AppIcons.categoryHealth,
          'celular / eletronicos' => AppIcons.shoppingElectronics,
          'viagem' => AppIcons.categoryTravel,
          _ => AppIcons.categoryInsurance,
        };
      case 'financeiro & impostos':
        return switch (child) {
          'tarifas bancarias' || 'contabilidade' => AppIcons.financeBankFee,
          'juros' => AppIcons.financeInterest,
          'impostos' || 'iof / taxas' || 'multas' => AppIcons.financeTax,
          _ => AppIcons.financeAdjustment,
        };
      case 'dividas & financiamentos':
        return switch (child) {
          'emprestimos' => AppIcons.debtLoan,
          'financiamentos' => AppIcons.debtFinancing,
          'acordos / renegociacoes' => AppIcons.debtAgreement,
          'parcelamentos' => AppIcons.debtInstallment,
          _ => null,
        };
      case 'outros gastos':
        return AppIcons.categoryOther;
      case 'receitas':
        return legacy.CategoryVisuals.iconFor(
          category: child,
          eventType: 'income',
        );
    }
    return null;
  }

  static Color? _parseHexColor(String? value) {
    if (value == null) return null;
    var hex = value.trim().replaceFirst('#', '');
    if (hex.length == 6) hex = 'FF$hex';
    if (hex.length != 8) return null;
    final parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }

  static String? _normalize(String? value) {
    if (value == null) return null;
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return null;
    return text
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('ã', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ä', 'a')
        .replaceAll('é', 'e')
        .replaceAll('è', 'e')
        .replaceAll('ê', 'e')
        .replaceAll('ë', 'e')
        .replaceAll('í', 'i')
        .replaceAll('ì', 'i')
        .replaceAll('î', 'i')
        .replaceAll('ï', 'i')
        .replaceAll('ó', 'o')
        .replaceAll('ò', 'o')
        .replaceAll('ô', 'o')
        .replaceAll('õ', 'o')
        .replaceAll('ö', 'o')
        .replaceAll('ú', 'u')
        .replaceAll('ù', 'u')
        .replaceAll('û', 'u')
        .replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}
