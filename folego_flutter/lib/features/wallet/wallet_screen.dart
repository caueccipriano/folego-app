import 'package:flutter/material.dart';
import 'package:tabler_icons_plus/tabler_icons_plus.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import 'card_invoice_payment_sheet.dart';

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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loading = false;
        _error = error.toString();
      });
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

  String _money(double value) {
    final negative = value < 0;
    final parts = value.abs().toStringAsFixed(2).split('.');
    final reversed = parts.first.split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      final end = i + 3 < reversed.length ? i + 3 : reversed.length;
      groups.add(reversed.sublist(i, end).reversed.join());
    }

    return '${negative ? '-' : ''}R\$ ${groups.reversed.join('.')},${parts.last}';
  }

  String _date(DateTime? value) {
    if (value == null) return '—';
    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _accountType(String value) {
    switch (value) {
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
        return value;
    }
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'cash':
        return TablerIcons.cashBanknote;
      case 'investment':
        return TablerIcons.chartLine;
      case 'reserve':
        return TablerIcons.lock;
      default:
        return TablerIcons.buildingBank;
    }
  }

  Color _valueColor({
    required double value,
    required Brightness brightness,
    required Color fallback,
  }) {
    return value < 0 ? AppColors.expenseText(brightness) : fallback;
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final background = AppColors.background(brightness);
    final layout = AppBreakpoints.of(context);
    final useTwoColumns =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    Widget? loadedContent;
    if (_overview != null) {
      final details = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSelector(brightness),
          const SizedBox(height: 20),
          _buildSelectedSection(brightness),
        ],
      );

      loadedContent = useTwoColumns
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 5, child: _buildSummary(brightness)),
                const SizedBox(width: 24),
                Expanded(flex: 7, child: details),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummary(brightness),
                const SizedBox(height: 24),
                details,
              ],
            );
    }

    return ColoredBox(
      color: background,
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
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _buildError(brightness)
                else if (loadedContent != null)
                  loadedContent,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Brightness brightness) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
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
                  color: primaryText,
                ),
              ),
            ),
            IconButton(
              tooltip: 'atualizar',
              onPressed: _load,
              style: IconButton.styleFrom(
                minimumSize: const Size(42, 42),
                backgroundColor: surface,
                foregroundColor: secondaryText,
                side: BorderSide(color: border),
              ),
              icon: const Icon(TablerIcons.refresh, size: 19),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'tudo que faz parte da sua vida financeira',
          style: AppTypography.body(
            context,
            fontSize: 13,
            color: secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(Brightness brightness) {
    final summary = _overview!.summary;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final expense = AppColors.expenseText(brightness);
    final availableColor = _valueColor(
      value: summary.availableCash,
      brightness: brightness,
      fallback: primaryText,
    );
    final highInvoice = summary.totalCardInvoice > summary.totalCash;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (highInvoice) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: expense.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(99),
              border: Border.all(color: expense.withValues(alpha: .24)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(TablerIcons.alertCircle, size: 16, color: expense),
                const SizedBox(width: 6),
                Text(
                  'fatura alta chegando',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: expense,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
        ],
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surface,
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: purple.withValues(alpha: .22)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: purple.withValues(alpha: .12),
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: Icon(TablerIcons.wallet, size: 19, color: purple),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'dinheiro disponível',
                    style: AppTypography.body(
                      context,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: secondaryText,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  _money(summary.availableCash),
                  style: AppTypography.money(
                    context,
                    fontSize: 31,
                    color: availableColor,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'o que está disponível nas contas marcadas para uso',
                style: AppTypography.body(
                  context,
                  fontSize: 12,
                  color: secondaryText,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _summaryMetric(
                      label: 'em contas',
                      value: summary.totalCash,
                      brightness: brightness,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _summaryMetric(
                      label: 'faturas',
                      value: summary.totalCardInvoice,
                      brightness: brightness,
                      emphasize: highInvoice,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              _summaryMetric(
                label: 'benefícios disponíveis',
                value: summary.totalBenefit,
                brightness: brightness,
                icon: AppIcons.benefit,
              ),
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    Icon(TablerIcons.wallet, color: purple, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'saldo restante em dívidas',
                        style: AppTypography.body(
                          context,
                          fontSize: 12,
                          color: secondaryText,
                        ),
                      ),
                    ),
                    Text(
                      _money(summary.totalDebtRemaining),
                      style: AppTypography.money(
                        context,
                        fontSize: 12,
                        color: _valueColor(
                          value: summary.totalDebtRemaining,
                          brightness: brightness,
                          fallback: primaryText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _summaryMetric({
    required String label,
    required double value,
    required Brightness brightness,
    bool emphasize = false,
    IconData? icon,
  }) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);
    final expense = AppColors.expenseText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final valueColor = value < 0
        ? expense
        : emphasize
            ? expense
            : primaryText;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: emphasize
            ? expense.withValues(alpha: .07)
            : border.withValues(alpha: .18),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: emphasize ? expense.withValues(alpha: .20) : border,
        ),
      ),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, size: 17, color: purple),
            const SizedBox(width: 8),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 5),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _money(value),
                    style: AppTypography.money(
                      context,
                      fontSize: 15,
                      color: valueColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector(Brightness brightness) {
    final sections = [
      ('contas', AppIcons.account, _overview!.paymentAccounts.length),
      ('cartões', AppIcons.creditCard, _overview!.cards.length),
      ('benefícios', AppIcons.benefit, _overview!.benefits.length),
      ('dívidas', AppIcons.debt, _overview!.debts.length),
      ('parcelas', AppIcons.calendar, _overview!.installments.length),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sections.length, (index) {
          final selected = _section == index;
          final section = sections[index];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _WalletSectionChip(
              label: '${section.$1} ${section.$3}',
              icon: section.$2,
              selected: selected,
              onTap: () => setState(() => _section = index),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSelectedSection(Brightness brightness) {
    switch (_section) {
      case 0:
        return _buildAccounts(brightness);
      case 1:
        return _buildCards(brightness);
      case 2:
        return _buildBenefits(brightness);
      case 3:
        return _buildDebts(brightness);
      case 4:
        return _buildInstallments(brightness);
      default:
        return const SizedBox();
    }
  }

  Widget _sectionHeader({
    required String title,
    required String description,
    required Brightness brightness,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
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
        ],
      ),
    );
  }

  Widget _responsiveCards(List<Widget> cards) {
    final layout = AppBreakpoints.of(context);
    final useGrid =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    if (!useGrid) {
      return Column(children: cards);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          children: cards
              .map((card) => SizedBox(width: width, child: card))
              .toList(growable: false),
        );
      },
    );
  }

  Widget _buildAccounts(Brightness brightness) {
    final accounts = _overview!.paymentAccounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'suas contas',
          description: 'onde seu dinheiro está hoje',
          brightness: brightness,
        ),
        if (accounts.isEmpty)
          _emptySection(
            icon: AppIcons.account,
            title: 'nenhuma conta cadastrada',
            description: 'suas contas aparecerão aqui',
            brightness: brightness,
          )
        else
          _responsiveCards(
            accounts.map((account) => _accountCard(account, brightness)).toList(),
          ),
      ],
    );
  }

  Widget _accountCard(WalletAccount account, Brightness brightness) {
    final purple = AppColors.primaryPurple(brightness);
    final positive = AppColors.positiveText(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);

    return _baseCard(
      brightness: brightness,
      child: Row(
        children: [
          _iconBox(icon: _accountIcon(account.type), color: purple),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: AppTypography.body(
                    context,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: primaryText,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account.institution ?? _accountType(account.type),
                  style: AppTypography.body(
                    context,
                    fontSize: 11,
                    color: secondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  account.availableForSpending
                      ? 'disponível para gastar'
                      : 'protegido do Fôlego',
                  style: AppTypography.label(
                    context,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: account.availableForSpending ? positive : purple,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              _money(account.balance),
              style: AppTypography.money(
                context,
                fontSize: 14,
                color: _valueColor(
                  value: account.balance,
                  brightness: brightness,
                  fallback: primaryText,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBenefits(Brightness brightness) {
    final benefits = _overview!.benefits;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'seus benefícios',
          description: 'saldos de alimentação, refeição e outros benefícios',
          brightness: brightness,
        ),
        if (benefits.isEmpty)
          _emptySection(
            icon: AppIcons.benefit,
            title: 'nenhum benefício cadastrado',
            description: 'seus saldos de benefício aparecerão aqui',
            brightness: brightness,
          )
        else
          _responsiveCards(
            benefits.map((benefit) => _benefitCard(benefit, brightness)).toList(),
          ),
      ],
    );
  }

  Widget _benefitCard(WalletAccount benefit, Brightness brightness) {
    final purple = AppColors.primaryPurple(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final positive = AppColors.positiveText(brightness);

    return _baseCard(
      brightness: brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _iconBox(icon: AppIcons.benefit, color: purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      benefit.name,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      benefit.institution == null || benefit.institution!.trim().isEmpty
                          ? 'benefício'
                          : '${benefit.institution} · benefício',
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'saldo disponível',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: secondaryText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _money(benefit.balance),
                    style: AppTypography.money(
                      context,
                      fontSize: 14,
                      color: _valueColor(
                        value: benefit.balance,
                        brightness: brightness,
                        fallback: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: positive.withValues(alpha: .08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: positive.withValues(alpha: .18)),
            ),
            child: Text(
              'saldo de benefício · não é crédito e não possui fatura',
              style: AppTypography.body(
                context,
                fontSize: 10,
                color: secondaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCards(Brightness brightness) {
    final cards = _overview!.cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'seus cartões',
          description: 'faturas, limites e vencimentos',
          brightness: brightness,
        ),
        if (cards.isEmpty)
          _emptySection(
            icon: AppIcons.creditCard,
            title: 'nenhum cartão cadastrado',
            description: 'seus cartões de crédito aparecerão aqui',
            brightness: brightness,
          )
        else
          _responsiveCards(
            cards.map((card) => _cardCard(card, brightness)).toList(),
          ),
      ],
    );
  }

  Widget _cardCard(WalletCard card, Brightness brightness) {
    final limit = card.effectiveLimit;
    final ratio = limit != null && limit > 0
        ? (card.invoiceBalance / limit).clamp(0.0, 1.0)
        : null;
    final purple = AppColors.primaryPurple(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return _baseCard(
      brightness: brightness,
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon: AppIcons.creditCard, color: purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (card.brand != null) card.brand!,
                        if (card.lastFour != null) '•••• ${card.lastFour!.trim()}',
                      ].join(' · '),
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'fatura',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: secondaryText,
                    ),
                  ),
                  Text(
                    _money(card.invoiceBalance),
                    style: AppTypography.money(
                      context,
                      fontSize: 13,
                      color: _valueColor(
                        value: card.invoiceBalance,
                        brightness: brightness,
                        fallback: primaryText,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (ratio != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 7,
                backgroundColor: border.withValues(alpha: .45),
                valueColor: AlwaysStoppedAnimation<Color>(purple),
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  label: 'limite disponível',
                  value: card.availableLimit == null
                      ? '—'
                      : _money(card.availableLimit!),
                  brightness: brightness,
                  valueColor: card.availableLimit != null && card.availableLimit! < 0
                      ? AppColors.expenseText(brightness)
                      : null,
                ),
              ),
              Expanded(
                child: _smallInfo(
                  label: 'vencimento',
                  value: card.invoiceDueDate != null
                      ? _date(card.invoiceDueDate)
                      : 'dia ${card.dueDay}',
                  alignRight: true,
                  brightness: brightness,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  'fecha dia ${card.closingDay}',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
              ),
              if (limit != null)
                Text(
                  'limite ${_money(limit)}',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
            ],
          ),
          if (card.canPayInvoice) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openInvoicePayment(card),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46),
                  foregroundColor: purple,
                  side: BorderSide(color: purple.withValues(alpha: .38)),
                ),
                icon: const Icon(AppIcons.cash, size: 18),
                label: Text(
                  'pagar fatura',
                  style: AppTypography.button(context, color: purple),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDebts(Brightness brightness) {
    final debts = _overview!.debts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'suas dívidas',
          description: 'acompanhe o que ainda falta pagar',
          brightness: brightness,
        ),
        if (debts.isEmpty)
          _emptySection(
            icon: AppIcons.debt,
            title: 'nenhuma dívida ativa',
            description: 'quando houver uma dívida ativa, ela aparecerá aqui',
            brightness: brightness,
          )
        else
          _responsiveCards(
            debts.map((debt) => _debtCard(debt, brightness)).toList(),
          ),
      ],
    );
  }

  Widget _debtCard(WalletDebt debt, Brightness brightness) {
    final total = debt.originalAmount ?? debt.openingBalance;
    final progress = total > 0
        ? ((total - debt.remainingBalance) / total).clamp(0.0, 1.0)
        : 0.0;
    final expense = AppColors.expenseText(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return _baseCard(
      brightness: brightness,
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon: AppIcons.debt, color: expense),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    if (debt.creditor != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        debt.creditor!,
                        style: AppTypography.body(
                          context,
                          fontSize: 11,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'falta pagar',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: secondaryText,
                    ),
                  ),
                  Text(
                    _money(debt.remainingBalance),
                    style: AppTypography.money(
                      context,
                      fontSize: 13,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: border.withValues(alpha: .45),
              valueColor: const AlwaysStoppedAnimation<Color>(AppColors.lime),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  label: 'próxima parcela',
                  value: debt.nextDueDate == null
                      ? '—'
                      : '${_money(debt.nextAmount)} · ${_date(debt.nextDueDate)}',
                  brightness: brightness,
                ),
              ),
              if (debt.totalInstallments != null)
                Text(
                  '${debt.paidInstallments}/${debt.totalInstallments} pagas',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallments(Brightness brightness) {
    final installments = _overview!.installments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'parcelamentos',
          description: 'compras parceladas ainda em andamento',
          brightness: brightness,
        ),
        if (installments.isEmpty)
          _emptySection(
            icon: AppIcons.calendar,
            title: 'nenhum parcelamento ativo',
            description: 'compras parceladas aparecerão aqui',
            brightness: brightness,
          )
        else
          _responsiveCards(
            installments.map((item) => _installmentCard(item, brightness)).toList(),
          ),
      ],
    );
  }

  Widget _installmentCard(WalletInstallment item, Brightness brightness) {
    final paid = item.installmentsCount - item.remainingInstallments;
    final progress = item.installmentsCount > 0
        ? (paid / item.installmentsCount).clamp(0.0, 1.0)
        : 0.0;
    final purple = AppColors.primaryPurple(brightness);
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
    final border = AppColors.border(brightness);

    return _baseCard(
      brightness: brightness,
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon: AppIcons.calendar, color: purple),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(
                        context,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: primaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.cardName,
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        color: secondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'restante',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: secondaryText,
                    ),
                  ),
                  Text(
                    _money(item.remainingAmount),
                    style: AppTypography.money(
                      context,
                      fontSize: 13,
                      color: primaryText,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: border.withValues(alpha: .45),
              valueColor: AlwaysStoppedAnimation<Color>(purple),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            children: [
              Expanded(
                child: Text(
                  '$paid de ${item.installmentsCount} parcelas concluídas',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
              ),
              if (item.nextDueDate != null)
                Text(
                  'próxima ${_date(item.nextDueDate)}',
                  style: AppTypography.body(
                    context,
                    fontSize: 10,
                    color: secondaryText,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _baseCard({required Widget child, required Brightness brightness}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }

  Widget _iconBox({required IconData icon, required Color color}) {
    return Container(
      width: 44,
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: color, size: 21),
    );
  }

  Widget _smallInfo({
    required String label,
    required String value,
    required Brightness brightness,
    bool alignRight = false,
    Color? valueColor,
  }) {
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
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: AppTypography.body(
            context,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: valueColor ?? AppColors.primaryText(brightness),
          ),
        ),
      ],
    );
  }

  Widget _emptySection({
    required IconData icon,
    required String title,
    required String description,
    required Brightness brightness,
  }) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
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
          _iconBox(icon: icon, color: purple),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(Brightness brightness) {
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
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
          _iconBox(icon: TablerIcons.alertCircle, color: expense),
          const SizedBox(height: 12),
          Text(
            'não consegui carregar sua carteira',
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: primaryText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: secondaryText,
            ),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _load, child: const Text('tentar novamente')),
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
    final primaryText = AppColors.primaryText(brightness);
    final secondaryText = AppColors.secondaryText(brightness);
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
              Icon(icon, size: 17, color: selected ? purple : secondaryText),
              const SizedBox(width: 6),
              Text(
                label,
                style: AppTypography.label(
                  context,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: selected ? primaryText : secondaryText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
