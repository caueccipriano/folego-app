import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/folego_snapshot.dart';

class EuBridge {
  static const _key = 'eu_bridge_folego_v1';

  static Future<void> publishFolego(FolegoSnapshot snapshot) async {
    final prefs = await SharedPreferences.getInstance();
    final budgetPercent = snapshot.monthlyBudgetPlanned <= 0
        ? null
        : ((snapshot.monthlyBudgetUsed / snapshot.monthlyBudgetPlanned) * 100)
            .clamp(0, 999)
            .round();

    final payload = <String, dynamic>{
      'version': 1,
      'app': 'folego',
      'title': 'Fôlego',
      'updatedAt': DateTime.now().toIso8601String(),
      'status': snapshot.status,
      'summary': _summary(snapshot, budgetPercent),
      'metrics': {
        'dailyFolego': snapshot.dailyFolego,
        'budgetUsedPercent': budgetPercent,
        'daysUntilIncome': snapshot.daysUntilIncome,
        'shortfall': snapshot.shortfall,
      },
    };

    await prefs.setString(_key, jsonEncode(payload));
  }

  static String _summary(FolegoSnapshot snapshot, int? budgetPercent) {
    final parts = <String>[];

    if (budgetPercent != null) {
      parts.add('$budgetPercent% do orçamento variável usado');
    }

    if (snapshot.daysUntilIncome != null) {
      parts.add('${snapshot.daysUntilIncome} dias até o próximo recebimento');
    }

    if (snapshot.shortfall > 0) {
      parts.add('atenção ao caixa');
    } else {
      parts.add('sem déficit projetado');
    }

    return parts.join(' · ');
  }
}
