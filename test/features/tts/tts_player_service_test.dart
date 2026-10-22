import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mekuru/features/tts/data/services/tts_player_service.dart';

class FakeFlutterTts extends FlutterTts {
  String? language;
  double? speechRate;
  double? pitch;
  double? volume;
  bool? sharedInstance;
  IosTextToSpeechAudioCategory? iosCategory;
  List<IosTextToSpeechAudioCategoryOptions>? iosOptions;

  bool languageAvailable = true;
  final List<String> spokenTexts = [];
  bool isPlaying = false;

  @override
  Future<dynamic> setLanguage(String language) async {
    this.language = language;
    return 1;
  }

  @override
  Future<dynamic> setSpeechRate(double rate) async {
    speechRate = rate;
    return 1;
  }

  @override
  Future<dynamic> setPitch(double pitch) async {
    this.pitch = pitch;
    return 1;
  }

  @override
  Future<dynamic> setVolume(double volume) async {
    this.volume = volume;
    return 1;
  }

  @override
  Future<dynamic> setSharedInstance(bool shared) async {
    sharedInstance = shared;
    return 1;
  }

  @override
  Future<dynamic> setIosAudioCategory(
    IosTextToSpeechAudioCategory category,
    List<IosTextToSpeechAudioCategoryOptions> options, [
    IosTextToSpeechAudioMode mode = IosTextToSpeechAudioMode.defaultMode,
  ]) async {
    iosCategory = category;
    iosOptions = options;
    return 1;
  }

  @override
  Future<dynamic> isLanguageAvailable(String language) async {
    return languageAvailable;
  }

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    isPlaying = true;
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isPlaying = false;
    cancelHandler?.call();
    return 1;
  }

  void triggerCompletion() {
    isPlaying = false;
    completionHandler?.call();
  }

  void triggerError(dynamic error) {
    isPlaying = false;
    errorHandler?.call(error);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsPlayerService', () {
    late FakeFlutterTts fakeTts;
    late TtsPlayerService service;

    setUp(() {
      fakeTts = FakeFlutterTts();
      service = TtsPlayerService(tts: fakeTts);
    });

    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
      service.dispose();
    });

    test('initializes ja-JP, speechRate 0.5, pitch 1.0, and volume 1.0 upon first speak', () async {
      await service.speak(expression: '角', reading: 'つの');

      expect(fakeTts.language, 'ja-JP');
      expect(fakeTts.speechRate, 0.5);
      expect(fakeTts.pitch, 1.0);
      expect(fakeTts.volume, 1.0);
      expect(fakeTts.spokenTexts, ['つの']);
    });

    test('configures iOS audio category playback with mixWithOthers and defaultToSpeaker when on iOS', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;

      await service.speak(expression: '食べる', reading: 'たべる');

      expect(fakeTts.sharedInstance, true);
      expect(fakeTts.iosCategory, IosTextToSpeechAudioCategory.playback);
      expect(fakeTts.iosOptions, contains(IosTextToSpeechAudioCategoryOptions.mixWithOthers));
      expect(fakeTts.iosOptions, contains(IosTextToSpeechAudioCategoryOptions.defaultToSpeaker));
    });

    test('state transitions to playing on speak and resolves kana reading', () async {
      expect(service.currentState.isIdle, true);

      await service.speak(expression: '角', reading: 'つの');

      expect(service.currentState.isPlaying, true);
      expect(service.currentState.expression, '角');
      expect(service.currentState.reading, 'つの');
      expect(service.currentState.text, 'つの');
      expect(service.currentState.activeKey, '角#つの');
      expect(service.currentState.isPlayingWord(expression: '角', reading: 'つの'), true);
    });

    test('toggles playback to stop when tapping the same word again', () async {
      await service.speak(expression: '角', reading: 'つの');
      expect(service.currentState.isPlaying, true);

      await service.speak(expression: '角', reading: 'つの');
      expect(service.currentState.isIdle, true);
      expect(fakeTts.isPlaying, false);
    });

    test('replaces previous utterance when speaking a different word', () async {
      await service.speak(expression: '角', reading: 'つの');
      expect(service.currentState.activeKey, '角#つの');

      await service.speak(expression: '犬', reading: 'いぬ');
      expect(service.currentState.activeKey, '犬#いぬ');
      expect(fakeTts.spokenTexts, ['つの', 'いぬ']);
    });

    test('resets state to idle when completionHandler fires', () async {
      await service.speak(expression: '猫', reading: 'ねこ');
      expect(service.currentState.isPlaying, true);

      fakeTts.triggerCompletion();
      expect(service.currentState.isIdle, true);
    });

    test('transitions to error state when ja-JP voice is unavailable', () async {
      fakeTts.languageAvailable = false;

      await service.speak(expression: 'テスト', reading: null);

      expect(service.currentState.hasError, true);
      expect(service.currentState.errorMessage, contains('Japanese speech synthesis is not available'));
    });

    test('transitions to error state when native errorHandler fires', () async {
      await service.speak(expression: 'テスト', reading: null);
      expect(service.currentState.isPlaying, true);

      fakeTts.triggerError('Native TTS failure');

      expect(service.currentState.hasError, true);
      expect(service.currentState.errorMessage, 'Native TTS failure');
    });

    test('does nothing when input resolves to empty text', () async {
      await service.speak(expression: '', reading: '');

      expect(service.currentState.isIdle, true);
      expect(fakeTts.spokenTexts.isEmpty, true);
    });
  });
}
