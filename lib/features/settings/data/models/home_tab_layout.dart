import 'dart:convert';

/// A tab the main bottom bar can show. The names are stored in
/// `app.home_tabs` and `app.startup_screen` and sent as telemetry tags, so
/// never rename one.
enum HomeTab {
  library,
  dictionary,
  vocabulary,
  you,
  recent,
  stats,
  freeBooks,
  settings,
}

/// The most tabs the bottom bar shows at once; more crowd the labels.
const maxVisibleHomeTabs = 5;

/// The bottom bar's layout: every tab in the user's order, and which of
/// them are hidden.
///
/// The constructor repairs whatever it is given, so a layout from an old
/// version or a hand-edited backup is always usable: unknown and repeated
/// tabs are dropped, tabs missing from [order] (added by a later version)
/// are appended hidden, Library is never hidden (imports and the book grid
/// live only there), and at most [maxVisibleHomeTabs] tabs are visible.
class HomeTabLayout {
  factory HomeTabLayout(Iterable<HomeTab> order, Set<HomeTab> hidden) {
    final fullOrder = order.toSet().toList();
    final hiddenTabs = {...hidden};
    for (final tab in HomeTab.values) {
      if (!fullOrder.contains(tab)) {
        fullOrder.add(tab);
        hiddenTabs.add(tab);
      }
    }
    hiddenTabs.remove(HomeTab.library);
    final visible = <HomeTab>[];
    for (final tab in fullOrder) {
      if (hiddenTabs.contains(tab)) continue;
      // Library always fits: it takes the place of the last one shown.
      if (visible.length == maxVisibleHomeTabs) {
        if (tab != HomeTab.library) {
          hiddenTabs.add(tab);
          continue;
        }
        hiddenTabs.add(visible.removeLast());
      }
      visible.add(tab);
    }
    return HomeTabLayout._(
      List.unmodifiable(fullOrder),
      Set.unmodifiable(hiddenTabs),
      List.unmodifiable(visible),
    );
  }

  HomeTabLayout._(this.order, this.hidden, this.visible);

  /// Today's four tabs; the newer ones start hidden.
  factory HomeTabLayout.defaults() => HomeTabLayout(HomeTab.values, const {
    HomeTab.recent,
    HomeTab.stats,
    HomeTab.freeBooks,
    HomeTab.settings,
  });

  /// Reads [encode]'s JSON; anything unreadable gives [HomeTabLayout.defaults].
  factory HomeTabLayout.decode(String? json) {
    if (json == null) return HomeTabLayout.defaults();
    try {
      final map = jsonDecode(json) as Map<String, dynamic>;
      final byName = HomeTab.values.asNameMap();
      Iterable<HomeTab> tabs(Object? names) =>
          (names as List).map((name) => byName[name]).nonNulls;
      return HomeTabLayout(tabs(map['order']), tabs(map['hidden']).toSet());
    } catch (_) {
      return HomeTabLayout.defaults();
    }
  }

  /// Every tab, in the user's order.
  final List<HomeTab> order;
  final Set<HomeTab> hidden;

  /// The tabs the bar shows, in order; Library is always one of them.
  final List<HomeTab> visible;

  /// Whether the bar leads to Settings, as its own tab or through the You
  /// hub. Without either, the Library's app bar shows a Settings button.
  bool get settingsInBar =>
      visible.contains(HomeTab.you) || visible.contains(HomeTab.settings);

  String encode() => jsonEncode({
    'order': [for (final tab in order) tab.name],
    'hidden': [
      for (final tab in order)
        if (hidden.contains(tab)) tab.name,
    ],
  });
}
