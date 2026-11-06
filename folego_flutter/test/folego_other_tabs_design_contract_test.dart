import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Movimentos has themed search, legible ledger and preserved actions', () {
    final source = File('lib/features/transactions/transactions_screen_base.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('transactions-section-tabs-surface')"));
    expect(source, contains('buscar por nome, categoria ou conta'));
    expect(source, contains("AppColorSelection.selected.value == 'ink'"));
    expect(source, contains('final surface = tokens.superficie;'));
    expect(source, contains("ValueKey('transaction-row-amount')"));
    expect(source, contains('pendingClassificationCount > 0'));
    expect(source, contains('onOpen(item)'));
  });

  test('Planejar presents verified remaining amount with semantic theme colors', () {
    final source = File('lib/features/plan/plan_screen_web2.dart')
        .readAsStringSync();
    expect(source, contains('final tokens = FolegoColorTokens.of(context);'));
    expect(source, contains('Formatters.money(summary.remainingAmount.abs())'));
    expect(source, contains('summary.usageRatio.clamp(0.0, 1.0)'));
    expect(source, contains('não é saldo em conta'));
    expect(source, contains("ValueKey('plan-summary-usage-progress')"));
    expect(source, contains('tokens.superficieAlta.withValues(alpha: .25)'));
  });

  test('Carteira separates balances, shows readable secondary metrics and retains choices', () {
    final source = File('lib/features/wallet/wallet_screen_base.dart')
        .readAsStringSync();
    expect(source, contains("ValueKey('wallet-summary-available')"));
    expect(source, contains("ValueKey('wallet-section-scroller')"));
    expect(source, contains('tokens.estourado'));
    expect(source, contains("label: 'faturas em aberto'"));
    expect(source, contains("label: 'dívidas restantes'"));
    expect(source, contains('FinancialPrivacy.hidden'));
    expect(source, contains('_selectSection(index)'));
  });

  test('Perfil keeps secure account actions while making rows theme-aware', () {
    final source = File('lib/features/profile/profile_widgets.dart')
        .readAsStringSync();
    expect(source, contains('final colors = FolegoColorTokens.of(context);'));
    expect(source, contains('onTap: enabled ? onTap : null'));
    expect(source, contains('colors.estourado'));
    expect(source, contains('colors.superficie'));
    final profile = File('lib/features/profile/profile_screen_v2.dart')
        .readAsStringSync();
    expect(profile, contains('title: \'tema do app\''));
    expect(profile, contains('onTap: _openAppTheme'));
    expect(profile, contains('onTap: _confirmSignOut'));
  });

  test('Mais preserves the five routes and concise mobile two-column menu', () {
    final source = File('lib/features/shell/more_tools_sheet.dart')
        .readAsStringSync();
    expect(source, contains('TUDO EM UM LUGAR'));
    expect(source, contains('tools-two-columns'));
    expect(source, contains('tools-single-column'));
    expect(source, contains("ValueKey('tools-financial-ai')"));
    for (var i = 0; i < 5; i++) {
      expect(source, contains('onSelected($i)'));
    }
  });
}
