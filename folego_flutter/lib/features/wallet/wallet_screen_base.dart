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
import 'card_invoice_payment_sheet.dart';
import 'wallet_detail_screen.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen> {
  bool _loading = true;
  String? _error;
  WalletOverview? _overview;
  int _section = 0;

  bool _installmentsLoading = false;
  String? _installmentsError;
  List<WalletInstallmentPosition>? _installmentPositions;

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
      final overview = await widget.repository.getWalletOverview(
        spaceId: widget.spaceId,
      );
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _loading = false;
      });
      if (_section == 4 || _installmentPositions != null) {
        await _loadInstallments();
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  Future<void> _loadInstallments() async {
    if (_installmentsLoading) return;
    setState(() {
      _installmentsLoading = true;
      _installmentsError = null;
    });
    try {
      final positions = await widget.repository.listWalletInstallmentPositions(
        spaceId: widget.spaceId,
      );
      if (!mounted) return;
      setState(() {
        _installmentPositions = positions;
        _installmentsLoading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _installmentsLoading = false;
        _installmentsError = error.toString();
      });
    }
  }

  void _selectSection(int index) {
    if (_section == index) return;
    setState(() => _section = index);
    if (index == 4 && _installmentPositions == null) {
      _loadInstallments();
    }
  }

  Future<void> _openInvoicePayment(WalletCard card) async {
    if (!card.canPayInvoice) return;
    final paid = await showCardInvoicePaymentSheet(
      context: context,
      repository: widget.repository,
      spaceId: widget.spaceId,
      card: card,
    );
    if (paid != true || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('fatura atualizada')),
    );
    await _load();
  }

  Future<void> _openAccount(WalletAccount account) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletAccountDetailScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          account: account,
        ),
      ),
    );
  }

  Future<void> _openBenefit(WalletAccount benefit) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletBenefitDetailScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          benefit: benefit,
        ),
      ),
    );
  }

  Future<void> _openCard(WalletCard card) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletCardDetailScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          card: card,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _openDebt(WalletDebt debt) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletDebtDetailScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
          debt: debt,
        ),
      ),
    );
  }

  Future<void> _openInstallment(WalletInstallmentPosition item) async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => WalletInstallmentDetailScreen(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(0, 22, 0, 150),
              children: [
                _buildHeader(brightness),
                const SizedBox(height: 22),
                if (_loading)
                  const _WalletLoading()
                else if (_error != null)
                  _WalletError(message: _error!, onRetry: _load)
                else if (_overview != null) ...[
                  _buildPositionSummary(),
                  const SizedBox(height: 24),
                  _buildSelector(),
                  const SizedBox(height: 20),
                  _buildSelectedSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Brightness brightness) {
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'carteira',
                style: AppTypography.display(
                  context,
                  fontSize: 28,
                  color: primary,
                ),
              ),
            ),
            IconButton(
              tooltip: 'atualizar',
              onPressed: _load,
              style: IconButton.styleFrom(
                minimumSize: const Size(42, 42),
                backgroundColor: surface,
                foregroundColor: secondary,
                side: BorderSide(color: border),
              ),
              icon: const Icon(AppIcons.refresh, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'contas, cartões, benefícios e dívidas num só lugar',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondary,
          ),
        ),
      ],
    );
  }

  Widget _buildPositionSummary() {
    final summary = _overview!.summary;
    final metrics = [
      _PositionMetric(
        label: 'dinheiro em contas',
        value: summary.totalCash,
        icon: AppIcons.account,
        subtitle: '${Formatters.money(summary.availableCash)} disponível para gastar',
      ),
      _PositionMetric(
        label: 'benefícios',
        value: summary.totalBenefit,
        icon: AppIcons.benefit,
      ),
      _PositionMetric(
        label: 'faturas em aberto',
        value: summary.totalCardInvoice,
        icon: AppIcons.creditCard,
      ),
      _PositionMetric(
        label: 'dívidas restantes',
        value: summary.totalDebtRemaining,
        icon: AppIcons.debt,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
        final columns = switch (layout) {
          AppLayoutSize.compact => 2,
          AppLayoutSize.medium => 4,
          AppLayoutSize.expanded => 4,
          AppLayoutSize.wide => 4,
        };
        const spacing = 10.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: metrics
              .map(
                (metric) => SizedBox(
                  width: width,
                  child: _PositionMetricCard(metric: metric),
                ),
              )
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildSelector() {
    final sections = [
      ('contas', AppIcons.account, _overview!.paymentAccounts.length),
      ('cartões', AppIcons.creditCard, _overview!.cards.length),
      ('benefícios', AppIcons.benefit, _overview!.benefits.length),
      ('dívidas', AppIcons.debt, _overview!.debts.length),
      (
        'parcelas',
        AppIcons.calendar,
        _installmentPositions?.length ?? _overview!.installments.length,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sections.length, (index) {
          final section = sections[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _WalletSectionChip(
              label: '${section.$1} ${section.$3}',
              icon: section.$2,
              selected: _section == index,
              onTap: () => _selectSection(index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedSection() {
    switch (_section) {
      case 0:
        return _buildAccounts();
      case 1:
        return _buildCards();
      case 2:
        return _buildBenefits();
      case 3:
        return _buildDebts();
      case 4:
        return _buildInstallments();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccounts() {
    final accounts = _overview!.paymentAccounts;
    return _WalletSection(
      title: 'suas contas',
      description: 'seu dinheiro disponível em contas e reservas',
      child: accounts.isEmpty
          ? const _WalletEmpty(
              icon: AppIcons.account,
              title: 'nenhuma conta por aqui',
              description: 'suas contas aparecerão nesta seção',
            )
          : _ResponsiveWalletGrid(
              children: accounts
                  .map(
                    (account) => _AccountCard(
                      account: account,
                      onTap: () => _openAccount(account),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildCards() {
    final cards = _overview!.cards;
    return _WalletSection(
      title: 'seus cartões',
      description: 'fatura e limite de cada cartão',
      child: cards.isEmpty
          ? const _WalletEmpty(
              icon: AppIcons.creditCard,
              title: 'nenhum cartão por aqui',
              description: 'seus cartões de crédito aparecerão nesta seção',
            )
          : _ResponsiveWalletGrid(
              children: cards
                  .map(
                    (card) => _CreditCardCard(
                      card: card,
                      onTap: () => _openCard(card),
                      onPay: card.canPayInvoice
                          ? () => _openInvoicePayment(card)
                          : null,
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildBenefits() {
    final benefits = _overview!.benefits;
    return _WalletSection(
      title: 'seus benefícios',
      description: 'vale, alimentação e outros benefícios separados das contas',
      child: benefits.isEmpty
          ? const _WalletEmpty(
              icon: AppIcons.benefit,
              title: 'nenhum benefício por aqui',
              description: 'seus saldos de benefício aparecerão nesta seção',
            )
          : _ResponsiveWalletGrid(
              children: benefits
                  .map(
                    (benefit) => _BenefitCard(
                      benefit: benefit,
                      onTap: () => _openBenefit(benefit),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildDebts() {
    final debts = _overview!.debts;
    return _WalletSection(
      title: 'suas dívidas',
      description: 'o que você deve e quanto ainda falta pagar',
      child: debts.isEmpty
          ? const _WalletEmpty(
              icon: AppIcons.debt,
              title: 'nenhuma dívida por aqui',
              description: 'obrigações ativas aparecerão nesta seção',
            )
          : _ResponsiveWalletGrid(
              children: debts
                  .map(
                    (debt) => _DebtCard(
                      debt: debt,
                      onTap: () => _openDebt(debt),
                    ),
                  )
                  .toList(growable: false),
            ),
    );
  }

  Widget _buildInstallments() {
    Widget content;
    if (_installmentsLoading && _installmentPositions == null) {
      content = const _WalletSectionLoading();
    } else if (_installmentsError != null && _installmentPositions == null) {
      content = _WalletSectionError(
        message: _installmentsError!,
        onRetry: _loadInstallments,
      );
    } else {
      final items = _installmentPositions ?? const <WalletInstallmentPosition>[];
      content = items.isEmpty
          ? const _WalletEmpty(
              icon: AppIcons.calendar,
              title: 'nenhuma parcela por aqui',
              description: 'compras parceladas aparecerão nesta seção',
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_installmentsError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _WalletSectionError(
                      message: _installmentsError!,
                      onRetry: _loadInstallments,
                    ),
                  ),
                _ResponsiveWalletGrid(
                  children: items
                      .map(
                        (item) => _InstallmentCard(
                          item: item,
                          onTap: () => _openInstallment(item),
                        ),
                      )
                      .toList(growable: false),
                ),
              ],
            );
    }

    return _WalletSection(
      title: 'parcelas',
      description: 'o que ainda falta das compras parceladas',
      child: content,
    );
  }
}

class _PositionMetric {
  const _PositionMetric({
    required this.label,
    required this.value,
    required this.icon,
    this.subtitle,
  });
  final String label;
  final double value;
  final IconData icon;
  final String? subtitle;
}

class _PositionMetricCard extends StatelessWidget {
  const _PositionMetricCard({required this.metric});
  final _PositionMetric metric;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    return Container(
      constraints: const BoxConstraints(minHeight: 108),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(metric.icon, size: 17, color: purple),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  metric.label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    color: secondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              Formatters.money(metric.value),
              style: AppTypography.money(
                context,
                fontSize: 16,
                color: metric.value < 0
                    ? AppColors.expenseText(brightness)
                    : primary,
              ),
            ),
          ),
          if (metric.subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              metric.subtitle!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.label(
                context,
                fontSize: 9,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalletSection extends StatelessWidget {
  const _WalletSection({
    required this.title,
    required this.description,
    required this.child,
  });

  final String title;
  final String description;
  final Widget child;

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
            fontSize: 20,
            color: AppColors.primaryText(brightness),
          ),
        ),
        const SizedBox(height: 3),
        Text(
          description,
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: AppColors.secondaryText(brightness),
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _ResponsiveWalletGrid extends StatelessWidget {
  const _ResponsiveWalletGrid({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final layout = AppBreakpoints.fromWidth(constraints.maxWidth);
        final columns = switch (layout) {
          AppLayoutSize.compact => 1,
          AppLayoutSize.medium => 2,
          AppLayoutSize.expanded => 2,
          AppLayoutSize.wide => 3,
        };
        const spacing = 12.0;
        final width =
            (constraints.maxWidth - spacing * (columns - 1)) / columns;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: children
              .map((child) => SizedBox(width: width, child: child))
              .toList(growable: false),
        );
      },
    );
  }
}

class _AccountCard extends StatelessWidget {
  const _AccountCard({required this.account, required this.onTap});
  final WalletAccount account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final positive = AppColors.positiveText(brightness);
    return _InteractiveWalletCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardIcon(icon: AppIcons.account),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (account.institution?.trim().isNotEmpty == true)
                          account.institution!.trim(),
                        _accountTypeLabel(account.type),
                      ].join(' · '),
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
              const Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'saldo',
            style: AppTypography.label(context, fontSize: 9, color: secondary),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.money(account.balance),
            style: AppTypography.money(
              context,
              fontSize: 21,
              color: account.balance < 0
                  ? AppColors.expenseText(brightness)
                  : primary,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _StatusPill(label: 'ativa', color: positive),
              _StatusPill(
                label: account.availableForSpending
                    ? 'entra no saldo disponível'
                    : 'saldo protegido',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BenefitCard extends StatelessWidget {
  const _BenefitCard({required this.benefit, required this.onTap});
  final WalletAccount benefit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final positive = AppColors.positiveText(brightness);
    return _InteractiveWalletCard(
      onTap: onTap,
      accentColor: positive,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: AppIcons.benefit, color: positive),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      benefit.institution?.trim().isNotEmpty == true
                          ? benefit.institution!.trim()
                          : 'benefício',
                      style: AppTypography.body(
                        context,
                        fontSize: 10,
                        color: secondary,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 18),
          Text(
            'saldo de benefício',
            style: AppTypography.label(context, fontSize: 9, color: secondary),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.money(benefit.balance),
            style: AppTypography.money(context, fontSize: 21, color: primary),
          ),
          const SizedBox(height: 12),
          Text(
            'separado do dinheiro das suas contas',
            style: AppTypography.body(
              context,
              fontSize: 10,
              color: secondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreditCardCard extends StatelessWidget {
  const _CreditCardCard({
    required this.card,
    required this.onTap,
    this.onPay,
  });

  final WalletCard card;
  final VoidCallback onTap;
  final VoidCallback? onPay;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final ratio = card.limitUsageRatio;
    final tone = _limitTone(brightness, ratio);
    final identity = [
      if (card.issuer?.trim().isNotEmpty == true) card.issuer!.trim(),
      if (card.brand?.trim().isNotEmpty == true) card.brand!.trim(),
      if (card.lastFour?.trim().isNotEmpty == true)
        '•••• ${card.lastFour!.trim()}',
    ].join(' · ');

    return _InteractiveWalletCard(
      onTap: onTap,
      accentColor: purple,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _CardIcon(icon: AppIcons.creditCard),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    if (identity.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        identity,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 10,
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 17),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _CardMetric(
                  label: 'fatura atual',
                  value: Formatters.money(card.invoiceBalance),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardMetric(
                  label: 'limite disponível',
                  value: card.availableLimit == null
                      ? '—'
                      : Formatters.money(card.availableLimit),
                  alignRight: true,
                ),
              ),
            ],
          ),
          if (ratio != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'uso do limite',
                    style: AppTypography.body(
                      context,
                      fontSize: 9,
                      color: secondary,
                    ),
                  ),
                ),
                Text(
                  '${(ratio * 100).round()}%',
                  style: AppTypography.label(
                    context,
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: tone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio.clamp(0.0, 1.0).toDouble(),
                minHeight: 7,
                backgroundColor: AppColors.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(tone),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  card.invoiceDueDate == null
                      ? 'vence dia ${card.dueDay}'
                      : 'vence ${Formatters.shortDate.format(card.invoiceDueDate!)}',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondary,
                  ),
                ),
              ),
              Text(
                'fecha dia ${card.closingDay}',
                style: AppTypography.body(
                  context,
                  fontSize: 10,
                  color: secondary,
                ),
              ),
            ],
          ),
          if (card.issuerLimit != null || card.personalLimit != null) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (card.issuerLimit != null || card.personalLimit != null)
                  _StatusPill(
                    label:
                        'limite total ${Formatters.money(card.issuerLimit ?? card.personalLimit)}',
                  ),
                if (card.personalLimit != null)
                  _StatusPill(
                    label:
                        'teto pessoal ${Formatters.money(card.personalLimit)}',
                  ),
              ],
            ),
          ],
          if (onPay != null) ...[
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
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

class _DebtCard extends StatelessWidget {
  const _DebtCard({required this.debt, required this.onTap});
  final WalletDebt debt;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final expense = AppColors.expenseText(brightness);
    final positive = AppColors.positiveText(brightness);
    final progress = debt.progress;
    return _InteractiveWalletCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CardIcon(icon: AppIcons.debt, color: expense),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primary,
                      ),
                    ),
                    if (debt.creditor?.trim().isNotEmpty == true) ...[
                      const SizedBox(height: 3),
                      Text(
                        debt.creditor!,
                        style: AppTypography.body(
                          context,
                          fontSize: 10,
                          color: secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(AppIcons.chevronRight, size: 18),
            ],
          ),
          const SizedBox(height: 17),
          Text(
            'saldo restante',
            style: AppTypography.label(context, fontSize: 9, color: secondary),
          ),
          const SizedBox(height: 4),
          Text(
            Formatters.money(debt.remainingBalance),
            style: AppTypography.money(context, fontSize: 21, color: primary),
          ),
          if (progress != null && debt.originalAmount != null) ...[
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: AppColors.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(positive),
              ),
            ),
            const SizedBox(height: 7),
            Text(
              '${Formatters.money(debt.paidAmount)} de ${Formatters.money(debt.originalAmount)} pagos · ${(progress * 100).round()}%',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondary,
              ),
            ),
          ],
          const SizedBox(height: 12),
          const _StatusPill(label: 'ativa'),
          if (debt.nextDueDate != null) ...[
            const SizedBox(height: 12),
            Text(
              'próxima ${Formatters.money(debt.nextAmount)} · ${Formatters.shortDate.format(debt.nextDueDate!)}',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InstallmentCard extends StatelessWidget {
  const _InstallmentCard({required this.item, required this.onTap});
  final WalletInstallmentPosition item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final positive = AppColors.positiveText(brightness);
    final tone = item.completed ? secondary : purple;
    return Opacity(
      opacity: item.completed ? .72 : 1,
      child: _InteractiveWalletCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _CardIcon(icon: AppIcons.calendar, color: tone),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.body(
                          context,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: primary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          item.cardName,
                          if (item.categoryName != null) item.categoryName!,
                        ].join(' · '),
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
                const Icon(AppIcons.chevronRight, size: 18),
              ],
            ),
            const SizedBox(height: 17),
            Row(
              children: [
                Expanded(
                  child: _CardMetric(
                    label: 'parcela',
                    value: Formatters.money(item.installmentAmount),
                  ),
                ),
                Expanded(
                  child: _CardMetric(
                    label: item.completed ? 'status' : 'andamento',
                    value: item.completed
                        ? 'concluído'
                        : '${item.currentInstallment} de ${item.totalInstallments}',
                    alignRight: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 13),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: item.progress,
                minHeight: 7,
                backgroundColor: AppColors.border(brightness),
                valueColor: AlwaysStoppedAnimation<Color>(
                  item.completed ? positive : purple,
                ),
              ),
            ),
            if (item.nextDueDate != null) ...[
              const SizedBox(height: 8),
              Text(
                'próxima fatura ${Formatters.shortDate.format(item.nextDueDate!)}',
                style: AppTypography.body(
                  context,
                  fontSize: 10,
                  color: secondary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CardMetric extends StatelessWidget {
  const _CardMetric({
    required this.label,
    required this.value,
    this.alignRight = false,
  });
  final String label;
  final String value;
  final bool alignRight;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Column(
      crossAxisAlignment:
          alignRight ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: AppTypography.label(
            context,
            fontSize: 9,
            color: AppColors.secondaryText(brightness),
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: alignRight ? Alignment.centerRight : Alignment.centerLeft,
          child: Text(
            value,
            textAlign: alignRight ? TextAlign.right : TextAlign.left,
            style: AppTypography.body(
              context,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.primaryText(brightness),
            ),
          ),
        ),
      ],
    );
  }
}

class _InteractiveWalletCard extends StatelessWidget {
  const _InteractiveWalletCard({
    required this.onTap,
    required this.child,
    this.accentColor,
  });

  final VoidCallback onTap;
  final Widget child;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final border = AppColors.border(brightness);
    return Material(
      color: AppColors.surface(brightness),
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: accentColor?.withValues(alpha: .24) ?? border,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({required this.icon, this.color});
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tone = color ?? AppColors.primaryPurple(brightness);
    return Container(
      width: 42,
      height: 42,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .11),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Icon(icon, color: tone, size: 20),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tone = color ?? AppColors.secondaryText(brightness);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: .08),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: tone.withValues(alpha: .16)),
      ),
      child: Text(
        label,
        style: AppTypography.label(
          context,
          fontSize: 8,
          fontWeight: FontWeight.w600,
          color: tone,
        ),
      ),
    );
  }
}

class _WalletEmpty extends StatelessWidget {
  const _WalletEmpty({
    required this.icon,
    required this.title,
    required this.description,
  });
  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          _CardIcon(icon: icon, color: purple),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.secondaryText(brightness),
            ),
          ),
        ],
      ),
    );
  }
}

class _WalletSectionLoading extends StatelessWidget {
  const _WalletSectionLoading();
  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 120,
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _WalletLoading extends StatelessWidget {
  const _WalletLoading();
  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 100),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _WalletSectionError extends StatelessWidget {
  const _WalletSectionError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final expense = AppColors.expenseText(brightness);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: expense.withValues(alpha: .24)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.warning, size: 20, color: expense),
          const SizedBox(height: 8),
          Text(
            'não consegui carregar as parcelas',
            textAlign: TextAlign.center,
            style: AppTypography.body(context, fontSize: 11, color: expense),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 9,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => onRetry(),
            child: const Text('tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _WalletError extends StatelessWidget {
  const _WalletError({required this.message, required this.onRetry});
  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final expense = AppColors.expenseText(brightness);
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: Column(
        children: [
          Icon(AppIcons.warning, size: 24, color: expense),
          const SizedBox(height: 12),
          Text(
            'não consegui carregar sua carteira',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.primaryText(brightness),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 10,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => onRetry(),
            child: const Text('tentar novamente'),
          ),
        ],
      ),
    );
  }
}

class _WalletSectionChip extends StatelessWidget {
  const _WalletSectionChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? purple.withValues(alpha: .13) : surface,
            borderRadius: BorderRadius.circular(99),
            border: Border.all(
              color: selected ? purple.withValues(alpha: .45) : border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: selected ? purple : secondary),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? primary : secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Color _limitTone(Brightness brightness, double? ratio) {
  if (ratio == null || ratio < .70) {
    return AppColors.positiveText(brightness);
  }
  if (ratio <= 1) {
    return AppColors.primaryPurple(brightness);
  }
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
