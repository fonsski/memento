import 'package:flutter/material.dart';

import 'app_colors.dart';

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

  factory MementoColors.dark() => const MementoColors(
    navPanel: MementoDarkColors.navPanel,
    hoverOverlay: MementoDarkColors.hoverOverlay,
    activeOverlay: MementoDarkColors.activeOverlay,
    selectedBackground: MementoDarkColors.selectedBackground,
    selectedBorder: MementoDarkColors.selectedBorder,
    link: MementoDarkColors.link,
    warning: MementoDarkColors.warning,
    success: MementoDarkColors.success,
    info: MementoDarkColors.info,
    textSelection: MementoDarkColors.textSelection,
    searchHighlight: MementoDarkColors.searchHighlight,
  );

  factory MementoColors.light() => const MementoColors(
    navPanel: MementoLightColors.navPanel,
    hoverOverlay: MementoLightColors.hoverOverlay,
    activeOverlay: MementoLightColors.activeOverlay,
    selectedBackground: MementoLightColors.selectedBackground,
    selectedBorder: MementoLightColors.selectedBorder,
    link: MementoLightColors.link,
    warning: MementoLightColors.warning,
    success: MementoLightColors.success,
    info: MementoLightColors.info,
    textSelection: MementoLightColors.textSelection,
    searchHighlight: MementoLightColors.searchHighlight,
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
      selectedBackground:
          Color.lerp(selectedBackground, other.selectedBackground, t)!,
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
