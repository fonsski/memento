import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_colors.dart';
import 'package:memento/core/theme/custom_theme.dart';

void main() {
  group('tryParseHexColor', () {
    test('parses a 6-digit hex as opaque', () {
      expect(tryParseHexColor('#C68B46'), const Color(0xFFC68B46));
    });

    test('parses a 6-digit hex without the leading #', () {
      expect(tryParseHexColor('C68B46'), const Color(0xFFC68B46));
    });

    test('parses an 8-digit hex with explicit alpha', () {
      expect(tryParseHexColor('#80C68B46'), const Color(0x80C68B46));
    });

    test('returns null for an invalid string', () {
      expect(tryParseHexColor('not a color'), isNull);
      expect(tryParseHexColor('#GGGGGG'), isNull);
      expect(tryParseHexColor('#ABC'), isNull);
    });
  });

  group('CustomThemeColorSet.fromJson', () {
    final CustomThemeColorSet fallback = CustomThemeColorSet.defaultsFor(
      Brightness.dark,
    );

    test('overrides only the fields present in JSON', () {
      final CustomThemeColorSet result = CustomThemeColorSet.fromJson({
        'accent': '#FF0000',
      }, fallback);

      expect(result.accent, const Color(0xFFFF0000));
      expect(result.backgroundPrimary, fallback.backgroundPrimary);
      expect(result.textPrimary, fallback.textPrimary);
    });

    test('falls back for an invalid hex value', () {
      final CustomThemeColorSet result = CustomThemeColorSet.fromJson({
        'accent': 'garbage',
      }, fallback);

      expect(result.accent, fallback.accent);
    });

    test('falls back entirely for an empty map', () {
      final CustomThemeColorSet result = CustomThemeColorSet.fromJson(
        {},
        fallback,
      );

      expect(result.backgroundPrimary, fallback.backgroundPrimary);
      expect(result.accent, fallback.accent);
      expect(result.info, fallback.info);
    });
  });

  group('CustomThemeDefinition.fromJson', () {
    test('parses a name plus light/dark overrides', () {
      final CustomThemeDefinition theme = CustomThemeDefinition.fromJson({
        'name': 'Океан',
        'dark': {'accent': '#2E86AB'},
        'light': {'accent': '#1B4F72'},
      });

      expect(theme.name, 'Океан');
      expect(theme.dark.accent, const Color(0xFF2E86AB));
      expect(theme.light.accent, const Color(0xFF1B4F72));
      // Untouched fields still fall back to the built-in defaults.
      expect(theme.dark.backgroundPrimary, MementoDarkColors.backgroundPrimary);
      expect(
        theme.light.backgroundPrimary,
        MementoLightColors.backgroundPrimary,
      );
    });

    test('defaults the name when missing or blank', () {
      expect(CustomThemeDefinition.fromJson({}).name, 'Без названия');
      expect(
        CustomThemeDefinition.fromJson({'name': '   '}).name,
        'Без названия',
      );
    });

    test('falls back entirely when light/dark sections are missing', () {
      final CustomThemeDefinition theme = CustomThemeDefinition.fromJson({
        'name': 'Только имя',
      });

      expect(theme.dark.accent, MementoDarkColors.accent);
      expect(theme.light.accent, MementoLightColors.accent);
    });
  });
}
