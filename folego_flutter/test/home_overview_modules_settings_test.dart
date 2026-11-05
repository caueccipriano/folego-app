import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:folego/features/home/home_overview_modules_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('defaults show all modules in a predictable order', () async {
    final settings = await HomeOverviewModulesSettings.load('space-one');
    expect(settings.order, ['actions', 'budget', 'accounts']);
    expect(settings.hidden, isEmpty);
    expect(settings.compact, isTrue);
  });

  test('reordering and hidden modules persist within a financial space',
      () async {
    final initial = await HomeOverviewModulesSettings.load('space-one');
    final next = initial.move('accounts', -1)
        .withVisibility('budget', false);
    await next.save('space-one');

    final restored = await HomeOverviewModulesSettings.load('space-one');
    expect(restored.order, ['actions', 'accounts', 'budget']);
    expect(restored.isVisible('budget'), isFalse);
    expect(restored.isVisible('accounts'), isTrue);
    expect(restored.compact, isTrue);

    final otherSpace = await HomeOverviewModulesSettings.load('space-two');
    expect(otherSpace.order, HomeOverviewModulesSettings.defaultOrder);
    expect(otherSpace.hidden, isEmpty);
    expect(otherSpace.compact, isTrue);
  });

  test('layout density stays independent for each financial space', () async {
    final one = await HomeOverviewModulesSettings.load('space-one');
    final comfortable = one.withCompact(false);
    await comfortable.save('space-one');

    final restored = await HomeOverviewModulesSettings.load('space-one');
    final other = await HomeOverviewModulesSettings.load('space-two');
    expect(restored.compact, isFalse);
    expect(restored.order, HomeOverviewModulesSettings.defaultOrder);
    expect(other.compact, isTrue);
    expect(restored.move('budget', -1).compact, isFalse);
    expect(restored.withVisibility('accounts', false).compact, isFalse);
  });

  test('invalid and duplicate module ids are discarded safely', () {
    expect(
      HomeOverviewModulesSettings.normalizeOrder(
          ['accounts', 'invalid', 'accounts']),
      ['accounts', 'actions', 'budget'],
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
