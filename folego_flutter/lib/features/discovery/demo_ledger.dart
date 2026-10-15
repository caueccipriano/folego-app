import 'discovery_model.dart';

/// Memory-only sandbox. This module has no repository, auth or storage imports.
class DemoLedger {
  DemoLedger({DateTime? today}) : today = today ?? DateTime.now() {
    reset();
  }
  final DateTime today;
  late double balance;
  late List<DiscoveryEntry> transactions;
  late List<DiscoveryEntry> pending;
  int _nextId = 0;
  void reset() {
    balance = 2450;
    _nextId = 0;
    transactions = [
      DiscoveryEntry(
        id: 'demo-market',
        kind: DiscoveryKind.transaction,
        title: 'mercado da semana',
        subtitle: 'alimentação · conta dia a dia',
        amount: -185.40,
        date: today.subtract(const Duration(days: 1)),
      ),
      DiscoveryEntry(
        id: 'demo-income',
        kind: DiscoveryKind.transaction,
        title: 'salário',
        subtitle: 'renda · conta dia a dia',
        amount: 4200,
        date: today.subtract(const Duration(days: 5)),
      ),
      DiscoveryEntry(
        id: 'demo-coffee',
        kind: DiscoveryKind.transaction,
        title: 'café com amigos',
        subtitle: 'lazer · cartão exemplo',
        amount: -32,
        date: today.subtract(const Duration(days: 2)),
      ),
    ];
    pending = [
      DiscoveryEntry(
        id: 'demo-rent',
        kind: DiscoveryKind.scheduled,
        title: 'aluguel',
        subtitle: 'vence hoje · exemplo',
        amount: 1100,
        date: today,
        priority: 1,
      ),
      DiscoveryEntry(
        id: 'demo-internet',
        kind: DiscoveryKind.scheduled,
        title: 'internet',
        subtitle: 'vence em 3 dias · exemplo',
        amount: 99.90,
        date: today.add(const Duration(days: 3)),
        priority: 2,
      ),
      DiscoveryEntry(
        id: 'demo-review',
        kind: DiscoveryKind.classification,
        title: 'compra a categorizar',
        subtitle: 'conferir categoria · exemplo',
        amount: 48,
        date: today,
        priority: 3,
      ),
    ];
  }

  void addExpense(String description, double amount) {
    if (description.trim().isEmpty ||
        !amount.isFinite ||
        amount <= 0 ||
        amount > 999999) {
      throw ArgumentError('Informe uma descrição e um valor positivo.');
    }
    balance -= amount;
    transactions.insert(
      0,
      DiscoveryEntry(
        id: 'demo-new-${_nextId++}',
        kind: DiscoveryKind.transaction,
        title: description.trim(),
        subtitle: 'gasto simulado · conta dia a dia',
        amount: -amount,
        date: today,
      ),
    );
  }

  void complete(DiscoveryEntry entry) {
    pending.removeWhere((row) => row.id == entry.id && row.kind == entry.kind);
  }

  DiscoveryData get data => DiscoveryData(
    entries: [
      ...transactions,
      DiscoveryEntry(
        id: 'demo-account',
        kind: DiscoveryKind.account,
        title: 'conta dia a dia',
        subtitle: 'saldo fictício',
        amount: balance,
      ),
      const DiscoveryEntry(
        id: 'demo-card',
        kind: DiscoveryKind.card,
        title: 'cartão exemplo',
        subtitle: 'fatura fictícia · final 1234',
        amount: 320,
      ),
      ...pending.where((row) => row.kind == DiscoveryKind.scheduled),
    ],
    pending: prioritizeDiscovery(pending),
  );
}
