import 'package:flutter/material.dart';

/// Raw color tokens for the "Ink & Patina" palette.
///
/// These are the base swatches only; [ColorScheme]/[ThemeData] assembly
/// happens in `app_theme.dart`.
class MementoDarkColors {
  const MementoDarkColors._();

  static const Color backgroundPrimary = Color(0xFF0D0E10);
  static const Color backgroundSecondary = Color(0xFF16181B);
  static const Color navPanel = Color(0xFF131518);
  static const Color card = Color(0xFF1C1F23);
  static const Color divider = Color(0xFF2A2D31);

  static const Color textPrimary = Color(0xFFEDEBE6);
  static const Color textSecondary = Color(0xFFA8A6A0);
  static const Color textDisabled = Color(0xFF5C5B58);

  static const Color link = Color(0xFF6FA593);
  static const Color accent = Color(0xFFC68B46);
  static const Color onAccent = Color(0xFF141414);

  static const Color hoverOverlay = Color(0x0FFFFFFF);
  static const Color activeOverlay = Color(0x1AFFFFFF);
  static const Color selectedBackground = Color(0x24C68B46);
  static const Color selectedBorder = accent;

  static const Color error = Color(0xFFC1554A);
  static const Color warning = Color(0xFFD6A23C);
  static const Color success = Color(0xFF6E9B6B);
  static const Color info = Color(0xFF6D87AD);

  static const Color textSelection = Color(0x38C68B46);
  static const Color searchHighlight = Color(0x59F2C24C);
}

class MementoLightColors {
  const MementoLightColors._();

  static const Color backgroundPrimary = Color(0xFFFAF8F4);
  static const Color backgroundSecondary = Color(0xFFF1EEE7);
  static const Color navPanel = Color(0xFFF5F2EC);
  static const Color card = Color(0xFFFFFFFF);
  static const Color divider = Color(0xFFE0DCD3);

  static const Color textPrimary = Color(0xFF1E1C1A);
  static const Color textSecondary = Color(0xFF5C5954);
  static const Color textDisabled = Color(0xFFA6A29A);

  static const Color link = Color(0xFF3F7A68);
  static const Color accent = Color(0xFFA66C2E);
  static const Color onAccent = Color(0xFFFAF8F4);

  static const Color hoverOverlay = Color(0x0A000000);
  static const Color activeOverlay = Color(0x14000000);
  static const Color selectedBackground = Color(0x1FA66C2E);
  static const Color selectedBorder = accent;

  static const Color error = Color(0xFFA8392F);
  static const Color warning = Color(0xFFB5822A);
  static const Color success = Color(0xFF4F7A4D);
  static const Color info = Color(0xFF4E6890);

  static const Color textSelection = Color(0x33A66C2E);
  static const Color searchHighlight = Color(0x66E8B23C);
}
