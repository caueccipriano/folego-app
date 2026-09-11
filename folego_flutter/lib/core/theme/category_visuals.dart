import 'package:flutter/widgets.dart';

import 'app_colors.dart';
import 'app_icons.dart';

/// Fonte única para o visual de categorias e subcategorias.
///
/// Regras:
/// - categoria principal define a cor da família;
/// - subcategoria pode ter ícone próprio;
/// - subcategoria herda a cor da categoria principal;
/// - categorias antigas do banco também são reconhecidas durante a migração.
abstract final class CategoryVisuals {
  // ---------------------------------------------------------------------------
  // API PÚBLICA
  // ---------------------------------------------------------------------------

  static IconData iconFor({required String category, String? subcategory}) {
    final categoryKey = _normalize(category);
    final subcategoryKey = _normalize(subcategory ?? '');

    // -------------------------------------------------------------------------
    // COMPATIBILIDADE COM AS CATEGORIAS ANTIGAS
    // -------------------------------------------------------------------------

    if (subcategoryKey.isEmpty) {
      if (_containsAny(categoryKey, ['restaurante'])) {
        return AppIcons.foodRestaurant;
      }

      if (_containsAny(categoryKey, ['delivery'])) {
        return AppIcons.foodDelivery;
      }

      if (_containsAny(categoryKey, ['supermercado', 'mercado'])) {
        return AppIcons.foodSupermarket;
      }

      if (_containsAny(categoryKey, ['gasolina', 'combustivel'])) {
        return AppIcons.transportFuel;
      }

      if (_containsAny(categoryKey, ['farmacia'])) {
        return AppIcons.healthPharmacy;
      }

      if (_containsAny(categoryKey, ['energia', 'luz'])) {
        return AppIcons.billsEnergy;
      }

      if (_containsAny(categoryKey, ['agua'])) {
        return AppIcons.billsWater;
      }

      if (_containsAny(categoryKey, ['internet'])) {
        return AppIcons.billsInternet;
      }

      if (_containsAny(categoryKey, ['telefone', 'celular'])) {
        return AppIcons.billsPhone;
      }

      if (_containsAny(categoryKey, ['compras online'])) {
        return AppIcons.shoppingOnline;
      }

      if (_containsAny(categoryKey, ['tarifas bancarias', 'tarifa bancaria'])) {
        return AppIcons.financeBankFee;
      }

      if (_containsAny(categoryKey, ['emprestimos', 'emprestimo'])) {
        return AppIcons.debtLoan;
      }
    }

    // -------------------------------------------------------------------------
    // A CLASSIFICAR
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, [
      'a classificar',
      'sem categoria',
      'nao classificado',
    ])) {
      return AppIcons.categoryUnclassified;
    }

    // -------------------------------------------------------------------------
    // ALIMENTAÇÃO
    // -------------------------------------------------------------------------

    if (_isFood(categoryKey)) {
      if (_containsAny(subcategoryKey, ['supermercado', 'mercado'])) {
        return AppIcons.foodSupermarket;
      }

      if (_containsAny(subcategoryKey, ['restaurante'])) {
        return AppIcons.foodRestaurant;
      }

      if (_containsAny(subcategoryKey, ['delivery', 'entrega'])) {
        return AppIcons.foodDelivery;
      }

      if (_containsAny(subcategoryKey, ['cafe', 'lanche', 'padaria'])) {
        return AppIcons.foodCafe;
      }

      return AppIcons.categoryFood;
    }

    // -------------------------------------------------------------------------
    // MORADIA
    // -------------------------------------------------------------------------

    if (_isHousing(categoryKey)) {
      if (_containsAny(subcategoryKey, ['aluguel'])) {
        return AppIcons.housingRent;
      }

      if (_containsAny(subcategoryKey, ['condominio'])) {
        return AppIcons.housingCondo;
      }

      if (_containsAny(subcategoryKey, ['manutencao', 'reparo'])) {
        return AppIcons.housingMaintenance;
      }

      if (_containsAny(subcategoryKey, [
        'moveis',
        'moveis e utilidades',
        'utilidades',
      ])) {
        return AppIcons.housingFurniture;
      }

      return AppIcons.categoryHousing;
    }

    // -------------------------------------------------------------------------
    // CONTAS DA CASA
    // -------------------------------------------------------------------------

    if (_isHouseholdBills(categoryKey)) {
      if (_containsAny(subcategoryKey, ['energia', 'luz'])) {
        return AppIcons.billsEnergy;
      }

      if (_containsAny(subcategoryKey, ['agua'])) {
        return AppIcons.billsWater;
      }

      if (_containsAny(subcategoryKey, ['gas'])) {
        return AppIcons.billsGas;
      }

      if (_containsAny(subcategoryKey, ['internet'])) {
        return AppIcons.billsInternet;
      }

      if (_containsAny(subcategoryKey, ['telefone', 'celular'])) {
        return AppIcons.billsPhone;
      }

      return AppIcons.categoryHouseholdBills;
    }

    // -------------------------------------------------------------------------
    // TRANSPORTE
    // -------------------------------------------------------------------------

    if (_isTransport(categoryKey)) {
      if (_containsAny(subcategoryKey, ['gasolina', 'combustivel'])) {
        return AppIcons.transportFuel;
      }

      if (_containsAny(subcategoryKey, ['uber', '99', 'taxi', 'aplicativo'])) {
        return AppIcons.transportRide;
      }

      if (_containsAny(subcategoryKey, [
        'onibus',
        'transporte publico',
        'metro',
        'trem',
      ])) {
        return AppIcons.transportPublic;
      }

      if (_containsAny(subcategoryKey, ['estacionamento'])) {
        return AppIcons.transportParking;
      }

      if (_containsAny(subcategoryKey, ['pedagio'])) {
        return AppIcons.transportToll;
      }

      if (_containsAny(subcategoryKey, ['manutencao', 'oficina', 'revisao'])) {
        return AppIcons.transportMaintenance;
      }

      return AppIcons.categoryTransport;
    }

    // -------------------------------------------------------------------------
    // SAÚDE
    // -------------------------------------------------------------------------

    if (_isHealth(categoryKey)) {
      if (_containsAny(subcategoryKey, ['farmacia', 'medicamento'])) {
        return AppIcons.healthPharmacy;
      }

      if (_containsAny(subcategoryKey, ['consulta', 'medico'])) {
        return AppIcons.healthConsultation;
      }

      if (_containsAny(subcategoryKey, ['exame', 'exames'])) {
        return AppIcons.healthExams;
      }

      if (_containsAny(subcategoryKey, [
        'terapia',
        'psicologo',
        'psicologia',
      ])) {
        return AppIcons.healthTherapy;
      }

      if (_containsAny(subcategoryKey, ['academia', 'bem estar', 'fitness'])) {
        return AppIcons.healthGym;
      }

      return AppIcons.categoryHealth;
    }

    // -------------------------------------------------------------------------
    // EDUCAÇÃO
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['educacao'])) {
      if (_containsAny(subcategoryKey, ['faculdade', 'universidade'])) {
        return AppIcons.educationCollege;
      }

      if (_containsAny(subcategoryKey, ['curso', 'cursos'])) {
        return AppIcons.educationCourse;
      }

      if (_containsAny(subcategoryKey, ['livro', 'livros', 'material'])) {
        return AppIcons.educationBooks;
      }

      return AppIcons.categoryEducation;
    }

    // -------------------------------------------------------------------------
    // LAZER
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['lazer'])) {
      if (_containsAny(subcategoryKey, ['cinema', 'filme'])) {
        return AppIcons.leisureCinema;
      }

      if (_containsAny(subcategoryKey, ['passeio', 'passeios'])) {
        return AppIcons.leisureOuting;
      }

      if (_containsAny(subcategoryKey, [
        'evento',
        'eventos',
        'festa',
        'show',
      ])) {
        return AppIcons.leisureEvent;
      }

      if (_containsAny(subcategoryKey, ['hobby', 'hobbies'])) {
        return AppIcons.leisureHobby;
      }

      if (_containsAny(subcategoryKey, ['jogo', 'jogos', 'game'])) {
        return AppIcons.leisureGames;
      }

      return AppIcons.categoryLeisure;
    }

    // -------------------------------------------------------------------------
    // ASSINATURAS
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['assinatura', 'assinaturas'])) {
      if (_containsAny(subcategoryKey, [
        'streaming',
        'tv',
        'filmes',
        'series',
      ])) {
        return AppIcons.subscriptionStreaming;
      }

      if (_containsAny(subcategoryKey, ['musica'])) {
        return AppIcons.subscriptionMusic;
      }

      if (_containsAny(subcategoryKey, ['app', 'apps', 'aplicativo'])) {
        return AppIcons.subscriptionApps;
      }

      if (_containsAny(subcategoryKey, ['software'])) {
        return AppIcons.subscriptionSoftware;
      }

      return AppIcons.categorySubscriptions;
    }

    // -------------------------------------------------------------------------
    // COMPRAS
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['compras', 'compra'])) {
      if (_containsAny(subcategoryKey, ['online', 'internet'])) {
        return AppIcons.shoppingOnline;
      }

      if (_containsAny(subcategoryKey, ['casa'])) {
        return AppIcons.shoppingHome;
      }

      if (_containsAny(subcategoryKey, [
        'eletronico',
        'eletronicos',
        'tecnologia',
      ])) {
        return AppIcons.shoppingElectronics;
      }

      if (_containsAny(subcategoryKey, ['marketplace'])) {
        return AppIcons.shoppingMarketplace;
      }

      return AppIcons.categoryShopping;
    }

    // -------------------------------------------------------------------------
    // VESTUÁRIO
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['vestuario'])) {
      if (_containsAny(subcategoryKey, ['roupa', 'roupas'])) {
        return AppIcons.clothingClothes;
      }

      if (_containsAny(subcategoryKey, [
        'calcado',
        'calcados',
        'tenis',
        'sapato',
      ])) {
        return AppIcons.clothingShoes;
      }

      if (_containsAny(subcategoryKey, ['acessorio', 'acessorios'])) {
        return AppIcons.clothingAccessories;
      }

      return AppIcons.categoryClothing;
    }

    // -------------------------------------------------------------------------
    // BELEZA E CUIDADOS
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, [
      'beleza',
      'beleza e cuidados',
      'cuidados pessoais',
    ])) {
      if (_containsAny(subcategoryKey, ['cabelo', 'barbearia', 'salao'])) {
        return AppIcons.beautyHair;
      }

      if (_containsAny(subcategoryKey, [
        'cosmetico',
        'cosmeticos',
        'maquiagem',
      ])) {
        return AppIcons.beautyCosmetics;
      }

      if (_containsAny(subcategoryKey, ['estetica'])) {
        return AppIcons.beautyAesthetics;
      }

      if (_containsAny(subcategoryKey, ['cuidados', 'higiene'])) {
        return AppIcons.beautyPersonalCare;
      }

      return AppIcons.categoryBeauty;
    }

    // -------------------------------------------------------------------------
    // PRESENTES
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['presente', 'presentes'])) {
      if (_containsAny(subcategoryKey, [
        'data comemorativa',
        'aniversario',
        'natal',
      ])) {
        return AppIcons.giftsCelebration;
      }

      if (_containsAny(subcategoryKey, ['doacao', 'doacoes'])) {
        return AppIcons.giftsDonation;
      }

      return AppIcons.categoryGifts;
    }

    // -------------------------------------------------------------------------
    // FINANCEIRO
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, ['financeiro', 'banco'])) {
      if (_containsAny(subcategoryKey, ['tarifa', 'tarifas'])) {
        return AppIcons.financeBankFee;
      }

      if (_containsAny(subcategoryKey, ['juros'])) {
        return AppIcons.financeInterest;
      }

      if (_containsAny(subcategoryKey, ['iof', 'imposto', 'taxa'])) {
        return AppIcons.financeTax;
      }

      if (_containsAny(subcategoryKey, ['ajuste'])) {
        return AppIcons.financeAdjustment;
      }

      return AppIcons.categoryFinance;
    }

    // -------------------------------------------------------------------------
    // DÍVIDAS E EMPRÉSTIMOS
    // -------------------------------------------------------------------------

    if (_containsAny(categoryKey, [
      'dividas',
      'divida',
      'emprestimos',
      'emprestimo',
    ])) {
      if (_containsAny(subcategoryKey, ['emprestimo'])) {
        return AppIcons.debtLoan;
      }

      if (_containsAny(subcategoryKey, ['parcelamento', 'parcelamentos'])) {
        return AppIcons.debtInstallment;
      }

      if (_containsAny(subcategoryKey, ['financiamento', 'financiamentos'])) {
        return AppIcons.debtFinancing;
      }

      if (_containsAny(subcategoryKey, ['acordo', 'acordos'])) {
        return AppIcons.debtAgreement;
      }

      return AppIcons.categoryDebt;
    }

    return AppIcons.categoryUnclassified;
  }

  static Color colorFor({
    required String category,
    required Brightness brightness,
  }) {
    final key = _normalize(category);
    final dark = brightness == Brightness.dark;

    if (_isFood(key) ||
        _containsAny(key, ['restaurante', 'delivery', 'supermercado'])) {
      return dark ? AppColors.foodDark : AppColors.foodLight;
    }

    if (_isHousing(key)) {
      return dark ? AppColors.homeDark : AppColors.homeLight;
    }

    if (_isHouseholdBills(key) ||
        _containsAny(key, ['agua', 'energia', 'internet', 'telefone'])) {
      return dark ? AppColors.transportDark : AppColors.transportLight;
    }

    if (_isTransport(key) || _containsAny(key, ['gasolina'])) {
      return dark ? AppColors.transportDark : AppColors.transportLight;
    }

    if (_isHealth(key) || _containsAny(key, ['farmacia'])) {
      return dark ? AppColors.healthDark : AppColors.healthLight;
    }

    if (_containsAny(key, [
      'educacao',
      'assinatura',
      'assinaturas',
      'vestuario',
    ])) {
      return dark ? AppColors.foodDark : AppColors.foodLight;
    }

    if (_containsAny(key, ['beleza', 'compras', 'compras online', 'lazer'])) {
      return dark ? AppColors.homeDark : AppColors.homeLight;
    }

    if (_containsAny(key, [
      'presente',
      'presentes',
      'dividas',
      'divida',
      'emprestimo',
      'emprestimos',
    ])) {
      return dark ? AppColors.healthDark : AppColors.healthLight;
    }

    if (_containsAny(key, ['financeiro', 'tarifas bancarias'])) {
      return dark ? AppColors.transportDark : AppColors.transportLight;
    }

    return AppColors.secondaryText(brightness);
  }

  /// Descobre a futura categoria principal de uma categoria antiga.
  ///
  /// Isso será útil durante a migração do banco.
  static String canonicalCategory(String category) {
    final key = _normalize(category);

    if (_containsAny(key, ['restaurante', 'delivery', 'supermercado'])) {
      return 'Alimentação';
    }

    if (_containsAny(key, ['agua', 'energia', 'internet', 'telefone'])) {
      return 'Contas da casa';
    }

    if (_containsAny(key, ['farmacia'])) {
      return 'Saúde';
    }

    if (_containsAny(key, ['gasolina'])) {
      return 'Transporte';
    }

    if (_containsAny(key, ['compras online'])) {
      return 'Compras';
    }

    if (_containsAny(key, ['tarifas bancarias'])) {
      return 'Financeiro';
    }

    if (_containsAny(key, ['emprestimos', 'emprestimo'])) {
      return 'Dívidas e empréstimos';
    }

    return category;
  }

  /// Descobre a futura subcategoria de uma categoria antiga.
  static String? canonicalSubcategory(String category) {
    final key = _normalize(category);

    if (_containsAny(key, ['restaurante'])) {
      return 'Restaurante';
    }

    if (_containsAny(key, ['delivery'])) {
      return 'Delivery';
    }

    if (_containsAny(key, ['supermercado'])) {
      return 'Supermercado';
    }

    if (_containsAny(key, ['agua'])) {
      return 'Água';
    }

    if (_containsAny(key, ['energia'])) {
      return 'Energia';
    }

    if (_containsAny(key, ['internet', 'telefone'])) {
      return 'Internet / telefone';
    }

    if (_containsAny(key, ['farmacia'])) {
      return 'Farmácia';
    }

    if (_containsAny(key, ['gasolina'])) {
      return 'Gasolina';
    }

    if (_containsAny(key, ['compras online'])) {
      return 'Compras online';
    }

    if (_containsAny(key, ['tarifas bancarias'])) {
      return 'Tarifas bancárias';
    }

    if (_containsAny(key, ['emprestimos', 'emprestimo'])) {
      return 'Empréstimos';
    }

    return null;
  }

  // ---------------------------------------------------------------------------
  // IDENTIFICAÇÃO DAS FAMÍLIAS
  // ---------------------------------------------------------------------------

  static bool _isFood(String value) {
    return _containsAny(value, ['alimentacao', 'comida']);
  }

  static bool _isHousing(String value) {
    return _containsAny(value, ['moradia', 'habitacao']);
  }

  static bool _isHouseholdBills(String value) {
    return _containsAny(value, ['contas da casa', 'contas domesticas']);
  }

  static bool _isTransport(String value) {
    return _containsAny(value, ['transporte']);
  }

  static bool _isHealth(String value) {
    return _containsAny(value, ['saude']);
  }

  // ---------------------------------------------------------------------------
  // NORMALIZAÇÃO
  // ---------------------------------------------------------------------------

  static bool _containsAny(String value, List<String> possibilities) {
    for (final possibility in possibilities) {
      if (value.contains(_normalize(possibility))) {
        return true;
      }
    }

    return false;
  }

  static String _normalize(String value) {
    return value
        .trim()
        .toLowerCase()
        .replaceAll('á', 'a')
        .replaceAll('à', 'a')
        .replaceAll('â', 'a')
        .replaceAll('ã', 'a')
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
