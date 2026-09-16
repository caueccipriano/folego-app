import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/recurring_item.dart';
import '../../data/models/transaction_detail.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_actions.dart';
import '../../data/repositories/folego_repository_transaction_detail.dart';
import 'recurring_form_sheet.dart';
import 'transaction_action_sheets.dart';
import 'transaction_edit_sheet.dart';

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
        child: TransactionDetailPanel(
          space: space,
          repository: repository,
          eventId: eventId,
        ),
      ),
    );
  }

  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 780,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .86,
        ),
        child: TransactionDetailPanel(
          space: space,
          repository: repository,
          eventId: eventId,
        ),
      ),
    ),
  );
}

class TransactionDetailPanel extends StatefulWidget {
  const TransactionDetailPanel({
    super.key,
    required this.space,
    required this.repository,
    required this.eventId,
  });

  final FinancialSpace space;
  final FolegoRepository repository;
  final String eventId;

  @override
  State<TransactionDetailPanel> createState() => _TransactionDetailPanelState();
}

class _TransactionDetailPanelState extends State<TransactionDetailPanel> {
  TransactionDetail? _detail;
  bool _loading = true;
  bool _working = false;
  bool _changed = false;
  String? _error;

  bool get _compact => AppBreakpoints.of(context) == AppLayoutSize.compact;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final value = await widget.repository.getTransactionDetail(
        spaceId: widget.space.id,
        eventId: widget.eventId,
      );
      if (!mounted) return;
      setState(() {
        _detail = value;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _friendly(error);
      });
    }
  }

  Future<bool?> _showEditor(Widget child) {
    if (_compact) {
      return showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => child,
      );
    }
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppContentWidths.form,
            maxHeight: 820,
          ),
          child: child,
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final detail = _detail;
    if (detail == null || !detail.canEdit || _working) return;

    bool? saved;
    if (detail.isSimple) {
      final accountId = detail.eventType == 'income'
          ? detail.destinationAccountId
          : detail.sourceAccountId;
      final accountName = detail.eventType == 'income'
          ? detail.destinationAccountName
          : detail.sourceAccountName;
      saved = await _showEditor(
        TransactionEditSheet(
          space: widget.space,
          repository: widget.repository,
          transaction: TransactionItem(
            id: detail.id,
            eventType: detail.eventType,
            description: detail.description,
            amount: detail.amount,
            occurredAt: detail.occurredAt,
            competenceDate: detail.competenceDate,
            status: detail.status,
            source: detail.source,
            categoryId: detail.categoryId,
            categoryName: detail.categoryName,
            accountId: accountId,
            accountName: accountName,
          ),
        ),
      );
    } else if (detail.isCardPurchase) {
      saved = await _showEditor(
        CardPurchaseEditSheet(repository: widget.repository, detail: detail),
      );
    } else if (detail.isBenefitExpense) {
      saved = await _showEditor(
        BenefitExpenseEditSheet(repository: widget.repository, detail: detail),
      );
    } else if (detail.isCanonicalTransfer) {
      saved = await _showEditor(
        TransferEditSheet(repository: widget.repository, detail: detail),
      );
    }

    if (saved == true && mounted) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _editRecurringOrigin() async {
    final id = _detail?.recurringItemId;
    if (id == null || _working) return;
    setState(() => _working = true);
    try {
      final items = await widget.repository.listRecurringItems(widget.space.id);
      RecurringItem? recurring;
      for (final item in items) {
        if (item.id == id) {
          recurring = item;
          break;
        }
      }
      if (!mounted) return;
      setState(() => _working = false);
      if (recurring == null) {
        setState(() => _error = 'Essa recorrência não está mais disponível.');
        return;
      }
      final saved = await _showEditor(
        RecurringFormSheet(
          space: widget.space,
          repository: widget.repository,
          item: recurring,
        ),
      );
      if (saved == true && mounted) {
        _changed = true;
        await _load();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _friendly(error);
      });
    }
  }

  Future<void> _reverse() async {
    final detail = _detail;
    if (detail == null || !detail.canReverse || _working) return;
    final copy = transactionReverseCopy(detail);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(copy.$1),
        content: Text(copy.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('manter'),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.expenseText(
                Theme.of(dialogContext).brightness,
              ),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(copy.$3),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _working = true);
    try {
      if (detail.isSimple) {
        await widget.repository.cancelSimpleTransaction(
          spaceId: detail.spaceId,
          eventId: detail.id,
        );
      } else if (detail.isCardPurchase) {
        await widget.repository.cancelCardPurchase(
          spaceId: detail.spaceId,
          eventId: detail.id,
        );
      } else if (detail.isBenefitExpense) {
        await widget.repository.cancelBenefitExpense(
          spaceId: detail.spaceId,
          eventId: detail.id,
        );
      } else if (detail.isCanonicalTransfer) {
        await widget.repository.cancelTransferTransaction(
          spaceId: detail.spaceId,
          eventId: detail.id,
        );
      } else if (detail.isCardPayment) {
        await widget.repository.reverseCardPayment(
          spaceId: detail.spaceId,
          eventId: detail.id,
        );
      } else {
        throw StateError('Ação indisponível para este lançamento.');
      }
      if (!mounted) return;
      _changed = true;
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _working = false;
        _error = _friendly(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final body = _loading
        ? const SizedBox(
            height: 240,
            child: Center(child: CircularProgressIndicator()),
          )
        : _error != null && _detail == null
            ? SizedBox(height: 260, child: _errorView(brightness))
            : _detailBody(brightness);

    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(_compact ? 28 : 24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          mainAxisSize: _compact ? MainAxisSize.max : MainAxisSize.min,
          children: [
            _header(brightness),
            if (_compact) Expanded(child: body) else Flexible(child: body),
          ],
        ),
      ),
    );
  }

  Widget _header(Brightness brightness) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'detalhe do lançamento',
                style: AppTypography.section(
                  context,
                  fontSize: 18,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ),
            IconButton(
              tooltip: 'fechar detalhe',
              onPressed: () => Navigator.of(context).pop(_changed),
              icon: const Icon(AppIcons.close),
            ),
          ],
        ),
      );

  Widget _errorView(Brightness brightness) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                AppIcons.warning,
                color: AppColors.expenseText(brightness),
                size: 32,
              ),
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _load,
                child: const Text('tentar novamente'),
              ),
            ],
          ),
        ),
      );

  Widget _detailBody(Brightness brightness) {
    final detail = _detail!;
    final source = transactionSourceLabel(detail.source);
    final displayDescription = financialDisplayDescription(detail.description);
    final specificRows = _specificRows(detail);
    final readOnly = transactionReadOnlyMessage(detail);

    return ListView(
      shrinkWrap: !_compact,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Hero(
          detail: detail,
          description: displayDescription.isEmpty
              ? detail.typeLabel
              : displayDescription,
        ),
        if (detail.legacyException) ...[
          const SizedBox(height: 14),
          _LegacyCard(
            title: detail.legacyTitle ?? 'registro histórico',
            message: detail.legacyMessage ??
                'Parte do histórico original não estava disponível.',
          ),
        ],
        const SizedBox(height: 18),
        _Section(
          title: 'sobre este lançamento',
          children: [
            _DetailRow('tipo', detail.typeLabel),
            _DetailRow('data', _fullDate(detail.occurredAt)),
            if (detail.competenceDate != null)
              _DetailRow('competência', _fullDate(detail.competenceDate!)),
            _DetailRow('status', _statusLabel(detail.status)),
            if (detail.categoryName != null)
              _DetailRow('categoria', _categoryLabel(detail)),
            if (source != null) _DetailRow('origem', source),
          ],
        ),
        if (specificRows.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(title: 'como aconteceu', children: specificRows),
        ],
        if (detail.installments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'parcelas e faturas',
            children: [
              for (final item in detail.installments)
                _DetailRow(
                  'parcela ${item.number} de ${item.total}',
                  '${Formatters.money(item.amount)} · '
                  '${item.invoiceDueDate == null ? 'fatura sem vencimento' : 'vence ${_shortDate(item.invoiceDueDate!)}'} · '
                  '${_invoiceStatus(item.invoiceStatus)}',
                ),
            ],
          ),
        ],
        if (detail.recurringItemName != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'recorrência',
            children: [
              _DetailRow('origem', detail.recurringItemName!),
              if (detail.recurringDueDate != null)
                _DetailRow('ocorrência', _fullDate(detail.recurringDueDate!)),
              if (detail.recurringItemId != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: const ValueKey('transaction-edit-recurring-origin'),
                    onPressed: _working ? null : _editRecurringOrigin,
                    icon: const Icon(AppIcons.recurring, size: 17),
                    label: const Text('editar recorrência'),
                  ),
                ),
            ],
          ),
        ],
        if (detail.reflectionType != null) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'diário',
            children: [
              _DetailRow('reflexão', _reflectionLabel(detail.reflectionType!)),
              if (detail.reflectionNote?.trim().isNotEmpty == true)
                _DetailRow('nota', detail.reflectionNote!.trim()),
            ],
          ),
        ],
        if (readOnly != null) ...[
          const SizedBox(height: 16),
          _Notice(text: readOnly),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.expenseText(brightness),
            ),
          ),
        ],
        if (detail.canEdit || detail.canReverse) ...[
          const SizedBox(height: 22),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              if (detail.canEdit)
                FilledButton.icon(
                  key: const ValueKey('transaction-edit-action'),
                  onPressed: _working ? null : _edit,
                  icon: const Icon(AppIcons.edit, size: 18),
                  label: Text(_editLabel(detail)),
                ),
              if (detail.canReverse)
                Semantics(
                  button: true,
                  label: _reverseLabel(detail),
                  child: OutlinedButton.icon(
                    key: const ValueKey('transaction-reverse-action'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.expenseText(brightness),
                    ),
                    onPressed: _working ? null : _reverse,
                    icon: _working
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.refresh, size: 18),
                    label: Text(_reverseLabel(detail)),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }

  List<Widget> _specificRows(TransactionDetail detail) {
    final rows = <Widget>[];
    if (detail.isCardPurchase) {
      if (detail.cardName != null) rows.add(_DetailRow('cartão', detail.cardName!));
      if (detail.cardMerchant?.trim().isNotEmpty == true) {
        rows.add(_DetailRow('estabelecimento', detail.cardMerchant!.trim()));
      }
      if (detail.cardInstallmentsCount != null) {
        rows.add(_DetailRow('parcelamento', '${detail.cardInstallmentsCount}x'));
      }
      if (detail.cardPurchaseRestriction != null && !detail.cardPurchaseFinancialEditable) {
        rows.add(_DetailRow('proteção', detail.cardPurchaseRestriction!));
      }
    } else if (detail.isBenefitExpense) {
      if (detail.benefitAccountName != null) {
        rows.add(_DetailRow('benefício', detail.benefitAccountName!));
      }
      rows.add(const _DetailRow('caixa', 'não movimenta dinheiro da conta'));
    } else if (detail.eventType == 'transfer') {
      if (detail.sourceAccountName != null) {
        rows.add(_DetailRow('origem', detail.sourceAccountName!));
      }
      if (detail.destinationAccountName != null) {
        rows.add(_DetailRow('destino', detail.destinationAccountName!));
      }
    } else if (detail.isCardPayment) {
      if (detail.cardName != null) rows.add(_DetailRow('cartão', detail.cardName!));
      if (detail.cardPaymentAccountName != null) {
        rows.add(_DetailRow('conta pagadora', detail.cardPaymentAccountName!));
      }
      if (detail.cardPaymentType != null) {
        rows.add(_DetailRow(
          'tipo',
          detail.cardPaymentType == 'advance' ? 'adiantamento' : 'pagamento',
        ));
      }
      if (detail.cardPaymentInvoiceDueDate != null) {
        rows.add(_DetailRow(
          'fatura',
          'vence ${_fullDate(detail.cardPaymentInvoiceDueDate!)}',
        ));
      }
    } else if (detail.eventType == 'debt_payment') {
      if (detail.debtName != null) rows.add(_DetailRow('dívida', detail.debtName!));
      if (detail.debtCreditor != null) rows.add(_DetailRow('credor', detail.debtCreditor!));
    } else {
      final account = detail.eventType == 'income'
          ? detail.destinationAccountName
          : detail.sourceAccountName;
      if (account != null) rows.add(_DetailRow('conta', account));
    }
    return rows;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail, required this.description});
  final TransactionDetail detail;
  final String description;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final positive = detail.eventType == 'income' ||
        detail.eventType == 'refund' ||
        detail.eventType == 'reimbursement';
    final tone = positive
        ? AppColors.positiveText(brightness)
        : AppColors.primaryText(brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            description,
            style: AppTypography.section(
              context,
              fontSize: 18,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            Formatters.money(detail.amount.abs()),
            style: AppTypography.money(context, fontSize: 30, color: tone),
          ),
          const SizedBox(height: 4),
          Text(
            detail.typeLabel,
            style: AppTypography.label(
              context,
              fontSize: 10,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: purple.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: purple.withValues(alpha: .20)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AppIcons.info, color: purple, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: AppColors.secondaryText(brightness),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            title,
            style: AppTypography.section(
              context,
              fontSize: 14,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 9),
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index < children.length - 1)
              Divider(height: 16, color: AppColors.border(brightness)),
          ],
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
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 112,
          child: Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 9,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value,
            style: AppTypography.body(
              context,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.background(brightness),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(
        text,
        style: AppTypography.body(
          context,
          fontSize: 10,
          color: AppColors.secondaryText(brightness),
        ),
      ),
    );
  }
}

