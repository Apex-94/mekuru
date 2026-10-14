import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:mekuru/features/settings/presentation/screens/navigation_bar_settings_screen.dart';
import 'package:mekuru/features/settings/presentation/screens/settings_screen.dart';
import 'package:mekuru/features/stats/presentation/providers/stats_providers.dart';
import 'package:mekuru/features/stats/presentation/screens/stats_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../test_app.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpEditor(
    WidgetTester tester, {
    Set<HomeTab> hidden = const {
      HomeTab.recent,
      HomeTab.stats,
      HomeTab.freeBooks,
      HomeTab.settings,
    },
    Widget home = const NavigationBarSettingsScreen(),
  }) async {
    SharedPreferences.setMockInitialValues({
      'app.home_tabs': HomeTabLayout(HomeTab.values, hidden).encode(),
    });
    container = ProviderContainer(
      overrides: [
        sessionsProvider.overrideWith((ref) => Stream.value(const [])),
        wordEventsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    addTearDown(container.dispose);
    await container.read(homeTabsProvider.notifier).loadPersistedSettings();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildLocalizedTestApp(home: home),
      ),
    );
    await tester.pumpAndSettle();
  }

  Finder switchFor(String label) => find.descendant(
    of: find.widgetWithText(ListTile, label),
    matching: find.byType(Switch),
  );

  Switch switchOf(WidgetTester tester, String label) =>
      tester.widget<Switch>(switchFor(label));

  Future<void> toggle(WidgetTester tester, String label) async {
    await tester.tap(switchFor(label));
    await tester.pumpAndSettle();
  }

  testWidgets('showing a tab saves the layout', (tester) async {
    await pumpEditor(tester);
    await toggle(tester, 'Recent');

    expect(container.read(homeTabsProvider).visible, [
      HomeTab.library,
      HomeTab.dictionary,
      HomeTab.vocabulary,
      HomeTab.you,
      HomeTab.recent,
    ]);
    final prefs = await SharedPreferences.getInstance();
    expect(
      HomeTabLayout.decode(prefs.getString('app.home_tabs')).visible,
      contains(HomeTab.recent),
    );
  });

  testWidgets('Library cannot be hidden', (tester) async {
    await pumpEditor(tester);
    expect(switchOf(tester, 'Library').value, isTrue);
    expect(switchOf(tester, 'Library').onChanged, isNull);
    expect(find.text('Always shown'), findsOneWidget);
  });

  testWidgets('with five tabs shown, the others cannot be turned on', (
    tester,
  ) async {
    await pumpEditor(
      tester,
      hidden: {HomeTab.stats, HomeTab.freeBooks, HomeTab.settings},
    );
    expect(switchOf(tester, 'Stats').onChanged, isNull);
    expect(switchOf(tester, 'Recent').onChanged, isNotNull);

    await toggle(tester, 'Recent');
    expect(switchOf(tester, 'Stats').onChanged, isNotNull);
  });

  testWidgets('hiding the startup tab sets the startup screen to Library', (
    tester,
  ) async {
    await pumpEditor(tester);
    container
        .read(startupScreenProvider.notifier)
        .setStartupScreen(StartupScreen.vocabulary);

    await toggle(tester, 'Vocabulary');

    expect(container.read(startupScreenProvider), StartupScreen.library);
  });

  testWidgets('the hint says where hidden tabs go', (tester) async {
    await pumpEditor(tester);
    expect(
      find.textContaining('Hidden tabs open from Settings.'),
      findsOneWidget,
    );
  });

  group('Settings lists the pages the bar no longer leads to', () {
    Future<void> pumpSettings(WidgetTester tester, Set<HomeTab> hidden) =>
        pumpEditor(tester, hidden: hidden, home: const SettingsScreen());

    final section = find.text('Hidden tabs');

    testWidgets('Recent, by default', (tester) async {
      await pumpSettings(tester, {
        HomeTab.recent,
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      });
      expect(section, findsOneWidget);
      expect(find.text('Recently read'), findsOneWidget);
      // You still links them.
      expect(find.text('Reading stats'), findsNothing);
    });

    testWidgets("You's pages once You is hidden, and they open", (
      tester,
    ) async {
      await pumpSettings(tester, {
        HomeTab.vocabulary,
        HomeTab.you,
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      });
      expect(find.text('Vocabulary'), findsOneWidget);
      expect(find.text('Free books'), findsOneWidget);

      await tester.tap(find.text('Reading stats'));
      await tester.pumpAndSettle();
      expect(find.byType(StatsScreen), findsOneWidget);
    });

    testWidgets('no section when every page is in the bar', (tester) async {
      await pumpSettings(tester, {
        HomeTab.stats,
        HomeTab.freeBooks,
        HomeTab.settings,
      });
      expect(section, findsNothing);
    });
  });
}
