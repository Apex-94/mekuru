import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/dictionary/data/services/word_audio_resolver.dart';

void main() {
  group('WordAudioResolver.containsKanji', () {
    test('returns true for words containing Kanji', () {
      expect(WordAudioResolver.containsKanji('食べる'), isTrue);
      expect(WordAudioResolver.containsKanji('日本語'), isTrue);
      expect(WordAudioResolver.containsKanji('一'), isTrue);
    });

    test('returns false for Kana-only or Latin text', () {
      expect(WordAudioResolver.containsKanji('ありがとう'), isFalse);
      expect(WordAudioResolver.containsKanji('コーヒー'), isFalse);
      expect(WordAudioResolver.containsKanji('hello'), isFalse);
      expect(WordAudioResolver.containsKanji('123'), isFalse);
      expect(WordAudioResolver.containsKanji(''), isFalse);
    });
  });

  group('WordAudioResolver.buildJapanesePod101Url', () {
    test('constructs valid URL for Kanji word with reading', () {
      final url = WordAudioResolver.buildJapanesePod101Url(
        expression: '食べる',
        reading: 'たべる',
      );

      final uri = Uri.parse(url);
      expect(uri.scheme, 'https');
      expect(uri.host, 'assets.languagepod101.com');
      expect(uri.path, '/dictionary/japanese/audiomp3.php');
      expect(uri.queryParameters['kanji'], '食べる');
      expect(uri.queryParameters['kana'], 'たべる');
    });

    test('constructs valid URL for Kanji word with empty reading', () {
      final url = WordAudioResolver.buildJapanesePod101Url(
        expression: '本',
        reading: '',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['kanji'], '本');
      expect(uri.queryParameters['kana'], '本');
    });

    test('constructs valid URL for Kana-only word', () {
      final url = WordAudioResolver.buildJapanesePod101Url(
        expression: 'ありがとう',
        reading: 'ありがとう',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['kanji'], 'ありがとう');
      expect(uri.queryParameters['kana'], 'ありがとう');
    });

    test('trims whitespace before encoding URL parameters', () {
      final url = WordAudioResolver.buildJapanesePod101Url(
        expression: '  食べる  ',
        reading: '  たべる  ',
      );

      final uri = Uri.parse(url);
      expect(uri.queryParameters['kanji'], '食べる');
      expect(uri.queryParameters['kana'], 'たべる');
    });
  });

  group('WordAudioResolver.computeAudioCacheKey', () {
    test('is deterministic for identical expression and reading', () {
      final key1 = WordAudioResolver.computeAudioCacheKey(
        expression: '食べる',
        reading: 'たべる',
      );
      final key2 = WordAudioResolver.computeAudioCacheKey(
        expression: '食べる',
        reading: 'たべる',
      );

      expect(key1, key2);
      expect(key1.length, 32);
    });

    test('normalizes whitespace around inputs', () {
      final key1 = WordAudioResolver.computeAudioCacheKey(
        expression: '食べる',
        reading: 'たべる',
      );
      final key2 = WordAudioResolver.computeAudioCacheKey(
        expression: '  食べる  ',
        reading: '  たべる  ',
      );

      expect(key1, key2);
    });

    test('produces different keys for different readings of same expression', () {
      final key1 = WordAudioResolver.computeAudioCacheKey(
        expression: '角',
        reading: 'かど',
      );
      final key2 = WordAudioResolver.computeAudioCacheKey(
        expression: '角',
        reading: 'つの',
      );

      expect(key1, isNot(equals(key2)));
    });
  });

  group('WordAudioResolver.resolveTtsSpeechText', () {
    test('prefers reading over expression when reading is available', () {
      final text = WordAudioResolver.resolveTtsSpeechText(
        expression: '私',
        reading: 'わたし',
      );

      expect(text, 'わたし');
    });

    test('falls back to expression when reading is empty or whitespace', () {
      final text1 = WordAudioResolver.resolveTtsSpeechText(
        expression: 'ありがとう',
        reading: '',
      );
      final text2 = WordAudioResolver.resolveTtsSpeechText(
        expression: '猫',
        reading: '   ',
      );

      expect(text1, 'ありがとう');
      expect(text2, '猫');
    });
  });

  group('WordAudioResolver.isValidAudioBytes', () {
    test('returns false when byte length is less than 512 bytes', () {
      final shortBytes = Uint8List(511);
      expect(WordAudioResolver.isValidAudioBytes(shortBytes), isFalse);
    });

    test('returns true for MP3 with ID3v2 header', () {
      final bytes = Uint8List(1024);
      // 'ID3' header
      bytes[0] = 0x49; // 'I'
      bytes[1] = 0x44; // 'D'
      bytes[2] = 0x33; // '3'
      expect(WordAudioResolver.isValidAudioBytes(bytes), isTrue);
    });

    test('returns true for raw MP3 sync frame (0xFF 0xFB)', () {
      final bytes = Uint8List(1024);
      bytes[0] = 0xFF;
      bytes[1] = 0xFB; // MPEG-1 Layer 3
      expect(WordAudioResolver.isValidAudioBytes(bytes), isTrue);
    });

    test('returns true for RIFF WAVE audio', () {
      final bytes = Uint8List(1024);
      // 'RIFF'
      bytes[0] = 0x52;
      bytes[1] = 0x49;
      bytes[2] = 0x46;
      bytes[3] = 0x46;
      // 'WAVE' at offset 8
      bytes[8] = 0x57;
      bytes[9] = 0x41;
      bytes[10] = 0x56;
      bytes[11] = 0x45;
      expect(WordAudioResolver.isValidAudioBytes(bytes), isTrue);
    });

    test('returns false for HTML error response disguised as large payload', () {
      final padding = ' ' * 600;
      final html = '<!DOCTYPE html><html><body>404 Not Found</body></html>$padding';
      final bytes = Uint8List.fromList(utf8.encode(html));
      expect(WordAudioResolver.isValidAudioBytes(bytes), isFalse);
    });

    test('returns false for JSON error response disguised as large payload', () {
      final padding = ' ' * 600;
      final json = '{"error": "word not found in dictionary"}$padding';
      final bytes = Uint8List.fromList(utf8.encode(json));
      expect(WordAudioResolver.isValidAudioBytes(bytes), isFalse);
    });

    test('returns false for arbitrary unformatted byte streams', () {
      final bytes = Uint8List(1024); // all zeros
      expect(WordAudioResolver.isValidAudioBytes(bytes), isFalse);
    });
  });
}
