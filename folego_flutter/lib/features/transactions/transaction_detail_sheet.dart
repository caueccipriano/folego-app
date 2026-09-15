import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/financial_display_text.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_detail.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_actions.dart';
import '../../data/repositories/folego_repository_transaction_detail.dart';
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
    builder: (_) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 820, maxHeight: 900),
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
    if (AppBreakpoints.of(context) == AppLayoutSize.compact) {
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
        insetPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppContentWidths.form, maxHeight: 820),
          child: child,
        ),
      ),
    );
  }

  Future<void> _edit() async {
    final detail = _detail;
    if (detail == null || !detail.canEdit) return;

    bool? saved;
    if (detail.isSimple) {
      final accountId = detail.eventType == 'income'
          ? detail.destinationAccountId
          : detail.sourceAccountId;
      final accountName = detail.eventType == 'income'
          ? detail.destinationAccountName
          : detail.sourceAccountName;
      final item = TransactionItem(
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
      );
      saved = await _showEditor(
        TransactionEditSheet(
          space: widget.space,
          repository: widget.repository,
          transaction: item,
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

  Future<void> _reverse() async {
    final detail = _detail;
    if (detail == null || !detail.canReverse || _working) return;
    final copy = _reverseCopy(detail);
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
          FilledButton(
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
        throw StateError('Ação não disponível para este tipo.');
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
    final surface = AppColors.surface(brightness);
    return Material(
      color: surface,
      borderRadius: BorderRadius.circular(
        AppBreakpoints.of(context) == AppLayoutSize.compact ? 28 : 24,
      ),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Column(
          children: [
            _header(brightness),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null && _detail == null
                      ? _errorView(brightness)
                      : _detailBody(brightness),
            ),
          ],
        ),
      ),
    );
  }

  Widget _header(Brightness brightness) {
    return Padding(
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
            tooltip: 'fechar',
            onPressed: () => Navigator.of(context).pop(_changed),
            icon: const Icon(AppIcons.close),
          ),
        ],
      ),
    );
  }

  Widget _errorView(Brightness brightness) {
    return Center(
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
            OutlinedButton(onPressed: _load, child: const Text('tentar novamente')),
          ],
        ),
      ),
    );
  }

  Widget _detailBody(Brightness brightness) {
    final detail = _detail!;
    final secondary = AppColors.secondaryText(brightness);
    final displayDescription = financialDisplayDescription(detail.description);
    return ListView(
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
                'parte do histórico original não estava disponível na importação.',
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
            _DetailRow('origem', _sourceLabel(detail.source)),
          ],
        ),
        if (_specificRows(detail).isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(title: 'como aconteceu', children: _specificRows(detail)),
        ],
        if (detail.installments.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'parcelas e faturas',
            children: detail.installments
                .map(
                  (item) => _DetailRow(
                    'parcela ${item.number} de ${item.total}',
                    '${Formatters.money(item.amount)} · '
                    '${item.invoiceDueDate == null ? 'fatura sem vencimento' : 'vence ${_shortDate(item.invoiceDueDate!)}'} · '
                    '${_invoiceStatus(item.invoiceStatus)}',
                  ),
                )
                .toList(),
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
        if (_readOnlyMessage(detail) != null) ...[
          const SizedBox(height: 16),
          _Notice(text: _readOnlyMessage(detail)!),
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
          Row(
            children: [
              if (detail.canEdit)
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _working ? null : _edit,
                    icon: const Icon(AppIcons.edit, size: 18),
                    label: const Text('editar'),
                  ),
                ),
              if (detail.canEdit && detail.canReverse)
                const SizedBox(width: 10),
              if (detail.canReverse)
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _working ? null : _reverse,
                    icon: _working
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(AppIcons.refresh, size: 18),
                    label: Text(
                      detail.isCardPayment ? 'reverter pagamento' : 'cancelar',
                    ),
                  ),
                ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        Text(
          'id ${detail.id.length <= 8 ? detail.id : detail.id.substring(0, 8)}',
          textAlign: TextAlign.center,
          style: AppTypography.label(
            context,
            fontSize: 8,
            color: secondary,
          ),
        ),
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
      if (detail.cardPurchaseRestriction != null) {
        rows.add(_DetailRow('edição financeira', detail.cardPurchaseRestriction!));
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
        rows.add(
          _DetailRow(
            'tipo',
            detail.cardPaymentType == 'advance' ? 'adiantamento' : 'pagamento',
          ),
        );
      }
      if (detail.cardPaymentInvoiceDueDate != null) {
        rows.add(
          _DetailRow(
            'fatura',
            'vence ${_fullDate(detail.cardPaymentInvoiceDueDate!)}',
          ),
        );
      }
      if (detail.cardPaymentRestriction != null) {
        rows.add(_DetailRow('reversão', detail.cardPaymentRestriction!));
      }
    } else if (detail.eventType == 'debt_payment') {
      if (detail.debtName != null) rows.add(_DetailRow('dívida', detail.debtName!));
      if (detail.debtCreditor != null) {
        rows.add(_DetailRow('credor', detail.debtCreditor!));
      }
    } else {
      final account = detail.eventType == 'income'
          ? detail.destinationAccountName
          : detail.sourceAccountName;
      if (account != null) rows.add(_DetailRow('conta', account));
    }
    return rows;
  }

  String? _readOnlyMessage(TransactionDetail detail) {
    if (detail.legacyException) {
      return 'este registro histórico é somente leitura porque parte do backing original não estava disponível na importação.';
    }
    if (detail.eventType == 'opening_balance') {
      return 'saldo inicial é mostrado como registro de abertura e não é tratado como receita.';
    }
    if (detail.eventType == 'debt_payment') {
      return 'esse lançamento é gerenciado pela dívida e fica somente para consulta aqui.';
    }
    if (detail.eventType == 'refund' ||
        detail.eventType == 'reimbursement' ||
        detail.eventType == 'adjustment' ||
        detail.eventType == 'reserve_transfer' ||
        detail.eventType == 'benefit_credit') {
      return 'este tipo possui semântica própria e fica somente para consulta até existir uma operação canônica específica.';
    }
    if (detail.isCardPayment && !detail.cardPaymentReversible) {
      return detail.cardPaymentRestriction ??
          'este pagamento não pode ser revertido automaticamente.';
    }
    if (detail.isCardPurchase && !detail.cardPurchaseReversible) {
      return detail.cardPurchaseRestriction;
    }
    return null;
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.detail, required this.description});

  final TransactionDetail detail;
  final String description;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final expense = detail.eventType != 'income' &&
        detail.eventType != 'refund' &&
        detail.eventType != 'reimbursement';
    final tone = expense
        ? AppColors.expenseText(brightness)
        : AppColors.positiveText(brightness);
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
          for (var i = 0; i < children.length; i++) ...[
            children[i],
            if (i < children.length - 1)
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

(String, String, String) _reverseCopy(TransactionDetail detail) {
  switch (detail.eventType) {
    case 'card_payment':
      return (
        'reverter este pagamento?',
        'a conta pagadora receberá ${Formatters.money(detail.amount.abs())} de volta e a fatura voltará a refletir esse valor em aberto.',
        'reverter pagamento',
      );
    case 'card_purchase':
      return (
        'cancelar esta compra?',
        'a compra e as parcelas ficam canceladas sem apagar o histórico. só é permitido quando as faturas relacionadas ainda estão abertas e sem pagamento.',
        'cancelar compra',
      );
    case 'benefit_expense':
      return (
        'cancelar este gasto?',
        'o saldo do benefício, o resultado econômico e o orçamento serão restaurados. caixa continua sem alteração.',
        'cancelar gasto',
      );
    case 'transfer':
      return (
        'cancelar esta transferência?',
        'os dois impactos de caixa serão removidos juntos e o histórico ficará preservado.',
        'cancelar transferência',
      );
    default:
      return (
        'cancelar este lançamento?',
        'os impactos financeiros deste lançamento serão removidos e o histórico ficará preservado.',
        'cancelar',
      );
  }
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
String _sourceLabel(String value) => switch (value) {
      'app' => 'Fôlego',
      'sheet-sync' => 'importação histórica',
      'onboarding' => 'configuração inicial',
      _ => value,
    };
String _friendly(Object error) =>
    error.toString().replaceFirst('Exception: ', '');
