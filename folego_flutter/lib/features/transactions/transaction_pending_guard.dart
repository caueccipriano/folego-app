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
