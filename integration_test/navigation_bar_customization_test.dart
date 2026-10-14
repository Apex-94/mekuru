import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:mekuru/core/database/database_provider.dart';
import 'package:mekuru/l10n/generated/app_localizations.dart';

import 'shared/test_infrastructure.dart';
import 'test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late AppLocalizations l10n;

  setUp(() async {
    l10n = await loadExpectedL10n();
  });

  Finder editorRow(String label) => find.widgetWithText(ListTile, label);

  Future<void> toggle(WidgetTester tester, String label) async {
    await tester.tap(
      find.descendant(of: editorRow(label), matching: find.byType(Switch)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('hide, show and move tabs from Settings', (tester) async {
    final db = createTestDatabase();
    addTearDown(db.close);
    await db
        .into(db.books)
        .insert(
          BooksCompanion.insert(
            title: 'Opened yesterday',
            filePath: '/fake/opened.epub',
            lastReadAt: Value(DateTime.now().subtract(const Duration(days: 1))),
          ),
        );

    await tester.pumpWidget(buildIntegrationTestRealApp(db: db));
    await pumpUntilVisible(
      tester,
      mainTabBar,
      timeout: const Duration(seconds: 15),
    );

    // You > Settings > Navigation bar.
    await tester.tap(mainTab(l10n.navYou));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(l10n.settingsNavBarTitle));
    await tester.pumpAndSettle();

    await toggle(tester, l10n.navVocabulary);
    await toggle(tester, l10n.navRecent);

    // Drag Recent above Library.
    final handle = find.descendant(
      of: editorRow(l10n.navRecent),
      matching: find.byIcon(Icons.drag_handle),
    );
    final libraryHandle = find.descendant(
      of: editorRow(l10n.navLibrary),
      matching: find.byIcon(Icons.drag_handle),
    );
    final start = tester.getCenter(handle);
    // A row above Library's centre.
    final end =
        tester.getCenter(libraryHandle) -
        Offset(0, tester.getSize(editorRow(l10n.navLibrary)).height);
    await tester.timedDragFrom(
      start,
      end - start,
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();
    expect(
      tester.getCenter(editorRow(l10n.navRecent)).dy,
      lessThan(tester.getCenter(editorRow(l10n.navLibrary)).dy),
    );

    // Back in Settings, the hidden Vocabulary opens from Hidden tabs.
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.text(l10n.settingsSectionHiddenTabs), findsOneWidget);
    await tester.tap(find.text(l10n.navVocabulary));
    await pumpUntilVisible(tester, find.text(l10n.vocabularyEmptyTitle));
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.pageBack();
    await tester.pumpAndSettle();

    // The bar: Recent first, no Vocabulary.
    expect(
      find.descendant(of: mainTabBar, matching: find.text(l10n.navVocabulary)),
      findsNothing,
    );
    expect(
      tester.getCenter(mainTab(l10n.navRecent)).dx,
      lessThan(tester.getCenter(mainTab(l10n.navLibrary)).dx),
    );

    await tester.tap(mainTab(l10n.navRecent));
    await pumpUntilVisible(tester, find.text('Opened yesterday'));
    expect(find.text(l10n.recentlyReadTitle), findsOneWidget);
  });
}
