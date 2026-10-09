import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/financial_space.dart';
import '../../core/utils/formatters.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../transactions/transaction_classification_inbox.dart';
import 'quick_register_sheet.dart';
import 'upcoming_events_screen.dart';

class DailyReviewCard extends StatefulWidget {
  const DailyReviewCard({
    super.key,
    required this.space,
    required this.repository,
    this.refreshToken,
  });
  final FinancialSpace space;
  final FolegoRepository repository;
  final Object? refreshToken;
  @override
  State<DailyReviewCard> createState() => _DailyReviewCardState();
}

class _DailyReviewCardState extends State<DailyReviewCard> {
  Map<String, dynamic>? _state;
  bool _busy = false;
  bool _expanded = false;
  bool _movements = false;
  bool _commitments = false;
  bool _noMovements = false;
  String? _error;
  int get _pending => (_state?['pending_count'] as num?)?.toInt() ?? 0;
  bool get _complete => (_state?['review'] as Map?)?['completed_at'] != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant DailyReviewCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space.id != widget.space.id) {
      _state = null;
      _expanded = false;
      _error = null;
      _movements = false;
      _commitments = false;
      _noMovements = false;
      _load();
    } else if (oldWidget.refreshToken != widget.refreshToken) {
      _load();
    }
  }

  Future<void> _load() async {
    final spaceId = widget.space.id;
    try {
      final response = await Supabase.instance.client.rpc(
        'get_daily_financial_review',
        params: {'p_space_id': spaceId},
      );
      if (!mounted || widget.space.id != spaceId) return;
      final state = Map<String, dynamic>.from(response as Map);
      final review = state['review'] as Map?;
      setState(() {
        _state = state;
        _movements = review?['movements_checked'] == true;
        _commitments = review?['commitments_checked'] == true;
        _noMovements = review?['no_movements'] == true;
        _error = null;
      });
    } catch (_) {
      if (mounted && widget.space.id == spaceId) {
        setState(
          () => _error = 'Não foi possível carregar sua revisão. Toque para tentar novamente.',
        );
      }
    }
  }

  Future<void> _save({bool complete = false, bool snooze = false}) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Supabase.instance.client.rpc(
        'save_daily_financial_review',
        params: {
          'p_space_id': widget.space.id,
          'p_movements_checked': _movements,
          'p_commitments_checked': _commitments,
          'p_no_movements': _noMovements,
          'p_complete': complete,
          'p_snooze': snooze,
        },
      );
      await _load();
      if (mounted && snooze) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Revisão adiada por 30 minutos.')),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Não foi possível salvar. Confira as pendências e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _classify() async {
    setState(() => _busy = true);
    try {
      final items = await widget.repository
          .listPendingTransactionClassifications(widget.space.id);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => TransactionClassificationInbox(
            repository: widget.repository,
            spaceId: widget.space.id,
            initialItems: items,
            batchSize: 5,
          ),
        ),
      );
      await _load();
    } catch (_) {
      if (mounted) {
        setState(
          () =>
              _error = 'Não foi possível abrir as pendências. Tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _register() async {
    final registered = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => QuickRegisterSheet(
        space: widget.space,
        repository: widget.repository,
        initialType: 'expense',
      ),
    );
    if (registered == true && mounted) {
      setState(() => _noMovements = false);
      await _save();
    }
    await _load();
  }

  Future<void> _upcoming() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UpcomingEventsScreen(
          repository: widget.repository,
          spaceId: widget.space.id,
        ),
      ),
    );
    if (mounted) {
      setState(() => _commitments = true);
      await _save();
    }
  }

  @override
  Widget build(BuildContext context) {
    final days = (_state?['completed_days'] as List?) ?? [];
    final pace = _state?['spending_pace'] as Map?;
    final today = DateTime.tryParse(_state?['today']?.toString() ?? '');
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _complete ? 'Revisão de hoje concluída ✓' : 'Sua revisão diária',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '${days.length}/7 dias revisados · seu progresso continua mesmo se perder um dia',
            ),
            if (today != null && (_expanded || _complete))
              Wrap(
                spacing: 4,
                children: List.generate(7, (index) {
                  final date = today.subtract(Duration(days: 6 - index));
                  final key =
                      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                  return Chip(
                    label: Text('${date.day}${days.contains(key) ? ' ✓' : ''}'),
                  );
                }),
              ),
            if (today?.weekday == DateTime.sunday && !_complete)
              const Text(
                'Revisão de domingo: confira também os compromissos da próxima semana.',
              ),
            if (pace != null) ...[
              const SizedBox(height: 8),
              Text(switch (pace['status']) {
                'at_risk' =>
                  'Ritmo em atenção: média de ${Formatters.money((pace['average_per_day'] as num).toDouble())}/dia nos 7 dias completos anteriores. Limite atual: ${Formatters.money((pace['daily_limit'] as num?)?.toDouble() ?? 0)}/dia. Mantendo a média, pode faltar ${Formatters.money((pace['projected_excess'] as num).toDouble())} até receber.',
                'review_needed' => 'Classifique as despesas recentes para avaliar seu ritmo com segurança.',
                'income_needed' =>
                  'Configure o próximo recebimento para avaliar seu ritmo.',
                'insufficient_history' => 'Ritmo: aguardando gastos registrados em pelo menos 3 dias dos últimos 7.',
                _ => 'Ritmo dos últimos 7 dias dentro do limite atual até receber.',
              }),
            ],
            if (_error != null)
              TextButton(onPressed: _load, child: Text(_error!)),
            if (_state == null && _error == null)
              const LinearProgressIndicator(),
            if (_state != null && !_complete && !_expanded) ...[
              Text('$_pending pendências para classificar'),
              FilledButton(
                onPressed: () => setState(() => _expanded = true),
                child: const Text('Começar revisão'),
              ),
            ],
            if (_state != null && !_complete && _expanded) ...[
              const SizedBox(height: 8),
              Text(
                _pending > 0
                    ? '$_pending lançamento(s) para classificar'
                    : 'Classificações em dia ✓',
              ),
              if (_pending > 0)
                FilledButton(
                  onPressed: _busy ? null : _classify,
                  child: const Text('Resolver até 5 pendências'),
                ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conferi os movimentos de hoje'),
                value: _movements,
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _movements = v ?? false);
                        _save();
                      },
              ),
              Wrap(
                spacing: 8,
                children: [
                  TextButton(
                    onPressed: _busy ? null : _register,
                    child: const Text('Registrar gasto'),
                  ),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () {
                            setState(() {
                              _noMovements = true;
                              _movements = true;
                            });
                            _save();
                          },
                    child: Text(
                      _noMovements
                          ? 'Sem movimentações ✓'
                          : 'Hoje não tive movimentações',
                    ),
                  ),
                ],
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Conferi as próximas contas'),
                value: _commitments,
                onChanged: _busy
                    ? null
                    : (v) {
                        setState(() => _commitments = v ?? false);
                        _save();
                      },
              ),
              TextButton(
                onPressed: _busy ? null : _upcoming,
                child: const Text('Ver próximas contas'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilledButton(
                    onPressed:
                        !_busy && _pending == 0 && _movements && _commitments
                        ? () => _save(complete: true)
                        : null,
                    child: const Text('Concluir revisão'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _save(snooze: true),
                    child: const Text('Adiar 30 min'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
