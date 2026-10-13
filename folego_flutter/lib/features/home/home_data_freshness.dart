import 'package:flutter/material.dart';

/// This reports a successful Fôlego read, not a Google Sheets sync.
String homeDataFreshnessLabel(
  DateTime? lastLoadedAt, {
  required bool failed,
  bool loading = false,
}) {
  if (failed) {
    return lastLoadedAt == null
        ? 'não foi possível consultar seus dados'
        : 'mostrando dados anteriores · atualização falhou';
  }
  if (loading) return 'consultando dados do Fôlego…';
  if (lastLoadedAt == null) return 'aguardando consulta ao Fôlego';

  final local = lastLoadedAt.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return 'Fôlego consultado às $hour:$minute';
}

class HomeDataFreshness extends StatelessWidget {
  const HomeDataFreshness({
    super.key,
    required this.lastLoadedAt,
    required this.failed,
    required this.loading,
    required this.onRefresh,
  });

  final DateTime? lastLoadedAt;
  final bool failed;
  final bool loading;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = failed ? theme.colorScheme.error : theme.colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: Row(
        children: [
          Icon(
            failed ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
            color: color,
            size: 15,
            semanticLabel: failed ? 'consulta falhou' : 'consulta realizada',
          ),
          const SizedBox(width: 7),
          Expanded(
            child: Tooltip(
              message: 'A consulta ao Fôlego não confirma que a planilha Google já sincronizou.',
              child: Text(
                homeDataFreshnessLabel(
                  lastLoadedAt,
                  failed: failed,
                  loading: loading,
                ),
                key: const ValueKey('home-data-freshness'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(color: color),
              ),
            ),
          ),
          if (failed)
            TextButton(
              onPressed: loading ? null : onRefresh,
              child: const Text('tentar novamente'),
            ),
        ],
      ),
    );
  }
}
