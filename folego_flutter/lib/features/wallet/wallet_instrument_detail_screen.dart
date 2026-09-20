import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/wallet_detail.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_payment_instruments.dart';
import '../../data/repositories/folego_repository_wallet_details.dart';
import '../../data/repositories/folego_repository_wallet_management.dart';
import '../../shared/widgets/app_error_state.dart';
import '../../shared/widgets/app_loading_state.dart';
import '../../shared/widgets/app_page_header.dart';
import '../../shared/widgets/app_section_header.dart';
import 'card_invoice_payment_sheet.dart';
import 'wallet_instrument_management.dart';

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
    return _WalletAccountDetailPage(
      repository: repository,
      spaceId: spaceId,
      initial: account,
      benefitMode: false,
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
    return _WalletAccountDetailPage(
      repository: repository,
      spaceId: spaceId,
      initial: benefit,
      benefitMode: true,
    );
  }
}

class _WalletAccountDetailPage extends StatefulWidget {
  const _WalletAccountDetailPage({
    required this.repository,
    required this.spaceId,
    required this.initial,
    required this.benefitMode,
  });

  final FolegoRepository repository;
  final String spaceId;
  final WalletAccount initial;
  final bool benefitMode;

  @override
  State<_WalletAccountDetailPage> createState() => _WalletAccountDetailPageState();
}

class _WalletAccountDetailPageState extends State<_WalletAccountDetailPage> {
  late WalletAccount _account;
  bool _loading = true;
  String? _error;
  List<WalletMovement> _movements = const [];

  String get _dimension => widget.benefitMode ? 'benefit' : 'cash';

  @override
  void initState() {
    super.initState();
    _account = widget.initial;
    _load();
  }

  Future<void> _load() async {
    try {
      final values = await Future.wait<dynamic>([
        widget.repository.getWalletOverview(spaceId: widget.spaceId),
        widget.repository.listWalletMovements(
          spaceId: widget.spaceId,
          accountId: _account.id,
          dimension: _dimension,
          limit: 12,
        ),
      ]);
      if (!mounted) return;
      final overview = values[0] as WalletOverview;
      final matches = overview.accounts.where((item) => item.id == _account.id);
      setState(() {
        if (matches.isNotEmpty) _account = matches.first;
        _movements = values[1] as List<WalletMovement>;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = walletManagementFriendlyError(error);
      });
    }
  }

