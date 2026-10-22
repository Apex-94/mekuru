import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mekuru/core/services/usage_telemetry.dart';

import '../models/word_audio_models.dart';
import 'audio_pack_manager.dart';
import 'word_audio_resolver.dart';

/// Strict 2-tier service responsible for word pronunciation playback:
/// - Tier 1: Local downloaded audio pack (`AudioPackManager`, O(1) instant playback via `audioplayers`)
/// - Tier 2: Instant on-device Japanese TTS fallback (`flutter_tts`, `ja-JP`)
///
/// Lookups are 100% offline — zero HTTP network requests during reading.
/// Audio sessions configure iOS silent mode bypass (`AVAudioSessionCategoryPlayback` + `mixWithOthers`).
class WordAudioPlayerService {
  final AudioPackManager _audioPackManager;
  final AudioPlayer _audioPlayer;
  final FlutterTts _flutterTts;

  final StreamController<AudioPlaybackState> _stateController =
      StreamController<AudioPlaybackState>.broadcast();

  AudioPlaybackState _currentState = const AudioPlaybackState.idle();
  StreamSubscription<void>? _playerCompleteSub;
  Timer? _ttsSafetyTimer;
  Timer? _errorResetTimer;
  bool _isAudioContextConfigured = false;
  bool _isTtsInitialized = false;

  WordAudioPlayerService({
    required AudioPackManager audioPackManager,
    AudioPlayer? audioPlayer,
    FlutterTts? flutterTts,
  })  : _audioPackManager = audioPackManager,
        _audioPlayer = audioPlayer ?? AudioPlayer(),
        _flutterTts = flutterTts ?? FlutterTts() {
    _initPlayerListeners();
  }

  /// Current active playback state.
  AudioPlaybackState get currentState => _currentState;

  /// Broadcast stream of playback state changes.
  Stream<AudioPlaybackState> get playbackStateStream =>
      _stateController.stream;

  void _initPlayerListeners() {
    _playerCompleteSub = _audioPlayer.onPlayerComplete.listen((_) {
      _emitIdle();
    });

    _flutterTts.setCompletionHandler(() {
      _ttsSafetyTimer?.cancel();
      _emitIdle();
    });

    _flutterTts.setCancelHandler(() {
      _ttsSafetyTimer?.cancel();
      _emitIdle();
    });

    _flutterTts.setErrorHandler((dynamic msg) {
      _ttsSafetyTimer?.cancel();
      _emitError(msg?.toString() ?? 'TTS playback failed');
    });
  }

  /// Configures platform-specific audio session category to ensure sound plays
  /// even when iOS hardware silent switch is engaged.
  Future<void> _ensureAudioContextConfigured() async {
    if (_isAudioContextConfigured) return;
    try {
      await AudioPlayer.global.setAudioContext(
        AudioContext(
          iOS: AudioContextIOS(
            category: AVAudioSessionCategory.playback,
            options: {
              AVAudioSessionOptions.mixWithOthers,
            },
          ),
          android: AudioContextAndroid(
            isSpeakerphoneOn: false,
            stayAwake: false,
            contentType: AndroidContentType.speech,
            usageType: AndroidUsageType.assistanceSonification,
            audioFocus: AndroidAudioFocus.gainTransientMayDuck,
          ),
        ),
      );
      _isAudioContextConfigured = true;
    } catch (e) {
      debugPrint('Failed to configure AudioPlayer global context: $e');
    }
  }

  /// Initializes FlutterTts with Japanese language settings and iOS category.
  Future<void> _ensureTtsInitialized() async {
    if (_isTtsInitialized) return;
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        await _flutterTts.setIosAudioCategory(
          IosTextToSpeechAudioCategory.playback,
          [
            IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
          ],
          IosTextToSpeechAudioMode.defaultMode,
        );
      }
      await _flutterTts.setLanguage('ja-JP');
      await _flutterTts.setSpeechRate(0.5);
      await _flutterTts.setPitch(1.0);
      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('Failed to initialize FlutterTts: $e');
    }
  }

  /// Plays pronunciation for [expression] and [reading] using the strict 2-tier pipeline:
  ///
  /// Tier 1: Check downloaded audio pack for local file.
  /// Tier 2: Instant fallback to on-device ja-JP speech synthesis.
  Future<void> play({
    required String expression,
    String? reading,
  }) async {
    final exp = expression.trim();
    final read = (reading ?? '').trim();
    if (exp.isEmpty) return;

    // Stop any ongoing playback
    await stop();

    await _ensureAudioContextConfigured();

    // ── Tier 1: Downloaded Audio Pack ──
    try {
      final File? audioFile = await _audioPackManager.getAudioFile(
        expression: exp,
        reading: read,
      );

      if (audioFile != null) {
        _emit(AudioPlaybackState(
          status: AudioPlaybackStatus.playing,
          expression: exp,
          reading: read,
          sourceType: WordAudioSourceType.downloadedPack,
        ));
        await _audioPlayer.play(DeviceFileSource(audioFile.path));
        logUsage('word_audio_played', attrs: {'source': 'pack'});
        return;
      }
    } catch (e) {
      debugPrint('Tier 1 audio pack playback failed: $e');
    }

    // ── Tier 2: Instant On-Device Japanese TTS Fallback ──
    try {
      await _ensureTtsInitialized();
      final speechText = WordAudioResolver.resolveTtsSpeechText(
        expression: exp,
        reading: read,
      );

      _emit(AudioPlaybackState(
        status: AudioPlaybackStatus.playing,
        expression: exp,
        reading: read,
        sourceType: WordAudioSourceType.ttsFallback,
      ));

      // Safety watchdog: returns state to idle if completion callback drops
      _ttsSafetyTimer?.cancel();
      _ttsSafetyTimer = Timer(const Duration(seconds: 4), () {
        if (_currentState.status == AudioPlaybackStatus.playing &&
            _currentState.expression == exp) {
          _emitIdle();
        }
      });

      final dynamic result = await _flutterTts.speak(speechText);
      if (result == 0) {
        _ttsSafetyTimer?.cancel();
        _emitError('TTS engine failed to speak');
      } else {
        logUsage('word_audio_played', attrs: {'source': 'tts'});
      }
    } catch (e) {
      _ttsSafetyTimer?.cancel();
      _emitError('TTS unavailable');
    }
  }

  /// Stops any currently playing audio or speech synthesis.
  Future<void> stop() async {
    _ttsSafetyTimer?.cancel();
    try {
      await _audioPlayer.stop();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    _emitIdle();
  }

  void _emit(AudioPlaybackState state) {
    _currentState = state;
    if (!_stateController.isClosed) {
      _stateController.add(state);
    }
  }

  void _emitIdle() {
    _emit(const AudioPlaybackState.idle());
  }

  void _emitError(String message) {
    _errorResetTimer?.cancel();
    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.error,
      expression: _currentState.expression,
      reading: _currentState.reading,
      errorMessage: message,
    ));
    // Auto-dismiss error state after 3 seconds
    _errorResetTimer = Timer(const Duration(seconds: 3), () {
      if (_currentState.status == AudioPlaybackStatus.error) {
        _emitIdle();
      }
    });
  }

  /// Disposes resources held by the service.
  Future<void> dispose() async {
    _ttsSafetyTimer?.cancel();
    _errorResetTimer?.cancel();
    await _playerCompleteSub?.cancel();
    try {
      await _audioPlayer.dispose();
    } catch (_) {}
    try {
      await _flutterTts.stop();
    } catch (_) {}
    await _stateController.close();
  }
}
