import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekuru/features/tts/data/models/tts_playback_state.dart';
import 'package:mekuru/features/tts/data/services/tts_player_service.dart';

/// Provider for the singleton [TtsPlayerService].
final ttsPlayerServiceProvider = Provider<TtsPlayerService>((ref) {
  final service = TtsPlayerService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Riverpod notifier managing the active Japanese TTS playback state.
class TtsPlaybackNotifier extends Notifier<TtsPlaybackState> {
  @override
  TtsPlaybackState build() {
    final service = ref.watch(ttsPlayerServiceProvider);
    final subscription = service.stateStream.listen((newState) {
      state = newState;
    });
    ref.onDispose(() => subscription.cancel());
    return service.currentState;
  }

  /// Synthesizes and plays Japanese pronunciation for the given [expression] and optional [reading].
  Future<void> speak({
    required String expression,
    String? reading,
  }) async {
    final service = ref.read(ttsPlayerServiceProvider);
    await service.speak(expression: expression, reading: reading);
  }

  /// Stops current speech playback and resets state to idle.
  Future<void> stop() async {
    final service = ref.read(ttsPlayerServiceProvider);
    await service.stop();
  }
}

/// Provider for [TtsPlaybackNotifier].
final ttsPlaybackProvider =
    NotifierProvider<TtsPlaybackNotifier, TtsPlaybackState>(
      TtsPlaybackNotifier.new,
    );

/// Alias for [ttsPlaybackProvider] matching architectural design specifications.
final ttsPlaybackStateProvider = ttsPlaybackProvider;