  Future<void> _edit() async {
    final changed = await showWalletAccountEditor(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      account: _account,
      benefitMode: widget.benefitMode,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _archive() async {
    final confirmed = await _confirmArchive(
      context,
      title: widget.benefitMode ? 'arquivar benefício?' : 'arquivar conta?',
      body: widget.benefitMode
          ? 'o histórico permanece intacto. o saldo precisa estar zerado antes do arquivamento.'
          : 'o histórico permanece intacto. saldo, recorrências, cartões e dívidas vinculadas precisam estar resolvidos.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.archiveWalletAccount(
        spaceId: widget.spaceId,
        accountId: _account.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(walletManagementFriendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final benefit = widget.benefitMode;
    return _InstrumentDetailScaffold(
      title: _account.name,
      subtitle: _account.institution ?? walletAccountTypeLabel(_account.type),
      icon: benefit ? AppIcons.benefit : AppIcons.account,
      onEdit: _edit,
      onArchive: _archive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveDetailGrid(
            children: [
              _DetailPanel(
                label: benefit ? 'saldo de benefício' : 'saldo atual',
                value: Formatters.money(_account.balance),
                supporting: benefit
                    ? 'dimensão benefit · fora de cash'
                    : 'derivado do ledger · nunca editado diretamente',
                emphasis: true,
              ),
              _DetailPanel(
                label: 'tipo',
                value: walletAccountTypeLabel(_account.type),
                supporting: benefit
                    ? 'não pode pagar fatura nem participar de transferências cash'
                    : _account.availableForSpending
                        ? 'incluída no dinheiro disponível'
                        : 'saldo protegido do disponível',
              ),
            ],
          ),
          const SizedBox(height: 24),
          _SectionTitle(
            benefit ? 'últimas movimentações do benefício' : 'últimas movimentações',
            'o instrumento pode ser arquivado sem apagar este histórico',
          ),
          const SizedBox(height: 12),
          if (_loading)
            const AppLoadingState(label: 'organizando este instrumento')
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_movements.isEmpty)
            const _EmptyCard(text: 'nenhuma movimentação encontrada')
          else
            ..._movements.map((item) => _MovementTile(item: item)),
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
  String? _paymentAccountName;
  List<WalletCardPurchaseLine> _purchases = const [];
  List<WalletCardInstallmentLine> _upcoming = const [];
  CardInvoiceSemantics? _invoiceSemantics;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _card = widget.card;
    _load();
  }

  Future<T> _bestEffort<T>(
    Future<T> Function() load,
    T fallback,
  ) async {
    try {
      return await load();
    } catch (error) {
      debugPrint('Wallet card optional detail failed: $error');
      return fallback;
    }
  }

  Future<void> _load() async {
    try {
      final overview = await widget.repository.getWalletOverview(spaceId: widget.spaceId);
      final match = overview.cards.where((item) => item.id == _card.id);
      final card = match.isEmpty ? _card : match.first;
      final accountsFuture = _bestEffort(
        () => widget.repository.listPaymentAccounts(widget.spaceId),
        const <dynamic>[],
      );
      final purchasesFuture = card.invoiceId == null
          ? Future.value(<WalletCardPurchaseLine>[])
          : _bestEffort(
              () => widget.repository.listCardInvoicePurchases(
                spaceId: widget.spaceId,
                cardId: card.id,
                invoiceId: card.invoiceId!,
              ),
              const <WalletCardPurchaseLine>[],
            );
      final upcomingFuture = _bestEffort(
        () => widget.repository.listCardUpcomingInstallments(
          spaceId: widget.spaceId,
          cardId: card.id,
          currentInvoiceId: card.invoiceId,
        ),
        const <WalletCardInstallmentLine>[],
      );
      final semanticsFuture = _bestEffort(
        () => widget.repository.getCardInvoiceSemantics(
          spaceId: widget.spaceId,
          cardId: card.id,
        ),
        CardInvoiceSemantics(
          grossPurchases: card.invoiceBalance,
          credits: 0,
          payments: 0,
          amountDue: card.invoiceBalance,
          dueDate: card.invoiceDueDate,
        ),
      );
      final values = await Future.wait<dynamic>([
        accountsFuture,
        purchasesFuture,
        upcomingFuture,
        semanticsFuture,
      ]);
      if (!mounted) return;
      final accounts = values[0] as List;
      String? payer;
      for (final account in accounts) {
        if (account.id == card.paymentAccountId) {
          payer = account.name as String;
          break;
        }
      }
      setState(() {
        _card = card;
        _paymentAccountName = payer;
        _purchases = values[1] as List<WalletCardPurchaseLine>;
        _upcoming = values[2] as List<WalletCardInstallmentLine>;
        _invoiceSemantics = values[3] as CardInvoiceSemantics;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = walletManagementFriendlyError(error);
      });
    }
  }

  Future<void> _edit() async {
    final changed = await showWalletCardEditor(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      card: _card,
    );
    if (changed == true && mounted) await _load();
  }

  Future<void> _payInvoice() async {
    if (!_card.canPayInvoice) return;
    final paid = await showCardInvoicePaymentSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      card: _card,
    );
    if (paid == true && mounted) await _load();
  }

  Future<void> _archive() async {
    final confirmed = await _confirmArchive(
      context,
      title: 'arquivar cartão?',
      body: 'faturas abertas, parcelas futuras ou recorrências impedem o arquivamento. nenhuma compra será cancelada automaticamente.',
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.archiveWalletCard(
        spaceId: widget.spaceId,
        cardId: _card.id,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(walletManagementFriendlyError(error))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final identity = [
      if (_card.issuer?.trim().isNotEmpty == true) _card.issuer!.trim(),
      if (_card.brand?.trim().isNotEmpty == true) _card.brand!.trim(),
      if (_card.lastFour?.trim().isNotEmpty == true) '•••• ${_card.lastFour!.trim()}',
    ].join(' · ');
    final semantics = _invoiceSemantics;
    final semanticDue = semantics?.dueDate ?? _card.invoiceDueDate;
    final due = semanticDue == null
        ? 'vence dia ${_card.dueDay}'
        : 'vence ${Formatters.shortDate.format(semanticDue)}';

    return _InstrumentDetailScaffold(
      title: _card.name,
      subtitle: identity.isEmpty ? 'cartão de crédito' : identity,
      icon: AppIcons.creditCard,
      onEdit: _edit,
      onArchive: _archive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ResponsiveDetailGrid(
            children: [
              _DetailPanel(
                label: 'compras do ciclo',
                value: Formatters.money(
                  semantics?.grossPurchases ?? _card.invoiceBalance,
                ),
                supporting: 'compras e parcelas lançadas neste ciclo',
              ),
              _DetailPanel(
                label: 'créditos',
                value: semantics == null || semantics.credits <= 0
                    ? Formatters.money(0)
                    : '-${Formatters.money(semantics.credits)}',
                supporting: 'estornos e créditos reduzem o valor a pagar',
              ),
              _DetailPanel(
                label: 'a pagar',
                value: Formatters.money(
                  semantics?.amountDue ?? _card.invoiceBalance,
                ),
                supporting: '$due · fecha dia ${_card.closingDay}',
                emphasis: true,
                action: _card.canPayInvoice
                    ? TextButton.icon(
                        onPressed: _payInvoice,
                        icon: const Icon(AppIcons.check, size: 16),
                        label: const Text('pagar'),
                      )
                    : null,
              ),
              _DetailPanel(
                label: 'vencimento',
                value: semanticDue == null
                    ? 'dia ${_card.dueDay}'
                    : Formatters.shortDate.format(semanticDue),
                supporting: semantics?.referenceMonth == null
                    ? 'ciclo atual'
                    : 'referência ${Formatters.monthYear.format(semantics!.referenceMonth!)}',
              ),
              _DetailPanel(
                label: 'limite',
                value: _card.effectiveLimit == null
                    ? 'não informado'
                    : Formatters.money(_card.effectiveLimit),
                supporting: [
                  if (_card.usedLimit != null) 'usado ${Formatters.money(_card.usedLimit)}',
                  if (_card.availableLimit != null) 'disponível ${Formatters.money(_card.availableLimit)}',
                ].join(' · '),
              ),
              _DetailPanel(
                label: 'conta pagadora',
                value: _paymentAccountName ?? 'não resolvida',
                supporting: 'benefícios nunca são elegíveis para pagamento de fatura',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _SectionTitle('compras da fatura', 'itens vinculados à fatura atual'),
          const SizedBox(height: 12),
          if (_loading)
            const AppLoadingState(label: 'organizando este instrumento')
          else if (_error != null)
            _ErrorCard(message: _error!, onRetry: _load)
          else if (_purchases.isEmpty)
            const _EmptyCard(text: 'nenhuma compra nesta fatura')
          else
            ..._purchases.map((item) => _CardPurchaseTile(item: item)),
          const SizedBox(height: 24),
          const _SectionTitle('parcelas futuras', 'compromissos deste cartão depois da fatura atual'),
          const SizedBox(height: 12),
          if (!_loading && _upcoming.isEmpty)
            const _EmptyCard(text: 'nenhuma parcela futura neste cartão')
          else if (!_loading)
            ..._upcoming.map((item) => _UpcomingInstallmentTile(item: item)),
        ],
      ),
    );
  }
}

class _InstrumentDetailScaffold extends StatelessWidget {
  const _InstrumentDetailScaffold({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onEdit,
    required this.onArchive,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final accent = AppColors.primaryPurple(brightness);

    return Scaffold(
      backgroundColor: AppColors.background(brightness),
      body: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(0, 20, 0, 48),
            children: [
              AppPageHeader(
                title: title,
                subtitle: subtitle,
                leading: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: 'voltar',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(AppIcons.back),
                    ),
                    Icon(icon, color: accent, size: 22),
                  ],
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      key: const ValueKey('wallet-detail-edit'),
                      tooltip: 'editar',
                      onPressed: onEdit,
                      icon: const Icon(AppIcons.edit),
                    ),
                    IconButton(
                      key: const ValueKey('wallet-detail-archive'),
                      tooltip: 'arquivar',
                      onPressed: onArchive,
                      icon: const Icon(AppIcons.eyeOff),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _ResponsiveDetailGrid extends StatelessWidget {
  const _ResponsiveDetailGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
        final columns = layout == AppLayoutSize.compact ? 1 : children.length.clamp(1, 3);
        const gap = 12.0;
        final width = (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: children.map((child) => SizedBox(width: width, child: child)).toList(growable: false),
        );
      },
    );
  }
}

class _DetailPanel extends StatelessWidget {
  const _DetailPanel({
    required this.label,
    required this.value,
    required this.supporting,
    this.emphasis = false,
    this.action,
  });

  final String label;
  final String value;
  final String supporting;
  final bool emphasis;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      constraints: const BoxConstraints(minHeight: 126),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.compactCard),
        border: Border.all(
          color: emphasis
              ? AppColors.primaryPurple(brightness).withValues(alpha: .25)
              : AppColors.border(brightness),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.label(context, fontSize: 9, color: AppColors.secondaryText(brightness))),
          const SizedBox(height: 8),
          Text(value, style: emphasis ? AppTypography.money(context, fontSize: 24) : AppTypography.section(context, fontSize: 17)),
          const SizedBox(height: 7),
          Text(supporting.isEmpty ? '—' : supporting, style: AppTypography.body(context, fontSize: 10, color: AppColors.secondaryText(brightness))),
          if (action != null) ...[const SizedBox(height: 8), action!],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title, this.subtitle);

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return AppSectionHeader(title: title, subtitle: subtitle);
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.item});
  final WalletMovement item;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return _RowSurface(
      icon: item.amount >= 0 ? AppIcons.income : AppIcons.expense,
      title: item.description,
      subtitle: [if (item.categoryName != null) item.categoryName!, Formatters.shortDate.format(item.occurredAt)].join(' · '),
      trailing: Formatters.money(item.amount),
      trailingColor: item.amount >= 0 ? AppColors.positiveText(brightness) : AppColors.expenseText(brightness),
    );
  }
}

class _CardPurchaseTile extends StatelessWidget {
  const _CardPurchaseTile({required this.item});
  final WalletCardPurchaseLine item;

  @override
  Widget build(BuildContext context) {
    return _RowSurface(
      icon: AppIcons.expense,
      title: item.displayName,
      subtitle: [
        if (item.categoryName != null) item.categoryName!,
        if (item.totalInstallments > 1) '${item.installmentNumber}/${item.totalInstallments}',
      ].join(' · '),
      trailing: Formatters.money(item.amount),
    );
  }
}

class _UpcomingInstallmentTile extends StatelessWidget {
  const _UpcomingInstallmentTile({required this.item});
  final WalletCardInstallmentLine item;

  @override
  Widget build(BuildContext context) {
    return _RowSurface(
      icon: AppIcons.calendar,
      title: item.displayName,
      subtitle: [
        '${item.installmentNumber}/${item.totalInstallments}',
        if (item.invoiceDueDate != null) Formatters.shortDate.format(item.invoiceDueDate!),
      ].join(' · '),
      trailing: Formatters.money(item.amount),
    );
  }
}

class _RowSurface extends StatelessWidget {
  const _RowSurface({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.trailing,
    this.trailingColor,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String trailing;
  final Color? trailingColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 19, color: AppColors.secondaryText(brightness)),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTypography.body(context, fontSize: 12, fontWeight: FontWeight.w600)),
                if (subtitle.isNotEmpty)
                  Text(subtitle, style: AppTypography.body(context, fontSize: 9, color: AppColors.secondaryText(brightness))),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(trailing, style: AppTypography.body(context, fontSize: 11, fontWeight: FontWeight.w700, color: trailingColor)),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Text(text, style: AppTypography.body(context, fontSize: 11, color: AppColors.secondaryText(brightness))),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return AppErrorState(
      title: 'não consegui carregar estes detalhes',
      description: message,
      onRetry: () async => onRetry(),
    );
  }
}

Future<bool?> _confirmArchive(
  BuildContext context, {
  required String title,
  required String body,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('cancelar')),
        FilledButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('arquivar')),
      ],
    ),
  );
}
