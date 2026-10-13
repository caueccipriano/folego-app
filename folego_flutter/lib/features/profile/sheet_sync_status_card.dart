import 'package:flutter/material.dart';

import '../../data/models/sheet_sync_status.dart';

typedef SheetSyncStatusLoader = Future<SheetSyncStatus> Function(String spaceId);

/// Profile-only diagnostic, never an assertion of reconciled balances.
class SheetSyncStatusCard extends StatefulWidget {
  const SheetSyncStatusCard({
    super.key,
    required this.spaceId,
    required this.loadStatus,
  });

  final String spaceId;
  final SheetSyncStatusLoader loadStatus;

  @override
  State<SheetSyncStatusCard> createState() => _SheetSyncStatusCardState();
}

class _SheetSyncStatusCardState extends State<SheetSyncStatusCard> {
  SheetSyncStatus? _status;
  bool _loading = true;
  bool _failed = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant SheetSyncStatusCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId ||
        oldWidget.loadStatus != widget.loadStatus) {
      _status = null;
      _failed = false;
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final requestedSpaceId = widget.spaceId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final status = await widget.loadStatus(requestedSpaceId);
      if (!mounted || generation != _generation ||
          widget.spaceId != requestedSpaceId) return;
      setState(() {
        _status = status;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation ||
          widget.spaceId != requestedSpaceId) return;
      setState(() {
        _status = null;
        _failed = true;
        _loading = false;
      });
    }
  }

  String _date(DateTime? value) {
    if (value == null) return 'sem registro';
    final local = value.toLocal();
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)} ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final status = _status;
    return Card(
      key: const ValueKey('sheet-sync-status'),
      margin: EdgeInsets.zero,
      elevation: 0,
      color: colors.surface,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: colors.outlineVariant),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(15, 14, 15, 15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.sync_alt_rounded, size: 19, color: colors.primary),
                const SizedBox(width: 9),
                Expanded(
                  child: Text('planilha conectada',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    )),
                ),
                if (_loading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    key: const ValueKey('sheet-sync-refresh'),
                    tooltip: 'consultar novamente',
                    onPressed: _refresh,
                    icon: const Icon(Icons.refresh_rounded, size: 19),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Text('consultando o status da integração…')
            else if (_failed)
              Text('não foi possível verificar a conexão agora',
                key: const ValueKey('sheet-sync-error'),
                style: TextStyle(color: colors.error))
            else if (status != null) ...[
              Text(status.headline,
                key: const ValueKey('sheet-sync-headline'),
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                )),
              if (status.configured) ...[
                const SizedBox(height: 10),
                Text('Último envio da planilha ao Fôlego: ${_date(status.lastPushAt)}',
                  key: const ValueKey('sheet-sync-last-push')),
                const SizedBox(height: 5),
                Text('Última consulta da planilha ao Fôlego: ${_date(status.lastPullAt)}',
                  key: const ValueKey('sheet-sync-last-pull')),
                const SizedBox(height: 7),
                Text('Horário do aparelho. São registros de comunicação, não confirmação de que todos os lançamentos foram conciliados.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colors.onSurfaceVariant,
                  )),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
