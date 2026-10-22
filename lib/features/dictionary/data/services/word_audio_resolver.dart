import 'dart:convert';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// Pure Dart utility service for resolving audio pronunciation URLs, cache keys,
/// audio byte integrity, and TTS fallback text.
///
/// Strictly free of Flutter UI widget imports to maintain unit-testability.
class WordAudioResolver {
  const WordAudioResolver();

  /// Regular expression matching CJK Unified Ideographs (Kanji).
  static final RegExp _kanjiRegex = RegExp(
    r'[\u4E00-\u9FFF\u3400-\u4DBF\uF900-\uFAFF]',
  );

  /// JapanesePod101 audio endpoint base URL.
  static const String jpodBaseUrl =
      'https://assets.languagepod101.com/dictionary/japanese/audiomp3.php';

  /// Minimum byte length for an audio file to be considered valid and non-empty.
  static const int minValidAudioByteLength = 512;

  /// Returns true if [text] contains at least one Kanji character.
  static bool containsKanji(String text) {
    return _kanjiRegex.hasMatch(text);
  }

  /// Builds the JapanesePod101 audio pronunciation URL for [expression] and [reading].
  ///
  /// URL rules:
  /// - If [expression] contains Kanji (e.g., 食べる, reading たべる):
  ///     kanji = expression, kana = reading (or expression if reading is empty)
  /// - If [expression] is Kana-only (e.g., ありがとう):
  ///     kanji = expression, kana = expression
  ///
  /// Parameters are URL-component encoded.
  static String buildJapanesePod101Url({
    required String expression,
    required String reading,
  }) {
    final exp = expression.trim();
    final read = reading.trim();

    final String kanjiParam;
    final String kanaParam;

    if (containsKanji(exp)) {
      kanjiParam = exp;
      kanaParam = read.isNotEmpty ? read : exp;
    } else {
      kanjiParam = exp;
      kanaParam = exp;
    }

    final encodedKanji = Uri.encodeComponent(kanjiParam);
    final encodedKana = Uri.encodeComponent(kanaParam);

    return '$jpodBaseUrl?kanji=$encodedKanji&kana=$encodedKana';
  }

  /// Computes a deterministic MD5 cache key for [expression] and [reading].
  ///
  /// Normalizes whitespace and returns a 32-character lowercase hex string.
  static String computeAudioCacheKey({
    required String expression,
    required String reading,
  }) {
    final normalized = '${expression.trim()}_${reading.trim()}';
    return md5.convert(utf8.encode(normalized)).toString();
  }

  /// Resolves the optimal text to pass to the TTS engine.
  ///
  /// Prefers [reading] (Hiragana/Katakana) when non-empty to ensure correct
  /// pronunciation of words with alternate or irregular readings. Falls back
  /// to [expression].
  static String resolveTtsSpeechText({
    required String expression,
    required String reading,
  }) {
    final read = reading.trim();
    if (read.isNotEmpty) {
      return read;
    }
    return expression.trim();
  }

  /// Validates whether [bytes] represents a legitimate audio payload.
  ///
  /// Checks for:
  /// 1. Minimum byte length ([minValidAudioByteLength]).
  /// 2. Common audio container/codec headers (MP3 ID3v2, raw MP3 frame sync,
  ///    WAV, AAC ADTS, OGG).
  /// 3. Rejects HTML, XML, or plain text error pages.
  static bool isValidAudioBytes(Uint8List bytes) {
    if (bytes.length < minValidAudioByteLength) {
      return false;
    }

    // Check for HTML/XML error responses: '<!DOC', '<html', '<?xml', '{"error"'
    if (bytes[0] == 0x3C /* '<' */ || bytes[0] == 0x7B /* '{' */) {
      final prefix = utf8.decode(bytes.sublist(0, 16), allowMalformed: true).toLowerCase();
      if (prefix.startsWith('<!doc') ||
          prefix.startsWith('<html') ||
          prefix.startsWith('<?xml') ||
          prefix.startsWith('{"err')) {
        return false;
      }
    }

    // 1. MP3 with ID3v2 header: 'ID3' (0x49, 0x44, 0x33)
    if (bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) {
      return true;
    }

    // 2. Raw MP3 sync frame: 11 set bits (0xFF followed by byte with upper 3 bits set: 0xE0)
    // Common second bytes: 0xFB (MPEG-1 Layer 3), 0xF3 (MPEG-2 Layer 3), 0xF2 (MPEG-2.5 Layer 3)
    if (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0) {
      return true;
    }

    // 3. RIFF WAV: 'RIFF' at 0..3 and 'WAVE' at 8..11
    if (bytes.length >= 12 &&
        bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46 &&
        bytes[8] == 0x57 && bytes[9] == 0x41 && bytes[10] == 0x56 && bytes[11] == 0x45) {
      return true;
    }

    // 4. AAC ADTS: 0xFF followed by 0xF0..0xF9
    if (bytes[0] == 0xFF && (bytes[1] & 0xF6) == 0xF0) {
      return true;
    }

    // 5. OGG container: 'OggS' (0x4F, 0x67, 0x67, 0x53)
    if (bytes[0] == 0x4F && bytes[1] == 0x67 && bytes[2] == 0x67 && bytes[3] == 0x53) {
      return true;
    }

    return false;
  }
}
