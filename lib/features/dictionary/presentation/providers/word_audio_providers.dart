import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/word_audio_models.dart';
import '../../data/services/word_audio_cache_manager.dart';
import '../../data/services/word_audio_player_service.dart';

/// Provider for the [WordAudioCacheManager] singleton.
final wordAudioCacheManagerProvider = Provider<WordAudioCacheManager>((ref) {
  return WordAudioCacheManager();
});

/// Provider for the [WordAudioPlayerService].
/// Disposes the underlying audio player and TTS resources when destroyed.
final wordAudioPlayerServiceProvider = Provider<WordAudioPlayerService>((ref) {
  final cacheManager = ref.watch(wordAudioCacheManagerProvider);
  final service = WordAudioPlayerService(cacheManager: cacheManager);
  ref.onDispose(service.dispose);
  return service;
});

/// Notifier managing active word pronunciation playback state.
class WordAudioPlaybackNotifier extends Notifier<AudioPlaybackState> {
  @override
  AudioPlaybackState build() {
    final service = ref.watch(wordAudioPlayerServiceProvider);

    // Synchronize state with native playback events
    final subscription = service.playbackStateStream.listen((playbackState) {
      state = playbackState;
    });
    ref.onDispose(subscription.cancel);

    return service.currentState;
  }

  /// Initiates pronunciation for [expression] and [reading].
  ///
  /// If the word is already playing or loading, toggles playback off (stop).
  Future<void> playWord({
    required String expression,
    String? reading,
  }) async {
    final exp = expression.trim();
    final read = (reading ?? '').trim();

    if (state.isPlayingWord(exp, read) || state.isLoadingWord(exp, read)) {
      await stop();
      return;
    }

    await ref.read(wordAudioPlayerServiceProvider).play(
          expression: exp,
          reading: read,
        );
  }

  /// Stops any ongoing audio or speech playback.
  Future<void> stop() async {
    await ref.read(wordAudioPlayerServiceProvider).stop();
  }
}

/// Global provider for audio pronunciation playback state.
final wordAudioPlaybackProvider =
    NotifierProvider<WordAudioPlaybackNotifier, AudioPlaybackState>(
  WordAudioPlaybackNotifier.new,
);
