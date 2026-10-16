import 'package:flutter/material.dart';

import '../../core/utils/formatters.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/financial_space.dart';
import '../../data/smart_category_suggestion.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_notifications.dart';
import '../transactions/transaction_detail_sheet_v2.dart';
import '../transactions/transactions_screen.dart';

/// A receipt is evidence to review, never a confirmed financial event.
class CaptureReviewScreen extends StatefulWidget {
  const CaptureReviewScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.captureId,
  });
  final FolegoRepository repository;
  final String spaceId, captureId;
  @override
  State<CaptureReviewScreen> createState() => _CaptureReviewScreenState();
}

class _CaptureReviewScreenState extends State<CaptureReviewScreen> {
  late Future<Map<String, dynamic>?> _capture;
  @override
  void initState() {
    super.initState();
    _capture = _loadCapture();
  }

  Future<Map<String, dynamic>?> _loadCapture() async {
    final data = await widget.repository.getCaptureForReview(
      widget.spaceId,
      widget.captureId,
    );
    if (data == null) return null;
    final metadata = data['metadata'] is Map
        ? Map<String, dynamic>.from(data['metadata'] as Map)
        : <String, dynamic>{};
    // A suggestion is read-only; own-account transfers and unknown directions
    // never receive an economic category from their amount alone.
    final direction = captureSuggestionEventType(data['direction'], metadata);
    if (metadata['suggested_category'] == null && direction != null) {
      try {
        final categories = direction == 'income'
            ? await widget.repository.listIncomeCategories(widget.spaceId)
            : await widget.repository.listExpenseCategories(widget.spaceId);
        final history = await widget.repository.getTransactionsPage(
          widget.spaceId,
        );
        final suggestion = suggestSmartCategory(
          description:
              data['description']?.toString() ??
              data['counterparty']?.toString() ??
              '',
          eventType: direction,
          history: history.items,
          categories: categories,
        );
        if (suggestion != null) {
          metadata['suggested_category'] = suggestion.category.breadcrumb;
          metadata['suggestion_reason'] = suggestion.reason;
        }
      } catch (_) {
        // Category suggestions are optional; a receipt must remain reviewable
        // even if the category catalog or history is temporarily unavailable.
      }
    }
    return {...data, 'metadata': metadata};
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background(Theme.of(context).brightness),
    appBar: AppBar(title: const Text('conferir comprovante')),
    body: FutureBuilder<Map<String, dynamic>?>(
      future: _capture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done)
          return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError || snapshot.data == null)
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('não consegui carregar este comprovante'),
                TextButton(
                  onPressed: () => setState(() => _capture = _loadCapture()),
                  child: const Text('tentar novamente'),
                ),
              ],
            ),
          );
        final data = snapshot.data!;
        final metadata = data['metadata'] is Map
            ? Map<String, dynamic>.from(data['metadata'] as Map)
            : <String, dynamic>{};
        final eventId =
            data['linked_event_id']?.toString() ??
            metadata['candidate_event_id']?.toString();
        final amount = num.tryParse(data['amount']?.toString() ?? '');
        return ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              data['description']?.toString() ??
                  data['counterparty']?.toString() ??
                  'comprovante Mercado Pago',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 16),
            Text(switch (data['review_status']) {
              'linked' => 'comprovante vinculado ao lançamento existente · nenhum lançamento adicional foi criado.',
              'ignored' => 'comprovante arquivado sem efeito financeiro.',
              _ => 'pendente de revisão · este comprovante não confirma uma receita ou despesa e não altera seu saldo.',
            }),
            const SizedBox(height: 24),
            if (amount != null)
              Text(
                Formatters.money(amount),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
            const SizedBox(height: 12),
            Text('conta: ${data['account_name'] ?? 'Mercado Pago'}'),
            Text(
              'data do comprovante: ${captureDateLabel(data['occurred_at'] ?? data['occurred_date'])}',
            ),
            Text('beneficiário: ${data['counterparty'] ?? 'não identificado'}'),
            const SizedBox(height: 20),
            Text(
              captureReviewReason(
                data['review_reason']?.toString(),
                metadata['difference'],
              ),
            ),
            if (metadata['suggested_category'] != null)
              Text('sugestão de categoria: ${metadata['suggested_category']}'),
            const SizedBox(height: 24),
            if (eventId != null)
              FilledButton(
                onPressed: () => showTransactionDetail(
                  context: context,
                  space: FinancialSpace(
                    id: widget.spaceId,
                    name: 'Minhas finanças',
                  ),
                  repository: widget.repository,
                  eventId: eventId,
                ),
                child: const Text('revisar lançamento correspondente'),
              ),
            OutlinedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TransactionsScreen(
                    repository: widget.repository,
                    space: FinancialSpace(
                      id: widget.spaceId,
                      name: 'Minhas finanças',
                    ),
                    initialPushRoute: '/transactions/classification',
                  ),
                ),
              ),
              child: const Text('abrir classificação de lançamentos'),
            ),
            const SizedBox(height: 12),
            const Text(
              'nenhum lançamento é criado ao abrir este comprovante. use a revisão existente para conferir seus registros antes de qualquer alteração.',
            ),
          ],
        );
      },
    ),
  );
}

String captureReviewReason(String? reason, dynamic difference) {
  switch (reason) {
    case 'amount_mismatch':
      final value = num.tryParse(difference?.toString() ?? '');
      return 'o valor do comprovante difere do lançamento existente${value == null ? '' : ' em ${Formatters.money(value.abs())}'}. confira antes de corrigir; nenhum valor foi alterado.';
    case 'no_exact_match':
    case 'no_matching_transaction':
      return 'não encontrei um lançamento correspondente. confira seus registros antes de cadastrar qualquer movimentação.';
    case 'multiple_compatible_events':
    case 'ambiguous_match':
      return 'mais de um lançamento pode corresponder a este comprovante. confira qual é o correto.';
    case 'invalid_receipt':
      return 'o comprovante não contém todos os dados necessários para validação. confira a origem e as informações da operação.';
    case 'direction_unknown':
      return 'não foi possível identificar com segurança se o dinheiro entrou ou saiu. confira o comprovante; nenhum saldo foi alterado.';
    case 'scan_limit':
      return 'a consulta atingiu o limite de registros. confira os lançamentos antes de decidir se esta movimentação já existe.';
    case 'existing_confirmed_event':
      return 'esta movimentação já está registrada. confira o lançamento vinculado; nenhum lançamento adicional foi criado.';
    case 'counterparty_mismatch':
      return 'o beneficiário do comprovante difere do lançamento encontrado. confira os dados antes de vincular ou corrigir.';
    case 'context_unknown':
    case 'insufficient_context':
      return 'faltam informações para confirmar a correspondência. confira beneficiário, conta, data e valor.';
    default:
      return 'este comprovante precisa de conferência. compare beneficiário, conta, data e valor com seus lançamentos; nenhum saldo foi alterado.';
  }
}

String captureDateLabel(dynamic raw) {
  final value = DateTime.tryParse(raw?.toString() ?? '');
  if (value == null) return 'a conferir';
  final local = raw.toString().length <= 10
      ? value
      : value.toUtc().subtract(const Duration(hours: 3));
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '${Formatters.fullDate.format(local)} · $hour:$minute · São Paulo';
}

String? captureSuggestionEventType(
  dynamic direction,
  Map<String, dynamic> metadata,
) {
  if (metadata['is_internal_transfer'] == true ||
      metadata['event_type'] == 'transfer' ||
      metadata['classification'] == 'transfer')
    return null;
  return switch (direction) {
    'in' => 'income',
    'out' => 'expense',
    _ => null,
  };
}
