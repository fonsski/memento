import 'package:flutter/material.dart';

import '../domain/inline_markdown_tokenizer.dart';

/// A [TextEditingController] for a single block's text: renders
/// `**bold**`/`*italic*`/`` `code` `` with dimmed markers and styled
/// content, via [tokenizeInlineMarkdown]. Editing behaves exactly like a
/// normal text field — only the rendering (via [buildTextSpan]) differs.
///
/// Unlike the old whole-document `MarkdownSyntaxController`, this never
/// sees `#`/list/quote markers — those are [Block.type] in the block
/// model, not characters inside the text this controller renders.
class InlineMarkdownController extends TextEditingController {
  InlineMarkdownController({super.text});

  /// Opacity applied to the base text color for dimmed markers, so they
  /// stay legible (this is still Markdown, not hidden) without competing
  /// with actual content.
  static const double markerOpacity = 0.28;

  /// Markers are also shrunk slightly relative to the surrounding text,
  /// on top of the opacity drop, so they read as quiet punctuation
  /// rather than content competing for attention.
  static const double markerFontScale = 0.85;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    final Color color = style?.color ?? const Color(0xFF000000);
    final Color dimColor = color.withValues(alpha: markerOpacity);

    return TextSpan(
      style: style,
      children: [
        for (final InlineToken token in tokenizeInlineMarkdown(text))
          TextSpan(
            text: token.text,
            style: _styleFor(token.kind, style, dimColor),
          ),
      ],
    );
  }

  TextStyle? _styleFor(InlineSpanKind kind, TextStyle? base, Color dimColor) {
    switch (kind) {
      case InlineSpanKind.marker:
        final double? baseSize = base?.fontSize;
        return base?.copyWith(
          color: dimColor,
          fontSize: baseSize == null ? null : baseSize * markerFontScale,
        );
      case InlineSpanKind.bold:
        return base?.copyWith(fontWeight: FontWeight.w700);
      case InlineSpanKind.italic:
        return base?.copyWith(fontStyle: FontStyle.italic);
      case InlineSpanKind.code:
        return base?.copyWith(fontFamily: 'JetBrains Mono');
      case InlineSpanKind.plain:
        return base;
    }
  }
}
