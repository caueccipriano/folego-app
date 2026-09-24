enum SubscriptionAccessKind {
  free,
  trial,
  premium,
  complimentary,
  lifetime,
}

class SubscriptionAccess {
  const SubscriptionAccess({
    required this.kind,
    this.expiresAt,
  });

  final SubscriptionAccessKind kind;
  final DateTime? expiresAt;

  bool get hasPremium => kind != SubscriptionAccessKind.free;

  String get label {
    switch (kind) {
      case SubscriptionAccessKind.free:
        return 'Fôlego Free';
      case SubscriptionAccessKind.trial:
        return 'Premium · teste grátis';
      case SubscriptionAccessKind.premium:
        return 'Fôlego Premium';
      case SubscriptionAccessKind.complimentary:
        return 'Premium · cortesia';
      case SubscriptionAccessKind.lifetime:
        return 'Premium · vitalício';
    }
  }
}
