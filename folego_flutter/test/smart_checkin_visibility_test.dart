import 'package:flutter_test/flutter_test.dart';
import 'package:folego/features/home/smart_checkin_card.dart';

void main() {
  test('a clean, successful review does not demand attention', () {
    expect(
      shouldShowSmartCheckin(
        loading: false,
        pending: 0,
        autopilotApplied: 0,
        autopilotUnavailable: false,
        error: null,
      ),
      isFalse,
    );
  });

  test('no loading flash before the check finishes', () {
    expect(
      shouldShowSmartCheckin(
        loading: true,
        pending: null,
        autopilotApplied: 0,
        autopilotUnavailable: false,
        error: null,
      ),
      isFalse,
    );
  });

  test('only meaningful exceptions or useful automation results surface', () {
    for (final state in [
      (pending: 2, applied: 0, unavailable: false, error: null),
      (pending: 0, applied: 3, unavailable: false, error: null),
      (pending: 0, applied: 0, unavailable: true, error: null),
      (pending: 0, applied: 0, unavailable: false, error: 'Falha'),
    ]) {
      expect(
        shouldShowSmartCheckin(
          loading: false,
          pending: state.pending,
          autopilotApplied: state.applied,
          autopilotUnavailable: state.unavailable,
          error: state.error,
        ),
        isTrue,
      );
    }
  });
}
