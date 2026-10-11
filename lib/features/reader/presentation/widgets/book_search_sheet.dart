import 'package:flutter/material.dart';
import 'package:mekuru/features/reader/data/services/book_search_session.dart';
import 'package:mekuru/l10n/l10n.dart';

/// Opens in-book search over the reader. Tapping a hit closes it and passes
/// the hit to [onOpenHit].
Future<void> showBookSearchSheet(
  BuildContext context, {
  required BookSearchSession session,
  required ValueChanged<BookSearchHit> onOpenHit,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) =>
        BookSearchSheet(session: session, onOpenHit: onOpenHit),
  );
}

/// A search field over the hits [session] finds, which stream in chapter by
/// chapter. The session outlives the sheet, so reopening it shows the same
/// results where the list was left.
class BookSearchSheet extends StatefulWidget {
  const BookSearchSheet({
    super.key,
    required this.session,
    required this.onOpenHit,
  });

  final BookSearchSession session;
  final ValueChanged<BookSearchHit> onOpenHit;

  @override
  State<BookSearchSheet> createState() => _BookSearchSheetState();
}

class _BookSearchSheetState extends State<BookSearchSheet> {
  late final _query = TextEditingController(text: widget.session.query);
  late final ScrollController _list = ScrollController(
    initialScrollOffset: widget.session.listOffset,
  )..addListener(() => widget.session.listOffset = _list.offset);

  @override
  void dispose() {
    _query.dispose();
    _list.dispose();
    super.dispose();
  }

  void _open(int index) {
    final session = widget.session;
    session.lastOpened = index;
    Navigator.pop(context);
    widget.onOpenHit(session.hits[index]);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final media = MediaQuery.of(context);
    return Padding(
      padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
      child: SizedBox(
        height: media.size.height * 0.85,
        child: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) {
            final session = widget.session;
            final hits = session.hits;
            final searching = session.status == BookSearchStatus.searching;
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                  child: TextField(
                    controller: _query,
                    autofocus: session.query.isEmpty,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: l10n.readerSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: l10n.commonClearSearch,
                        onPressed: () {
                          _query.clear();
                          session.start('');
                        },
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: session.start,
                  ),
                ),
                if (searching) LinearProgressIndicator(value: session.progress),
                if (hits.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        session.status == BookSearchStatus.capped
                            ? l10n.readerSearchResultsCapped(count: hits.length)
                            : l10n.readerSearchResultCount(count: hits.length),
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ),
                  ),
                const Divider(height: 1),
                Expanded(
                  child: hits.isEmpty && session.status == BookSearchStatus.done
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(
                              l10n.readerSearchNoResults,
                              textAlign: TextAlign.center,
                            ),
                          ),
                        )
                      : ListView.builder(
                          controller: _list,
                          itemCount: hits.length,
                          itemBuilder: (context, index) {
                            final hit = hits[index];
                            return ListTile(
                              selected: index == session.lastOpened,
                              title: Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(text: hit.before),
                                    TextSpan(
                                      text: hit.match,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    TextSpan(text: hit.after),
                                  ],
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle: hit.chapter.isEmpty
                                  ? null
                                  : Text(
                                      hit.chapter,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                              onTap: () => _open(index),
                            );
                          },
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
