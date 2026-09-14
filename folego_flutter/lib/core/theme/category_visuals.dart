import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_icons.dart';

class CategoryVisualData {
  const CategoryVisualData({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Fonte única de verdade para o visual de categorias.
///
/// Regras:
/// - categoria principal = ícone oficial + cor da família;
/// - subcategoria = ícone próprio quando mapeado + cor da categoria pai;
/// - subcategoria sem ícone próprio herda o ícone da categoria pai;
/// - receitas usam a semântica visual oficial de receita do Fôlego;
/// - telas não devem criar mapas locais de categoria.
class CategoryVisuals {
  static const Set<String> _incomeCategoryKeys = {
    'adiantamento',
    'bonificacao',
    'bonus',
    'comissao',
    'comissoes',
    'freela',
    'freelance',
    'outra receita',
    'outras receitas',
    'presente recebido',
    'receita',
    'receitas',
    'renda',
    'rendimento',
    'rendimentos',
    'salario',
    'trabalho extra',
    'venda',
    'vendas',
  };

  static CategoryVisualData resolve({
    required Brightness brightness,
    String? category,
    String? subcategory,
    String? eventType,
  }) {
    final categoryName = category == null || category.trim().isEmpty
        ? 'A classificar'
        : category.trim();

    return CategoryVisualData(
      icon: iconFor(
        category: categoryName,
        subcategory: subcategory,
        eventType: eventType,
      ),
      color: colorFor(
        category: categoryName,
        brightness: brightness,
        eventType: eventType,
      ),
    );
  }

  static IconData iconFor({
    String? category,
    String? subcategory,
    String? eventType,
  }) {
    final c = _normalize(category);
    final s = _normalize(subcategory);

    // =========================================================
    // SUBCATEGORIAS
    // =========================================================

    if (s != null) {
      switch (s) {
        // ALIMENTAÇÃO
        case 'supermercado':
        case 'mercado':
          return AppIcons.foodSupermarket;

        case 'restaurante':
          return AppIcons.foodRestaurant;

        case 'delivery':
        case 'ifood':
          return AppIcons.foodDelivery;

        case 'cafe / lanche':
        case 'cafe':
        case 'lanche':
          return AppIcons.foodCafe;

        // ASSINATURAS
        case 'apps':
          return AppIcons.subscriptionApps;

        case 'musica':
          return AppIcons.subscriptionMusic;

        case 'software':
          return AppIcons.subscriptionSoftware;

        case 'streaming':
          return AppIcons.subscriptionStreaming;

        // BELEZA E CUIDADOS
        case 'cabelo / barbearia':
        case 'cabelo':
        case 'barbearia':
          return AppIcons.beautyHair;

        case 'cosmeticos':
          return AppIcons.beautyCosmetics;

        case 'cuidados pessoais':
          return AppIcons.beautyPersonalCare;

        case 'estetica':
          return AppIcons.beautyAesthetics;

        // COMPRAS
        case 'casa':
          return AppIcons.shoppingHome;

        case 'compras online':
          return AppIcons.shoppingOnline;

        case 'eletronicos':
          return AppIcons.shoppingElectronics;

        case 'marketplace':
          return AppIcons.shoppingMarketplace;

        // CONTAS DA CASA
        case 'agua':
          return AppIcons.billsWater;

        case 'energia':
          return AppIcons.billsEnergy;

        case 'gas':
          return AppIcons.billsGas;

        case 'internet / telefone':
        case 'internet':
          return AppIcons.billsInternet;

        case 'telefone':
          return AppIcons.billsPhone;

        // DÍVIDAS E EMPRÉSTIMOS
        case 'acordos':
          return AppIcons.debtAgreement;

        case 'emprestimos':
        case 'emprestimo':
          return AppIcons.debtLoan;

        case 'financiamentos':
        case 'financiamento':
          return AppIcons.debtFinancing;

        case 'parcelamentos':
        case 'parcelamento':
          return AppIcons.debtInstallment;

        // EDUCAÇÃO
        case 'cursos':
        case 'curso':
          return AppIcons.educationCourse;

        case 'faculdade':
          return AppIcons.educationCollege;

        case 'livros / material':
        case 'livros':
          return AppIcons.educationBooks;

        // FINANCEIRO
        case 'ajustes financeiros':
        case 'ajuste':
          return AppIcons.financeAdjustment;

        case 'iof / taxas':
        case 'iof':
        case 'taxas':
          return AppIcons.financeTax;

        case 'juros':
          return AppIcons.financeInterest;

        case 'tarifas bancarias':
          return AppIcons.financeBankFee;

        // LAZER
        case 'cinema':
          return AppIcons.leisureCinema;

        case 'eventos':
          return AppIcons.leisureEvent;

        case 'hobbies':
          return AppIcons.leisureHobby;

        case 'jogos':
          return AppIcons.leisureGames;

        case 'passeios':
          return AppIcons.leisureOuting;

        // MORADIA / TRANSPORTE
        // "Manutenção" existe nas duas famílias e usa o mesmo glyph oficial.
        case 'manutencao':
          return AppIcons.housingMaintenance;

        // MORADIA
        case 'aluguel':
          return AppIcons.housingRent;

        case 'condominio':
          return AppIcons.housingCondo;

        case 'moveis / utilidades':
        case 'moveis':
          return AppIcons.housingFurniture;

        // PRESENTES
        case 'datas comemorativas':
          return AppIcons.giftsCelebration;

        case 'doacoes':
          return AppIcons.giftsDonation;

        // SAÚDE
        case 'academia / bem-estar':
        case 'academia':
          return AppIcons.healthGym;

        case 'consulta':
          return AppIcons.healthConsultation;

        case 'exames':
          return AppIcons.healthExams;

        case 'farmacia':
          return AppIcons.healthPharmacy;

        case 'terapia':
          return AppIcons.healthTherapy;

        // TRANSPORTE
        case 'estacionamento / pedagio':
        case 'estacionamento':
          return AppIcons.transportParking;

        case 'pedagio':
          return AppIcons.transportToll;

        case 'gasolina':
        case 'combustivel':
          return AppIcons.transportFuel;

        case 'transporte publico':
          return AppIcons.transportPublic;

        case 'uber / taxi':
        case 'uber':
        case 'taxi':
          return AppIcons.transportRide;

        // VESTUÁRIO
        case 'acessorios':
          return AppIcons.clothingAccessories;

        case 'calcados':
          return AppIcons.clothingShoes;

        case 'roupas':
          return AppIcons.clothingClothes;
      }
    }

    // =========================================================
    // CATEGORIAS PRINCIPAIS DE DESPESA
    // =========================================================

    switch (c) {
      case 'a classificar':
        return AppIcons.categoryUnclassified;

      case 'alimentacao':
        return AppIcons.categoryFood;

      case 'assinaturas':
        return AppIcons.categorySubscriptions;

      case 'beleza e cuidados':
      case 'beleza':
        return AppIcons.categoryBeauty;

      case 'compras':
        return AppIcons.categoryShopping;

      case 'contas da casa':
        return AppIcons.categoryHouseholdBills;

      case 'dividas e emprestimos':
      case 'dividas':
      case 'emprestimos':
        return AppIcons.categoryDebt;

      case 'educacao':
        return AppIcons.categoryEducation;

      case 'financeiro':
        return AppIcons.categoryFinance;

      case 'lazer':
        return AppIcons.categoryLeisure;

      case 'moradia':
      case 'casa':
        return AppIcons.categoryHousing;

      case 'presentes':
        return AppIcons.categoryGifts;

      case 'saude':
        return AppIcons.categoryHealth;

      case 'transporte':
        return AppIcons.categoryTransport;

      case 'vestuario':
        return AppIcons.categoryClothing;

      case 'viagens':
        return AppIcons.categoryTravel;

      case 'outros':
      case 'outros gastos':
        return AppIcons.categoryOther;
    }

    // =========================================================
    // CATEGORIAS DE RECEITA
    // =========================================================

    if (c != null && _incomeCategoryKeys.contains(c)) {
      switch (c) {
        case 'adiantamento':
          return AppIcons.debtInstallment;

        case 'bonificacao':
        case 'bonus':
          return AppIcons.achievements;

        case 'comissao':
        case 'comissoes':
          return AppIcons.financeInterest;

        case 'freela':
        case 'freelance':
          return AppIcons.journal;

        case 'outra receita':
        case 'outras receitas':
        case 'receita':
        case 'receitas':
        case 'renda':
          return AppIcons.income;

        case 'presente recebido':
          return AppIcons.giftsPresent;

        case 'rendimento':
        case 'rendimentos':
          return AppIcons.categoryFinance;

        case 'salario':
          return AppIcons.cash;

        case 'trabalho extra':
          return AppIcons.shoppingElectronics;

        case 'venda':
        case 'vendas':
          return AppIcons.categoryShopping;
      }
    }

    // =========================================================
    // OUTROS TIPOS / FALLBACK PELO EVENTO
    // =========================================================

    switch (c) {
      case 'transferencia':
      case 'transferencias':
        return AppIcons.transfer;

      case 'saldo inicial':
      case 'ajustes':
        return AppIcons.wallet;
    }

    switch (eventType) {
      case 'income':
        return AppIcons.income;

      case 'expense':
      case 'benefit_expense':
        return AppIcons.expense;

      case 'transfer':
        return AppIcons.transfer;

      case 'card_purchase':
        return AppIcons.creditCard;

      case 'card_payment':
        return AppIcons.expense;

      case 'opening_balance':
        return AppIcons.wallet;

      case 'debt_payment':
        return AppIcons.categoryDebt;

      default:
        return AppIcons.categoryUnclassified;
    }
  }

  static Color colorFor({
    required String category,
    required Brightness brightness,
    String? eventType,
  }) {
    final c = _normalize(category) ?? 'a classificar';

    if (_incomeCategoryKeys.contains(c) || eventType == 'income') {
      return AppColors.positiveText(brightness);
    }

    final isDark = brightness == Brightness.dark;

    switch (c) {
      // ROXO ELÉTRICO
      case 'alimentacao':
        return isDark ? const Color(0xFF9B7BFF) : const Color(0xFF6C3CE9);

      // AZUL NEON
      case 'assinaturas':
        return isDark ? const Color(0xFF53B9FF) : const Color(0xFF1774B8);

      // ROSA NEON
      case 'beleza e cuidados':
      case 'beleza':
        return isDark ? const Color(0xFFFF62B0) : const Color(0xFFD4457A);

      // AMARELO NEON
      case 'compras':
        return isDark ? const Color(0xFFFFD84D) : const Color(0xFF9A6A00);

      // LARANJA NEON
      case 'contas da casa':
        return isDark ? const Color(0xFFFF9F43) : const Color(0xFFB35A00);

      // VERMELHO-CORAL NEON
      case 'dividas e emprestimos':
      case 'dividas':
      case 'emprestimos':
        return isDark ? const Color(0xFFFF6B6B) : const Color(0xFFB33A3A);

      // AZUL-ÍNDIGO NEON
      case 'educacao':
        return isDark ? const Color(0xFF7C8CFF) : const Color(0xFF4A57C8);

      // TURQUESA NEON
      case 'financeiro':
        return isDark ? const Color(0xFF4DE1C1) : const Color(0xFF16816D);

      // VIOLETA NEON
      case 'lazer':
        return isDark ? const Color(0xFFC96BFF) : const Color(0xFF8242B5);

      // VERDE-MENTA NEON
      case 'moradia':
      case 'casa':
        return isDark ? const Color(0xFF6FE7A1) : const Color(0xFF2C8B55);

      // CORAL / PÊSSEGO NEON
      case 'presentes':
        return isDark ? const Color(0xFFFF8A70) : const Color(0xFFB84F3B);

      // MAGENTA-VERMELHO NEON
      case 'saude':
        return isDark ? const Color(0xFFFF7A9C) : const Color(0xFFB93E66);

      // LIME — assinatura do FÔLEGO
      case 'transporte':
        return isDark ? const Color(0xFFC6F135) : const Color(0xFF5E7F14);

      // CIANO NEON
      case 'vestuario':
        return isDark ? const Color(0xFF5DDCFF) : const Color(0xFF247B95);

      // CIANO ELÉTRICO — VIAGENS
      case 'viagens':
        return isDark ? const Color(0xFF4FEAFF) : const Color(0xFF167D91);

      // NEUTRO — OUTROS
      case 'outros':
      case 'outros gastos':
        return isDark ? const Color(0xFFB5B2C0) : const Color(0xFF6B6656);

      // TRANSFERÊNCIAS — CIANO ELÉTRICO
      case 'transferencia':
      case 'transferencias':
        return isDark ? const Color(0xFF4FEAFF) : const Color(0xFF167D91);

      // AJUSTES — LILÁS NEON
      case 'saldo inicial':
      case 'ajustes':
        return isDark ? const Color(0xFFB79CFF) : const Color(0xFF7054B8);

      // NEUTRO
      case 'a classificar':
      default:
        return isDark ? const Color(0xFF9B98A8) : const Color(0xFF6B6656);
    }
  }

  static String canonicalCategory(String value) {
    final normalized = _normalize(value);

    switch (normalized) {
      case 'a classificar':
        return 'A classificar';

      case 'alimentacao':
        return 'Alimentação';

      case 'assinaturas':
        return 'Assinaturas';

      case 'beleza e cuidados':
      case 'beleza':
        return 'Beleza e cuidados';

      case 'compras':
        return 'Compras';

      case 'contas da casa':
        return 'Contas da casa';

      case 'dividas e emprestimos':
      case 'dividas':
      case 'emprestimos':
        return 'Dívidas e empréstimos';

      case 'educacao':
        return 'Educação';

      case 'financeiro':
        return 'Financeiro';

      case 'lazer':
        return 'Lazer';

      case 'moradia':
      case 'casa':
        return 'Moradia';

      case 'presentes':
        return 'Presentes';

      case 'saude':
        return 'Saúde';

      case 'transporte':
        return 'Transporte';

      case 'vestuario':
        return 'Vestuário';

      case 'viagens':
        return 'Viagens';

      case 'outros':
      case 'outros gastos':
        return 'Outros';

      case 'adiantamento':
        return 'Adiantamento';

      case 'bonificacao':
      case 'bonus':
        return 'Bonificação';

      case 'comissao':
      case 'comissoes':
        return 'Comissões';

      case 'freela':
      case 'freelance':
        return 'Freelance';

      case 'outra receita':
      case 'outras receitas':
        return 'Outras receitas';

      case 'presente recebido':
        return 'Presente recebido';

      case 'rendimento':
      case 'rendimentos':
        return 'Rendimentos';

      case 'salario':
        return 'Salário';

      case 'trabalho extra':
        return 'Trabalho extra';

      case 'venda':
      case 'vendas':
        return 'Venda';

      case 'receita':
      case 'receitas':
      case 'renda':
        return 'Receitas';

      case 'transferencia':
      case 'transferencias':
        return 'Transferências';

      case 'saldo inicial':
      case 'ajustes':
        return 'Ajustes';

      default:
        return value.trim();
    }
  }

  static String canonicalSubcategory(String value) {
    return value.trim();
  }

  static String? _normalize(String? value) {
    if (value == null) {
      return null;
    }

    final text = value.trim().toLowerCase();

    if (text.isEmpty) {
      return null;
    }

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
