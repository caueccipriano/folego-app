import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';

/// Read-only panel. Privileged data remains protected by folego_admin_dashboard.
class FolegoAdminScreen extends StatefulWidget {
  const FolegoAdminScreen({
    super.key,
    required this.client,
    this.loadDashboard,
  });

  final SupabaseClient client;

  /// Synthetic data seam for UI tests; live app always calls the guarded RPC.
  final Future<dynamic> Function()? loadDashboard;

  @override
  State<FolegoAdminScreen> createState() => _FolegoAdminScreenState();
}

class _FolegoAdminScreenState extends State<FolegoAdminScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  int _tab = 0;
  String _search = '';
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = widget.loadDashboard == null
          ? await widget.client.rpc('folego_admin_dashboard')
          : await widget.loadDashboard!();
      if (!mounted || generation != _generation) return;
      if (value is! Map) throw const FormatException('Invalid dashboard data');
      setState(() {
        _data = Map<String, dynamic>.from(value);
        _loading = false;
      });
    } catch (_) {
      if (!mounted || generation != _generation) return;
      setState(() {
        _data = null;
        _loading = false;
        _error = 'não foi possível consultar o painel. confira sua sessão.';
      });
    }
  }

  Map<String, dynamic> get _metrics {
    final value = _data?['metrics'];
    return value is Map ? Map<String, dynamic>.from(value) : {};
  }

  List<Map<String, dynamic>> _rows(String key) {
    final value = _data?[key];
    return value is List
        ? value
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : const [];
  }

  String _number(dynamic value) =>
      value is num ? NumberFormat.decimalPattern('pt_BR').format(value) : '—';

  String _date(dynamic value) {
    final d = value is String ? DateTime.tryParse(value) : null;
    return d == null
        ? 'não registrado'
        : DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final textColor = AppColors.primaryText(brightness);
    final muted = AppColors.secondaryText(brightness);
    return Scaffold(
      appBar: AppBar(
        title: const Text('administração'),
        actions: [
          IconButton(
            key: const ValueKey('admin-refresh'),
            tooltip: 'atualizar',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1000),
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                key: const ValueKey('folego-admin-dashboard'),
                padding: const EdgeInsets.fromLTRB(18, 20, 18, 92),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  Text(
                    'seu produto, de perto.',
                    style: AppTypography.display(
                      context,
                      fontSize: 29,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'pessoas, desempenho e sugestões.',
                    style: AppTypography.body(
                      context,
                      fontSize: 12,
                      color: muted,
                    ),
                  ),
                  const SizedBox(height: 13),
                  const _Info(
                    'área privada · nenhum saldo ou gasto individual é exibido.',
                  ),
                  const SizedBox(height: 22),
                  if (_loading && _data == null)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(36),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_error != null)
                    _Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_error!),
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _load,
                            child: const Text('tentar novamente'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    _Kpis(metrics: _metrics),
                    const SizedBox(height: 20),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _tabButton(
                            0,
                            'visão geral',
                            Icons.space_dashboard_outlined,
                          ),
                          const SizedBox(width: 7),
                          _tabButton(1, 'usuários', Icons.people_outline),
                          const SizedBox(width: 7),
                          _tabButton(2, 'sugestões', Icons.chat_bubble_outline),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_tab == 0)
                      _overview()
                    else if (_tab == 1)
                      _users()
                    else
                      _feedback(),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int tab, String label, IconData icon) => ChoiceChip(
    key: ValueKey('admin-tab-$tab'),
    avatar: Icon(icon, size: 17),
    label: Text(label),
    selected: _tab == tab,
    onSelected: (_) => setState(() => _tab = tab),
  );

  Widget _overview() {
    final m = _metrics;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading(
          'jornada dos usuários',
          'do cadastro ao primeiro lançamento',
        ),
        const SizedBox(height: 10),
        _Surface(
          child: Column(
            children: [
              _CountLine('e-mails confirmados', _number(m['confirmed'])),
              _CountLine(
                'configuração inicial concluída',
                _number(m['completed_intro']),
              ),
              _CountLine(
                'com conta cadastrada',
                _number(m['users_with_account']),
              ),
              _CountLine(
                'já fizeram lançamentos',
                _number(m['users_with_transactions']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const _Heading(
          'acesso premium e cobrança',
          'situação dos registros, não faturamento',
        ),
        const SizedBox(height: 10),
        _Surface(
          child: Column(
            children: [
              _CountLine(
                'premium vitalício · cortesia',
                _number(m['lifetime_premium']),
              ),
              _CountLine(
                'Asaas sandbox · registros',
                _number(m['sandbox_subscription_records']),
              ),
              _CountLine(
                'Asaas produção · registros',
                _number(m['production_subscription_records']),
              ),
            ],
          ),
        ),
        const SizedBox(height: 13),
        const _Info(
          'login recente não comprova uso ativo. '
          'registros de assinatura não comprovam pagamento recebido.',
        ),
      ],
    );
  }

  Widget _users() {
    final users = _rows('users');
    final q = _search.trim().toLowerCase();
    final filtered = users
        .where(
          (u) =>
              ("${(u['name'] ?? '').toString()} ${(u['email'] ?? '').toString()}")
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Heading('pessoas no fôlego', '${users.length} cadastros'),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('admin-user-search'),
          onChanged: (value) => setState(() => _search = value),
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'buscar nome ou e-mail',
          ),
        ),
        const SizedBox(height: 13),
        if (filtered.isEmpty)
          const _Surface(child: Text('nenhuma pessoa encontrada.'))
        else if (MediaQuery.sizeOf(context).width >= 900)
          _Surface(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 24,
                horizontalMargin: 0,
                dataRowMinHeight: 72,
                dataRowMaxHeight: 96,
                columns: const [
                  DataColumn(label: Text('pessoa')),
                  DataColumn(label: Text('acesso')),
                  DataColumn(label: Text('cadastro')),
                  DataColumn(label: Text('último login')),
                ],
                rows: [
                  for (final user in filtered)
                    DataRow(
                      cells: [
                        DataCell(
                          SizedBox(
                            width: 270,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  (user['name'] ?? 'pessoa sem nome')
                                      .toString(),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.body(
                                    context,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  (user['email'] ?? '').toString(),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTypography.label(context),
                                ),
                              ],
                            ),
                          ),
                        ),
                        DataCell(
                          SizedBox(
                            width: 150,
                            child: Text(
                              user['lifetime_premium'] == true
                                  ? 'premium vitalício'
                                  : user['email_confirmed'] == true
                                  ? 'confirmado'
                                  : 'e-mail pendente',
                            ),
                          ),
                        ),
                        DataCell(Text(_date(user['created_at']))),
                        DataCell(Text(_date(user['last_login']))),
                      ],
                    ),
                ],
              ),
            ),
          )
        else
          for (final user in filtered) ...[
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_circle_outlined, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (user['name'] ?? '').toString().trim().isEmpty
                                  ? 'pessoa sem nome'
                                  : (user['name'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.section(
                                context,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              (user['email'] ?? '').toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: AppTypography.body(context, fontSize: 11),
                            ),
                          ],
                        ),
                      ),
                      if (user['lifetime_premium'] == true)
                        const Tooltip(
                          message: 'premium vitalício',
                          child: Icon(Icons.workspace_premium_outlined),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 7,
                    children: [
                      _Pill(
                        user['email_confirmed'] == true
                            ? 'confirmado'
                            : 'e-mail pendente',
                      ),
                      if (user['lifetime_premium'] == true)
                        const _Pill('premium cortesia'),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'cadastro ${_date(user['created_at'])} · login ${_date(user['last_login'])}',
                    style: AppTypography.body(context, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
      ],
    );
  }

  Widget _feedback() {
    final items = _rows('feedback');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _Heading('o que estão dizendo', 'até 50 mensagens mais recentes'),
        const SizedBox(height: 12),
        if (items.isEmpty)
          const _Surface(child: Text('nenhuma sugestão recebida ainda.'))
        else
          for (final item in items) ...[
            _Surface(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    children: [
                      _Pill(switch ((item['kind'] ?? '').toString()) {
                        'idea' => 'ideia',
                        'bug' => 'problema',
                        'praise' => 'elogio',
                        _ => 'mensagem',
                      }),
                      Text(
                        _date(item['created_at']),
                        style: AppTypography.body(context, fontSize: 11),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  SelectableText(
                    (item['message'] ?? '').toString(),
                    style: AppTypography.body(context, fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    (item['name'] ?? '').toString().trim().isEmpty
                        ? 'usuário do fôlego'
                        : (item['name'] ?? '').toString(),
                    style: AppTypography.label(context, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 9),
          ],
      ],
    );
  }
}

class _Kpis extends StatelessWidget {
  const _Kpis({required this.metrics});
  final Map<String, dynamic> metrics;

  @override
  Widget build(BuildContext context) {
    final items = [
      ('cadastrados', metrics['registered'], Icons.people_alt_outlined),
      ('logins · 30d', metrics['logged_in_30d'], Icons.login_rounded),
      (
        'lançaram · 30d',
        metrics['users_with_transactions_30d'],
        Icons.receipt_long_outlined,
      ),
      ('sugestões', metrics['feedback_count'], Icons.chat_bubble_outline),
    ];
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth > 700 ? 4 : 2;
        const gap = 10.0;
        final width = (constraints.maxWidth - (columns - 1) * gap) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final item in items)
              SizedBox(
                width: width,
                child: _Surface(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        item.$3,
                        size: 18,
                        color: AppColors.primaryPurple(
                          Theme.of(context).brightness,
                        ),
                      ),
                      const SizedBox(height: 13),
                      Text(
                        item.$2 is num
                            ? NumberFormat.decimalPattern('pt_BR')
                                  .format(item.$2)
                            : '—',
                        style: AppTypography.money(context, fontSize: 29),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.$1,
                        maxLines: 2,
                        style: AppTypography.body(context, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _Surface extends StatelessWidget {
  const _Surface({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface(brightness),
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: AppColors.border(brightness)),
      ),
      child: child,
    );
  }
}

class _Info extends StatelessWidget {
  const _Info(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(
        Icons.lock_outline_rounded,
        size: 16,
        color: AppColors.primaryPurple(Theme.of(context).brightness),
      ),
      const SizedBox(width: 7),
      Expanded(
        child: Text(label, style: AppTypography.body(context, fontSize: 11)),
      ),
    ],
  );
}

class _Heading extends StatelessWidget {
  const _Heading(this.title, this.description);
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: AppTypography.section(context, fontSize: 17)),
      const SizedBox(height: 3),
      Text(description, style: AppTypography.body(context, fontSize: 11)),
    ],
  );
}

class _CountLine extends StatelessWidget {
  const _CountLine(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Expanded(
          child: Text(label, style: AppTypography.body(context, fontSize: 12)),
        ),
        const SizedBox(width: 8),
        Text(value, style: AppTypography.section(context, fontSize: 15)),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(100),
      color: AppColors.primaryPurple(Theme.of(context).brightness)
          .withValues(alpha: .09),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      child: Text(label, style: AppTypography.label(context, fontSize: 11)),
    ),
  );
}
