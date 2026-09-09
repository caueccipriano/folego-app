import 'package:flutter/material.dart';

import '../../shared/widgets/page_placeholder.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PagePlaceholder(
      title: 'Transações',
      description: 'Seu histórico, filtros e classificação automática entram aqui na próxima etapa. O registro rápido já funciona pela Home.',
      icon: Icons.receipt_long_rounded,
    );
  }
}
