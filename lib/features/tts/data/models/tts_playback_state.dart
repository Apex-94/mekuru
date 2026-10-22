import 'package:flutter/foundation.dart';

/// Status of the Text-To-Speech engine.
enum TtsPlaybackStatus {
  idle,
  playing,
  error,
}

/// Immutable state model representing the current state of TTS audio playback.
@immutable
class TtsPlaybackState {
  const TtsPlaybackState({
    this.status = TtsPlaybackStatus.idle,
    this.expression,
    this.reading,
    this.text,
    this.activeKey,
    this.errorMessage,
  });

  final TtsPlaybackStatus status;
  final String? expression;
  final String? reading;
  final String? text;
  final String? activeKey;
  final String? errorMessage;

  bool get isPlaying => status == TtsPlaybackStatus.playing;
  bool get isIdle => status == TtsPlaybackStatus.idle;
  bool get hasError => status == TtsPlaybackStatus.error;

  /// Returns whether a specific playback key is currently being spoken.
  bool isKeyPlaying(String key) => isPlaying && activeKey == key;

  /// Returns whether a word matching [expression] and optional [reading] is playing.
  bool isPlayingWord({required String expression, String? reading}) {
    if (!isPlaying) return false;
    final targetKey = makeKey(expression: expression, reading: reading);
    if (activeKey != null) {
      return activeKey == targetKey;
    }
    return this.expression == expression &&
        (this.reading ?? '') == (reading ?? '');
  }

  /// Constructs a deterministic key identifying an utterance by expression and reading.
  static String makeKey({required String expression, String? reading}) {
    final cleanExpr = expression.trim();
    final cleanReading = reading?.trim() ?? '';
    return '$cleanExpr#$cleanReading';
  }

  TtsPlaybackState copyWith({
    TtsPlaybackStatus? status,
    String? expression,
    String? reading,
    String? text,
    String? activeKey,
    String? errorMessage,
  }) {
    return TtsPlaybackState(
      status: status ?? this.status,
      expression: expression ?? this.expression,
      reading: reading ?? this.reading,
      text: text ?? this.text,
      activeKey: activeKey ?? this.activeKey,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TtsPlaybackState &&
        other.status == status &&
        other.expression == expression &&
        other.reading == reading &&
        other.text == text &&
        other.activeKey == activeKey &&
        other.errorMessage == errorMessage;
  }

  @override
  int get hashCode => Object.hash(
        status,
        expression,
        reading,
        text,
        activeKey,
        errorMessage,
      );

  @override
  String toString() {
    return 'TtsPlaybackState(status: $status, activeKey: $activeKey, text: $text, error: $errorMessage)';
  }
}
