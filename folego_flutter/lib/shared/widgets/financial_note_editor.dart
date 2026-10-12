import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/repositories/folego_repository.dart';

/// Uses the existing session and space policies. No ledger writes or offline cache.
class FinancialNoteEditor extends StatefulWidget {
  const FinancialNoteEditor({super.key, required this.repository,
    required this.spaceId, required this.targetType, required this.targetId,
    this.existingOnly = false});
  final FolegoRepository repository;
  final String spaceId, targetType, targetId;
  final bool existingOnly;
  @override
  State<FinancialNoteEditor> createState() => _FinancialNoteEditorState();
}

class _FinancialNoteEditorState extends State<FinancialNoteEditor> {
  final _text = TextEditingController();
  int _revision = 0;
  int _generation = 0;
  bool _busy = true, _editing = false, _loaded = false;
  String? _error;
  late String? _user;
  StreamSubscription<String?>? _session;

  @override
  void initState() { super.initState(); _watchSession(); _load(); }
  void _watchSession() {
    _session?.cancel();
    _session = widget.repository.commentsSessionChanges.listen((user) {
      if (mounted && user != _user) {
        ++_generation;
        setState(() { _user = null; _text.clear(); _loaded = false; _editing = false; });
      }
    });
  }
  @override
  void didUpdateWidget(covariant FinancialNoteEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId || oldWidget.targetId != widget.targetId ||
        oldWidget.targetType != widget.targetType || oldWidget.repository != widget.repository) {
      _text.clear(); _loaded = false; _editing = false; _load();
      _watchSession();
    }
  }
  bool _current(int generation, String? user) => mounted &&
    generation == _generation && user != null &&
    widget.repository.commentsUserId == user;
  Future<void> _load({bool preserveDraft = false}) async {
    final generation = ++_generation;
    final user = widget.repository.commentsUserId;
    _user = user;
    setState(() { _busy = true; _error = null; });
    try {
      final note = await widget.repository.getFinancialNote(spaceId: widget.spaceId,
        targetType: widget.targetType, targetId: widget.targetId);
      if (!_current(generation, user)) return;
      setState(() {
        _revision = (note?['revision'] as num?)?.toInt() ?? 0;
        if (!preserveDraft) _text.text = note?['content'] as String? ?? '';
        _loaded = true; _busy = false;
        if (preserveDraft) _error = 'Versão atual: ${note?['content'] ?? 'sem comentário'}. Seu rascunho continua no campo; confira antes de salvar.';
      });
    } catch (_) {
      if (!_current(generation, user)) return;
      setState(() { _busy = false; _error = 'Não foi possível ler o comentário. Tente novamente.'; });
    }
  }
  Future<void> _save() async {
    if (_user == null || !_loaded) return;
    final generation = _generation, user = _user;
    final content = _text.text;
    setState(() { _busy = true; _error = null; });
    try {
      final note = await widget.repository.saveFinancialNote(spaceId: widget.spaceId,
        targetType: widget.targetType, targetId: widget.targetId, content: content,
        revision: _revision, userId: user!);
      if (!_current(generation, user)) return;
      setState(() { _revision = (note['revision'] as num).toInt();
        _text.text = note['content'] as String; _editing = false; _busy = false; });
    } catch (_) {
      if (!_current(generation, user)) return;
      setState(() { _busy = false; _error = 'Não foi possível salvar. Pode haver uma versão mais recente. Seu texto foi preservado; confira a versão atual antes de tentar novamente.'; });
    }
  }
  @override
  void dispose() { ++_generation; _session?.cancel(); _text.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if (widget.repository.commentsUserId != _user || _user == null) return const SizedBox.shrink();
    if (widget.existingOnly && _loaded && _revision == 0) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (_busy) const LinearProgressIndicator(),
      if (_editing)
        TextField(controller: _text, enabled: !_busy, minLines: 2, maxLines: 8,
          maxLength: 4000, decoration: const InputDecoration(labelText: 'comentário compartilhado'))
      else Text(_loaded && _text.text.isNotEmpty ? _text.text : 'sem comentário compartilhado'),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!)),
      Wrap(children: [
        if (_loaded) TextButton(onPressed: _busy ? null : () {
          if (_editing) { _save(); } else { setState(() => _editing = true); }
        }, child: Text(_editing ? 'salvar comentário' : 'editar comentário')),
        TextButton(onPressed: _busy ? null : () => _load(preserveDraft: _editing),
          child: Text(_editing ? 'conferir versão atual' : 'atualizar')),
      ]),
    ]);
  }
}

class InvoiceFinancialNotes extends StatefulWidget {
  const InvoiceFinancialNotes({super.key, required this.repository,
    required this.spaceId, required this.cardId});
  final FolegoRepository repository;
  final String spaceId, cardId;
  @override
  State<InvoiceFinancialNotes> createState() => _InvoiceFinancialNotesState();
}
class _InvoiceFinancialNotesState extends State<InvoiceFinancialNotes> {
  late Future<List<Map<String, dynamic>>> _targets;
  @override
  void initState() { super.initState(); _reset(); }
  void _reset() { _targets = widget.repository.listInvoiceNoteTargets(
    spaceId: widget.spaceId, cardId: widget.cardId); }
  @override
  void didUpdateWidget(covariant InvoiceFinancialNotes oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId || oldWidget.cardId != widget.cardId ||
        oldWidget.repository != widget.repository) {
      _reset();
    }
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<List<Map<String, dynamic>>>(
    future: _targets, builder: (context, snapshot) {
      if (snapshot.hasError) return TextButton(onPressed: () => setState(_reset), child: const Text('tentar carregar comentários'));
      if (!snapshot.hasData) return const LinearProgressIndicator();
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        for (final target in snapshot.data!) Padding(padding: const EdgeInsets.only(bottom: 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('fatura · ${target['reference_month']}'),
            FinancialNoteEditor(key: ValueKey('${widget.spaceId}:${target['id']}'),
              repository: widget.repository, spaceId: widget.spaceId,
              targetType: 'invoice_snapshot', targetId: target['id'] as String),
          ])),
      ]);
    });
}
