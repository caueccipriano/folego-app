import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Home mobile answers spendable first and keeps actions accessible', () {
    final source =
        File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final compact = source
        .split('if (layout == AppLayoutSize.compact) ...[')
        .last
        .split('] else if (layout == AppLayoutSize.medium) ...[')
        .first;
    final hero = compact.indexOf('hero,');
    final actions = compact.indexOf('quickActions,');
    final pulse = compact.indexOf('pulse,');
    expect(hero, greaterThanOrEqualTo(0));
    expect(actions, greaterThan(hero));
    expect(pulse, greaterThan(actions));
    expect(compact, contains("ValueKey('home-monthly-details')"));
  });

  test('Home mobile shows upcoming details only when expanded', () {
    final source =
        File('lib/features/home/home_screen_base.dart').readAsStringSync();
    final compact = source
        .split('if (layout == AppLayoutSize.compact) ...[')
        .last
        .split('] else if (layout == AppLayoutSize.medium) ...[')
        .first;
    final details = compact.indexOf("ValueKey('home-monthly-details')");
    final upcoming = compact.indexOf('if (showUpcoming) ...[');
    expect(details, greaterThan(0));
    expect(upcoming, greaterThan(details));
    expect(compact.substring(0, details), isNot(contains('upcoming,')));
    expect(source, contains('onPressed: _openUpcomingEvents'));
  });
}
