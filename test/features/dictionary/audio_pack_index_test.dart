import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/dictionary/data/services/audio_pack_index_service.dart';

void main() {
  group('AudioPackIndexService & AudioPackIndex', () {
    test('Correctly indexes compound (expression_reading) filenames', () {
      final paths = [
        'audio/食べる_たべる.mp3',
        'audio/飲む_のむ.m4a',
        'audio/行く_いく (1).ogg',
      ];

      final index = AudioPackIndexService.buildIndex(paths);

      // Exact compound resolution
      expect(
        index.resolveRelativePath(expression: '食べる', reading: 'たべる'),
        'audio/食べる_たべる.mp3',
      );
      expect(
        index.resolveRelativePath(expression: '飲む', reading: 'のむ'),
        'audio/飲む_のむ.m4a',
      );
      expect(
        index.resolveRelativePath(expression: '行く', reading: 'いく'),
        'audio/行く_いく (1).ogg',
      );

      // Expression fallback
      expect(
        index.resolveRelativePath(expression: '食べる', reading: ''),
        'audio/食べる_たべる.mp3',
      );

      // Reading fallback
      expect(
        index.resolveRelativePath(expression: '食', reading: 'たべる'),
        'audio/食べる_たべる.mp3',
      );
    });

    test('Indexes Kana-only filenames into readingMap', () {
      final paths = [
        'audio/ありがとう.mp3',
        'audio/こんにちは.wav',
        'audio/ラーメン.opus',
      ];

      final index = AudioPackIndexService.buildIndex(paths);

      expect(
        index.resolveRelativePath(expression: 'ありがとう', reading: 'ありがとう'),
        'audio/ありがとう.mp3',
      );
      expect(
        index.resolveRelativePath(expression: 'こんにちは', reading: 'こんにちは'),
        'audio/こんにちは.wav',
      );
      expect(
        index.resolveRelativePath(expression: 'ラーメン', reading: 'らーめん'),
        'audio/ラーメン.opus', // reading match for expression when read empty or reading match
      );
    });

    test('Indexes Kanji-only filenames into expressionMap', () {
      final paths = [
        'audio/猫.mp3',
        'audio/犬.mp3',
      ];

      final index = AudioPackIndexService.buildIndex(paths);

      expect(
        index.resolveRelativePath(expression: '猫', reading: 'ねこ'),
        'audio/猫.mp3',
      );
      expect(
        index.resolveRelativePath(expression: '犬', reading: ''),
        'audio/犬.mp3',
      );
    });

    test('Serializes to JSON and deserializes correctly', () {
      final paths = [
        'audio/本_ほん.mp3',
        'audio/さようなら.mp3',
      ];

      final original = AudioPackIndexService.buildIndex(paths);
      final serialized = original.serialize();
      final restored = AudioPackIndex.deserialize(serialized);

      expect(
        restored.resolveRelativePath(expression: '本', reading: 'ほん'),
        'audio/本_ほん.mp3',
      );
      expect(
        restored.resolveRelativePath(expression: 'さようなら', reading: 'さようなら'),
        'audio/さようなら.mp3',
      );
      expect(restored.uniqueFileCount, 2);
    });

    test('Returns null on lookup miss', () {
      final index = const AudioPackIndex.empty();
      expect(
        index.resolveRelativePath(expression: '存在しない', reading: 'そんざいしない'),
        isNull,
      );
    });
  });
}
