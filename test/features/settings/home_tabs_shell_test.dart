import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart';
import 'package:mekuru/app.dart';
import 'package:mekuru/core/database/database_provider.dart';
import 'package:mekuru/features/backup/presentation/providers/backup_providers.dart';
import 'package:mekuru/features/dictionary/presentation/screens/dictionary_search_screen.dart';
import 'package:mekuru/features/library/presentation/screens/library_screen.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:mekuru/features/stats/presentation/providers/stats_providers.dart';
import 'package:mekuru/features/vocabulary/presentation/screens/vocabulary_screen.dart';
import 'package:mekuru/main.dart' show databaseProvider;
import 'package:shared_preferences/shared_preferences.dart';

import '../../shared/test_database.dart';

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

void main() {
  late AppDatabase db;

  setUp(() => db = createTestDatabase());
  tearDown(() => db.close());

  String layout(List<HomeTab> order, Set<HomeTab> hidden) =>
      HomeTabLayout(order, hidden).encode();

  Future<void> pumpApp(
    WidgetTester tester, [
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          autoBackupCheckerProvider.overrideWith((ref) async {}),
          sessionsProvider.overrideWith((ref) => Stream.value(const [])),
          wordEventsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: const MekuruApp(),
      ),
    );
    await settle(tester);
  }

  /// A test of the whole app, unmounted at the end so the timers it starts
  /// (drift streams, startup work) run out before the test does.
  void appTest(
    String description,
    Future<void> Function(WidgetTester) body, {
    TestVariant<Object?> variant = const DefaultTestVariant(),
  }) {
    testWidgets(description, (tester) async {
      await body(tester);
      await tester.pumpWidget(const SizedBox());
      await settle(tester);
    }, variant: variant);
  }

  // The app bar's gear, not the Settings tab's own tooltip.
  final settingsGear = find.descendant(
    of: find.byType(AppBar),
    matching: find.byTooltip('Settings'),
  );

  List<String> barLabels(WidgetTester tester) => [
    for (final destination in tester.widgetList<NavigationDestination>(
      find.byType(NavigationDestination),
    ))
      destination.label,
  ];

  appTest('the bar shows the visible tabs in the saved order', (tester) async {
    await pumpApp(tester, {
      'app.home_tabs': layout(
        [HomeTab.you, HomeTab.recent, HomeTab.library, HomeTab.dictionary],
        {HomeTab.vocabulary},
      ),
    });

    expect(barLabels(tester), ['You', 'Recent', 'Library', 'Dictionary']);
    // The app still opens on Library, wherever it sits.
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(settingsGear, findsNothing, reason: 'You is in the bar');
  });

  appTest('Library alone has no bar, and a Settings gear', (tester) async {
    await pumpApp(tester, {
      'app.home_tabs': layout(HomeTab.values, {...HomeTab.values}),
    });

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(settingsGear, findsOneWidget);
  });

  appTest('a Settings tab replaces the gear', (tester) async {
    await pumpApp(tester, {
      'app.home_tabs': layout(HomeTab.values, {
        HomeTab.you,
        HomeTab.recent,
        HomeTab.stats,
        HomeTab.freeBooks,
      }),
    });

    expect(barLabels(tester), [
      'Library',
      'Dictionary',
      'Vocabulary',
      'Settings',
    ]);
    expect(settingsGear, findsNothing);
  });

  appTest('a startup screen whose tab is hidden opens Library', (tester) async {
    await pumpApp(tester, {
      'app.startup_screen': 'dictionary',
      'app.home_tabs': layout(HomeTab.values, {
        HomeTab.dictionary,
        HomeTab.recent,
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      }),
    });

    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(
      find.byType(DictionarySearchScreen, skipOffstage: false),
      findsNothing,
    );
  });

  appTest('hiding the current tab goes back to Library', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Vocabulary'));
    await tester.pump();
    expect(find.byType(VocabularyScreen), findsOneWidget);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(MekuruApp)),
    );
    final current = container.read(homeTabsProvider);
    container
        .read(homeTabsProvider.notifier)
        .setLayout(
          HomeTabLayout(current.order, {...current.hidden, HomeTab.vocabulary}),
        );
    await tester.pump();

    expect(barLabels(tester), ['Library', 'Dictionary', 'You']);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(VocabularyScreen, skipOffstage: false), findsNothing);
  });

  appTest('the Recent tab lists opened books, newest first', (tester) async {
    await tester.runAsync(() async {
      for (final (title, lastReadAt) in [
        ('Older', DateTime.now().subtract(const Duration(days: 3))),
        ('Never opened', null),
        ('Newer', DateTime.now()),
      ]) {
        await db
            .into(db.books)
            .insert(
              BooksCompanion.insert(
                title: title,
                filePath: '/unused/$title',
                lastReadAt: Value(lastReadAt),
              ),
            );
      }
    });
    await pumpApp(tester, {
      'app.home_tabs': layout(HomeTab.values, {
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      }),
    });

    await tester.tap(find.text('Recent'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    final titles = find.descendant(
      of: find.byType(ListTile),
      matching: find.textContaining(RegExp('Older|Newer|Never opened')),
    );
    expect(tester.widgetList<Text>(titles).map((text) => text.data), [
      'Newer',
      'Older',
    ]);
    expect(find.textContaining('Today'), findsOneWidget);
    expect(find.textContaining('3 days ago'), findsOneWidget);
  });

  appTest('iOS: the glass bar shows the visible tabs', (tester) async {
    await pumpApp(tester, {
      'app.home_tabs': layout(HomeTab.values, {
        HomeTab.vocabulary,
        HomeTab.recent,
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      }),
    });
    expect(find.byType(GlassTabBar), findsOneWidget);
    expect(find.text('Vocabulary'), findsNothing);
    expect(find.text('You'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  appTest('iOS: Library alone has no glass bar', (tester) async {
    await pumpApp(tester, {
      'app.home_tabs': layout(HomeTab.values, {...HomeTab.values}),
    });
    expect(find.byType(GlassTabBar), findsNothing);
    expect(settingsGear, findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
