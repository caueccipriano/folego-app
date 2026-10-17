import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/transactions/transaction_pending_guard.dart';

void main() {
  test('same-space pending response from latest request is accepted', () {
    expect(shouldApplyTransactionPendingResponse(
      requestGeneration: 5,
      currentGeneration: 5,
      requestSpaceEpoch: 1,
      currentSpaceEpoch: 1,
      requestedSpaceId: 'space-b',
      activeSpaceId: 'space-b',
    ), isTrue);
  });

  test('older request cannot overwrite a fresh pending review list', () {
    expect(shouldApplyTransactionPendingResponse(
      requestGeneration: 4,
      currentGeneration: 5,
      requestSpaceEpoch: 1,
      currentSpaceEpoch: 1,
      requestedSpaceId: 'space-b',
      activeSpaceId: 'space-b',
    ), isFalse);
  });

  test('space changes reject late responses even if request numbers match', () {
    expect(shouldApplyTransactionPendingResponse(
      requestGeneration: 5,
      currentGeneration: 5,
      requestSpaceEpoch: 1,
      currentSpaceEpoch: 2,
      requestedSpaceId: 'space-a',
      activeSpaceId: 'space-b',
    ), isFalse);
    expect(shouldApplyTransactionPendingResponse(
      requestGeneration: 5,
      currentGeneration: 5,
      requestSpaceEpoch: 2,
      currentSpaceEpoch: 2,
      requestedSpaceId: 'space-a',
      activeSpaceId: 'space-b',
    ), isFalse);
  });

  test('primary-space fallback remains valid when no explicit space is set', () {
    expect(shouldApplyTransactionPendingResponse(
      requestGeneration: 1,
      currentGeneration: 1,
      requestSpaceEpoch: 0,
      currentSpaceEpoch: 0,
      requestedSpaceId: null,
      activeSpaceId: null,
    ), isTrue);
  });
}
