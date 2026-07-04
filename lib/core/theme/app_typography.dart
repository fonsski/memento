import 'package:flutter/material.dart';

const String _uiFontFamily = 'Inter';
const String _editorFontFamily = 'PT Serif';
const String _codeFontFamily = 'JetBrains Mono';

/// Builds the Material [TextTheme] used for app chrome (sidebars, menus,
/// buttons, dialogs). Headings use [FontWeight.w600] at most — Memento's
/// calm character never reaches for bold (w700) in the UI.
TextTheme buildUiTextTheme(Color primary, Color secondary) {
  return TextTheme(
    // Screen/dialog headings.
    headlineLarge: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 32,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    headlineMedium: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 28,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    headlineSmall: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 24,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    titleLarge: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 20,
      height: 1.3,
      fontWeight: FontWeight.w600,
      color: primary,
    ),
    // Section headers, important labels.
    titleMedium: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 16,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    titleSmall: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 14,
      height: 1.4,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    // Base UI text: menu items, list rows, body copy in chrome.
    bodyLarge: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 16,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodyMedium: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 14,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: primary,
    ),
    bodySmall: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 12,
      height: 1.4,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    // Buttons and interactive labels.
    labelLarge: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 14,
      height: 1.2,
      fontWeight: FontWeight.w500,
      color: primary,
    ),
    labelMedium: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 13,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
    labelSmall: TextStyle(
      fontFamily: _uiFontFamily,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w400,
      color: secondary,
    ),
  );
}

/// Prose styles for the Markdown editor/reading surface. Deliberately a
/// serif (PT Serif) so a note reads like a page, not a form field — the
/// one typographic signature that sets Memento apart from a plain editor.
class AppEditorTextStyles {
  const AppEditorTextStyles._();

  static TextStyle body(Color color) => TextStyle(
    fontFamily: _editorFontFamily,
    fontSize: 16,
    height: 1.7,
    fontWeight: FontWeight.w400,
    color: color,
  );

  static TextStyle heading1(Color color) => TextStyle(
    fontFamily: _editorFontFamily,
    fontSize: 28,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heading2(Color color) => TextStyle(
    fontFamily: _editorFontFamily,
    fontSize: 24,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heading3(Color color) => TextStyle(
    fontFamily: _editorFontFamily,
    fontSize: 20,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: color,
  );

  static TextStyle heading4(Color color) => TextStyle(
    fontFamily: _editorFontFamily,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: color,
  );
}

/// Monospace style for fenced code blocks and inline code.
class AppCodeTextStyle {
  const AppCodeTextStyle._();

  static TextStyle code(Color color) => TextStyle(
    fontFamily: _codeFontFamily,
    fontSize: 14,
    height: 1.6,
    fontWeight: FontWeight.w400,
    color: color,
  );
}
