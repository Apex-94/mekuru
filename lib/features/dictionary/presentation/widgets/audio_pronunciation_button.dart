import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:mekuru/l10n/l10n.dart';
import '../../data/models/word_audio_models.dart';
import '../providers/word_audio_providers.dart';

/// An action button that plays native audio pronunciation or TTS for a word.
///
/// Reactively displays:
/// - Loading spinner while resolving/downloading audio
/// - Filled primary icon while actively playing
/// - Error icon if playback fails or audio is unavailable
/// - Outlined speaker icon when idle
class AudioPronunciationButton extends ConsumerWidget {
  final String expression;
  final String? reading;
  final double iconSize;
  final EdgeInsetsGeometry? padding;
  final VisualDensity? visualDensity;

  const AudioPronunciationButton({
    super.key,
    required this.expression,
    this.reading,
    this.iconSize = 20,
    this.padding,
    this.visualDensity,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playbackState = ref.watch(wordAudioPlaybackProvider);
    final theme = Theme.of(context);
    final l10n = context.l10n;

    final exp = expression.trim();
    final read = (reading ?? '').trim();

    final isThisWordPlaying = playbackState.isPlayingWord(exp, read);
    final isThisWordLoading = playbackState.isLoadingWord(exp, read);
    final isThisWordError = playbackState.status == AudioPlaybackStatus.error &&
        playbackState.expression == exp &&
        (playbackState.reading ?? '') == read;

    Widget iconWidget;
    String tooltip;

    if (isThisWordLoading) {
      iconWidget = SizedBox.square(
        dimension: iconSize * 0.9,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: theme.colorScheme.primary,
        ),
      );
      tooltip = l10n.dictionaryPlayAudioTooltip;
    } else if (isThisWordPlaying) {
      iconWidget = Icon(
        Icons.volume_up_rounded,
        size: iconSize,
        color: theme.colorScheme.primary,
      );
      tooltip = l10n.dictionaryPlayAudioTooltip;
    } else if (isThisWordError) {
      iconWidget = Icon(
        Icons.volume_off_outlined,
        size: iconSize,
        color: theme.colorScheme.error,
      );
      tooltip = playbackState.errorMessage ?? l10n.dictionaryAudioErrorTooltip;
    } else {
      iconWidget = Icon(
        Icons.volume_up_outlined,
        size: iconSize,
      );
      tooltip = l10n.dictionaryPlayAudioTooltip;
    }

    return IconButton(
      onPressed: () {
        ref.read(wordAudioPlaybackProvider.notifier).playWord(
              expression: exp,
              reading: read,
            );
      },
      icon: iconWidget,
      tooltip: tooltip,
      iconSize: iconSize,
      padding: padding,
      visualDensity: visualDensity,
    );
  }
}
