/// Pure Dart resolver that sanitizes and prepares dictionary words and readings
/// for Japanese text-to-speech synthesis.
///
/// NOTE: In accordance with CLAUDE.md, this pure logic file must remain free of
/// Flutter UI/widget imports.
class TtsSpeechTextResolver {
  const TtsSpeechTextResolver._();

  // Pattern matching Kanji followed by bracketed kana furigana, e.g. 漢字[かんじ] or 食[た]べる
  static final RegExp _furiganaPattern = RegExp(
    r'[\u4e00-\u9faf]+[\[\(（〔]([\u3040-\u309f\u30a0-\u30ff]+)[\]\)）〕]',
  );

  // Standalone bracket characters to strip
  static final RegExp _bracketChars = RegExp(
    r'[\[\]\(\)〔〕（）【】「」『』《》〈〉]',
  );

  // Leading or trailing punctuation, symbols, and whitespace (preserving kana prolonged sound mark ー)
  static final RegExp _leadingTrailingPunctuation = RegExp(
    r'^[〜~・･*\/―—\-、。,.!?！？:;：；…\s]+|[〜~・･*\/―—\-、。,.!?！？:;：；…\s]+$',
  );

  // Zero-width characters and control codes
  static final RegExp _zeroWidthAndControl = RegExp(
    r'[\u200B-\u200D\uFEFF\x00-\x1F\x7F]',
  );

  /// Resolves the optimal text string for Japanese TTS synthesis.
  ///
  /// Prioritizes [reading] (kana) over [expression] (kanji) to guarantee
  /// correct phonetic pronunciation by the OS speech engine.
  static String resolveSpeechText({
    required String expression,
    String? reading,
  }) {
    if (reading != null && reading.trim().isNotEmpty) {
      final sanitizedReading = sanitize(reading);
      if (sanitizedReading.isNotEmpty) {
        return sanitizedReading;
      }
    }

    return sanitize(expression);
  }

  /// Sanitizes raw dictionary text by stripping brackets, furigana artifacts,
  /// leading/trailing tildes, bullets, and extraneous punctuation.
  static String sanitize(String text) {
    if (text.isEmpty) return '';

    var cleaned = text.replaceAll(_zeroWidthAndControl, '');

    // Resolve furigana patterns: e.g. 漢字[かんじ] -> かんじ, 食[た]べる -> たべる
    cleaned = cleaned.replaceAllMapped(_furiganaPattern, (match) {
      return match.group(1) ?? '';
    });

    // Remove standalone bracket characters
    cleaned = cleaned.replaceAll(_bracketChars, '');

    // Iteratively strip leading/trailing punctuation and whitespace
    String prev;
    do {
      prev = cleaned;
      cleaned = cleaned.replaceAll(_leadingTrailingPunctuation, '');
    } while (cleaned != prev);

    return cleaned.trim();
  }
}
