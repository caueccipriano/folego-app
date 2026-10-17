class PushRecurringRouteTarget {
  const PushRecurringRouteTarget({
    required this.itemId,
    required this.subscription,
  });

  final String itemId;
  final bool subscription;
}

class PushWalletInvoiceTarget {
  const PushWalletInvoiceTarget({
    required this.cardId,
    required this.invoiceId,
  });

  final String cardId;
  final String invoiceId;
}

List<String> _pushRouteSegments(String? route) {
  if (route == null || route.trim().isEmpty) return const <String>[];
  try {
    return Uri.parse(route).pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList(growable: false);
  } catch (_) {
    return const <String>[];
  }
}

String? pushWalletDebtId(String? route) {
  final segments = _pushRouteSegments(route);
  if (segments.length == 3 &&
      segments[0] == 'wallet' &&
      segments[1] == 'debt') {
    return segments[2];
  }
  return null;
}

PushWalletInvoiceTarget? pushWalletInvoiceTarget(String? route) {
  final segments = _pushRouteSegments(route);
  if (segments.length == 5 &&
      segments[0] == 'wallet' &&
      segments[1] == 'card' &&
      segments[3] == 'invoice') {
    return PushWalletInvoiceTarget(
      cardId: segments[2],
      invoiceId: segments[4],
    );
  }
  return null;
}

PushRecurringRouteTarget? pushRecurringRouteTarget(String? route) {
  final segments = _pushRouteSegments(route);
  if (segments.length != 3 || segments[0] != 'transactions') return null;

  if (segments[1] == 'subscriptions') {
    return PushRecurringRouteTarget(
      itemId: segments[2],
      subscription: true,
    );
  }
  if (segments[1] == 'recurring') {
    return PushRecurringRouteTarget(
      itemId: segments[2],
      subscription: false,
    );
  }
  return null;
}
