import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Parses a `#RRGGBB` or `#AARRGGBB` hex color string (the `#` is
/// optional). Returns `null` for anything else, rather than throwing —
/// user-authored theme JSON is a system boundary and a bad value should
/// fall back to the default, not crash the app.
Color? tryParseHexColor(String value) {
  final String hex = value.trim().replaceFirst('#', '');
  if (hex.length == 6) {
    final int? parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(0xFF000000 | parsed);
  }
  if (hex.length == 8) {
    final int? parsed = int.tryParse(hex, radix: 16);
    return parsed == null ? null : Color(parsed);
  }
  return null;
}

/// The subset of the palette a custom theme can override. Colors that
/// exist only as computed overlays (hover/selection/etc.) aren't part of
/// this — they're derived from [accent] and [divider] in `app_theme.dart`
/// the same way the built-in palettes derive them, so a custom theme
/// re-skins the app by setting far fewer values than the full palette.
@immutable
class CustomThemeColorSet {
  const CustomThemeColorSet({
    required this.backgroundPrimary,
    required this.backgroundSecondary,
    required this.navPanel,
    required this.card,
    required this.divider,
    required this.textPrimary,
    required this.textSecondary,
    required this.textDisabled,
    required this.link,
    required this.accent,
    required this.onAccent,
    required this.error,
    required this.warning,
    required this.success,
    required this.info,
  });

  /// Builds a color set from JSON, falling back field-by-field to
  /// [fallback] for any key that's missing or not a valid hex color.
  factory CustomThemeColorSet.fromJson(
    Map<String, dynamic> json,
    CustomThemeColorSet fallback,
  ) {
    Color read(String key, Color fallbackColor) {
      final Object? value = json[key];
      if (value is String) {
        final Color? parsed = tryParseHexColor(value);
        if (parsed != null) return parsed;
      }
      return fallbackColor;
    }

    return CustomThemeColorSet(
      backgroundPrimary: read('backgroundPrimary', fallback.backgroundPrimary),
      backgroundSecondary: read(
        'backgroundSecondary',
        fallback.backgroundSecondary,
      ),
      navPanel: read('navPanel', fallback.navPanel),
      card: read('card', fallback.card),
      divider: read('divider', fallback.divider),
      textPrimary: read('textPrimary', fallback.textPrimary),
      textSecondary: read('textSecondary', fallback.textSecondary),
      textDisabled: read('textDisabled', fallback.textDisabled),
      link: read('link', fallback.link),
      accent: read('accent', fallback.accent),
      onAccent: read('onAccent', fallback.onAccent),
      error: read('error', fallback.error),
      warning: read('warning', fallback.warning),
      success: read('success', fallback.success),
      info: read('info', fallback.info),
    );
  }

  final Color backgroundPrimary;
  final Color backgroundSecondary;
  final Color navPanel;
  final Color card;
  final Color divider;
  final Color textPrimary;
  final Color textSecondary;
  final Color textDisabled;
  final Color link;
  final Color accent;
  final Color onAccent;
  final Color error;
  final Color warning;
  final Color success;
  final Color info;

  static CustomThemeColorSet defaultsFor(Brightness brightness) =>
      brightness == Brightness.dark ? _defaultDark : _defaultLight;

  static const CustomThemeColorSet _defaultDark = CustomThemeColorSet(
    backgroundPrimary: MementoDarkColors.backgroundPrimary,
    backgroundSecondary: MementoDarkColors.backgroundSecondary,
    navPanel: MementoDarkColors.navPanel,
    card: MementoDarkColors.card,
    divider: MementoDarkColors.divider,
    textPrimary: MementoDarkColors.textPrimary,
    textSecondary: MementoDarkColors.textSecondary,
    textDisabled: MementoDarkColors.textDisabled,
    link: MementoDarkColors.link,
    accent: MementoDarkColors.accent,
    onAccent: MementoDarkColors.onAccent,
    error: MementoDarkColors.error,
    warning: MementoDarkColors.warning,
    success: MementoDarkColors.success,
    info: MementoDarkColors.info,
  );

  static const CustomThemeColorSet _defaultLight = CustomThemeColorSet(
    backgroundPrimary: MementoLightColors.backgroundPrimary,
    backgroundSecondary: MementoLightColors.backgroundSecondary,
    navPanel: MementoLightColors.navPanel,
    card: MementoLightColors.card,
    divider: MementoLightColors.divider,
    textPrimary: MementoLightColors.textPrimary,
    textSecondary: MementoLightColors.textSecondary,
    textDisabled: MementoLightColors.textDisabled,
    link: MementoLightColors.link,
    accent: MementoLightColors.accent,
    onAccent: MementoLightColors.onAccent,
    error: MementoLightColors.error,
    warning: MementoLightColors.warning,
    success: MementoLightColors.success,
    info: MementoLightColors.info,
  );
}

/// A user-authored theme: a display [name] plus a light and dark color
/// set, loaded from a JSON file in the themes folder. See
/// `CustomThemeRepository` for where these files live.
@immutable
class CustomThemeDefinition {
  const CustomThemeDefinition({
    required this.name,
    required this.light,
    required this.dark,
  });

  factory CustomThemeDefinition.fromJson(Map<String, dynamic> json) {
    final String? rawName = json['name'] as String?;
    final String name = (rawName != null && rawName.trim().isNotEmpty)
        ? rawName.trim()
        : 'Без названия';

    final Map<String, dynamic> lightJson =
        (json['light'] as Map<String, dynamic>?) ?? const {};
    final Map<String, dynamic> darkJson =
        (json['dark'] as Map<String, dynamic>?) ?? const {};

    return CustomThemeDefinition(
      name: name,
      light: CustomThemeColorSet.fromJson(
        lightJson,
        CustomThemeColorSet.defaultsFor(Brightness.light),
      ),
      dark: CustomThemeColorSet.fromJson(
        darkJson,
        CustomThemeColorSet.defaultsFor(Brightness.dark),
      ),
    );
  }

  final String name;
  final CustomThemeColorSet light;
  final CustomThemeColorSet dark;
}