(String, String, String) transactionReverseCopy(TransactionDetail detail) {
  switch (detail.eventType) {
    case 'card_payment':
      return (
        'reverter este pagamento?',
        'A conta pagadora receberá ${Formatters.money(detail.amount.abs())} de volta e a fatura voltará a refletir esse valor em aberto.',
        'reverter pagamento',
      );
    case 'card_purchase':
      return (
        'cancelar esta compra?',
        'A compra e as parcelas serão canceladas sem apagar o histórico. A operação só é permitida enquanto as faturas relacionadas puderem ser alteradas com segurança.',
        'cancelar compra',
      );
    case 'benefit_expense':
      return (
        'cancelar este gasto?',
        'O saldo do benefício, o resultado econômico e o orçamento serão restaurados. O caixa continua sem alteração.',
        'cancelar gasto',
      );
    case 'transfer':
      return (
        'cancelar esta transferência?',
        'Os dois lados da transferência serão revertidos juntos e o histórico será preservado.',
        'cancelar transferência',
      );
    default:
      return (
        'cancelar este lançamento?',
        'Os impactos financeiros deste lançamento serão removidos e o histórico será preservado.',
        'cancelar lançamento',
      );
  }
}

String? transactionSourceLabel(String value) {
  switch (value.trim().toLowerCase().replaceAll('_', '-')) {
    case 'app':
    case 'manual':
      return 'Adicionado manualmente';
    case 'plan':
      return 'Planejamento';
    case 'reconciliation':
      return 'Reconciliação';
    case 'statement-import':
      return 'Importado de extrato';
    case 'sheet-sync':
      return 'Importação histórica';
    case 'sheet-rebuild-anchor':
      return 'Reconciliação histórica';
    case 'recurring':
    case 'recurrence':
      return 'Recorrência';
    case 'onboarding':
      return 'Configuração inicial';
    default:
      return null;
  }
}

