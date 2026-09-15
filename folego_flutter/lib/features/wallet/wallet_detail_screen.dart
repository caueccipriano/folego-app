import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/wallet_detail.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_wallet_details.dart';
import '../transactions/transactions_screen.dart';
import 'card_invoice_payment_sheet.dart';

class WalletAccountDetailScreen extends StatelessWidget {
  const WalletAccountDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.account,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletAccount account;

  @override
  Widget build(BuildContext context) {
    return _MovementDetailScreen(
      repository: repository,
      spaceId: spaceId,
      accountId: account.id,
      dimension: 'cash',
      title: account.name,
      subtitle: account.institution ?? _accountTypeLabel(account.type),
      balanceLabel: 'saldo atual',
      balance: account.balance,
      supporting: 'posição desta conta na carteira',
      icon: AppIcons.account,
      info: [
        _Info('tipo', _accountTypeLabel(account.type)),
        const _Info('status', 'ativa'),
        _Info(
          'uso no Fôlego',
          account.availableForSpending
              ? 'considerada no saldo disponível'
              : 'protegida do saldo disponível',
        ),
      ],
      sectionTitle: 'últimas movimentações',
      sectionDescription: 'entradas e saídas que afetaram esta conta',
      showTransactionsAction: true,
    );
  }
}

class WalletBenefitDetailScreen extends StatelessWidget {
  const WalletBenefitDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.benefit,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletAccount benefit;

  @override
  Widget build(BuildContext context) {
    return _MovementDetailScreen(
      repository: repository,
      spaceId: spaceId,
      accountId: benefit.id,
      dimension: 'benefit',
      title: benefit.name,
      subtitle: benefit.institution ?? 'benefício',
      balanceLabel: 'saldo de benefício',
      balance: benefit.balance,
      supporting: 'separado do dinheiro das suas contas',
      icon: AppIcons.benefit,
      accent: true,
      info: const [
        _Info('tipo', 'benefício'),
        _Info('status', 'ativo'),
      ],
      sectionTitle: 'últimas compras',
      sectionDescription: 'movimentações que usaram este saldo',
      showTransactionsAction: false,
    );
  }
}

class _MovementDetailScreen extends StatefulWidget {
  const _MovementDetailScreen({
    required this.repository,
    required this.spaceId,
    required this.accountId,
    required this.dimension,
    required this.title,
    required this.subtitle,
    required this.balanceLabel,
    required this.balance,
    required this.supporting,
    required this.icon,
    required this.info,
    required this.sectionTitle,
    required this.sectionDescription,
    required this.showTransactionsAction,
    this.accent = false,
  });

  final FolegoRepository repository;
  final String spaceId;
  final String accountId;
  final String dimension;
  final String title;
  final String subtitle;
  final String balanceLabel;
  final double balance;
  final String supporting;
  final IconData icon;
  final List<_Info> info;
  final String sectionTitle;
  final String sectionDescription;
  final bool showTransactionsAction;
  final bool accent;

  @override
  State<_MovementDetailScreen> createState() => _MovementDetailScreenState();
}

class _MovementDetailScreenState extends State<_MovementDetailScreen> {
  bool _loading = true;
  String? _error;
  List<WalletMovement> _items = const [];

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
      final items = await widget.repository.listWalletMovements(
        spaceId: widget.spaceId,
        accountId: widget.accountId,
        dimension: widget.dimension,
        limit: 8,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: widget.title,
      subtitle: widget.subtitle,
      icon: widget.icon,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountPanel(
            label: widget.balanceLabel,
            value: widget.balance,
            supporting: widget.supporting,
            accent: widget.accent,
          ),
          const SizedBox(height: 14),
          _InfoGrid(items: widget.info),
          const SizedBox(height: 24),
          _SectionTitle(
            widget.sectionTitle,
            description: widget.sectionDescription,
          ),
          const SizedBox(height: 12),
          _AsyncList(
            loading: _loading,
            error: _error,
            emptyText: 'nenhuma movimentação encontrada',
            onRetry: _load,
            children: _items.map((item) => _MovementRow(item)).toList(),
          ),
          if (widget.showTransactionsAction) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => TransactionsScreen(
                    repository: widget.repository,
                  ),
                ),
              ),
              icon: const Icon(AppIcons.transactions, size: 18),
              label: const Text('ver todos os lançamentos'),
            ),
          ],
        ],
      ),
    );
  }
}

