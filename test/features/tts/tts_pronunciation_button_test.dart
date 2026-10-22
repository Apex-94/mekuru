import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:mekuru/features/tts/data/services/tts_player_service.dart';
import 'package:mekuru/features/tts/presentation/providers/tts_providers.dart';
import 'package:mekuru/features/tts/presentation/widgets/tts_pronunciation_button.dart';
import '../../test_app.dart';

class FakeFlutterTts extends FlutterTts {
  final List<String> spokenTexts = [];
  bool isPlaying = false;

  @override
  Future<dynamic> setLanguage(String language) async => 1;

  @override
  Future<dynamic> setSpeechRate(double rate) async => 1;

  @override
  Future<dynamic> setPitch(double pitch) async => 1;

  @override
  Future<dynamic> setVolume(double volume) async => 1;

  @override
  Future<dynamic> isLanguageAvailable(String language) async => true;

  @override
  Future<dynamic> speak(String text, {bool focus = false}) async {
    spokenTexts.add(text);
    isPlaying = true;
    startHandler?.call();
    return 1;
  }

  @override
  Future<dynamic> stop() async {
    isPlaying = false;
    cancelHandler?.call();
    return 1;
  }

  void triggerCompletion() {
    isPlaying = false;
    completionHandler?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TtsPronunciationButton', () {
    late FakeFlutterTts fakeTts;
    late TtsPlayerService service;

    setUp(() {
      fakeTts = FakeFlutterTts();
      service = TtsPlayerService(tts: fakeTts);
    });

    tearDown(() {
      service.dispose();
    });

    testWidgets('renders idle state with volume_up_outlined icon and tooltip', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlayerServiceProvider.overrideWithValue(service),
          ],
          child: buildLocalizedTestApp(
            home: const Scaffold(
              body: Center(
                child: TtsPronunciationButton(
                  expression: '角',
                  reading: 'つの',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.tooltip, isNotEmpty);
    });

    testWidgets('tapping button triggers tts speak and updates icon to playing state', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlayerServiceProvider.overrideWithValue(service),
          ],
          child: buildLocalizedTestApp(
            home: const Scaffold(
              body: Center(
                child: TtsPronunciationButton(
                  expression: '角',
                  reading: 'つの',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(IconButton));
      await tester.pump();

      expect(fakeTts.spokenTexts, contains('つの'));
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      fakeTts.triggerCompletion();
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
    });

    testWidgets('tapping active playing button stops playback', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlayerServiceProvider.overrideWithValue(service),
          ],
          child: buildLocalizedTestApp(
            home: const Scaffold(
              body: Center(
                child: TtsPronunciationButton(
                  expression: '角',
                  reading: 'つの',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // First tap starts playback
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up), findsOneWidget);

      // Second tap toggles to stop
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(find.byIcon(Icons.volume_up_outlined), findsOneWidget);
      expect(fakeTts.isPlaying, false);
    });

    testWidgets('renders compact variant with compact constraints', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlayerServiceProvider.overrideWithValue(service),
          ],
          child: buildLocalizedTestApp(
            home: const Scaffold(
              body: Center(
                child: TtsPronunciationButton(
                  expression: '角',
                  reading: 'つの',
                  variant: TtsButtonVariant.compact,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final iconButton = tester.widget<IconButton>(find.byType(IconButton));
      expect(iconButton.visualDensity, VisualDensity.compact);
      expect(iconButton.constraints?.minWidth, 32);
      expect(iconButton.constraints?.minHeight, 32);
    });

    testWidgets('renders tonal variant', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            ttsPlayerServiceProvider.overrideWithValue(service),
          ],
          child: buildLocalizedTestApp(
            home: const Scaffold(
              body: Center(
                child: TtsPronunciationButton(
                  expression: '角',
                  reading: 'つの',
                  variant: TtsButtonVariant.tonal,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
    });
  });
}