String? transactionReadOnlyMessage(TransactionDetail detail) {
  if (detail.legacyException) {
    return 'Este registro veio do histórico e não possui informação suficiente para uma alteração segura.';
  }
  switch (detail.eventType) {
    case 'opening_balance':
      return 'Este saldo inicial abriu o saldo da conta e não é tratado como receita.';
    case 'debt_payment':
      return 'Este pagamento é gerenciado pela dívida correspondente. Ajustes devem ser feitos na Carteira para preservar o histórico da dívida.';
    case 'refund':
      return 'Este estorno faz parte do histórico. Como o lançamento original não está vinculado de forma segura, ele fica somente para consulta.';
    case 'reimbursement':
      return 'Este reembolso faz parte do histórico e fica somente para consulta quando não há vínculo seguro com a origem.';
    case 'adjustment':
      return detail.source == 'reconciliation'
          ? 'Este ajuste foi usado para reconciliar um saldo anterior e não pode ser alterado.'
          : 'Este ajuste preserva uma correção de saldo e fica somente para consulta.';
    case 'reserve_transfer':
      return detail.source == 'plan'
          ? 'Este aporte foi criado automaticamente pelo seu planejamento.'
          : 'Este movimento faz parte do histórico da reserva e não deve ser alterado como um gasto comum.';
    case 'benefit_credit':
      return 'Este crédito atualiza o saldo do benefício e não movimenta o caixa.';
  }
  if (detail.isCardPayment && !detail.cardPaymentReversible) {
    return detail.cardPaymentRestriction ??
        'Este pagamento já afeta um período posterior e não pode ser revertido automaticamente.';
  }
  if (detail.isCardPurchase && !detail.cardPurchaseFinancialEditable) {
    return detail.cardPurchaseRestriction;
  }
  return null;
}

