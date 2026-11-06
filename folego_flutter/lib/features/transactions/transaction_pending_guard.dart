/// Protects transaction-classification previews from late network responses.
/// A stale response must not fill a screen after a refresh or space switch.
bool shouldApplyTransactionPendingResponse({
  required int requestGeneration,
  required int currentGeneration,
  required int requestSpaceEpoch,
  required int currentSpaceEpoch,
  required String? requestedSpaceId,
  required String? activeSpaceId,
}) =>
    requestGeneration == currentGeneration &&
    requestSpaceEpoch == currentSpaceEpoch &&
    requestedSpaceId == activeSpaceId;
 
/// The pending-classification repository returns a fixed-length list.
/// Always copy results into a growable inbox state list so removeWhere can
/// safely dismiss classified transactions, including after a refresh.
List<T> mutableClassificationQueue<T>(Iterable<T> items) =>
    List<T>.of(items, growable: true);
