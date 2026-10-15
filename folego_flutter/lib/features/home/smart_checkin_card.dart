import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/privacy/financial_privacy.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/app_radii.dart';
import '../../core/theme/app_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/wallet_overview.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../transactions/transaction_classification_inbox.dart';
import '../wallet/wallet_screen.dart';

/// Runs a read-only daily preflight. Bank-app balances are NOT bank-verified:
/// they reflect the ledger in Supabase until bank data is connected/imported.
class SmartCheckinCard extends StatefulWidget {
  const SmartCheckinCard({
    super.key,
    required this.spaceId,
    required this.repository,
    this.loadReview,
    this.loadWallet,
    this.applyApprovedRules,
  });

  final String spaceId;
  final FolegoRepository repository;
  final Future<Map<String, dynamic>> Function(String spaceId)? loadReview;
  final Future<WalletOverview> Function(String spaceId)? loadWallet;
  final Future<Map<String, dynamic>> Function(String spaceId)?
      applyApprovedRules;

  @override
  State<SmartCheckinCard> createState() => _SmartCheckinCardState();
}

class _SmartCheckinCardState extends State<SmartCheckinCard> {
  int _generation = 0;
  bool _loading = true;
  bool _opening = false;
  int? _pending;
  WalletOverview? _wallet;
  String? _error;
  int _autopilotApplied = 0;
  bool _autopilotUnavailable = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant SmartCheckinCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.spaceId != widget.spaceId) {
      _pending = null;
      _wallet = null;
      _autopilotApplied = 0;
      _autopilotUnavailable = false;
      _load();
    }
  }

  @override
  void dispose() {
    _generation++;
    super.dispose();
  }

  Future<void> _load() async {
    final id = widget.spaceId;
    final generation = ++_generation;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      // An authenticated server RPC, not a browser-side pattern guess.
      // It applies *only* exact, user-approved, historically consistent
      // rules, updates category-only fields atomically, and is idempotent.
      var applied = 0;
      var unavailable = false;
      try {
        if (widget.applyApprovedRules != null) {
          final result = await widget.applyApprovedRules!(id);
          applied = (result['applied'] as num?)?.toInt() ?? 0;
        } else if (widget.loadReview == null && widget.loadWallet == null) {
          final result = await Supabase.instance.client.rpc(
            'autopilot_apply_approved_categories',
            params: {'p_space_id': id},
          );
          applied = (Map<String, dynamic>.from(result as Map)['applied']
                  as num?)
              ?.toInt() ?? 0;
        }
      } catch (_) {
        unavailable = true; // Keep the original read-only review available.
      }
      if (!mounted || widget.spaceId != id || generation != _generation) {
        return;
      }
      final reviewFuture = widget.loadReview != null
          ? widget.loadReview!(id)
          : Supabase.instance.client
              .rpc('get_daily_financial_review', params: {'p_space_id': id})
              .then((value) => Map<String, dynamic>.from(value as Map));
      final walletFuture = widget.loadWallet != null
          ? widget.loadWallet!(id)
          : widget.repository.getWalletOverview(spaceId: id);
      final values = await Future.wait<dynamic>([reviewFuture, walletFuture]);
      if (!mounted || widget.spaceId != id || generation != _generation) {
        return;
      }
      final review = Map<String, dynamic>.from(values[0] as Map);
      setState(() {
        _pending = (review['pending_count'] as num?)?.toInt() ?? 0;
        _wallet = values[1] as WalletOverview;
        _autopilotApplied = applied;
        _autopilotUnavailable = unavailable;
        _loading = false;
      });
    } catch (_) {
      if (!mounted || widget.spaceId != id || generation != _generation) {
        return;
      }
      setState(() {
        _loading = false;
        _error = 'Não foi possível verificar tudo agora. Atualize para tentar novamente.';
      });
    }
  }

  Future<void> _classify() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      final pending = await widget.repository
          .listPendingTransactionClassifications(widget.spaceId);
      if (!mounted) return;
      await Navigator.of(context).push<bool>(MaterialPageRoute<bool>(
        builder: (_) => TransactionClassificationInbox(
          repository: widget.repository,
          spaceId: widget.spaceId,
          initialItems: pending,
        ),
      ));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível abrir as classificações. Tente novamente.');
      }
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _load();
      }
    }
  }

  Future<void> _openWallet() async {
    if (_opening) return;
    setState(() => _opening = true);
    try {
      await Navigator.of(context).push<void>(MaterialPageRoute(
        builder: (_) => WalletScreen(
          repository: widget.repository,
          spaceId: widget.spaceId,
        ),
      ));
    } finally {
      if (mounted) {
        setState(() => _opening = false);
        await _load();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final surface = AppColors.surface(brightness);
    final border = AppColors.border(brightness);
    final primary = AppColors.primaryText(brightness);
    final secondary = AppColors.secondaryText(brightness);
    final purple = AppColors.primaryPurple(brightness);
    final wallet = _wallet;
    final pending = _pending;

    return Container(
      key: const ValueKey('home-smart-checkin'),
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(AppRadii.card),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(AppIcons.check, size: 17, color: purple),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  'conferência inteligente',
                  style: AppTypography.body(context,
                      fontSize: 13, fontWeight: FontWeight.w700,
                      color: primary),
                ),
              ),
              IconButton(
                tooltip: 'atualizar conferência',
                onPressed: _loading || _opening ? null : _load,
                icon: Icon(AppIcons.refresh, size: 18, color: secondary),
              ),
            ],
          ),
          const SizedBox(height: 3),
          if (_loading)
            Text('Conferindo dados registrados…',
                style: AppTypography.body(context,
                    fontSize: 12, color: secondary))
          else if (_error != null)
            Text(_error!, style: AppTypography.body(context,
                fontSize: 12, color: secondary))
          else ...[
            Text(
              pending == 0
                  ? 'Tudo classificado nos registros atuais.'
                  : '$pending lançamento${pending == 1 ? "" : "s"} '
                    'aguardando categoria.',
              key: const ValueKey('smart-checkin-pending'),
              style: AppTypography.body(context,
                  fontSize: 12, color: primary),
            ),
            if (_autopilotApplied > 0) ...[
              const SizedBox(height: 6),
              Text(
                'Autopilot organizou $_autopilotApplied '
                'lançamento${_autopilotApplied == 1 ? "" : "s"} '
                'com regras que você aprovou.',
                key: const ValueKey('smart-checkin-autopilot-applied'),
                style: AppTypography.body(
                  context, fontSize: 12, color: purple,
                ),
              ),
            ],
            if (_autopilotUnavailable) ...[
              const SizedBox(height: 6),
              Text(
                'A classificação automática não respondeu. '
                'Seus lançamentos foram preservados.',
                style: AppTypography.body(
                  context, fontSize: 11, color: secondary,
                ),
              ),
            ],
            const SizedBox(height: 6),
            ValueListenableBuilder<bool>(
              valueListenable: FinancialPrivacy.hidden,
              builder: (context, hidden, child) => Text(
                wallet == null
                    ? 'Saldos não consultados.'
                    : '${wallet.paymentAccounts.length} conta(s) no Fôlego · '
                        '${Formatters.money(wallet.summary.totalCash)} registrados.',
                key: const ValueKey('smart-checkin-ledger'),
                style: AppTypography.body(context,
                    fontSize: 12, color: secondary),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Conferência automática do app; saldo bancário real '
              'ainda depende de extrato ou integração.',
              style: AppTypography.body(context,
                  fontSize: 11, color: secondary),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 5,
              children: [
                if (pending != null && pending > 0)
                  FilledButton.tonalIcon(
                    key: const ValueKey('smart-checkin-categorize'),
                    onPressed: _opening ? null : _classify,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                    ),
                    icon: const Icon(AppIcons.categoryUnclassified, size: 18),
                    label: const Text('organizar sugestões'),
                  ),
                TextButton.icon(
                  key: const ValueKey('smart-checkin-accounts'),
                  onPressed: _opening ? null : _openWallet,
                  icon: const Icon(AppIcons.wallet, size: 18),
                  label: const Text('conferir minhas contas'),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