class WalletCardDetailScreen extends StatefulWidget {
  const WalletCardDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.card,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletCard card;

  @override
  State<WalletCardDetailScreen> createState() => _WalletCardDetailScreenState();
}

class _WalletCardDetailScreenState extends State<WalletCardDetailScreen> {
  late WalletCard _card;
  bool _loading = true;
  String? _error;
  List<WalletCardPurchaseLine> _purchases = const [];
  List<WalletCardInstallmentLine> _upcoming = const [];

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final invoiceId = _card.invoiceId;
      final values = await Future.wait<dynamic>([
        invoiceId == null
            ? Future.value(<WalletCardPurchaseLine>[])
            : widget.repository.listCardInvoicePurchases(
                spaceId: widget.spaceId,
                cardId: _card.id,
                invoiceId: invoiceId,
              ),
        widget.repository.listCardUpcomingInstallments(
          spaceId: widget.spaceId,
          cardId: _card.id,
          currentInvoiceId: invoiceId,
        ),
      ]);
      if (!mounted) return;
      setState(() {
        _purchases = values[0] as List<WalletCardPurchaseLine>;
        _upcoming = values[1] as List<WalletCardInstallmentLine>;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _pay() async {
    if (!_card.canPayInvoice) return;
    final paid = await showCardInvoicePaymentSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      card: _card,
    );
    if (paid != true || !mounted) return;

    final overview = await widget.repository.getWalletOverview(
      spaceId: widget.spaceId,
    );
    if (!mounted) return;
    setState(() {
      _card = overview.cards.firstWhere(
        (item) => item.id == _card.id,
        orElse: () => _card,
      );
    });
    await _load();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('fatura atualizada')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    final identity = [
      if (_card.issuer?.trim().isNotEmpty == true) _card.issuer!.trim(),
      if (_card.brand?.trim().isNotEmpty == true) _card.brand!.trim(),
      if (_card.lastFour?.trim().isNotEmpty == true)
        '•••• ${_card.lastFour!.trim()}',
    ].join(' · ');

    final finance = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _InvoicePanel(card: _card, onPay: _pay),
        const SizedBox(height: 14),
        _LimitPanel(card: _card),
      ],
    );
    final activity = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _SectionTitle(
          'compras da fatura',
          description: 'itens vinculados à fatura atual',
        ),
        const SizedBox(height: 12),
        _AsyncList(
          loading: _loading,
          error: _error,
          emptyText: 'nenhuma compra nesta fatura',
          onRetry: _load,
          children: _purchases.map((item) => _PurchaseRow(item)).toList(),
        ),
        const SizedBox(height: 22),
        const _SectionTitle(
          'próximas parcelas',
          description: 'parcelas deste cartão depois da fatura atual',
        ),
        const SizedBox(height: 12),
        _AsyncList(
          loading: _loading,
          error: _error,
          emptyText: 'nenhuma parcela futura neste cartão',
          onRetry: _load,
          children: _upcoming.map((item) => _UpcomingRow(item)).toList(),
        ),
      ],
    );

    return _DetailScaffold(
      title: _card.name,
      subtitle: identity.isEmpty ? 'cartão de crédito' : identity,
      icon: AppIcons.creditCard,
      child: desktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: finance),
                const SizedBox(width: 24),
                Expanded(flex: 7, child: activity),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [finance, const SizedBox(height: 24), activity],
            ),
    );
  }
}

class WalletDebtDetailScreen extends StatefulWidget {
  const WalletDebtDetailScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    required this.debt,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletDebt debt;

  @override
  State<WalletDebtDetailScreen> createState() => _WalletDebtDetailScreenState();
}

