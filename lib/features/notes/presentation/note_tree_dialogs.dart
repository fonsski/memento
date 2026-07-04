import 'package:flutter/material.dart';

/// Shows a dialog with a single text field, pre-filled with
/// [initialValue]. Returns the entered, trimmed text, or `null` if the
/// user cancelled or submitted an empty value.
Future<String?> promptForTitle(
  BuildContext context, {
  required String dialogTitle,
  String initialValue = '',
}) {
  return showDialog<String>(
    context: context,
    builder: (BuildContext context) {
      return _TitlePromptDialog(title: dialogTitle, initialValue: initialValue);
    },
  );
}

class _TitlePromptDialog extends StatefulWidget {
  const _TitlePromptDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_TitlePromptDialog> createState() => _TitlePromptDialogState();
}

class _TitlePromptDialogState extends State<_TitlePromptDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final String trimmed = _controller.text.trim();
    Navigator.of(context).pop(trimmed.isEmpty ? null : trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        TextButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}

/// Shows a confirmation dialog for deleting [itemTitle]. Returns `true`
/// only if the user confirmed.
Future<bool> confirmDelete(BuildContext context, String itemTitle) async {
  final bool? confirmed = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Удалить безвозвратно?'),
        content: Text('«$itemTitle» будет удалено без возможности отмены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Удалить'),
          ),
        ],
      );
    },
  );
  return confirmed ?? false;
}
