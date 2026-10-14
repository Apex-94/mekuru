import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekuru/features/settings/data/models/home_tab_layout.dart';
import 'package:mekuru/features/settings/presentation/providers/app_settings_providers.dart';
import 'package:mekuru/features/settings/presentation/widgets/home_tab_ui.dart';
import 'package:mekuru/l10n/generated/app_localizations.dart';
import 'package:mekuru/l10n/l10n.dart';
import 'package:mekuru/shared/utils/haptics.dart';

/// Settings > Navigation bar: which tabs the bottom bar shows, in what
/// order. Changes apply at once.
class NavigationBarSettingsScreen extends ConsumerWidget {
  const NavigationBarSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final layout = ref.watch(homeTabsProvider);
    final notifier = ref.read(homeTabsProvider.notifier);
    final full = layout.visible.length >= maxVisibleHomeTabs;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsNavBarTitle)),
      body: ReorderableListView.builder(
        header: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            l10n.navBarEditorHint,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        padding: const EdgeInsets.only(bottom: 8),
        itemCount: layout.order.length,
        onReorderItem: (oldIndex, newIndex) {
          final order = List.of(layout.order);
          order.insert(newIndex, order.removeAt(oldIndex));
          notifier.setLayout(HomeTabLayout(order, layout.hidden));
        },
        itemBuilder: (context, index) {
          final tab = layout.order[index];
          final shown = !layout.hidden.contains(tab);
          final note = _note(l10n, tab);
          return ListTile(
            key: ValueKey(tab),
            leading: ReorderableDragStartListener(
              index: index,
              child: const Icon(Icons.drag_handle),
            ),
            title: Row(
              children: [
                Icon(tab.icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Flexible(child: Text(tab.label(l10n))),
              ],
            ),
            subtitle: note == null ? null : Text(note),
            trailing: Switch(
              value: shown,
              onChanged: tab == HomeTab.library || (!shown && full)
                  ? null
                  : (value) {
                      AppHaptics.light();
                      notifier.setLayout(
                        HomeTabLayout(
                          layout.order,
                          value
                              ? ({...layout.hidden}..remove(tab))
                              : {...layout.hidden, tab},
                        ),
                      );
                    },
            ),
          );
        },
      ),
    );
  }

  /// The tabs whose switch needs a word of explanation.
  static String? _note(AppLocalizations l10n, HomeTab tab) => switch (tab) {
    HomeTab.library => l10n.navBarLibraryNote,
    HomeTab.you => l10n.navBarYouNote,
    _ => null,
  };
}
