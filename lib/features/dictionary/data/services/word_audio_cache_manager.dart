import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'word_audio_resolver.dart';

/// Cache manager for word audio pronunciation files.
///
/// Stores downloaded MP3 files in `<appSupportDirectory>/audio_cache/`.
/// Follows dynamic path re-anchoring rules (CLAUDE.md) by resolving the
/// root directory dynamically at runtime rather than persisting absolute paths.
class WordAudioCacheManager {
  final Future<Directory> Function() _supportDirProvider;

  WordAudioCacheManager({
    Future<Directory> Function()? supportDirProvider,
  }) : _supportDirProvider = supportDirProvider ?? getApplicationSupportDirectory;

  static const String audioSubdir = 'audio_cache';
  static const int defaultMaxSizeBytes = 50 * 1024 * 1024; // 50 MB
  static const int defaultTargetPruneBytes = 40 * 1024 * 1024; // 40 MB

  /// Returns the re-anchored `<appSupportDirectory>/audio_cache/` directory,
  /// ensuring it exists on disk.
  Future<Directory> getAudioCacheDirectory() async {
    final supportDir = await _supportDirProvider();
    final cacheDir = Directory(p.join(supportDir.path, audioSubdir));
    if (!cacheDir.existsSync()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Checks if a valid cached audio file exists for the given [expression] and [reading].
  ///
  /// Returns the [File] if it exists and satisfies [WordAudioResolver.minValidAudioByteLength],
  /// or `null` if not cached.
  Future<File?> getCachedAudioFile({
    required String expression,
    required String reading,
  }) async {
    try {
      final cacheDir = await getAudioCacheDirectory();
      final cacheKey = WordAudioResolver.computeAudioCacheKey(
        expression: expression,
        reading: reading,
      );
      final file = File(p.join(cacheDir.path, '$cacheKey.mp3'));
      if (await file.exists()) {
        final length = await file.length();
        if (length >= WordAudioResolver.minValidAudioByteLength) {
          return file;
        } else {
          // Incomplete or corrupted file; delete it
          await file.delete().catchError((_) => file);
        }
      }
    } catch (_) {
      // Ignore disk read errors and proceed as un-cached
    }
    return null;
  }

  /// Atomically writes [bytes] to `<appSupportDirectory>/audio_cache/{cacheKey}.mp3`.
  ///
  /// Writes first to a `.tmp` file and renames to prevent partial files upon app kill.
  Future<File> saveAudioBytes({
    required String expression,
    required String reading,
    required Uint8List bytes,
  }) async {
    final cacheDir = await getAudioCacheDirectory();
    final cacheKey = WordAudioResolver.computeAudioCacheKey(
      expression: expression,
      reading: reading,
    );
    final targetFile = File(p.join(cacheDir.path, '$cacheKey.mp3'));
    final tempFile = File(p.join(cacheDir.path, '$cacheKey.mp3.tmp'));

    await tempFile.writeAsBytes(bytes, flush: true);
    return tempFile.rename(targetFile.path);
  }

  /// Prunes the audio cache directory if the total size exceeds [maxBytes],
  /// deleting oldest modified files until the directory size is under [targetBytes].
  Future<void> pruneCache({
    int maxBytes = defaultMaxSizeBytes,
    int targetBytes = defaultTargetPruneBytes,
  }) async {
    try {
      final cacheDir = await getAudioCacheDirectory();
      final entities = cacheDir.listSync().whereType<File>().toList();

      int totalSize = 0;
      final fileStats = <File, int>{};
      for (final file in entities) {
        if (file.path.endsWith('.tmp')) {
          // Clean up stale temp files
          file.deleteSync();
          continue;
        }
        final size = file.lengthSync();
        totalSize += size;
        fileStats[file] = size;
      }

      if (totalSize <= maxBytes) {
        return;
      }

      // Sort by last modified ascending (oldest first)
      entities.sort((a, b) {
        final aTime = a.lastModifiedSync();
        final bTime = b.lastModifiedSync();
        return aTime.compareTo(bTime);
      });

      for (final file in entities) {
        if (totalSize <= targetBytes) {
          break;
        }
        final size = fileStats[file] ?? file.lengthSync();
        try {
          file.deleteSync();
          totalSize -= size;
        } catch (_) {
          // Continue pruning remaining files if one fails
        }
      }
    } catch (_) {
      // Background pruning should never crash the app
    }
  }

  /// Clears all files in the audio cache directory.
  Future<void> clearAll() async {
    try {
      final cacheDir = await getAudioCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (_) {
      // Ignore
    }
  }
}
