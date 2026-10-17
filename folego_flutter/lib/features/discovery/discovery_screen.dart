import 'package:flutter/material.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import 'discovery_model.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    super.key,
    required this.identity,
    required this.load,
    required this.onOpen,
    this.pendingOnly = false,
  });
  final String identity;
  final Future<DiscoveryData> Function() load;
  final Future<void> Function(DiscoveryEntry) onOpen;
  final bool pendingOnly;
  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  final _query = TextEditingController();
  DiscoveryData? _data;
  DiscoveryKind? _kind;
  bool _loading = true;
  bool _failed = false;
  bool _opening = false;
  int _generation = 0;
  int _visible = 40;
  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void didUpdateWidget(covariant DiscoveryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.identity != widget.identity) {
      _query.clear();
      _kind = null;
      _data = null;
      _refresh();
    }
  }

  @override
  void dispose() {
    _generation++;
    _query.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _failed = false;
      _data = null;
    });
    try {
      final data = await widget.load();
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = data;
        _loading = false;
        _visible = 40;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _failed = true;
        _loading = false;
      });
    }
  }

  Future<void> _open(DiscoveryEntry entry) async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await widget.onOpen(entry);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível abrir. Tente novamente.'),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _refresh();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pendingOnly;
    final entries = pending
        ? _data?.pending ?? const <DiscoveryEntry>[]
        : _data?.entries ?? const <DiscoveryEntry>[];
    final results = searchDiscovery(entries, _query.text, kind: _kind);
    final kinds = entries.map((entry) => entry.kind).toSet();
    return Scaffold(
      appBar: AppBar(
        title: Text(pending ? 'pendências' : 'buscar no Fôlego'),
        actions: [
          IconButton(
            tooltip: 'atualizar',
            onPressed: _loading ? null : _refresh,
            icon: const Icon(AppIcons.refresh),
          ),
        ],
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: FinancialPrivacy.hidden,
        builder: (context, hidden, _) => Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  pending
                      ? 'o que precisa da sua atenção'
                      : 'encontre sem trocar de tela',
                  style: AppTypography.section(context, fontSize: 22),
                ),
                const SizedBox(height: 8),
                Text(
                  pending
                      ? 'Agenda: últimos 30 dias e próximos 7. Até 500 categorias a revisar e uma amostra dos retornos recentes da planilha; confira antes de agir.'
                      : 'Todo o histórico de lançamentos, contas e cartões deste espaço. Agenda: últimos 30 dias e próximos 30. Busque também por categoria.',
                ),
                if (_data?.sources.isNotEmpty ?? false)
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('fontes e atualização'),
                    subtitle: const Text(
                      'Consulta ao Fôlego; não confirma saldo bancário em tempo real.',
                    ),
                    children: [
                      for (final source in _data!.sources)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            source.confirmed
                                ? Icons.check_circle_outline
                                : Icons.cloud_off_outlined,
                          ),
                          title: Text(source.name),
                          subtitle: Text(
                            '${source.confirmed ? 'consulta concluída' : 'consulta falhou'} · ${source.checkedAt.hour.toString().padLeft(2, '0')}:${source.checkedAt.minute.toString().padLeft(2, '0')}${source.note == null ? '' : '\n${source.note}'}',
                          ),
                        ),
                    ],
                  ),
                const SizedBox(height: 20),
                TextField(
                  controller: _query,
                  decoration: InputDecoration(
                    labelText: pending
                        ? 'filtrar pendências'
                        : 'o que você procura?',
                    prefixIcon: const Icon(AppIcons.search),
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'limpar busca',
                            onPressed: () => setState(() {
                              _query.clear();
                              _visible = 40;
                            }),
                            icon: const Icon(AppIcons.close),
                          ),
                  ),
                  onChanged: (_) => setState(() => _visible = 40),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ChoiceChip(
                      label: const Text('tudo'),
                      selected: _kind == null,
                      onSelected: (_) => setState(() {
                        _kind = null;
                        _visible = 40;
                      }),
                    ),
                    for (final kind in kinds)
                      ChoiceChip(
                        label: Text(
                          entries.firstWhere((e) => e.kind == kind).kindLabel,
                        ),
                        selected: _kind == kind,
                        onSelected: (_) => setState(() {
                          _kind = kind;
                          _visible = 40;
                        }),
                      ),
                  ],
                ),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.all(36),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                if (_failed) ...[
                  const Text('Não foi possível consultar os dados.'),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('tentar novamente'),
                  ),
                ],
                if (_data?.unavailable.isNotEmpty ?? false)
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.border(Theme.of(context).brightness),
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'consulta incompleta',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Não foi possível consultar: ${_data!.unavailable.join(', ')}. Os resultados abaixo são parciais.',
                        ),
                        TextButton(
                          onPressed: _refresh,
                          child: const Text('tentar novamente'),
                        ),
                      ],
                    ),
                  ),
                if (!_loading && !_failed) ...[
                  const SizedBox(height: 12),
                  Text(
                    '${results.length} ${pending ? (results.length == 1 ? 'item para conferir' : 'itens para conferir') : (results.length == 1 ? 'resultado' : 'resultados')}',
                  ),
                  if (results.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 30),
                      child: Text(
                        _query.text.isNotEmpty || _kind != null
                            ? 'Nenhum resultado com este filtro. Tente outro termo.'
                            : pending
                            ? 'Nenhuma pendência encontrada nas fontes consultadas.'
                            : 'Ainda não há registros para buscar.',
                      ),
                    ),
                  for (final entry in results.take(_visible))
                    Card(
                      margin: const EdgeInsets.only(top: 10),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        title: Text(entry.title),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(entry.subtitle),
                            if (entry.amount != null)
                              Text(
                                Formatters.money(entry.amount),
                                style: AppTypography.money(
                                  context,
                                  fontSize: 16,
                                ),
                              ),
                          ],
                        ),
                        trailing: const Icon(AppIcons.forward, size: 18),
                        onTap: _opening ? null : () => _open(entry),
                      ),
                    ),
                  if (results.length > _visible)
                    TextButton(
                      onPressed: () => setState(() => _visible += 40),
                      child: const Text('mostrar mais resultados'),
                    ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
