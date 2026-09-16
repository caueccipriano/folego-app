import 'package:flutter/material.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/folego_repository.dart';
import 'debt_form_sheet.dart';
import 'wallet_screen_base.dart' as base;

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  int _localRevision = 0;

  Future<void> _createDebt() async {
    final created = await showDebtFormSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
    );
    if (created == true && mounted) {
      setState(() => _localRevision += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return RealtimeRefreshView(
      domain: AppRealtimeDomain.wallet,
      identity: (widget.spaceId, _localRevision),
      builder: (key) => Stack(
        children: [
          base.WalletScreen(
            key: key,
            repository: widget.repository,
            spaceId: widget.spaceId,
          ),
          Positioned(
            right: 18,
            bottom: 104,
            child: FloatingActionButton.extended(
              heroTag: 'wallet-new-debt',
              onPressed: _createDebt,
              icon: const Icon(AppIcons.debt, size: 19),
              label: const Text('nova dívida'),
            ),
          ),
        ],
      ),
    );
  }
}
