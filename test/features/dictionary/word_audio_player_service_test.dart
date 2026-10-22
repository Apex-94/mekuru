import 'dart:io';
import 'package:archive/archive.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mekuru/features/dictionary/data/models/word_audio_models.dart';
import 'package:mekuru/features/dictionary/data/services/audio_pack_manager.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_player_service.dart';

class _FakeAudioPlayer extends AudioPlayer {
  Source? lastPlayedSource;
  bool stopCalled = false;
  bool disposeCalled = false;

  @override
  Future<void> play(
    Source source, {
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
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late AudioPackManager audioPackManager;
  late _FakeAudioPlayer fakeAudioPlayer;
  late _FakeFlutterTts fakeFlutterTts;

  setUp(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers.global'),
      (call) async => 1,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('xyz.luan/audioplayers'),
      (call) async => 1,
    );

    tempDir = await Directory.systemTemp.createTemp('mekuru_player_test_');
    audioPackManager = AudioPackManager(supportDirProvider: () async => tempDir);
    fakeAudioPlayer = _FakeAudioPlayer();
    fakeFlutterTts = _FakeFlutterTts();
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> seedAudioPackWithWord({
    required String expression,
    required String reading,
  }) async {
    final archive = Archive();
    final fileData = List<int>.generate(100, (i) => i % 256);
    archive.addFile(
      ArchiveFile('audio/${expression}_$reading.mp3', fileData.length, fileData),
    );
    final zipData = ZipEncoder().encode(archive);
    final zipFile = File('${tempDir.path}/seed.zip');
    zipFile.writeAsBytesSync(zipData);
    await audioPackManager.importZip(zipFile);
  }

  group('WordAudioPlayerService (Strict 2-Tier Pipeline)', () {
    test('Tier 1: Plays audio from downloaded pack when word exists', () async {
      await seedAudioPackWithWord(expression: '食べる', reading: 'たべる');

      final service = WordAudioPlayerService(
        audioPackManager: audioPackManager,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '食べる', reading: 'たべる');

      expect(fakeAudioPlayer.lastPlayedSource, isA<DeviceFileSource>());
      expect(fakeFlutterTts.lastSpokenText, isNull);
      expect(service.currentState.status, AudioPlaybackStatus.playing);
      expect(service.currentState.sourceType, WordAudioSourceType.downloadedPack);

      await service.dispose();
    });

    test('Tier 2: Immediately falls back to on-device TTS on pack miss', () async {
      // Audio pack is empty or does not contain '本'
      final service = WordAudioPlayerService(
        audioPackManager: audioPackManager,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '本', reading: 'ほん');

      expect(fakeAudioPlayer.lastPlayedSource, isNull);
      expect(fakeFlutterTts.lastSpokenText, 'ほん');
      expect(service.currentState.status, AudioPlaybackStatus.playing);
      expect(service.currentState.sourceType, WordAudioSourceType.ttsFallback);

      await service.dispose();
    });

    test('Tier 2 TTS fallback uses expression when reading is null/empty', () async {
      final service = WordAudioPlayerService(
        audioPackManager: audioPackManager,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: 'こんにちは');

      expect(fakeFlutterTts.lastSpokenText, 'こんにちは');
      expect(service.currentState.sourceType, WordAudioSourceType.ttsFallback);

      await service.dispose();
    });

    test('stop() cancels both AudioPlayer and FlutterTts and emits idle', () async {
      final service = WordAudioPlayerService(
        audioPackManager: audioPackManager,
        audioPlayer: fakeAudioPlayer,
        flutterTts: fakeFlutterTts,
      );

      await service.play(expression: '猫', reading: 'ねこ');
      await service.stop();

      expect(fakeAudioPlayer.stopCalled, isTrue);
      expect(fakeFlutterTts.stopCalled, isTrue);
      expect(service.currentState.status, AudioPlaybackStatus.idle);

      await service.dispose();
    });
  });
}
