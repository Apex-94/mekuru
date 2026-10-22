import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:mekuru/core/platform/ios_storage.dart';
import 'package:mekuru/core/services/download_to_file.dart';
import 'package:mekuru/core/services/usage_telemetry.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../models/audio_pack_models.dart';
import 'audio_pack_index_service.dart';

/// Payload passed to isolate for archive extraction and indexing.
class _AudioPackExtractPayload {
  final String zipPath;
  final String stagingDir;

  const _AudioPackExtractPayload({
    required this.zipPath,
    required this.stagingDir,
  });
}

/// Result returned from isolate extraction.
class _AudioPackExtractResult {
  final int fileCount;
  final int totalBytes;
  final String indexJson;
  final String metaJson;

  const _AudioPackExtractResult({
    required this.fileCount,
    required this.totalBytes,
    required this.indexJson,
    required this.metaJson,
  });
}

/// Top-level function for extracting audio pack ZIP archives.
_AudioPackExtractResult _extractAndIndexArchive(
  _AudioPackExtractPayload payload,
) {
  final input = InputFileStream(payload.zipPath);
  try {
    final archive = ZipDecoder().decodeStream(input);
    final audioOutputDir = Directory(p.join(payload.stagingDir, 'audio'));
    if (!audioOutputDir.existsSync()) {
      audioOutputDir.createSync(recursive: true);
    }

    final relativePaths = <String>[];
    int totalBytes = 0;

    for (final file in archive.files) {
      if (!file.isFile) continue;

      final ext = p.extension(file.name).toLowerCase();
      if (!AudioPackIndexService.supportedExtensions.contains(ext)) {
        continue;
      }

      final fileName = p.basename(file.name);
      final destPath = p.join(audioOutputDir.path, fileName);
      final destFile = File(destPath);
      final bytes = file.content as List<int>;
      destFile.writeAsBytesSync(bytes);
      totalBytes += bytes.length;
      relativePaths.add('audio/$fileName');

      // Free file memory immediately
      file.clear();
    }

    if (relativePaths.isEmpty) {
      throw const FormatException(
        'Archive does not contain any supported Japanese audio files (.mp3, .m4a, .ogg, .wav).',
      );
    }

    final index = AudioPackIndexService.buildIndex(relativePaths);
    final meta = AudioPackMeta(
      title: 'Japanese Word Audio Pack',
      version: '1.0.0',
      entryCount: index.uniqueFileCount,
      totalSizeBytes: totalBytes,
      installedAt: DateTime.now(),
    );

    return _AudioPackExtractResult(
      fileCount: index.uniqueFileCount,
      totalBytes: totalBytes,
      indexJson: index.serialize(),
      metaJson: jsonEncode(meta.toJson()),
    );
  } finally {
    input.closeSync();
  }
}

/// Service managing the local Japanese audio pronunciation pack.
///
/// Features:
/// 1. Relative-path in-memory indexing (`index.json`) stored under `<appSupport>/audio_pack/`.
/// 2. Atomic swap on install/import to prevent corrupt state.
/// 3. Offline-first resolution with zero network latency.
class AudioPackManager {
  static const String packDirName = 'audio_pack';
  static const String stagingDirName = 'audio_pack_staging';
  static const String indexFileName = 'index.json';
  static const String metaFileName = 'meta.json';

  /// Standard curated Japanese word audio pack repository URL.
  static const String defaultAudioPackUrl =
      'https://github.com/matt-dl/mekuru/releases/download/v1.0.0-assets/japanese_word_audio_pack.zip';

  final Future<Directory> Function() _supportDirProvider;
  AudioPackIndex? _index;
  AudioPackMeta? _meta;
  bool _isInitialized = false;

  AudioPackManager({Future<Directory> Function()? supportDirProvider})
      : _supportDirProvider = supportDirProvider ?? getApplicationSupportDirectory;

  /// Returns true if an audio pack is currently installed and non-empty.
  bool get isInstalled =>
      _index != null && _index!.uniqueFileCount > 0 && (_meta?.entryCount ?? 0) > 0;

  /// Active pack metadata snapshot, or null if uninstalled.
  AudioPackMeta? get meta => _meta;

  /// Active in-memory index, or null if uninstalled.
  AudioPackIndex? get index => _index;

  /// Initializes the audio pack manager by loading `meta.json` and `index.json` from disk.
  Future<void> initialize() async {
    if (_isInitialized) return;
    await _loadFromDisk();
    _isInitialized = true;
  }

  Future<Directory> _getPackDir() async {
    final support = await _supportDirProvider();
    return Directory(p.join(support.path, packDirName));
  }

  Future<Directory> _getStagingDir() async {
    final support = await _supportDirProvider();
    return Directory(p.join(support.path, stagingDirName));
  }

