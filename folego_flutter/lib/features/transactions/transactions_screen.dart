import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../core/theme/app_icons.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_filters.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import 'statement_import_screen.dart';
import 'transaction_classification_inbox.dart';
import 'transactions_screen_base.dart' as impl;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
    this.space,
    this.initialFilters,
  });

  final FolegoRepository repository;
  final FinancialSpace? space;
  final TransactionFilters? initialFilters;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  FinancialSpace? _space;
  List<TransactionItem> _pending = const [];
  bool _loadingPending = true;
  bool _openedPushClassification = false;
  RealtimeRefreshBinding? _realtimeBinding;

  @override
  void initState() {
    super.initState();
    _bindRealtime();
    unawaited(
      _loadPending().then((_) => _openClassificationFromPushIfNeeded()),
    );
  }

  @override
  void didUpdateWidget(covariant TransactionsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.space?.id != widget.space?.id) {
      unawaited(_loadPending());
    }
  }

  void _bindRealtime() {
    final coordinator = AppRealtimeRegistry.coordinator;
    if (coordinator == null) return;
    _realtimeBinding = coordinator.bind(
      domain: AppRealtimeDomain.transactions,
      onRefresh: _loadPending,
    );
  }

  @override
  void dispose() {
    _realtimeBinding?.dispose();
    super.dispose();
  }

  Future<void> _loadPending() async {
    try {
      final space =
          widget.space ?? _space ?? await widget.repository.getPrimarySpace();
      final pending = await widget.repository.listPendingTransactionClassifications(
        space.id,
      );
      if (!mounted) return;
      setState(() {
        _space = space;
        _pending = pending;
        _loadingPending = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingPending = false);
    }
  }

  void _openClassificationFromPushIfNeeded() {
    if (_openedPushClassification || !mounted) return;
    final route = Uri.base.queryParameters['push_route'];
    if (route != '/transactions/classification') return;

    _openedPushClassification = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_openClassificationInbox());
    });
  }

  Future<FinancialSpace?> _resolveSpace() async {
    final current = widget.space ?? _space;
    if (current != null) return current;
    try {
      final space = await widget.repository.getPrimarySpace();
      if (!mounted) return null;
      setState(() => _space = space);
      return space;
    } catch (_) {
      return null;
    }
  }

  Future<void> _openImport() async {
    final space = await _resolveSpace();
    if (space == null || !mounted) return;
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => StatementImportScreen(
          repository: widget.repository,
          spaceId: space.id,
        ),
      ),
    );
  }

  Future<void> _openClassificationInbox() async {
    final space = widget.space ?? _space;
    if (space == null) {
      await _loadPending();
      if (!mounted) return;
    }
    final resolvedSpace = widget.space ?? _space;
    if (resolvedSpace == null || !mounted) return;

    final compact = AppBreakpoints.of(context) == AppLayoutSize.compact;
    if (compact) {
      await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: Colors.transparent,
        builder: (_) => FractionallySizedBox(
          heightFactor: .94,
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: TransactionClassificationInbox(
              repository: widget.repository,
              spaceId: resolvedSpace.id,
              initialItems: _pending,
            ),
          ),
        ),
      );
    } else {
      await showDialog<bool>(
        context: context,
        builder: (_) => Dialog(
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 720,
            height: MediaQuery.sizeOf(context).height * .86,
            child: TransactionClassificationInbox(
              repository: widget.repository,
              spaceId: resolvedSpace.id,
              initialItems: _pending,
            ),
          ),
        ),
      );
    }

    if (mounted) await _loadPending();
  }

  @override
  Widget build(BuildContext context) {
    final layout = AppBreakpoints.of(context);
    final desktop =
        layout == AppLayoutSize.expanded || layout == AppLayoutSize.wide;
    final screen = impl.TransactionsScreenV3(
      key: ValueKey<String>(widget.space?.id ?? 'primary-space'),
      repository: widget.repository,
      space: widget.space,
      initialFilters: widget.initialFilters,
    );

    final content = Stack(
      children: [
        Positioned.fill(child: screen),
        Positioned(
          right: 16,
          bottom: 84,
          child: SafeArea(
            child: FloatingActionButton.small(
              key: const ValueKey('statement-import-entry'),
              heroTag: 'transaction-import-statement',
              tooltip: 'importar extrato',
              onPressed: _openImport,
              child: const Icon(AppIcons.receipt),
            ),
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: SafeArea(
            child: FloatingActionButton.extended(
              heroTag: 'transaction-classification-inbox',
              onPressed: _openClassificationInbox,
              icon: Icon(
                _pending.isEmpty && !_loadingPending
                    ? AppIcons.check
                    : AppIcons.categoryUnclassified,
              ),
              label: Text(
                _loadingPending
                    ? 'Classificar'
                    : _pending.isEmpty
                        ? 'Classificar'
                        : 'Classificar (${_pending.length})',
              ),
            ),
          ),
        ),
      ],
    );

    if (!desktop) return content;

    return Theme(
      data: Theme.of(context).copyWith(visualDensity: VisualDensity.compact),
      child: KeyedSubtree(
        key: const ValueKey('transactions-desktop-layout'),
        child: content,
      ),
    );
  }
}
