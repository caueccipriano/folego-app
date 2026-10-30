import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/category_item.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../../data/smart_category_suggestion.dart';
import '../../shared/widgets/financial_note_editor.dart';
import '../plan/spending_behavior_screen.dart';
import '../profile/capture_review_screen.dart';
import 'transaction_detail_sheet_v2.dart';
import 'transaction_classification_inbox.dart';
import 'resolver_queue.dart';


String financialNoteMonth(Object? date) {
  final value = DateTime.tryParse(date?.toString() ?? '');
  if (value == null) return '';
  return '${value.year}-${value.month.toString().padLeft(2, '0')}';
}

/// Pure filter used by the comments hub. A missing account is explicitly
/// unknown, never guessed from a card's billing relationship.
bool financialNoteMatchesFilters(
  Map<String, dynamic> note, {
  String query = '',
  String targetType = '',
  String month = '',
  String categoryId = '',
  String accountId = '',
}) {
  final text = [note['content'], note['title'], note['note_category_name'],
      note['note_account_name']].join(' ').toLowerCase();
  return (query.isEmpty || text.contains(query.toLowerCase())) &&
      (targetType.isEmpty || note['target_type'] == targetType) &&
      (month.isEmpty || note['note_month'] == month) &&
      (categoryId.isEmpty || note['note_category_id'] == categoryId) &&
      (accountId.isEmpty || note['note_account_id'] == accountId);
}

/// Read-only queues, with explicit user confirmation for category changes.
/// Notification reads never modify pending financial evidence.
class FinancialReviewHub extends StatefulWidget {
  const FinancialReviewHub({
    super.key, required this.repository, required this.spaceId,
    this.initialTab = 0,
  });
  final FolegoRepository repository;
  final String spaceId;
  final int initialTab;
  @override
  State<FinancialReviewHub> createState() => _FinancialReviewHubState();
}

