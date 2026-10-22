import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/tts/data/services/tts_speech_text_resolver.dart';

void main() {
  group('TtsSpeechTextResolver', () {
    group('reading priority over kanji expression', () {
      test('prioritizes kana reading over kanji expression for correct phonetic pronunciation', () {
        final result = TtsSpeechTextResolver.resolveSpeechText(
          expression: '角',
          reading: 'つの',
        );
        expect(result, 'つの');
      });

      test('resolves ambiguous homophone kanji by exact dictionary reading', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(expression: '一日', reading: 'ついたち'),
          'ついたち',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(expression: '一日', reading: 'いちにち'),
          'いちにち',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(expression: '明日', reading: 'あした'),
          'あした',
        );
      });
    });

    group('expression fallback when reading is absent', () {
      test('falls back to expression when reading is null', () {
        final result = TtsSpeechTextResolver.resolveSpeechText(
          expression: '食べる',
          reading: null,
        );
        expect(result, '食べる');
      });

      test('falls back to expression when reading is empty', () {
        final result = TtsSpeechTextResolver.resolveSpeechText(
          expression: '飲む',
          reading: '',
        );
        expect(result, '飲む');
      });

      test('falls back to expression when reading contains only whitespace', () {
        final result = TtsSpeechTextResolver.resolveSpeechText(
          expression: '走る',
          reading: '   ',
        );
        expect(result, '走る');
      });

      test('falls back to expression when reading sanitizes to empty string', () {
        final result = TtsSpeechTextResolver.resolveSpeechText(
          expression: '歩く',
          reading: '〜〜・',
        );
        expect(result, '歩く');
      });
    });

    group('bracket and quotation stripping', () {
      test('strips Japanese full-width brackets and parentheses', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '〔角〕',
            reading: '〔つの〕',
          ),
          'つの',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '（角）',
            reading: '（つの）',
          ),
          'つの',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '【角】',
            reading: '【つの】',
          ),
          'つの',
        );
      });

      test('strips Japanese quotation brackets 「」 and 『』', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '「こんにちは」',
            reading: null,
          ),
          'こんにちは',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '『さようなら』',
            reading: null,
          ),
          'さようなら',
        );
      });

      test('strips ASCII brackets and parentheses', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '(テスト)',
            reading: null,
          ),
          'テスト',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '[テスト]',
            reading: null,
          ),
          'テスト',
        );
      });
    });

    group('furigana pattern resolution', () {
      test('resolves Kanji[furigana] syntax to kana', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '漢字[かんじ]',
            reading: null,
          ),
          'かんじ',
        );
      });

      test('resolves inline stem furigana 食[た]べる into full word たべる', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '食[た]べる',
            reading: null,
          ),
          'たべる',
        );
      });

      test('resolves full-width parentheses furigana 漢字（かんじ）', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '漢字（かんじ）',
            reading: null,
          ),
          'かんじ',
        );
      });

      test('resolves half-width parentheses furigana 漢字(かんじ)', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '漢字(かんじ)',
            reading: null,
          ),
          'かんじ',
        );
      });
    });

    group('punctuation, symbols, and tilde stripping', () {
      test('strips leading and trailing wave tildes 〜 and ~', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '〜する',
            reading: '〜する',
          ),
          'する',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '~する~',
            reading: null,
          ),
          'する',
        );
      });

      test('strips leading and trailing middle dots and bullets', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '・テスト・',
            reading: null,
          ),
          'テスト',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '･テスト･',
            reading: null,
          ),
          'テスト',
        );
      });

      test('strips leading and trailing slashes and asterisks', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '/*テスト*/',
            reading: null,
          ),
          'テスト',
        );
      });

      test('strips Japanese and ASCII trailing punctuation', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: 'すごい！',
            reading: 'すごい！',
          ),
          'すごい',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '本当？',
            reading: 'ほんとう？',
          ),
          'ほんとう',
        );
      });
    });

    group('katakana long vowel mark preservation', () {
      test('preserves long vowel mark ー in Katakana words', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: 'コーヒー',
            reading: 'コーヒー',
          ),
          'コーヒー',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: 'ラーメン',
            reading: null,
          ),
          'ラーメン',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: 'スキー',
            reading: null,
          ),
          'スキー',
        );
      });
    });

    group('whitespace and zero-width characters', () {
      test('trims whitespace and removes zero-width characters', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '  食べる  ',
            reading: ' \u200B たべる \uFEFF ',
          ),
          'たべる',
        );
      });

      test('returns empty string when input is completely empty or punctuation', () {
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '',
            reading: '',
          ),
          '',
        );
        expect(
          TtsSpeechTextResolver.resolveSpeechText(
            expression: '〜〜〜///...',
            reading: null,
          ),
          '',
        );
      });
    });
  });
}
