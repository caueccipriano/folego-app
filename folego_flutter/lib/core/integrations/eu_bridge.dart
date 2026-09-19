import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/folego_snapshot.dart';

class EuBridge {
  static const _legacyKey = 'eu_bridge_folego_v1';
  static const _key = 'eu_bridge_folego_v2';

  static Future<void> publishFolego(FolegoSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final budgetPercent = snapshot.monthlyBudgetPlanned <= 0
        ? null
        : ((snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned) * 100)
            .clamp(0, 999)
            .round();

    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'version': 2,
      'schema': 'eu.bridge/2',
      'app': 'folego',
      'title': 'Fôlego',
      'updatedAt': now,
      'status': _status(snapshot),
      'summary': _summary(snapshot, budgetPercent),
      'metrics': {
        'dailyFolego': snapshot.dailyFolego,
        'budgetUsedPercent': budgetPercent,
        'daysUntilIncome': snapshot.daysUntilIncome,
        'shortfall': snapshot.shortfall,
        'liquidBalance': snapshot.liquidBalance,
        'protectedBalance': snapshot.protectedBalance,
        'cashHeadroom': snapshot.cashHeadroom,
        'spendablePool': snapshot.spendablePool,
        'nextIncomeAmount': snapshot.nextIncomeAmount,
        'monthlyBudgetPlanned': snapshot.monthlyBudgetPlanned,
        'monthlyBudgetUsed': snapshot.monthlyBudgetUsed,
        'budgetConfigured': snapshot.budgetConfigured,
        'limitingFactor': snapshot.limitingFactor,
      },
    };

    final encoded = jsonEncode(payload);
    await Future.wait([
      prefs.setString(_key, encoded),
      prefs.setString(_legacyKey, encoded),
    ]);
  }

  static String _status(FolegoSnapshot snapshot) {
    switch (snapshot.status) {
      case 'tranquilo':
        return 'dentro do plano';
      case 'apertado':
        return 'apertado';
      case 'segure_gastos':
        return 'segure gastos';
      case 'sem_folga':
        return 'sem folga';
      case 'configurar_recebimento':
        return 'configurar recebimento';
      default:
        return snapshot.status;
    }
  }

  static String _summary(FolegoSnapshot snapshot, int? budgetPercent) {
    final parts = <String>[];

    if (snapshot.dailyFolego != null) {
      parts.add('R\$ ${snapshot.dailyFolego!.toStringAsFixed(2).replaceAll('.', ',')} por dia');
    }

    if (budgetPercent != null) {
      parts.add('$budgetPercent% do orçamento variável usado');
    }

    if (snapshot.daysUntilIncome != null) {
      parts.add('${snapshot.daysUntilIncome} dias até o próximo recebimento');
    }

    if (snapshot.shortfall > 0) {
      parts.add('atenção ao caixa');
    } else if (snapshot.cashHeadroom > 0) {
      parts.add('caixa com folga');
    } else {
      parts.add('sem déficit projetado');
    }

    return parts.join(' · ');
  }
}
