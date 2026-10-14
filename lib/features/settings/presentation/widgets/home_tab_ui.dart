import 'package:flutter/material.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/l10n/generated/app_localizations.dart';

/// How a [HomeTab] looks in the bottom bar, its settings and the startup
/// screen picker.
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
}
