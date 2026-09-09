import 'package:flutter/material.dart';

import '../../shared/widgets/page_placeholder.dart';

class WalletScreen extends StatelessWidget {
  const WalletScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PagePlaceholder(
      title: 'Carteira',
      description: 'Contas, cartões, faturas, dívidas e reservas ficarão organizados nesta área.',
      icon: Icons.account_balance_wallet_rounded,
    );
  }
}
