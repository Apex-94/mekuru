import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/reader/data/services/book_search_session.dart';

// A tocPlacement result naming 第二章 for spine item 1.
const _toc = '{"spine":1,"toc":[["第一章",0,false],["第二章",1,null]]}';

Map<String, Object?> _hit(String match) => {
  'cfi': 'epubcfi(/6/4!/4/2/1,:0,:${match.length})',
  'before': '前',
  'match': match,
  'after': '後',
};

void main() {
  late List<(int, String)> sent;
  late List<(BookSearchStatus, int)> finished;
  late BookSearchSession session;

  setUp(() {
    sent = [];
    finished = [];
    session = BookSearchSession(
      (id, query) => sent.add((id, query)),
      onFinished: (status, hits) => finished.add((status, hits)),
    );
  });

  tearDown(() => session.dispose());

  test('streams hits in, labelled with their chapter', () {
    session.start(' 羅生門 ');
    expect(sent, [(1, '羅生門')]);
    expect(session.status, BookSearchStatus.searching);

    session.onProgress({'id': 1, 'searched': 1, 'total': 2, 'hits': []});
    session.onProgress({
      'id': 1,
      'searched': 2,
      'total': 2,
      'hits': [_hit('羅生門'), _hit('羅生門')],
      'toc': _toc,
    });
    expect(session.hits, hasLength(2));
    expect(session.hits.first.chapter, '第二章');
    expect(session.hits.first.match, '羅生門');
    expect(session.progress, 1.0);

    session.onProgress({'id': 1, 'done': true, 'capped': false});
    expect(session.status, BookSearchStatus.done);
    expect(finished, [(BookSearchStatus.done, 2)]);
  });

  test('ignores messages from a search it replaced', () {
    session.start('一');
    session.start('二');
    session.onProgress({
      'id': 1,
      'searched': 1,
      'total': 1,
      'hits': [_hit('一')],
      'toc': _toc,
    });
    session.onProgress({'id': 1, 'done': true, 'capped': false});
    expect(session.hits, isEmpty);
    expect(session.status, BookSearchStatus.searching);
    expect(finished, isEmpty);
  });

  test('reports a capped search', () {
    session.start('の');
    session.onProgress({'id': 1, 'done': true, 'capped': true});
    expect(session.status, BookSearchStatus.capped);
  });

  test('an empty query stops the search without starting one', () {
    session.start('一');
    session.start('  ');
    expect(sent.last, (2, ''));
    expect(session.status, BookSearchStatus.idle);
  });

  test('an interrupted search is run again', () {
    session.start('一');
    session.onProgress({
      'id': 1,
      'searched': 1,
      'total': 3,
      'hits': [_hit('一')],
      'toc': _toc,
    });
    session.markInterrupted();
    expect(session.status, BookSearchStatus.interrupted);

    session.resumeIfInterrupted();
    expect(sent.last, (2, '一'));
    expect(session.hits, isEmpty);
    expect(session.status, BookSearchStatus.searching);
  });

  test('a finished search is not interrupted by a new viewer', () {
    session.start('一');
    session.onProgress({'id': 1, 'done': true, 'capped': false});
    session.markInterrupted();
    session.resumeIfInterrupted();
    expect(sent, hasLength(1));
    expect(session.status, BookSearchStatus.done);
  });
}
