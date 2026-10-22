import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekuru/features/tts/data/models/tts_playback_state.dart';
import 'package:mekuru/features/tts/presentation/providers/tts_providers.dart';
import 'package:mekuru/l10n/l10n.dart';

/// Style variant for [TtsPronunciationButton].
enum TtsButtonVariant {
  /// Standard IconButton matching Copy and Anki action buttons.
  standard,

  /// Filled tonal IconButton matching bookmark / filled action buttons.
  tonal,

  /// Compact icon button with reduced padding for headers and dense list tiles.
  compact,
}

/// Reusable pronunciation speaker button that triggers on-device Japanese TTS.
class TtsPronunciationButton extends ConsumerWidget {
  const TtsPronunciationButton({
    super.key,
    required this.expression,
    this.reading,
    this.variant = TtsButtonVariant.standard,
    this.iconSize = 20.0,
    this.padding,
    this.tooltip,
  });

  /// The dictionary expression / kanji headword.
  final String expression;

  /// The optional kana reading (prioritized for phonetic accuracy).
  final String? reading;

  /// Visual variant of the button.
  final TtsButtonVariant variant;

  /// Icon size in logical pixels.
  final double iconSize;

  /// Custom padding for the button.
  final EdgeInsetsGeometry? padding;

  /// Custom tooltip override.
  final String? tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final playbackState = ref.watch(ttsPlaybackProvider);

    final isPlaying = playbackState.isPlayingWord(
      expression: expression,
      reading: reading,
    );

    final isThisWordError =
        playbackState.hasError && playbackState.expression == expression;

    ref.listen<TtsPlaybackState>(ttsPlaybackProvider, (prev, next) {
      if (next.hasError &&
          next.expression == expression &&
          prev?.status != TtsPlaybackStatus.error) {
        final messenger = ScaffoldMessenger.maybeOf(context);
        messenger?.removeCurrentSnackBar();
        messenger?.showSnackBar(
          SnackBar(
            content: Text(
              next.errorMessage?.isNotEmpty == true
                  ? l10n.ttsLanguageNotSupported
                  : l10n.dictionaryAudioErrorTooltip,
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    });

    final Widget icon;
    final String effectiveTooltip;
    final VoidCallback onPressed;

    if (isPlaying) {
      icon = Icon(
        Icons.volume_up,
        color: theme.colorScheme.primary,
        size: iconSize,
      );
      effectiveTooltip = l10n.dictionaryStopAudioTooltip;
      onPressed = () {
        HapticFeedback.lightImpact();
        ref.read(ttsPlaybackProvider.notifier).stop();
      };
    } else if (isThisWordError) {
      icon = Icon(
        Icons.volume_off_outlined,
        color: theme.colorScheme.error,
        size: iconSize,
      );
      effectiveTooltip = l10n.dictionaryAudioErrorTooltip;
      onPressed = () {
        HapticFeedback.lightImpact();
        ref.read(ttsPlaybackProvider.notifier).speak(
              expression: expression,
              reading: reading,
            );
      };
    } else {
      icon = Icon(
        Icons.volume_up_outlined,
        color: theme.colorScheme.onSurfaceVariant,
        size: iconSize,
      );
      effectiveTooltip = tooltip ?? l10n.dictionaryPlayAudioTooltip;
      onPressed = () {
        HapticFeedback.lightImpact();
        ref.read(ttsPlaybackProvider.notifier).speak(
              expression: expression,
              reading: reading,
            );
      };
    }

    switch (variant) {
      case TtsButtonVariant.standard:
        return IconButton(
          onPressed: onPressed,
          icon: icon,
          iconSize: iconSize,
          padding: padding,
          tooltip: effectiveTooltip,
        );
      case TtsButtonVariant.tonal:
        return IconButton.filledTonal(
          onPressed: onPressed,
          icon: icon,
          iconSize: iconSize,
          padding: padding,
          tooltip: effectiveTooltip,
        );
      case TtsButtonVariant.compact:
        return IconButton(
          onPressed: onPressed,
          icon: icon,
          iconSize: iconSize,
          padding: padding ?? EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          visualDensity: VisualDensity.compact,
          tooltip: effectiveTooltip,
        );
    }
  }
}
