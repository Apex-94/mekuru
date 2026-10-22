import 'dart:io';
import 'dart:typed_data';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mekuru/features/dictionary/data/models/word_audio_models.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_cache_manager.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_player_service.dart';

class _FakeAudioPlayer extends AudioPlayer {
  Source? lastPlayedSource;
  bool stopCalled = false;
  bool disposeCalled = false;

  @override
  Future<void> play(Source source, {
    double? volume,
    double? balance,
    AudioContext? ctx,
    Duration? position,
    PlayerMode? mode,
  }) async {
    lastPlayedSource = source;
  }

  @override
  Future<void> stop() async {
    stopCalled = true;
  }

  @override
  Future<void> dispose() async {
    disposeCalled = true;
  }
}

class _FakeFlutterTts extends FlutterTts {
  String? lastSpokenText;
  bool stopCalled = false;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    lastSpokenText = text;
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    stopCalled = true;
    return 1;
  }

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;
}

void main() {
  late Directory tempDir;
  late WordAudioCacheManager cacheManager;
  late _FakeAudioPlayer fakeAudioPlayer;
  late _FakeFlutterTts fakeFlutterTts;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mekuru_player_test_');
    cacheManager = WordAudioCacheManager(supportDirProvider: () async => tempDir);
    fakeAudioPlayer = _FakeAudioPlayer();
    fakeFlutterTts = _FakeFlutterTts();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Uint8List createValidAudioBytes() {
    final bytes = Uint8List(600);
    bytes[0] = 0x49; // 'I'
    bytes[1] = 0x44; // 'D'
    bytes[2] = 0x33; // '3'
    return bytes;
  }

  group('WordAudioPlayerService', () {
    test('Tier 1: Plays cached file immediately without network request', () async {
      final validBytes = createValidAudioBytes();
      await cacheManager.saveAudioBytes(
        expression: '食べる',
        reading: 'たべる',
        bytes: validBytes,
      );

      bool networkHit = false;
      final mockClient = MockClient((request) async {
        networkHit = true;
        return http.Response('not hit', 500);
      });

      final service = WordAudioPlayerService(
        cacheManager: cacheManager,
        httpClient: mockClient,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '食べる', reading: 'たべる');

      expect(networkHit, isFalse);
      expect(fakeAudioPlayer.lastPlayedSource, isA<DeviceFileSource>());
      expect(fakeFlutterTts.lastSpokenText, isNull);
      expect(service.currentState.status, AudioPlaybackStatus.playing);

      await service.dispose();
    });

    test('Tier 2: Downloads online audio and caches to disk when un-cached', () async {
      final validBytes = createValidAudioBytes();
      final mockClient = MockClient((request) async {
        expect(request.url.queryParameters['kanji'], '本');
        expect(request.url.queryParameters['kana'], 'ほん');
        return http.Response.bytes(validBytes, 200);
      });

      final service = WordAudioPlayerService(
        cacheManager: cacheManager,
        httpClient: mockClient,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '本', reading: 'ほん');

      expect(fakeAudioPlayer.lastPlayedSource, isA<DeviceFileSource>());
      final cachedFile = await cacheManager.getCachedAudioFile(
        expression: '本',
        reading: 'ほん',
      );
      expect(cachedFile, isNotNull);
      expect(service.currentState.status, AudioPlaybackStatus.playing);

      await service.dispose();
    });

    test('Tier 3: Falls back to on-device TTS when network request returns 404', () async {
      final mockClient = MockClient((request) async {
        return http.Response('Not Found', 404);
      });

      final service = WordAudioPlayerService(
        cacheManager: cacheManager,
        httpClient: mockClient,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '私', reading: 'わたし');

      expect(fakeFlutterTts.lastSpokenText, 'わたし');
      expect(service.currentState.status, AudioPlaybackStatus.playing);

      await service.dispose();
    });

    test('stop() cancels both AudioPlayer and FlutterTts and emits idle', () async {
      final service = WordAudioPlayerService(
        cacheManager: cacheManager,
        httpClient: http.Client(),
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.stop();

      expect(fakeAudioPlayer.stopCalled, isTrue);
      expect(fakeFlutterTts.stopCalled, isTrue);
      expect(service.currentState.status, AudioPlaybackStatus.idle);

      await service.dispose();
    });
  });
}
