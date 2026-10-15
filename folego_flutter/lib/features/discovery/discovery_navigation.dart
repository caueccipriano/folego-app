import 'package:flutter/material.dart';

import '../../data/models/financial_space.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../home/upcoming_events_screen.dart';
import '../profile/sheet_audit_screen.dart';
import '../transactions/transaction_classification_inbox.dart';
import '../transactions/transaction_detail_sheet_v2.dart';
import '../wallet/wallet_detail_screen.dart';
import 'discovery_loader.dart';
import 'discovery_model.dart';
import 'discovery_screen.dart';

Future<void> openDiscovery(
  BuildContext context, {
  required FinancialSpace space,
  required FolegoRepository repository,
  bool pendingOnly = false,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (routeContext) => DiscoveryScreen(
      identity: space.id,
      pendingOnly: pendingOnly,
      load: () => loadDiscovery(repository, space.id, pendingOnly: pendingOnly),
      onOpen: (entry) async {
        Widget destination;
        switch (entry.kind) {
          case DiscoveryKind.transaction:
            await showTransactionDetail(
              context: routeContext,
              repository: repository,
              space: space,
              eventId: entry.id,
            );
            return;
          case DiscoveryKind.account:
          case DiscoveryKind.card:
            final wallet = await repository.getWalletOverview(
              spaceId: space.id,
            );
            if (!routeContext.mounted) return;
            if (entry.kind == DiscoveryKind.card) {
              final card = wallet.cards
                  .where((item) => item.id == entry.id)
                  .firstOrNull;
              if (card == null) throw StateError('registro indisponível');
              destination = WalletCardDetailScreen(
                repository: repository,
                spaceId: space.id,
                card: card,
              );
            } else {
              final account = wallet.accounts
                  .where((item) => item.id == entry.id)
                  .firstOrNull;
              if (account == null) throw StateError('registro indisponível');
              destination = account.isBenefit
                  ? WalletBenefitDetailScreen(
                      repository: repository,
                      spaceId: space.id,
                      benefit: account,
                    )
                  : WalletAccountDetailScreen(
                      repository: repository,
                      spaceId: space.id,
                      account: account,
                    );
            }
          case DiscoveryKind.scheduled:
            destination = UpcomingEventsScreen(
              initialSourceId: entry.targetId,
              initialDate: entry.date,
              repository: repository,
              spaceId: space.id,
            );
          case DiscoveryKind.sync:
            if (entry.id == 'disabled') {
              await showDialog<void>(
                context: routeContext,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('integração desativada'),
                  content: const Text(
                    'Abra perfil → planilha para conferir a conexão. Nenhum dado foi sincronizado por esta ação.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext),
                      child: const Text('entendi'),
                    ),
                  ],
                ),
              );
              return;
            }
            destination = SheetAuditScreen(
              spaceId: space.id,
              loadItems: (id) async =>
                  (await repository.getSheetAuditItems(id))
                      .where((item) => item.id == entry.id)
                      .toList(),
            );
          case DiscoveryKind.classification:
            final items = await repository
                .listPendingTransactionClassifications(space.id);
            if (!routeContext.mounted) return;
            destination = TransactionClassificationInbox(
              repository: repository,
              spaceId: space.id,
              initialItems: items.where((item) => item.id == entry.id).toList(),
            );
        }
        if (!routeContext.mounted) return;
        await Navigator.of(routeContext)
            .push<void>(MaterialPageRoute(builder: (_) => destination));
      },
    ),
  ),
);
