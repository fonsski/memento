import 'package:flutter/material.dart';

import 'app_typography.dart';
import 'custom_theme.dart';
import 'memento_colors.dart';

/// Corner radius scale used across the app: small controls, cards/inputs,
/// and floating surfaces (modals, large popovers).
class AppRadius {
  const AppRadius._();

  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
}

/// Assembles the light and dark [ThemeData] from a [CustomThemeColorSet]
/// plus the typography tokens. Flat by default: borders (hairlines)
/// separate content, shadows are reserved for floating surfaces only.
///
/// [dark]/[light] are the built-in palette; [buildDark]/[buildLight] take
/// an explicit [CustomThemeColorSet] (e.g. parsed from a user theme file)
/// for everything else.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark =>
      buildDark(CustomThemeColorSet.defaultsFor(Brightness.dark));

  static ThemeData get light =>
      buildLight(CustomThemeColorSet.defaultsFor(Brightness.light));

  static ThemeData buildDark(CustomThemeColorSet colors) =>
      _build(brightness: Brightness.dark, colors: colors);

  static ThemeData buildLight(CustomThemeColorSet colors) =>
      _build(brightness: Brightness.light, colors: colors);

  static ThemeData _build({
    required Brightness brightness,
    required CustomThemeColorSet colors,
  }) {
    final Color background = colors.backgroundPrimary;
    final Color surface = colors.card;
    final Color divider = colors.divider;
    final Color textPrimary = colors.textPrimary;
    final Color textSecondary = colors.textSecondary;
    final Color accent = colors.accent;
    final Color onAccent = colors.onAccent;
    final Color error = colors.error;
    final MementoColors mementoColors = MementoColors.fromColorSet(
      colors,
      brightness,
    );

    final ColorScheme colorScheme = ColorScheme(
      brightness: brightness,
      primary: accent,
      onPrimary: onAccent,
      secondary: accent,
      onSecondary: onAccent,
      error: error,
      onError: onAccent,
      surface: surface,
      onSurface: textPrimary,
    );

    final TextTheme textTheme = buildUiTextTheme(textPrimary, textSecondary);
    final RoundedRectangleBorder controlShape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
    );
    final OutlineInputBorder inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(AppRadius.medium),
      borderSide: BorderSide(color: divider),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: background,
      canvasColor: background,
      dividerColor: divider,
      textTheme: textTheme,
      // InkSparkle uses a custom fragment shader; on some Linux Mesa Intel
      // iGPU drivers that has been known to wedge the GPU command queue
      // hard enough to freeze the whole desktop compositor, not just this
      // app. InkRipple needs no custom shader and is the safe choice here.
      splashFactory: InkRipple.splashFactory,
      hoverColor: mementoColors.hoverOverlay,
      extensions: [mementoColors],
      dividerTheme: DividerThemeData(color: divider, thickness: 1, space: 1),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: BorderSide(color: divider),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          disabledBackgroundColor: divider,
          elevation: 0,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: textPrimary,
          side: BorderSide(color: divider),
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accent,
          minimumSize: const Size(0, 40),
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: controlShape,
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 10,
        ),
        border: inputBorder,
        enabledBorder: inputBorder,
        focusedBorder: inputBorder.copyWith(
          borderSide: BorderSide(color: accent, width: 1.5),
        ),
        hintStyle: textTheme.bodyMedium?.copyWith(color: textSecondary),
      ),
      checkboxTheme: CheckboxThemeData(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.small),
        ),
        fillColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? accent
              : Colors.transparent,
        ),
        side: BorderSide(color: divider, width: 1.5),
        checkColor: WidgetStatePropertyAll(onAccent),
      ),
      switchTheme: SwitchThemeData(
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected) ? accent : divider,
        ),
        thumbColor: WidgetStatePropertyAll(onAccent),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      tabBarTheme: TabBarThemeData(
        dividerColor: divider,
        indicatorColor: accent,
        labelColor: textPrimary,
        unselectedLabelColor: textSecondary,
        labelStyle: textTheme.labelLarge,
        unselectedLabelStyle: textTheme.labelLarge,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.large),
        ),
        titleTextStyle: textTheme.titleLarge,
        contentTextStyle: textTheme.bodyMedium,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: BorderSide(color: divider),
        ),
        textStyle: textTheme.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surface,
        contentTextStyle: textTheme.bodyMedium,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.medium),
          side: BorderSide(color: divider),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: surface,
          borderRadius: BorderRadius.circular(AppRadius.small),
          border: Border.all(color: divider),
        ),
        textStyle: textTheme.bodySmall?.copyWith(color: textPrimary),
      ),
    );
  }
}