  Future<void> _loadFromDisk() async {
    try {
      final packDir = await _getPackDir();
      final indexFile = File(p.join(packDir.path, indexFileName));
      final metaFile = File(p.join(packDir.path, metaFileName));

      if (await indexFile.exists() && await metaFile.exists()) {
        final indexContent = await indexFile.readAsString();
        final metaContent = await metaFile.readAsString();

        _index = AudioPackIndex.deserialize(indexContent);
        final metaMap = jsonDecode(metaContent) as Map<String, dynamic>;
        _meta = AudioPackMeta.fromJson(metaMap);
      } else {
        _index = null;
        _meta = null;
      }
    } catch (e) {
      debugPrint('[AudioPackManager] Error loading index from disk: $e');
      _index = null;
      _meta = null;
    }
  }

  /// Resolves the absolute [File] for [expression] and [reading] if present in the audio pack.
  ///
  /// Dynamically re-anchors the application support directory path for iOS compatibility.
  Future<File?> getAudioFile({
    required String expression,
    String? reading,
  }) async {
    if (!_isInitialized) {
      await initialize();
    }

    final currentIndex = _index;
    if (currentIndex == null) return null;

    final relativePath = currentIndex.resolveRelativePath(
      expression: expression,
      reading: reading,
    );
    if (relativePath == null) return null;

    final packDir = await _getPackDir();
    final file = File(p.join(packDir.path, relativePath));
    if (await file.exists() && (await file.length()) > 0) {
      return file;
    }
    return null;
  }

  /// Imports an audio pack from a local ZIP file.
  Future<int> importZip(
    File zipFile, {
    void Function(double progress)? onProgress,
  }) async {
    if (!await zipFile.exists()) {
      throw FileSystemException('Zip file does not exist', zipFile.path);
    }

    final stagingDir = await _getStagingDir();
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }
    await stagingDir.create(recursive: true);

    onProgress?.call(0.1);

    final payload = _AudioPackExtractPayload(
      zipPath: zipFile.path,
      stagingDir: stagingDir.path,
    );

    // Run extraction & index generation on a worker isolate
    final result = await compute(_extractAndIndexArchive, payload);
    onProgress?.call(0.8);

    // Write index.json and meta.json in staging dir
    await File(p.join(stagingDir.path, indexFileName))
        .writeAsString(result.indexJson);
    await File(p.join(stagingDir.path, metaFileName))
        .writeAsString(result.metaJson);

    onProgress?.call(0.9);

    // Atomic swap: replace active audio_pack with staging directory
    final packDir = await _getPackDir();
    if (await packDir.exists()) {
      final trashDir = Directory('${packDir.path}_trash_${DateTime.now().millisecondsSinceEpoch}');
      await packDir.rename(trashDir.path);
      // Delete trash asynchronously
      unawaited(trashDir.delete(recursive: true).then<void>((_) {}, onError: (_) {}));
    }

    await stagingDir.rename(packDir.path);
    await excludeFromIosBackup([packDir.path]);

    // Reload in-memory state
    await _loadFromDisk();
    onProgress?.call(1.0);

    logUsage(
      'audio_pack.imported',
      attrs: {
        'word_count': result.fileCount,
        'size_bytes': result.totalBytes,
      },
    );

    return result.fileCount;
  }

  /// Downloads the curated Japanese word audio pack and installs it.
  Future<int> downloadPack({
    String? url,
    void Function(double progress)? onProgress,
    bool wifiOnly = false,
  }) async {
    final targetUrl = url ?? defaultAudioPackUrl;
    final stopwatch = Stopwatch()..start();

    try {
      final tempDir = await getTemporaryDirectory();
      final tempZipPath = p.join(
        tempDir.path,
        'audio_pack_${DateTime.now().millisecondsSinceEpoch}.zip',
      );

      final wordCount = await withDownloadedFile(
        targetUrl,
        tempZipPath,
        wifiOnly: wifiOnly,
        onProgress: (downloadProgress) {
          // Map 0.0 - 1.0 download to 0.0 - 0.85 overall progress
          onProgress?.call(downloadProgress * 0.85);
        },
        use: (zipPath) async {
          onProgress?.call(0.85);
          return await importZip(
            File(zipPath),
            onProgress: (extractProgress) {
              // Map 0.0 - 1.0 extraction to 0.85 - 1.0 overall progress
              onProgress?.call(0.85 + (extractProgress * 0.15));
            },
          );
        },
      );

      logUsage(
        'download.completed',
        attrs: {
          'asset': 'audio_pack',
          'duration_ms': stopwatch.elapsedMilliseconds,
          'word_count': wordCount,
        },
      );

      return wordCount;
    } catch (e) {
      logFailure('download.failed', e, attrs: {'asset': 'audio_pack'});
      rethrow;
    }
  }

  /// Completely deletes the installed audio pack and resets state.
  Future<void> deletePack() async {
    final packDir = await _getPackDir();
    if (await packDir.exists()) {
      await packDir.delete(recursive: true);
    }
    final stagingDir = await _getStagingDir();
    if (await stagingDir.exists()) {
      await stagingDir.delete(recursive: true);
    }

    _index = null;
    _meta = null;
    logUsage('download.uninstalled', attrs: {'asset': 'audio_pack'});
  }
}
