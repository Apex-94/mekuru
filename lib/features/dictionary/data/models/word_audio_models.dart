/// Pure Dart models for Japanese word audio pronunciation and playback.
///
/// Contains playback status, playback state, and resolved audio source models.
/// Keeps pure-logic separation free of Flutter UI widget imports.
library;

/// The current status of audio pronunciation playback.
enum AudioPlaybackStatus {
  idle,
  loading,
  playing,
  error,
}

/// Active playback state snapshot.
class AudioPlaybackState {
  final AudioPlaybackStatus status;
  final String? expression;
  final String? reading;
  final String? errorMessage;

  const AudioPlaybackState({
    required this.status,
    this.expression,
    this.reading,
    this.errorMessage,
  });

  const AudioPlaybackState.idle()
      : status = AudioPlaybackStatus.idle,
        expression = null,
        reading = null,
        errorMessage = null;

  bool isPlayingWord(String exp, String? read) =>
      status == AudioPlaybackStatus.playing &&
      expression == exp &&
      (reading ?? '') == (read ?? '');

  bool isLoadingWord(String exp, String? read) =>
      status == AudioPlaybackStatus.loading &&
      expression == exp &&
      (reading ?? '') == (read ?? '');

  AudioPlaybackState copyWith({
    AudioPlaybackStatus? status,
    String? expression,
    String? reading,
    String? errorMessage,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      expression: expression ?? this.expression,
      reading: reading ?? this.reading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AudioPlaybackState &&
          runtimeType == other.runtimeType &&
          status == other.status &&
          expression == other.expression &&
          reading == other.reading &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode => Object.hash(status, expression, reading, errorMessage);

  @override
  String toString() =>
      'AudioPlaybackState(status: $status, expression: $expression, reading: $reading, error: $errorMessage)';
}

/// The origin tier of resolved audio.
enum WordAudioSourceType {
  /// Audio file retrieved from local disk cache (`<appSupport>/audio_cache/`).
  localCache,

  /// Audio stream/download from remote audio endpoint (JapanesePod101).
  onlineEndpoint,

  /// Synthesized speech using native on-device TTS (ja-JP).
  ttsFallback,
}

/// Resolved word audio metadata prior to playback.
class ResolvedWordAudio {
  final WordAudioSourceType sourceType;
  final String? filePath;
  final String? url;
  final String? ttsText;

  const ResolvedWordAudio({
    required this.sourceType,
    this.filePath,
    this.url,
    this.ttsText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedWordAudio &&
          runtimeType == other.runtimeType &&
          sourceType == other.sourceType &&
          filePath == other.filePath &&
          url == other.url &&
          ttsText == other.ttsText;

  @override
  int get hashCode => Object.hash(sourceType, filePath, url, ttsText);

  @override
  String toString() =>
      'ResolvedWordAudio(sourceType: $sourceType, filePath: $filePath, url: $url, ttsText: $ttsText)';
}
