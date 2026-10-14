import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/sheet_reconciliation_audit.dart';

typedef SheetAuditLoader = Future<List<SheetAuditItem>> Function(String spaceId);

/// A safe, read-only operational preview. There is no sheet-side receipt
/// protocol, so never label these entries as fully reconciled or approved.
class SheetAuditScreen extends StatefulWidget {
  const SheetAuditScreen({
    super.key,
    required this.spaceId,
    required this.loadItems,
  });

  final String spaceId;
  final SheetAuditLoader loadItems;

  @override
  State<SheetAuditScreen> createState() => _SheetAuditScreenState();
}

class _SheetAuditScreenState extends State<SheetAuditScreen> {
  List<SheetAuditItem> _items = const [];
  bool _loading = true;
  bool _failed = false;
  bool _onlyReview = true;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant SheetAuditScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId == widget.spaceId &&
        oldWidget.loadItems == widget.loadItems) {
      return;
    }
    _items = const [];
    _loading = true;
    _failed = false;
    _refresh();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    final requestedSpaceId = widget.spaceId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final rows = await widget.loadItems(requestedSpaceId);
      if (!mounted || _generation != generation ||
          widget.spaceId != requestedSpaceId) {
        return;
      }
      setState(() {
        _items = rows;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || _generation != generation ||
          widget.spaceId != requestedSpaceId) {
        return;
      }
      setState(() {
        _items = const [];
        _loading = false;
        _failed = true;
      });
    }
  }

  String _date(DateTime value) {
    final local = value.toLocal();
    String pad(int n) => n.toString().padLeft(2, '0');
    return '${pad(local.day)}/${pad(local.month)}/${local.year}';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final reviewCount = _items.where((e) => e.needsReview).length;
    final visible = _onlyReview
        ? _items.where((e) => e.needsReview).toList(growable: false)
        : _items;
    return Scaffold(
      appBar: AppBar(title: const Text('conferir vínculos com a planilha')),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
            children: [
              Text('Auditoria por lançamento',
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                'Esta tela mostra registros vinculados à planilha dentro '
                'do Fôlego. Sem uma confirmação de aplicação enviada '
                'pela própria planilha, nenhum item pode ser considerado '
                'totalmente conciliado.',
                key: const ValueKey('sheet-audit-no-ack-warning'),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'Amostra limitada: até 50 registros recentes e até 100 '
                'pendências de categoria. Não representa o histórico inteiro.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              if (_loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(25),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (_failed) ...[
                const Text(
                  'Não foi possível consultar os vínculos. '
                  'O resultado anterior não foi reaproveitado.',
                  key: ValueKey('sheet-audit-unavailable'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: _refresh,
                  child: const Text('tentar novamente'),
                ),
              ] else ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('sheet-audit-only-review'),
                      label: Text('Revisar ($reviewCount)'),
                      selected: _onlyReview,
                      onSelected: (_) => setState(() => _onlyReview = true),
                    ),
                    ChoiceChip(
                      key: const ValueKey('sheet-audit-all'),
                      label: Text('Amostra (${_items.length})'),
                      selected: !_onlyReview,
                      onSelected: (_) => setState(() => _onlyReview = false),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                if (visible.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 18),
                    child: Text(
                      _onlyReview
                        ? 'Nenhuma categoria pendente nesta amostra. '
                          'Isso não confirma sincronização completa.'
                        : 'Nenhum registro vinculado encontrado nesta amostra.',
                      key: const ValueKey('sheet-audit-empty'),
                    ),
                  )
                else
                  for (final item in visible)
                    Card(
                      key: ValueKey('sheet-audit-row-${item.id}'),
                      child: ListTile(
                        title: Text(
                          item.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${_date(item.occurredAt)} • ${item.reviewLabel}',
                          maxLines: 3,
                        ),
                        trailing: ValueListenableBuilder<bool>(
                          valueListenable: FinancialPrivacy.hidden,
                          builder: (context, hidden, _) => Text(
                            hidden ? 'R$ ••••' : Formatters.money(item.amount),
                            key: ValueKey('sheet-audit-amount-${item.id}'),
                          ),
                        ),
                      ),
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
