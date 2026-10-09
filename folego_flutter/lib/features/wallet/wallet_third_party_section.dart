import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/utils/formatters.dart';

/// Exibe conciliações de compras de terceiros sem gerar outra despesa,
/// receita, pagamento de fatura ou projeção de cartão.
class WalletThirdPartySection extends StatefulWidget {
  const WalletThirdPartySection({super.key, required this.spaceId});
  final String spaceId;

  @override
  State<WalletThirdPartySection> createState() =>
      _WalletThirdPartySectionState();
}

class _WalletThirdPartySectionState extends State<WalletThirdPartySection> {
  late Future<List<Map<String, dynamic>>> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
  }

  @override
  void didUpdateWidget(covariant WalletThirdPartySection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) _data = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final db = Supabase.instance.client;
    final categories = await db.from('categories').select('id')
        .eq('space_id', widget.spaceId)
        .eq('name', 'Compras de terceiros').limit(1);
    if (categories.isEmpty) return [];
    final entries = await db.from('financial_events')
        .select('id,metadata').eq('space_id', widget.spaceId)
        .eq('category_id', categories.first['id'] as String)
        .order('occurred_at', ascending: false).limit(100);
    return entries.where((row) {
      final meta = row['metadata'];
      return meta is Map && meta['purchase_total'] != null;
    }).toList(growable: false);
  }

  void _reload() => setState(() => _data = _load());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _data,
      builder: (context, snapshot) {
        if (!snapshot.hasData && !snapshot.hasError) {
          return const Padding(
            padding: EdgeInsets.all(28),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasError) {
          return Column(children: [
            const Text('Não foi possível carregar as compras de terceiros.'),
            TextButton.icon(
              onPressed: _reload,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Tentar novamente'),
            ),
          ]);
        }
        final items = snapshot.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text('Nenhuma compra de terceiros para acompanhar.'),
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final row in items) ...[
              _PurchaseCard(data: Map<String, dynamic>.from(
                row['metadata'] as Map,
              )),
              const SizedBox(height: 10),
            ],
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                'Acompanhamento de terceiros: sem duplicar cobranças '
                'ou lançar reembolsos como salário.',
                style: TextStyle(fontSize: 12),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Atualizar'),
              ),
            ),
          ],
        );
      },
    );
  }
}

double _amount(dynamic v) =>
    v is num ? v.toDouble() : double.tryParse(v?.toString() ?? '') ?? 0;

String _date(dynamic raw) {
  final d = DateTime.tryParse(raw?.toString() ?? '');
  if (d == null) return 'A confirmar';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/' + d.year.toString();
}

class _PurchaseCard extends StatelessWidget {
  const _PurchaseCard({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final person = data['person']?.toString() ?? 'Terceiro';
    final origin = data['origin']?.toString() ?? 'Compra';
    final count = (data['installments_total'] as num?)?.toInt() ?? 1;
    final future = (data['next_installments'] as List? ?? [])
        .whereType<Map>().map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
    future.sort((a, b) =>
        ((a['number'] as num?)?.toInt() ?? 0)
            .compareTo((b['number'] as num?)?.toInt() ?? 0));
    final pending = future.fold<double>(
      0, (sum, due) => sum + _amount(due['amount']),
    );

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        border: Border.all(color: AppColors.border(brightness)),
        borderRadius: BorderRadius.circular(18),
      ),
      child: ExpansionTile(
        shape: const Border(),
        collapsedShape: const Border(),
        tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        leading: const Icon(AppIcons.categoryFamily),
        title: Text(
          '$person · $origin',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textColor, fontWeight: FontWeight.w700, fontSize: 15,
          ),
        ),
        subtitle: Text(
          Formatters.money(_amount(data['purchase_total'])) +
              ' · ' + count.toString() + ' parcelas · ' +
              Formatters.money(pending) + ' a vencer',
          style: TextStyle(color: secondary, fontSize: 12),
        ),
        children: [
          Divider(color: AppColors.border(brightness)),
          _DetailRow('Categoria', 'Compras de terceiros'),
          _DetailRow('Responsável pelo consumo', person),
          _DetailRow('Origem', origin),
          _DetailRow(
            'Produto',
            (data['product_description']?.toString().isNotEmpty ?? false)
                ? data['product_description'].toString()
                : 'Descrição não informada',
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Parcelas', style: TextStyle(
              color: textColor, fontWeight: FontWeight.w700,
            )),
          ),
          const SizedBox(height: 8),
          if (data['installment_number'] != null)
            _InstallmentRow(
              number: (data['installment_number'] as num).toInt(),
              count: count,
              date: _date(data['invoice_due_date']),
              amount: _amount(data['installment_amount']),
              paid: true,
            ),
          for (final entry in future)
            _InstallmentRow(
              number: (entry['number'] as num).toInt(),
              count: count,
              date: _date(entry['due_date']),
              amount: _amount(entry['amount']),
              paid: false,
            ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: .06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Acerto com ' + person.toLowerCase(),
                    style: TextStyle(color: textColor, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(
                  'A primeira parcela foi compensada com dinheiro '
                  'que já estava sob sua guarda, não com nova receita.',
                  style: TextStyle(color: secondary, fontSize: 12.5),
                ),
                if (data['custody_remaining'] != null) ...[
                  const SizedBox(height: 10),
                  _DetailRow(
                    'Saldo atribuído à pessoa',
                    Formatters.money(_amount(data['custody_remaining'])),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'As próximas parcelas continuam no seu nome. '
            'Esta ficha não é outra fatura e não duplica o pagamento.',
            style: TextStyle(color: secondary, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final b = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(child: Text(label, style: TextStyle(
          color: AppColors.secondaryText(b), fontSize: 12,
        ))),
        const SizedBox(width: 12),
        Flexible(child: Text(
          value, textAlign: TextAlign.right,
          style: TextStyle(
            color: AppColors.primaryText(b),
            fontSize: 12.5, fontWeight: FontWeight.w600,
          ),
        )),
      ]),
    );
  }
}

class _InstallmentRow extends StatelessWidget {
  const _InstallmentRow({
    required this.number,
    required this.count,
    required this.date,
    required this.amount,
    required this.paid,
  });
  final int number;
  final int count;
  final String date;
  final double amount;
  final bool paid;

  @override
  Widget build(BuildContext context) {
    final muted = AppColors.secondaryText(Theme.of(context).brightness);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 9),
      child: Row(children: [
        Icon(
          paid ? Icons.check_circle_outline_rounded : Icons.schedule_rounded,
          color: paid ? Colors.teal : muted,
          size: 18,
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(
          '$number/$count · $date',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
        )),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(Formatters.money(amount), style: const TextStyle(
            fontSize: 13, fontWeight: FontWeight.w700,
          )),
          Text(paid ? 'Paga e compensada' : 'A vencer',
              style: TextStyle(
                fontSize: 11, color: paid ? Colors.teal : muted,
              )),
        ]),
      ]),
    );
  }
}
