import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/home_load_guard.dart';

void main() {
  test('accepts only the current load for the current financial space', () {
    expect(shouldApplyHomeResponse(
      requestGeneration: 2, currentGeneration: 2,
      requestedSpaceId: 'space-a', currentSpaceId: 'space-a',
    ), isTrue);
    expect(shouldApplyHomeResponse(
      requestGeneration: 1, currentGeneration: 2,
      requestedSpaceId: 'space-a', currentSpaceId: 'space-a',
    ), isFalse);
    expect(shouldApplyHomeResponse(
      requestGeneration: 2, currentGeneration: 2,
      requestedSpaceId: 'space-a', currentSpaceId: 'space-b',
    ), isFalse);
  });
}
