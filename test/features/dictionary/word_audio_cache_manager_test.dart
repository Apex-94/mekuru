import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_cache_manager.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_resolver.dart';

void main() {
  late Directory tempDir;
  late WordAudioCacheManager cacheManager;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('mekuru_audio_test_');
    cacheManager = WordAudioCacheManager(
      supportDirProvider: () async => tempDir,
    );
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  group('WordAudioCacheManager', () {
    test('creates audio_cache subdirectory on demand', () async {
      final cacheDir = await cacheManager.getAudioCacheDirectory();
      expect(await cacheDir.exists(), isTrue);
      expect(cacheDir.path.endsWith(WordAudioCacheManager.audioSubdir), isTrue);
    });

    test('saves and retrieves cached audio file atomically', () async {
      final dummyBytes = Uint8List(WordAudioResolver.minValidAudioByteLength + 100);
      dummyBytes[0] = 0x49;
      dummyBytes[1] = 0x44;
      dummyBytes[2] = 0x33; // 'ID3'

      final savedFile = await cacheManager.saveAudioBytes(
        expression: '食べる',
        reading: 'たべる',
        bytes: dummyBytes,
      );

      expect(await savedFile.exists(), isTrue);
      expect(savedFile.path.endsWith('.mp3'), isTrue);

      final retrieved = await cacheManager.getCachedAudioFile(
        expression: '食べる',
        reading: 'たべる',
      );

      expect(retrieved, isNotNull);
      expect(await retrieved!.length(), dummyBytes.length);
    });

    test('returns null when cached file does not exist', () async {
      final retrieved = await cacheManager.getCachedAudioFile(
        expression: '存在しない',
        reading: 'そんざいしない',
      );

      expect(retrieved, isNull);
    });

    test('prunes oldest files when total size exceeds maxBytes', () async {
      final cacheDir = await cacheManager.getAudioCacheDirectory();

      // Create 3 files of 1000 bytes each
      final file1 = File('${cacheDir.path}/file1.mp3');
      final file2 = File('${cacheDir.path}/file2.mp3');
      final file3 = File('${cacheDir.path}/file3.mp3');

      await file1.writeAsBytes(Uint8List(1000));
      // Artificial delay so lastModified differs
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await file2.writeAsBytes(Uint8List(1000));
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await file3.writeAsBytes(Uint8List(1000));

      // Prune with maxBytes = 2500, targetBytes = 1500
      await cacheManager.pruneCache(maxBytes: 2500, targetBytes: 1500);

      // file1 (oldest) should be deleted first
      expect(await file1.exists(), isFalse);
      expect(await file3.exists(), isTrue);
    });

    test('clearAll removes all cache files', () async {
      final dummyBytes = Uint8List(600);
      dummyBytes[0] = 0x49;
      dummyBytes[1] = 0x44;
      dummyBytes[2] = 0x33;

      await cacheManager.saveAudioBytes(
        expression: '犬',
        reading: 'いぬ',
        bytes: dummyBytes,
      );

      await cacheManager.clearAll();

      final retrieved = await cacheManager.getCachedAudioFile(
        expression: '犬',
        reading: 'いぬ',
      );
      expect(retrieved, isNull);
    });
  });
}
