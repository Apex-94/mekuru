import 'package:flutter/material.dart';
import 'package:mekuru/core/utils/japanese_text.dart';
import 'package:mekuru/features/dictionary/presentation/widgets/hit_testable_rich_text.dart';
import 'package:mekuru/shared/widgets/furigana_text.dart';

/// Displays a Japanese expression with furigana only above kanji, where each
/// kanji character is individually tappable.
///
/// Kana portions are rendered as plain text at the normal baseline. Kanji
/// characters are styled to indicate tappability, and each segment's text
/// resolves which of its kanji was tapped.
///
/// If [reading] is empty or matches [expression], only the expression is shown.
class TappableExpressionText extends StatefulWidget {
  const TappableExpressionText({
    super.key,
    required this.expression,
    required this.reading,
    required this.onKanjiTap,
    this.expressionStyle,
    this.furiganaStyle,
  });

  final String expression;
  final String reading;
  final void Function(String kanji) onKanjiTap;
  final TextStyle? expressionStyle;
  final TextStyle? furiganaStyle;

  @override
  State<TappableExpressionText> createState() => _TappableExpressionTextState();
}

class _TappableExpressionTextState extends State<TappableExpressionText> {
  List<_ExpressionSegmentCache> _segmentCache = const [];

  @override
  void initState() {
    super.initState();
    _rebuildSegmentCache();
  }

  @override
  void didUpdateWidget(TappableExpressionText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.expression != widget.expression ||
        oldWidget.reading != widget.reading) {
      _rebuildSegmentCache();
    }
  }

  @override
  void reassemble() {
    super.reassemble();
    _rebuildSegmentCache();
  }

  void _rebuildSegmentCache() {
    final showFurigana =
        widget.reading.isNotEmpty && widget.reading != widget.expression;

    final rawSegments = showFurigana
        ? segmentFurigana(widget.expression, widget.reading)
        : [FuriganaSegment(widget.expression)];

    _segmentCache = rawSegments
        .map((segment) {
          return _ExpressionSegmentCache(
            furigana: segment.furigana,
            glyphs: _buildGlyphCache(segment.text),
          );
        })
        .toList(growable: false);
  }

  List<_ExpressionGlyphCache> _buildGlyphCache(String text) {
    final glyphs = <_ExpressionGlyphCache>[];
    for (var i = 0; i < text.length; i++) {
      final char = text[i];
      glyphs.add(
        _ExpressionGlyphCache(char, isTappable: isKanji(char.codeUnitAt(0))),
      );
    }
    return glyphs;
  }

  List<InlineSpan> _buildCharSpans(
    List<_ExpressionGlyphCache> glyphs,
    TextStyle? baseStyle,
    TextStyle? kanjiStyle,
  ) {
    return glyphs
        .map((glyph) {
          return TextSpan(
            text: glyph.char,
            style: glyph.isTappable ? kanjiStyle : baseStyle,
          );
        })
        .toList(growable: false);
  }

  List<TextTapTarget> _buildFlatTargets(List<_ExpressionGlyphCache> glyphs) {
    final targets = <TextTapTarget>[];
    for (var i = 0; i < glyphs.length; i++) {
      final glyph = glyphs[i];
      if (!glyph.isTappable) continue;
      targets.add(TextTapTarget(start: i, end: i + 1, value: glyph.char));
    }
    return targets;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final exprStyle =
        widget.expressionStyle ??
        Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold);

    final kanjiStyle = exprStyle?.copyWith(
      color: theme.colorScheme.primary,
      decoration: TextDecoration.underline,
      decorationStyle: TextDecorationStyle.dotted,
      decorationColor: theme.colorScheme.primary.withAlpha(100),
    );

    final furiStyle =
        widget.furiganaStyle ??
        exprStyle?.copyWith(
          fontSize: (exprStyle.fontSize ?? 16) * 0.55,
          fontWeight: FontWeight.w400,
          height: 1.0,
        );

    // A Wrap, so a word wider than the line breaks between segments (and a
    // segment wider than the line wraps its own text) instead of overflowing.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: _segmentCache
          .map((segment) {
            final base = HitTestableRichText(
              text: TextSpan(
                children: _buildCharSpans(
                  segment.glyphs,
                  exprStyle,
                  kanjiStyle,
                ),
                style: exprStyle,
              ),
              targets: _buildFlatTargets(segment.glyphs),
              onTapTarget: widget.onKanjiTap,
            );
            final furigana = segment.furigana;
            if (furigana == null) return base;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(furigana, style: furiStyle, textAlign: TextAlign.center),
                base,
              ],
            );
          })
          .toList(growable: false),
    );
  }
}

class _ExpressionSegmentCache {
  const _ExpressionSegmentCache({required this.furigana, required this.glyphs});

  final String? furigana;
  final List<_ExpressionGlyphCache> glyphs;
}

class _ExpressionGlyphCache {
  const _ExpressionGlyphCache(this.char, {required this.isTappable});

  final String char;
  final bool isTappable;
}
