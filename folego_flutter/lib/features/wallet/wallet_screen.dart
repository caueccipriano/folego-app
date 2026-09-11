import 'package:flutter/material.dart';

import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';

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
  static const _purple = Color(0xFF6C3BF0);
  static const _lime = Color(0xFFC6F135);

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

      if (!mounted) {
        return;
      }

      setState(() {
        _overview = overview;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _loading = false;
        _error = error.toString();
      });
    }
  }

  String _money(double value) {
    final negative = value < 0;
    final absolute = value.abs();

    final parts = absolute.toStringAsFixed(2).split('.');
    final integer = parts.first;
    final decimal = parts.last;

    final reversed = integer.split('').reversed.toList();
    final groups = <String>[];

    for (var i = 0; i < reversed.length; i += 3) {
      final end = i + 3 < reversed.length ? i + 3 : reversed.length;

      groups.add(reversed.sublist(i, end).reversed.join());
    }

    final formatted = groups.reversed.join('.');

    return '${negative ? '-' : ''}'
        'R\$ $formatted,$decimal';
  }

  String _date(DateTime? value) {
    if (value == null) {
      return '—';
    }

    return '${value.day.toString().padLeft(2, '0')}/'
        '${value.month.toString().padLeft(2, '0')}/'
        '${value.year}';
  }

  String _accountType(String value) {
    switch (value) {
      case 'checking':
        return 'Conta corrente';

      case 'savings':
        return 'Poupança';

      case 'cash':
        return 'Dinheiro';

      case 'investment':
        return 'Investimento';

      case 'benefit':
        return 'Benefício';

      default:
        return value;
    }
  }

  IconData _accountIcon(String type) {
    switch (type) {
      case 'cash':
        return Icons.payments_outlined;

      case 'investment':
        return Icons.trending_up_rounded;

      case 'benefit':
        return Icons.card_giftcard_rounded;

      default:
        return Icons.account_balance_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: RefreshIndicator(
            onRefresh: _load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(18, 18, 18, 120),
              children: [
                _buildHeader(),

                const SizedBox(height: 22),

                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 100),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_error != null)
                  _buildError()
                else if (_overview != null) ...[
                  _buildSummary(),

                  const SizedBox(height: 26),

                  _buildSelector(),

                  const SizedBox(height: 18),

                  _buildSelectedSection(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Carteira',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Atualizar',
              onPressed: _load,
              icon: const Icon(Icons.refresh_rounded),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          'Tudo que faz parte da sua vida financeira.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .58),
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final summary = _overview!.summary;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF7444F4), Color(0xFF5A22E8)],
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dinheiro disponível',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .74),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 5),

          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(summary.availableCash),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(height: 6),

          Text(
            'O que está disponível nas contas '
            'marcadas para uso.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .70),
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 20),

          Row(
            children: [
              Expanded(
                child: _summaryMetric(
                  label: 'Em contas',
                  value: summary.totalCash,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _summaryMetric(
                  label: 'Faturas',
                  value: summary.totalCardInvoice,
                ),
              ),
            ],
          ),

          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .12),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Saldo restante em dívidas',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: .76),
                      fontSize: 12,
                    ),
                  ),
                ),
                Text(
                  _money(summary.totalDebtRemaining),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryMetric({required String label, required double value}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withValues(alpha: .70),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 5),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              _money(value),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelector() {
    final sections = [
      ('Contas', Icons.account_balance_rounded, _overview!.accounts.length),
      ('Cartões', Icons.credit_card_rounded, _overview!.cards.length),
      ('Dívidas', Icons.receipt_long_rounded, _overview!.debts.length),
      (
        'Parcelas',
        Icons.calendar_view_month_rounded,
        _overview!.installments.length,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(sections.length, (index) {
          final selected = _section == index;

          final section = sections[index];

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              selected: selected,
              onSelected: (_) {
                setState(() {
                  _section = index;
                });
              },
              avatar: Icon(section.$2, size: 18),
              label: Text('${section.$1} ${section.$3}'),
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
        return _buildDebts();

      case 3:
        return _buildInstallments();

      default:
        return const SizedBox();
    }
  }

  Widget _sectionHeader({required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 3),
          Text(
            description,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: .55),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccounts() {
    final accounts = _overview!.accounts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Suas contas',
          description: 'Onde seu dinheiro está hoje.',
        ),

        if (accounts.isEmpty)
          _emptySection(
            icon: Icons.account_balance_outlined,
            title: 'Nenhuma conta cadastrada',
            description: 'Suas contas bancárias aparecerão aqui.',
          )
        else
          ...accounts.map((account) => _accountCard(account)),
      ],
    );
  }

  Widget _accountCard(WalletAccount account) {
    return _baseCard(
      child: Row(
        children: [
          _iconBox(icon: _accountIcon(account.type), color: _purple),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  account.name,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  account.institution ?? _accountType(account.type),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 4),
                Text(
                  account.availableForSpending
                      ? 'Disponível para gastar'
                      : 'Protegido do Fôlego',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: account.availableForSpending
                        ? const Color(0xFF368C45)
                        : _purple,
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
              style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 15),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCards() {
    final cards = _overview!.cards;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Seus cartões',
          description: 'Faturas, limites e vencimentos.',
        ),

        if (cards.isEmpty)
          _emptySection(
            icon: Icons.credit_card_off_rounded,
            title: 'Nenhum cartão cadastrado',
            description: 'Seus cartões de crédito aparecerão aqui.',
          )
        else
          ...cards.map((card) => _cardCard(card)),
      ],
    );
  }

  Widget _cardCard(WalletCard card) {
    final limit = card.effectiveLimit;

    final ratio = limit != null && limit > 0
        ? (card.invoiceBalance / limit).clamp(0.0, 1.0)
        : null;

    return _baseCard(
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon: Icons.credit_card_rounded, color: _purple),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (card.brand != null) card.brand!,
                        if (card.lastFour != null)
                          '•••• ${card.lastFour!.trim()}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Fatura', style: TextStyle(fontSize: 11)),
                  Text(
                    _money(card.invoiceBalance),
                    style: const TextStyle(fontWeight: FontWeight.w900),
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
                backgroundColor: Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest,
                valueColor: const AlwaysStoppedAnimation<Color>(_purple),
              ),
            ),
            const SizedBox(height: 8),
          ],

          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  label: 'Limite disponível',
                  value: card.availableLimit == null
                      ? '—'
                      : _money(card.availableLimit!),
                ),
              ),
              Expanded(
                child: _smallInfo(
                  label: 'Vencimento',
                  value: card.invoiceDueDate != null
                      ? _date(card.invoiceDueDate)
                      : 'Dia ${card.dueDay}',
                  alignRight: true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: Text(
                  'Fecha dia ${card.closingDay}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (limit != null)
                Text(
                  'Limite ${_money(limit)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDebts() {
    final debts = _overview!.debts;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Suas dívidas',
          description: 'Acompanhe o que ainda falta pagar.',
        ),

        if (debts.isEmpty)
          _emptySection(
            icon: Icons.check_circle_outline_rounded,
            title: 'Nenhuma dívida ativa',
            description: 'Quando houver uma dívida ativa, ela aparecerá aqui.',
          )
        else
          ...debts.map((debt) => _debtCard(debt)),
      ],
    );
  }

  Widget _debtCard(WalletDebt debt) {
    final total = debt.originalAmount ?? debt.openingBalance;

    final progress = total > 0
        ? ((total - debt.remainingBalance) / total).clamp(0.0, 1.0)
        : 0.0;

    return _baseCard(
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(
                icon: Icons.receipt_long_rounded,
                color: const Color(0xFFED7A3B),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      debt.name,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    if (debt.creditor != null) ...[
                      const SizedBox(height: 3),
                      Text(
                        debt.creditor!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Falta pagar', style: TextStyle(fontSize: 11)),
                  Text(
                    _money(debt.remainingBalance),
                    style: const TextStyle(fontWeight: FontWeight.w900),
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(_lime),
            ),
          ),

          const SizedBox(height: 10),

          Row(
            children: [
              Expanded(
                child: _smallInfo(
                  label: 'Próxima parcela',
                  value: debt.nextDueDate == null
                      ? '—'
                      : '${_money(debt.nextAmount)} · ${_date(debt.nextDueDate)}',
                ),
              ),
              if (debt.totalInstallments != null)
                Text(
                  '${debt.paidInstallments}/'
                  '${debt.totalInstallments} pagas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInstallments() {
    final installments = _overview!.installments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          title: 'Parcelamentos',
          description: 'Compras parceladas ainda em andamento.',
        ),

        if (installments.isEmpty)
          _emptySection(
            icon: Icons.calendar_month_outlined,
            title: 'Nenhum parcelamento ativo',
            description: 'Compras parceladas aparecerão aqui.',
          )
        else
          ...installments.map((item) => _installmentCard(item)),
      ],
    );
  }

  Widget _installmentCard(WalletInstallment item) {
    final paid = item.installmentsCount - item.remainingInstallments;

    final progress = item.installmentsCount > 0
        ? (paid / item.installmentsCount).clamp(0.0, 1.0)
        : 0.0;

    return _baseCard(
      child: Column(
        children: [
          Row(
            children: [
              _iconBox(icon: Icons.calendar_view_month_rounded, color: _purple),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.description,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      item.cardName,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text('Restante', style: TextStyle(fontSize: 11)),
                  Text(
                    _money(item.remainingAmount),
                    style: const TextStyle(fontWeight: FontWeight.w900),
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
              backgroundColor: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest,
              valueColor: const AlwaysStoppedAnimation<Color>(_purple),
            ),
          ),

          const SizedBox(height: 9),

          Row(
            children: [
              Expanded(
                child: Text(
                  '$paid de '
                  '${item.installmentsCount} parcelas concluídas',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              if (item.nextDueDate != null)
                Text(
                  'Próxima ${_date(item.nextDueDate)}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _baseCard({required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .28),
        ),
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
    bool alignRight = false,
  }) {
    return Column(
      crossAxisAlignment: alignRight
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          textAlign: alignRight ? TextAlign.right : TextAlign.left,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }

  Widget _emptySection({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: Theme.of(context).dividerColor.withValues(alpha: .25),
        ),
      ),
      child: Column(
        children: [
          Icon(icon, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 5),
          Text(
            description,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, size: 40),
          const SizedBox(height: 12),
          const Text(
            'Não consegui carregar sua carteira.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 18),
          FilledButton(onPressed: _load, child: const Text('Tentar novamente')),
        ],
      ),
    );
  }
}
