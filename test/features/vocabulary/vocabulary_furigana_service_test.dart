import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/reader/data/services/furigana_generator.dart';
import 'package:mekuru/features/reader/data/services/mecab_service.dart';
import 'package:mekuru/features/vocabulary/data/services/vocabulary_furigana_service.dart';
import 'package:mekuru/shared/widgets/furigana_text.dart';

class _FakeTokenizer implements FuriganaTokenizer {
  _FakeTokenizer(this._byInput, {this.ready = true});
  final Map<String, List<TokenInfo>> _byInput;
  final bool ready;

  @override
  Future<bool> ensureReady() async => ready;

  @override
  List<TokenInfo> tokenize(String text) =>
      _byInput[text] ?? const <TokenInfo>[];
}

TokenInfo _tok(String surface, String reading, int start) => TokenInfo(
      surface: surface,
      dictionaryForm: surface,
      reading: reading,
      pos: '',
      startInText: start,
    );

void main() {
  group('VocabularyFuriganaService', () {
    test('returns empty list for empty sentence', () async {
      const service = VocabularyFuriganaService();
      final segments = await service.generateFurigana('');
      expect(segments, isEmpty);
    });

    test('generates full sentence furigana when tokenizer is ready', () async {
      final fake = _FakeTokenizer({
        '朝ご飯を食べる。': [
          _tok('朝ご飯', 'アサゴハン', 0),
          _tok('を', 'ヲ', 3),
          _tok('食べる', 'タベル', 4),
          _tok('。', '。', 7),
        ],
      });
      final service = VocabularyFuriganaService(tokenizer: fake);
      final segments = await service.generateFurigana(
        '朝ご飯を食べる。',
        expression: '食べる',
        reading: 'たべる',
      );

      expect(segments, isNotEmpty);
      expect(segments.any((s) => s.text == '食べる' || s.text == '食'), isTrue);
    });

    test('falls back to aligning target word when tokenizer is not ready', () async {
      final fake = _FakeTokenizer(const {}, ready: false);
      final service = VocabularyFuriganaService(tokenizer: fake);
      final segments = await service.generateFurigana(
        'パンを食べる。',
        expression: '食べる',
        reading: 'たべる',
      );

      // Should have: "パンを", "食" (reading: "た"), "べる", "。"
      expect(segments, hasLength(4));
      expect(segments[0].text, 'パンを');
      expect(segments[0].furigana, isNull);
      expect(segments[1].text, '食');
      expect(segments[1].furigana, 'た');
      expect(segments[2].text, 'べる');
      expect(segments[2].furigana, isNull);
      expect(segments[3].text, '。');
      expect(segments[3].furigana, isNull);
    });

    test('fallback returns single segment if word not in sentence', () {
      final segments = VocabularyFuriganaService.fallbackSegments(
        '今日はいい天気です。',
        expression: '食べる',
        reading: 'たべる',
      );

      expect(segments, hasLength(1));
      expect(segments[0].text, '今日はいい天気です。');
      expect(segments[0].furigana, isNull);
    });
  });
}
