/// Reject a delayed financial response after a newer request or space switch.
/// The check is UI-only and must not alter financial event data.
bool shouldApplyHomeResponse({
  required int requestGeneration,
  required int currentGeneration,
  required String requestedSpaceId,
  required String currentSpaceId,
}) =>
    requestGeneration == currentGeneration &&
    requestedSpaceId == currentSpaceId;
