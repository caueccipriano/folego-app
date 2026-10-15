import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../../core/utils/formatters.dart';
import 'discovery_model.dart';

/// On-demand reads only, always scoped to the mounted financial space.
/// No shared cache, financial mutation or cross-account index.
Future<DiscoveryData> loadDiscovery(
  FolegoRepository repository,
  String spaceId, {
  bool pendingOnly = false,
  DateTime? now,
}) async {
  final current = now ?? DateTime.now();
  final today = DateTime(current.year, current.month, current.day);
  final entries = <DiscoveryEntry>[];
  final pending = <DiscoveryEntry>[];
  final unavailable = <String>[];
  Future<void> source(String label, Future<void> Function() read) async {
    try {
      await read();
    } catch (_) {
      unavailable.add(label);
    }
  }

  await Future.wait([
    if (!pendingOnly)
      source('lançamentos', () async {
        final rows = await repository.getTransactions(spaceId);
        for (final row in rows) {
          entries.add(
            DiscoveryEntry(
              id: row.id,
              kind: DiscoveryKind.transaction,
              title: row.description,
              subtitle:
                  '${row.categoryName ?? 'sem categoria'} · ${row.accountName ?? 'lançamento'} · ${Formatters.fullDate.format(row.occurredAt)}',
              searchContext: row.source,
              amount: row.amount,
              date: row.occurredAt,
            ),
          );
        }
      }),
    if (!pendingOnly)
      source('carteira', () async {
        final wallet = await repository.getWalletOverview(spaceId: spaceId);
        for (final account in wallet.accounts) {
          entries.add(
            DiscoveryEntry(
              id: account.id,
              kind: DiscoveryKind.account,
              title: account.name,
              subtitle: account.isBenefit ? 'benefício' : 'conta',
              searchContext: account.institution ?? '',
              amount: account.balance,
            ),
          );
        }
        for (final card in wallet.cards) {
          entries.add(
            DiscoveryEntry(
              id: card.id,
              kind: DiscoveryKind.card,
              title: card.name,
              subtitle:
                  'fatura aberta · final ${card.lastFour ?? 'não informado'}',
              searchContext: '${card.issuer ?? ''} ${card.brand ?? ''}',
              amount: card.invoiceBalance,
            ),
          );
        }
      }),
    source('agenda', () async {
      final rows = await repository.getUpcomingEvents(
        spaceId,
        from: today.subtract(const Duration(days: 30)),
        days: 61,
      );
      for (final row in rows) {
        if (!row.isPending) continue;
        final due = DateTime(
          row.dueDate.year,
          row.dueDate.month,
          row.dueDate.day,
        );
        final days = DateTime.utc(
          due.year,
          due.month,
          due.day,
        ).difference(DateTime.utc(today.year, today.month, today.day)).inDays;
        final timing = days < 0
            ? 'vencido há ${-days} dias'
            : days == 0
            ? 'hoje'
            : 'em $days dias';
        final entry = DiscoveryEntry(
          id: '${row.source}:${row.id}:${due.toIso8601String()}',
          kind: DiscoveryKind.scheduled,
          title: row.name,
          subtitle:
              '${row.sourceLabel.toLowerCase()} · $timing · ${Formatters.fullDate.format(due)}',
          amount: row.amount,
          date: due,
          priority: days < 0
              ? 0
              : days == 0
              ? 1
              : 2,
        );
        entries.add(entry);
        if (days <= 7) pending.add(entry);
      }
    }),
    if (pendingOnly)
      source('categorias', () async {
        final rows = await repository.listPendingTransactionClassifications(
          spaceId,
        );
        for (final row in rows) {
          final entry = DiscoveryEntry(
            id: row.id,
            kind: DiscoveryKind.classification,
            title: row.description,
            subtitle:
                'conferir categoria · ${Formatters.fullDate.format(row.occurredAt)}',
            amount: row.amount,
            date: row.occurredAt,
            priority: 3,
          );
          pending.add(entry);
        }
      }),
    if (pendingOnly)
      source('planilha', () async {
        final status = await repository.getSheetSyncStatus(spaceId);
        if (!status.configured) return;
        if (!status.enabled) {
          pending.add(
            const DiscoveryEntry(
              id: 'disabled',
              kind: DiscoveryKind.sync,
              title: 'integração desativada',
              subtitle: 'conferir conexão com a planilha',
              priority: 4,
            ),
          );
          return;
        }
        final rows = await repository.getSheetAuditItems(spaceId);
        for (final row in rows) {
          if (row.hidden || row.needsReview || row.sheetAppliedAt != null) {
            continue;
          }
          pending.add(
            DiscoveryEntry(
              id: row.id,
              kind: DiscoveryKind.sync,
              title: row.description,
              subtitle:
                  'sem confirmação de retorno · isso não comprova um conflito',
              date: row.occurredAt,
              priority: 4,
            ),
          );
        }
      }),
  ]);
  entries.sort(
    (a, b) => (b.date ?? DateTime(1900)).compareTo(a.date ?? DateTime(1900)),
  );
  return DiscoveryData(
    entries: entries,
    pending: prioritizeDiscovery(pending),
    unavailable: unavailable..sort(),
  );
}
