import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Server-side RPC checks every request against private.folego_admins.
class FolegoAdminScreen extends StatefulWidget {
  const FolegoAdminScreen({super.key, required this.client});
  final SupabaseClient client;
  @override
  State<FolegoAdminScreen> createState() => _FolegoAdminScreenState();
}

class _FolegoAdminScreenState extends State<FolegoAdminScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.client.rpc('folego_admin_dashboard');
      if (!mounted) return;
      setState(() { _data = Map<String, dynamic>.from(result as Map); _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'não foi possível carregar o painel. confira seu acesso.'; _loading = false; });
    }
  }

  List<Map<String, dynamic>> _rows(String key) {
    final value = _data?[key];
    if (value is! List) return const [];
    return value.whereType<Map>().map((row) => Map<String, dynamic>.from(row)).toList();
  }

  String _date(dynamic value) {
    if (value is! String) return 'nunca';
    final parsed = DateTime.tryParse(value);
    return parsed == null ? 'não informado' : DateFormat('dd/MM/yyyy').format(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final metrics = _data?['metrics'] is Map
        ? Map<String, dynamic>.from(_data!['metrics'] as Map)
        : <String, dynamic>{};
    return Scaffold(
      appBar: AppBar(title: const Text('Fôlego Admin')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            const Text('Acesso administrativo. Nenhum dado financeiro dos usuários é exibido.'),
            const SizedBox(height: 16),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_error != null)
              Card(child: Padding(padding: const EdgeInsets.all(16), child: Text(_error!)))
            else ...[
              Wrap(spacing: 8, runSpacing: 8, children: [
                _metric('cadastrados', metrics['registered']),
                _metric('confirmados', metrics['confirmed']),
                _metric('login em 30 dias', metrics['logged_in_30d']),
                _metric('premium vitalício', metrics['lifetime_premium']),
                _metric('configuração financeira concluída', metrics['completed_intro']),
                _metric('com conta cadastrada', metrics['users_with_account']),
                _metric('com lançamentos', metrics['users_with_transactions']),
                _metric('lançamentos nos últimos 30 dias', metrics['users_with_transactions_30d']),
                _metric('sugestões', metrics['feedback_count']),
                _metric('Asaas sandbox', metrics['sandbox_subscription_records']),
                _metric('Asaas produção (registros)', metrics['production_subscription_records']),
              ]),
              const SizedBox(height: 24),
              Text('usuários', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_rows('users').isEmpty) const Text('nenhum usuário encontrado'),
              for (final user in _rows('users'))
                Card(child: ListTile(
                  leading: Icon(user['lifetime_premium'] == true
                      ? Icons.workspace_premium_outlined : Icons.person_outline),
                  title: Text((user['name'] ?? '').toString()),
                  subtitle: Text(
                    '${user['email'] ?? ''}\n'
                    'cadastro ${_date(user['created_at'])} • último login ${_date(user['last_login'])}\n'
                    '${user['email_confirmed'] == true ? 'confirmado' : 'pendente'}'
                    '${user['lifetime_premium'] == true ? ' • premium vitalício' : ''}',
                  ),
                  isThreeLine: true,
                )),
              const SizedBox(height: 24),
              Text('sugestões recebidas', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              if (_rows('feedback').isEmpty) const Text('nenhuma sugestão até agora'),
              for (final item in _rows('feedback'))
                Card(child: ListTile(
                  title: Text('${item['kind'] ?? ''} • ${item['name'] ?? ''}'),
                  subtitle: Text('${item['message'] ?? ''}\n${_date(item['created_at'])}'),
                  isThreeLine: true,
                )),
              const SizedBox(height: 20),
              const Text(
                'Login recente não comprova uso ativo. Registros de assinatura não são faturamento recebido.',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _metric(String label, dynamic value) => SizedBox(
    width: 160,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text((value ?? '—').toString(), style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ]),
    )),
  );
}
