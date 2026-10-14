import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/providers/app_settings_providers.dart';

void main() {
  const library = HomeTab.library;
  const dictionary = HomeTab.dictionary;
  const vocabulary = HomeTab.vocabulary;
  const you = HomeTab.you;
  const recent = HomeTab.recent;
  const stats = HomeTab.stats;
  const freeBooks = HomeTab.freeBooks;
  const settings = HomeTab.settings;

  group('HomeTabLayout', () {
    test('defaults show the four original tabs', () {
      expect(HomeTabLayout.defaults().visible, [
        library,
        dictionary,
        vocabulary,
        you,
      ]);
      expect(HomeTabLayout.decode(null).visible, [
        library,
        dictionary,
        vocabulary,
        you,
      ]);
    });

    test('encode and decode round-trip order and hidden tabs', () {
      final layout = HomeTabLayout(
        [
          recent,
          library,
          you,
          dictionary,
          vocabulary,
          stats,
          freeBooks,
          settings,
        ],
        {dictionary, vocabulary, stats, freeBooks},
      );
      final decoded = HomeTabLayout.decode(layout.encode());
      expect(decoded.order, layout.order);
      expect(decoded.hidden, layout.hidden);
      expect(decoded.visible, [recent, library, you, settings]);
    });

    test('drops unknown and repeated names', () {
      final layout = HomeTabLayout.decode(
        jsonEncode({
          'order': ['you', 'gone', 'library', 'you', 42],
          'hidden': ['gone'],
        }),
      );
      expect(layout.order.take(2), [you, library]);
      expect(layout.order, hasLength(HomeTab.values.length));
      expect(layout.visible, [you, library]);
    });

    test('tabs missing from the order are appended hidden', () {
      final layout = HomeTabLayout.decode(
        jsonEncode({
          'order': ['dictionary', 'library'],
          'hidden': <String>[],
        }),
      );
      expect(layout.visible, [dictionary, library]);
      expect(layout.order.skip(2), [
        vocabulary,
        you,
        recent,
        stats,
        freeBooks,
        settings,
      ]);
    });

    test('Library is never hidden', () {
      final layout = HomeTabLayout(HomeTab.values, {library, dictionary});
      expect(layout.visible, contains(library));
      expect(layout.hidden, isNot(contains(library)));
    });

    test('at most five tabs are visible, Library always among them', () {
      final layout = HomeTabLayout([
        dictionary,
        vocabulary,
        you,
        recent,
        stats,
        freeBooks,
        library,
        settings,
      ], const {});
      expect(layout.visible, [dictionary, vocabulary, you, recent, library]);
      expect(layout.hidden, {stats, freeBooks, settings});
    });

    test('Settings is in the bar through You or its own tab', () {
      expect(HomeTabLayout.defaults().settingsInBar, isTrue);
      expect(HomeTabLayout(HomeTab.values, {you}).settingsInBar, isFalse);
      expect(
        HomeTabLayout(HomeTab.values, {you, recent, stats}).settingsInBar,
        isTrue,
        reason: 'the Settings tab shows',
      );
    });

    test('unreadable JSON gives the defaults', () {
      for (final json in ['', 'not json', '[]', '{"order": "library"}']) {
        expect(
          HomeTabLayout.decode(json).visible,
          HomeTabLayout.defaults().visible,
          reason: json,
        );
      }
    });
  });

  group('StartupScreen', () {
    test('every tab has a startup screen of the same name', () {
      for (final tab in HomeTab.values) {
        expect(StartupScreen.forTab(tab).tab, tab);
      }
    });

    test('the last-read book opens over Library', () {
      expect(StartupScreen.lastRead.tab, library);
    });
  });
}
