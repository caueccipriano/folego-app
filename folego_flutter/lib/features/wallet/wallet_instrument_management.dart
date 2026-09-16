import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/account_item.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../data/repositories/folego_repository_wallet_management.dart';

enum WalletAddAction { account, card, benefit, debt }

const List<String> walletManagedAccountTypes = <String>[
  'checking',
  'savings',
  'cash',
  'reserve',
  'investment',
  'other',
];

bool walletAccountTypeIsProtected(String type) {
  return type == 'reserve' || type == 'investment' || type == 'benefit';
}

String walletAccountTypeLabel(String type) {
  return switch (type) {
    'checking' => 'conta corrente',
    'savings' => 'poupança',
    'cash' => 'dinheiro / carteira',
    'reserve' => 'reserva',
    'investment' => 'investimento',
    'benefit' => 'benefício',
    _ => 'outra conta',
  };
}

String walletManagementFriendlyError(Object error) {
  final text = error.toString();
  if (text.contains('account_name_already_exists')) {
    return 'já existe uma conta com esse nome';
  }
  if (text.contains('card_name_already_exists')) {
    return 'já existe um cartão com esse nome';
  }
  if (text.contains('account_type_history_conflict')) {
    return 'esse tipo não pode ser trocado porque a conta já possui histórico ou vínculos';
  }
  if (text.contains('account_has_balance')) {
    return 'zere ou transfira o saldo antes de arquivar este instrumento';
  }
  if (text.contains('account_has_active_recurring')) {
    return 'pause ou mova as recorrências desta conta antes de arquivar';
  }
  if (text.contains('account_is_card_payment_account')) {
    return 'troque a conta pagadora dos cartões vinculados antes de arquivar';
  }
  if (text.contains('account_is_debt_payment_account')) {
    return 'troque a conta de pagamento das dívidas ativas antes de arquivar';
  }
  if (text.contains('card_has_active_recurring')) {
    return 'pause ou mova as compras recorrentes deste cartão antes de arquivar';
  }
  if (text.contains('card_has_open_invoice')) {
    return 'quite ou resolva a fatura aberta antes de arquivar o cartão';
  }
  if (text.contains('card_has_future_installments')) {
    return 'existem parcelas futuras vinculadas a este cartão';
  }
  if (text.contains('invalid_payment_account')) {
    return 'selecione uma conta ativa que não seja benefício';
  }
  if (text.contains('invalid_card_cycle')) {
    return 'fechamento e vencimento devem estar entre os dias 1 e 31';
  }
  if (text.contains('invalid_last_four')) {
    return 'os quatro últimos dígitos precisam conter exatamente 4 números';
  }
  if (text.contains('write_access_denied') || text.contains('42501')) {
    return 'você não tem permissão para alterar este espaço financeiro';
  }
  return text.replaceFirst('Exception: ', '');
}

Future<WalletAddAction?> showWalletAddAction(BuildContext context) {
  final content = _WalletAddMenu();
  return _showWalletAdaptive<WalletAddAction>(
    context: context,
    child: content,
    maxWidth: 430,
  );
}

Future<bool?> showWalletAccountEditor({
  required BuildContext context,
  required FolegoRepository repository,
  required String spaceId,
  WalletAccount? account,
  bool benefitMode = false,
}) {
  return _showWalletAdaptive<bool>(
    context: context,
    child: WalletAccountEditor(
      repository: repository,
      spaceId: spaceId,
      account: account,
      benefitMode: benefitMode || account?.isBenefit == true,
    ),
    maxWidth: 620,
  );
}

Future<bool?> showWalletCardEditor({
  required BuildContext context,
  required FolegoRepository repository,
  required String spaceId,
  WalletCard? card,
}) {
  return _showWalletAdaptive<bool>(
    context: context,
    child: WalletCardEditor(
      repository: repository,
      spaceId: spaceId,
      card: card,
    ),
    maxWidth: 660,
  );
}

Future<T?> _showWalletAdaptive<T>({
  required BuildContext context,
  required Widget child,
  required double maxWidth,
}) {
  final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
  if (compact) {
    return showModalBottomSheet<T>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: FractionallySizedBox(heightFactor: .92, child: child),
        );
      },
    );
  }

  return showDialog<T>(
    context: context,
    useRootNavigator: true,
    builder: (dialogContext) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: MediaQuery.sizeOf(dialogContext).height * .90,
        ),
        child: child,
      ),
    ),
  );
}

