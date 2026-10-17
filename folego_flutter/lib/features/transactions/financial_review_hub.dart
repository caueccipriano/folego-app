import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/financial_privacy.dart';
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
  List<CategoryItem> _categories = const [];
  List<TransactionItem> _history = const [];
  int _epoch = 0;

  @override
  void initState() {
    super.initState();
    _tab = widget.initialTab.clamp(0, 2);
    _refresh();
  }

  @override
  void didUpdateWidget(covariant FinancialReviewHub oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _search.clear();
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
            .from('financial_events').select('id,description,amount')
            .eq('space_id', space).inFilter('id', eventIds));
      final purchases = purchaseIds.isEmpty ? <Map<String, dynamic>>[] :
          List<Map<String, dynamic>>.from(await client
            .from('card_purchases')
            .select('id,event_id,description,total_amount')
            .eq('space_id', space).inFilter('id', purchaseIds));
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
        note['event_id'] = purchase ? found?['event_id'] :
            (found == null ? null : note['target_id']);
        note['amount'] = found?[purchase ? 'total_amount' : 'amount'];
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
      return [
        for (final c in captures) {...c, 'kind': 'capture'},
        for (final e in pending) {...e, 'kind': 'classification'},
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

  Future<void> _openPending(Map<String, dynamic> row) async {
    if (row['kind'] == 'capture') {
      await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CaptureReviewScreen(
          repository: widget.repository, spaceId: widget.spaceId,
          captureId: row['id'].toString(),
        ),
      ));
    } else {
      await showModalBottomSheet<bool>(
        context: context, useSafeArea: true, isScrollControlled: true,
        builder: (_) => FractionallySizedBox(
          heightFactor: .92,
          child: TransactionClassificationInbox(
            repository: widget.repository, spaceId: widget.spaceId,
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
              title: Text('sugestão: ' + suggestion.category.breadcrumb),
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
    if (selected == null || !mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('confirmar a categoria?'),
        content: Text('Trocar Outros por ' + selected.breadcrumb +
          '. O valor e o saldo não serão modificados.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false),
              child: const Text('cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true),
              child: const Text('confirmar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await widget.repository.classifyFinancialEvent(
        spaceId: widget.spaceId,
        eventId: row['id'].toString(),
        categoryId: selected.id,
      );
      if (mounted) _refresh();
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não consegui salvar. Tente novamente.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('organizar meu dinheiro')),
    body: Column(children: [
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (var i = 0; i < 3; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: ChoiceChip(
                label: Text(const ['comentários', 'pendências', 'Outros'][i]),
                selected: _tab == i,
                onSelected: (_) => _selectTab(i),
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
          if (snapshot.hasError) return Center(
            child: TextButton(
              onPressed: _refresh,
              child: const Text('Não consegui consultar. Tentar novamente'),
            ),
          );
          if (!snapshot.hasData) return const Center(
            child: CircularProgressIndicator());
          final q = _search.text.trim().toLowerCase();
          final all = snapshot.data!;
          final rows = _tab != 0 ? all : all.where((n) =>
              q.isEmpty || (n['content']?.toString() ?? '').toLowerCase().contains(q)
              || (n['title']?.toString() ?? '').toLowerCase().contains(q)).toList();
          return RefreshIndicator(
            onRefresh: () async { _refresh(); await _future; },
            child: ListView(children: [
              ListTile(
                title: Text(_tab == 0 ? 'Meus comentários' :
                    _tab == 1 ? 'Pendências financeiras' : 'organizar Outros'),
                subtitle: Text(_tab == 0
                  ? 'Compras, lançamentos e faturas · até 300 notas recentes.'
                  : _tab == 1
                  ? 'Ler uma notificação não resolve um comprovante ou lançamento.'
                  : 'Até 200 despesas. Sugestões só com evidência; toda alteração requer confirmação.'),
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
                          : 'categoria pendente')
                      : 'toque para revisar a categoria';
                    return ListTile(
                      key: ValueKey('financial-review-' + row['id'].toString()),
                      title: Text(title),
                      subtitle: Text(subtitle, maxLines: 3,
                          overflow: TextOverflow.ellipsis),
                      trailing: raw == null ? const Icon(Icons.chevron_right)
                          : Text(Formatters.money(raw)),
                      onTap: () => _tab == 0
                        ? _openNote(row)
                        : _tab == 1 ? _openPending(row) : _reviewOther(row),
                    );
                  },
                ),
            ]),
          );
        },
      )),
    ]),
  );
}
