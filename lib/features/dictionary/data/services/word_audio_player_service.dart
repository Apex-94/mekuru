import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;

import '../models/word_audio_models.dart';
import 'word_audio_cache_manager.dart';
import 'word_audio_resolver.dart';

/// Service responsible for managing word pronunciation playback across:
/// 1. Tier 1: Local disk cache (`<appSupport>/audio_cache/`)
/// 2. Tier 2: Online endpoint (JapanesePod101 audio endpoint with caching)
/// 3. Tier 3: Local TTS fallback (ja-JP)
///
/// Configures audio sessions to ensure silent mode bypass on iOS
/// (AVAudioSessionCategoryPlayback + mixWithOthers) and transient audio focus on Android.
class WordAudioPlayerService {
  final WordAudioCacheManager _cacheManager;
  final http.Client _httpClient;
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
    required WordAudioCacheManager cacheManager,
    http.Client? httpClient,
    AudioPlayer? audioPlayer,
    FlutterTts? flutterTts,
  })  : _cacheManager = cacheManager,
        _httpClient = httpClient ?? http.Client(),
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
              AVAudioSessionOptions.defaultToSpeaker,
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

  /// Plays pronunciation for [expression] and [reading].
  ///
  /// Waterfall strategy:
  /// 1. Tier 1: Check disk cache
  /// 2. Tier 2: Fetch from JapanesePod101 URL and cache to disk
  /// 3. Tier 3: On-device TTS fallback (ja-JP)
  Future<void> play({
    required String expression,
    String? reading,
  }) async {
    final exp = expression.trim();
    final read = (reading ?? '').trim();
    if (exp.isEmpty) return;

    // Stop any ongoing playback
    await stop();

    _emit(AudioPlaybackState(
      status: AudioPlaybackStatus.loading,
      expression: exp,
      reading: read,
    ));

    await _ensureAudioContextConfigured();

    // --- Tier 1: Local Cache ---
    try {
      final cachedFile = await _cacheManager.getCachedAudioFile(
        expression: exp,
        reading: read,
      );
      if (cachedFile != null) {
        _emit(AudioPlaybackState(
          status: AudioPlaybackStatus.playing,
          expression: exp,
          reading: read,
        ));
        await _audioPlayer.play(DeviceFileSource(cachedFile.path));
        return;
      }
    } catch (e) {
      debugPrint('Tier 1 cache lookup failed: $e');
    }

    // --- Tier 2: Online Endpoint ---
    bool onlineSucceeded = false;
    try {
      final url = WordAudioResolver.buildJapanesePod101Url(
        expression: exp,
        reading: read,
      );
      final response = await _httpClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 &&
          WordAudioResolver.isValidAudioBytes(response.bodyBytes)) {
        final savedFile = await _cacheManager.saveAudioBytes(
          expression: exp,
          reading: read,
          bytes: response.bodyBytes,
        );
        onlineSucceeded = true;
        _emit(AudioPlaybackState(
          status: AudioPlaybackStatus.playing,
          expression: exp,
          reading: read,
        ));
        await _audioPlayer.play(DeviceFileSource(savedFile.path));
        return;
      }
    } catch (e) {
      debugPrint('Tier 2 online fetch failed, falling back to TTS: $e');
    }

    if (onlineSucceeded) return;

    // --- Tier 3: Offline TTS Fallback ---
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
      ));

      // Safety timer to prevent being stuck in 'playing' state if TTS completes silently
      _ttsSafetyTimer?.cancel();
      _ttsSafetyTimer = Timer(const Duration(seconds: 4), () {
        if (_currentState.status == AudioPlaybackStatus.playing &&
            _currentState.expression == exp) {
          _emitIdle();
        }
      });

      final dynamic result = await _flutterTts.speak(speechText);
      // In flutter_tts, 1 indicates success on iOS/Android, 0 indicates failure
      if (result == 0) {
        _ttsSafetyTimer?.cancel();
        _emitError('TTS engine failed to speak');
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