class _FinancialReviewHubState extends State<FinancialReviewHub> {
  late int _tab;
  late Future<List<Map<String, dynamic>>> _future;
  final _search = TextEditingController();
  String _noteType = '';
  String _noteMonth = '';
  String _noteCategory = '';
  String _noteAccount = '';
  List<CategoryItem> _categories = const [];
  List<TransactionItem> _history = const [];
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, resolverTabIndex);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant FinancialReviewHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _search.clear();
      _noteType = '';
      _noteMonth = '';
      _noteCategory = '';
      _noteAccount = '';
      _categories = const [];
      _history = const [];
      _refresh();
    }
  }

  @override
  void dispose() {
    _epoch++;
    _search.dispose();
    super.dispose();
  }

  void _selectTab(int index) {
    if (_tab == index) return;
    setState(() => _tab = index);
    _refresh();
  }

  void _refresh() {
    final epoch = ++_epoch;
    final space = widget.spaceId;
    setState(() => _future = _load(_tab, space, epoch));
  }

  Future<List<Map<String, dynamic>>> _load(
      int tab, String space, int epoch) async {
    final client = Supabase.instance.client;
    if (client.auth.currentUser == null) {
      throw StateError('Faça login para consultar suas finanças.');
    }
    if (tab == resolverTabIndex) {
      final queues = await Future.wait([
        _load(1, space, epoch),
        _load(2, space, epoch),
      ]);
      return mergeResolverTasks(pending: queues[0], other: queues[1]);
    }
    if (tab == 0) {
      final notes = List<Map<String, dynamic>>.from(await client
          .from('financial_notes')
          .select('id,target_type,target_id,content,last_source,updated_at')
          .eq('space_id', space)
          .order('updated_at', ascending: false).limit(300));
      final eventIds = notes.where((n) => n['target_type'] == 'event')
          .map((n) => n['target_id'].toString()).toSet().toList();
      final purchaseIds = notes.where((n) => n['target_type'] == 'card_purchase')
          .map((n) => n['target_id'].toString()).toSet().toList();
      final events = eventIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('financial_events')
            .select('id,description,amount,category_id,occurred_at')
            .eq('space_id', space).inFilter('id', eventIds));
      final purchases = purchaseIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('card_purchases')
            .select('id,event_id,description,total_amount,category_id,purchase_at,card_id')
            .eq('space_id', space).inFilter('id', purchaseIds));
      // Every lookup is scoped to the selected space and existing RLS.
      final allEventIds = <String>{
        ...eventIds,
        for (final p in purchases)
          if (p['event_id'] != null) p['event_id'].toString(),
      }.toList();
      final impacts = allEventIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('financial_impacts').select('event_id,account_id,dimension')
            .eq('space_id', space).inFilter('event_id', allEventIds));
      final accountIds = impacts.where((i) => i['account_id'] != null)
          .map((i) => i['account_id'].toString()).toSet().toList();
      final accounts = accountIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('accounts').select('id,name')
            .eq('space_id', space).inFilter('id', accountIds));
      final accountNames = {
        for (final a in accounts) a['id'].toString(): a['name'].toString(),
      };
      final accountByEvent = <String, String>{};
      for (final impact in impacts) {
        final eventId = impact['event_id']?.toString();
        final accountId = impact['account_id']?.toString();
        if (eventId != null && accountId != null &&
            impact['dimension'] != 'budget' && accountNames.containsKey(accountId)) {
          accountByEvent.putIfAbsent(eventId, () => accountId);
        }
      }
      final categoryIds = <String>{
        for (final e in events)
          if (e['category_id'] != null) e['category_id'].toString(),
        for (final p in purchases)
          if (p['category_id'] != null) p['category_id'].toString(),
      }.toList();
      final categories = categoryIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('categories').select('id,name')
            .eq('space_id', space).inFilter('id', categoryIds));
      final categoryNames = {
        for (final c in categories) c['id'].toString(): c['name'].toString(),
      };
      final eventMap = {for (final e in events) e['id'].toString(): e};
      final purchaseMap = {for (final p in purchases) p['id'].toString(): p};
      for (final note in notes) {
        final purchase = note['target_type'] == 'card_purchase';
        final found = purchase
            ? purchaseMap[note['target_id'].toString()]
            : eventMap[note['target_id'].toString()];
        note['title'] = found?['description'] ??
            (note['target_type'] == 'invoice_snapshot'
                ? 'comentário da fatura' : 'lançamento antigo');
        note['event_id'] = purchase
            ? (found == null ? null : found['event_id'])
            : (found == null ? null : note['target_id']);
        note['amount'] = found == null ? null :
            found[purchase ? 'total_amount' : 'amount'];
        note['note_date'] = found == null
            ? note['updated_at']
            : found[purchase ? 'purchase_at' : 'occurred_at'];
        final categoryId = found?['category_id']?.toString() ?? '';
        note['note_category_id'] = categoryId;
        note['note_category_name'] = categoryNames[categoryId] ?? 'sem categoria';
        final linkedEvent = note['event_id']?.toString() ?? '';
        final accountId = accountByEvent[linkedEvent] ?? '';
        note['note_account_id'] = accountId;
        note['note_account_name'] = accountNames[accountId] ?? '';
        note['note_month'] = financialNoteMonth(note['note_date']);
      }
      return notes;
    }
    if (tab == 1) {
      final captures = List<Map<String, dynamic>>.from(await client
        .from('financial_capture_inbox')
        .select('id,counterparty,amount,review_reason,occurred_at')
        .eq('space_id', space)
        .eq('review_status', 'needs_review')
        .order('occurred_at', ascending: false).limit(100));
      final pending = List<Map<String, dynamic>>.from(await client
        .from('financial_events')
        .select('id,description,amount,occurred_at')
        .eq('space_id', space).eq('status', 'confirmed')
        .eq('metadata->>needs_classification', 'true')
        .order('occurred_at', ascending: false).limit(100));
      final unclassified = List<Map<String, dynamic>>.from(await client
        .from('financial_events')
        .select('id,description,amount,occurred_at')
        .eq('space_id', space).eq('status', 'confirmed')
        .inFilter('event_type', const [
          'expense', 'card_purchase', 'benefit_expense',
        ])
        .isFilter('behavior_class', null)
        .order('occurred_at', ascending: false).limit(500));
      return [
        for (final c in captures) {...c, 'kind': 'capture'},
        for (final e in pending) {...e, 'kind': 'classification'},
        for (final e in unclassified) {...e, 'kind': 'behavior'},
      ];
    }
    final otherCats = List<Map<String, dynamic>>.from(await client
        .from('categories').select('id').eq('space_id', space)
        .eq('name', 'Outros').eq('kind', 'expense'));
    final otherIds = otherCats.map((c) => c['id'].toString()).toList();
    final events = otherIds.isEmpty ? <Map<String, dynamic>>[] :
        List<Map<String, dynamic>>.from(await client
        .from('financial_events')
        .select('id,description,amount,event_type,occurred_at')
        .eq('space_id', space).eq('status', 'confirmed')
        .inFilter('category_id', otherIds)
        .order('occurred_at', ascending: false).limit(200));
    final categories = await widget.repository.listExpenseCategories(space);
    List<TransactionItem> history = [];
    try {
      history = (await widget.repository.getTransactionsPage(space)).items;
    } catch (_) {
      // No history means no evidence-based suggestions, not a guessed category.
    }
    if (mounted && epoch == _epoch && widget.spaceId == space) {
      _categories = categories;
      _history = history;
    }
    return events;
  }


  Widget _noteFilterControls(List<Map<String, dynamic>> notes) {
    List<DropdownMenuItem<String>> options(
      Map<String, String> values, String emptyLabel,
    ) => [
      DropdownMenuItem(value: '', child: Text(emptyLabel)),
      for (final entry in values.entries)
        DropdownMenuItem(value: entry.key,
          child: Text(entry.value, overflow: TextOverflow.ellipsis)),
    ];
    final months = <String, String>{};
    final categories = <String, String>{};
    final accounts = <String, String>{};
    for (final note in notes) {
      final month = note['note_month']?.toString() ?? '';
      if (month.isNotEmpty) {
        months[month] = '${month.substring(5, 7)}/${month.substring(0, 4)}';
      }
      final cat = note['note_category_id']?.toString() ?? '';
      if (cat.isNotEmpty) {
        categories[cat] = note['note_category_name']?.toString() ?? cat;
      }
      final account = note['note_account_id']?.toString() ?? '';
      if (account.isNotEmpty) {
        accounts[account] = note['note_account_name']?.toString() ?? account;
      }
    }
    final sortedMonths = Map.fromEntries(months.entries.toList()
      ..sort((a, b) => b.key.compareTo(a.key)));
    Widget selector(
      String key, String value, List<DropdownMenuItem<String>> items,
      ValueChanged<String> change,
    ) => SizedBox(
      width: 154,
      child: DropdownButtonFormField<String>(
        key: ValueKey(key),
        initialValue: items.any((item) => item.value == value) ? value : '',
        isExpanded: true,
        decoration: const InputDecoration(isDense: true,
          border: OutlineInputBorder()),
        items: items,
        onChanged: (next) => change(next ?? ''),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, runSpacing: 8, children: [
          selector('comments-type-filter', _noteType, options(const {
            'event': 'lançamento', 'card_purchase': 'compra',
            'invoice_snapshot': 'fatura',
          }, 'todos os tipos'), (v) => setState(() => _noteType = v)),
          selector('comments-month-filter', _noteMonth,
            options(sortedMonths, 'todos os meses'),
            (v) => setState(() => _noteMonth = v)),
          selector('comments-category-filter', _noteCategory,
            options(categories, 'todas categorias'),
            (v) => setState(() => _noteCategory = v)),
          selector('comments-account-filter', _noteAccount,
            options(accounts, 'todas as contas'),
            (v) => setState(() => _noteAccount = v)),
        ]),
        if (_noteType.isNotEmpty || _noteMonth.isNotEmpty ||
            _noteCategory.isNotEmpty || _noteAccount.isNotEmpty ||
            _search.text.isNotEmpty)
          Align(alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => setState(() {
                _noteType = '';
                _noteMonth = '';
                _noteCategory = '';
                _noteAccount = '';
                _search.clear();
              }),
              child: const Text('limpar filtros'),
            )),
      ]),
    );
  }

  Future<void> _openNote(Map<String, dynamic> note) async {
    await showModalBottomSheet<void>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
          16, 18, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
        child: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(note['title']?.toString() ?? 'comentário',
              style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 14),
            FinancialNoteEditor(
              repository: widget.repository, spaceId: widget.spaceId,
              targetType: note['target_type'].toString(),
              targetId: note['target_id'].toString(),
            ),
            if (note['event_id'] != null)
              TextButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('abrir transação'),
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (!mounted) return;
                  await showTransactionDetail(
                    context: context,
                    space: FinancialSpace(
                      id: widget.spaceId, name: 'Minhas finanças'),
                    repository: widget.repository,
                    eventId: note['event_id'].toString(),
                  );
                },
              ),
          ]),
        ),
      ),
    );
    if (mounted) _refresh();
  }

  Future<void> _openResolverTask(Map<String, dynamic> row) async {
    if (row['kind'] == 'other') {
      await _reviewOther(row);
    } else {
      await _openPending(row);
    }
  }

  Widget _resolverTile(Map<String, dynamic> row, {bool featured = false}) {
    final kind = row['kind']?.toString() ?? '';
    final title = resolverTaskLabel(kind);
    final action = resolverTaskAction(kind);
    final description = (kind == 'capture'
        ? row['counterparty']
        : row['description'])?.toString().trim() ?? '';
    final amount = num.tryParse(row['amount']?.toString() ?? '');
    return ValueListenableBuilder<bool>(
      valueListenable: FinancialPrivacy.hidden,
      builder: (context, hidden, _) => ListTile(
        key: ValueKey('resolver-item-$kind-${row['id']}'),
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        leading: Icon(
          switch (kind) {
            'capture' => Icons.receipt_long_outlined,
            'classification' => Icons.sell_outlined,
            'other' => Icons.category_outlined,
            _ => Icons.tune_outlined,
          },
          size: 22,
        ),
        title: Text(title, maxLines: 2,
          overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (description.isNotEmpty)
              Text(hidden ? 'descrição oculta' : description,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            if (amount != null)
              Text(hidden ? FinancialPrivacy.maskMoney() : Formatters.money(amount)),
            if (featured)
              Text(action, style: TextStyle(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w600)),
          ],
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _openResolverTask(row),
      ),
    );
  }

  Widget _resolverSection(List<Map<String, dynamic>> tasks) {
    final scheme = Theme.of(context).colorScheme;
    if (tasks.isEmpty) {
      return Padding(
        key: const ValueKey('resolver-empty'),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 34),
        child: Column(children: [
          Icon(Icons.check_circle_outline, size: 34, color: scheme.primary),
          const SizedBox(height: 10),
          const Text('nada para resolver agora',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17)),
          const SizedBox(height: 5),
          Text('Nenhuma pendência encontrada nas filas consultadas. '
            'Seus registros continuam disponíveis em Movimentos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ]),
      );
    }
    return Padding(
      key: const ValueKey('resolver-center'),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('uma coisa por vez',
            style: TextStyle(fontWeight: FontWeight.w700,
              fontSize: 19, color: scheme.onSurface)),
          const SizedBox(height: 4),
          Text('${tasks.length} pendência(s) nos registros consultados. '
            'Revisar não altera valores automaticamente.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 14),
          Material(
            color: scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(16),
            child: _resolverTile(tasks.first, featured: true),
          ),
          if (tasks.length > 1) ...[
            const SizedBox(height: 12),
            Theme(
              data: Theme.of(context).copyWith(dividerColor: AppColors.transparent),
              child: ExpansionTile(
                key: const ValueKey('resolver-more'),
                tilePadding: const EdgeInsets.symmetric(horizontal: 4),
                initiallyExpanded: false,
                title: Text('outras ${tasks.length - 1} pendências',
                  style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: const Text('abrir somente quando quiser'),
                children: [
                  for (final row in tasks.skip(1)) _resolverTile(row),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openPending(Map<String, dynamic> row) async {
    if (row['kind'] == 'capture') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CaptureReviewScreen(
          repository: widget.repository, spaceId: widget.spaceId,
          captureId: row['id'].toString(),
        ),
      ));
    } else if (row['kind'] == 'behavior') {
      await showTransactionDetail(
        context: context,
        space: FinancialSpace(id: widget.spaceId, name: 'Minhas finanças'),
        repository: widget.repository,
        eventId: row['id'].toString(),
      );
    } else {
      final pending = await widget.repository.listPendingTransactionClassifications(
        widget.spaceId);
      if (!mounted) return;
      await showModalBottomSheet<bool>(
        context: context, useSafeArea: true, isScrollControlled: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .92,
          child: TransactionClassificationInbox(
            repository: widget.repository, spaceId: widget.spaceId,
            initialItems: pending,
          ),
        ),
      );
    }
    if (mounted) _refresh();
  }

  Future<void> _reviewOther(Map<String, dynamic> row) async {
    final suggestion = suggestSmartCategory(
      description: row['description']?.toString() ?? '',
      eventType: row['event_type']?.toString() ?? '',
      history: _history,
      categories: _categories.where((c) => c.name != 'Outros'),
    );
    final choices = _categories.where((c) =>
      c.active && c.isSelectable && c.name != 'Outros' &&
      (c.kind == null || c.kind == 'expense')).toList()
        ..sort((a, b) => a.breadcrumb.compareTo(b.breadcrumb));
    final selected = await showModalBottomSheet<CategoryItem>(
      context: context, isScrollControlled: true, useSafeArea: true,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * .72,
        child: Column(children: [
          const SizedBox(height: 12),
          Text('organizar esta despesa',
              style: Theme.of(ctx).textTheme.titleMedium),
          Padding(padding: const EdgeInsets.all(12),
              child: Text(row['description']?.toString() ?? 'despesa')),
          if (suggestion != null)
            ListTile(
              key: const ValueKey('others-suggested'),
              title: Text('sugestão: ${suggestion.category.breadcrumb}'),
              subtitle: Text(suggestion.reason),
              onTap: () => Navigator.pop(ctx, suggestion.category),
            ),
          const Divider(),
          const Text('ou escolha uma categoria existente'),
          Expanded(child: ListView.builder(
            itemCount: choices.length,
            itemBuilder: (_, i) => ListTile(
              title: Text(choices[i].breadcrumb),
              onTap: () => Navigator.pop(ctx, choices[i]),
            ),
          )),
        ]),
      ),
    );
    if (selected == null || !mounted) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('confirmar a categoria?'),
        content: Text('Trocar Outros por ${selected.breadcrumb}. '
          'O valor e o saldo não serão modificados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await widget.repository.classifyFinancialEvent(
        spaceId: widget.spaceId,
        eventId: row['id'].toString(),
        categoryId: selected.id,
      );
      if (mounted) {
        _refresh();
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Não consegui salvar. Tente novamente.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_tab == resolverTabIndex
      ? 'resolver.' : 'organizar meu dinheiro')),
    body: Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (final tab in const [resolverTabIndex, 0, 1, 2])
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                key: ValueKey('financial-hub-tab-$tab'),
                label: Text(switch (tab) {
                  resolverTabIndex => 'resolver',
                  0 => 'comentários',
                  1 => 'pendências',
                  _ => 'Outros',
                }),
                selected: _tab == tab,
                onSelected: (_) => _selectTab(tab),
              ),
            ),
        ]),
      ),
      if (_tab == 0)
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(
              labelText: 'buscar por palavra no comentário',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
      if (_tab == 1)
        ListTile(
          title: const Text('gastos fixos e variáveis'),
          subtitle: const Text('classificação independente da categoria'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
            builder: (_) => SpendingBehaviorScreen(
              repository: widget.repository, spaceId: widget.spaceId,
              periodMonth: DateTime.now(),
            ),
          )),
        ),
      Expanded(child: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: TextButton(
                onPressed: _refresh,
                child: const Text('Não consegui consultar. Tentar novamente'),
              ),
            );
          }
          // FutureBuilder may retain the previous space's result while a
          // new request is connecting. Never show stale financial records.
          if (snapshot.connectionState != ConnectionState.done ||
              !snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final q = _search.text.trim().toLowerCase();
          final all = snapshot.data!;
          final rows = _tab != 0 ? all : all.where((n) =>
              financialNoteMatchesFilters(n, query: q, targetType: _noteType,
                month: _noteMonth, categoryId: _noteCategory,
                accountId: _noteAccount)).toList();
          return RefreshIndicator(
            onRefresh: () async { _refresh(); await _future; },
            child: ListView(children: [
              if (_tab == resolverTabIndex)
                _resolverSection(rows)
              else ...[
              if (_tab == 0) _noteFilterControls(all),
              ListTile(
                title: Text(_tab == 0 ? 'Meus comentários' :
                    _tab == 1 ? 'Pendências financeiras' : 'organizar Outros'),
                subtitle: Text(_tab == 0
                  ? '${rows.length} de ${all.length} comentários encontrados. '
                    'Compras, lançamentos e faturas.'
                  : _tab == 1
                  ? 'Comprovantes, categorias e gastos sem fixo/variável '
                    'de todos os meses. ${all.length} itens nesta consulta.'
                  : 'Até 200 despesas. Sugestões só com evidência; '
                    'toda alteração requer confirmação.'),
              ),
              if (rows.isEmpty) const ListTile(
                title: Text('nada encontrado nesta consulta')),
              for (final row in rows)
                ValueListenableBuilder<bool>(
                  valueListenable: FinancialPrivacy.hidden,
                  builder: (context, hidden, _) {
                    final raw = num.tryParse(row['amount']?.toString() ?? '');
                    final title = _tab == 0
                      ? row['title']?.toString() ?? 'comentário'
                      : _tab == 1 && row['kind'] == 'capture'
                      ? row['counterparty']?.toString() ?? 'comprovante'
                      : row['description']?.toString() ?? 'lançamento';
                    final subtitle = _tab == 0
                      ? (hidden ? 'comentário oculto' :
                          row['content']?.toString() ?? '')
                      : _tab == 1
                      ? (row['kind'] == 'capture'
                          ? 'comprovante aguardando conciliação'
                          : row['kind'] == 'behavior'
                          ? 'sem tipo fixo/variável · toque para classificar'
                          : 'categoria pendente')
                      : 'toque para revisar a categoria';
                    return ListTile(
                      key: ValueKey('financial-review-${row['id']}'),
                      title: Text(title),
                      subtitle: Text(subtitle, maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      trailing: raw == null ? const Icon(Icons.chevron_right)
                          : Text(hidden
                              ? FinancialPrivacy.maskMoney()
                              : Formatters.money(raw)),
                      onTap: () => _tab == 0
                        ? _openNote(row)
                        : _tab == 1 ? _openPending(row) : _reviewOther(row),
                    );
                  },
                ),
              ],
            ]),
          );
        },
      )),
    ]),
  );
}
