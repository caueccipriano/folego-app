import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_payment_recognition.dart';

Future<bool?> showExistingPaymentPicker(
  BuildContext context, {
  required FolegoRepository repository,
  required String spaceId,
  required String targetKind,
  required String targetId,
  required String targetName,
  required double outstanding,
}) => showDialog<bool>(
  context: context,
  builder: (_) => ExistingPaymentPicker(
    targetName: targetName,
    loadCandidates: () => repository.paymentCandidates(spaceId, outstanding),
    linkPayment: (item) => repository.recognizePayment(
      spaceId: spaceId,
      eventId: item.id,
      targetKind: targetKind,
      targetId: targetId,
    ),
  ),
);

class ExistingPaymentPicker extends StatefulWidget {
  const ExistingPaymentPicker({
    super.key,
    required this.targetName,
    required this.loadCandidates,
    required this.linkPayment,
  });
  final String targetName;
  final Future<List<TransactionItem>> Function() loadCandidates;
  final Future<void> Function(TransactionItem) linkPayment;
  @override
  State<ExistingPaymentPicker> createState() => _ExistingPaymentPickerState();
}

class _ExistingPaymentPickerState extends State<ExistingPaymentPicker> {
  late Future<List<TransactionItem>> _rows;
  String _query = '';
  bool _saving = false;
  bool _choosing = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _rows = widget.loadCandidates();
  }

  Future<void> _choose(TransactionItem item) async {
    if (_saving || _choosing) return;
    setState(() => _choosing = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('reconhecer este pagamento?'),
        content: Text(
          '${item.description} → ${widget.targetName}\n${Formatters.money(item.amount)} · ${item.accountName ?? 'conta'} · ${Formatters.fullDate.format(item.occurredAt)}\n\nO saldo da conta permanece igual. Esta saída será vinculada ao compromisso e deixará de contar como uma nova despesa no orçamento. Confira conta, data e valor antes de confirmar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('voltar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('confirmar vínculo'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _choosing = false);
    if (confirmed != true) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.linkPayment(item);
      AppRealtimeRegistry.coordinator?.invalidateDomains({
        AppRealtimeDomain.home,
        AppRealtimeDomain.wallet,
        AppRealtimeDomain.transactions,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Não foi possível vincular. O lançamento pode já ter sido usado ou o saldo do compromisso mudou. Atualize e confira novamente.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('usar uma saída já registrada'),
    content: SizedBox(
      width: 560,
      height: (MediaQuery.sizeOf(context).height * .55).clamp(180.0, 440.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.targetName),
          const Text(
            'Sugestões por valor; nenhuma correspondência é confirmada automaticamente.',
          ),
          TextField(
            decoration: const InputDecoration(
              labelText: 'buscar descrição ou conta',
            ),
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Expanded(
            child: FutureBuilder<List<TransactionItem>>(
              future: _rows,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Column(
                    children: [
                      const Text('Não foi possível consultar as saídas.'),
                      TextButton(
                        onPressed: () =>
                            setState(() => _rows = widget.loadCandidates()),
                        child: const Text('tentar novamente'),
                      ),
                    ],
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snapshot.data!
                    .where(
                      (r) => '${r.description} ${r.accountName}'
                          .toLowerCase()
                          .contains(_query),
                    )
                    .toList();
                if (rows.isEmpty) {
                  return const Center(
                    child: Text(
                      'Nenhuma saída elegível. Você pode voltar e registrar um novo pagamento.',
                    ),
                  );
                }
                return ValueListenableBuilder<bool>(
                  valueListenable: FinancialPrivacy.hidden,
                  builder: (context, hidden, _) => ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, index) {
                      final r = rows[index];
                      return ListTile(
                        enabled: !_saving && !_choosing,
                        title: Text(r.description),
                        subtitle: Text(
                          '${r.accountName ?? 'conta'} · ${Formatters.fullDate.format(r.occurredAt)}',
                        ),
                        trailing: Text(
                          hidden ? '••••' : Formatters.money(r.amount),
                        ),
                        onTap: () => _choose(r),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context, false),
        child: const Text('voltar'),
      ),
    ],
  );
}