String _editLabel(TransactionDetail detail) {
  if (detail.isCardPurchase) return 'editar compra';
  if (detail.isCanonicalTransfer) return 'editar transferência';
  if (detail.isBenefitExpense) return 'editar gasto';
  return 'editar lançamento';
}

String _reverseLabel(TransactionDetail detail) {
  if (detail.isCardPayment) return 'reverter pagamento';
  if (detail.isCardPurchase) return 'cancelar compra';
  if (detail.isCanonicalTransfer) return 'cancelar transferência';
  if (detail.isBenefitExpense) return 'cancelar gasto';
  return 'cancelar lançamento';
}

String _categoryLabel(TransactionDetail detail) {
  final parent = detail.categoryParentName?.trim();
  return parent == null || parent.isEmpty
      ? detail.categoryName!
      : '$parent › ${detail.categoryName}';
}

String _fullDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';

String _shortDate(DateTime value) =>
    '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}';

String _statusLabel(String value) => switch (value) {
      'confirmed' => 'confirmado',
      'cancelled' => 'cancelado',
      'pending' => 'pendente',
      'ignored' => 'ignorado',
      _ => value,
    };

String _invoiceStatus(String? value) => switch (value) {
      'open' => 'aberta',
      'closed' => 'fechada',
      'paid' => 'paga',
      'partially_paid' => 'parcialmente paga',
      'overdue' => 'atrasada',
      'cancelled' => 'cancelada',
      null => 'fatura',
      _ => value,
    };

String _reflectionLabel(String value) => switch (value) {
      'necessary' => 'necessário',
      'want' => 'vontade',
      'self_investment' => 'investimento em mim',
      _ => value,
    };

String _friendly(Object error) => error
    .toString()
    .replaceFirst('Exception: ', '')
    .replaceFirst('Bad state: ', '');
