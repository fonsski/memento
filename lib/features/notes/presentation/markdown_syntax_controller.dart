import 'package:flutter/material.dart';

import '../../../core/theme/app_typography.dart';
import '../domain/markdown_tokenizer.dart';

/// A [TextEditingController] that renders its raw Markdown text with
/// dimmed syntax markers and styled headings/bold/italic/code, instead of
/// showing plain, uniformly-styled text. Editing behaves exactly like a
/// normal text field — only the rendering (via [buildTextSpan]) differs.
class MarkdownSyntaxController extends TextEditingController {
  MarkdownSyntaxController({super.text});

  /// Opacity applied to the base text color for dimmed markers, so they
  /// stay legible (this is still Markdown, not hidden) without competing
  /// with actual content.
  static const double markerOpacity = 0.28;

  /// Markers are also shrunk slightly relative to the surrounding text,
  /// on top of the opacity drop, so they read as quiet punctuation rather
  /// than content competing for attention.
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
      style: AppEditorTextStyles.body(color),
      children: [
        for (final MarkdownToken token in tokenizeMarkdown(text))
          TextSpan(
            text: token.text,
            style: _styleFor(token.kind, color, dimColor),
          ),
      ],
    );
  }

  TextStyle _styleFor(MarkdownSpanKind kind, Color color, Color dimColor) {
    switch (kind) {
      case MarkdownSpanKind.marker:
      case MarkdownSpanKind.listMarker:
        final TextStyle base = AppEditorTextStyles.body(dimColor);
        return base.copyWith(fontSize: base.fontSize! * markerFontScale);
      case MarkdownSpanKind.heading1:
        return AppEditorTextStyles.heading1(color);
      case MarkdownSpanKind.heading2:
        return AppEditorTextStyles.heading2(color);
      case MarkdownSpanKind.heading3:
        return AppEditorTextStyles.heading3(color);
      case MarkdownSpanKind.heading4:
        return AppEditorTextStyles.heading4(color);
      case MarkdownSpanKind.bold:
        return AppEditorTextStyles.body(
          color,
        ).copyWith(fontWeight: FontWeight.w700);
      case MarkdownSpanKind.italic:
        return AppEditorTextStyles.body(
          color,
        ).copyWith(fontStyle: FontStyle.italic);
      case MarkdownSpanKind.code:
        return AppCodeTextStyle.code(color);
      case MarkdownSpanKind.plain:
        return AppEditorTextStyles.body(color);
    }
  }
}
