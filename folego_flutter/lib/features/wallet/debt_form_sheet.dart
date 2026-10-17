import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
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

typedef DebtSaveOverride = Future<void> Function(DebtDraft draft);

Future<bool?> showDebtFormSheet({
  required BuildContext context,
  required FolegoRepository repository,
  required String spaceId,
  DebtDetail? existing,
  DebtSaveOverride? onSaveOverride,
}) {
  final layout = AppBreakpoints.of(context);
  final form = DebtForm(
    repository: repository,
    spaceId: spaceId,
    existing: existing,
    onSaveOverride: onSaveOverride,
  );
  if (layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide) {
    return showDialog<bool>(
      context: context,
      builder: (_) => Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620, maxHeight: 820),
          child: form,
        ),
      ),
    );
  }
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => FractionallySizedBox(heightFactor: .92, child: form),
  );
}

class DebtForm extends StatefulWidget {
  const DebtForm({
    super.key,
    required this.repository,
    required this.spaceId,
    this.existing,
    this.onSaveOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  final DebtDetail? existing;
  final DebtSaveOverride? onSaveOverride;

  @override
  State<DebtForm> createState() => _DebtFormState();
}

class _DebtFormState extends State<DebtForm> {
  final _name = TextEditingController();
  final _creditor = TextEditingController();
  final _amount = TextEditingController();
  final _installments = TextEditingController();
  final _interest = TextEditingController();
  final _notes = TextEditingController();

  List<AccountItem> _accounts = const [];
  String? _accountId;
  String _debtType = 'other';
  late DateTime _firstDue;
  bool _loadingAccounts = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.existing != null;
  bool get _canRestructure => widget.existing?.canRestructure ?? true;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing != null) {
      final debt = existing.debt;
      _name.text = debt.name;
      _creditor.text = debt.creditor;
      _amount.text = debt.originalAmount.toStringAsFixed(2).replaceAll('.', ',');
      _installments.text = debt.totalInstallments.toString();
      _interest.text = debt.interestRateMonthly
              ?.toStringAsFixed(2)
              .replaceAll('.', ',') ??
          '';
      _notes.text = debt.notes ?? '';
      _accountId = debt.paymentAccountId;
      _debtType = debt.debtType;
      _firstDue = debt.firstDueDate ?? DateTime.now();
    } else {
      _firstDue = DateTime.now();
    }
    _loadAccounts();
  }

