import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_detail.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_detail.dart';

Future<bool?> showTransactionDetail({
  required BuildContext context,
  required FinancialSpace space,
  required FolegoRepository repository,
  required String eventId,
}) {
  final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
  if (compact) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: .94,
        child: TransactionDetailPanel(space: space, repository: repository, eventId: eventId),
      ),
    );
  }
  return showDialog<bool>(
    context: context,
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 900),
        child: TransactionDetailPanel(space: space, repository: repository, eventId: eventId),
      ),
    ),
  );
}

class TransactionDetailPanel extends StatefulWidget {
  const TransactionDetailPanel({super.key, required this.space, required this.repository, required this.eventId});
  final FinancialSpace space;
  final FolegoRepository repository;
  final String eventId;

  @override
  State<TransactionDetailPanel> createState() => _TransactionDetailPanelState();
}

class _TransactionDetailPanelState extends State<TransactionDetailPanel> {
  TransactionDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final value = await widget.repository.getTransactionDetail(spaceId: widget.space.id, eventId: widget.eventId);
      if (!mounted) return;
      setState(() { _detail = value; _loading = false; });
    } catch (error) {
      if (!mounted) return;
      setState(() { _loading = false; _error = error.toString().replaceFirst('Exception: ', ''); });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(AppBreakpoints.of(context) == AppLayoutSize.compact ? 28 : 24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
              child: Row(children: [
                Expanded(child: Text('detalhe do lançamento', style: AppTypography.section(context, fontSize: 18, color: AppColors.primaryText(brightness)))),
                IconButton(tooltip: 'fechar', onPressed: () => Navigator.of(context).pop(false), icon: const Icon(AppIcons.close)),
              ]),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _detail == null
                      ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(_error!, textAlign: TextAlign.center)))
                      : _body(brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(Brightness brightness) {
    final detail = _detail!;
    final description = financialDisplayDescription(detail.description);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Hero(detail: detail, description: description.isEmpty ? detail.typeLabel : description),
        if (detail.legacyException) ...[
          const SizedBox(height: 14),
          _LegacyCard(title: detail.legacyTitle ?? 'registro histórico', message: detail.legacyMessage ?? 'parte do histórico original não estava disponível na importação.'),
        ],
        const SizedBox(height: 18),
        _Section(title: 'sobre este lançamento', children: [
          _DetailRow('tipo', detail.typeLabel),
          _DetailRow('data', _fullDate(detail.occurredAt)),
          if (detail.competenceDate != null) _DetailRow('competência', _fullDate(detail.competenceDate!)),
          _DetailRow('status', detail.status),
          if (detail.categoryName != null) _DetailRow('categoria', detail.categoryParentName == null ? detail.categoryName! : '${detail.categoryParentName} › ${detail.categoryName}'),
          _DetailRow('origem', detail.source),
        ]),
        if (_specific(detail).isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(title: 'como aconteceu', children: _specific(detail)),
        ],
        if (detail.installments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(title: 'parcelas e faturas', children: detail.installments.map((item) => _DetailRow('parcela ${item.number} de ${item.total}', '${Formatters.money(item.amount)} · ${item.invoiceDueDate == null ? 'fatura sem vencimento' : 'vence ${_fullDate(item.invoiceDueDate!)}'}')).toList()),
        ],
        if (detail.recurringItemName != null) ...[
          const SizedBox(height: 16),
          _Section(title: 'recorrência', children: [_DetailRow('origem', detail.recurringItemName!), if (detail.recurringDueDate != null) _DetailRow('ocorrência', _fullDate(detail.recurringDueDate!))]),
        ],
        if (detail.reflectionType != null) ...[
          const SizedBox(height: 16),
          _Section(title: 'diário', children: [_DetailRow('reflexão', detail.reflectionType!), if (detail.reflectionNote?.trim().isNotEmpty == true) _DetailRow('nota', detail.reflectionNote!.trim())]),
        ],
        const SizedBox(height: 16),
        _Notice(text: _readOnlyMessage(detail)),
      ],
    );
  }

  List<Widget> _specific(TransactionDetail detail) {
    final rows = <Widget>[];
    if (detail.isCardPurchase) {
      if (detail.cardName != null) rows.add(_DetailRow('cartão', detail.cardName!));
      if (detail.cardMerchant?.trim().isNotEmpty == true) rows.add(_DetailRow('estabelecimento', detail.cardMerchant!.trim()));
      if (detail.cardInstallmentsCount != null) rows.add(_DetailRow('parcelamento', '${detail.cardInstallmentsCount}x'));
    } else if (detail.isBenefitExpense) {
      if (detail.benefitAccountName != null) rows.add(_DetailRow('benefício', detail.benefitAccountName!));
    } else if (detail.eventType == 'transfer') {
      if (detail.sourceAccountName != null) rows.add(_DetailRow('origem', detail.sourceAccountName!));
      if (detail.destinationAccountName != null) rows.add(_DetailRow('destino', detail.destinationAccountName!));
    } else if (detail.isCardPayment) {
      if (detail.cardName != null) rows.add(_DetailRow('cartão', detail.cardName!));
      if (detail.cardPaymentAccountName != null) rows.add(_DetailRow('conta pagadora', detail.cardPaymentAccountName!));
      if (detail.cardPaymentType != null) rows.add(_DetailRow('tipo', detail.cardPaymentType == 'advance' ? 'adiantamento' : 'pagamento'));
    } else if (detail.eventType == 'debt_payment') {
      if (detail.debtName != null) rows.add(_DetailRow('dívida', detail.debtName!));
      if (detail.debtCreditor != null) rows.add(_DetailRow('credor', detail.debtCreditor!));
    } else {
      final account = detail.eventType == 'income' ? detail.destinationAccountName : detail.sourceAccountName;
      if (account != null) rows.add(_DetailRow('conta', account));
    }
    return rows;
  }

  String _readOnlyMessage(TransactionDetail detail) {
    if (detail.legacyException) return 'este registro histórico é uma exceção documentada do ledger e fica somente para consulta.';
    if (detail.eventType == 'opening_balance') return 'saldo inicial é mostrado como registro de abertura e não é tratado como receita.';
    if (detail.eventType == 'debt_payment') return 'esse lançamento é gerenciado pela dívida.';
    return 'ações específicas deste tipo aparecem apenas quando há um fluxo financeiro seguro.';
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail, required this.description});
  final TransactionDetail detail;
  final String description;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: AppColors.background(brightness), borderRadius: BorderRadius.circular(22), border: Border.all(color: AppColors.border(brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(description, style: AppTypography.section(context, fontSize: 18, color: AppColors.primaryText(brightness))),
        const SizedBox(height: 8),
        Text(Formatters.money(detail.amount.abs()), style: AppTypography.money(context, fontSize: 30)),
        const SizedBox(height: 4),
        Text(detail.typeLabel, style: AppTypography.label(context, fontSize: 10, color: AppColors.secondaryText(brightness))),
      ]),
    );
  }
}

class _LegacyCard extends StatelessWidget {
  const _LegacyCard({required this.title, required this.message});
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: purple.withValues(alpha: .08), borderRadius: BorderRadius.circular(18), border: Border.all(color: purple.withValues(alpha: .20))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Icon(AppIcons.info, color: purple, size: 20), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: AppTypography.body(context, fontSize: 12, fontWeight: FontWeight.w700)), const SizedBox(height: 3), Text(message, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness)))]))]),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppColors.surface(brightness), borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.border(brightness))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Text(title, style: AppTypography.section(context, fontSize: 14)), const SizedBox(height: 9), ...children]),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [SizedBox(width: 112, child: Text(label, style: AppTypography.label(context, fontSize: 9, color: AppColors.secondaryText(brightness)))), const SizedBox(width: 10), Expanded(child: Text(value, style: AppTypography.body(context, fontSize: 11, fontWeight: FontWeight.w600)))]),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(padding: const EdgeInsets.all(13), decoration: BoxDecoration(color: AppColors.background(brightness), borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border(brightness))), child: Text(text, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness))));
  }
}

String _fullDate(DateTime value) => '${value.day.toString().padLeft(2,'0')}/${value.month.toString().padLeft(2,'0')}/${value.year}';
