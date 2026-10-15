import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/layout/app_breakpoints.dart';
import '../../core/realtime/realtime_invalidation.dart';
import '../../core/realtime/realtime_session.dart';
import '../../data/models/financial_space.dart';
import '../../data/models/transaction_filters.dart';
import '../../data/models/transaction_item.dart';
import '../../data/repositories/folego_repository.dart';
import '../../data/repositories/folego_repository_transaction_classification.dart';
import '../plan/spending_behavior_screen.dart';
import 'statement_import_screen.dart';
import 'transaction_classification_inbox.dart';
import 'transaction_pending_guard.dart';
import 'transactions_screen_base.dart' as impl;

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({
    super.key,
    required this.repository,
    this.space,
    this.initialFilters,
    this.initialPushRoute,
  });

  final FolegoRepository repository;
  final FinancialSpace? space;
  final TransactionFilters? initialFilters;
  final String? initialPushRoute;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  FinancialSpace? _space;
  List<TransactionItem> _pending = const [];
  bool _loadingPending = true;
  bool _pendingUnavailable = false;
  bool _openedPushClassification = false;
  RealtimeRefreshBinding? _realtimeBinding;
  int _pendingLoadGeneration = 0;
  int _spaceEpoch = 0;

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
      // Immediately remove previous-space data and invalidate in-flight reads.
      _spaceEpoch++;
      _pendingLoadGeneration++;
      _space = widget.space;
      _pending = const [];
      _loadingPending = true;
      _pendingUnavailable = false;
      _openedPushClassification = false;
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
    final requestGeneration = ++_pendingLoadGeneration;
    final requestedEpoch = _spaceEpoch;
    final requestedSpaceId = widget.space?.id ?? _space?.id;
    if (mounted) {
      setState(() {
        _loadingPending = true;
        _pendingUnavailable = false;
      });
    }
    try {
      final space =
          widget.space ?? _space ?? await widget.repository.getPrimarySpace();
      final pending = await widget.repository.listPendingTransactionClassifications(
        space.id,
      );
      if (!mounted ||
          !shouldApplyTransactionPendingResponse(
            requestGeneration: requestGeneration,
            currentGeneration: _pendingLoadGeneration,
            requestSpaceEpoch: requestedEpoch,
            currentSpaceEpoch: _spaceEpoch,
            requestedSpaceId: requestedSpaceId,
            activeSpaceId: widget.space?.id,
          )) {
        return;
      }
      setState(() {
        _space = space;
        _pending = pending;
        _loadingPending = false;
        _pendingUnavailable = false;
      });
    } catch (_) {
      if (!mounted ||
          !shouldApplyTransactionPendingResponse(
            requestGeneration: requestGeneration,
            currentGeneration: _pendingLoadGeneration,
            requestSpaceEpoch: requestedEpoch,
            currentSpaceEpoch: _spaceEpoch,
            requestedSpaceId: requestedSpaceId,
            activeSpaceId: widget.space?.id,
          )) {
        return;
      }
      setState(() {
        // Keep no stale counter when a fresh pending read fails.
        _pending = const [];
        _loadingPending = false;
        _pendingUnavailable = true;
      });
    }
  }

  void _openClassificationFromPushIfNeeded() {
    if (_openedPushClassification || !mounted) return;
    final route = widget.initialPushRoute ?? Uri.base.queryParameters['push_route'];
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
    final requestedEpoch = _spaceEpoch;
    try {
      final space = await widget.repository.getPrimarySpace();
      if (!mounted || requestedEpoch != _spaceEpoch ||
          (widget.space != null && widget.space!.id != space.id)) {
        return null;
      }
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

  Future<void> _openExpenseBehaviors() async {
    final space = await _resolveSpace();
    if (space == null || !mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => SpendingBehaviorScreen(
          repository: widget.repository,
          spaceId: space.id,
          periodMonth: DateTime.now(),
        ),
      ),
    );
  }

  Future<void> _openClassificationInbox() async {
    // Do not open an empty inbox when a failed request only means 'unknown'.
    if (_pendingUnavailable) {
      await _loadPending();
      if (!mounted) return;
      if (_pendingUnavailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('não consegui consultar pendências agora')),
        );
        return;
      }
    }
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
    final content = impl.TransactionsScreenV3(
      key: ValueKey<String>(widget.space?.id ?? 'primary-space'),
      repository: widget.repository,
      space: widget.space,
      initialFilters: widget.initialFilters,
      initialPushRoute: widget.initialPushRoute,
      onImportRequested: _openImport,
      onClassificationRequested: _openClassificationInbox,
      onSpendingBehaviorRequested: _openExpenseBehaviors,
      pendingClassificationCount: _pending.length,
      pendingClassificationLoading: _loadingPending,
      pendingClassificationUnavailable: _pendingUnavailable,
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
