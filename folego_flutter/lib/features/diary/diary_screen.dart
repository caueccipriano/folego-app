import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/layout/app_content_container.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/theme/category_visuals.dart';
import '../../core/theme/reflection_visuals.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/transaction_reflection.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_diary.dart';
import '../../shared/widgets/category_icon_badge.dart';
import '../transactions/transactions_screen.dart';
import 'reflection_form_sheet.dart';

class DiaryScreen extends StatefulWidget {
  const DiaryScreen({
    super.key,
    required this.repository,
    required this.spaceId,
    this.active = true,
  });

  final FolegoRepository repository;
  final String spaceId;
  final bool active;

  @override
  State<DiaryScreen> createState() => _DiaryScreenState();
}

class _DiaryScreenState extends State<DiaryScreen> {
  late DateTime _month;
  List<DiaryEntry> _entries = const [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _month = DateTime(now.year, now.month);
    _load();
  }

  @override
  void didUpdateWidget(covariant DiaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) _load(silent: true);
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final entries = await widget.repository.getDiaryEntries(
        spaceId: widget.spaceId,
        periodMonth: _month,
      );
      if (!mounted) return;
      setState(() {
        _entries = entries;
        _loading = false;
        _error = null;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _changeMonth(int delta) async {
    setState(() => _month = DateTime(_month.year, _month.month + delta));
    await _load();
  }

  Future<void> _openTransactions() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TransactionsScreen(repository: widget.repository),
      ),
    );
    if (mounted) await _load(silent: true);
  }

  Future<void> _reflect(DiaryEntry entry) async {
    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    final saved = compact
        ? await showModalBottomSheet<bool>(
            context: context,
            useSafeArea: true,
            isScrollControlled: true,
            backgroundColor: Colors.transparent,
            builder: (_) => FractionallySizedBox(
              heightFactor: .82,
              child: ReflectionFormSheet(
                repository: widget.repository,
                spaceId: widget.spaceId,
                entry: entry,
              ),
            ),
          )
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: ReflectionFormSheet(
                  repository: widget.repository,
                  spaceId: widget.spaceId,
                  entry: entry,
                ),
              ),
            ),
          );
    if (saved == true && mounted) await _load(silent: true);
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final layout = AppBreakpoints.of(context);
    final summary = DiarySummary.fromEntries(_entries);
    final timeline = reflectedTimeline(_entries);
    final pending = pendingReflectionEntries(_entries, limit: 4);
    final expanded = layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;

    return ColoredBox(
      color: AppColors.background(brightness),
      child: SafeArea(
        child: AppContentContainer.dashboard(
          fillHeight: true,
          child: RefreshIndicator(
            onRefresh: _load,
            child: _loading
                ? const ListView(
                    physics: AlwaysScrollableScrollPhysics(),
                    children: [SizedBox(height: 280), Center(child: CircularProgressIndicator())],
                  )
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.fromLTRB(
                      0,
                      24,
                      0,
                      MediaQuery.paddingOf(context).bottom + 140,
                    ),
                    children: [
                      _header(brightness),
                      const SizedBox(height: 22),
                      if (_error != null)
                        _errorCard(brightness)
                      else if (expanded)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  _summaryCard(summary, brightness),
                                  const SizedBox(height: 18),
                                  _pendingSection(pending, brightness),
                                ],
                              ),
                            ),
                            const SizedBox(width: 24),
                            Expanded(
                              flex: 7,
                              child: _timelineSection(timeline, pending, brightness),
                            ),
                          ],
                        )
                      else ...[
                        _summaryCard(summary, brightness),
                        const SizedBox(height: 18),
                        _timelineSection(timeline, pending, brightness),
                        const SizedBox(height: 18),
                        _pendingSection(pending, brightness),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _header(Brightness brightness) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'diário',
                style: AppTypography.display(
                  context,
                  fontSize: 28,
                  color: AppColors.primaryText(brightness),
                ),
              ),
            ),
            TextButton.icon(
              onPressed: _openTransactions,
              icon: const Icon(AppIcons.transactions, size: 18),
              label: const Text('ver lançamentos'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'como você tem se relacionado com seus gastos?',
          style: AppTypography.body(
            context,
            fontSize: 12,
            color: AppColors.secondaryText(brightness),
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.surface(brightness),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border(brightness)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'mês anterior',
                  onPressed: () => _changeMonth(-1),
                  icon: const Icon(AppIcons.chevronLeft, size: 19),
                ),
                Text(
                  _monthLabel(_month),
                  style: AppTypography.body(
                    context,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  tooltip: 'próximo mês',
                  onPressed: () => _changeMonth(1),
                  icon: const Icon(AppIcons.chevronRight, size: 19),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryCard(DiarySummary summary, Brightness brightness) {
    return _card(
      brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('seu mês', style: AppTypography.section(context, fontSize: 17)),
          const SizedBox(height: 4),
          Text(
            'distribuição dos gastos que você já refletiu',
            style: AppTypography.body(
              context,
              fontSize: 11,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: SizedBox(
              width: 188,
              height: 188,
              child: CustomPaint(
                painter: _DiaryDonutPainter(summary: summary, brightness: brightness),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        summary.totalReflected <= 0
                            ? 'seu mês'
                            : Formatters.money(summary.totalReflected),
                        textAlign: TextAlign.center,
                        style: AppTypography.money(
                          context,
                          fontSize: summary.totalReflected <= 0 ? 15 : 17,
                          color: AppColors.primaryText(brightness),
                        ),
                      ),
                      if (summary.totalReflected > 0)
                        Text(
                          'refletido',
                          style: AppTypography.label(
                            context,
                            fontSize: 9,
                            color: AppColors.secondaryText(brightness),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 18),
          ...ReflectionType.values.map(
            (type) => Padding(
              padding: const EdgeInsets.only(bottom: 9),
              child: _legendRow(type, summary, brightness),
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: AppColors.background(brightness).withValues(alpha: .55),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              summary.insight,
              style: AppTypography.body(
                context,
                fontSize: 12,
                color: AppColors.primaryText(brightness),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendRow(
    ReflectionType type,
    DiarySummary summary,
    Brightness brightness,
  ) {
    final color = ReflectionVisuals.foreground(type, brightness);
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            type.label,
            style: AppTypography.body(context, fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          '${(summary.percentage(type) * 100).round()}%',
          style: AppTypography.label(
            context,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _timelineSection(
    List<DiaryEntry> timeline,
    List<DiaryEntry> pending,
    Brightness brightness,
  ) {
    if (timeline.isEmpty) {
      return _card(
        brightness,
        child: Column(
          children: [
            const Icon(AppIcons.journal, size: 34),
            const SizedBox(height: 14),
            Text(
              'seu diário começa quando você olha para um gasto e entende o que ele significou pra você.',
              textAlign: TextAlign.center,
              style: AppTypography.body(context, fontSize: 13),
            ),
            if (pending.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'há ${pending.length} gasto${pending.length == 1 ? '' : 's'} aqui embaixo para começar.',
                textAlign: TextAlign.center,
                style: AppTypography.body(
                  context,
                  fontSize: 11,
                  color: AppColors.secondaryText(brightness),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _card(
      brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('suas reflexões', style: AppTypography.section(context, fontSize: 17)),
          const SizedBox(height: 14),
          ...timeline.map((entry) => _timelineItem(entry, brightness)),
        ],
      ),
    );
  }

  Widget _timelineItem(DiaryEntry entry, Brightness brightness) {
    final reflection = entry.reflection!;
    final family = entry.categoryName ?? 'A classificar';
    final categoryColor = CategoryVisuals.colorFor(
      category: family,
      brightness: brightness,
    );
    final categoryIcon = CategoryVisuals.iconFor(category: family);
    final reflectionColor = ReflectionVisuals.foreground(reflection.type, brightness);

    return InkWell(
      onTap: () => _reflect(entry),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryIconBadge(
              icon: categoryIcon,
              color: categoryColor,
              size: 42,
              iconSize: 20,
              radius: 14,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          entry.displayDescription,
                          style: AppTypography.body(
                            context,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        Formatters.money(entry.amount.abs()),
                        style: AppTypography.money(
                          context,
                          fontSize: 11,
                          color: AppColors.secondaryText(brightness),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${entry.displayCategory} · ${_dateLabel(entry.occurredAt)}',
                    style: AppTypography.label(
                      context,
                      fontSize: 9,
                      color: AppColors.secondaryText(brightness),
                    ),
                  ),
                  const SizedBox(height: 7),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: ReflectionVisuals.background(reflection.type, brightness),
                      borderRadius: BorderRadius.circular(99),
                      border: Border.all(
                        color: ReflectionVisuals.border(reflection.type, brightness),
                      ),
                    ),
                    child: Text(
                      reflection.type.label,
                      style: AppTypography.label(
                        context,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: reflectionColor,
                      ),
                    ),
                  ),
                  if (reflection.note != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      '“${reflection.note}”',
                      style: AppTypography.body(
                        context,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                        color: AppColors.secondaryText(brightness),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pendingSection(List<DiaryEntry> pending, Brightness brightness) {
    if (pending.isEmpty) return const SizedBox.shrink();
    return _card(
      brightness,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('para refletir', style: AppTypography.section(context, fontSize: 16)),
          const SizedBox(height: 4),
          Text(
            'alguns gastos recentes sem reflexão',
            style: AppTypography.body(
              context,
              fontSize: 10,
              color: AppColors.secondaryText(brightness),
            ),
          ),
          const SizedBox(height: 12),
          ...pending.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.displayDescription,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.body(
                            context,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${entry.displayCategory} · ${_dateLabel(entry.occurredAt)} · ${Formatters.money(entry.amount.abs())}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTypography.label(
                            context,
                            fontSize: 9,
                            color: AppColors.secondaryText(brightness),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  TextButton(
                    onPressed: () => _reflect(entry),
                    child: const Text('refletir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _errorCard(Brightness brightness) {
    return _card(
      brightness,
      child: Column(
        children: [
          const Icon(AppIcons.warning, size: 30),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('tentar novamente')),
        ],
      ),
    );
  }

  Widget _card(Brightness brightness, {required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }

  String _monthLabel(DateTime value) {
    const months = [
      'janeiro',
      'fevereiro',
      'março',
      'abril',
      'maio',
      'junho',
      'julho',
      'agosto',
      'setembro',
      'outubro',
      'novembro',
      'dezembro',
    ];
    return '${months[value.month - 1]} ${value.year}';
  }

  String _dateLabel(DateTime value) {
    final day = value.day.toString().padLeft(2, '0');
    final month = value.month.toString().padLeft(2, '0');
    return '$day/$month';
  }
}

class _DiaryDonutPainter extends CustomPainter {
  const _DiaryDonutPainter({required this.summary, required this.brightness});

  final DiarySummary summary;
  final Brightness brightness;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2 - 12;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final track = Paint()
      ..color = AppColors.border(brightness).withValues(alpha: .65)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, track);

    if (summary.totalReflected <= 0) return;
    var start = -math.pi / 2;
    const gap = .035;
    for (final type in ReflectionType.values) {
      final ratio = summary.percentage(type);
      if (ratio <= 0) continue;
      final sweep = math.pi * 2 * ratio;
      final paint = Paint()
        ..color = ReflectionVisuals.foreground(type, brightness)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 18
        ..strokeCap = StrokeCap.round;
      canvas.drawArc(rect, start + gap, math.max(0, sweep - gap * 2), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DiaryDonutPainter oldDelegate) {
    return oldDelegate.summary.totalReflected != summary.totalReflected ||
        oldDelegate.summary.amounts != summary.amounts ||
        oldDelegate.brightness != brightness;
  }
}
