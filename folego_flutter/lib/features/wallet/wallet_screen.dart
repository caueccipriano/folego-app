import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_refresh_view.dart';
import '../../core/theme/app_icons.dart';
import '../../data/repositories/folego_repository.dart';
import 'debt_form_sheet.dart';
import 'wallet_instrument_management.dart';
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

  Future<void> _addInstrument() async {
    final action = await showWalletAddAction(context);
    if (action == null || !mounted) return;

    final changed = switch (action) {
      WalletAddAction.account => showWalletAccountEditor(
          context: context,
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      WalletAddAction.card => showWalletCardEditor(
          context: context,
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      WalletAddAction.benefit => showWalletAccountEditor(
          context: context,
          repository: widget.repository,
          spaceId: widget.spaceId,
          benefitMode: true,
        ),
      WalletAddAction.debt => showDebtFormSheet(
          context: context,
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
    };

    if (await changed == true && mounted) {
      setState(() => _localRevision += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return RealtimeRefreshView(
      domain: AppRealtimeDomain.wallet,
      identity: (widget.spaceId, _localRevision),
      builder: (key) {
        final content = Stack(
          key: ValueKey(desktop ? 'wallet-desktop-layout' : 'wallet-mobile-layout'),
          children: [
            base.WalletScreen(
              key: key,
              repository: widget.repository,
              spaceId: widget.spaceId,
            ),
            Positioned(
              right: desktop ? 32 : 18,
              bottom: desktop ? 32 : 104,
              child: FloatingActionButton.extended(
                key: const ValueKey('wallet-add-action'),
                heroTag: 'wallet-add-instrument',
                onPressed: _addInstrument,
                icon: const Icon(AppIcons.add, size: 19),
                label: const Text('adicionar'),
              ),
            ),
          ],
        );

        if (!desktop) return content;
        return Theme(
          data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
          child: content,
        );
      },
    );
  }
}
