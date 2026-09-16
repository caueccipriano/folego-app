import 'package:flutter/widgets.dart';

import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import 'transactions_screen_base.dart' as impl;

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
    this.space,
  });

  final FolegoRepository repository;
  final FinancialSpace? space;

  @override
  Widget build(BuildContext context) {
    return impl.TransactionsScreenV3(
      repository: repository,
      space: space,
    );
  }
}
