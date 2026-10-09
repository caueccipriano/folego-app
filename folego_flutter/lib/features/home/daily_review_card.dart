import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/financial_space.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
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
  final ValueNotifier<int> _revision = ValueNotifier(0);
  bool _busy = false;
  bool _movements = false;
  bool _commitments = false;
  bool _noMovements = false;
  String? _error;
  int get _pending => (_state?['pending_count'] as num?)?.toInt() ?? 0;
  bool get _complete => (_state?['review'] as Map?)?['completed_at'] != null;

  void _refreshUi(VoidCallback action) {
    if (!mounted) return;
    setState(action);
    _revision.value++;
  }

  @override
  void dispose() {
    _revision.dispose();
    super.dispose();
  }

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
      _refreshUi(() {
        _state = state;
        _movements = review?['movements_checked'] == true;
        _commitments = review?['commitments_checked'] == true;
        _noMovements = review?['no_movements'] == true;
        _error = null;
      });
    } catch (_) {
      if (mounted && widget.space.id == spaceId) {
        _refreshUi(
          () => _error = 'Não foi possível carregar sua revisão. Toque para tentar novamente.',
        );
      }
    }
  }

  Future<void> _save({bool complete = false, bool snooze = false}) async {
    if (_busy) return;
    _refreshUi(() => _busy = true);
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
      if (mounted && (complete || snooze)) {
        Navigator.of(context).pop();
        if (snooze) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Revisão adiada por 30 minutos.')),
          );
        }
      }
    } catch (_) {
      if (mounted) {
        _refreshUi(
          () => _error = 'Não foi possível salvar. Confira as pendências e tente novamente.',
        );
      }
    } finally {
      if (mounted) _refreshUi(() => _busy = false);
    }
  }

  Future<void> _classify() async {
    _refreshUi(() => _busy = true);
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
        _refreshUi(
          () =>
              _error = 'Não foi possível abrir as pendências. Tente novamente.',
        );
      }
    } finally {
      if (mounted) _refreshUi(() => _busy = false);
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
      _refreshUi(() => _noMovements = false);
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
      _refreshUi(() => _commitments = true);
      await _save();
    }
  }

  Future<void> _openReview() async {
    final brightness = Theme.of(context).brightness;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.background(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadii.sheet)),
      ),
      builder: (_) => FractionallySizedBox(
        heightFactor: .86,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ValueListenableBuilder<int>(
              valueListenable: _revision,
              builder: (context, tick, child) => _buildReviewSheet(context),
            ),
          ),
        ),
      ),
    );
    if (!mounted) return;
    await _load();
  }

  Widget _buildReviewSheet(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final days = ((_state?['completed_days'] as List?) ?? const <dynamic>[])
        .map((date) => date.toString()).toSet();
    final today = DateTime.tryParse(_state?['today']?.toString() ?? '');
    final pace = _state?['spending_pace'] as Map?;
    final canFinish = !_busy && _state != null && _movements && _commitments;

    return SafeArea(
      top: false,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 12, 15),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _complete ? 'check-in concluído' : 'seu check-in',
                        style: AppTypography.section(context, fontSize: 20, color: primary),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'pequenos passos para cuidar do seu dinheiro',
                        style: AppTypography.body(context, fontSize: 12, color: secondary),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'fechar revisão',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(AppIcons.close, color: secondary),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    days.length.toString() + '/7 dias revisados',
                    style: AppTypography.label(
                      context, color: purple, fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (today != null)
                    Row(
                      children: List.generate(7, (i) {
                        final date = today.subtract(Duration(days: 6 - i));
                        final key = date.year.toString() + '-' +
                            date.month.toString().padLeft(2, '0') + '-' +
                            date.day.toString().padLeft(2, '0');
                        final done = days.contains(key);
                        return Expanded(
                          child: Column(
                            children: [
                              Container(
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 3),
                                decoration: BoxDecoration(
                                  color: done ? purple : border,
                                  borderRadius: BorderRadius.circular(AppRadii.pill),
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                date.day.toString(),
                                style: AppTypography.label(
                                  context,
                                  color: done ? purple : secondary,
                                  fontWeight: done ? FontWeight.w700 : FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ),
                  const SizedBox(height: 20),
                  if (_state == null && _error == null)
                    const LinearProgressIndicator()
                  else if (_complete)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: surface, border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Text(
                        'feito por hoje ✓ · volte amanhã para continuar seu hábito.',
                        style: AppTypography.body(context, fontSize: 13, color: primary),
                      ),
                    )
                  else if (_state != null) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'o essencial de hoje',
                            style: AppTypography.section(context, fontSize: 15, color: primary),
                          ),
                        ),
                        Text(
                          ((_movements ? 1 : 0) + (_commitments ? 1 : 0)).toString() + ' de 2',
                          style: AppTypography.label(context, color: secondary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      decoration: BoxDecoration(
                        color: surface, border: Border.all(color: border),
                        borderRadius: BorderRadius.circular(AppRadii.card),
                      ),
                      child: Column(
                        children: [
                          _ReviewTask(
                            checked: _movements,
                            busy: _busy,
                            title: 'conferir meus movimentos',
                            subtitle: 'veja se ficou algum gasto de fora',
                            onTap: () {
                              _refreshUi(() {
                                _movements = !_movements;
                                if (!_movements) _noMovements = false;
                              });
                              _save();
                            },
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(51, 0, 8, 8),
                            child: Wrap(
                              spacing: 0,
                              children: [
                                TextButton(
                                  onPressed: _busy ? null : _register,
                                  child: const Text('registrar gasto'),
                                ),
                                TextButton(
                                  onPressed: _busy ? null : () {
                                    _refreshUi(() {
                                      _noMovements = true;
                                      _movements = true;
                                    });
                                    _save();
                                  },
                                  child: Text(
                                    _noMovements ? 'sem movimentos ✓' : 'não tive movimentos',
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Divider(height: 1, indent: 14, endIndent: 14, color: border),
                          _ReviewTask(
                            checked: _commitments,
                            busy: _busy,
                            title: 'conferir próximas contas',
                            subtitle: 'evite surpresas antes de receber',
                            onTap: () {
                              _refreshUi(() => _commitments = !_commitments);
                              _save();
                            },
                          ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(51, 0, 8, 8),
                              child: TextButton(
                                onPressed: _busy ? null : _upcoming,
                                child: const Text('ver próximas contas'),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_pending > 0) ...[
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Icon(AppIcons.categoryUnclassified, color: purple, size: 19),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '$_pending lançamentos para organizar',
                              style: AppTypography.body(
                                context, fontSize: 12, color: primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: _busy ? null : _classify,
                            child: const Text('resolver 5'),
                          ),
                        ],
                      ),
                      Text(
                        'vá aos poucos — isso não trava o seu check-in.',
                        style: AppTypography.body(context, fontSize: 11, color: secondary),
                      ),
                    ],
                    if (pace != null) ...[
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(AppIcons.chartLine, color: purple, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              dailyReviewPaceMessage(pace),
                              style: AppTypography.body(context, fontSize: 12, color: secondary),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (today?.weekday == DateTime.sunday) ...[
                      const SizedBox(height: 12),
                      Text(
                        'domingo: confira também as contas da semana.',
                        style: AppTypography.body(context, fontSize: 12, color: secondary),
                      ),
                    ],
                  ],
                  if (_error != null)
                    TextButton.icon(
                      onPressed: _load,
                      icon: const Icon(AppIcons.refresh, size: 17),
                      label: Text(_error!),
                    ),
                ],
              ),
            ),
          ),
          if (!_complete && _state != null) ...[
            Divider(height: 1, color: border),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 50,
                    child: FilledButton(
                      key: const ValueKey('daily-review-finish'),
                      onPressed: canFinish ? () => _save(complete: true) : null,
                      style: FilledButton.styleFrom(
                        backgroundColor: purple,
                        foregroundColor: AppColors.iconOnPurpleLight,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(AppRadii.control),
                        ),
                      ),
                      child: const Text('concluir check-in'),
                    ),
                  ),
                  TextButton(
                    onPressed: _busy ? null : () => _save(snooze: true),
                    child: const Text('lembrar daqui a 30 minutos'),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DailyReviewPrompt(
      complete: _complete,
      pending: _pending,
      days: (_state?['completed_days'] as List?)?.length ?? 0,
      pace: _state?['spending_pace'] as Map?,
      error: _error,
      loading: _state == null && _error == null,
      onTap: _openReview,
    );
  }
}

String dailyReviewPaceMessage(Map pace) {
  switch (pace['status']) {
    case 'at_risk':
      final average = (pace['average_per_day'] as num?)?.toDouble() ?? 0;
      final limit = (pace['daily_limit'] as num?)?.toDouble() ?? 0;
      return 'média de ' + Formatters.money(average) + '/dia na última semana; '
          'limite de ' + Formatters.money(limit) + '/dia. confira seu plano.';
    case 'review_needed':
      return 'classificar alguns gastos ajuda a conhecer seu ritmo.';
    case 'income_needed':
      return 'cadastre o próximo recebimento para avaliar seu ritmo.';
    case 'insufficient_history':
      return 'registre gastos por alguns dias para conhecer seu ritmo.';
    default:
      return 'seu ritmo está dentro do limite atual até receber.';
  }
}

class DailyReviewPrompt extends StatelessWidget {
  const DailyReviewPrompt({
    super.key, required this.complete, required this.pending,
    required this.days, required this.loading, required this.onTap,
    this.pace, this.error,
  });

  final bool complete;
  final int pending;
  final int days;
  final Map? pace;
  final bool loading;
  final String? error;
  final VoidCallback onTap;

  String get subtitle {
    if (error != null) return 'toque para tentar novamente';
    if (loading) return 'organizando seu dia…';
    if (complete) return 'feito por hoje · $days/7 dias revisados';
    if (pace?['status'] == 'at_risk') return 'seu ritmo merece atenção';
    if (pending > 0) return '$pending lançamentos para organizar, aos poucos';
    return 'dois minutos para manter tudo em dia';
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final border = AppColors.border(brightness);
    return Material(
      key: const ValueKey('home-daily-review-prompt'),
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.control),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: border))),
          child: Row(
            children: [
              Container(
                width: 36, height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: purple.withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  complete ? AppIcons.check : AppIcons.calendar,
                  color: purple, size: 18,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      complete ? 'check-in concluído' : 'seu check-in',
                      style: AppTypography.body(
                        context, fontSize: 13, fontWeight: FontWeight.w700, color: primary,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: AppTypography.body(context, fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                complete ? 'ver' : 'revisar',
                style: AppTypography.button(context, fontSize: 12, color: purple),
              ),
              const SizedBox(width: 4),
              Icon(AppIcons.chevronRight, color: purple, size: 17),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReviewTask extends StatelessWidget {
  const _ReviewTask({
    required this.checked, required this.busy,
    required this.title, required this.subtitle, required this.onTap,
  });

  final bool checked;
  final bool busy;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final purple = AppColors.primaryPurple(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    return Semantics(
      button: true, checked: checked, label: title,
      child: InkWell(
        onTap: busy ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 13, 12, 7),
          child: Row(
            children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: checked ? purple : Colors.transparent,
                  border: Border.all(color: checked ? purple : border, width: 1.5),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: checked
                    ? const Icon(AppIcons.check, color: AppColors.iconOnPurpleLight, size: 17)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.body(
                        context, fontSize: 12, color: primary, fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTypography.body(context, fontSize: 11, color: secondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