class _WalletDebtDetailScreenState extends State<WalletDebtDetailScreen> {
  bool _loading = true;
  String? _error;
  List<WalletDebtInstallment> _items = const [];

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
      final items = await widget.repository.listDebtInstallments(
        spaceId: widget.spaceId,
        debtId: widget.debt.id,
      );
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final debt = widget.debt;
    final overdue = _items.any((item) => item.isOverdue);
    return _DetailScaffold(
      title: debt.name,
      subtitle: debt.creditor ?? 'dívida',
      icon: AppIcons.debt,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountPanel(
            label: 'saldo restante',
            value: debt.remainingBalance,
            supporting: debt.nextDueDate == null
                ? 'obrigação ativa'
                : 'próxima ${Formatters.money(debt.nextAmount)} · ${Formatters.shortDate.format(debt.nextDueDate!)}',
          ),
          if (debt.progress != null && debt.originalAmount != null) ...[
            const SizedBox(height: 14),
            _ProgressPanel(
              progress: debt.progress!,
              label:
                  '${Formatters.money(debt.paidAmount)} de ${Formatters.money(debt.originalAmount)} pagos',
            ),
          ],
          const SizedBox(height: 14),
          _InfoGrid(
            items: [
              const _Info('status', 'ativa'),
              if (debt.originalAmount != null)
                _Info('valor original', Formatters.money(debt.originalAmount)),
              if (debt.totalInstallments != null)
                _Info(
                  'parcelas pagas',
                  '${debt.paidInstallments} de ${debt.totalInstallments}',
                ),
              if (overdue) const _Info('atenção', 'há parcela atrasada'),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle(
            'parcelas da dívida',
            description: 'status real registrado para cada vencimento',
          ),
          const SizedBox(height: 12),
          _AsyncList(
            loading: _loading,
            error: _error,
            emptyText: 'nenhuma parcela detalhada encontrada',
            onRetry: _load,
            children: _items.map((item) => _DebtRow(item)).toList(),
          ),
        ],
      ),
    );
  }
}

class WalletInstallmentDetailScreen extends StatelessWidget {
  const WalletInstallmentDetailScreen({super.key, required this.item});
  final WalletInstallmentPosition item;

