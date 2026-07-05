import 'package:flutter/material.dart';

import 'custom_theme.dart';

/// Semantic colors that don't have a home in Material's [ColorScheme]:
/// interaction overlays, the selected-row treatment, links, and the
/// non-error/warning/success/info-adjacent highlight colors. Read via
/// `Theme.of(context).extension<MementoColors>()`.
@immutable
class MementoColors extends ThemeExtension<MementoColors> {
  const MementoColors({
    required this.navPanel,
    required this.hoverOverlay,
    required this.activeOverlay,
    required this.selectedBackground,
    required this.selectedBorder,
    required this.link,
    required this.warning,
    required this.success,
    required this.info,
    required this.textSelection,
    required this.searchHighlight,
  });

  /// Derives the full set from a [CustomThemeColorSet]: [navPanel]/
  /// [link]/[warning]/[success]/[info] pass straight through, while the
  /// interaction/highlight colors are computed from [colors.accent] (and
  /// a neutral black/white for hover/active) so a custom theme re-skins
  /// consistently by setting far fewer values than this full set.
  factory MementoColors.fromColorSet(
    CustomThemeColorSet colors,
    Brightness brightness,
  ) {
    final bool isDark = brightness == Brightness.dark;
    final Color neutralOverlay = isDark ? Colors.white : Colors.black;
    return MementoColors(
      navPanel: colors.navPanel,
      hoverOverlay: neutralOverlay.withValues(alpha: isDark ? 0.06 : 0.04),
      activeOverlay: neutralOverlay.withValues(alpha: isDark ? 0.10 : 0.08),
      selectedBackground: colors.accent.withValues(alpha: isDark ? 0.14 : 0.12),
      selectedBorder: colors.accent,
      link: colors.link,
      warning: colors.warning,
      success: colors.success,
      info: colors.info,
      textSelection: colors.accent.withValues(alpha: isDark ? 0.22 : 0.20),
      searchHighlight: colors.accent.withValues(alpha: isDark ? 0.35 : 0.40),
    );
  }

  static MementoColors dark() => MementoColors.fromColorSet(
    CustomThemeColorSet.defaultsFor(Brightness.dark),
    Brightness.dark,
  );

  static MementoColors light() => MementoColors.fromColorSet(
    CustomThemeColorSet.defaultsFor(Brightness.light),
    Brightness.light,
  );

  final Color navPanel;
  final Color hoverOverlay;
  final Color activeOverlay;
  final Color selectedBackground;
  final Color selectedBorder;
  final Color link;
  final Color warning;
  final Color success;
  final Color info;
  final Color textSelection;
  final Color searchHighlight;

  @override
  MementoColors copyWith({
    Color? navPanel,
    Color? hoverOverlay,
    Color? activeOverlay,
    Color? selectedBackground,
    Color? selectedBorder,
    Color? link,
    Color? warning,
    Color? success,
    Color? info,
    Color? textSelection,
    Color? searchHighlight,
  }) {
    return MementoColors(
      navPanel: navPanel ?? this.navPanel,
      hoverOverlay: hoverOverlay ?? this.hoverOverlay,
      activeOverlay: activeOverlay ?? this.activeOverlay,
      selectedBackground: selectedBackground ?? this.selectedBackground,
      selectedBorder: selectedBorder ?? this.selectedBorder,
      link: link ?? this.link,
      warning: warning ?? this.warning,
      success: success ?? this.success,
      info: info ?? this.info,
      textSelection: textSelection ?? this.textSelection,
      searchHighlight: searchHighlight ?? this.searchHighlight,
    );
  }

  @override
  MementoColors lerp(ThemeExtension<MementoColors>? other, double t) {
    if (other is! MementoColors) return this;
    return MementoColors(
      navPanel: Color.lerp(navPanel, other.navPanel, t)!,
      hoverOverlay: Color.lerp(hoverOverlay, other.hoverOverlay, t)!,
      activeOverlay: Color.lerp(activeOverlay, other.activeOverlay, t)!,
      selectedBackground: Color.lerp(
        selectedBackground,
        other.selectedBackground,
        t,
      )!,
      selectedBorder: Color.lerp(selectedBorder, other.selectedBorder, t)!,
      link: Color.lerp(link, other.link, t)!,
      warning: Color.lerp(warning, other.warning, t)!,
      success: Color.lerp(success, other.success, t)!,
      info: Color.lerp(info, other.info, t)!,
      textSelection: Color.lerp(textSelection, other.textSelection, t)!,
      searchHighlight: Color.lerp(searchHighlight, other.searchHighlight, t)!,
    );
  }
}
