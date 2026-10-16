import 'package:flutter/material.dart';

import '../../core/theme/app_typography.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/folego_snapshot.dart';
import '../../data/models/monthly_money_summary.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../plan/category_period_comparison.dart';
import '../plan/spending_behavior_screen.dart';
import '../transactions/transaction_classification_inbox.dart';
import '../wallet/wallet_screen.dart';
import 'folego_change_explanation.dart';
import 'monthly_closing_review.dart';

Future<void> reviewFinancialAccounts(
  BuildContext context,
  FolegoRepository repository,
  String spaceId,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => Scaffold(
      appBar: AppBar(title: const Text('conferir contas e faturas')),
      body: WalletScreen(repository: repository, spaceId: spaceId),
    ),
  ),
);

Future<void> reviewFinancialCategories(
  BuildContext context,
  FolegoRepository repository,
  String spaceId,
) async {
  final pending = await repository.listPendingTransactionClassifications(
    spaceId,
  );
  if (!context.mounted) return;
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => TransactionClassificationInbox(
        repository: repository,
        spaceId: spaceId,
        initialItems: pending,
      ),
    ),
  );
}

Future<void> reviewFinancialBehavior(
  BuildContext context,
  FolegoRepository repository,
  String spaceId,
  DateTime month,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => SpendingBehaviorScreen(
      repository: repository,
      spaceId: spaceId,
      periodMonth: month,
    ),
  ),
);

class FinancialReviewScreen extends StatelessWidget {
  const FinancialReviewScreen({
    super.key,
    required this.repository,
    required this.space,
    required this.snapshot,
    this.previous,
    this.summary,
  });
  final FolegoRepository repository;
  final FinancialSpace space;
  final FolegoSnapshot snapshot;
  final FolegoSnapshot? previous;
  final MonthlyMoneySummary? summary;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        'entenda seu Fôlego',
        style: AppTypography.section(context, fontSize: 16),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FolegoChangeExplanation(current: snapshot, previous: previous),
        const SizedBox(height: 24),
        FilledButton.icon(
          icon: const Icon(Icons.bar_chart_rounded),
          label: const Text('comparar categorias no mesmo período'),
          onPressed: () => Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => CategoryPeriodComparison(
                repository: repository,
                spaceId: space.id,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (summary != null)
          OutlinedButton.icon(
            icon: const Icon(Icons.fact_check_outlined),
            label: const Text('fazer meu fechamento guiado'),
            onPressed: () => showMonthlyClosingReview(
              context,
              summary: summary!,
              onReviewAccounts: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(
                      title: const Text('conferir contas e faturas'),
                    ),
                    body: WalletScreen(
                      repository: repository,
                      spaceId: space.id,
                    ),
                  ),
                ),
              ),
              onReviewCategories: () async {
                final pending = await repository
                    .listPendingTransactionClassifications(space.id);
                if (!context.mounted) return;
                await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) => TransactionClassificationInbox(
                      repository: repository,
                      spaceId: space.id,
                      initialItems: pending,
                    ),
                  ),
                );
              },
              onReviewBehavior: () => Navigator.of(context).push<void>(
                MaterialPageRoute(
                  builder: (_) => SpendingBehaviorScreen(
                    repository: repository,
                    spaceId: space.id,
                    periodMonth: summary!.periodMonth,
                  ),
                ),
              ),
            ),
          ),
        const SizedBox(height: 8),
        const Text(
          'as ferramentas de conferência abrem seus registros atuais. ao retornar ao início, puxe para atualizar e ver uma nova leitura do Fôlego.',
        ),
      ],
    ),
  );
}
