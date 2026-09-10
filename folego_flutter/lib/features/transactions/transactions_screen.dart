import 'package:flutter/material.dart';

import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
  });

  final FolegoRepository repository;

  Future<List<TransactionItem>> _loadTransactions() async {
    final space = await repository.getPrimarySpace();
    return repository.getTransactions(space.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transações'),
      ),
      body: FutureBuilder<List<TransactionItem>>(
        future: _loadTransactions(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Não foi possível carregar as transações.\n${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final transactions = snapshot.data ?? [];

          if (transactions.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Nenhuma transação encontrada.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
            itemCount: transactions.length,
            separatorBuilder: (context, index) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final transaction = transactions[index];

              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 4,
                  vertical: 8,
                ),
                leading: CircleAvatar(
                  child: Icon(
                    _iconForType(transaction.eventType),
                  ),
                ),
                title: Text(transaction.description),
                subtitle: Text(
                  [
                    if (transaction.categoryName != null)
                      transaction.categoryName!,
                    _formatDate(transaction.occurredAt),
                  ].join(' • '),
                ),
                trailing: Text(
                  'R\$ ${transaction.amount.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  IconData _iconForType(String type) {
    switch (type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'expense':
        return Icons.arrow_upward_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      case 'card_purchase':
        return Icons.credit_card_rounded;
      case 'card_payment':
        return Icons.receipt_long_rounded;
      default:
        return Icons.payments_outlined;
    }
  }

  String _formatDate(DateTime date) {
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    return '$day/$month/${date.year}';
  }
}