  @override
  void dispose() {
    _name.dispose();
    _creditor.dispose();
    _amount.dispose();
    _installments.dispose();
    _interest.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final accounts = await widget.repository.listAccounts(widget.spaceId);
      if (!mounted) return;
      setState(() {
        _accounts = accounts.where((item) => item.isPaymentAccount).toList();
        _loadingAccounts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAccounts = false;
        _error = 'não consegui carregar as contas: $error';
      });
    }
  }

  Future<void> _pickDue() async {
    if (!_canRestructure) return;
    final value = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (value != null && mounted) setState(() => _firstDue = value);
  }

  DebtDraft? _draft() {
    final amount = parseDebtNumber(_amount.text);
    final installments = int.tryParse(_installments.text.trim());
    final interest = _interest.text.trim().isEmpty
        ? null
        : parseDebtNumber(_interest.text);
    if (amount == null || installments == null || interest == null && _interest.text.trim().isNotEmpty) {
      _error = 'confira os valores informados';
      return null;
    }
    final existing = widget.existing?.debt;
    return DebtDraft(
      name: _name.text,
      creditor: _creditor.text,
      originalAmount: amount,
      totalInstallments: installments,
      firstDueDate: _firstDue,
      paymentAccountId: _accountId,
      startedOn: existing?.startedOn,
      interestRateMonthly: interest,
      debtType: _debtType,
      notes: _notes.text,
    );
  }

  Future<void> _save() async {
    if (_saving) return;
    final draft = _draft();
    if (draft == null) {
      setState(() {});
      return;
    }
    final validation = draft.validate();
    if (validation != null) {
      setState(() => _error = validation);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSaveOverride != null) {
        await widget.onSaveOverride!(draft);
      } else if (_editing) {
        await widget.repository.updateDebtV2(
          spaceId: widget.spaceId,
          debtId: widget.existing!.debt.id,
          draft: draft,
        );
      } else {
        await widget.repository.createDebtV2(
          spaceId: widget.spaceId,
          draft: draft,
        );
      }
      AppRealtimeRegistry.coordinator?.invalidateDomains({
        AppRealtimeDomain.home,
        AppRealtimeDomain.wallet,
      });
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().contains('debt_restructure_after_payment')
          ? 'parcelas já pagas impedem reestruturar valor, quantidade ou primeiro vencimento'
          : error.toString().replaceFirst('Exception: ', '');
      setState(() {
        _saving = false;
        _error = message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return Material(
      color: AppColors.background(brightness),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _editing ? 'editar dívida' : 'nova dívida',
                          style: AppTypography.display(
                            context,
                            fontSize: 22,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'cadastro da obrigação, sem criar movimentação financeira',
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: _saving ? null : () => Navigator.pop(context, false),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  MediaQuery.viewInsetsOf(context).bottom + 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'nome'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _creditor,
                      decoration: const InputDecoration(labelText: 'credor'),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _debtType,
                      decoration: const InputDecoration(labelText: 'tipo'),
                      items: debtTypes
                          .map((type) => DropdownMenuItem(
                                value: type,
                                child: Text(debtTypeLabel(type)),
                              ))
                          .toList(growable: false),
                      onChanged: _saving
                          ? null
                          : (value) => setState(() => _debtType = value ?? 'other'),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _amount,
                            enabled: _canRestructure && !_saving,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: const InputDecoration(
                              labelText: 'valor original',
                              prefixText: 'R\$ ',
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _installments,
                            enabled: _canRestructure && !_saving,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'parcelas'),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: _saving ? null : _pickDue,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      child: InputDecorator(
                        decoration: const InputDecoration(labelText: 'primeiro vencimento'),
                        child: Row(
                          children: [
                            const Icon(AppIcons.calendar, size: 18),
                            const SizedBox(width: 8),
                            Text(Formatters.shortDate.format(_firstDue)),
                          ],
                        ),
                      ),
                    ),
                    if (!_canRestructure) ...[
                      const SizedBox(height: 8),
                      Text(
                        'valor, quantidade e vencimentos ficam protegidos depois do primeiro pagamento',
                        style: AppTypography.body(context, fontSize: 11, color: secondary),
                      ),
                    ],
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String?>(
                      initialValue: _accountId,
                      decoration: InputDecoration(
                        labelText: _loadingAccounts ? 'carregando conta…' : 'conta para pagar',
                      ),
                      items: [
                        const DropdownMenuItem<String?>(
                          value: null,
                          child: Text('definir depois'),
                        ),
                        ..._accounts.map((account) => DropdownMenuItem<String?>(
                              value: account.id,
                              child: Text(account.name),
                            )),
                      ],
                      onChanged: _saving || _loadingAccounts
                          ? null
                          : (value) => setState(() => _accountId = value),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _interest,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'juros ao mês (opcional)',
                        suffixText: '%',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _notes,
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'observação (opcional)'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      Text(
                        _error!,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: AppColors.expenseText(brightness),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 17,
                              height: 17,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(AppIcons.check, size: 18),
                      label: Text(_editing ? 'salvar alterações' : 'criar dívida'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

double? parseDebtNumber(String input) {
  var value = input.trim().replaceAll('R\$', '').replaceAll(' ', '');
  if (value.isEmpty) return null;
  if (value.contains(',')) {
    value = value.replaceAll('.', '').replaceAll(',', '.');
  }
  return double.tryParse(value);
}
