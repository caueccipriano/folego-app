import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
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
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    final screen = impl.TransactionsScreenV3(
      key: ValueKey<String>(space?.id ?? 'primary-space'),
      repository: repository,
      space: space,
    );

    if (!desktop) return screen;

    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
      child: KeyedSubtree(
        key: const ValueKey('transactions-desktop-layout'),
        child: screen,
      ),
    );
  }
}
