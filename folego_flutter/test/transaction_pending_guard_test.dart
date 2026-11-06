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
  test('classification queue stays growable after fixed-length refresh', () {
    final repositoryItems = List<String>.of(
      ['pending-a', 'pending-b'],
      growable: false,
    );
    final queue = mutableClassificationQueue(repositoryItems);

    queue.removeWhere((item) => item == 'pending-a');

    expect(queue, ['pending-b']);
    expect(repositoryItems, ['pending-a', 'pending-b']);
  });

  test('classification queue copies unmodifiable results for batch review', () {
    final repositoryItems = List<String>.unmodifiable([
      'first',
      'second',
      'third',
    ]);
    final queue = mutableClassificationQueue(repositoryItems);

    queue.removeWhere((item) => item == 'first' || item == 'second');

    expect(queue, ['third']);
    expect(repositoryItems, ['first', 'second', 'third']);
  });

  test('classification actions are unlocked only in idle state', () {
    bool locked({
      bool loading = false,
      bool refreshing = false,
      bool saving = false,
      bool applyingSuggestions = false,
      bool creatingAutomaticRule = false,
    }) => classificationActionLocked(
      loading: loading,
      refreshing: refreshing,
      saving: saving,
      applyingSuggestions: applyingSuggestions,
      creatingAutomaticRule: creatingAutomaticRule,
    );

    expect(locked(), isFalse);
    expect(locked(loading: true), isTrue);
    expect(locked(refreshing: true), isTrue);
    expect(locked(saving: true), isTrue);
    expect(locked(applyingSuggestions: true), isTrue);
    expect(locked(creatingAutomaticRule: true), isTrue);
  });

}
