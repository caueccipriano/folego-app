import 'package:shared_preferences/shared_preferences.dart';

/// UI-only preferences for the monthly overview. No financial data is stored.
class HomeOverviewModulesSettings {
  const HomeOverviewModulesSettings({
    required this.order,
    required this.hidden,
  });

  static const defaultOrder = <String>['actions', 'budget', 'accounts'];

  final List<String> order;
  final Set<String> hidden;

  static List<String> normalizeOrder(Iterable<String>? values) {
    final result = <String>[];
    for (final name in values ?? const <String>[]) {
      if (defaultOrder.contains(name) && !result.contains(name)) {
        result.add(name);
      }
    }
    for (final name in defaultOrder) {
      if (!result.contains(name)) result.add(name);
    }
    return result;
  }

  static Set<String> normalizeHidden(Iterable<String>? values) {
    return (values ?? const <String>[])
        .where(defaultOrder.contains)
        .toSet();
  }

  static String _storageKey(String spaceId, String field) =>
      'folego.overview.v1.$spaceId.$field';

  static Future<HomeOverviewModulesSettings> load(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    return HomeOverviewModulesSettings(
      order: normalizeOrder(
        prefs.getStringList(_storageKey(spaceId, 'order')),
      ),
      hidden: normalizeHidden(
        prefs.getStringList(_storageKey(spaceId, 'hidden')),
      ),
    );
  }

  Future<void> save(String spaceId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _storageKey(spaceId, 'order'),
      normalizeOrder(order),
    );
    await prefs.setStringList(
      _storageKey(spaceId, 'hidden'),
      normalizeHidden(hidden).toList(),
    );
  }

  HomeOverviewModulesSettings withVisibility(String section, bool show) {
    final nextHidden = {...hidden};
    if (show) {
      nextHidden.remove(section);
    } else {
      nextHidden.add(section);
    }
    return HomeOverviewModulesSettings(order: [...order], hidden: nextHidden);
  }

  HomeOverviewModulesSettings move(String section, int delta) {
    final nextOrder = [...normalizeOrder(order)];
    final from = nextOrder.indexOf(section);
    final to = from + delta;
    if (from < 0 || to < 0 || to >= nextOrder.length) return this;
    nextOrder.removeAt(from);
    nextOrder.insert(to, section);
    return HomeOverviewModulesSettings(order: nextOrder, hidden: {...hidden});
  }

  bool isVisible(String section) => !hidden.contains(section);
}
