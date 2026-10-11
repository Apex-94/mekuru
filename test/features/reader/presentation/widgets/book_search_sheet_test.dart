import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/reader/data/services/book_search_session.dart';
import 'package:mekuru/features/reader/presentation/widgets/book_search_sheet.dart';
import 'package:mekuru/l10n/generated/app_localizations_en.dart';

import '../../../../test_app.dart';

const _toc = '{"spine":1,"toc":[["第二章",1,false]]}';

Map<String, Object?> _hit(int n) => {
  'cfi': 'epubcfi(/6/4!/4/$n/1,:0,:3)',
  'before': '前の文$n',
  'match': '羅生門',
  'after': 'が見える。',
};

void main() {
  final en = AppLocalizationsEn();
  late List<String> queries;
  late BookSearchSession session;
  late List<BookSearchHit> opened;

  setUp(() {
    queries = [];
    opened = [];
    session = BookSearchSession((id, query) => queries.add(query));
  });

  tearDown(() => session.dispose());

  /// Opens the sheet from a button, as the reader does, so a tap on a hit
  /// has a route to close.
  Future<void> openSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      buildLocalizedTestApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => showBookSearchSheet(
                context,
                session: session,
                onOpenHit: opened.add,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    // Not pumpAndSettle: a search's progress bar never settles.
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('searches for the submitted text', (tester) async {
    await openSheet(tester);
    await tester.enterText(find.byType(TextField), '羅生門');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();

    expect(queries, ['羅生門']);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
  });

  testWidgets('lists hits as they arrive and opens the one tapped', (
    tester,
  ) async {
    session.start('羅生門');
    await openSheet(tester);
    session.onProgress({
      'id': 1,
      'searched': 1,
      'total': 2,
      'hits': [_hit(2), _hit(4)],
      'toc': _toc,
    });
    await tester.pump();

    expect(find.text(en.readerSearchResultCount(count: 2)), findsOneWidget);
    expect(find.text('第二章'), findsNWidgets(2));
    TextSpan? match;
    tester
        .widget<RichText>(find.textContaining('前の文4', findRichText: true))
        .text
        .visitChildren((span) {
          if (span is TextSpan && span.text == '羅生門') match = span;
          return match == null;
        });
    expect(match?.style?.fontWeight, FontWeight.bold);

    await tester.tap(find.textContaining('前の文4', findRichText: true));
    await tester.pumpAndSettle();
    expect(opened.single.cfi, 'epubcfi(/6/4!/4/4/1,:0,:3)');
    expect(session.lastOpened, 1);
    expect(find.byType(TextField), findsNothing, reason: 'the sheet closes');
  });

  testWidgets('says when nothing matched', (tester) async {
    session.start('無い');
    session.onProgress({'id': 1, 'done': true, 'capped': false});
    await openSheet(tester);

    expect(find.text(en.readerSearchNoResults), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('says when the results stopped at the limit', (tester) async {
    session.start('の');
    session.onProgress({
      'id': 1,
      'searched': 1,
      'total': 1,
      'hits': [_hit(2)],
      'toc': _toc,
    });
    session.onProgress({'id': 1, 'done': true, 'capped': true});
    await openSheet(tester);

    expect(find.text(en.readerSearchResultsCapped(count: 1)), findsOneWidget);
  });
}
