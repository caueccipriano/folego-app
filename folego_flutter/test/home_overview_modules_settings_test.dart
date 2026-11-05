import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folego/features/home/home_overview_modules_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults show all modules in a predictable order', () async {
    final settings = await HomeOverviewModulesSettings.load('space-one');
    expect(settings.order, ['actions', 'analytics', 'budget', 'accounts']);
    expect(settings.hidden, isEmpty);
  });

  test('reordering and hidden modules persist within a financial space',
      () async {
    final initial = await HomeOverviewModulesSettings.load('space-one');
    final next = initial.move('accounts', -1)
        .withVisibility('budget', false);
    await next.save('space-one');

    final restored = await HomeOverviewModulesSettings.load('space-one');
    expect(restored.order, ['actions', 'analytics', 'accounts', 'budget']);
    expect(restored.isVisible('budget'), isFalse);
    expect(restored.isVisible('accounts'), isTrue);

    final otherSpace = await HomeOverviewModulesSettings.load('space-two');
    expect(otherSpace.order, HomeOverviewModulesSettings.defaultOrder);
    expect(otherSpace.hidden, isEmpty);
  });

  test('invalid and duplicate module ids are discarded safely', () {
    expect(
      HomeOverviewModulesSettings.normalizeOrder(
          ['accounts', 'invalid', 'accounts']),
      ['accounts', 'actions', 'analytics', 'budget'],
    );
    expect(
      HomeOverviewModulesSettings.normalizeHidden(['unknown', 'actions']),
      {'actions'},
    );
  });

  test('restoring a hidden module leaves all other choices unchanged', () {
    const settings = HomeOverviewModulesSettings(
      order: ['budget', 'accounts', 'actions'],
      hidden: {'accounts'},
    );
    final visible = settings.withVisibility('accounts', true);
    expect(visible.hidden, isEmpty);
    expect(visible.order, settings.order);
  });
}
