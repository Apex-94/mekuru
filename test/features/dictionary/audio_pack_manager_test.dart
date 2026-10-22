import 'dart:io';
import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/dictionary/data/services/audio_pack_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempSupportDir;
  late AudioPackManager manager;

  setUp(() async {
    tempSupportDir = await Directory.systemTemp.createTemp('mekuru_audio_pack_test_');
    manager = AudioPackManager(
      supportDirProvider: () async => tempSupportDir,
    );
  });

  tearDown(() async {
    if (await tempSupportDir.exists()) {
      await tempSupportDir.delete(recursive: true);
    }
  });

  File createTestZipFile(Directory dir) {
    final archive = Archive();

    // File 1: 食べる_たべる.mp3
    final file1Data = List<int>.generate(128, (i) => i % 256);
    archive.addFile(ArchiveFile('audio/食べる_たべる.mp3', file1Data.length, file1Data));

    // File 2: ありがとう.mp3
    final file2Data = List<int>.generate(64, (i) => (i * 2) % 256);
    archive.addFile(ArchiveFile('audio/ありがとう.mp3', file2Data.length, file2Data));

    // File 3: Non-audio readme (should be ignored)
    final readmeData = 'Test Audio Pack'.codeUnits;
    archive.addFile(ArchiveFile('README.txt', readmeData.length, readmeData));

    final zipData = ZipEncoder().encode(archive);
    final zipFile = File('${dir.path}/test_pack.zip');
    zipFile.writeAsBytesSync(zipData);
    return zipFile;
  }

  group('AudioPackManager', () {
    test('Initializes as not installed when support dir is empty', () async {
      await manager.initialize();
      expect(manager.isInstalled, isFalse);
      expect(manager.meta, isNull);
      expect(manager.index, isNull);
    });

    test('importZip extracts audio files, indexes them, and writes meta.json & index.json', () async {
      final zipFile = createTestZipFile(tempSupportDir);

      double lastProgress = 0.0;
      final importedCount = await manager.importZip(
        zipFile,
        onProgress: (p) => lastProgress = p,
      );

      expect(importedCount, 2);
      expect(lastProgress, 1.0);
      expect(manager.isInstalled, isTrue);
      expect(manager.meta?.entryCount, 2);
      expect(manager.meta?.totalSizeBytes, 128 + 64);

      // Verify file lookup
      final file1 = await manager.getAudioFile(
        expression: '食べる',
        reading: 'たべる',
      );
      expect(file1, isNotNull);
      expect(await file1!.exists(), isTrue);
      expect(await file1.length(), 128);

      final file2 = await manager.getAudioFile(
        expression: 'ありがとう',
        reading: 'ありがとう',
      );
      expect(file2, isNotNull);
      expect(await file2!.exists(), isTrue);

      // Verify miss
      final fileMiss = await manager.getAudioFile(
        expression: '飲む',
        reading: 'のむ',
      );
      expect(fileMiss, isNull);
    });

    test('Re-initializing reloads index from disk without re-extracting', () async {
      final zipFile = createTestZipFile(tempSupportDir);
      await manager.importZip(zipFile);

      // Create a fresh manager instance pointing to the same support directory
      final freshManager = AudioPackManager(
        supportDirProvider: () async => tempSupportDir,
      );
      await freshManager.initialize();

      expect(freshManager.isInstalled, isTrue);
      expect(freshManager.meta?.entryCount, 2);

      final file = await freshManager.getAudioFile(
        expression: '食べる',
        reading: 'たべる',
      );
      expect(file, isNotNull);
    });

    test('deletePack removes files and resets installed state', () async {
      final zipFile = createTestZipFile(tempSupportDir);
      await manager.importZip(zipFile);
      expect(manager.isInstalled, isTrue);

      await manager.deletePack();

      expect(manager.isInstalled, isFalse);
      expect(manager.meta, isNull);
      expect(manager.index, isNull);

      final packDir = Directory('${tempSupportDir.path}/${AudioPackManager.packDirName}');
      expect(await packDir.exists(), isFalse);
    });
  });
}
