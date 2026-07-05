import 'dart:async';

import 'package:flutter/material.dart';

import 'custom_theme.dart';
import 'custom_theme_repository.dart';

/// Shows a dialog listing the built-in theme plus every custom theme
/// found in the themes folder. Resolves to the chosen theme as
/// `(id, definition)` — both `null` for the built-in theme — or to
/// `null` itself if dismissed without a choice.
Future<(String?, CustomThemeDefinition?)?> showThemePicker(
  BuildContext context, {
  required String? currentThemeId,
}) {
  return showDialog<(String?, CustomThemeDefinition?)>(
    context: context,
    builder: (context) => _ThemePickerDialog(currentThemeId: currentThemeId),
  );
}

class _ThemePickerDialog extends StatefulWidget {
  const _ThemePickerDialog({required this.currentThemeId});

  final String? currentThemeId;

  @override
  State<_ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends State<_ThemePickerDialog> {
  Map<String, CustomThemeDefinition>? _themes;
  String? _themesFolderPath;
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    try {
      final CustomThemeRepository repository =
          await CustomThemeRepository.create();
      final Map<String, CustomThemeDefinition> themes = await repository
          .loadAll();
      if (mounted) {
        setState(() {
          _themes = themes;
          _themesFolderPath = repository.themesDirectory.path;
        });
      }
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  void _choose(String? id, CustomThemeDefinition? definition) {
    Navigator.of(context).pop((id, definition));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Тема оформления'),
      content: SizedBox(
        width: 360,
        height: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _buildContent()),
            if (_themesFolderPath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Свои темы (.json) кладите сюда:',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SelectableText(
                _themesFolderPath!,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontFamily: 'JetBrains Mono'),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Закрыть'),
        ),
      ],
    );
  }

  // The built-in theme never depends on the themes-folder scan, so it
  // stays selectable even if that scan fails — only the custom-theme
  // section below it reflects loading/error state.
  Widget _buildContent() {
    final Map<String, CustomThemeDefinition>? themes = _themes;

    return ListView(
      shrinkWrap: true,
      children: [
        _ThemeOption(
          label: 'Встроенная (Ink & Patina)',
          selected: widget.currentThemeId == null,
          onTap: () => _choose(null, null),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Не удалось загрузить пользовательские темы',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else if (themes == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          )
        else
          for (final MapEntry<String, CustomThemeDefinition> entry
              in themes.entries)
            _ThemeOption(
              label: entry.value.name,
              selected: widget.currentThemeId == entry.key,
              onTap: () => _choose(entry.key, entry.value),
            ),
      ],
    );
  }
}

class _ThemeOption extends StatelessWidget {
  const _ThemeOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(
        selected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: selected ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(label),
      onTap: onTap,
    );
  }
}
