import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

class CategoryVisualData {
  const CategoryVisualData({required this.icon, required this.color});

  final IconData icon;
  final Color color;
}

class CategoryVisuals {
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
      color: colorFor(category: categoryName, brightness: brightness),
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
          return TablerIcons.shoppingCart;

        case 'restaurante':
          return TablerIcons.toolsKitchen;

        case 'delivery':
        case 'ifood':
          return TablerIcons.motorbike;

        case 'cafe / lanche':
        case 'cafe':
        case 'lanche':
          return TablerIcons.coffee;

        // ASSINATURAS
        case 'apps':
          return TablerIcons.apps;

        case 'musica':
          return TablerIcons.music;

        case 'software':
          return TablerIcons.code;

        case 'streaming':
          return TablerIcons.deviceTv;

        // BELEZA E CUIDADOS
        case 'cabelo / barbearia':
        case 'cabelo':
        case 'barbearia':
          return TablerIcons.scissors;

        case 'cosmeticos':
          return TablerIcons.brush;

        case 'cuidados pessoais':
          return TablerIcons.heart;

        case 'estetica':
          return TablerIcons.sparkles;

        // COMPRAS
        case 'casa':
          return TablerIcons.package;

        case 'compras online':
          return TablerIcons.shoppingCart;

        case 'eletronicos':
          return TablerIcons.deviceLaptop;

        case 'marketplace':
          return TablerIcons.buildingStore;

        // CONTAS DA CASA
        case 'agua':
          return TablerIcons.droplet;

        case 'energia':
          return TablerIcons.bolt;

        case 'gas':
          return TablerIcons.flame;

        case 'internet / telefone':
        case 'internet':
          return TablerIcons.wifi;

        case 'telefone':
          return TablerIcons.phone;

        // DÍVIDAS E EMPRÉSTIMOS
        case 'acordos':
          return TablerIcons.fileCheck;

        case 'emprestimos':
        case 'emprestimo':
          return TablerIcons.cashBanknote;

        case 'financiamentos':
        case 'financiamento':
          return TablerIcons.fileDollar;

        case 'parcelamentos':
        case 'parcelamento':
          return TablerIcons.calendarDollar;

        // EDUCAÇÃO
        case 'cursos':
        case 'curso':
          return TablerIcons.certificate;

        case 'faculdade':
          return TablerIcons.school;

        case 'livros / material':
        case 'livros':
          return TablerIcons.books;

        // FINANCEIRO
        case 'ajustes financeiros':
        case 'ajuste':
          return TablerIcons.arrowsExchange;

        case 'iof / taxas':
        case 'iof':
        case 'taxas':
          return TablerIcons.receiptTax;

        case 'juros':
          return TablerIcons.percentage;

        case 'tarifas bancarias':
          return TablerIcons.buildingBank;

        // LAZER
        case 'cinema':
          return TablerIcons.movie;

        case 'eventos':
          return TablerIcons.ticket;

        case 'hobbies':
          return TablerIcons.palette;

        case 'jogos':
          return TablerIcons.deviceGamepad;

        case 'passeios':
          return TablerIcons.mapPin;

        // MORADIA
        case 'aluguel':
          return TablerIcons.home;

        case 'condominio':
          return TablerIcons.building;

        case 'manutencao':
          return TablerIcons.tools;

        case 'moveis / utilidades':
        case 'moveis':
          return TablerIcons.armchair;

        // PRESENTES
        case 'datas comemorativas':
          return TablerIcons.confetti;

        case 'doacoes':
          return TablerIcons.heartHandshake;

        // SAÚDE
        case 'academia / bem-estar':
        case 'academia':
          return TablerIcons.dumbbell;

        case 'consulta':
          return TablerIcons.stethoscope;

        case 'exames':
          return TablerIcons.microscope;

        case 'farmacia':
          return TablerIcons.pill;

        case 'terapia':
          return TablerIcons.brain;

        // TRANSPORTE
        case 'estacionamento / pedagio':
        case 'estacionamento':
          return TablerIcons.parking;

        case 'pedagio':
          return TablerIcons.road;

        case 'gasolina':
        case 'combustivel':
          return TablerIcons.gasStation;

        case 'transporte publico':
          return TablerIcons.bus;

        case 'uber / taxi':
        case 'uber':
        case 'taxi':
          return TablerIcons.car;

        // VESTUÁRIO
        case 'acessorios':
          return TablerIcons.eyeglass2;

        case 'calcados':
          return TablerIcons.shoe;

        case 'roupas':
          return TablerIcons.shirt;
      }
    }

    // =========================================================
    // CATEGORIAS PRINCIPAIS
    // =========================================================

    switch (c) {
      case 'a classificar':
        return TablerIcons.category;

      case 'alimentacao':
        return TablerIcons.toolsKitchen2;

      case 'assinaturas':
        return TablerIcons.repeat;

      case 'beleza e cuidados':
      case 'beleza':
        return TablerIcons.sparkles;

      case 'compras':
        return TablerIcons.shoppingBag;

      case 'contas da casa':
        return TablerIcons.bolt;

      case 'dividas e emprestimos':
      case 'dividas':
      case 'emprestimos':
        return TablerIcons.wallet;

      case 'educacao':
        return TablerIcons.school;

      case 'financeiro':
        return TablerIcons.buildingBank;

      case 'lazer':
        return TablerIcons.confetti;

      case 'moradia':
      case 'casa':
        return TablerIcons.home;

      case 'presentes':
        return TablerIcons.gift;

      case 'saude':
        return TablerIcons.heartRateMonitor;

      case 'transporte':
        return TablerIcons.car;

      case 'vestuario':
        return TablerIcons.shirt;

      case 'receita':
      case 'receitas':
      case 'renda':
      case 'salario':
        return TablerIcons.cashBanknote;

      case 'transferencia':
      case 'transferencias':
        return TablerIcons.arrowsExchange;

      case 'saldo inicial':
      case 'ajustes':
        return TablerIcons.wallet;
    }

    // =========================================================
    // FALLBACK PELO TIPO DO EVENTO
    // =========================================================

    switch (eventType) {
      case 'income':
        return TablerIcons.cashBanknote;

      case 'expense':
        return TablerIcons.receipt2;

      case 'transfer':
        return TablerIcons.arrowsExchange;

      case 'card_purchase':
        return TablerIcons.creditCard;

      case 'card_payment':
        return TablerIcons.receipt2;

      case 'opening_balance':
        return TablerIcons.wallet;

      case 'benefit_expense':
        return TablerIcons.receipt2;

      case 'debt_payment':
        return TablerIcons.wallet;

      default:
        return TablerIcons.category;
    }
  }

  static Color colorFor({
    required String category,
    required Brightness brightness,
  }) {
    final c = _normalize(category) ?? 'a classificar';

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

      // RECEITAS — VERDE-LIME MAIS FORTE
      case 'receita':
      case 'receitas':
      case 'renda':
      case 'salario':
        return isDark ? const Color(0xFFA8FF60) : const Color(0xFF4F8617);

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

      case 'receita':
      case 'receitas':
      case 'renda':
      case 'salario':
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
