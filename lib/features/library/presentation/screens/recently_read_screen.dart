import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekuru/core/database/database_provider.dart';
import 'package:mekuru/features/library/presentation/providers/library_providers.dart';
import 'package:mekuru/features/library/presentation/widgets/book_cover_image.dart';
import 'package:mekuru/l10n/l10n.dart';
import 'package:mekuru/shared/utils/app_routes.dart';
import 'package:mekuru/shared/widgets/glass_tab_bar.dart';

/// The Recent tab: every book the user has opened, most recent first,
/// across folders and collections.
class RecentlyReadScreen extends ConsumerWidget {
  const RecentlyReadScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final books = ref.watch(recentlyReadBooksProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.recentlyReadTitle)),
      body: switch (books) {
        null => const Center(child: CircularProgressIndicator()),
        [] => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(l10n.recentlyReadEmpty, textAlign: TextAlign.center),
          ),
        ),
        _ => ListView.builder(
          padding: EdgeInsets.only(
            top: 8,
            bottom: 8 + glassTabBarInset(context),
          ),
          itemCount: books.length,
          itemBuilder: (context, i) => _RecentBookTile(book: books[i]),
        ),
      },
    );
  }
}

class _RecentBookTile extends StatelessWidget {
  const _RecentBookTile({required this.book});

  final Book book;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final progress = book.readProgress.clamp(0.0, 1.0);
    return ListTile(
      leading: SizedBox(
        width: 40,
        height: 56,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: BookCoverImage(book: book),
        ),
      ),
      title: Text(book.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${(progress * 100).round()}% · '
        '${l10n.recentlyReadDaysAgo(count: _daysBefore(book.lastReadAt!, DateTime.now()))}',
        style: theme.textTheme.bodySmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
      onTap: () => openBookReader(Navigator.of(context), book),
    );
  }
}

/// Calendar days from [then] to [now] in local time: 0 today, 1 yesterday,
/// never negative (a clock set back). Counted on UTC dates so a
/// daylight-saving change never loses a day.
int _daysBefore(DateTime then, DateTime now) {
  final a = then.toLocal();
  final b = now.toLocal();
  final days = DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  return days < 0 ? 0 : days;
}
