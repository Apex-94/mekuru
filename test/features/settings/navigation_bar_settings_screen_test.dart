import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:mekuru/features/settings/presentation/screens/navigation_bar_settings_screen.dart';
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
  }) async {
    SharedPreferences.setMockInitialValues({
      'app.home_tabs': HomeTabLayout(HomeTab.values, hidden).encode(),
    });
    container = ProviderContainer();
    addTearDown(container.dispose);
    await container.read(homeTabsProvider.notifier).loadPersistedSettings();
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: buildLocalizedTestApp(home: const NavigationBarSettingsScreen()),
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

  testWidgets('hiding Dictionary and Vocabulary explains what stays', (
    tester,
  ) async {
    await pumpEditor(tester);
    expect(
      find.text('Lookups while reading still work without this tab.'),
      findsOneWidget,
    );
    expect(
      find.text(
        'Saved words are kept, but the list and CSV export are only in this tab.',
      ),
      findsOneWidget,
    );
  });
}
