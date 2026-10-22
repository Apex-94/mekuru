import 'dart:convert';
import 'package:path/path.dart' as p;

/// Pure Dart index mapping Japanese word expressions and readings to relative audio file paths.
class AudioPackIndex {
  /// Maps normalized `${expression}_${reading}` -> relative audio path.
  final Map<String, String> exactMap;

  /// Maps normalized `${reading}` -> relative audio path.
  final Map<String, String> readingMap;

  /// Maps normalized `${expression}` -> relative audio path.
  final Map<String, String> expressionMap;

  const AudioPackIndex({
    required this.exactMap,
    required this.readingMap,
    required this.expressionMap,
  });

  const AudioPackIndex.empty()
      : exactMap = const {},
        readingMap = const {},
        expressionMap = const {};

  /// Total number of unique audio files indexed.
  int get uniqueFileCount {
    final set = <String>{};
    set.addAll(exactMap.values);
    set.addAll(readingMap.values);
    set.addAll(expressionMap.values);
    return set.length;
  }

  /// Resolves the relative path to an audio file for [expression] and [reading] in O(1) time.
  String? resolveRelativePath({
    required String expression,
    String? reading,
  }) {
    final exp = expression.trim();
    final read = (reading ?? '').trim();

    // 1. Compound match: expression_reading
    if (read.isNotEmpty) {
      final exactKey = '${exp}_$read';
      final exactMatch = exactMap[exactKey];
      if (exactMatch != null) return exactMatch;
    }

    // 2. Reading match
    if (read.isNotEmpty) {
      final readMatch = readingMap[read];
      if (readMatch != null) return readMatch;
    }

    // 3. Expression match
    if (exp.isNotEmpty) {
      final expMatch = expressionMap[exp];
      if (expMatch != null) return expMatch;
    }

    return null;
  }

  Map<String, dynamic> toJson() => {
    'exact': exactMap,
    'reading': readingMap,
    'expression': expressionMap,
  };

  factory AudioPackIndex.fromJson(Map<String, dynamic> json) => AudioPackIndex(
    exactMap: Map<String, String>.from(json['exact'] as Map? ?? const {}),
    readingMap: Map<String, String>.from(json['reading'] as Map? ?? const {}),
    expressionMap: Map<String, String>.from(
      json['expression'] as Map? ?? const {},
    ),
  );

  String serialize() => jsonEncode(toJson());

  factory AudioPackIndex.deserialize(String jsonStr) {
    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      return AudioPackIndex.fromJson(map);
    } catch (_) {
      return const AudioPackIndex.empty();
    }
  }
}

/// Pure Dart utility service for building and resolving `AudioPackIndex`.
class AudioPackIndexService {
  const AudioPackIndexService();

  static const supportedExtensions = {
    '.mp3',
    '.m4a',
    '.ogg',
    '.wav',
    '.aac',
    '.opus',
    '.flac',
  };

  static final RegExp _kanaRegex = RegExp(
    r'^[\u3040-\u309F\u30A0-\u30FF\u31F0-\u31FF\uFF65-\uFF9Fー\s]+$',
  );

  /// Returns true if [text] consists exclusively of Kana characters and spaces.
  static bool isKanaOnly(String text) {
    if (text.isEmpty) return false;
    return _kanaRegex.hasMatch(text);
  }

  /// Builds an [AudioPackIndex] by parsing a collection of relative audio file paths.
  static AudioPackIndex buildIndex(Iterable<String> relativePaths) {
    final exactMap = <String, String>{};
    final readingMap = <String, String>{};
    final expressionMap = <String, String>{};

    for (final rawPath in relativePaths) {
      final ext = p.extension(rawPath).toLowerCase();
      if (!supportedExtensions.contains(ext)) continue;

      final baseName = p.basenameWithoutExtension(rawPath);
      // Normalize and sanitize filename (strip copy indicators like " (1)" or "[1]")
      final sanitized = baseName
          .replaceAll(RegExp(r'\s*\(\d+\)$'), '')
          .replaceAll(RegExp(r'\[\d+\]$'), '')
          .trim();

      if (sanitized.isEmpty) continue;

      if (sanitized.contains('_')) {
        final splitIndex = sanitized.indexOf('_');
        final exp = sanitized.substring(0, splitIndex).trim();
        final read = sanitized.substring(splitIndex + 1).trim();

        if (exp.isNotEmpty && read.isNotEmpty) {
          exactMap['${exp}_$read'] = rawPath;
          expressionMap.putIfAbsent(exp, () => rawPath);
          readingMap.putIfAbsent(read, () => rawPath);
        } else if (exp.isNotEmpty) {
          expressionMap.putIfAbsent(exp, () => rawPath);
        }
      } else {
        if (isKanaOnly(sanitized)) {
          readingMap.putIfAbsent(sanitized, () => rawPath);
          expressionMap.putIfAbsent(sanitized, () => rawPath);
        } else {
          expressionMap.putIfAbsent(sanitized, () => rawPath);
        }
      }
    }

    return AudioPackIndex(
      exactMap: exactMap,
      readingMap: readingMap,
      expressionMap: expressionMap,
    );
  }
}
