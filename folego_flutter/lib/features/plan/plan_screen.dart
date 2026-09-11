import 'package:flutter/material.dart';

import '../../data/models/budget_overview_item.dart';
import '../../data/repositories/folego_repository.dart';

class PlanScreen extends StatefulWidget {
  const PlanScreen({
    super.key,
    required this.repository,
    required this.spaceId,
  });

  final FolegoRepository repository;
  final String spaceId;

  @override
  State<PlanScreen> createState() => _PlanScreenState();
}

class _PlanScreenState extends State<PlanScreen> {
  static const _purple = Color(0xFF6C3BF0);
  static const _lime = Color(0xFFC6F135);

  late DateTime _month;

  bool _loading = true;
  String? _error;

  List<BudgetOverviewItem> _items = [];

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _month = DateTime(now.year, now.month);

    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final items = await widget.repository.getBudgetOverview(
        spaceId: widget.spaceId,
        periodMonth: _month,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _items = items;
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

  Future<void> _changeMonth(int delta) async {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });

    await _load();
  }

  double get _totalPlanned {
    return _items.fold(0.0, (total, item) => total + item.plannedAmount);
  }

  double get _totalActual {
    return _items.fold(0.0, (total, item) => total + item.actualAmount);
  }

  double get _totalRemaining {
    return _totalPlanned - _totalActual;
  }

  int get _budgetedCount {
    return _items.where((item) => item.hasBudget).length;
  }

  String _monthLabel(DateTime date) {
    const months = [
      'Janeiro',
      'Fevereiro',
      'Março',
      'Abril',
      'Maio',
      'Junho',
      'Julho',
      'Agosto',
      'Setembro',
      'Outubro',
      'Novembro',
      'Dezembro',
    ];

    return '${months[date.month - 1]} ${date.year}';
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
      final end = (i + 3 < reversed.length) ? i + 3 : reversed.length;

      groups.add(reversed.sublist(i, end).reversed.join());
    }

    final formatted = groups.reversed.join('.');

    return '${negative ? '-' : ''}'
        'R\$ $formatted,$decimal';
  }

  double? _parseMoney(String text) {
    var normalized = text.trim().replaceAll(RegExp(r'[^0-9,.\-]'), '');

    if (normalized.isEmpty) {
      return null;
    }

    if (normalized.contains(',')) {
      normalized = normalized.replaceAll('.', '').replaceAll(',', '.');
    }

    return double.tryParse(normalized);
  }

  Color _categoryColor(String? hex) {
    if (hex == null || hex.trim().isEmpty) {
      return _purple;
    }

    var value = hex.replaceAll('#', '').trim();

    if (value.length == 6) {
      value = 'FF$value';
    }

    final parsed = int.tryParse(value, radix: 16);

    if (parsed == null) {
      return _purple;
    }

    return Color(parsed);
  }

  Color _progressColor(BudgetOverviewItem item) {
    if (item.isOverBudget || item.status == 'critical') {
      return const Color(0xFFD9534F);
    }

    if (item.status == 'warning') {
      return const Color(0xFFE89A3C);
    }

    return _purple;
  }

  String _statusLabel(BudgetOverviewItem item) {
    if (!item.hasBudget) {
      return 'Sem limite';
    }

    if (item.isOverBudget) {
      return 'Acima do plano';
    }

    switch (item.status) {
      case 'critical':
        return 'Quase no limite';

      case 'warning':
        return 'Atenção';

      default:
        return 'Dentro do plano';
    }
  }

  Future<void> _editBudget(BudgetOverviewItem item) async {
    final controller = TextEditingController(
      text: item.plannedAmount > 0
          ? item.plannedAmount.toStringAsFixed(2).replaceAll('.', ',')
          : '',
    );

    String? validationError;

    final newAmount = await showModalBottomSheet<double>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (innerContext, setSheetState) {
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                20,
                20,
                MediaQuery.of(innerContext).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 42,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).dividerColor,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),

                  Text(
                    'Planejar ${item.categoryName}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),

                  const SizedBox(height: 6),

                  Text(
                    'Quanto você quer separar '
                    'para essa categoria neste mês?',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: .60),
                    ),
                  ),

                  const SizedBox(height: 22),

                  TextField(
                    controller: controller,
                    autofocus: true,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: 'Limite mensal',
                      prefixText: 'R\$ ',
                      errorText: validationError,
                      border: const OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  if (item.actualAmount > 0)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Você já gastou '
                        '${_money(item.actualAmount)} '
                        'nessa categoria em '
                        '${_monthLabel(_month)}.',
                      ),
                    ),

                  const SizedBox(height: 22),

                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final amount = _parseMoney(controller.text);

                        if (amount == null || amount < 0) {
                          setSheetState(() {
                            validationError = 'Digite um valor válido.';
                          });

                          return;
                        }

                        Navigator.of(innerContext).pop(amount);
                      },
                      child: const Padding(
                        padding: EdgeInsets.symmetric(vertical: 14),
                        child: Text('Salvar planejamento'),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    controller.dispose();

    if (newAmount == null || !mounted) {
      return;
    }

    try {
      await widget.repository.setBudgetItem(
        spaceId: widget.spaceId,
        periodMonth: _month,
        categoryId: item.categoryId,
        plannedAmount: newAmount,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            newAmount == 0
                ? 'Limite de ${item.categoryName} removido.'
                : '${item.categoryName} planejado em '
                      '${_money(newAmount)}.',
          ),
        ),
      );

      await _load();
    } catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Não consegui salvar: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Center(
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
                        padding: EdgeInsets.symmetric(vertical: 80),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (_error != null)
                      _buildError()
                    else ...[
                      _buildSummary(),

                      const SizedBox(height: 28),

                      _buildCategoriesHeader(),

                      const SizedBox(height: 12),

                      if (_items.isEmpty)
                        _buildEmpty()
                      else
                        ..._items.map(_buildCategory),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
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
                'Plano',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),

            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Theme.of(context).dividerColor.withValues(alpha: .30),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Mês anterior',
                    onPressed: () => _changeMonth(-1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  IconButton(
                    tooltip: 'Próximo mês',
                    onPressed: () => _changeMonth(1),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 5),

        Text(
          'Organize o mês sem transformar '
          'sua vida em uma planilha.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(
              context,
            ).colorScheme.onSurface.withValues(alpha: .60),
          ),
        ),

        const SizedBox(height: 18),

        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _lime.withValues(alpha: .18),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18),
              const SizedBox(width: 8),
              Text(
                _monthLabel(_month),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary() {
    final remaining = _totalRemaining;

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
            'Seu plano do mês',
            style: TextStyle(
              color: Colors.white.withValues(alpha: .74),
              fontWeight: FontWeight.w600,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            remaining >= 0
                ? _money(remaining)
                : '${_money(remaining.abs())} acima do plano',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 4),

          Text(
            remaining >= 0
                ? 'ainda disponíveis no orçamento'
                : 'precisam ser compensados no mês',
            style: TextStyle(color: Colors.white.withValues(alpha: .75)),
          ),

          const SizedBox(height: 22),

          Row(
            children: [
              Expanded(child: _summaryMetric('Planejado', _totalPlanned)),
              const SizedBox(width: 10),
              Expanded(child: _summaryMetric('Realizado', _totalActual)),
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
                  Icons.category_outlined,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$_budgetedCount '
                    '${_budgetedCount == 1 ? 'categoria planejada' : 'categorias planejadas'}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
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

  Widget _summaryMetric(String label, double value) {
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
              color: Colors.white.withValues(alpha: .72),
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
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoriesHeader() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Categorias',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                'Toque em uma categoria para definir o limite.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: .55),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCategory(BudgetOverviewItem item) {
    final categoryColor = _categoryColor(item.colorHex);

    final progressColor = _progressColor(item);

    final percentage = (item.usageRatio * 100).round();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _editBudget(item),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: Theme.of(context).dividerColor.withValues(alpha: .28),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: .13),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        item.essential
                            ? Icons.home_work_outlined
                            : Icons.category_outlined,
                        color: categoryColor,
                        size: 21,
                      ),
                    ),

                    const SizedBox(width: 12),

                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.categoryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            _statusLabel(item),
                            style: TextStyle(
                              fontSize: 12,
                              color: progressColor,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          item.hasBudget
                              ? _money(item.plannedAmount)
                              : 'Definir',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                        if (item.hasBudget)
                          Text(
                            'limite',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                      ],
                    ),

                    const SizedBox(width: 4),

                    const Icon(Icons.chevron_right_rounded, size: 20),
                  ],
                ),

                if (item.hasBudget || item.hasActivity) ...[
                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Gasto ${_money(item.actualAmount)}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ),
                      if (item.hasBudget)
                        Text(
                          '$percentage%',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                    ],
                  ),

                  if (item.hasBudget) ...[
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(99),
                      child: LinearProgressIndicator(
                        value: item.progress,
                        minHeight: 7,
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.surfaceContainerHighest,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          progressColor,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.isOverBudget
                                ? '${_money(item.actualAmount - item.plannedAmount)} acima'
                                : '${_money(item.remainingAmount)} restantes',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
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
            'Não consegui carregar seu planejamento.',
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

  Widget _buildEmpty() {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Column(
        children: [
          Icon(Icons.account_balance_wallet_outlined, size: 42),
          SizedBox(height: 12),
          Text(
            'Nenhuma categoria encontrada.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}
