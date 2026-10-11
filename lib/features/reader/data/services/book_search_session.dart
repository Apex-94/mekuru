import 'package:flutter/foundation.dart';
import 'package:mekuru/features/reader/data/models/epub_models.dart';

enum BookSearchStatus {
  idle,
  searching,
  done,

  /// Stopped at the bridge's hit limit.
  capped,

  /// The viewer was rebuilt mid-search, which ended it.
  interrupted,
}

/// One match found by `searchBook` in reader_bridge.js.
class BookSearchHit {
  const BookSearchHit({
    required this.cfi,
    required this.chapter,
    required this.before,
    required this.match,
    required this.after,
  });

  final String cfi;

  /// '' when the table of contents names no chapter for it.
  final String chapter;

  /// The text around [match], for the results list.
  final String before;
  final String match;
  final String after;
}

/// The reader's in-book search: the query, the hits streamed in chapter by
/// chapter, and where the results list was left, kept while the reader is
/// open so reopening the list shows them again.
class BookSearchSession extends ChangeNotifier {
  BookSearchSession(this._send, {this.onFinished});

  /// Starts `searchBook(id, query)` in the bridge (see there).
  final void Function(int id, String query) _send;

  /// A search ran to the end (done or capped) with [hits] matches.
  final void Function(BookSearchStatus status, int hits)? onFinished;

  int _id = 0;

  String query = '';
  BookSearchStatus status = BookSearchStatus.idle;
  final List<BookSearchHit> hits = [];

  /// The share of chapters searched so far; null before the first.
  double? progress;

  /// The hit opened last, and the results list's scroll offset.
  int? lastOpened;
  double listOffset = 0;

  void start(String text) {
    query = text.trim();
    _id++;
    hits.clear();
    progress = null;
    lastOpened = null;
    listOffset = 0;
    status = query.isEmpty ? BookSearchStatus.idle : BookSearchStatus.searching;
    _send(_id, query);
    notifyListeners();
  }

  /// One `searchProgress` message: a chapter's hits, or the end.
  void onProgress(Map<dynamic, dynamic> message) {
    if (message['id'] != _id || status != BookSearchStatus.searching) return;
    if (message['done'] == true) {
      status = message['capped'] == true
          ? BookSearchStatus.capped
          : BookSearchStatus.done;
      onFinished?.call(status, hits.length);
    } else {
      progress =
          (message['searched'] as num) / (message['total'] as num).toDouble();
      final found = message['hits'] as List;
      if (found.isNotEmpty) {
        // ponytail: one label per file, from its first TOC entry; hits after
        // a second chapter's anchor in the same file get the first's title.
        final toc = message['toc'];
        final chapter = toc == null ? '' : chapterTitleFromPlacement(toc);
        for (final hit in found.cast<Map>()) {
          hits.add(
            BookSearchHit(
              cfi: hit['cfi'] as String,
              chapter: chapter,
              before: hit['before'] as String,
              match: hit['match'] as String,
              after: hit['after'] as String,
            ),
          );
        }
      }
    }
    notifyListeners();
  }

  /// The viewer is being rebuilt, which ends a search in progress.
  void markInterrupted() {
    if (status != BookSearchStatus.searching) return;
    status = BookSearchStatus.interrupted;
    notifyListeners();
  }

  void resumeIfInterrupted() {
    if (status == BookSearchStatus.interrupted) start(query);
  }
}
