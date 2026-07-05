import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:memento/core/theme/app_colors.dart';
import 'package:memento/core/theme/app_theme.dart';
import 'package:memento/core/theme/custom_theme.dart';
import 'package:memento/core/theme/memento_colors.dart';

void main() {
  /// Compares only the RGB channels, ignoring alpha — used to check that
  /// a derived overlay/highlight color is "based on" a fully-opaque
  /// source color regardless of the alpha this derivation applies.
  bool sameRgb(Color a, Color b) => a.r == b.r && a.g == b.g && a.b == b.b;

  test('AppTheme.dark/light use the built-in palette by default', () {
    expect(AppTheme.dark.colorScheme.primary, MementoDarkColors.accent);
    expect(AppTheme.light.colorScheme.primary, MementoLightColors.accent);
  });

  test('buildDark applies a custom color set', () {
    const Color customAccent = Color(0xFF2E86AB);
    const Color customNavPanel = Color(0xFF101820);
    final CustomThemeColorSet colors = CustomThemeColorSet.fromJson({
      'accent': '#2E86AB',
      'navPanel': '#101820',
    }, CustomThemeColorSet.defaultsFor(Brightness.dark));

    final ThemeData theme = AppTheme.buildDark(colors);

    expect(theme.colorScheme.primary, customAccent);
    final MementoColors mementoColors = theme.extension<MementoColors>()!;
    expect(mementoColors.navPanel, customNavPanel);
    expect(mementoColors.selectedBorder, customAccent);
  });

  test(
    'derived MementoColors (selection/highlight) track the custom accent',
    () {
      const Color customAccent = Color(0xFF2E86AB);
      final CustomThemeColorSet colors = CustomThemeColorSet.fromJson({
        'accent': '#2E86AB',
      }, CustomThemeColorSet.defaultsFor(Brightness.dark));

      final MementoColors mementoColors = MementoColors.fromColorSet(
        colors,
        Brightness.dark,
      );

      expect(sameRgb(mementoColors.selectedBackground, customAccent), isTrue);
      expect(sameRgb(mementoColors.textSelection, customAccent), isTrue);
      expect(sameRgb(mementoColors.searchHighlight, customAccent), isTrue);
      expect(mementoColors.selectedBackground.a, lessThan(1.0));
    },
  );
}
