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

/// The origin tier of resolved word audio.
enum WordAudioSourceType {
  /// Local audio file from installed Japanese audio pack.
  downloadedPack,

  /// Synthesized speech using native on-device TTS (ja-JP).
  ttsFallback,
}

/// Active playback state snapshot.
class AudioPlaybackState {
  final AudioPlaybackStatus status;
  final String? expression;
  final String? reading;
  final WordAudioSourceType? sourceType;
  final String? errorMessage;

  const AudioPlaybackState({
    required this.status,
    this.expression,
    this.reading,
    this.sourceType,
    this.errorMessage,
  });

  const AudioPlaybackState.idle()
      : status = AudioPlaybackStatus.idle,
        expression = null,
        reading = null,
        sourceType = null,
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
    WordAudioSourceType? sourceType,
    String? errorMessage,
  }) {
    return AudioPlaybackState(
      status: status ?? this.status,
      expression: expression ?? this.expression,
      reading: reading ?? this.reading,
      sourceType: sourceType ?? this.sourceType,
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
          sourceType == other.sourceType &&
          errorMessage == other.errorMessage;

  @override
  int get hashCode =>
      Object.hash(status, expression, reading, sourceType, errorMessage);

  @override
  String toString() =>
      'AudioPlaybackState(status: $status, expression: $expression, reading: $reading, source: $sourceType, error: $errorMessage)';
}

/// Resolved word audio metadata prior to playback.
class ResolvedWordAudio {
  final WordAudioSourceType sourceType;
  final String? filePath;
  final String? ttsText;

  const ResolvedWordAudio({
    required this.sourceType,
    this.filePath,
    this.ttsText,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ResolvedWordAudio &&
          runtimeType == other.runtimeType &&
          sourceType == other.sourceType &&
          filePath == other.filePath &&
          ttsText == other.ttsText;

  @override
  int get hashCode => Object.hash(sourceType, filePath, ttsText);

  @override
  String toString() =>
      'ResolvedWordAudio(sourceType: $sourceType, filePath: $filePath, ttsText: $ttsText)';
}