class _WalletAddMenu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'adicionar à carteira',
                      style: AppTypography.section(context, fontSize: 20),
                    ),
                  ),
                  IconButton(
                    tooltip: 'fechar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.close),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'organize sua estrutura financeira sem misturar os tipos de saldo',
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
              const SizedBox(height: 14),
              _AddTile(
                key: const ValueKey('wallet-add-account'),
                icon: AppIcons.account,
                title: 'conta ou reserva',
                subtitle: 'corrente, poupança, dinheiro, reserva ou investimento',
                onTap: () => Navigator.of(context).pop(WalletAddAction.account),
              ),
              _AddTile(
                key: const ValueKey('wallet-add-card'),
                icon: AppIcons.creditCard,
                title: 'cartão',
                subtitle: 'limite, ciclo e conta pagadora',
                onTap: () => Navigator.of(context).pop(WalletAddAction.card),
              ),
              _AddTile(
                key: const ValueKey('wallet-add-benefit'),
                icon: AppIcons.benefit,
                title: 'benefício',
                subtitle: 'VR, VA, Flash e outros saldos finalísticos',
                onTap: () => Navigator.of(context).pop(WalletAddAction.benefit),
              ),
              _AddTile(
                key: const ValueKey('wallet-add-debt'),
                icon: AppIcons.debt,
                title: 'dívida',
                subtitle: 'usa o fluxo Debt 2.0 já existente',
                onTap: () => Navigator.of(context).pop(WalletAddAction.debt),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Material(
        color: AppColors.background(brightness).withValues(alpha: .55),
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(icon, size: 22, color: AppColors.primaryPurple(brightness)),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title, style: AppTypography.body(context, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 2),
                      Text(subtitle, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness))),
                    ],
                  ),
                ),
                const Icon(AppIcons.chevronRight, size: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WalletAccountEditor extends StatefulWidget {
  const WalletAccountEditor({
    super.key,
    required this.repository,
    required this.spaceId,
    this.account,
    this.benefitMode = false,
    this.saveOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletAccount? account;
  final bool benefitMode;
  final Future<void> Function({
    required String name,
    required String institution,
    required String type,
    required double openingBalance,
    required bool availableForSpending,
  })? saveOverride;

  @override
  State<WalletAccountEditor> createState() => _WalletAccountEditorState();
}

class _WalletAccountEditorState extends State<WalletAccountEditor> {
  late final TextEditingController _name;
  late final TextEditingController _institution;
  late final TextEditingController _opening;
  late String _type;
  late bool _available;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.account != null;
  bool get _benefit => widget.benefitMode;

  @override
  void initState() {
    super.initState();
    final account = widget.account;
    _name = TextEditingController(text: account?.name ?? '');
    _institution = TextEditingController(text: account?.institution ?? '');
    _opening = TextEditingController();
    _type = _benefit ? 'benefit' : (account?.type ?? 'checking');
    if (!walletManagedAccountTypes.contains(_type) && _type != 'benefit') {
      _type = 'other';
    }
    _available = account?.availableForSpending ?? !walletAccountTypeIsProtected(_type);
  }

  @override
  void dispose() {
    _name.dispose();
    _institution.dispose();
    _opening.dispose();
    super.dispose();
  }

  void _changeType(String? value) {
    if (value == null) return;
    setState(() {
      _type = value;
      if (walletAccountTypeIsProtected(value)) _available = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = _benefit ? 'informe o nome do benefício' : 'informe o nome da conta');
      return;
    }
    final opening = _editing ? 0.0 : Formatters.parseMoney(_opening.text).toDouble();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final override = widget.saveOverride;
      if (override != null) {
        await override(
          name: name,
          institution: _institution.text,
          type: _type,
          openingBalance: opening,
          availableForSpending: _available,
        );
      } else if (_editing) {
        await widget.repository.updateWalletAccount(
          spaceId: widget.spaceId,
          accountId: widget.account!.id,
          name: name,
          institution: _institution.text,
          type: _type,
          availableForSpending: _available,
        );
      } else {
        await widget.repository.createWalletAccount(
          spaceId: widget.spaceId,
          name: name,
          institution: _institution.text,
          type: _type,
          openingBalance: opening,
          balanceDate: DateTime.now(),
          availableForSpending: _available,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = walletManagementFriendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final protected = walletAccountTypeIsProtected(_type);
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EditorHeader(
                title: _editing
                    ? (_benefit ? 'editar benefício' : 'editar conta')
                    : (_benefit ? 'novo benefício' : 'nova conta'),
                subtitle: _benefit
                    ? 'benefício continua separado de cash'
                    : 'saldo atual continua vindo do ledger',
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('wallet-account-name'),
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: _benefit ? 'nome do benefício' : 'nome / apelido'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _institution,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: _benefit ? 'operadora / empresa' : 'instituição'),
              ),
              if (!_benefit) ...[
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  key: const ValueKey('wallet-account-type'),
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'tipo'),
                  items: walletManagedAccountTypes
                      .map((type) => DropdownMenuItem(value: type, child: Text(walletAccountTypeLabel(type))))
                      .toList(growable: false),
                  onChanged: _changeType,
                ),
              ],
              if (!_editing) ...[
                const SizedBox(height: 12),
                TextField(
                  key: const ValueKey('wallet-opening-balance'),
                  controller: _opening,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                  decoration: InputDecoration(
                    labelText: _benefit ? 'saldo inicial do benefício' : 'saldo inicial',
                    prefixText: 'R\$ ',
                    helperText: _benefit
                        ? 'registrado como opening balance na dimensão benefit'
                        : 'registrado como opening balance, nunca como receita',
                  ),
                ),
              ] else ...[
                const SizedBox(height: 14),
                _InfoNote(
                  icon: AppIcons.info,
                  text: 'o saldo não é editável aqui. correções de saldo devem passar pelo fluxo canônico de ajuste/reconciliação.',
                ),
              ],
              if (!_benefit) ...[
                const SizedBox(height: 12),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  value: protected ? false : _available,
                  onChanged: protected ? null : (value) => setState(() => _available = value),
                  title: const Text('incluir no dinheiro disponível'),
                  subtitle: Text(
                    protected
                        ? '${walletAccountTypeLabel(_type)} é protegido por definição'
                        : 'afeta apenas a leitura de saldo disponível, não o saldo da conta',
                  ),
                ),
              ],
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: AppColors.expenseText(brightness))),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('wallet-account-save'),
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.check, size: 18),
                label: Text(_editing ? 'salvar alterações' : (_benefit ? 'criar benefício' : 'criar conta')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class WalletCardEditor extends StatefulWidget {
  const WalletCardEditor({
    super.key,
    required this.repository,
    required this.spaceId,
    this.card,
    this.accountsLoader,
    this.saveOverride,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletCard? card;
  final Future<List<AccountItem>> Function()? accountsLoader;
  final Future<void> Function({
    required String name,
    required String issuer,
    required String brand,
    required String lastFour,
    required double? personalLimit,
    required int closingDay,
    required int dueDay,
    required String paymentAccountId,
  })? saveOverride;

  @override
  State<WalletCardEditor> createState() => _WalletCardEditorState();
}

class _WalletCardEditorState extends State<WalletCardEditor> {
  late final TextEditingController _name;
  late final TextEditingController _issuer;
  late final TextEditingController _brand;
  late final TextEditingController _lastFour;
  late final TextEditingController _limit;
  late int _closingDay;
  late int _dueDay;
  String? _paymentAccountId;
  List<AccountItem> _accounts = const [];
  bool _loadingAccounts = true;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.card != null;

  @override
  void initState() {
    super.initState();
    final card = widget.card;
    _name = TextEditingController(text: card?.name ?? '');
    _issuer = TextEditingController(text: card?.issuer ?? '');
    _brand = TextEditingController(text: card?.brand ?? '');
    _lastFour = TextEditingController(text: card?.lastFour ?? '');
    _limit = TextEditingController(
      text: card?.personalLimit == null ? '' : card!.personalLimit!.toStringAsFixed(2).replaceAll('.', ','),
    );
    _closingDay = card?.closingDay ?? 5;
    _dueDay = card?.dueDay ?? 10;
    _paymentAccountId = card?.paymentAccountId;
    _loadAccounts();
  }

  @override
  void dispose() {
    _name.dispose();
    _issuer.dispose();
    _brand.dispose();
    _lastFour.dispose();
    _limit.dispose();
    super.dispose();
  }

  Future<void> _loadAccounts() async {
    try {
      final loader = widget.accountsLoader;
      final accounts = loader != null
          ? await loader()
          : await widget.repository.listPaymentAccounts(widget.spaceId);
      if (!mounted) return;
      final preferred = _paymentAccountId;
      setState(() {
        _accounts = accounts;
        _paymentAccountId = preferred != null && accounts.any((a) => a.id == preferred)
            ? preferred
            : accounts.isEmpty
                ? null
                : accounts.first.id;
        _loadingAccounts = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingAccounts = false;
        _error = walletManagementFriendlyError(error);
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'informe o nome do cartão');
      return;
    }
    if (_paymentAccountId == null) {
      setState(() => _error = 'cadastre ou selecione uma conta pagadora válida');
      return;
    }
    final lastFour = _lastFour.text.trim();
    if (lastFour.isNotEmpty && !RegExp(r'^\d{4}$').hasMatch(lastFour)) {
      setState(() => _error = 'informe exatamente os 4 últimos dígitos');
      return;
    }
    final limitText = _limit.text.trim();
    final personalLimit = limitText.isEmpty ? null : Formatters.parseMoney(limitText).toDouble();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final override = widget.saveOverride;
      if (override != null) {
        await override(
          name: name,
          issuer: _issuer.text,
          brand: _brand.text,
          lastFour: lastFour,
          personalLimit: personalLimit,
          closingDay: _closingDay,
          dueDay: _dueDay,
          paymentAccountId: _paymentAccountId!,
        );
      } else if (_editing) {
        await widget.repository.updateWalletCard(
          spaceId: widget.spaceId,
          cardId: widget.card!.id,
          name: name,
          issuer: _issuer.text,
          brand: _brand.text,
          lastFour: lastFour,
          personalLimit: personalLimit,
          closingDay: _closingDay,
          dueDay: _dueDay,
          paymentAccountId: _paymentAccountId!,
        );
      } else {
        await widget.repository.createWalletCard(
          spaceId: widget.spaceId,
          name: name,
          issuer: _issuer.text,
          brand: _brand.text,
          lastFour: lastFour,
          personalLimit: personalLimit,
          closingDay: _closingDay,
          dueDay: _dueDay,
          paymentAccountId: _paymentAccountId!,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (mounted) setState(() => _error = walletManagementFriendlyError(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _EditorHeader(
                title: _editing ? 'editar cartão' : 'novo cartão',
                subtitle: _editing
                    ? 'mudanças de ciclo valem para o futuro; faturas históricas não são reescritas'
                    : 'a conta pagadora precisa ser uma conta ativa, nunca benefício',
              ),
              const SizedBox(height: 18),
              TextField(
                key: const ValueKey('wallet-card-name'),
                controller: _name,
                decoration: const InputDecoration(labelText: 'nome / apelido'),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: TextField(controller: _issuer, decoration: const InputDecoration(labelText: 'emissor'))),
                  const SizedBox(width: 10),
                  Expanded(child: TextField(controller: _brand, decoration: const InputDecoration(labelText: 'bandeira'))),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _lastFour,
                      keyboardType: TextInputType.number,
                      maxLength: 4,
                      decoration: const InputDecoration(labelText: 'últimos 4 dígitos', counterText: ''),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _limit,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'limite', prefixText: 'R\$ '),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _DayDropdown(label: 'fechamento', value: _closingDay, onChanged: (v) => setState(() => _closingDay = v))),
                  const SizedBox(width: 10),
                  Expanded(child: _DayDropdown(label: 'vencimento', value: _dueDay, onChanged: (v) => setState(() => _dueDay = v))),
                ],
              ),
              const SizedBox(height: 12),
              if (_loadingAccounts)
                const LinearProgressIndicator()
              else
                DropdownButtonFormField<String>(
                  key: const ValueKey('wallet-card-payment-account'),
                  initialValue: _accounts.any((a) => a.id == _paymentAccountId) ? _paymentAccountId : null,
                  decoration: const InputDecoration(labelText: 'conta pagadora padrão'),
                  items: _accounts
                      .map((account) => DropdownMenuItem(value: account.id, child: Text(account.name)))
                      .toList(growable: false),
                  onChanged: (value) => setState(() => _paymentAccountId = value),
                ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(_error!, style: TextStyle(color: AppColors.expenseText(brightness))),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                key: const ValueKey('wallet-card-save'),
                onPressed: _saving || _loadingAccounts ? null : _save,
                icon: _saving
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(AppIcons.check, size: 18),
                label: Text(_editing ? 'salvar alterações' : 'criar cartão'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayDropdown extends StatelessWidget {
  const _DayDropdown({required this.label, required this.value, required this.onChanged});
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<int>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: List.generate(31, (index) => index + 1)
          .map((day) => DropdownMenuItem(value: day, child: Text('dia $day')))
          .toList(growable: false),
      onChanged: (day) {
        if (day != null) onChanged(day);
      },
    );
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: AppTypography.section(context, fontSize: 20)),
              const SizedBox(height: 4),
              Text(subtitle, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness))),
            ],
          ),
        ),
        IconButton(
          tooltip: 'fechar',
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(AppIcons.close),
        ),
      ],
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.background(brightness).withValues(alpha: .55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: AppColors.secondaryText(brightness)),
          const SizedBox(width: 9),
          Expanded(child: Text(text, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness)))),
        ],
      ),
    );
  }
}
