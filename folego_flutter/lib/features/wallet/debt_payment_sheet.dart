import 'package:flutter/material.dart';

import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/debt_detail.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_debts.dart';
import 'debt_form_sheet.dart';

Future<bool?> showDebtPaymentSheet({
  required BuildContext context,
  required FolegoRepository repository,
  required String spaceId,
  required DebtRecord debt,
  required DebtInstallmentRecord installment,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => DebtPaymentSheet(
      repository: repository,
      spaceId: spaceId,
      debt: debt,
      installment: installment,
    ),
  );
}

class DebtPaymentSheet extends StatefulWidget {
  const DebtPaymentSheet({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.debt,
    required this.installment,
  });

  final FolegoRepository repository;
  final String spaceId;
  final DebtRecord debt;
  final DebtInstallmentRecord installment;

  @override
  State<DebtPaymentSheet> createState() => _DebtPaymentSheetState();
}

class _DebtPaymentSheetState extends State<DebtPaymentSheet> {
  final _amount = TextEditingController();
  List<AccountItem> _accounts = const [];
  String? _accountId;
  late DateTime _paidAt;
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _amount.text = widget.installment.remainingAmount
        .toStringAsFixed(2)
        .replaceAll('.', ',');
    _accountId = widget.debt.paymentAccountId;
    _paidAt = DateTime.now();
    _loadAccounts();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.repository.listAccounts(widget.spaceId);
      if (!mounted) return;
      final paymentAccounts = accounts.where((item) => item.isPaymentAccount).toList();
      setState(() {
        _accounts = paymentAccounts;
        if (_accountId == null && paymentAccounts.isNotEmpty) {
          _accountId = paymentAccounts.first.id;
        }
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'não consegui carregar as contas: $error';
      });
    }
  }

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _paidAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (value != null && mounted) {
      setState(() {
        _paidAt = DateTime(value.year, value.month, value.day, 12);
      });
    }
  }

  Future<void> _pay() async {
    if (_saving) return;
    final amount = parseDebtNumber(_amount.text);
    if (_accountId == null) {
      setState(() => _error = 'selecione a conta que pagou a parcela');
      return;
    }
    if (amount == null || amount <= 0 || amount > widget.installment.remainingAmount + .001) {
      setState(() => _error = 'informe um valor válido até o saldo da parcela');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.payDebtInstallmentV2(
        spaceId: widget.spaceId,
        installmentId: widget.installment.id,
        accountId: _accountId!,
        amount: amount,
        paidAt: _paidAt,
      );
      AppRealtimeRegistry.coordinator?.invalidateDomains({
        AppRealtimeDomain.home,
        AppRealtimeDomain.wallet,
        AppRealtimeDomain.transactions,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        18,
        20,
        MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'pagar parcela',
                    style: AppTypography.display(context, fontSize: 22, color: primary),
                  ),
                ),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.pop(context, false),
                  icon: const Icon(AppIcons.close),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.debt.name} · parcela ${widget.installment.installmentNumber}',
              style: AppTypography.body(context, fontSize: 12, color: secondary),
            ),
            const SizedBox(height: 18),
            TextField(
              controller: _amount,
              enabled: !_saving,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'valor pago',
                prefixText: 'R\$ ',
                helperText: 'restante: ${Formatters.money(widget.installment.remainingAmount)}',
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _accountId,
              decoration: InputDecoration(
                labelText: _loading ? 'carregando conta…' : 'conta pagadora',
              ),
              items: _accounts
                  .map((account) => DropdownMenuItem(
                        value: account.id,
                        child: Text(account.name),
                      ))
                  .toList(growable: false),
              onChanged: _saving || _loading
                  ? null
                  : (value) => setState(() => _accountId = value),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: _saving ? null : _pickDate,
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'data do pagamento'),
                child: Row(
                  children: [
                    const Icon(AppIcons.calendar, size: 18),
                    const SizedBox(width: 8),
                    Text(Formatters.shortDate.format(_paidAt)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.surface(brightness),
                borderRadius: BorderRadius.circular(AppRadii.control),
                border: Border.all(color: AppColors.border(brightness)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(AppIcons.info, size: 18, color: secondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'o pagamento reduz cash da conta. economic e budget continuam zero para não contar a dívida duas vezes.',
                      style: AppTypography.body(context, fontSize: 11, color: secondary),
                    ),
                  ),
                ],
              ),
            ),
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
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _saving || _loading ? null : _pay,
              icon: _saving
                  ? const SizedBox(
                      width: 17,
                      height: 17,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(AppIcons.check, size: 18),
              label: const Text('registrar pagamento'),
            ),
          ],
        ),
      ),
    );
  }
}
