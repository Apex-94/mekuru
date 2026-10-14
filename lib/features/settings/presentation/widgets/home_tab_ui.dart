import 'package:flutter/material.dart';
import 'package:mekuru/features/dictionary/presentation/screens/dictionary_search_screen.dart';
import 'package:mekuru/features/free_books/presentation/screens/free_books_screen.dart';
import 'package:mekuru/features/library/presentation/screens/library_screen.dart';
import 'package:mekuru/features/library/presentation/screens/recently_read_screen.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/screens/settings_screen.dart';
import 'package:mekuru/features/stats/presentation/screens/stats_screen.dart';
import 'package:mekuru/features/vocabulary/presentation/screens/vocabulary_screen.dart';
import 'package:mekuru/features/you/presentation/screens/you_screen.dart';
import 'package:mekuru/l10n/generated/app_localizations.dart';
import 'package:mekuru/shared/utils/app_routes.dart';

/// How a [HomeTab] looks in the bottom bar, its settings and the startup
/// screen picker, and the page it opens.
extension HomeTabUi on HomeTab {
  IconData get icon => _icons.$1;

  IconData get selectedIcon => _icons.$2;

  /// The bar's icon, then the one it shows while selected.
  (IconData, IconData) get _icons => switch (this) {
    HomeTab.library => (Icons.auto_stories_outlined, Icons.auto_stories),
    HomeTab.dictionary => (Icons.book_outlined, Icons.book),
    HomeTab.vocabulary => (Icons.bookmark_border, Icons.bookmark),
    HomeTab.you => (Icons.person_outline, Icons.person),
    HomeTab.recent => (Icons.history, Icons.history),
    HomeTab.stats => (Icons.insights_outlined, Icons.insights),
    HomeTab.freeBooks => (Icons.local_library_outlined, Icons.local_library),
    HomeTab.settings => (Icons.settings_outlined, Icons.settings),
  };

  String label(AppLocalizations l10n) => switch (this) {
    HomeTab.library => l10n.navLibrary,
    HomeTab.dictionary => l10n.navDictionary,
    HomeTab.vocabulary => l10n.navVocabulary,
    HomeTab.you => l10n.navYou,
    HomeTab.recent => l10n.navRecent,
    HomeTab.stats => l10n.navStats,
    HomeTab.freeBooks => l10n.navFreeBooks,
    HomeTab.settings => l10n.settingsTitle,
  };

  /// The page's own title, where there is room for more than the label.
  String pageTitle(AppLocalizations l10n) => switch (this) {
    HomeTab.recent => l10n.recentlyReadTitle,
    HomeTab.stats => l10n.statsScreenTitle,
    HomeTab.freeBooks => l10n.freeBooksTitle,
    _ => label(l10n),
  };

  /// The tab's page.
  Widget page({Key? key}) => switch (this) {
    HomeTab.library => LibraryScreen(key: key),
    HomeTab.dictionary => DictionarySearchScreen(key: key),
    HomeTab.vocabulary => VocabularyScreen(key: key),
    HomeTab.you => YouScreen(key: key),
    HomeTab.recent => RecentlyReadScreen(key: key),
    HomeTab.stats => StatsScreen(key: key),
    HomeTab.freeBooks => FreeBooksScreen(key: key),
    HomeTab.settings => SettingsScreen(key: key),
  };

  /// [page] pushed over the bar, named like the app's other routes to it.
  Route<void> pageRoute() => namedRoute(switch (this) {
    HomeTab.dictionary => 'dictionary_search',
    HomeTab.recent => 'recently_read',
    HomeTab.freeBooks => 'free_books',
    _ => name,
  }, (_) => page());
}
