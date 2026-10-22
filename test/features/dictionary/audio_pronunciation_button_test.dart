import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mekuru/features/dictionary/data/models/word_audio_models.dart';
import 'package:mekuru/features/dictionary/presentation/providers/word_audio_providers.dart';
import 'package:mekuru/features/dictionary/presentation/widgets/audio_pronunciation_button.dart';

import '../../test_app.dart';

class _FakeWordAudioPlaybackNotifier extends WordAudioPlaybackNotifier {
  final AudioPlaybackState _initial;
  String? lastPlayedExpression;
  String? lastPlayedReading;

  _FakeWordAudioPlaybackNotifier(this._initial);

  @override
  AudioPlaybackState build() => _initial;

  @override
  Future<void> playWord({required String expression, String? reading}) async {
    lastPlayedExpression = expression;
    lastPlayedReading = reading;
  }
}

void main() {
  Widget buildTestWidget({
    required AudioPlaybackState state,
    required String expression,
    String? reading,
    _FakeWordAudioPlaybackNotifier? notifier,
  }) {
    final fakeNotifier = notifier ?? _FakeWordAudioPlaybackNotifier(state);
    return ProviderScope(
      overrides: [
        wordAudioPlaybackProvider.overrideWith(() => fakeNotifier),
      ],
      child: buildLocalizedTestApp(
        home: Scaffold(
          body: Center(
            child: AudioPronunciationButton(
              expression: expression,
              reading: reading,
            ),
          ),
        ),
      ),
    );
  }

  group('AudioPronunciationButton', () {
    testWidgets('displays outlined speaker icon when idle', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          state: const AudioPlaybackState.idle(),
          expression: '食べる',
          reading: 'たべる',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('displays circular progress indicator when loading this word', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          state: const AudioPlaybackState(
            status: AudioPlaybackStatus.loading,
            expression: '食べる',
            reading: 'たべる',
          ),
          expression: '食べる',
          reading: 'たべる',
        ),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays filled rounded speaker icon when playing this word', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          state: const AudioPlaybackState(
            status: AudioPlaybackStatus.playing,
            expression: '食べる',
            reading: 'たべる',
          ),
          expression: '食べる',
          reading: 'たべる',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
    });

    testWidgets('displays error icon when error occurs for this word', (tester) async {
      await tester.pumpWidget(
        buildTestWidget(
          state: const AudioPlaybackState(
            status: AudioPlaybackStatus.error,
            expression: '食べる',
            reading: 'たべる',
            errorMessage: 'Pronunciation unavailable',
          ),
          expression: '食べる',
          reading: 'たべる',
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_off_outlined), findsOneWidget);
    });

    testWidgets('triggers playWord on tap when idle', (tester) async {
      final notifier = _FakeWordAudioPlaybackNotifier(const AudioPlaybackState.idle());

      await tester.pumpWidget(
        buildTestWidget(
          state: const AudioPlaybackState.idle(),
          expression: '食べる',
          reading: 'たべる',
          notifier: notifier,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(AudioPronunciationButton));
      await tester.pump();

      expect(notifier.lastPlayedExpression, '食べる');
      expect(notifier.lastPlayedReading, 'たべる');
    });
  });
}
