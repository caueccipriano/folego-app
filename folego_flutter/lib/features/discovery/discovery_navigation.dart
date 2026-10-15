import 'package:flutter/material.dart';

import '../../data/models/financial_space.dart';
import '../../data/models/transaction_filters.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../home/upcoming_events_screen.dart';
import '../profile/sheet_audit_screen.dart';
import '../transactions/transaction_classification_inbox.dart';
import '../transactions/transactions_screen.dart';
import '../wallet/wallet_screen.dart';
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
            destination = TransactionsScreen(
              repository: repository,
              space: space,
              initialFilters: TransactionFilters(search: entry.title),
            );
          case DiscoveryKind.account:
          case DiscoveryKind.card:
            destination = WalletScreen(
              repository: repository,
              spaceId: space.id,
            );
          case DiscoveryKind.scheduled:
            destination = UpcomingEventsScreen(
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
              loadItems: repository.getSheetAuditItems,
            );
          case DiscoveryKind.classification:
            final items = await repository
                .listPendingTransactionClassifications(space.id);
            if (!routeContext.mounted) return;
            destination = TransactionClassificationInbox(
              repository: repository,
              spaceId: space.id,
              initialItems: items,
            );
        }
        if (!routeContext.mounted) return;
        await Navigator.of(routeContext)
            .push<void>(MaterialPageRoute(builder: (_) => destination));
      },
    ),
  ),
);
