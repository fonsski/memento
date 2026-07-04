import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';
import 'memento_colors.dart';

/// Corner radius scale used across the app: small controls, cards/inputs,
/// and floating surfaces (modals, large popovers).
class AppRadius {
  const AppRadius._();

  static const double small = 4;
  static const double medium = 8;
  static const double large = 12;
}

/// Assembles the light and dark [ThemeData] from the raw color and
/// typography tokens. Flat by default: borders (hairlines) separate
/// content, shadows are reserved for floating surfaces only.
class AppTheme {
  const AppTheme._();

  static ThemeData get dark => _build(
    brightness: Brightness.dark,
    background: MementoDarkColors.backgroundPrimary,
    surface: MementoDarkColors.card,
    divider: MementoDarkColors.divider,
    textPrimary: MementoDarkColors.textPrimary,
    textSecondary: MementoDarkColors.textSecondary,
    accent: MementoDarkColors.accent,
    onAccent: MementoDarkColors.onAccent,
    error: MementoDarkColors.error,
    hoverOverlay: MementoDarkColors.hoverOverlay,
    mementoColors: MementoColors.dark(),
  );

  static ThemeData get light => _build(
    brightness: Brightness.light,
    background: MementoLightColors.backgroundPrimary,
    surface: MementoLightColors.card,
    divider: MementoLightColors.divider,
    textPrimary: MementoLightColors.textPrimary,
    textSecondary: MementoLightColors.textSecondary,
    accent: MementoLightColors.accent,
    onAccent: MementoLightColors.onAccent,
    error: MementoLightColors.error,
    hoverOverlay: MementoLightColors.hoverOverlay,
    mementoColors: MementoColors.light(),
  );

  static ThemeData _build({
    required Brightness brightness,
    required Color background,
    required Color surface,
    required Color divider,
    required Color textPrimary,
    required Color textSecondary,
    required Color accent,
    required Color onAccent,
    required Color error,
    required Color hoverOverlay,
    required MementoColors mementoColors,
  }) {
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
      splashFactory: InkSparkle.splashFactory,
      hoverColor: hoverOverlay,
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
