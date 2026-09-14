import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_icons.dart';

class CategoryVisualData {
  const CategoryVisualData({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

/// Fonte única de verdade do visual da taxonomia do Fôlego.
/// Subcategorias herdam a cor da família e podem ter um glyph específico.
class CategoryVisuals {
  static const Set<String> _incomeCategoryKeys = {
    'receita',
    'receitas',
    'renda',
    'salario',
    'adiantamento',
    'adiantamento salarial',
    'freela',
    'freelance',
    'freelance / trabalho extra',
    'trabalho extra',
    'comissao',
    'comissoes',
    'bonus',
    'bonificacao',
    'bonus / bonificacao',
    'venda',
    'vendas',
    'aluguel recebido',
    'rendimento',
    'rendimentos',
    'rendimentos de investimentos',
    'presente recebido',
    'reembolso recebido',
    'outra receita',
    'outras receitas',
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

    if (s != null) {
      final subIcon = _subcategoryIcon(s);
      if (subIcon != null) return subIcon;
    }

    switch (c) {
      case 'a classificar':
        return AppIcons.categoryUnclassified;
      case 'alimentacao':
        return AppIcons.categoryFood;
      case 'assinaturas':
      case 'assinaturas e servicos':
        return AppIcons.categorySubscriptions;
      case 'beleza':
      case 'beleza e cuidados':
      case 'beleza & cuidados':
      case 'cuidados pessoais':
        return AppIcons.categoryBeauty;
      case 'compras':
        return AppIcons.categoryShopping;
      case 'contas da casa':
        return AppIcons.categoryHouseholdBills;
      case 'dividas':
      case 'dividas e emprestimos':
      case 'dividas & financiamentos':
      case 'emprestimos':
        return AppIcons.categoryDebt;
      case 'educacao':
        return AppIcons.categoryEducation;
      case 'financeiro':
      case 'financeiro & impostos':
        return AppIcons.categoryFinance;
      case 'lazer':
      case 'lazer & entretenimento':
        return AppIcons.categoryLeisure;
      case 'moradia':
      case 'casa':
        return AppIcons.categoryHousing;
      case 'presentes':
      case 'presentes & doacoes':
        return AppIcons.categoryGifts;
      case 'saude':
      case 'saude & bem-estar':
        return AppIcons.categoryHealth;
      case 'transporte':
        return AppIcons.categoryTransport;
      case 'vestuario':
        return AppIcons.categoryClothing;
      case 'familia e pets':
      case 'familia & dependentes':
        return AppIcons.categoryFamily;
      case 'pets':
        return AppIcons.categoryPets;
      case 'seguros':
        return AppIcons.categoryInsurance;
      case 'viagens':
        return AppIcons.categoryTravel;
      case 'outros':
      case 'outros gastos':
        return AppIcons.categoryOther;
    }

    if (c != null && _incomeCategoryKeys.contains(c)) {
      return _incomeIcon(c);
    }

    switch (c) {
      case 'transferencia':
      case 'transferencias':
        return AppIcons.transfer;
      case 'saldo inicial':
      case 'ajustes':
        return AppIcons.wallet;
    }

    return switch (eventType) {
      'income' => AppIcons.income,
      'expense' || 'benefit_expense' => AppIcons.expense,
      'transfer' => AppIcons.transfer,
      'card_purchase' => AppIcons.creditCard,
      'card_payment' => AppIcons.expense,
      'opening_balance' => AppIcons.wallet,
      'debt_payment' => AppIcons.categoryDebt,
      _ => AppIcons.categoryUnclassified,
    };
  }

  static IconData? _subcategoryIcon(String s) {
    switch (s) {
      // Alimentação
      case 'supermercado':
      case 'mercado':
        return AppIcons.foodSupermarket;
      case 'restaurante':
      case 'restaurantes':
        return AppIcons.foodRestaurant;
      case 'delivery':
      case 'ifood':
        return AppIcons.foodDelivery;
      case 'cafe':
      case 'cafe / lanche':
      case 'lanche':
        return AppIcons.foodCafe;

      // Assinaturas
      case 'apps':
        return AppIcons.subscriptionApps;
      case 'musica':
        return AppIcons.subscriptionMusic;
      case 'software':
        return AppIcons.subscriptionSoftware;
      case 'streaming':
        return AppIcons.subscriptionStreaming;
      case 'nuvem / armazenamento':
      case 'noticias / conteudo':
      case 'outros servicos digitais':
        return AppIcons.subscriptionOther;

      // Beleza
      case 'cabelo':
      case 'barbearia':
      case 'cabelo / barbearia':
        return AppIcons.beautyHair;
      case 'cosmeticos':
        return AppIcons.beautyCosmetics;
      case 'cuidados pessoais':
      case 'lavanderia':
        return AppIcons.beautyPersonalCare;
      case 'estetica':
        return AppIcons.beautyAesthetics;

      // Compras
      case 'casa':
      case 'casa / decoracao':
        return AppIcons.shoppingHome;
      case 'compras online':
        return AppIcons.shoppingOnline;
      case 'eletronicos':
        return AppIcons.shoppingElectronics;
      case 'marketplace':
        return AppIcons.shoppingMarketplace;
      case 'outros produtos':
        return AppIcons.shoppingOther;
      case 'acessorios':
        return AppIcons.clothingAccessories;
      case 'calcados':
        return AppIcons.clothingShoes;
      case 'roupas':
        return AppIcons.clothingClothes;

      // Casa
      case 'agua':
        return AppIcons.billsWater;
      case 'energia':
        return AppIcons.billsEnergy;
      case 'gas':
        return AppIcons.billsGas;
      case 'internet':
      case 'internet / telefone':
        return AppIcons.billsInternet;
      case 'telefone':
        return AppIcons.billsPhone;
      case 'aluguel':
        return AppIcons.housingRent;
      case 'condominio':
        return AppIcons.housingCondo;
      case 'manutencao':
      case 'manutencao / reparos':
      case 'manutencao do veiculo':
        return AppIcons.housingMaintenance;
      case 'moveis':
      case 'moveis / utilidades':
      case 'moveis / decoracao':
        return AppIcons.housingFurniture;

      // Transporte
      case 'estacionamento':
      case 'estacionamento / pedagio':
        return AppIcons.transportParking;
      case 'pedagio':
        return AppIcons.transportToll;
      case 'gasolina':
      case 'combustivel':
        return AppIcons.transportFuel;
      case 'transporte publico':
        return AppIcons.transportPublic;
      case 'uber':
      case 'taxi':
      case 'uber / taxi':
        return AppIcons.transportRide;

      // Saúde
      case 'academia':
      case 'academia / bem-estar':
        return AppIcons.healthGym;
      case 'consulta':
      case 'consultas':
        return AppIcons.healthConsultation;
      case 'exame':
      case 'exames':
        return AppIcons.healthExams;
      case 'farmacia':
      case 'medicamentos':
        return AppIcons.healthPharmacy;
      case 'terapia':
        return AppIcons.healthTherapy;

      // Educação
      case 'curso':
      case 'cursos':
      case 'certificacoes':
        return AppIcons.educationCourse;
      case 'faculdade':
      case 'escola / faculdade':
      case 'escola / creche':
        return AppIcons.educationCollege;
      case 'livros':
      case 'livros / material':
        return AppIcons.educationBooks;

      // Lazer
      case 'cinema':
        return AppIcons.leisureCinema;
      case 'eventos':
      case 'eventos / shows':
      case 'baladas / festas':
        return AppIcons.leisureEvent;
      case 'hobbies':
        return AppIcons.leisureHobby;
      case 'jogos':
        return AppIcons.leisureGames;
      case 'passeios':
      case 'passeios / atracoes':
        return AppIcons.leisureOuting;

      // Presentes / financeiro / dívidas
      case 'datas comemorativas':
        return AppIcons.giftsCelebration;
      case 'doacoes':
        return AppIcons.giftsDonation;
      case 'presentes':
        return AppIcons.giftsPresent;
      case 'ajustes financeiros':
      case 'ajuste':
        return AppIcons.financeAdjustment;
      case 'iof':
      case 'iof / taxas':
      case 'taxas':
        return AppIcons.financeTax;
      case 'juros':
        return AppIcons.financeInterest;
      case 'tarifas bancarias':
      case 'contabilidade':
        return AppIcons.financeBankFee;
      case 'acordos':
      case 'acordos / renegociacoes':
        return AppIcons.debtAgreement;
      case 'emprestimo':
      case 'emprestimos':
        return AppIcons.debtLoan;
      case 'financiamento':
      case 'financiamentos':
        return AppIcons.debtFinancing;
      case 'parcelamento':
      case 'parcelamentos':
        return AppIcons.debtInstallment;

      // Viagens
      case 'passagens':
      case 'hospedagem':
      case 'transporte local':
      case 'alimentacao em viagem':
      case 'seguro viagem':
      case 'taxas':
        return AppIcons.categoryTravel;
    }
    return null;
  }

  static IconData _incomeIcon(String c) {
    switch (c) {
      case 'adiantamento':
      case 'adiantamento salarial':
        return AppIcons.debtInstallment;
      case 'bonificacao':
      case 'bonus':
      case 'bonus / bonificacao':
        return AppIcons.achievements;
      case 'comissao':
      case 'comissoes':
        return AppIcons.financeInterest;
      case 'freela':
      case 'freelance':
      case 'freelance / trabalho extra':
      case 'trabalho extra':
        return AppIcons.journal;
      case 'presente recebido':
        return AppIcons.giftsPresent;
      case 'rendimento':
      case 'rendimentos':
      case 'rendimentos de investimentos':
        return AppIcons.categoryFinance;
      case 'salario':
        return AppIcons.cash;
      case 'venda':
      case 'vendas':
        return AppIcons.categoryShopping;
      default:
        return AppIcons.income;
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
      case 'alimentacao':
        return isDark ? const Color(0xFF9B7BFF) : const Color(0xFF6C3CE9);
      case 'assinaturas':
      case 'assinaturas e servicos':
        return isDark ? const Color(0xFF53B9FF) : const Color(0xFF1774B8);
      case 'beleza':
      case 'beleza e cuidados':
      case 'beleza & cuidados':
        return isDark ? const Color(0xFFFF62B0) : const Color(0xFFD4457A);
      case 'compras':
        return isDark ? const Color(0xFFFFD84D) : const Color(0xFF9A6A00);
      case 'contas da casa':
        return isDark ? const Color(0xFFFF9F43) : const Color(0xFFB35A00);
      case 'dividas':
      case 'dividas e emprestimos':
      case 'dividas & financiamentos':
      case 'emprestimos':
        return isDark ? const Color(0xFFFF6B6B) : const Color(0xFFB33A3A);
      case 'educacao':
        return isDark ? const Color(0xFF7C8CFF) : const Color(0xFF4A57C8);
      case 'financeiro':
      case 'financeiro & impostos':
      case 'familia & dependentes':
        return isDark ? const Color(0xFF4DE1C1) : const Color(0xFF16816D);
      case 'lazer':
      case 'lazer & entretenimento':
        return isDark ? const Color(0xFFC96BFF) : const Color(0xFF8242B5);
      case 'moradia':
      case 'casa':
        return isDark ? const Color(0xFF6FE7A1) : const Color(0xFF2C8B55);
      case 'presentes':
      case 'presentes & doacoes':
        return isDark ? const Color(0xFFFF8A70) : const Color(0xFFB84F3B);
      case 'saude':
      case 'saude & bem-estar':
        return isDark ? const Color(0xFFFF7A9C) : const Color(0xFFB93E66);
      case 'transporte':
        return isDark ? const Color(0xFFC6F135) : const Color(0xFF5E7F14);
      case 'vestuario':
      case 'pets':
        return isDark ? const Color(0xFF5DDCFF) : const Color(0xFF247B95);
      case 'viagens':
        return isDark ? const Color(0xFF4FEAFF) : const Color(0xFF167D91);
      case 'seguros':
        return isDark ? const Color(0xFFB79CFF) : const Color(0xFF7054B8);
      case 'outros':
      case 'outros gastos':
        return isDark ? const Color(0xFFB5B2C0) : const Color(0xFF6B6656);
      case 'transferencia':
      case 'transferencias':
        return isDark ? const Color(0xFF4FEAFF) : const Color(0xFF167D91);
      case 'saldo inicial':
      case 'ajustes':
        return isDark ? const Color(0xFFB79CFF) : const Color(0xFF7054B8);
      default:
        return isDark ? const Color(0xFF9B98A8) : const Color(0xFF6B6656);
    }
  }

  static String canonicalCategory(String value) {
    final normalized = _normalize(value);
    switch (normalized) {
      case 'a classificar': return 'A classificar';
      case 'alimentacao': return 'Alimentação';
      case 'assinaturas':
      case 'assinaturas e servicos': return 'Assinaturas';
      case 'beleza':
      case 'beleza e cuidados':
      case 'beleza & cuidados': return 'Beleza & cuidados';
      case 'compras': return 'Compras';
      case 'contas da casa': return 'Contas da casa';
      case 'dividas':
      case 'dividas e emprestimos':
      case 'dividas & financiamentos': return 'Dívidas & financiamentos';
      case 'educacao': return 'Educação';
      case 'financeiro':
      case 'financeiro & impostos': return 'Financeiro & impostos';
      case 'lazer':
      case 'lazer & entretenimento': return 'Lazer & entretenimento';
      case 'moradia':
      case 'casa': return 'Moradia';
      case 'presentes':
      case 'presentes & doacoes': return 'Presentes & doações';
      case 'saude':
      case 'saude & bem-estar': return 'Saúde & bem-estar';
      case 'transporte': return 'Transporte';
      case 'vestuario': return 'Compras';
      case 'familia e pets':
      case 'familia & dependentes': return 'Família & dependentes';
      case 'pets': return 'Pets';
      case 'seguros': return 'Seguros';
      case 'viagens': return 'Viagens';
      case 'outros':
      case 'outros gastos': return 'Outros gastos';
      case 'receita':
      case 'receitas':
      case 'renda': return 'Receitas';
      case 'salario': return 'Salário';
      case 'adiantamento':
      case 'adiantamento salarial': return 'Adiantamento salarial';
      case 'freela':
      case 'freelance':
      case 'freelance / trabalho extra':
      case 'trabalho extra': return 'Freelance / trabalho extra';
      case 'comissao':
      case 'comissoes': return 'Comissões';
      case 'bonificacao':
      case 'bonus':
      case 'bonus / bonificacao': return 'Bônus / bonificação';
      case 'venda':
      case 'vendas': return 'Venda';
      case 'aluguel recebido': return 'Aluguel recebido';
      case 'rendimento':
      case 'rendimentos':
      case 'rendimentos de investimentos': return 'Rendimentos de investimentos';
      case 'presente recebido': return 'Presente recebido';
      case 'reembolso recebido': return 'Reembolso recebido';
      case 'outra receita':
      case 'outras receitas': return 'Outras receitas';
      case 'transferencia':
      case 'transferencias': return 'Transferências';
      case 'saldo inicial':
      case 'ajustes': return 'Ajustes';
      default: return value.trim();
    }
  }

  static String canonicalSubcategory(String value) => value.trim();

  static String? _normalize(String? value) {
    if (value == null) return null;
    final text = value.trim().toLowerCase();
    if (text.isEmpty) return null;
    return text
        .replaceAll('á', 'a').replaceAll('à', 'a').replaceAll('ã', 'a')
        .replaceAll('â', 'a').replaceAll('ä', 'a')
        .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e').replaceAll('ë', 'e')
        .replaceAll('í', 'i').replaceAll('ì', 'i').replaceAll('î', 'i').replaceAll('ï', 'i')
        .replaceAll('ó', 'o').replaceAll('ò', 'o').replaceAll('ô', 'o').replaceAll('õ', 'o').replaceAll('ö', 'o')
        .replaceAll('ú', 'u').replaceAll('ù', 'u').replaceAll('û', 'u').replaceAll('ü', 'u')
        .replaceAll('ç', 'c');
  }
}
