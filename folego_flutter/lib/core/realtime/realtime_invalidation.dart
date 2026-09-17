import 'dart:async';

enum AppRealtimeDomain {
  home,
  transactions,
  categories,
  paymentInstruments,
  plan,
  wallet,
  diary,
  goals,
  notifications,
  automationRules,
}

const Map<String, Set<AppRealtimeDomain>> appRealtimeTableDomains = {
  'financial_events': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.transactions,
    AppRealtimeDomain.plan,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.diary,
  },
  'financial_impacts': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.transactions,
    AppRealtimeDomain.plan,
    AppRealtimeDomain.wallet,
  },
  'accounts': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.paymentInstruments,
    AppRealtimeDomain.wallet,
  },
  'categories': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.categories,
    AppRealtimeDomain.plan,
    AppRealtimeDomain.diary,
    AppRealtimeDomain.automationRules,
  },
  'budgets': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.plan,
  },
  'budget_items': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.plan,
  },
  'budget_recurring_rules': {
    AppRealtimeDomain.plan,
  },
  'recurring_items': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.transactions,
    AppRealtimeDomain.notifications,
  },
  'recurring_occurrences': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.transactions,
    AppRealtimeDomain.notifications,
  },
  'card_installments': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.notifications,
  },
  'card_invoices': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.notifications,
  },
  'card_payments': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.notifications,
  },
  'card_purchases': {
    AppRealtimeDomain.wallet,
  },
  'credit_cards': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.paymentInstruments,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.automationRules,
  },
  'debts': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.notifications,
  },
  'debt_installments': {
    AppRealtimeDomain.home,
    AppRealtimeDomain.wallet,
    AppRealtimeDomain.notifications,
  },
  'transaction_reflections': {
    AppRealtimeDomain.diary,
  },
  'savings_goals': {
    AppRealtimeDomain.goals,
  },
  'goal_contributions': {
    AppRealtimeDomain.goals,
  },
  'automation_rules': {
    AppRealtimeDomain.automationRules,
  },
};

Set<AppRealtimeDomain> domainsForRealtimeTable(String table) {
  return appRealtimeTableDomains[table] ?? const <AppRealtimeDomain>{};
}

bool realtimeRecordBelongsToSpace({
  required String spaceId,
  Map<String, dynamic> newRecord = const <String, dynamic>{},
  Map<String, dynamic> oldRecord = const <String, dynamic>{},
}) {
  String? readSpace(Map<String, dynamic> record) {
    final value = record['space_id'];
    return value is String && value.isNotEmpty ? value : null;
  }

  final newSpace = readSpace(newRecord);
  if (newSpace != null) return newSpace == spaceId;

  final oldSpace = readSpace(oldRecord);
  if (oldSpace != null) return oldSpace == spaceId;

  return false;
}

typedef RealtimeRefreshCallback = Future<void> Function();

class RealtimeInvalidationCoordinator {
  RealtimeInvalidationCoordinator({
    this.debounce = const Duration(milliseconds: 250),
  });

  final Duration debounce;
  final Map<AppRealtimeDomain, Set<RealtimeRefreshBinding>> _bindings = {
    for (final domain in AppRealtimeDomain.values)
      domain: <RealtimeRefreshBinding>{},
  };
  final Set<AppRealtimeDomain> _pendingDomains = <AppRealtimeDomain>{};

  Timer? _timer;
  bool _disposed = false;

  RealtimeRefreshBinding bind({
    required AppRealtimeDomain domain,
    required RealtimeRefreshCallback onRefresh,
    bool active = true,
  }) {
    if (_disposed) {
      throw StateError('RealtimeInvalidationCoordinator já foi encerrado.');
    }

    final binding = RealtimeRefreshBinding._(
      coordinator: this,
      domain: domain,
      onRefresh: onRefresh,
      active: active,
    );
    _bindings[domain]!.add(binding);
    return binding;
  }

  void invalidate(AppRealtimeDomain domain) {
    invalidateDomains(<AppRealtimeDomain>{domain});
  }

  void invalidateDomains(Iterable<AppRealtimeDomain> domains) {
    if (_disposed) return;

    _pendingDomains.addAll(domains);
    if (_pendingDomains.isEmpty) return;

    _timer?.cancel();
    _timer = Timer(debounce, _flush);
  }

  void invalidateAll() {
    invalidateDomains(AppRealtimeDomain.values);
  }

  void cancelPending() {
    _timer?.cancel();
    _timer = null;
    _pendingDomains.clear();
  }

  void _flush() {
    if (_disposed || _pendingDomains.isEmpty) return;

    final domains = Set<AppRealtimeDomain>.from(_pendingDomains);
    _pendingDomains.clear();
    _timer = null;

    for (final domain in domains) {
      for (final binding in List<RealtimeRefreshBinding>.from(
        _bindings[domain]!,
      )) {
        binding._invalidate();
      }
    }
  }

  void _remove(RealtimeRefreshBinding binding) {
    _bindings[binding.domain]?.remove(binding);
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    cancelPending();

    final bindings = _bindings.values
        .expand((items) => items)
        .toList(growable: false);
    for (final binding in bindings) {
      binding._disposeFromCoordinator();
    }
    for (final items in _bindings.values) {
      items.clear();
    }
  }
}

class RealtimeRefreshBinding {
  RealtimeRefreshBinding._({
    required RealtimeInvalidationCoordinator coordinator,
    required this.domain,
    required RealtimeRefreshCallback onRefresh,
    required bool active,
  }) : _coordinator = coordinator,
       _onRefresh = onRefresh,
       _active = active;

  final RealtimeInvalidationCoordinator _coordinator;
  final AppRealtimeDomain domain;
  final RealtimeRefreshCallback _onRefresh;

  bool _active;
  bool _dirty = false;
  bool _disposed = false;
  bool _refreshing = false;
  bool _refreshAgain = false;

  bool get isActive => _active;
  bool get isDirty => _dirty;
  bool get isDisposed => _disposed;

  void setActive(bool active) {
    if (_disposed || _active == active) return;
    _active = active;

    if (_active && _dirty) {
      _requestRefresh();
    }
  }

  void _invalidate() {
    if (_disposed) return;

    if (!_active) {
      _dirty = true;
      return;
    }

    _requestRefresh();
  }

  void _requestRefresh() {
    if (_disposed) return;

    if (!_active) {
      _dirty = true;
      return;
    }

    if (_refreshing) {
      _refreshAgain = true;
      return;
    }

    unawaited(_runRefreshLoop());
  }

  Future<void> _runRefreshLoop() async {
    if (_disposed || !_active || _refreshing) return;

    _refreshing = true;
    try {
      do {
        _refreshAgain = false;
        _dirty = false;

        try {
          await _onRefresh();
        } catch (_) {
          // Realtime é uma melhoria de sincronização. A própria tela continua
          // responsável por seus estados/erros de leitura e refresh manual.
        }
      } while (!_disposed && _active && _refreshAgain);

      if (!_active && _refreshAgain) {
        _dirty = true;
      }
    } finally {
      _refreshing = false;
    }
  }

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _coordinator._remove(this);
  }

  void _disposeFromCoordinator() {
    _disposed = true;
  }
}
