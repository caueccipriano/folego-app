import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_agenda.dart';
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
  final sources = <DiscoverySourceStatus>[];
  final sourceNotes = <String, String>{};
  Future<void> source(String label, Future<void> Function() read) async {
    try {
      await read();
      sources.add(
        DiscoverySourceStatus(
          name: label,
          note: sourceNotes[label],
          confirmed: true,
          checkedAt: DateTime.now(),
        ),
      );
    } catch (_) {
      unavailable.add(label);
      sources.add(
        DiscoverySourceStatus(
          name: label,
          confirmed: false,
          checkedAt: DateTime.now(),
        ),
      );
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
                  '${row.categoryName ?? 'sem categoria'} · ${row.accountName ?? 'lançamento'} · ${Formatters.fullDate.format(row.occurredAt)} · ${discoveryOrigin(row.source)} · ${row.status == 'confirmed' ? 'confirmado' : row.status}',
              searchContext:
                  '${discoveryOrigin(row.source)} · ${row.status == 'confirmed' ? 'confirmado' : row.status}',
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
      final rows = await repository.getFinancialAgenda(
        spaceId,
        startDate: today.subtract(const Duration(days: 30)),
        endDate: today.add(Duration(days: pendingOnly ? 7 : 30)),
        limit: 200,
      );
      if (rows.length == 200) {
        unavailable.add('agenda completa (limite de 200 itens nesta consulta)');
      }
      for (final row in rows) {
        if (row.realized || row.status == 'paid' || row.status == 'cancelled') {
          continue;
        }
        final due = DateTime(
          row.dueDate.year,
          row.dueDate.month,
          row.dueDate.day,
        );
        if (due.isBefore(today.subtract(const Duration(days: 30))) ||
            due.isAfter(today.add(Duration(days: pendingOnly ? 7 : 30)))) {
          continue;
        }
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
          id: row.eventKey,
          targetId: row.sourceId,
          kind: DiscoveryKind.scheduled,
          title: row.title,
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
        String communication(DateTime? at) => at == null
            ? 'sem registro'
            : '${Formatters.fullDate.format(at)} ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
        sourceNotes['planilha'] = status.configured
            ? '${status.headline}. Envio pela planilha: ${communication(status.lastPushAt)}. Consulta pela planilha: ${communication(status.lastPullAt)}. A comunicação não confirma a aplicação de todas as linhas.'
            : 'Planilha não conectada. O app funciona sem essa integração.';
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
    sources: sources..sort((a, b) => a.name.compareTo(b.name)),
  );
}
