import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mekuru/features/tts/data/models/tts_playback_state.dart';
import 'package:mekuru/features/tts/data/services/tts_speech_text_resolver.dart';

/// Service managing the Text-To-Speech engine lifecycle, configuration,
/// playback state stream, and iOS audio session settings.
class TtsPlayerService {
  TtsPlayerService({FlutterTts? tts}) : _flutterTts = tts ?? FlutterTts() {
    _initHandlers();
  }

  final FlutterTts _flutterTts;
  final StreamController<TtsPlaybackState> _stateController =
      StreamController<TtsPlaybackState>.broadcast();

  TtsPlaybackState _currentState = const TtsPlaybackState();
  Timer? _safetyTimer;
  bool _isInitialized = false;

  /// Broadcast stream of playback state changes.
  Stream<TtsPlaybackState> get stateStream => _stateController.stream;

  /// Current playback state snapshot.
  TtsPlaybackState get currentState => _currentState;

  void _initHandlers() {
    _flutterTts.setStartHandler(() {
      // Playback has started
    });

    _flutterTts.setCompletionHandler(() {
      _onPlaybackFinished();
    });

    _flutterTts.setCancelHandler(() {
      _onPlaybackFinished();
    });

    _flutterTts.setErrorHandler((dynamic message) {
      _safetyTimer?.cancel();
      _safetyTimer = null;
      _updateState(
        _currentState.copyWith(
          status: TtsPlaybackStatus.error,
          errorMessage: message?.toString() ?? 'TTS synthesis error',
        ),
      );
    });
  }

  void _onPlaybackFinished() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    _updateState(const TtsPlaybackState(status: TtsPlaybackStatus.idle));
  }

  /// Initializes platform TTS parameters with ja-JP locale, rate 0.5, and iOS audio category.
  Future<void> _ensureInitialized() async {
    if (_isInitialized) return;
    try {
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      await _flutterTts.setVolume(1.0);

      // Branch using defaultTargetPlatform per CLAUDE.md cross-platform rules
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setSharedInstance(true);
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
        );
      }
      _isInitialized = true;
    } catch (e) {
      debugPrint('Error initializing TtsPlayerService: $e');
    }
  }

  /// Checks if the ja-JP voice is available on the current device.
  Future<bool> isJapaneseAvailable() async {
    try {
      final dynamic res = await _flutterTts.isLanguageAvailable('ja-JP');
      if (res is bool) return res;
      if (res is int) return res >= 0;
      return res == true;
    } catch (e) {
      debugPrint('Error checking Japanese TTS availability: $e');
      return false;
    }
  }

  /// Synthesizes and plays Japanese pronunciation for the given [expression] and optional [reading].
  ///
  /// Tapping the currently playing word stops playback (toggle-to-stop).
  /// Playing a new word immediately stops any previously playing utterance.
  Future<void> speak({
    required String expression,
    String? reading,
  }) async {
    final text = TtsSpeechTextResolver.resolveSpeechText(
      expression: expression,
      reading: reading,
    );

    if (text.isEmpty) {
      return;
    }

    final key = TtsPlaybackState.makeKey(
      expression: expression,
      reading: reading,
    );

    // If already playing this exact word, toggle to stop
    if (_currentState.isPlaying && _currentState.activeKey == key) {
      await stop();
      return;
    }

    // Stop any ongoing speech before starting a new one
    await stop();

    await _ensureInitialized();

    final available = await isJapaneseAvailable();
    if (!available) {
      _updateState(
        TtsPlaybackState(
          status: TtsPlaybackStatus.error,
          expression: expression,
          reading: reading,
          text: text,
          activeKey: key,
          errorMessage: 'Japanese speech synthesis is not available on this device',
        ),
      );
      return;
    }

    _updateState(
      TtsPlaybackState(
        status: TtsPlaybackStatus.playing,
        expression: expression,
        reading: reading,
        text: text,
        activeKey: key,
      ),
    );

    // Safety timeout: isolated words are brief utterances.
    // If native completion callback fails to trigger, revert to idle.
    _safetyTimer?.cancel();
    _safetyTimer = Timer(const Duration(seconds: 8), () {
      if (_currentState.isPlaying && _currentState.activeKey == key) {
        _onPlaybackFinished();
      }
    });

    try {
      await _flutterTts.speak(text);
    } catch (e) {
      _safetyTimer?.cancel();
      _safetyTimer = null;
      _updateState(
        TtsPlaybackState(
          status: TtsPlaybackStatus.error,
          expression: expression,
          reading: reading,
          text: text,
          activeKey: key,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Stops any currently active TTS utterance and resets the state to idle.
  Future<void> stop() async {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (_isInitialized) {
      try {
        await _flutterTts.stop();
      } catch (e) {
        debugPrint('Error stopping TTS: $e');
      }
    }
    _updateState(const TtsPlaybackState(status: TtsPlaybackStatus.idle));
  }

  void _updateState(TtsPlaybackState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  /// Disposes resources, timers, and streams.
  void dispose() {
    _safetyTimer?.cancel();
    _safetyTimer = null;
    if (_isInitialized) {
      _flutterTts.stop().catchError((_) => null);
    }
    _stateController.close();
  }
}
