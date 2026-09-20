import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_card_payments.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import 'card_invoice_payment_state.dart';

Future<bool?> showCardInvoicePaymentSheet({
  required BuildContext context,
  required FolegoRepository repository,
  required String spaceId,
  required WalletCard card,
}) {
  final layout = AppBreakpoints.of(context);

  Widget buildContent(BuildContext modalContext, bool dialogMode) {
    return AppContentContainer.form(
      child: _CardInvoicePaymentForm(
        repository: repository,
        spaceId: spaceId,
        card: card,
        dialogMode: dialogMode,
      ),
    );
  }

  if (layout == AppLayoutSize.compact) {
    return showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      showDragHandle: false,
      builder: (sheetContext) {
        final viewInsets = MediaQuery.of(sheetContext).viewInsets;

        return Padding(
          padding: EdgeInsets.only(bottom: viewInsets.bottom),
          child: buildContent(sheetContext, false),
        );
      },
    );
  }

  return showDialog<bool>(
    context: context,
    useRootNavigator: true,
    barrierDismissible: true,
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(
          horizontal: AppResponsiveSpacing.horizontal(dialogContext),
          vertical: 24,
        ),
        child: buildContent(dialogContext, true),
      );
    },
  );
}

class _CardInvoicePaymentForm extends StatefulWidget {
  const _CardInvoicePaymentForm({
    required this.repository,
    required this.spaceId,
    required this.card,
    required this.dialogMode,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletCard card;
  final bool dialogMode;

  @override
  State<_CardInvoicePaymentForm> createState() =>
      _CardInvoicePaymentFormState();
}

class _CardInvoicePaymentFormState extends State<_CardInvoicePaymentForm> {
  late final TextEditingController _amountController;

  List<AccountItem> _accounts = const [];
  String? _accountId;
  CardInvoicePaymentType _paymentType = CardInvoicePaymentType.payment;
  DateTime _paidAt = DateTime.now();

  bool _loadingAccounts = true;
  bool _saving = false;
  String? _loadError;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.card.invoiceBalance.toStringAsFixed(2).replaceAll('.', ','),
    );
    _loadAccounts();
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.repository
          .listPaymentAccounts(widget.spaceId)
          .timeout(const Duration(seconds: 10));

      if (!mounted) {
        return;
      }

      final preferredId = widget.card.paymentAccountId;
      final selectedId = preferredId != null &&
              accounts.any((account) => account.id == preferredId)
          ? preferredId
          : accounts.isEmpty
              ? null
              : accounts.first.id;

      setState(() {
        _accounts = accounts;
        _accountId = selectedId;
        _loadingAccounts = false;
        _loadError = null;
      });
    } on TimeoutException {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingAccounts = false;
        _loadError = 'as contas demoraram demais para carregar';
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loadingAccounts = false;
        _loadError = _friendlyError(error);
      });
    }
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      helpText: 'data do pagamento',
      cancelText: 'cancelar',
      confirmText: 'selecionar',
    );

    if (selected == null || !mounted) {
      return;
    }

    setState(() {
      _paidAt = selected;
      _error = null;
    });
  }

  Future<void> _submit() async {
    final amount = Formatters.parseMoney(_amountController.text);
    final state = CardInvoicePaymentState(
      type: _paymentType,
      accountId: _accountId,
      amount: amount,
    );
    final validation = state.validate(outstanding: widget.card.invoiceBalance);

    if (validation != null) {
      setState(() {
        _error = validation;
      });
      return;
    }

    final invoiceId = widget.card.invoiceId;
    if (invoiceId == null) {
      setState(() {
        _error = 'esta fatura não está disponível para pagamento';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await widget.repository.payCardInvoice(
        spaceId: widget.spaceId,
        invoiceId: invoiceId,
        accountId: _accountId!,
        amount: amount,
        paymentType: _paymentType.backendValue,
        paidAt: _paidAt,
      );

      if (!mounted) {
        return;
      }

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _error = _friendlyError(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    final text = error.toString();

    if (text.contains('invalid_payment_account')) {
      return 'selecione uma conta válida para pagar a fatura';
    }
    if (text.contains('invalid_invoice')) {
      return 'esta fatura não está mais disponível';
    }
    if (text.contains('invoice_has_no_outstanding_balance')) {
      return 'esta fatura já está quitada';
    }
    if (text.contains('payment_exceeds_outstanding_balance')) {
      return 'o valor não pode ser maior que o saldo da fatura';
    }
    if (text.contains('amount_must_be_positive')) {
      return 'informe um valor maior que zero';
    }
    if (text.contains('invalid_payment_type')) {
      return 'tipo de pagamento inválido';
    }
    if (text.contains('write_access_denied')) {
      return 'você não tem permissão para pagar esta fatura';
    }

    return text
        .replaceFirst('Invalid argument(s): ', '')
        .replaceFirst('Exception: ', '');
  }

  String _date(DateTime value) {
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);

    return Material(
      color: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 720),
        decoration: BoxDecoration(
          color: background,
          borderRadius: widget.dialogMode
              ? BorderRadius.circular(AppRadii.sheet)
              : const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: border),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.dialogMode) ...[
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: border,
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                ],
                Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: purple.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(13),
                      ),
                      child: Icon(
                        AppIcons.creditCard,
                        size: 20,
                        color: purple,
                      ),
                    ),
                    const SizedBox(width: 11),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'pagar fatura',
                            style: AppTypography.section(
                              context,
                              fontSize: 19,
                              color: primaryText,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.card.name,
                            style: AppTypography.body(
                              context,
                              fontSize: 12,
                              color: secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: Icon(
                        AppIcons.close,
                        size: 20,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: surface,
                    borderRadius: BorderRadius.circular(AppRadii.compactCard),
                    border: Border.all(color: border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'saldo da fatura',
                              style: AppTypography.label(
                                context,
                                fontSize: 10,
                                color: secondaryText,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              Formatters.money(widget.card.invoiceBalance),
                              style: AppTypography.money(
                                context,
                                fontSize: 20,
                                color: primaryText,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            'vencimento',
                            style: AppTypography.label(
                              context,
                              fontSize: 10,
                              color: secondaryText,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.card.invoiceDueDate == null
                                ? 'dia ${widget.card.dueDay}'
                                : _date(widget.card.invoiceDueDate!),
                            style: AppTypography.body(
                              context,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: primaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'tipo',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: CardInvoicePaymentType.values.map((type) {
                    final selected = _paymentType == type;
                    return _PaymentTypeChip(
                      label: type.label,
                      selected: selected,
                      onTap: _saving
                          ? null
                          : () {
                              setState(() {
                                _paymentType = type;
                                _error = null;
                              });
                            },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 18),
                Text(
                  'conta que pagará',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                if (_loadingAccounts)
                  const Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: CircularProgressIndicator(),
                    ),
                  )
                else if (_loadError != null)
                  _InlineMessage(
                    icon: AppIcons.warning,
                    text: _loadError!,
                    color: AppColors.expenseText(brightness),
                  )
                else if (_accounts.isEmpty)
                  _InlineMessage(
                    icon: AppIcons.account,
                    text: 'Nenhuma conta disponível',
                    color: secondaryText,
                  )
                else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    decoration: BoxDecoration(
                      color: surface,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: Border.all(color: border),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _accountId,
                        isExpanded: true,
                        icon: Icon(
                          AppIcons.chevronDown,
                          size: 18,
                          color: secondaryText,
                        ),
                        items: _accounts.map((account) {
                          return DropdownMenuItem<String>(
                            value: account.id,
                            child: Text(
                              account.name,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: _saving
                            ? null
                            : (value) {
                                setState(() {
                                  _accountId = value;
                                  _error = null;
                                });
                              },
                      ),
                    ),
                  ),
                const SizedBox(height: 18),
                Text(
                  'valor',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _amountController,
                  enabled: !_saving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTypography.body(
                    context,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                  decoration: InputDecoration(
                    prefixText: 'R\$ ',
                    filled: true,
                    fillColor: surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 14,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      borderSide: BorderSide(color: border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      borderSide: BorderSide(color: border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      borderSide: BorderSide(color: purple),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'data',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 8),
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _saving ? null : _pickDate,
                    borderRadius: BorderRadius.circular(AppRadii.control),
                    child: Ink(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      decoration: BoxDecoration(
                        color: surface,
                        borderRadius: BorderRadius.circular(AppRadii.control),
                        border: Border.all(color: border),
                      ),
                      child: Row(
                        children: [
                          Icon(AppIcons.calendar, size: 18, color: purple),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _date(_paidAt),
                              style: AppTypography.body(
                                context,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: primaryText,
                              ),
                            ),
                          ),
                          Icon(
                            AppIcons.chevronRight,
                            size: 17,
                            color: secondaryText,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                _InlineMessage(
                  icon: AppIcons.info,
                  text:
                      'Este pagamento reduz sua conta bancária e a fatura. O gasto já foi registrado quando você fez a compra.',
                  color: purple,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  _InlineMessage(
                    icon: AppIcons.warning,
                    text: _error!,
                    color: AppColors.expenseText(brightness),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _saving ||
                            _loadingAccounts ||
                            _accounts.isEmpty ||
                            _loadError != null
                        ? null
                        : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: AppColors.lime,
                      foregroundColor: AppColors.iconOnLime,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _paymentType == CardInvoicePaymentType.advance
                                ? 'registrar adiantamento'
                                : 'pagar fatura',
                            style: AppTypography.button(
                              context,
                              color: AppColors.iconOnLime,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PaymentTypeChip extends StatelessWidget {
  const _PaymentTypeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? purple.withValues(alpha: .12) : surface,
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: Border.all(color: selected ? purple : border),
          ),
          child: Text(
            label,
            style: AppTypography.label(
              context,
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: selected ? purple : primaryText,
            ),
          ),
        ),
      ),
    );
  }
}

class _InlineMessage extends StatelessWidget {
  const _InlineMessage({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              text,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: AppColors.secondaryText(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
