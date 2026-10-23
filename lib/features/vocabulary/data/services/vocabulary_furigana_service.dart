import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mekuru/features/reader/data/services/furigana_generator.dart';
import 'package:mekuru/shared/widgets/furigana_text.dart';

/// Service that generates per-word and sentence-level furigana for vocabulary entries.
class VocabularyFuriganaService {
  const VocabularyFuriganaService({
    this.tokenizer = const MecabFuriganaTokenizer(),
  });

  final FuriganaTokenizer tokenizer;

  /// Generates ruby [FuriganaSegment]s for [sentence].
  ///
  /// Uses MeCab tokenizer when available to annotate all kanji with hiragana readings.
  /// If the morphological analyzer is unavailable, falls back to annotating the
  /// target vocabulary [expression] using [reading].
  Future<List<FuriganaSegment>> generateFurigana(
    String sentence, {
    String? expression,
    String? reading,
  }) async {
    if (sentence.isEmpty) return const [];

    try {
      final generator = FuriganaGenerator(tokenizer);
      final results = await generator.generate([sentence]);
      if (results != null && results.isNotEmpty) {
        final segmentsRaw = results.first['segments'] as List<dynamic>?;
        if (segmentsRaw != null && segmentsRaw.isNotEmpty) {
          return segmentsRaw.map((s) {
            final map = s as Map<String, Object?>;
            return FuriganaSegment(
              map['t']! as String,
              map['f'] as String?,
            );
          }).toList();
        }
      }
    } catch (_) {
      // Fallback on error or missing native library
    }

    return fallbackSegments(sentence, expression: expression, reading: reading);
  }

  /// Pure fallback segmenter that annotates [expression] with [reading] inside [sentence].
  static List<FuriganaSegment> fallbackSegments(
    String sentence, {
    String? expression,
    String? reading,
  }) {
    if (expression == null ||
        expression.isEmpty ||
        reading == null ||
        reading.isEmpty ||
        reading == expression ||
        !sentence.contains(expression)) {
      return [FuriganaSegment(sentence)];
    }

    final segments = <FuriganaSegment>[];
    var remaining = sentence;
    final wordSegments = segmentFurigana(expression, reading);

    while (remaining.isNotEmpty) {
      final idx = remaining.indexOf(expression);
      if (idx == -1) {
        segments.add(FuriganaSegment(remaining));
        break;
      }
      if (idx > 0) {
        segments.add(FuriganaSegment(remaining.substring(0, idx)));
      }
      segments.addAll(wordSegments);
      remaining = remaining.substring(idx + expression.length);
    }

    return segments;
  }
}

/// Provider for [VocabularyFuriganaService].
final vocabularyFuriganaServiceProvider =
    Provider<VocabularyFuriganaService>((ref) {
  return const VocabularyFuriganaService();
});