  @override
  Widget build(BuildContext context) {
    return _DetailScaffold(
      title: item.displayName,
      subtitle: item.cardName,
      icon: AppIcons.calendar,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AmountPanel(
            label: item.completed ? 'última parcela' : 'valor da parcela',
            value: item.installmentAmount,
            supporting: item.completed
                ? 'parcelamento concluído'
                : '${item.currentInstallment} de ${item.totalInstallments} parcelas',
          ),
          const SizedBox(height: 14),
          _ProgressPanel(
            progress: item.progress,
            label: item.completed
                ? '${item.totalInstallments} de ${item.totalInstallments} concluídas'
                : '${item.currentInstallment} de ${item.totalInstallments} em andamento',
          ),
          const SizedBox(height: 14),
          _InfoGrid(
            items: [
              _Info('cartão', item.cardName),
              if (item.categoryName != null)
                _Info('categoria', item.categoryName!),
              _Info('status', item.completed ? 'concluído' : 'em aberto'),
              if (item.nextDueDate != null)
                _Info(
                  'próxima fatura',
                  Formatters.fullDate.format(item.nextDueDate!),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DetailScaffold extends StatelessWidget {
  const _DetailScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 48),
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: 'voltar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(AppIcons.back),
                  ),
                  const SizedBox(width: 5),
                  Container(
                    width: 42,
                    height: 42,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: .11),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(icon, size: 20, color: purple),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.section(
                            context,
                            fontSize: 21,
                            color: primary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            color: secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _AmountPanel extends StatelessWidget {
  const _AmountPanel({
    required this.label,
    required this.value,
    required this.supporting,
    this.accent = false,
  });

  final String label;
  final double value;
  final String supporting;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final tone = accent
        ? AppColors.positiveText(brightness)
        : AppColors.primaryPurple(brightness);
    return _Surface(
      borderColor: tone.withValues(alpha: .24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          const SizedBox(height: 7),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(value),
              style: AppTypography.money(
                context,
                fontSize: 30,
                color: value < 0 ? AppColors.expenseText(brightness) : primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            supporting,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _InvoicePanel extends StatelessWidget {
  const _InvoicePanel({required this.card, required this.onPay});
  final WalletCard card;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final due = card.invoiceDueDate == null
        ? 'vence dia ${card.dueDay}'
        : 'vence ${Formatters.shortDate.format(card.invoiceDueDate!)}';
    return _Surface(
      borderColor: purple.withValues(alpha: .24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _Label('fatura atual'),
          const SizedBox(height: 7),
          Text(
            Formatters.money(card.invoiceBalance),
            style: AppTypography.money(context, fontSize: 28, color: primary),
          ),
          const SizedBox(height: 5),
          Text(
            '$due · fecha dia ${card.closingDay}',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondary,
            ),
          ),
          if (card.canPayInvoice) ...[
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onPay,
                icon: const Icon(AppIcons.cash, size: 18),
                label: const Text('pagar fatura'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _LimitPanel extends StatelessWidget {
  const _LimitPanel({required this.card});
  final WalletCard card;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final ratio = card.limitUsageRatio;
    final tone = _limitTone(brightness, ratio);
    final effective = card.effectiveLimit;
    return _Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(child: _Label('limite')),
              if (ratio != null)
                Text(
                  '${(ratio * 100).round()}% usado',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: tone,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (ratio != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 8,
                backgroundColor: AppColors.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(tone),
              ),
            ),
            const SizedBox(height: 14),
          ],
          _InfoGrid(
            items: [
              if (effective != null)
                _Info('limite total', Formatters.money(effective)),
              if (card.usedLimit != null)
                _Info('limite usado', Formatters.money(card.usedLimit)),
              if (card.availableLimit != null)
                _Info('disponível', Formatters.money(card.availableLimit)),
              if (card.personalLimit != null)
                _Info('teto pessoal', Formatters.money(card.personalLimit)),
            ],
          ),
          if (effective == null && card.availableLimit == null)
            Text(
              'limite não informado para este cartão',
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: secondary,
              ),
            ),
          if (effective != null && card.availableLimit == null)
            Text(
              'limite disponível não foi retornado pelo backend',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondary,
              ),
            ),
          if (effective == null)
            const SizedBox.shrink()
          else
            Text(
              '',
              style: AppTypography.body(context, fontSize: 1, color: primary),
            ),
        ],
      ),
    );
  }
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({required this.progress, required this.label});
  final double progress;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final positive = AppColors.positiveText(brightness);
    return _Surface(
      compact: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0).toDouble(),
              minHeight: 7,
              backgroundColor: AppColors.border(brightness),
              valueColor: AlwaysStoppedAnimation<Color>(positive),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.body(
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

class _MovementRow extends StatelessWidget {
  const _MovementRow(this.item);
  final WalletMovement item;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final positive = AppColors.positiveText(brightness);
    final expense = AppColors.expenseText(brightness);
    return _RowCard(
      icon: item.amount >= 0 ? AppIcons.income : AppIcons.expense,
      iconColor: item.amount >= 0 ? positive : expense,
      title: item.description,
      subtitle: [
        if (item.categoryName != null) item.categoryName!,
        Formatters.shortDate.format(item.occurredAt),
      ].join(' · '),
      trailing: Formatters.money(item.amount),
      trailingColor: item.amount >= 0 ? positive : expense,
    );
  }
}

class _PurchaseRow extends StatelessWidget {
  const _PurchaseRow(this.item);
  final WalletCardPurchaseLine item;

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      icon: AppIcons.receipt,
      title: item.displayName,
      subtitle: [
        if (item.categoryName != null) item.categoryName!,
        Formatters.shortDate.format(item.purchaseAt),
        if (item.totalInstallments > 1)
          '${item.installmentNumber} de ${item.totalInstallments}',
      ].join(' · '),
      trailing: Formatters.money(item.amount),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow(this.item);
  final WalletCardInstallmentLine item;

  @override
  Widget build(BuildContext context) {
    return _RowCard(
      icon: AppIcons.calendar,
      title: item.displayName,
      subtitle: [
        '${item.installmentNumber} de ${item.totalInstallments}',
        if (item.invoiceDueDate != null)
          Formatters.shortDate.format(item.invoiceDueDate!),
      ].join(' · '),
      trailing: '${Formatters.money(item.amount)}/mês',
    );
  }
}

class _DebtRow extends StatelessWidget {
  const _DebtRow(this.item);
  final WalletDebtInstallment item;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tone = item.isOverdue
        ? AppColors.expenseText(brightness)
        : item.status == 'paid'
            ? AppColors.positiveText(brightness)
            : AppColors.secondaryText(brightness);
    return _RowCard(
      icon: AppIcons.debt,
      iconColor: tone,
      title: 'parcela ${item.installmentNumber}',
      subtitle:
          '${Formatters.shortDate.format(item.dueDate)} · ${_debtStatusLabel(item.status)}',
      trailing: Formatters.money(item.remainingAmount),
    );
  }
}

class _AsyncList extends StatelessWidget {
  const _AsyncList({
    required this.loading,
    required this.error,
    required this.emptyText,
    required this.onRetry,
    required this.children,
  });

  final bool loading;
  final String? error;
  final String emptyText;
  final Future<void> Function() onRetry;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (error != null) {
      final brightness = Theme.of(context).brightness;
      final expense = AppColors.expenseText(brightness);
      return _Surface(
        borderColor: expense.withValues(alpha: .24),
        child: Column(
          children: [
            Icon(AppIcons.warning, color: expense),
            const SizedBox(height: 7),
            Text(
              'não consegui carregar esta parte da carteira',
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
                fontSize: 11,
                color: expense,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              error!,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: AppTypography.body(
                context,
                fontSize: 9,
                color: AppColors.secondaryText(brightness),
              ),
            ),
            TextButton(
              onPressed: () => onRetry(),
              child: const Text('tentar novamente'),
            ),
          ],
        ),
      );
    }
    if (children.isEmpty) {
      return _Surface(
        child: Text(
          emptyText,
          textAlign: TextAlign.center,
          style: AppTypography.body(
            context,
            fontSize: 11,
            color: AppColors.secondaryText(Theme.of(context).brightness),
          ),
        ),
      );
    }
    return Column(children: children);
  }
}

class _RowCard extends StatelessWidget {
  const _RowCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.iconColor,
    this.trailingColor,
  });

  final IconData icon;
  final Color? iconColor;
  final String title;
  final String subtitle;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final tone = iconColor ?? purple;
    return Padding(
      padding: const EdgeInsets.only(bottom: 9),
      child: _Surface(
        compact: true,
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: tone.withValues(alpha: .10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 18, color: tone),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: primary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.body(
                      context,
                      fontSize: 10,
                      color: secondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                trailing,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.right,
                style: AppTypography.money(
                  context,
                  fontSize: 11,
                  color: trailingColor ?? primary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({
    required this.child,
    this.borderColor,
    this.compact = false,
  });

  final Widget child;
  final Color? borderColor;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 13 : 18),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(compact ? 18 : 22),
        border: Border.all(
          color: borderColor ?? AppColors.border(brightness),
        ),
      ),
      child: child,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, {this.description});
  final String title;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTypography.section(
            context,
            fontSize: 17,
            color: AppColors.primaryText(brightness),
          ),
        ),
        if (description != null) ...[
          const SizedBox(height: 3),
          Text(
            description!,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ],
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: AppTypography.label(
        context,
        fontSize: 9,
        color: AppColors.secondaryText(Theme.of(context).brightness),
      ),
    );
  }
}

class _Info {
  const _Info(this.label, this.value);
  final String label;
  final String value;
}

class _InfoGrid extends StatelessWidget {
  const _InfoGrid({required this.items});
  final List<_Info> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 780 ? 3 : 2;
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: items
              .map(
                (item) => SizedBox(
                  width: width,
                  child: _Surface(
                    compact: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _Label(item.label),
                        const SizedBox(height: 4),
                        Text(
                          item.value,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primaryText(
                              Theme.of(context).brightness,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    );
  }
}

Color _limitTone(Brightness brightness, double? ratio) {
  if (ratio == null || ratio < .70) {
    return AppColors.positiveText(brightness);
  }
  if (ratio <= 1) return AppColors.primaryPurple(brightness);
  return AppColors.expenseText(brightness);
}

String _accountTypeLabel(String type) {
  switch (type) {
    case 'checking':
      return 'conta corrente';
    case 'savings':
      return 'poupança';
    case 'cash':
      return 'dinheiro';
    case 'reserve':
      return 'reserva';
    case 'investment':
      return 'investimento';
    case 'other':
      return 'outra conta';
    default:
      return type;
  }
}

String _debtStatusLabel(String status) {
  switch (status) {
    case 'paid':
      return 'paga';
    case 'overdue':
      return 'atrasada';
    case 'partially_paid':
      return 'parcialmente paga';
    case 'pending':
      return 'pendente';
    default:
      return status;
  }
}
